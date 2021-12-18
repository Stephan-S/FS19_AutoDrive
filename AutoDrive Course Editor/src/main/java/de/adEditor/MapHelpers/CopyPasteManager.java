package de.adEditor.MapHelpers;

import de.adEditor.GUIBuilder;
import de.adEditor.MapPanel;
import java.awt.geom.AffineTransform;
import java.awt.geom.Point2D;
import java.util.LinkedList;

import static de.adEditor.ADUtils.LOG;
import static de.adEditor.AutoDriveEditor.*;
import static de.adEditor.MapPanel.*;

public class CopyPasteManager {

    private static final int WORLD_COORDINATES = 1;
    private static final int SCREEN_COORDINATES = 2;

    private LinkedList<MapNode> nodeCache;

    // NodeTransform is used to reference the old to new mapnodes when re-creating
    // the connections to the new nodes, this way we can keep the valid connections
    // when they are added to the node network

    private static class NodeTransform {
        MapNode originalNode;
        MapNode newNode;
        LinkedList<MapNode> incoming;
        LinkedList<MapNode> outgoing;

        public NodeTransform(MapNode origNode, MapNode newNode) {
            this.originalNode = origNode;
            this.newNode = newNode;
            this.incoming = new LinkedList<>();
            this.outgoing = new LinkedList<>();
        }
    }

    public CopyPasteManager () {

        this.nodeCache = new LinkedList<>();
    }

    public void CutSelection(LinkedList<MapNode> nodesToCopy) {
        deleteNodeList.clear();
        for (MapNode node : nodesToCopy) {
            addToDeleteList(node);
        }
        changeManager.addChangeable( new ChangeManager.RemoveNodeChanger(deleteNodeList));
        CopySelection(nodesToCopy);
        MapPanel.getMapPanel().removeNodes();
        clearMultiSelection();
    }

    public void CopySelection(LinkedList<MapNode> nodesToCopy) {
        LinkedList<MapNode> tempCache;
        // get the centre point of the selected nodes
        rectangleInfo recInfo = getSelectionBounds(nodesToCopy, WORLD_COORDINATES);
        Point2D centrePoint = null;
        if (recInfo != null) {
            centrePoint = recInfo.recCentre;
            // rebuild the selected nodes and there connections to a new arrayList
            tempCache = createNewMapNodesFromList(nodesToCopy, (int) centrePoint.getX(), (int) centrePoint.getY());
            // create a cached LinkedList so we can paste this in as many times as needed
            nodeCache = createNewMapNodesFromList(tempCache, 0, 0);
            GUIBuilder.rotationMenuEnabled(true);
        }
    }

    public void PasteSelection() {
        if (nodeCache.size() > 0 ) {
            LinkedList<MapNode> tempCache = createNewMapNodesFromList(nodeCache, 0, 0);
            addNodesToNetwork(tempCache);
        } else {
            LOG.info("Cannot Paste - Buffer empty");
        }
    }


    public LinkedList<MapNode> createNewMapNodesFromList(LinkedList<MapNode> list, int rectCentreX, int rectCentreY) {

        // create a new MapNode for each node in the list

        LinkedList<NodeTransform> workBuffer = new LinkedList<>();
        LinkedList<MapNode> tempCache = new LinkedList<>();

        int n = 1;
        for (MapNode node : list) {
            MapNode workBufferNode = new MapNode(n++, node.x - rectCentreX, node.y, node.z - rectCentreY, node.flag, true, false);
            workBuffer.add(new NodeTransform(node, workBufferNode));
        }

        // iterate through the list and remake the connections using the new nodes
        for (MapNode originalListNode : list) {
            MapNode sourceNode = null;

            for (NodeTransform workBufferNode : workBuffer) {
                if (workBufferNode.originalNode == originalListNode) {
                    sourceNode = workBufferNode.newNode;
                    //if (DEBUG) LOG.info("SourceNode = {}", sourceNode.id);
                    break;
                }
            }

            if (sourceNode != null) {
                MapNode destNode = null;
                for (int in = 0; in < originalListNode.incoming.size(); in++) {
                    MapNode originalIncomingNode = originalListNode.incoming.get(in);
                    for (NodeTransform workBufferNode : workBuffer) {
                        if (workBufferNode.originalNode == originalIncomingNode) {
                            destNode = workBufferNode.newNode;
                            sourceNode.incoming.add(destNode);
                            //if (DEBUG) LOG.info("{} incoming from {}", sourceNode.id, destNode.id);
                            break;
                        }
                    }
                }

                for (int out = 0; out < originalListNode.outgoing.size(); out++) {
                    MapNode originalOutgoingNode = originalListNode.outgoing.get(out);
                    for (NodeTransform workNode : workBuffer) {
                        if (workNode.originalNode == originalOutgoingNode) {
                            destNode = workNode.newNode;
                            sourceNode.outgoing.add(destNode);
                            //if (DEBUG) LOG.info("{} outgoing to {}", sourceNode.id, destNode.id);
                        }
                    }
                }
            }
        }

        for (NodeTransform node : workBuffer) {
            tempCache.add(node.newNode);
        }
        return tempCache;
    }

    public void addNodesToNetwork(LinkedList<MapNode> newNodes) {
        if ((roadMap == null) || (image == null)) {
            return;
        }
        Point2D selectionCentre = getMapPanel().screenPosToWorldPos(getMapPanel().getWidth() / 2, getMapPanel().getHeight() / 2);
        clearMultiSelection();

        int startID = roadMap.mapNodes.size() + 1;
        for (MapNode node : newNodes) {
            node.id = startID++;
            node.x += selectionCentre.getX();
            node.z += selectionCentre.getY();
            node.selected = false;
            roadMap.mapNodes.add(node);
        }

        changeManager.addChangeable( new ChangeManager.AddMultiNodeChanger(newNodes) );
        MapPanel.getMapPanel().setStale(true);
        MapPanel.getMapPanel().repaint();
    }

    public static void rotateSelected(double angle) {
        rectangleInfo recInfo = getSelectionBounds(multiSelectList, WORLD_COORDINATES);
        for (MapNode node : multiSelectList) {
            if ( recInfo != null ) {
                rotate(node, recInfo.recCentre, angle);
            }
        }
        MapPanel.getMapPanel().repaint();
        getSelectionBounds(multiSelectList, WORLD_COORDINATES);
    }

    public static void rotate(MapNode node, Point2D centre, double angle) {
        Point2D result = new Point2D.Double();
        AffineTransform rotation = new AffineTransform();
        double angleInRadians = Math.toRadians(angle);
        rotation.rotate(angleInRadians, centre.getX(), centre.getY());
        rotation.transform(new Point2D.Double(node.x, node.z), result);
        node.x = result.getX();
        node.z = result.getY();
        //node.x = (double) Math.round(result.getX() * 50) / 50;
        //node.z = (double)Math.round(result.getY() * 50) / 50;
    }

    private static rectangleInfo getSelectionBounds(LinkedList<MapNode> nodesToCopy, int coordType) {
        double topLeftX = 0, topLeftY = 0;
        double bottomRightX = 0, bottomRightY = 0;
        for (int j = 0; j < nodesToCopy.size(); j++) {
            MapNode node = nodesToCopy.get(j);
            if (j == 0) {
                topLeftX = node.x;
                topLeftY = node.z;
                bottomRightX = node.x;
                bottomRightY = node.z;
            } else {
                if (node.x < topLeftX ) {
                    topLeftX = node.x;
                }
                if (node.z < topLeftY ) {
                    topLeftY = node.z;
                }
                if (node.x > bottomRightX ) {
                    bottomRightX = node.x;
                }
                if (node.z > bottomRightY ) {
                    bottomRightY = node.z;
                }
            }
        }
        double rectSizeX = bottomRightX - topLeftX;
        double rectSizeY = bottomRightY - topLeftY;
        double centreX = bottomRightX - ( rectSizeX / 2 );
        double centreY = bottomRightY - ( rectSizeY / 2 );

        if (coordType == WORLD_COORDINATES) {
            //if (DEBUG) LOG.info("## WORLD_COORDINATES ## Rectangle start = {} , {} : end = {} , {} : size = {} , {} : Centre = {} , {}", topLeftX, topLeftY, bottomRightX, bottomRightY, rectSizeX, rectSizeY, centreX, centreY);
            return new rectangleInfo( new Point2D.Double(topLeftX, topLeftY) ,
                    new Point2D.Double(bottomRightX, bottomRightY),
                    new Point2D.Double(rectSizeX, rectSizeY),
                    new Point2D.Double(centreX, centreY));
        } else if (coordType == SCREEN_COORDINATES) {
            Point2D topLeft = worldPosToScreenPos(topLeftX, topLeftY);
            Point2D bottomRight = worldPosToScreenPos(bottomRightX, bottomRightY);
            Point2D rectSize = worldPosToScreenPos(rectSizeX, rectSizeY);
            Point2D rectCentre = worldPosToScreenPos(centreX, centreY);
            if (DEBUG) LOG.info("## SCREEN_COORDINATES ## Rectangle start = {} : end = {} : size = {} : Centre = {} ", topLeft, bottomRight, rectSize, rectCentre);
            return new rectangleInfo(topLeft, bottomRight, rectSize, rectCentre);
        } else {
            LOG.info("No return type specified for getSelectionBounds() - returning null");
            return null;
        }
    }

    public static class rectangleInfo{
        private final Point2D recStart;
        private final Point2D recEnd;
        private final Point2D recSize;
        private final Point2D recCentre;

        public rectangleInfo(Point2D start, Point2D end, Point2D size, Point2D centre){
            this.recStart = start;
            this.recEnd = end;
            this.recSize = size;
            this.recCentre = centre;
        }
        // getter setters
        public Point2D getRectangleStart() {
            return this.recStart;
        }

        public Point2D getRectangleEnd() {
            return this.recEnd;
        }

        public Point2D getRectangleSize() {
            return this.recSize;
        }

        public Point2D getRectangleCentre() {
            return this.recCentre;
        }

    }

}
