package de.adEditor;

import javax.swing.*;
import java.awt.*;
import java.awt.event.ComponentAdapter;
import java.awt.event.ComponentEvent;
import java.awt.geom.Point2D;
import java.awt.geom.Rectangle2D;
import java.awt.image.BufferedImage;
import java.text.Collator;
import java.util.ArrayList;
import java.util.Collections;
import java.util.LinkedList;

import de.adEditor.MapHelpers.*;

import static de.adEditor.ADUtils.*;
import static de.adEditor.AutoDriveEditor.*;
import static de.adEditor.GUIBuilder.*;
import static de.adEditor.MapHelpers.ChangeManager.*;

public class MapPanel extends JPanel{

    public static final int NODE_STANDARD = 0;
    public static final int NODE_SUBPRIO = 1;
    public static final int NODE_CONTROLPOINT = 2;

    public static final int CONNECTION_STANDARD = 0;
    public static final int CONNECTION_SUBPRIO = 1; // never used as subprio routes are based on a nodes .flag value
    public static final int CONNECTION_DUAL = 2;
    public static final int CONNECTION_REVERSE = 3;

    private BufferedImage image;
    private BufferedImage resizedImage;

    private double x = 0.5;
    private double y = 0.5;
    private double zoomLevel = 1.0;
    private double lastZoomLevel = 1.0;
    private int mapZoomFactor = 1;
    private double nodeSize = 1.0;
    private AutoDriveEditor editor;

    public static RoadMap roadMap;
    public static  MapNode hoveredNode = null;
    private MapNode movingNode = null;
    private MapNode selected = null;

    private static int mousePosX = 0;
    private static int mousePosY = 0;

    private boolean isDragging = false;
    public static  boolean isDraggingNode = false;
    private int lastX = 0;
    private int lastY = 0;

    private Point2D rectangleStart;
    public boolean isMultiSelectAllowed = false;

    private static boolean isMultipleSelected = false;
    public static LinkedList<MapNode> multiSelectList  = new LinkedList<>();

    public boolean isDraggingRoute = false;
    private static boolean isControlNodeSelected = false;
    private static boolean isQuadCurveCreated = false;
    public static QuadCurve quadCurve;
    public static LinearLine linearLine;
    public static int connectionType = 0; // 0 = regular , 1 = dual, 2 = reverse

    public static int createRegularConnectionState = 0;
    public static int createDualConnectionState = 0;
    public static int createReverseConnectionState = 0;

    public static LinkedList<NodeLinks> deleteNodeList = new LinkedList<>();
    public static int moveDiffX, moveDiffY;

    private final Color BROWN = new Color(152, 104, 50 );


    public MapPanel(AutoDriveEditor editor) {
        this.editor = editor;

        MouseListener mouseListener = new MouseListener(this);
        addMouseListener(mouseListener);
        addMouseMotionListener(mouseListener);
        addMouseWheelListener(mouseListener);

        addComponentListener(new ComponentAdapter(){
            @Override
            public void componentResized(ComponentEvent e) {
                resizeMap();
                repaint();
            }
        });
    }

    @Override
    protected void paintComponent(Graphics g) {
        super.paintComponent(g);

        if (this.image != null) {

            g.clipRect(0, 0, this.getWidth(), this.getHeight());

            g.drawImage(resizedImage, 0, 0, this); // see javadoc for more info on the parameters

            int sizescaled = (int) (nodeSize * zoomLevel);
            int sizescaledhalf = (int) (sizescaled * 0.5);

            if (roadMap != null) {
                for (MapNode mapNode : roadMap.mapNodes) {
                    Point2D nodePos = worldPosToScreenPos(mapNode.x, mapNode.z );
                    if (sizescaled > 3 ) {
                        if (mapNode.selected && mapNode.flag == 0) {
                            g.drawImage(nodeImageSelected, (int) (nodePos.getX() - sizescaledhalf), (int) (nodePos.getY() - sizescaledhalf), sizescaled, sizescaled, null);
                        } else if (mapNode.selected && mapNode.flag == 1) {
                            g.drawImage(subPrioNodeImageSelected, (int) (nodePos.getX() - sizescaledhalf), (int) (nodePos.getY() - sizescaledhalf), sizescaled, sizescaled, null);
                        } else if (mapNode.flag == 1) {
                            g.drawImage(subPrioNodeImage,(int) (nodePos.getX() - sizescaledhalf), (int) (nodePos.getY() - sizescaledhalf), sizescaled, sizescaled, null);
                        } else {
                            g.drawImage(nodeImage,(int) (nodePos.getX() - sizescaledhalf), (int) (nodePos.getY() - sizescaledhalf), sizescaled, sizescaled, null);
                        }
                    }

                    //
                    // TODO remove before release
                    //
                    g.setColor(Color.WHITE);
                    //Point2D nodePosMarker = worldPosToScreenPos(hoveredNode.x - 1, hoveredNode.z + 3);
                    String text = "ID " + mapNode.id;
                    g.drawString(text, (int) (nodePos.getX() - 10 ), (int) (nodePos.getY() + 30 ));

                    //
                    //
                    //

                    LinkedList<MapNode> mapNodes = mapNode.outgoing;
                    for (MapNode outgoing : mapNodes) {
                        boolean dual = RoadMap.isDual(mapNode, outgoing);
                        boolean reverse = RoadMap.isReverse(mapNode, outgoing);

                        if (dual && mapNode.flag == 1) {
                            g.setColor(BROWN);
                        } else if (dual) {
                            g.setColor(Color.BLUE);
                        } else if (reverse) {
                            g.setColor(Color.CYAN);
                        } else if (mapNode.flag == 1) {
                            g.setColor(Color.ORANGE);
                        } else {
                            g.setColor(Color.GREEN);
                        }

                        Point2D outPos = worldPosToScreenPos(outgoing.x, outgoing.z);
                        drawArrowBetween(g, nodePos, outPos, dual);
                    }
                }

                // draw map marker name

                for (MapMarker mapMarker : roadMap.mapMarkers) {
                    g.setColor(Color.WHITE);
                    Point2D nodePos = worldPosToScreenPos(mapMarker.mapNode.x - 1, mapMarker.mapNode.z - 1 );
                    g.drawString(mapMarker.name, (int) (nodePos.getX()), (int) (nodePos.getY()));
                }

                // change colour of in progress connection line

                if (selected != null) {
                    if (editorState == EDITORSTATE_CONNECTING) {
                        if (linearLine.lineNodeList.size() > 1) {
                            for (int j = 0; j < linearLine.lineNodeList.size() -1; j++) { // skip the starting node of the array
                                MapNode firstPos = linearLine.lineNodeList.get(j);
                                MapNode secondPos = linearLine.lineNodeList.get(j+1);

                                Point2D startNodePos = worldPosToScreenPos(firstPos.x, firstPos.y);
                                Point2D endNodePos = worldPosToScreenPos(secondPos.x, secondPos.y);

                                g.setColor(Color.WHITE);
                                // don't draw the circle for the last node in the array
                                if (j < linearLine.lineNodeList.size() - 2 ) {
                                    g.fillArc((int) (endNodePos.getX() - ((nodeSize * zoomLevel) * 0.5)), (int) (endNodePos.getY() - ((nodeSize * zoomLevel) * 0.5)), (int) (nodeSize * zoomLevel), (int) (nodeSize * zoomLevel), 0, 360);
                                }
                                if ( connectionType == CONNECTION_DUAL ) {
                                    g.setColor(Color.BLUE);
                                } else if ( connectionType == CONNECTION_REVERSE ) {
                                    g.setColor(Color.CYAN);
                                } else {
                                    g.setColor(Color.GREEN);
                                }
                                drawArrowBetween(g, startNodePos, endNodePos, connectionType == CONNECTION_DUAL);

                            }
                        }  else {
                            if (linearLine.lineNodeList.size() == 1) {

                                if ( connectionType == CONNECTION_DUAL ) {
                                    g.setColor(Color.BLUE);
                                } else if ( connectionType == CONNECTION_REVERSE ) {
                                    g.setColor(Color.CYAN);
                                } else {
                                    g.setColor(Color.GREEN);
                                }

                                Point2D startNodePos = worldPosToScreenPos(linearLine.getLineStartNode().x, linearLine.getLineStartNode().z);
                                Point2D mousePos = new Point2D.Double(mousePosX,mousePosY);
                                drawArrowBetween(g, startNodePos, mousePos, connectionType == CONNECTION_DUAL);

                            }
                        }
                    } else {
                        g.setColor(Color.white);
                        Point2D startNodePos = worldPosToScreenPos(selected.x, selected.z);
                        Point2D mousePos = new Point2D.Double(mousePosX,mousePosY);
                        drawArrowBetween(g, startNodePos, mousePos, false);
                    }
                }

                // draw node different colour if selected

                if (hoveredNode != null) {
                    Point2D nodePos = worldPosToScreenPos(hoveredNode.x, hoveredNode.z);
                    if (hoveredNode.flag == NODE_STANDARD) {
                        g.drawImage(nodeImageSelected,(int) (nodePos.getX() - sizescaledhalf), (int) (nodePos.getY() - sizescaledhalf), sizescaled, sizescaled, null);
                    } else if (hoveredNode.flag == NODE_SUBPRIO) {
                        g.drawImage(subPrioNodeImageSelected,(int) (nodePos.getX() - sizescaledhalf), (int) (nodePos.getY() - sizescaledhalf), sizescaled, sizescaled, null);
                    }

                    //draw marker group when hovering over node

                    for (MapMarker mapMarker : roadMap.mapMarkers) {
                        if (hoveredNode.id == mapMarker.mapNode.id) {
                            g.setColor(Color.WHITE);
                            Point2D nodePosMarker = worldPosToScreenPos(mapMarker.mapNode.x - 1, mapMarker.mapNode.z -1);
                            String text = "ID " + hoveredNode.id +": " +mapMarker.name + " ( " + mapMarker.group + " )";
                            g.drawString(text, (int) (nodePosMarker.getX()), (int) (nodePosMarker.getY()));

                        }
                    }
                }

                // draw quad curve related items

                if (quadCurve != null) {
                    if (isQuadCurveCreated) {
                        // draw control point
                        Point2D nodePos = worldPosToScreenPos(quadCurve.getControlPoint().x, quadCurve.getControlPoint().z);
                        if (quadCurve.getControlPoint().selected || hoveredNode == quadCurve.getControlPoint()) {
                            g.drawImage(controlPointImageSelected, (int) (nodePos.getX() - sizescaledhalf), (int) (nodePos.getY() - sizescaledhalf), sizescaled, sizescaled, null);
                        } else {
                            g.drawImage(controlPointImage, (int) (nodePos.getX() - sizescaledhalf), (int) (nodePos.getY() - sizescaledhalf), sizescaled, sizescaled, null);
                        }

                        //draw interpolation points for curve
                        for (int j = 0; j < quadCurve.curveNodesList.size() - 1; j++) {

                            MapNode currentcoord = quadCurve.curveNodesList.get(j);
                            MapNode nextcoored = quadCurve.curveNodesList.get(j + 1);

                            Point2D currentNodePos = worldPosToScreenPos(currentcoord.x, currentcoord.z);
                            Point2D nextNodePos = worldPosToScreenPos(nextcoored.x, nextcoored.z);

                            g.setColor(Color.WHITE);
                            //don't draw the first node as it already been drawn
                            if (j != 0) {
                                if (quadCurve.getNodeType() == NODE_STANDARD) {
                                    g.drawImage(curveNodeImage,(int) (currentNodePos.getX() - sizescaledhalf), (int) (currentNodePos.getY() - sizescaledhalf), sizescaled, sizescaled, null);
                                } else {
                                    g.drawImage(subPrioNodeImage,(int) (currentNodePos.getX() - (sizescaledhalf / 2 )), (int) (currentNodePos.getY() - (sizescaledhalf / 2 )), sizescaledhalf, sizescaledhalf, null);
                                }
                            }
                            if (quadCurve.isReversePath()) {
                                g.setColor(Color.CYAN);
                            } else if (quadCurve.isDualPath() && quadCurve.getNodeType() == NODE_STANDARD) {
                                g.setColor(Color.BLUE);
                            } else if (quadCurve.isDualPath() && quadCurve.getNodeType() == NODE_SUBPRIO) {
                                g.setColor(Color.ORANGE);
                            } else {
                                g.setColor(Color.GREEN);
                            }
                            drawArrowBetween(g, currentNodePos, nextNodePos, quadCurve.isDualPath()) ;
                        }
                    }
                }

                if (rectangleStart != null) {
                    g.setColor(Color.WHITE);
                    int width = (int) (mousePosX - rectangleStart.getX());
                    int height = (int) (mousePosY - rectangleStart.getY());
                    int recx = Double.valueOf(rectangleStart.getX()).intValue();
                    int recy = Double.valueOf(rectangleStart.getY()).intValue();
                    if (width < 0) {
                        recx += width;
                        width = -width;
                    }
                    if (height < 0) {
                        recy += height;
                        height = -height;
                    }
                    g.drawRect(recx, recy, width, height);
                }
            }
        }
    }

    private void resizeMap()  {
        if (image != null) {
            int widthScaled = (int) (this.getWidth() / zoomLevel);
            int heightScaled = (int) (this.getHeight() / zoomLevel);

            double maxX = 1 - (((this.getWidth() * 0.5) / zoomLevel) / image.getWidth());
            double minX = (((this.getWidth() * 0.5) / zoomLevel) / image.getWidth());
            double maxY = 1 - (((this.getHeight() * 0.5) / zoomLevel) / image.getHeight());
            double minY = (((this.getHeight() * 0.5) / zoomLevel) / image.getHeight());

            x = Math.min(x, maxX);
            x = Math.max(x, minX);
            y = Math.min(y, maxY);
            y = Math.max(y, minY);

            int centerX = (int) (x * image.getWidth());
            int centerY = (int) (y * image.getHeight());

            int offsetX = (centerX - (widthScaled / 2));
            int offsetY = (centerY - (heightScaled / 2));

            BufferedImage croppedImage = image.getSubimage(offsetX, offsetY, widthScaled, heightScaled);

            resizedImage = new BufferedImage(this.getWidth(), this.getHeight(), image.getType());
            Graphics2D g2 = (Graphics2D) resizedImage.getGraphics();
            g2.drawImage(croppedImage, 0, 0, this.getWidth(), this.getHeight(), null);
            g2.dispose();

            //lastZoomLevel = zoomLevel;
        }
    }

    public void moveMapBy(int diffX, int diffY) {
        if ((roadMap == null) || (this.image == null)) {
            return;
        }
        x -= diffX / (zoomLevel * image.getWidth());
        y -= diffY / (zoomLevel * image.getHeight());

        resizeMap();
        this.repaint();
    }

    public void increaseZoomLevelBy(int rotations) {
        double step = rotations * (zoomLevel * 0.1);
        if ((roadMap == null) || (this.image == null)) {
            return;
        }
        if (((this.getWidth()/(this.zoomLevel - step)) > image.getWidth()) || ((this.getHeight()/(this.zoomLevel - step)) > image.getHeight())) {
            return;
        }

        if ((this.zoomLevel - step) < 30) {
            this.zoomLevel -= step;
            resizeMap();
            repaint();
        }
    }

    public void moveNodeBy(MapNode node, int diffX, int diffY) {
            node.x +=  ((diffX * mapZoomFactor) / zoomLevel);
            node.z += ((diffY * mapZoomFactor) / zoomLevel);
            if (isQuadCurveCreated) {
                if (node == quadCurve.getCurveStartNode()) {
                    quadCurve.setCurveStartNode(node);
                } else if (node == quadCurve.getCurveEndNode()) {
                    quadCurve.setCurveEndNode(node);
                }
                if (node == quadCurve.getControlPoint()) {
                    quadCurve.updateControlPoint(node);
                }
            }
            editor.setStale(true);
            repaint();

    }

    public MapNode getNodeAt(double posX, double posY) {
        if ((roadMap != null) && (this.image != null)) {
            for (MapNode mapNode : roadMap.mapNodes) {
                double currentNodeSize = nodeSize * zoomLevel * 0.5;

                Point2D outPos = worldPosToScreenPos(mapNode.x, mapNode.z);

                if (posX < outPos.getX() + currentNodeSize && posX > outPos.getX() - currentNodeSize && posY < outPos.getY() + currentNodeSize && posY > outPos.getY() - currentNodeSize) {
                    return mapNode;
                }
            }
            if (isQuadCurveCreated) {
                double currentNodeSize = nodeSize * zoomLevel * 0.5;

                Point2D outPos = worldPosToScreenPos(quadCurve.getControlPoint().x, quadCurve.getControlPoint().z);

                if (posX < outPos.getX() + currentNodeSize && posX > outPos.getX() - currentNodeSize && posY < outPos.getY() + currentNodeSize && posY > outPos.getY() - currentNodeSize) {
                    return quadCurve.getControlPoint();
                }
            }
        }
        return null;
    }

    public void removeNodes() {
        for (int i = 0; i < deleteNodeList.size(); i++) {
            MapNode inList = deleteNodeList.get(i).node;
            roadMap.removeMapNode(inList);
        }
        editor.setStale(true);
        hoveredNode = null;
        this.repaint();
    }

    public void removeDestination(MapNode toDelete) {
        MapMarker destinationToDelete = null;
        LinkedList<MapMarker> mapMarkers = roadMap.mapMarkers;
        for (MapMarker mapMarker : mapMarkers) {
            if (mapMarker.mapNode.id == toDelete.id) {
                destinationToDelete = mapMarker;
            }
        }
        if (destinationToDelete != null) {
            roadMap.removeMapMarker(destinationToDelete);
            editor.setStale(true);
            this.repaint();
        }
    }

    public void createNode(double screenX, double screenY, int flag) {
        if ((roadMap == null) || (this.image == null)) {
            return;
        }
        MapNode mapNode = new MapNode(roadMap.mapNodes.size()+1, screenX, -1, screenY, flag, false); //flag = 0 causes created node to be regular by default
        roadMap.mapNodes.add(mapNode);
        editor.setStale(true);
        this.repaint();
        changeManager.addChangeable( new AddNodeChanger(mapNode) );
        LOG.error("");
    }

    public Point2D screenPosToWorldPos(int screenX, int screenY) {
        double centerX = (x * (image.getWidth()));
        double centerY = (y * (image.getHeight()));

        double widthScaled = (this.getWidth() / zoomLevel);
        double heightScaled = (this.getHeight() / zoomLevel);

        double topLeftX = centerX - (widthScaled/2);
        double topLeftY = centerY - (heightScaled/2);

        double diffScaledX = screenX / zoomLevel;
        double diffScaledY = screenY / zoomLevel;

        int centerPointOffset = 1024 * mapZoomFactor;

        double worldPosX = ((topLeftX + diffScaledX) * mapZoomFactor) - centerPointOffset;
        double worldPosY = ((topLeftY + diffScaledY) * mapZoomFactor) - centerPointOffset;

        return new Point2D.Double(worldPosX, worldPosY);
    }

    public Point2D worldPosToScreenPos(double worldX, double worldY) {

        int centerPointOffset = 1024 * mapZoomFactor;

        worldX += centerPointOffset;
        worldY += centerPointOffset;

        double scaledX = (worldX/mapZoomFactor) * zoomLevel;
        double scaledY = (worldY/mapZoomFactor) * zoomLevel;

        double centerXScaled = (x * (image.getWidth()*zoomLevel));
        double centerYScaled = (y * (image.getHeight()*zoomLevel));

        double topLeftX = centerXScaled - ((double) this.getWidth() /2);
        double topLeftY = centerYScaled - ((double) this.getHeight()/2);

        return new Point2D.Double(scaledX - topLeftX,scaledY - topLeftY);
    }

    public static void createConnectionBetween(MapNode start, MapNode target, int type) {
        if (start == target) {
            return;
        }

        if (!start.outgoing.contains(target)) {
            start.outgoing.add(target);

            if (type == CONNECTION_STANDARD) {
                if (!target.incoming.contains(start))
                target.incoming.add(start);
            } else if (type == CONNECTION_REVERSE ) {
                if (start.incoming.contains(target)) {
                    start.incoming.remove(target);
                }
                if (target.incoming.contains(start)) {
                    target.incoming.remove(start);
                }
                if (target.outgoing.contains(start)) {
                    target.outgoing.remove(start);
                }
            } else if (type == CONNECTION_DUAL) {
                if (!target.incoming.contains(start)) {
                    target.incoming.add(start);
                }
                if (!target.outgoing.contains(start)) {
                    target.outgoing.add(start);
                }
                if (!start.incoming.contains(target)) {
                    start.incoming.add(target);
                }
            }
        } else {
            if (type == CONNECTION_STANDARD) {
                if (start.outgoing.contains(target)) {
                    start.outgoing.remove(target);
                }
                if (target.incoming.contains(start)) {
                    target.incoming.remove(start);
                }
            } else if (type == CONNECTION_REVERSE ) {
                start.outgoing.remove(target);
                if (start.incoming.contains(target)) {
                    start.incoming.remove(target);
                }
                if (target.outgoing.contains(start)) {
                    target.outgoing.remove(start);
                }
                if (target.incoming.contains(start)) {
                    target.incoming.remove(start);
                }

            } else if (type == CONNECTION_DUAL) {
                start.outgoing.remove(target);
                if (start.incoming.contains(target)) {
                    start.incoming.remove(target);
                }
                if (target.incoming.contains(start)) {
                    target.incoming.remove(start);
                }
                if (target.outgoing.contains(start)) {
                    target.outgoing.remove(start);
                }
            }
        }
    }

    public void createDestinationAt(MapNode mapNode, String destinationName, String groupName) {
        if (mapNode != null && destinationName != null && destinationName.length() > 0) {
            if (groupName == null) groupName = "All";
            MapMarker mapMarker = new MapMarker(mapNode, destinationName, groupName);
            roadMap.addMapMarker(mapMarker);
            editor.setStale(true);
        }
    }

    public void changeNodePriority(MapNode nodeToChange) {
        if (nodeToChange.flag == 0) { // lazy way of doing nodeToChange.flag = 1 - nodeToChange.flag;
            nodeToChange.flag = 1;
        } else {
            nodeToChange.flag = 0;
        }
        editor.setStale(true);
        this.repaint();
    }

    public void removeAllNodesInScreenArea(Point2D rectangleStartScreen, Point2D rectangleEndScreen) {

        getAllNodesInArea(rectangleStartScreen, rectangleEndScreen);
        LOG.info("{}", localeString.getString("console_node_area_remove"));
        for (int j = 0; j < multiSelectList.size(); j++) {
            MapNode node = multiSelectList.get(j);

            addToDeleteList(node);

            /*LinkedList<MapNode> otherNodesInLinks = new LinkedList<>();
            LinkedList<MapNode> otherNodesOutLinks = new LinkedList<>();

            LinkedList<MapNode> roadmapNodes = roadMap.mapNodes;
            for (int i = 0; i < roadmapNodes.size(); i++) {
                MapNode mapNode = roadmapNodes.get(i);
                if (mapNode != node) {
                    if (mapNode.outgoing.contains(node)) {
                        otherNodesOutLinks.add(mapNode);
                    }
                    if (mapNode.incoming.contains(node)) {
                        otherNodesInLinks.add(mapNode);
                    }
                }

            }
            deleteNodeList.add(new NodeLinks(node, otherNodesInLinks, otherNodesOutLinks));*/
            LOG.info("Stored {}", node.id);
        }
        changeManager.addChangeable( new RemoveNodeChanger(deleteNodeList));
        removeNodes();
        deleteNodeList.clear();
        clearMultiSelection();
    }

    public void changeAllNodesPriInScreenArea(Point2D rectangleStartScreen, Point2D rectangleEndScreen) {

        getAllNodesInArea(rectangleStartScreen, rectangleEndScreen);
        if (!multiSelectList.isEmpty()) {
            editor.setStale(true);
            for (MapNode node : multiSelectList) {
                changeNodePriority(node);
            }
        }
        changeManager.addChangeable( new ChangeManager.NodePriorityChanger(multiSelectList));
        clearMultiSelection();
    }

   public void getAllNodesInArea(Point2D rectangleStartScreen, Point2D rectangleEndScreen) {
        if ((roadMap == null) || (this.image == null)) {
            return;
        }
        int screenStartX = (int) rectangleStartScreen.getX();
        int screenStartY = (int) rectangleStartScreen.getY();
        int width = (int)(rectangleEndScreen.getX() - rectangleStartScreen.getX());
        int height = (int)(rectangleEndScreen.getY() - rectangleStartScreen.getY());

        Rectangle2D rectangle = ADUtils.getNormalizedRectangleFor(screenStartX, screenStartY, width, height);
        screenStartX = (int) rectangle.getX();
        screenStartY = (int) rectangle.getY();
        width = (int) rectangle.getWidth();
        height = (int) rectangle.getHeight();

        LinkedList<MapNode> toChange = new LinkedList<>();
        for (MapNode mapNode : roadMap.mapNodes) {
            double currentNodeSize = nodeSize * zoomLevel * 0.5;

            Point2D nodePos = worldPosToScreenPos(mapNode.x, mapNode.z);

            if (screenStartX < nodePos.getX() + currentNodeSize && (screenStartX + width) > nodePos.getX() - currentNodeSize && screenStartY < nodePos.getY() + currentNodeSize && (screenStartY + height) > nodePos.getY() - currentNodeSize) {
                if (multiSelectList.contains(mapNode)) {
                    multiSelectList.remove(mapNode);
                    mapNode.selected = false;
                } else {
                    multiSelectList.add(mapNode);
                    mapNode.selected = true;
                }
            }
        }
        if (isQuadCurveCreated) {
            MapNode controlPoint = quadCurve.getControlPoint();
            if (multiSelectList.contains(controlPoint)) {
                multiSelectList.remove(controlPoint);
                controlPoint.selected = false;
            } else {
                multiSelectList.add(controlPoint);
                controlPoint.selected = true;
            }
        }
        if (multiSelectList.size() > 0 ) {
            isMultipleSelected = true;
        }
    }

    public static void clearMultiSelection() {
        if (multiSelectList != null && multiSelectList.size() > 0 ) {
            for (MapNode node : multiSelectList) {
                node.selected = false;
            }
            multiSelectList.clear();
        }
        isMultipleSelected = false;
    }

    public void drawArrowBetween(Graphics g, Point2D start, Point2D target, boolean dual) {
        double vecX = start.getX() - target.getX();
        double vecY = start.getY() - target.getY();

        double angleRad = Math.atan2(vecY, vecX);

        angleRad = normalizeAngle(angleRad);

        double arrowLength = 1.3 * zoomLevel;

        double arrowLeft = normalizeAngle(angleRad + Math.toRadians(-20));
        double arrowRight = normalizeAngle(angleRad + Math.toRadians(20));

        double arrowLeftX = target.getX() + Math.cos(arrowLeft) * arrowLength;
        double arrowLeftY = target.getY() + Math.sin(arrowLeft) * arrowLength;

        double arrowRightX = target.getX() + Math.cos(arrowRight) * arrowLength;
        double arrowRightY = target.getY() + Math.sin(arrowRight) * arrowLength;

        g.drawLine((int) (start.getX()), (int) (start.getY()), (int) (target.getX()), (int) (target.getY()));
        g.drawLine((int) (target.getX()), (int) (target.getY()), (int) arrowLeftX, (int) arrowLeftY);
        g.drawLine((int) (target.getX()), (int) (target.getY()), (int) arrowRightX, (int) arrowRightY);

        if (dual) {
            angleRad = normalizeAngle(angleRad+Math.PI);

            arrowLeft = normalizeAngle(angleRad + Math.toRadians(-20));
            arrowRight = normalizeAngle(angleRad + Math.toRadians(20));

            arrowLeftX = start.getX() + Math.cos(arrowLeft) * arrowLength;
            arrowLeftY = start.getY() + Math.sin(arrowLeft) * arrowLength;
            arrowRightX = start.getX() + Math.cos(arrowRight) * arrowLength;
            arrowRightY = start.getY() + Math.sin(arrowRight) * arrowLength;

            g.drawLine((int) (start.getX()), (int) (start.getY()), (int) arrowLeftX, (int) arrowLeftY);
            g.drawLine((int) (start.getX()), (int) (start.getY()), (int) arrowRightX, (int) arrowRightY);
        }
    }

    public void stopCurveEdit() {
        if (quadCurve != null) {
            quadCurve.clear();
            isQuadCurveCreated = false;
            isControlNodeSelected = false;
        }
    }

    //
    // Mouse movement and drag detection
    //

    public void mouseMoved(int x, int y) {
        if (this.image != null) {
            mousePosX = x;
            mousePosY = y;
            /*if (editorState == EDITORSTATE_CONNECTING && selected != null) {
                this.repaint();
            }*/
            if (editorState == EDITORSTATE_CONNECTING && selected != null) {
                if (isDraggingRoute) {
                    Point2D pointerPos = screenPosToWorldPos(mousePosX, mousePosY);
                    linearLine.updateLine(pointerPos.getX(), pointerPos.getY());
                    this.repaint();
                }
            }
            if (editorState == EDITORSTATE_QUADRATICBEZIER && selected != null) {
                this.repaint();
            }
            movingNode = getNodeAt(x, y);
            if (movingNode != hoveredNode) {
                hoveredNode = movingNode;
                this.repaint();
            }
        }
    }

    public void mouseDragged(int x, int y) {
        mousePosX = x;
        mousePosY = y;
        if (isDragging) {
            int diffX = x - lastX;
            int diffY = y - lastY;
            lastX = x;
            lastY = y;
            moveMapBy(diffX, diffY);
        }
        if (isDraggingNode) {
            int diffX = x - lastX;
            int diffY = y - lastY;
            lastX = x;
            lastY = y;
            moveDiffX += diffX;
            moveDiffY += diffY;
            if (editorState== EDITORSTATE_MOVING) {
                for (MapNode node : multiSelectList) {
                    moveNodeBy(node, diffX, diffY);
                }
            }
        }

        if (isControlNodeSelected) {
            int diffX = x - lastX;
            int diffY = y - lastY;
            lastX = x;
            lastY = y;

            moveNodeBy(quadCurve.getControlPoint(), diffX, diffY);
            quadCurve.updateCurve();

        }

        if (editorState == EDITORSTATE_QUADRATICBEZIER) {
            if (movingNode !=null && isQuadCurveCreated) {
                quadCurve.updateCurve();
                this.repaint();
            }
        }

        if (rectangleStart != null) {
            switch (editorState) {
                case EDITORSTATE_DELETE_NODES:
                case EDITORSTATE_CHANGE_NODE_PRIORITY:
                case EDITORSTATE_MOVING:
                case EDITORSTATE_ALIGN_HORIZONTAL:
                case EDITORSTATE_ALIGN_VERTICAL:
                case EDITORSTATE_CNP_SELECT:
                    this.repaint();
            }
        }
    }

    //
    // Left mouse button click/pressed/released states
    //

    public void mouseButton1Clicked(int x, int y) {

        movingNode = getNodeAt(x, y);

        if (editorState == EDITORSTATE_CREATE_PRIMARY_NODE) {
            Point2D worldPos = screenPosToWorldPos(x, y);
            createNode(worldPos.getX(), worldPos.getY(),NODE_STANDARD);
        }

        if (editorState == EDITORSTATE_CHANGE_NODE_PRIORITY) {
            MapNode changingNode = getNodeAt(x, y);
            if (changingNode != null) {
                if (changingNode.flag != NODE_CONTROLPOINT) {
                    changeNodePriority(changingNode);
                }
            }
        }

        if (editorState == EDITORSTATE_CREATE_SUBPRIO_NODE) {
            Point2D worldPos = screenPosToWorldPos(x, y);
            createNode(worldPos.getX(), worldPos.getY(),NODE_SUBPRIO);
        }

        if (editorState == EDITORSTATE_CREATING_DESTINATION) {
            if (movingNode != null) {
                for (int i = 0; i < roadMap.mapMarkers.size(); i++) {
                    MapMarker mapMarker = roadMap.mapMarkers.get(i);
                    if (mapMarker.mapNode == movingNode) {
                        LOG.info("{}", localeString.getString("console_marker_add_exists"));
                        return;
                    }
                }
                destInfo info = showNewMarkerDialog(movingNode.id);
                if (info != null && info.getName() != null) {
                    LOG.info("{} {} - Name = {} , Group = {}", localeString.getString("console_marker_add"), movingNode.id, info.getName(), info.getGroup());
                    createDestinationAt(movingNode, info.getName(), info.getGroup());
                    repaint();
                }
            }
        }

        if (editorState == EDITORSTATE_EDITING_DESTINATION) {
            if (movingNode != null) {
                for (int i = 0; i < roadMap.mapMarkers.size(); i++) {
                    MapMarker mapMarker = roadMap.mapMarkers.get(i);
                    if (mapMarker.mapNode == movingNode) {
                        destInfo info = showEditMarkerDialog(mapMarker.mapNode.id, mapMarker.name, mapMarker.group);
                        if (info != null && info.getName() != null) {
                            LOG.info("{} {} - Name = {} , Group = {}", localeString.getString("console_marker_modify"), movingNode.id, info.getName(), info.getGroup());
                            mapMarker.name = info.getName();
                            mapMarker.group = info.getGroup();
                            editor.setStale(true);
                        }
                    }
                }
            }
        }
        if (editorState == EDITORSTATE_ALIGN_HORIZONTAL) {
            if (isMultipleSelected && multiSelectList != null && movingNode != null) {
                //LOG.info("Horizontal Align {} nodes at {}",multiSelectList.size(), movingNode.y);
                for (MapNode node : multiSelectList) {
                    node.z = movingNode.z;
                }
                if (isQuadCurveCreated) {
                    quadCurve.updateCurve();
                }
                editor.setStale(true);
                clearMultiSelection();
                this.repaint();
            }
        }

        if (editorState == EDITORSTATE_ALIGN_VERTICAL) {
            if (isMultipleSelected && multiSelectList != null && movingNode != null) {
                //LOG.info("Horizontal Align {} nodes at {}",multiSelectList.size(), movingNode.x);
                for (MapNode node : multiSelectList) {
                    node.x = movingNode.x;
                }
                if (isQuadCurveCreated) {
                    quadCurve.updateCurve();
                }
                editor.setStale(true);
                clearMultiSelection();
                this.repaint();

            }
        }

        if (editorState == EDITORSTATE_QUADRATICBEZIER) {
            if (movingNode != null) {
                if (selected == null && !isQuadCurveCreated) {
                    selected = movingNode;
                    GUIBuilder.showInTextArea(localeString.getString("quadcurve_start"), true);
                } else if (selected == hoveredNode) {
                    selected = null;
                    GUIBuilder.showInTextArea(localeString.getString("quadcurve_cancel"), false);
                    stopCurveEdit();
                    this.repaint();
                } else {
                    if (!isQuadCurveCreated) {
                        GUIBuilder.showInTextArea(localeString.getString("quadcurve_complete"), false);
                        quadCurve = new QuadCurve(selected, movingNode);
                        quadCurve.setNumInterpolationPoints(GUIBuilder.numIterationsSlider.getValue());
                        isQuadCurveCreated = true;
                        selected = null;
                    }
                }
                repaint();
            }
        }
    }

    public void mouseButton1Pressed(int x, int y) {
        if (!bMiddleMouseMove) isDragging = true;
        lastX = x;
        lastY = y;
        movingNode = getNodeAt(x, y);

        if (editorState == EDITORSTATE_CONNECTING) {
            if (movingNode != null) {
                if (selected == null) {
                    selected = movingNode;
                    Point2D pointerPos = screenPosToWorldPos(mousePosX, mousePosY);
                    linearLine = new LinearLine(selected, pointerPos.getX(), pointerPos.getY());
                    isDraggingRoute = true;
                    GUIBuilder.showInTextArea(localeString.getString("linearline_start"), true);
                } else if (selected == hoveredNode) {
                    selected = null;
                    GUIBuilder.showInTextArea(localeString.getString("linearline_cancel"), false);
                } else {
                    int nodeType = 0;
                    if (connectionType == CONNECTION_STANDARD) {
                        nodeType = createRegularConnectionState;
                    } else if (connectionType == CONNECTION_DUAL) {
                        nodeType = createDualConnectionState;
                    } else if (connectionType == CONNECTION_REVERSE) {
                        nodeType = createReverseConnectionState;
                    }

                    linearLine.commit(movingNode, connectionType, nodeType);
                    GUIBuilder.showInTextArea(localeString.getString("linearline_complete"), false);
                    linearLine.clear();

                    if (AutoDriveEditor.bContinuousConnections) {
                        selected = movingNode;
                        Point2D pointerPos = screenPosToWorldPos(mousePosX, mousePosY);
                        linearLine = new LinearLine(movingNode, pointerPos.getX(), pointerPos.getY());
                    } else {
                        isDraggingRoute = false;
                        selected = null;
                    }
                }
                this.repaint();
            }
        }

        if (editorState == EDITORSTATE_QUADRATICBEZIER) {
            if (isQuadCurveCreated && movingNode == quadCurve.getControlPoint()) {
                    isControlNodeSelected = true;
            }
        }

        if (movingNode != null) {
            isDragging = false;
            if (editorState == EDITORSTATE_MOVING) {
                moveDiffX = 0;
                moveDiffY = 0;
                isDraggingNode = true;
                if (!multiSelectList.contains(movingNode)) {
                    multiSelectList.add(movingNode);
                }
            }
            if (editorState == EDITORSTATE_DELETE_NODES) {
                addToDeleteList(movingNode);
                changeManager.addChangeable( new RemoveNodeChanger(deleteNodeList));
                removeNodes();
                deleteNodeList.clear();
                clearMultiSelection();
            }
            if (editorState == EDITORSTATE_DELETING_DESTINATION) {
                removeDestination(movingNode);
            }
        }
    }

    public void mouseButton1Released(int x, int y) {
        if (!bMiddleMouseMove) isDragging = false;
        if (isDraggingNode) {
            changeManager.addChangeable( new MoveNodeChanger(multiSelectList, moveDiffX, moveDiffY));

            //moveEnd = new Point2D.Double( movingNode.x,movingNode.z);
            //LOG.info("start x = {} , y = {}", moveStart.x, moveStart.y);
            //LOG.info("end x = {} , y = {}", movingNode.x, movingNode.z);
            //LOG.info("diffx = {} , diffy = {}", ((moveDiffX * mapZoomFactor) / zoomLevel),((moveDiffY * mapZoomFactor) / zoomLevel));
            //moveNodeBy(movingNode, -moveDiffX, -moveDiffY);


        }
        clearMultiSelection();
        isDraggingNode = false;
        isControlNodeSelected=false;
    }

    //
    // Middle mouse button click/pressed/released states
    //

    public void mouseButton2Clicked(int x, int y) {}

    public void mouseButton2Pressed(int x, int y) {
        if (bMiddleMouseMove) {
            isDragging = true;
            lastX = x;
            lastY = y;
        }

    }

    public void mouseButton2Released() {
        if (bMiddleMouseMove) isDragging = false;
    }

    //
    // Right mouse button click/pressed/released states
    //

    public void mouseButton3Clicked(int x, int y) {
        clearMultiSelection();
        this.repaint();
    }

    public void mouseButton3Pressed(int x, int y) {

        if (editorState == EDITORSTATE_CONNECTING) {
            selected = null;
            if (linearLine != null ) linearLine.clear();
            this.repaint();
            return;
        }

        if (isMultiSelectAllowed) {
            rectangleStart = new Point2D.Double(x, y);
            LOG.info("{} {}/{}", localeString.getString("console_rect_start"), x, y);
        }
    }

    public void mouseButton3Released(int x, int y) {
        if (rectangleStart != null) {

            Point2D rectangleEnd = new Point2D.Double(x, y);
            LOG.info("{} {}/{}", localeString.getString("console_rect_end"), x, y);
            LOG.info("Rectangle centre = {} , {}", rectangleEnd.getX() - rectangleStart.getX(), rectangleEnd.getY() - rectangleStart.getY());

            switch (editorState) {
                case EDITORSTATE_DELETE_NODES:
                    removeAllNodesInScreenArea(rectangleStart, rectangleEnd);
                    this.repaint();
                    break;
                case EDITORSTATE_CHANGE_NODE_PRIORITY:
                    LOG.info("{}", localeString.getString("console_node_priority_toggle"));
                    changeAllNodesPriInScreenArea(rectangleStart, rectangleEnd);
                    this.repaint();
                    break;
                case EDITORSTATE_MOVING:
                    LOG.info("{}", localeString.getString("console_node_priority_toggle"));
                    getAllNodesInArea(rectangleStart, rectangleEnd);
                    this.repaint();
                    break;
                case EDITORSTATE_ALIGN_HORIZONTAL:
                    LOG.info("{}", localeString.getString("console_node_align_horizontal"));
                    getAllNodesInArea(rectangleStart, rectangleEnd);
                    this.repaint();
                    break;
                case EDITORSTATE_ALIGN_VERTICAL:
                    LOG.info("{}", localeString.getString("console_node_align_vertical"));
                    getAllNodesInArea(rectangleStart, rectangleEnd);
                    this.repaint();
                    break;
                case EDITORSTATE_CNP_SELECT:
                    getAllNodesInArea(rectangleStart, rectangleEnd);
                    this.repaint();
            }
            rectangleStart = null;
        }
    }

    public static void addToDeleteList(MapNode node) {
        LinkedList<MapNode> otherNodesInLinks = new LinkedList<>();
        LinkedList<MapNode> otherNodesOutLinks = new LinkedList<>();

        LinkedList<MapNode> roadmapNodes = roadMap.mapNodes;
        for (int i = 0; i < roadmapNodes.size(); i++) {
            MapNode mapNode = roadmapNodes.get(i);
            if (mapNode != node) {
                if (mapNode.outgoing.contains(node)) {
                    otherNodesOutLinks.add(mapNode);
                }
                if (mapNode.incoming.contains(node)) {
                    otherNodesInLinks.add(mapNode);
                }
            }

        }
        deleteNodeList.add(new NodeLinks(node, otherNodesInLinks, otherNodesOutLinks));
    }


    //
    // Dialogs for marker add/edit
    //

    private destInfo showNewMarkerDialog(int id) {

        JTextField destName = new JTextField();
        String[] group = new String[1];

        ArrayList<String> groupArray = new ArrayList<>();
        LinkedList<MapMarker> mapMarkers = roadMap.mapMarkers;
        for (MapMarker mapMarker : mapMarkers) {
            if (!mapMarker.group.equals("All")) {
                if (!groupArray.contains(mapMarker.group)) {
                    groupArray.add(mapMarker.group);
                }
            }
        }

        Collator coll = Collator.getInstance(AutoDriveEditor.locale);
        coll.setStrength(Collator.PRIMARY);
        Collections.sort(groupArray, coll);

        String[] groupString = new String[groupArray.size() + 1];
        groupString[0] = "None";
        for (int i = 0; i < groupArray.size(); i++) {
            groupString[i+1] = groupArray.get(i);
        }

        JComboBox comboBox = new JComboBox(groupString);
        comboBox.setEditable(true);
        comboBox.setSelectedIndex(0);
        comboBox.addActionListener(e -> {
            JComboBox cb = (JComboBox)e.getSource();
            group[0] = (String)cb.getSelectedItem();
        });

        Object[] inputFields = {localeString.getString("dialog_marker_select_name"), destName,
                localeString.getString("dialog_marker_add_select_group"), comboBox};

        int option = JOptionPane.showConfirmDialog(this, inputFields, ""+ localeString.getString("dialog_marker_add_title") + " ( Node ID " + id +" )", JOptionPane.OK_CANCEL_OPTION, JOptionPane.INFORMATION_MESSAGE, AutoDriveEditor.getMarkerIcon());

        if (option == JOptionPane.OK_OPTION) {

            if (group[0] == null || group[0].equals("None")) group[0] = "All";
            if (destName.getText() != null && destName.getText().length() > 0) {
                // since we can't return more than 1 string, we have to package them up
                return new destInfo(destName.getText(), group[0]);
            } else {
                LOG.info("{}", localeString.getString("console_marker_add_cancel_noname"));
                // null's are bad mmmmmkay.....
                return null;
            }
        }
        LOG.info("{}" , localeString.getString("console_marker_add_cancel"));
        return null;
    }

    private destInfo showEditMarkerDialog(int id, String markerName, String markerGroup) {

        String[] group = new String[1];
        int groupIndex = 0;


        JSeparator separator = new JSeparator(SwingConstants.HORIZONTAL);
        JLabel label1 = new JLabel("Destination Name");
        JTextField destName = new JTextField(markerName);

        ArrayList<String> groupArray = new ArrayList<>();
        LinkedList<MapMarker> mapMarkers = roadMap.mapMarkers;
        for (MapMarker mapMarker : mapMarkers) {
            if (!mapMarker.group.equals("All")) {
                if (!groupArray.contains(mapMarker.group)) {
                    groupArray.add(mapMarker.group);
                }
            }
        }

        Collator coll = Collator.getInstance(AutoDriveEditor.locale);
        coll.setStrength(Collator.PRIMARY);
        Collections.sort(groupArray, coll);


        String[] groupString = new String[groupArray.size() + 1];
        groupString[0] = "None";

        for (int i = 0; i < groupArray.size(); i++) {
            groupString[i+1] = groupArray.get(i);
            if (groupString[i+1].equals(markerGroup)) {
                groupIndex = i + 1;
            }

        }

        // edge case - set the output group to the selected one, this only
        // applies if the group isn't changed, otherwise it would return null
        group[0] = groupString[groupIndex];

        JComboBox comboBox = new JComboBox(groupString);
        comboBox.setEditable(true);
        comboBox.setSelectedIndex(groupIndex);
        comboBox.addActionListener(e -> {
            JComboBox cb = (JComboBox)e.getSource();
            group[0] = (String)cb.getSelectedItem();
        });

        Object[] inputFields = {localeString.getString("dialog_marker_select_name"), destName," ",
                localeString.getString("dialog_marker_group_change"), comboBox," ",
                separator, "<html><center><b><u>NOTE</b></u>:</center>" + localeString.getString("dialog_marker_group_empty_warning") + " ",
                " "
        };

        int option = JOptionPane.showConfirmDialog(this, inputFields, "" + localeString.getString("dialog_marker_edit_title") + " ( Node ID " + id +" )", JOptionPane.OK_CANCEL_OPTION, JOptionPane.INFORMATION_MESSAGE, AutoDriveEditor.getMarkerIcon());

        if (option == JOptionPane.OK_OPTION) {

            if (group[0] == null || group[0].equals("None")) group[0] = "All";
            if (destName.getText() != null && destName.getText().length() > 0) {
                if (markerName.equals(destName.getText()) && markerGroup.equals(group[0])) {
                    LOG.info("{}", localeString.getString("console_marker_edit_cancel_nochange"));
                    return null;
                } else {
                    // since we can't return more than 1 string, we have to package them up
                    return new destInfo(destName.getText(), group[0]);
                }
            }
        }
        LOG.info("{}", localeString.getString("console_marker_edit_cancel"));
        return null;
    }

    public static class destInfo{
        private final String name;
        private final String group;
        public destInfo(String destName, String groupName){
            name = destName;
            group = groupName;
        }
        // getter setters
        public String getName() {
            return name;
        }

        public String getGroup() {
            return group;
        }

    }

   //
   // getter and setters
   //

    public static MapPanel getMapPanel() {
        return mapPanel;
    }

    public BufferedImage getImage() {
        return image;
    }

    public void setImage(BufferedImage image) {
        this.image = image;
    }

    public RoadMap getRoadMap() {
        return roadMap;
    }

    public void setRoadMap(RoadMap roadMap) {
        MapPanel.roadMap = roadMap;
    }

    public void setMapZoomFactor(int mapZoomFactor) {
        this.mapZoomFactor = mapZoomFactor;
    }

    public void setStale(boolean stale) {
        editor.setStale(stale);
    }

    //
    ///
    //
    public static class NodeLinks {

        public MapNode node;
        public int nodeIDbackup;
        public LinkedList<MapNode> otherIncoming;
        public LinkedList<MapNode> otherOutgoing;

        public NodeLinks(MapNode mapNode, LinkedList<MapNode> in, LinkedList<MapNode> out) {
            this.node = mapNode;
            this.nodeIDbackup = mapNode.id;
            this.otherIncoming = new LinkedList<>();
            this.otherOutgoing = new LinkedList<>();

            for (int i = 0; i <= in.size() - 1 ; i++) {
                MapNode inNode = in.get(i);
                if (!this.otherIncoming.contains(inNode)) this.otherIncoming.add(inNode);
            }
            for (int i = 0; i <= out.size() - 1 ; i++) {
                MapNode outNode = out.get(i);
                if (!this.otherOutgoing.contains(outNode)) this.otherOutgoing.add(outNode);
            }
        }



    }
}
