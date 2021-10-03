package de.adEditor.MapHelpers;

import de.adEditor.AutoDriveEditor;
import de.adEditor.MapPanel;
import java.awt.geom.Point2D;
import java.util.LinkedList;

public class QuadCurve{

    public LinkedList<MapNode> curveNodesList;
    private MapNode curveStartNode = null;
    private MapNode curveEndNode = null;
    private int numInterpPoints = 1;
    private MapNode controlPoint;


    public QuadCurve(MapNode startNode, MapNode endNode, int numPoints) {
        this.curveNodesList = new LinkedList<>();
        this.curveStartNode = startNode;
        this.curveEndNode = endNode;
        this.numInterpPoints = numPoints;
        this.controlPoint = null;
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

        // clunky fix for precision of the for(.. loop, cannot use i<=1 as a comparison due to the rounding up of fractions
        // the last node would be outside the comparison range (1.0) by a tiny amount ( and i mean tiny :/ )
        // e.g. it would not calculate the last node as it would be just above 1
        // ( e.g. ranging between 1.0000000000000001 to 1.0000000000000028 for upto 100 steps )
        // i<=1.00001 fixes that and doesn't allow more nodes to calculate than needed...

        int id = 1;

        for(double i=0;i<=1.00001;i += step) {
            Point2D.Double point = pointsForQuadraticBezier(startNode, endNode, this.controlPoint.x, this.controlPoint.z, i);
            curveNodesList.add(new MapNode((int)id,point.getX(),point.getY(),0,MapPanel.NODE_STANDARD, false));
            id++;
        }
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
}
