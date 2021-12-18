package de.adEditor.MapHelpers;

import java.awt.geom.Point2D;
import java.util.LinkedList;

import de.adEditor.AutoDriveEditor;
import de.adEditor.MapPanel;

import static de.adEditor.ADUtils.LOG;
import static de.adEditor.AutoDriveEditor.DEBUG;
import static de.adEditor.AutoDriveEditor.changeManager;
import static de.adEditor.MapPanel.*;

public class LinearLine {

    public LinkedList<MapNode> lineNodeList;
    private MapNode lineStartNode;
    private int interpolationPointDistance;

    public LinearLine(MapNode startNode, double mousex, double mousey, int nodeDistance) {
        this.lineNodeList = new LinkedList<>();
        this.lineStartNode = startNode;
        this.interpolationPointDistance = nodeDistance;
        getLinearInterpolationPointsForLine(this.lineStartNode, mousex, mousey);
    }

    public LinearLine(MapNode startNode, double mouseX, double mouseY) {this(startNode, mouseX, mouseY, AutoDriveEditor.linearLineNodeDistance);}

    // to fix - zoom in/out updates the drawn line position but not the nodes coordinates along the line

    private void getLinearInterpolationPointsForLine(MapNode startNode, double endX, double endY) {

        lineNodeList.clear();

        double diffX = endX - startNode.x;
        double diffY = endY - startNode.z;

        double powX = Math.pow(diffX, 2);
        double powY = Math.pow(diffY, 2);

        double lineLength = Math.sqrt( powX + powY);

        int multiplier = (int)lineLength/this.interpolationPointDistance;
        int id = 1;

        for(int i=0;i<=multiplier;i++) {
            Point2D.Double point = new Point2D.Double();
            point.x = startNode.x * ((double)1 - ((double)i/(double)multiplier)) + endX * ((double)i / (double)multiplier);
            point.y = startNode.z * (1 - (i/(double)multiplier)) + endY * (i / (double)multiplier);
            lineNodeList.add(new MapNode(id,point.getX(),point.getY(),0,MapPanel.NODE_STANDARD, false, false));
            id++;
        }
    }

    public void updateLine(double mouseX, double mouseY) {
        if ((this.lineStartNode != null && this.interpolationPointDistance >0)) {
            getLinearInterpolationPointsForLine(this.lineStartNode, mouseX, mouseY);
        }
    }

    public void clear() {
        this.lineNodeList.clear();
        this.lineStartNode = null;
    }

    public void commit(MapNode lineEndNode, int connectionType, int nodeType) {
        LinkedList<MapNode> mergeNodesList  = new LinkedList<>();

        if (DEBUG) LOG.info("LinearLine size = {}",this.lineNodeList.size());
        mergeNodesList.add(lineStartNode);

        for (int j = 1; j < this.lineNodeList.size() - 1; j++) {
            MapNode tempNode = this.lineNodeList.get(j);
            MapNode newNode = new MapNode(roadMap.mapNodes.size() + 1, tempNode.x, -1, tempNode.y, nodeType, false, false);
            roadMap.mapNodes.add(newNode);
            mergeNodesList.add(newNode);
        }

        mergeNodesList.add(lineEndNode);
        if (DEBUG) LOG.info("mergeNodesList size = {}",mergeNodesList.size());
        changeManager.addChangeable( new ChangeManager.LinearLineChanger(this.lineStartNode, lineEndNode, mergeNodesList, connectionType));
        connectNodes(mergeNodesList, connectionType);


    }

    public static void connectNodes(LinkedList<MapNode> mergeNodesList, int connectionType)  {
        for (int j = 0; j < mergeNodesList.size() - 1; j++) {
            MapNode startNode = mergeNodesList.get(j);
            MapNode endNode = mergeNodesList.get(j+1);
            MapPanel.createConnectionBetween(startNode,endNode,connectionType);
        }
    }

    public boolean isLineCreated() {
        return this.lineNodeList.size() >0;
    }

    // getters and setters

    public MapNode getLineStartNode() {
        return this.lineStartNode;
    }

    public int getInterpolationPointDistance() { return this.interpolationPointDistance; }

    public void setInterpolationDistance(int distance) {
        this.interpolationPointDistance = distance;
    }
}
