package de.adEditor.MapHelpers;

import java.awt.event.MouseEvent;
import java.awt.event.MouseMotionListener;
import java.awt.geom.Point2D;
import java.util.LinkedList;
import de.adEditor.MapPanel;


public class LinearLine {

    public LinkedList<MapNode> lineNodeList;
    private MapNode lineStartNode;
    private int interpPointDistance = 12;

    public LinearLine(MapNode startNode, int mousex, int mousey, int nodeDistance) {

        this.lineNodeList = new LinkedList<>();
        this.lineStartNode = startNode;
        this.interpPointDistance = nodeDistance;
        getLinearInterpolationPointsForLine(this.lineStartNode, mousex, mousey);
    }

    public LinearLine(MapNode startNode, int mousex, int mousey) {
        this(startNode, mousex, mousey, 12);
    }

    // to fix - zoom in/out updates the drawn line position but not the nodes coords along the line

    private void getLinearInterpolationPointsForLine(MapNode startNode, int endx, int endy) {

        lineNodeList.clear();

        double diffx = endx - startNode.x;
        double diffy = endy - startNode.z;

        double xpow = Math.pow(diffx, 2);
        double ypow = Math.pow(diffy, 2);

        double lineLength = Math.sqrt( xpow + ypow);

        int multiplier = (int)lineLength/this.interpPointDistance;
        int id = 1;

        for(int i=0;i<=multiplier;i++) {
            Point2D.Double point = new Point2D.Double();
            point.x = startNode.x * ((double)1 - ((double)i/(double)multiplier)) + endx * ((double)i / (double)multiplier);
            point.y = startNode.z * (1 - (i/(double)multiplier)) + endy * (i / (double)multiplier);
            lineNodeList.add(new MapNode((int)id,point.getX(),point.getY(),0,MapPanel.NODE_STANDARD, false));
            id++;
        }
    }

    public void updateLine(int mouseX, int mouseY) {
        if ((this.lineStartNode != null && this.interpPointDistance >0)) {
            getLinearInterpolationPointsForLine(this.lineStartNode, mouseX, mouseY);
        }
    }

    public void clear() {
        this.lineNodeList.clear();
        this.lineStartNode = null;
    }
}
