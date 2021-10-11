package de.adEditor.MapHelpers;

import de.adEditor.ADUtils;
import de.adEditor.AutoDriveEditor;
import de.adEditor.MapPanel;
import java.awt.geom.Point2D;
import java.util.LinkedList;

import static de.adEditor.ADUtils.LOG;
import static de.adEditor.MapPanel.*;

public class QuadCurve{

    public LinkedList<MapNode> curveNodesList;
    private MapNode curveStartNode = null;
    private MapNode curveEndNode = null;
    private MapNode controlPoint;

    private int numInterpPoints = 1;
    private int nodeType=0;
    private boolean isReversePath = false;
    private boolean isDualPath = false;

    public QuadCurve(MapNode startNode, MapNode endNode, int numPoints) {
        this.curveNodesList = new LinkedList<>();
        this.curveStartNode = startNode;
        this.curveEndNode = endNode;
        this.numInterpPoints = numPoints;
        this.controlPoint = null;
        this.isReversePath = AutoDriveEditor.curvePathReverse.isSelected();
        this.isDualPath = AutoDriveEditor.curvePathDual.isSelected();
        this.nodeType = AutoDriveEditor.curvePathRegular.isSelected() ? NODE_STANDARD : NODE_SUBPRIO;
        this.updateCurve();
        AutoDriveEditor.curvePanel.setVisible(true);

    }

    // if no interpolation number is specified, default to 10 points
    public QuadCurve(MapNode startNode, MapNode endNode) {
        this(startNode, endNode, 10);
    }

     public void setNumInterpolationPoints(int points) {
        this.numInterpPoints = points;
        if (this.curveStartNode != null && this.curveEndNode !=null) {
            getInterpolationPointsForCurve(this.curveStartNode,this.curveEndNode);
        }

    }

    private void getInterpolationPointsForCurve (MapNode startNode, MapNode endNode) {

        if ((startNode == null || endNode == null || this.numInterpPoints < 1 )) return;

        if (this.controlPoint == null) {
            this.controlPoint = new MapNode(0,startNode.x,0,endNode.z, MapPanel.NODE_CONTROLPOINT, false);
        }
        double step = 1/(double)this.numInterpPoints;
        curveNodesList.clear();

        // first we add the starting node
        curveNodesList.add(curveStartNode);

        // now we calculate all the points in-between the start and end nodes
        // i=step makes sure we skip the first node to calculate as it's the curveStartNode
        //
        // i+step<1.0001 means we compare one node ahead so we don't calculate the end node (as it's curveEndNode)
        // rounding errors mean we can't compare i+step<1 as the last node would make i = 1.0000000000004 - 1.00000000000010
        // and we would be one node missing due to the comparison being fulfilled.

        int id = 0;
        for(double i=step;i+step<1.0001;i += step) {
            Point2D.Double point = pointsForQuadraticBezier(startNode, endNode, this.controlPoint.x, this.controlPoint.z, i);
            curveNodesList.add(new MapNode((int)id,point.getX(),-1,point.getY(),MapPanel.NODE_STANDARD, false));
            if (i+step >=1.0001 ) LOG.info("WARNING -- last node was not calculated, this should not happen!! -- step = {} ,  ", i+step);
            id++;
        }
        //add the end node to complete the curve
        curveNodesList.add(curveEndNode);
    }

    private Point2D.Double pointsForQuadraticBezier(MapNode startNode, MapNode endNode, double pointerx, double pointery, double precision) {
        Point2D.Double point = new Point2D.Double();
        point.x = Math.abs(Math.pow((1 - precision), 2)) * startNode.x + (double)2 * ((double)1 - precision) * precision * pointerx + Math.pow(precision, 2) * endNode.x;
        //point.x = ((double)1 - precision) * ((double)1 - precision) * startNode.x + ((double)2 - ((double)2 * precision)) * precision * pointerx + precision * precision * endNode.x;
        point.y = Math.abs(Math.pow((1 - precision), 2)) * startNode.z + (double)2 * ((double)1 - precision) * precision * pointery + Math.pow(precision, 2) * endNode.z;
        //point.y = ((double)1 - precision) * ((double)1 - precision) * startNode.z + ((double)2 - ((double)2 * precision)) * precision * pointery + precision * precision * endNode.z;

        return point;
    }

    // Untested
    private Point2D.Double pointsForCubicBezier(MapNode startNode, MapNode endNode, double pointer1x, double pointer1y, double pointer2x, double pointer2y, double precision) {
        Point2D.Double point = new Point2D.Double();
        point.x = Math.abs(Math.pow((1 - precision), 3)) * startNode.x + 3 * Math.pow((1 - precision), 2) * precision * pointer1x + 3 * Math.abs((1 - precision)) * Math.pow(precision, 2) * pointer2x + Math.abs(Math.pow(precision, 3)) * endNode.x;
        point.y = Math.abs(Math.pow((1 - precision), 3)) * startNode.z + 3 * Math.pow((1 - precision), 2) * precision * pointer1y + 3 * Math.abs((1 - precision)) * Math.pow(precision, 2) * pointer2y + Math.abs(Math.pow(precision, 3)) * endNode.z;
        return point;
    }

    public void updateCurve() {
        if ((this.curveStartNode != null && this.curveEndNode !=null && this.numInterpPoints >= 1)) {
            getInterpolationPointsForCurve(this.curveStartNode,this.curveEndNode);
        }
    }

    public void commitCurve(int pathType) {

        LinkedList<MapNode> mergeNodesList  = new LinkedList<>();
        MapNode newNode, lastNode;

        mergeNodesList.add(curveStartNode);

        for (int j = 1; j < curveNodesList.size() - 1; j++) {
            MapNode tempNode = curveNodesList.get(j);
            newNode = new MapNode(roadMap.mapNodes.size() + 1, tempNode.x, -1, tempNode.z, this.nodeType, false);
            roadMap.mapNodes.add(newNode);
            mergeNodesList.add(newNode);
        }

        mergeNodesList.add(curveEndNode);

        for (int j = 0; j < mergeNodesList.size() - 1; j++) {
            MapNode startNode = mergeNodesList.get(j);
            MapNode endNode = mergeNodesList.get(j+1);
            if (isReversePath) {
                MapPanel.createConnectionBetween(startNode,endNode,CONNECTION_REVERSE);
            } else if (isDualPath) {
                MapPanel.createConnectionBetween(startNode,endNode,CONNECTION_DUAL);
            } else {
                MapPanel.createConnectionBetween(startNode,endNode,CONNECTION_STANDARD);
            }
        }

        LOG.info("Curve created {} nodes", mergeNodesList.size() - 2 );
    }

    public void clear() {
        this.curveNodesList.clear();
        this.controlPoint = null;
        this.curveStartNode = null;
        this.curveEndNode = null;
        this.numInterpPoints = 10;
        AutoDriveEditor.curvePanel.setVisible(false);
    }

    public Boolean isCurveCreated() {
        return this.curveNodesList != null && this.curveNodesList.size() > 0;
    }

    // getters and setters

    public LinkedList<MapNode> getCurveNodes() {
        return this.curveNodesList;
    }

    public MapNode getCurveStartNode() {
        return this.curveStartNode;
    }

    public void setCurveStartNode(MapNode curveStartNode) {
        this.curveStartNode = curveStartNode;
        this.updateCurve();
    }

    public MapNode getCurveEndNode() {
        return this.curveEndNode;
    }

    public void setCurveEndNode(MapNode curveEndNode) {
        this.curveEndNode = curveEndNode;
        this.updateCurve();
    }

    public int getNumInterpolationPoints() {
        return this.numInterpPoints;
    }

    public MapNode getControlPoint() {
        return this.controlPoint;
    }

    public void updateControlPoint(MapNode controlPoint) {
        this.controlPoint = controlPoint;
        this.updateCurve();
    }

    public void setNodeType(int nodeType) {
        this.nodeType = nodeType;
    }

    public void setReversePath(boolean isSelected) {
        this.isReversePath = isSelected;
    }

    public void setDualPath(boolean isSelected) {
        this.isDualPath = isSelected;
    }

}
