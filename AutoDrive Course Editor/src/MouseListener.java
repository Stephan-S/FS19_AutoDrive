import javax.swing.*;
import java.awt.event.MouseEvent;
import java.awt.event.MouseMotionListener;
import java.awt.event.MouseWheelEvent;
import java.awt.event.MouseWheelListener;
import java.awt.geom.Point2D;
import java.awt.geom.Rectangle2D;
import java.util.Map;

public class MouseListener implements java.awt.event.MouseListener, MouseMotionListener, MouseWheelListener {
    MapPanel mapPanel;
    boolean isDragging = false;
    boolean isDraggingNode = false;
    double lastX = 0;
    double lastY = 0;
    MapNode movingNode = null;
    double mousePosX = 0;
    double mousePosY = 0;
    public Point2D rectangleStart, rectangleEnd;

    public MouseListener(MapPanel mapPanel) {
        this.mapPanel = mapPanel;
    }

    @Override
    public void mouseClicked(MouseEvent e) {
        if (e.getButton() == MouseEvent.BUTTON1) {
            if (this.mapPanel.editor.editorState == AutoDriveEditor.EDITORSTATE_CONNECTING) {
                movingNode = mapPanel.getNodeAt(e.getX(), e.getY());
                if (movingNode != null) {
                    if (this.mapPanel.editor.selected == null) {
                        this.mapPanel.editor.selected = movingNode;
                        this.mapPanel.repaint();
                    } else {
                        mapPanel.createConnectionBetween(this.mapPanel.editor.selected, movingNode);
                        this.mapPanel.editor.selected = null;
                        this.mapPanel.repaint();
                    }
                }
            }
            if (this.mapPanel.editor.editorState == AutoDriveEditor.EDITORSTATE_CREATING) {
                Point2D worldPos = mapPanel.screenPosToWorldPos((int)e.getX(),(int)e.getY());
                this.mapPanel.createNode((int)worldPos.getX(), (int)worldPos.getY());
            }
            if (this.mapPanel.editor.editorState == AutoDriveEditor.EDITORSTATE_CREATING_DESTINATION) {
                movingNode = mapPanel.getNodeAt(e.getX(), e.getY());
                if (movingNode != null) {
                    String destinationName = JOptionPane.showInputDialog("New destination name:", "" + movingNode.id );
                    if (destinationName != null) {
                        mapPanel.createDestinationAt(movingNode, destinationName);
                        this.mapPanel.repaint();
                    }
                }
            }

        }
    }

    @Override
    public void mousePressed(MouseEvent e) {
        if (e.getButton() == MouseEvent.BUTTON1) {
            isDragging = true;
            lastX = e.getX();
            lastY = e.getY();
            movingNode = mapPanel.getNodeAt(e.getX(), e.getY());
            if (movingNode != null) {
                isDragging = false;
                if (this.mapPanel.editor.editorState == AutoDriveEditor.EDITORSTATE_MOVING) {
                    isDraggingNode = true;
                }
                if (this.mapPanel.editor.editorState == AutoDriveEditor.EDITORSTATE_DELETING) {
                    this.mapPanel.removeNode(movingNode);
                }
                if (this.mapPanel.editor.editorState == AutoDriveEditor.EDITORSTATE_DELETING_DESTINATION) {
                    this.mapPanel.removeDestination(movingNode);
                }
            }
        }
        if (e.getButton() == MouseEvent.BUTTON3) {
            System.out.println("Rectangle start set at " + e.getX() + "/" + e.getY());
            rectangleStart = new Point2D.Double(e.getX(), e.getY());
        }
    }

    @Override
    public void mouseReleased(MouseEvent e) {
        if (e.getButton() == MouseEvent.BUTTON1) {
            isDragging = false;
            isDraggingNode = false;
        }
        if (e.getButton() == MouseEvent.BUTTON3) {
            rectangleEnd = new Point2D.Double(e.getX(), e.getY());
            System.out.println("Rectangle end set at " + e.getX() + "/" + e.getY());
            if (rectangleStart != null) {
                if (this.mapPanel.editor.editorState == AutoDriveEditor.EDITORSTATE_DELETING) {

                    System.out.println("Removing all nodes in area");
                    this.mapPanel.removeAllNodesInScreenArea(rectangleStart, rectangleEnd);
                    this.mapPanel.repaint();
                }
            }
            rectangleStart = null;
        }
    }

    @Override
    public void mouseEntered(MouseEvent e) {

    }

    @Override
    public void mouseExited(MouseEvent e) {

    }

    @Override
    public void mouseDragged(MouseEvent e) {
        mousePosX = e.getX();
        mousePosY = e.getY();
        if (isDragging) {
            double diffX = e.getX() - lastX;
            double diffY = e.getY() - lastY;
            this.lastX = e.getX();
            this.lastY = e.getY();
            mapPanel.moveMapBy(diffX, diffY);
        }
        else {
            if (isDraggingNode) {
                double diffX = e.getX() - lastX;
                double diffY = e.getY() - lastY;
                this.lastX = e.getX();
                this.lastY = e.getY();
                mapPanel.moveNodeBy(this.movingNode, diffX, diffY);
            }
        }
        if (this.mapPanel.editor.editorState == AutoDriveEditor.EDITORSTATE_DELETING && this.rectangleStart != null) {
            this.mapPanel.repaint();
        }
    }

    @Override
    public void mouseMoved(MouseEvent e) {
        mousePosX = e.getX();
        mousePosY = e.getY();
        if (mapPanel.editor.editorState == AutoDriveEditor.EDITORSTATE_CONNECTING && mapPanel.editor.selected != null) {
            mapPanel.repaint();
        }
        movingNode = mapPanel.getNodeAt(e.getX(), e.getY());
        if (movingNode != mapPanel.hoveredNode) {
            mapPanel.hoveredNode = movingNode;
            mapPanel.repaint();
        }
    }

    @Override
    public void mouseWheelMoved(MouseWheelEvent e) {
        mapPanel.increaseZoomLevelBy(e.getWheelRotation()* (mapPanel.zoomLevel * 0.1));
    }
}
