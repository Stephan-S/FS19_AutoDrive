package de.adEditor.MapHelpers;

import de.adEditor.GUIBuilder;
import de.adEditor.MapPanel;

import java.awt.geom.Point2D;
import java.util.LinkedList;

import static de.adEditor.ADUtils.LOG;
import static de.adEditor.MapPanel.*;

public class QuadCurve{

    public LinkedList<MapNode> curveNodesList;
    private MapNode curveStartNode;
    private MapNode curveEndNode;
    private MapNode controlPoint;

    private int numInterpolationPoints;
    private int nodeType;
    private boolean isReversePath;
    private boolean isDualPath;

    public QuadCurve(MapNode startNode, MapNode endNode, int numPoints) {
        this.curveNodesList = new LinkedList<>();
        this.curveStartNode = startNode;
        this.curveEndNode = endNode;
        this.numInterpolationPoints = numPoints;
        this.controlPoint = null;
        this.isReversePath = GUIBuilder.curvePathReverse.isSelected();
        this.isDualPath = GUIBuilder.curvePathDual.isSelected();
        this.nodeType = GUIBuilder.curvePathRegular.isSelected() ? NODE_STANDARD : NODE_SUBPRIO;
        this.updateCurve();
        GUIBuilder.curvePanel.setVisible(true);

    }

    // if no interpolation number is specified, defaults to default set by the editor config
    public QuadCurve(MapNode startNode, MapNode endNode) {
        this(startNode, endNode, GUIBuilder.numIterationsSlider.getValue());
    }

     public void setNumInterpolationPoints(int points) {
        this.numInterpolationPoints = points;
        if (this.curveStartNode != null && this.curveEndNode !=null) {
            getInterpolationPointsForCurve(this.curveStartNode,this.curveEndNode);
        }

    }

    private void getInterpolationPointsForCurve (MapNode startNode, MapNode endNode) {

        if ((startNode == null || endNode == null || this.numInterpolationPoints < 1 )) return;

        if (this.controlPoint == null) {
            this.controlPoint = new MapNode(0,startNode.x,0,endNode.z, MapPanel.NODE_CONTROLPOINT, false);
        }
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
            Point2D.Double point = pointsForQuadraticBezier(startNode, endNode, this.controlPoint.x, this.controlPoint.z, i);
            curveNodesList.add(new MapNode(id,point.getX(),-1,point.getY(),MapPanel.NODE_STANDARD, false));
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

    // Untested
    private Point2D.Double pointsForCubicBezier(MapNode startNode, MapNode endNode, double pointer1x, double pointer1y, double pointer2x, double pointer2y, double precision) {
        Point2D.Double point = new Point2D.Double();
        double abs = Math.abs(Math.pow((1 - precision), 3));
        point.x = abs * startNode.x + 3 * Math.pow((1 - precision), 2) * precision * pointer1x + 3 * Math.abs((1 - precision)) * Math.pow(precision, 2) * pointer2x + Math.abs(Math.pow(precision, 3)) * endNode.x;
        point.y = abs * startNode.z + 3 * Math.pow((1 - precision), 2) * precision * pointer1y + 3 * Math.abs((1 - precision)) * Math.pow(precision, 2) * pointer2y + Math.abs(Math.pow(precision, 3)) * endNode.z;
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
            MapNode newNode = new MapNode(roadMap.mapNodes.size() + 1, tempNode.x, -1, tempNode.z, this.nodeType, false);
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
        this.numInterpolationPoints = 10;
        GUIBuilder.curvePanel.setVisible(false);
    }

    public Boolean isCurveValid() {
        return this.curveNodesList != null && this.controlPoint !=null && this.curveNodesList.size() > 2;
    }

    public void updateControlPoint(MapNode controlPoint) {
        this.controlPoint = controlPoint;
        this.updateCurve();
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

    public MapNode getControlPoint() { return this.controlPoint; }

    public boolean isReversePath() { return isReversePath; }

    public boolean isDualPath() { return isDualPath; }

    // setters

    public void setReversePath(boolean isSelected) {
        this.isReversePath = isSelected;
    }

    public void setDualPath(boolean isSelected) {
        this.isDualPath = isSelected;
    }

    public void setNodeType(int nodeType) { this.nodeType = nodeType; }

    public void setCurveStartNode(MapNode curveStartNode) {
        this.curveStartNode = curveStartNode;
        this.updateCurve();
    }

    public void setCurveEndNode(MapNode curveEndNode) {
        this.curveEndNode = curveEndNode;
        this.updateCurve();
    }










}
