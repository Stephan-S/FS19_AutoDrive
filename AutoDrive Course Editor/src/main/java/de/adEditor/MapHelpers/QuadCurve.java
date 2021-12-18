package de.adEditor.MapHelpers;

import java.awt.geom.Point2D;
import java.util.LinkedList;

import de.adEditor.GUIBuilder;
import de.adEditor.MapPanel;
import static de.adEditor.ADUtils.LOG;
import static de.adEditor.AutoDriveEditor.*;
import static de.adEditor.MapPanel.*;

public class QuadCurve{

    public LinkedList<MapNode> curveNodesList;
    private MapNode curveStartNode;
    private MapNode curveEndNode;
    private MapNode controlPoint1;
    private Point2D.Double virtualControlPoint1;
    private double movementScaler = 1;

    private int numInterpolationPoints;
    private int nodeType;
    private boolean isReversePath;
    private boolean isDualPath;


    public QuadCurve(MapNode startNode, MapNode endNode) {
        this.curveNodesList = new LinkedList<>();
        this.curveStartNode = startNode;
        this.curveEndNode = endNode;
        this.numInterpolationPoints = GUIBuilder.numIterationsSlider.getValue();
        if (this.numInterpolationPoints < 2 ) this.numInterpolationPoints = 2 ;
        this.controlPoint1 = new MapNode(0,startNode.x,0,endNode.z, MapPanel.NODE_CONTROLPOINT, false, true);
        this.virtualControlPoint1 = new Point2D.Double(controlPoint1.x,controlPoint1.z);
        this.isReversePath = GUIBuilder.curvePathReverse.isSelected();
        this.isDualPath = GUIBuilder.curvePathDual.isSelected();
        this.nodeType = GUIBuilder.curvePathRegular.isSelected() ? NODE_STANDARD : NODE_SUBPRIO;
        this.movementScaler = controlPointMoveScaler;
        this.updateCurve();
        GUIBuilder.curvePanel.setVisible(true);
    }

    public void setNumInterpolationPoints(int points) {
        this.numInterpolationPoints = points;
        if (this.curveStartNode != null && this.curveEndNode !=null) {
            getInterpolationPointsForCurve(this.curveStartNode,this.curveEndNode);
        }
    }

    private void getInterpolationPointsForCurve (MapNode startNode, MapNode endNode) {

        if ((startNode == null || endNode == null || this.numInterpolationPoints < 1 )) return;

        double step = 1/(double)this.numInterpolationPoints;
        curveNodesList.clear();

        // first we add the starting node
        curveNodesList.add(curveStartNode);

        // now we calculate all the points in-between the start and end nodes
        // i=step makes sure we skip the first node to calculate as it's the curveStartNode
        //
        // i+step<1.0001 means we compare one node ahead, we don't calculate the end node (as it's curveEndNode)
        // rounding errors mean we can't compare i+step<1 as the last node would make i = 1.0000000000004 - 1.00000000000010
        // we would be one node missing due to the comparison being fulfilled.

        int id = 0;
        for(double i=step;i+step<1.0001;i += step) {
            Point2D.Double point = pointsForQuadraticBezier(startNode, endNode, this.virtualControlPoint1.x, this.virtualControlPoint1.y, i);
            curveNodesList.add(new MapNode(id,point.getX(),-1,point.getY(),MapPanel.NODE_STANDARD, false, false));
            if (i+step >=1.0001 ) LOG.info("WARNING -- last node was not calculated, this should not happen!! -- step = {} ,  ", i+step);
            id++;
        }
        //add the end node to complete the curve
        curveNodesList.add(curveEndNode);
    }

    private Point2D.Double pointsForQuadraticBezier(MapNode startNode, MapNode endNode, double pointerX, double pointerY, double precision) {
        Point2D.Double point = new Point2D.Double();
        double abs = Math.abs(Math.pow((1 - precision), 2));
        point.x = abs * startNode.x + (double)2 * ((double)1 - precision) * precision * pointerX + Math.pow(precision, 2) * endNode.x;
        point.y = abs * startNode.z + (double)2 * ((double)1 - precision) * precision * pointerY + Math.pow(precision, 2) * endNode.z;
        return point;
    }

    public void updateCurve() {
        if ((this.curveStartNode != null && this.curveEndNode !=null && this.numInterpolationPoints >= 1)) {
            getInterpolationPointsForCurve(this.curveStartNode,this.curveEndNode);
        }
    }

    public void commitCurve() {
        LinkedList<MapNode> mergeNodesList  = new LinkedList<>();

        mergeNodesList.add(curveStartNode);

        for (int j = 1; j < curveNodesList.size() - 1; j++) {
            MapNode tempNode = curveNodesList.get(j);
            MapNode newNode = new MapNode(roadMap.mapNodes.size() + 1, tempNode.x, -1, tempNode.z, this.nodeType, false, false);
            roadMap.mapNodes.add(newNode);
            mergeNodesList.add(newNode);
        }

        mergeNodesList.add(curveEndNode);
        changeManager.addChangeable( new ChangeManager.QuadCurveChanger(mergeNodesList, isReversePath, isDualPath));
        connectNodes(mergeNodesList, isReversePath, isDualPath);

        if (DEBUG) LOG.info("QuadCurve created {} nodes", mergeNodesList.size() - 2 );
    }

    public static void connectNodes(LinkedList<MapNode> mergeNodesList, boolean reversePath, boolean dualPath)  {
        for (int j = 0; j < mergeNodesList.size() - 1; j++) {
            MapNode startNode = mergeNodesList.get(j);
            MapNode endNode = mergeNodesList.get(j+1);
            if (reversePath) {
                MapPanel.createConnectionBetween(startNode,endNode,CONNECTION_REVERSE);
            } else if (dualPath) {
                MapPanel.createConnectionBetween(startNode,endNode,CONNECTION_DUAL);
            } else {
                MapPanel.createConnectionBetween(startNode,endNode,CONNECTION_STANDARD);
            }
        }
    }

    public void clear() {
        this.curveNodesList.clear();
        this.controlPoint1 = null;
        this.curveStartNode = null;
        this.curveEndNode = null;
        if (cubicCurve == null) GUIBuilder.curvePanel.setVisible(false);
        //GUIBuilder.curvePanel.setVisible(false);
    }

    public Boolean isCurveValid() {
        return this.curveNodesList != null && this.controlPoint1 !=null && this.curveNodesList.size() > 2;
    }

    public void updateControlPoint(double diffX, double diffY) {
        if (editorState == GUIBuilder.EDITORSTATE_QUADRATICBEZIER) {
            this.virtualControlPoint1.x += diffX * movementScaler;
            this.virtualControlPoint1.y += diffY * movementScaler;
        } else {
            this.virtualControlPoint1.x += diffX;
            this.virtualControlPoint1.y += diffY;
        }
        this.updateCurve();
    }

    public boolean isReversePath() { return isReversePath; }

    public boolean isDualPath() { return isDualPath; }

    public Boolean isControlNode(MapNode node) {
        return node == this.controlPoint1;
    }

    // getters

    public int getNodeType() { return this.nodeType; }

    public int getNumInterpolationPoints() { return this.numInterpolationPoints; }

    public LinkedList<MapNode> getCurveNodes() {
        return this.curveNodesList;
    }

    public MapNode getCurveStartNode() {
        return this.curveStartNode;
    }

    public MapNode getCurveEndNode() { return this.curveEndNode; }

    public MapNode getControlPoint() { return this.controlPoint1; }



    // setters

    public void setReversePath(boolean isSelected) {
        this.isReversePath = isSelected;
    }

    public void setDualPath(boolean isSelected) {
        this.isDualPath = isSelected;
    }

    public void setNodeType(int nodeType) {
        this.nodeType = nodeType;
        if (nodeType == NODE_SUBPRIO) {
            for (int j = 1; j < curveNodesList.size() - 1; j++) {
                MapNode tempNode = curveNodesList.get(j);
                tempNode.flag = 1;
            }
        }  else {
            for (int j = 1; j < curveNodesList.size() - 1; j++) {
                MapNode tempNode = curveNodesList.get(j);
                tempNode.flag = 0;
            }
        }
    }

    public void setCurveStartNode(MapNode curveStartNode) {
        this.curveStartNode = curveStartNode;
        this.updateCurve();
    }

    public void setCurveEndNode(MapNode curveEndNode) {
        this.curveEndNode = curveEndNode;
        this.updateCurve();
    }
}
