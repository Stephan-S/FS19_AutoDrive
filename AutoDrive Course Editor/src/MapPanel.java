import org.xml.sax.SAXException;

import javax.imageio.ImageIO;
import javax.swing.*;
import javax.xml.parsers.ParserConfigurationException;
import java.awt.*;
import java.awt.geom.Point2D;
import java.awt.geom.Rectangle2D;
import java.awt.image.BufferedImage;
import java.io.File;
import java.io.IOException;
import java.util.LinkedList;

public class MapPanel extends JPanel{

    public BufferedImage image;
    private BufferedImage resizedImage;
    private BufferedImage croppedImage;

    public double x = 0.5;
    public double y = 0.5;
    public double zoomLevel = 1.0;
    public double lastZoomLevel = 0;
    public double nodeSize = 1;
    public AutoDriveEditor editor;

    public RoadMap roadMap;
    public MapNode hoveredNode = null;

    public MapPanel(AutoDriveEditor editor) {
        this.editor = editor;
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
                    if (mapNode == editor.selected) {
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

                if (editor.selected != null && editor.editorState == AutoDriveEditor.EDITORSTATE_CONNECTING) {
                    Point2D nodePos = worldPosToScreenPos(editor.selected.x + 1024, editor.selected.z + 1024);
                    g.setColor(Color.WHITE);
                    g.drawLine((int) (nodePos.getX()), (int) (nodePos.getY()), (int) (editor.mouseListener.mousePosX), (int) (editor.mouseListener.mousePosY));
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

                if (editor.mouseListener.rectangleStart != null) {
                    g.setColor(Color.WHITE);
                    int width = (int) (editor.mouseListener.mousePosX - editor.mouseListener.rectangleStart.getX());
                    int height = (int) (editor.mouseListener.mousePosY - editor.mouseListener.rectangleStart.getY());
                    int x = (int)editor.mouseListener.rectangleStart.getX();
                    int y = (int)editor.mouseListener.rectangleStart.getY();
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

    public void resizeMap() {
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

        int centerX = (int)(x * image.getWidth());
        int centerY = (int)(y * image.getHeight());

        int offsetX = (centerX-(widthScaled/2));
        int offsetY = (centerY-(heightScaled/2));

        croppedImage = image.getSubimage(offsetX, offsetY, widthScaled, heightScaled);

        resizedImage = new BufferedImage(this.getWidth(), this.getHeight(), image.getType());
        Graphics2D g2 = resizedImage.createGraphics();
        g2.drawImage(croppedImage, 0, 0, this.getWidth(), this.getHeight(), null);
        g2.dispose();

        lastZoomLevel = zoomLevel;
    }

    public void moveMapBy(double diffX, double diffY) {
        if (this.roadMap == null || this.image == null) {
            return;
        }
        x -= diffX / (zoomLevel * image.getWidth());
        y -= diffY / (zoomLevel * image.getHeight());

        resizeMap();
        this.repaint();
    }

    public void increaseZoomLevelBy(double step) {
        if (this.roadMap == null || this.image == null) {
            return;
        }
        if (((this.getWidth()/(this.zoomLevel - step)) > image.getWidth()) || ((this.getHeight()/(this.zoomLevel - step)) > image.getHeight())) {
            return;
        }

        if ((this.zoomLevel - step) < 30) {
            this.zoomLevel -= step;
            resizeMap();
            this.repaint();
        }
    }

    public void moveNodeBy(MapNode node, double diffX, double diffY) {
        node.x += (diffX / zoomLevel) ;
        node.z += (diffY / zoomLevel);

        this.repaint();
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
            this.repaint();
        }
    }

    public void createNode(int screenX, int screenY) {
        if (this.roadMap == null || this.image == null) {
            return;
        }
        MapNode mapNode = new MapNode(this.roadMap.mapNodes.size()+1, screenX, -1, screenY);

        for (MapMarker mapMarker : this.roadMap.mapMarkers) {
            mapNode.directions.put(mapMarker, null);
        }

        this.roadMap.mapNodes.add(mapNode);
        this.repaint();
    }

    public Point2D screenPosToWorldPos(int screenX, int screenY) {
        Point2D worldPos = new Point2D.Double(0,0);

        double centerX = (x * (image.getWidth()));
        double centerY = (y * (image.getHeight()));

        double widthScaled = (this.getWidth() / zoomLevel);
        double heightScaled = (this.getHeight() / zoomLevel);

        double topLeftX = centerX - (widthScaled/2);
        double topLeftY = centerY - (heightScaled/2);

        double diffScaledX = screenX / zoomLevel;
        double diffScaledY = screenY / zoomLevel;

        double worldPosX = topLeftX + diffScaledX - 1024;
        double worldPosY = topLeftY + diffScaledY - 1024;

        worldPos.setLocation(worldPosX, worldPosY);

        return worldPos;
    }

    public Point2D worldPosToScreenPos(double worldX, double worldY) {
        Point2D screenPos = new Point2D.Double(0,0);

        double scaledX = worldX * zoomLevel;
        double scaledY = worldY * zoomLevel;

        //scaledX = ((worldX + 2048)/2.0) * zoomLevel;
        //scaledY = ((worldY + 2048)/2.0) * zoomLevel;

        double centerXScaled = (x * (image.getWidth()*zoomLevel));
        double centerYScaled = (y * (image.getHeight()*zoomLevel));

        double widthScaled = (this.getWidth() / zoomLevel);
        double heightScaled = (this.getHeight() / zoomLevel);

        double topLeftX = centerXScaled - (this.getWidth()/2);
        double topLeftY = centerYScaled - (this.getHeight()/2);

        screenPos.setLocation(scaledX - topLeftX, scaledY - topLeftY);

        return screenPos;
    }

    public void createConnectionBetween(MapNode start, MapNode target) {
        if (start == target) {
            return;
        }
        if (start.outgoing.contains(target) == false) {
            start.outgoing.add(target);
            target.incoming.add(start);
        }
        else {
            start.outgoing.remove(target);
            target.incoming.remove(start);
        }
    }

    public void createDestinationAt(MapNode mapNode, String destinationName) {
        if (mapNode != null && destinationName != null && destinationName.length() > 0) {
            MapMarker mapMarker = new MapMarker(mapNode, destinationName);
            this.roadMap.addMapMarker(mapMarker);
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
        for (MapNode node : toDelete)  {
            roadMap.removeMapNode(node);
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

}
