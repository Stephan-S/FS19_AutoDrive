package de.adEditor;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import javax.swing.*;
import java.awt.*;
import java.awt.event.ComponentAdapter;
import java.awt.event.ComponentEvent;
import java.awt.geom.Point2D;
import java.awt.geom.Rectangle2D;
import java.awt.image.BufferedImage;
import java.util.LinkedList;

public class MapPanel extends JPanel{

    private static Logger LOG = LoggerFactory.getLogger(MapPanel.class);

    private BufferedImage image;
    private BufferedImage resizedImage;

    private double x = 0.5;
    private double y = 0.5;
    private double zoomLevel = 1.0;
    private double lastZoomLevel = 0;
    private int mapZoomFactor = 1;
    private double nodeSize = 1;
    private AutoDriveEditor editor;

    private RoadMap roadMap;
    private MapNode hoveredNode = null;
    private MapNode movingNode = null;
    private MapNode selected = null;

    private int mousePosX = 0;
    private int mousePosY = 0;

    private boolean isDragging = false;
    private boolean isDraggingNode = false;
    private int lastX = 0;
    private int lastY = 0;
    private Point2D rectangleStart;

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

            if (lastZoomLevel != zoomLevel) {
                resizeMap();
            }

            g.clipRect(0, 0, this.getWidth(), this.getHeight());

            g.drawImage(resizedImage, 0, 0, this); // see javadoc for more info on the parameters

            if (this.roadMap != null) {
                for (MapNode mapNode : this.roadMap.mapNodes) {
                    g.setColor(Color.BLUE);
                    if (mapNode == selected) {
                        g.setColor(Color.PINK);
                    }
                    Point2D nodePos = worldPosToScreenPos(mapNode.x + 1024, mapNode.z + 1024);
                    g.fillArc((int) (nodePos.getX() - ((nodeSize * zoomLevel) * 0.5)), (int) (nodePos.getY() - ((nodeSize * zoomLevel) * 0.5)), (int) (nodeSize * zoomLevel), (int) (nodeSize * zoomLevel), 0, 360);
                    for (MapNode outgoing : mapNode.outgoing) {
                        g.setColor(Color.GREEN);
                        boolean dual = RoadMap.isDual(mapNode, outgoing);
                        if (dual) {
                            g.setColor(Color.RED);
                        }
                        Point2D outPos = worldPosToScreenPos(outgoing.x + 1024, outgoing.z + 1024);
                        drawArrowBetween(g, nodePos, outPos, dual);
                    }
                }

                for (MapMarker mapMarker : this.roadMap.mapMarkers) {
                    g.setColor(Color.BLUE);
                    Point2D nodePos = worldPosToScreenPos(mapMarker.mapNode.x + 1024 + 3, mapMarker.mapNode.z + 1024);
                    g.drawString(mapMarker.name, (int) (nodePos.getX()), (int) (nodePos.getY()));
                }

                if (selected != null && editor.editorState == AutoDriveEditor.EDITORSTATE_CONNECTING) {
                    Point2D nodePos = worldPosToScreenPos(selected.x + 1024, selected.z + 1024);
                    g.setColor(Color.WHITE);
                    g.drawLine((int) (nodePos.getX()), (int) (nodePos.getY()), mousePosX, mousePosY);
                }

                if (hoveredNode != null) {
                    g.setColor(Color.WHITE);
                    Point2D nodePos = worldPosToScreenPos(hoveredNode.x + 1024, hoveredNode.z + 1024);
                    g.fillArc((int) (nodePos.getX() - ((nodeSize * zoomLevel) * 0.5)), (int) (nodePos.getY() - ((nodeSize * zoomLevel) * 0.5)), (int) (nodeSize * zoomLevel), (int) (nodeSize * zoomLevel), 0, 360);
                    for (MapMarker mapMarker : this.roadMap.mapMarkers) {
                        if (hoveredNode.id == mapMarker.mapNode.id) {
                            Point2D nodePosMarker = worldPosToScreenPos(mapMarker.mapNode.x + 1024 + 3, mapMarker.mapNode.z + 1024);
                            g.drawString(mapMarker.name, (int) (nodePosMarker.getX()), (int) (nodePosMarker.getY()));
                        }
                    }
                }

                if (rectangleStart != null) {
                    g.setColor(Color.WHITE);
                    int width = (int) (mousePosX - rectangleStart.getX());
                    int height = (int) (mousePosY - rectangleStart.getY());
                    int x = Double.valueOf(rectangleStart.getX()).intValue();
                    int y = Double.valueOf(rectangleStart.getY()).intValue();
                    if (width < 0) {
                        x += width;
                        width = -width;
                    }
                    if (height < 0) {
                        y += height;
                        height = -height;
                    }
                    g.drawRect(x, y, width, height);
                }
            }
        }
    }

    private void resizeMap() {
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
            Graphics2D g2 = resizedImage.createGraphics();
            g2.drawImage(croppedImage, 0, 0, this.getWidth(), this.getHeight(), null);
            g2.dispose();

            lastZoomLevel = zoomLevel;
        }
    }

    public void moveMapBy(int diffX, int diffY) {
        if (this.roadMap == null || this.image == null) {
            return;
        }
        x -= diffX / (zoomLevel * image.getWidth());
        y -= diffY / (zoomLevel * image.getHeight());

        resizeMap();
        this.repaint();
    }

    public void increaseZoomLevelBy(int rotations) {
        double step = rotations * (zoomLevel * 0.1);
        if (this.roadMap == null || this.image == null) {
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
        editor.setStale(true);
        repaint();
    }

    public MapNode getNodeAt(double posX, double posY) {
        if (this.roadMap != null && this.image != null) {
            for (MapNode mapNode : this.roadMap.mapNodes) {
                double currentNodeSize = nodeSize * zoomLevel * 0.5;

                Point2D outPos = worldPosToScreenPos(mapNode.x + 1024, mapNode.z + 1024);

                if (posX < outPos.getX() + currentNodeSize && posX > outPos.getX() - currentNodeSize && posY < outPos.getY() + currentNodeSize && posY > outPos.getY() - currentNodeSize) {
                    return mapNode;
                }
            }
        }
        return null;
    }

    public void removeNode(MapNode toDelete) {
        this.roadMap.removeMapNode(toDelete);
        editor.setStale(true);
        this.repaint();
    }

    public void removeDestination(MapNode toDelete) {
        MapMarker destinationToDelete = null;
        for (MapMarker mapMarker : this.roadMap.mapMarkers) {
            if (mapMarker.mapNode.id == toDelete.id) {
                destinationToDelete = mapMarker;
            }
        }
        if (destinationToDelete != null) {
            this.roadMap.removeMapMarker(destinationToDelete);
            editor.setStale(true);
            this.repaint();
        }
    }

    public void createNode(int screenX, int screenY) {
        if (this.roadMap == null || this.image == null) {
            return;
        }
        LOG.info("createNode: {}, {}", screenX, screenY);
        MapNode mapNode = new MapNode(this.roadMap.mapNodes.size()+1, screenX, -1, screenY);

        this.roadMap.mapNodes.add(mapNode);
        editor.setStale(true);
        this.repaint();
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

        LOG.info("topLeftX: {}, diffScaledX: {}", topLeftX, diffScaledX);
        LOG.info("topLeftY: {}, diffScaledY: {}", topLeftY, diffScaledY);
        double worldPosX = ((topLeftX + diffScaledX) * mapZoomFactor) - 1024;
        double worldPosY = ((topLeftY + diffScaledY) * mapZoomFactor) - 1024;

        return new Point2D.Double(worldPosX, worldPosY);
    }

    public Point2D worldPosToScreenPos(double worldX, double worldY) {
        double scaledX = (worldX/mapZoomFactor) * zoomLevel;
        double scaledY = (worldY/mapZoomFactor) * zoomLevel;

        double centerXScaled = (x * (image.getWidth()*zoomLevel));
        double centerYScaled = (y * (image.getHeight()*zoomLevel));

        double topLeftX = centerXScaled - ((double) this.getWidth() /2);
        double topLeftY = centerYScaled - ((double) this.getHeight()/2);

        return new Point2D.Double(scaledX - topLeftX,scaledY - topLeftY);
    }

    public void createConnectionBetween(MapNode start, MapNode target) {
        if (start == target) {
            return;
        }
        if (!start.outgoing.contains(target)) {
            start.outgoing.add(target);
            target.incoming.add(start);
        }
        else {
            start.outgoing.remove(target);
            target.incoming.remove(start);
        }
        editor.setStale(true);
    }

    public void createDestinationAt(MapNode mapNode, String destinationName) {
        if (mapNode != null && destinationName != null && destinationName.length() > 0) {
            MapMarker mapMarker = new MapMarker(mapNode, destinationName, "All");
            this.roadMap.addMapMarker(mapMarker);
            editor.setStale(true);
        }
    }

    public void removeAllNodesInScreenArea(Point2D rectangleStartScreen, Point2D rectangleEndScreen) {
        if (this.roadMap == null || this.image == null) {
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

        LinkedList<MapNode> toDelete = new LinkedList<>();
        for (MapNode mapNode : this.roadMap.mapNodes) {
            double currentNodeSize = nodeSize * zoomLevel * 0.5;

            Point2D nodePos = worldPosToScreenPos(mapNode.x + 1024, mapNode.z + 1024);

            if (screenStartX < nodePos.getX() + currentNodeSize && (screenStartX + width) > nodePos.getX() - currentNodeSize && screenStartY < nodePos.getY() + currentNodeSize && (screenStartY + height) > nodePos.getY() - currentNodeSize) {
                toDelete.add(mapNode);
            }
        }
        if (!toDelete.isEmpty()) {
            editor.setStale(true);

            for (MapNode node : toDelete) {
                roadMap.removeMapNode(node);
            }
        }
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

    public double normalizeAngle(double input) {
        if (input > (2*Math.PI)) {
            input = input - (2*Math.PI);
        }
        else {
            if (input < -(2*Math.PI)) {
                input = input + (2*Math.PI);
            }
        }

        return input;
    }

    public void mouseButton1Clicked(int x, int y) {
        if (editor.editorState == AutoDriveEditor.EDITORSTATE_CONNECTING) {
            movingNode = getNodeAt(x, y);
            if (movingNode != null) {
                if (selected == null) {
                    selected = movingNode;
                } else {
                    createConnectionBetween(selected, movingNode);
                    selected = null;
                }
                repaint();
            }
        }
        if (editor.editorState == AutoDriveEditor.EDITORSTATE_CREATING) {
            Point2D worldPos = screenPosToWorldPos(x, y);
            createNode((int)worldPos.getX(), (int)worldPos.getY());
        }
        if (editor.editorState == AutoDriveEditor.EDITORSTATE_CREATING_DESTINATION) {
            movingNode = getNodeAt(x, y);
            if (movingNode != null) {
                String destinationName = JOptionPane.showInputDialog("New destination name:", "" + movingNode.id );
                if (destinationName != null) {
                    createDestinationAt(movingNode, destinationName);
                    repaint();
                }
            }
        }
    }

    public void mouseMoved(int x, int y) {
        mousePosX = x;
        mousePosY = y;
        if (editor.editorState == AutoDriveEditor.EDITORSTATE_CONNECTING && selected != null) {
            repaint();
        }
        movingNode = getNodeAt(x, y);
        if (movingNode != hoveredNode) {
            hoveredNode = movingNode;
            repaint();
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
        else {
            if (isDraggingNode) {
                int diffX = x - lastX;
                int diffY = y - lastY;
                lastX = x;
                lastY = y;
                moveNodeBy(movingNode, diffX, diffY);
            }
        }
        if (editor.editorState == AutoDriveEditor.EDITORSTATE_DELETING && rectangleStart != null) {
            repaint();
        }
    }

    public void mouseButton1Pressed(int x, int y) {
        isDragging = true;
        lastX = x;
        lastY = y;
        movingNode = getNodeAt(x, y);
        if (movingNode != null) {
            isDragging = false;
            if (editor.editorState == AutoDriveEditor.EDITORSTATE_MOVING) {
                isDraggingNode = true;
            }
            if (editor.editorState == AutoDriveEditor.EDITORSTATE_DELETING) {
                removeNode(movingNode);
            }
            if (editor.editorState == AutoDriveEditor.EDITORSTATE_DELETING_DESTINATION) {
                removeDestination(movingNode);
            }
        }
    }

    public void mouseButton3Pressed(int x, int y) {
        LOG.info("Rectangle start set at {}/{}", x, y);
        rectangleStart = new Point2D.Double(x, y);
    }

    public void mouseButton1Released() {
        isDragging = false;
        isDraggingNode = false;
    }

    public void mouseButton3Released(int x, int y) {
        Point2D rectangleEnd = new Point2D.Double(x, y);
        LOG.info("Rectangle end set at {}/{}", x, y);
        if (rectangleStart != null) {
            if (editor.editorState == AutoDriveEditor.EDITORSTATE_DELETING) {

                LOG.info("Removing all nodes in area");
                removeAllNodesInScreenArea(rectangleStart, rectangleEnd);
                repaint();
            }
        }
        rectangleStart = null;
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
        this.roadMap = roadMap;
    }

    public void setMapZoomFactor(int mapZoomFactor) {
        this.mapZoomFactor = mapZoomFactor;
    }
}
