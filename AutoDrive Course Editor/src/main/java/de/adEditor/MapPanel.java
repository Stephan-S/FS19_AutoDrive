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
    private double lastZoomLevel = 0;
    private int mapZoomFactor = 1;
    private double nodeSize = 1.0;
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

    private boolean multiSelect = false;
    private LinkedList<MapNode> multiSelectList  = new LinkedList<>();
    private boolean isDraggingRoute = false;
    private static boolean isControlNodeSelected = false;
    private static boolean curveCreated = false;
    private static boolean hasJustClicked = false;
    public static QuadCurve quadCurve;
    public static LinearLine linearLine;
    public static int connectionType = 0; //default to standard connection

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

            if (lastZoomLevel != zoomLevel) {
                resizeMap();
            }

            g.clipRect(0, 0, this.getWidth(), this.getHeight());

            g.drawImage(resizedImage, 0, 0, this); // see javadoc for more info on the parameters

            int sizescaled = (int) (nodeSize * zoomLevel);
            int sizescaledhalf = (int) (sizescaled * 0.5);
            int[] x = new int[3];
            int[] y = new int[3];

            int ghy=0;

            if (this.roadMap != null) {
                for (MapNode mapNode : this.roadMap.mapNodes) {

                    if (quadCurve != null) {
                        if (quadCurve.getControlPoint() != null) {
                            Point2D nodePos = worldPosToScreenPos(quadCurve.getControlPoint().x, quadCurve.getControlPoint().z );
                            int centrex = (int) (nodePos.getX() - sizescaledhalf);
                            int centrey = (int) (nodePos.getY() - sizescaledhalf);

                            x[0] = centrex; x[1] = centrex + (sizescaled / 2); x[2] = centrex + sizescaled;
                            y[0] = centrey; y[1] = centrey + sizescaled; y[2] = centrey;

                            g.setColor(Color.MAGENTA);
                            g.fillPolygon(x, y, 3);
                        }
                    }

                    if (mapNode.selected) {
                        g.setColor(Color.WHITE);
                    } else if (mapNode.flag == 0) {
                        g.setColor(Color.RED);
                    } else {
                        g.setColor(Color.ORANGE);
                    }

                    Point2D nodePos = worldPosToScreenPos(mapNode.x, mapNode.z );
                    //g.drawImage(nodeImage,(int) (nodePos.getX() - sizescaledhalf), (int) (nodePos.getY() - sizescaledhalf), (int)sizescaled, (int)sizescaled, null);
                    g.fillArc((int) (nodePos.getX() - sizescaledhalf), (int) (nodePos.getY() - sizescaledhalf), sizescaled, sizescaled, 0, 360);



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

                for (MapMarker mapMarker : RoadMap.mapMarkers) {
                    g.setColor(Color.WHITE);
                    Point2D nodePos = worldPosToScreenPos(mapMarker.mapNode.x - 1, mapMarker.mapNode.z - 1 );
                    g.drawString(mapMarker.name, (int) (nodePos.getX()), (int) (nodePos.getY()));
                }

                // change colour of in progress connection line

                if (selected != null) {
                    if (editor.editorState == AutoDriveEditor.EDITORSTATE_LINEARLINE) {
                        for (int j = 1; j < linearLine.lineNodeList.size(); j++) { // skip the starting node of the array
                            MapNode newpos = linearLine.lineNodeList.get(j);
                            MapNode prevpos = linearLine.lineNodeList.get(j-1);

                            Point2D fakenodePos = worldPosToScreenPos(newpos.x, newpos.y);
                            Point2D prevfakenodePos = worldPosToScreenPos(prevpos.x, prevpos.y);

                            g.setColor(Color.WHITE);
                            // don't draw the circle for the last node in the array
                            if (j != linearLine.lineNodeList.size()-1) {
                                g.fillArc((int) (fakenodePos.getX() - ((nodeSize * zoomLevel) * 0.5)), (int) (fakenodePos.getY() - ((nodeSize * zoomLevel) * 0.5)), (int) (nodeSize * zoomLevel), (int) (nodeSize * zoomLevel), 0, 360);
                            }
                            g.setColor(Color.GREEN);
                            drawArrowBetween(g, prevfakenodePos, fakenodePos, false);
                        }
                    } else {
                        Point2D nodePos = worldPosToScreenPos(selected.x, selected.z);
                        if (editor.editorState == AutoDriveEditor.EDITORSTATE_CONNECTING) {
                            if (connectionType == CONNECTION_STANDARD && selected.flag == 1) {
                                g.setColor(Color.ORANGE);
                            } else if (connectionType == CONNECTION_STANDARD) { // CONNECTION_SUBPRIO
                                g.setColor(Color.GREEN);
                            } else if (connectionType == CONNECTION_DUAL) {
                                g.setColor(Color.BLUE);
                            } else if (connectionType == CONNECTION_REVERSE) {
                                g.setColor(Color.CYAN);
                            }
                        }
                        /*if (connectionType == CONNECTION_REVERSE) {
                            g.setColor(Color.CYAN);
                        } else {
                            if (selected.flag == 1) {
                                g.setColor(Color.ORANGE);
                            } else {
                                g.setColor(Color.GREEN);
                            }
                        }*/
                        g.drawLine((int) (nodePos.getX()), (int) (nodePos.getY()), mousePosX, mousePosY);
                    }
                }

                if (curveCreated) {
                     for (int j = 0; j < quadCurve.curveNodesList.size() - 1; j++) {

                         MapNode currentcoord = quadCurve.curveNodesList.get(j);
                         MapNode nextcoored = quadCurve.curveNodesList.get(j+1);


                         Point2D currentNodePos = worldPosToScreenPos(currentcoord.x, currentcoord.y);
                         Point2D nextNodePos = worldPosToScreenPos(nextcoored.x, nextcoored.y);

                         g.setColor(Color.WHITE);
                         if ( j != 0 ) {
                             g.fillArc((int) (currentNodePos.getX() - ((nodeSize * zoomLevel) * 0.5)), (int) (currentNodePos.getY() - ((nodeSize * zoomLevel) * 0.5)), (int) (nodeSize * zoomLevel), (int) (nodeSize * zoomLevel), 0, 360);
                         }
                         g.setColor(Color.GREEN);
                         drawArrowBetween(g, currentNodePos, nextNodePos, false);
                     }
                }

                //draw marker group when hovering over node

                if (hoveredNode != null) {
                    Point2D nodePos = worldPosToScreenPos(hoveredNode.x, hoveredNode.z);
                    g.setColor(Color.WHITE);
                    if (hoveredNode.flag == NODE_CONTROLPOINT) {
                        int centrex = (int) (nodePos.getX() - sizescaledhalf);
                        int centrey = (int) (nodePos.getY() - sizescaledhalf);

                        x[0]= centrex; x[1]=centrex + (sizescaled/2); x[2]=centrex + sizescaled;
                        y[0]= centrey; y[1]=centrey + sizescaled; y[2]=centrey;
                        g.fillPolygon(x,y,3);
                    } else {
                        g.fillArc((int) (nodePos.getX() - sizescaledhalf), (int) (nodePos.getY() - sizescaledhalf), sizescaled, sizescaled, 0, 360);
                    }
                    for (MapMarker mapMarker : RoadMap.mapMarkers) {
                        if (hoveredNode.id == mapMarker.mapNode.id) {
                            g.setColor(Color.WHITE);
                            Point2D nodePosMarker = worldPosToScreenPos(mapMarker.mapNode.x - 1, mapMarker.mapNode.z -1);
                            String text = mapMarker.name + " ( " + mapMarker.group + " )";
                            g.drawString(text, (int) (nodePosMarker.getX()), (int) (nodePosMarker.getY()));

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
            Graphics2D g2 = (Graphics2D) resizedImage.getGraphics();
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
            if (curveCreated) {
                if (node == quadCurve.getCurveStartNode()) {
                    LOG.info("Moved Curve Start");
                    quadCurve.setCurveStartNode(node);
                } else if (node == quadCurve.getCurveEndNode()) {
                    LOG.info("Moved Curve End");
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
        if (this.roadMap != null && this.image != null) {
            for (MapNode mapNode : this.roadMap.mapNodes) {
                double currentNodeSize = nodeSize * zoomLevel * 0.5;

                Point2D outPos = worldPosToScreenPos(mapNode.x, mapNode.z);

                if (posX < outPos.getX() + currentNodeSize && posX > outPos.getX() - currentNodeSize && posY < outPos.getY() + currentNodeSize && posY > outPos.getY() - currentNodeSize) {
                    return mapNode;
                }
            }
            if (curveCreated && editor.editorState == EDITORSTATE_QUADRATICBEZIER) {
                double currentNodeSize = nodeSize * zoomLevel * 0.5;

                Point2D outPos = worldPosToScreenPos(quadCurve.getControlPoint().x, quadCurve.getControlPoint().z);

                if (posX < outPos.getX() + currentNodeSize && posX > outPos.getX() - currentNodeSize && posY < outPos.getY() + currentNodeSize && posY > outPos.getY() - currentNodeSize) {
                    return quadCurve.getControlPoint();
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
        LinkedList<MapMarker> mapMarkers = RoadMap.mapMarkers;
        for (MapMarker mapMarker : mapMarkers) {
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

    public void createNode(int screenX, int screenY, int flag) {
        if (this.roadMap == null || this.image == null) {
            return;
        }
        LOG.info("createNode: {}, {}", screenX, screenY);
        MapNode mapNode = new MapNode(this.roadMap.mapNodes.size()+1, screenX, -1, screenY, flag, false); //flag = 0 causes created node to be regular by default

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

    public void createConnectionBetween(MapNode start, MapNode target,int type) {
        if (start == target) {
            return;
        }
        if (!start.outgoing.contains(target)) {
            start.outgoing.add(target);

            if (connectionType == CONNECTION_STANDARD) {
                target.incoming.add(start);
            } else if (connectionType == CONNECTION_REVERSE ) {
                target.incoming.remove(start);
            } else if (connectionType == CONNECTION_DUAL) {
                target.incoming.add(start);
                if (!target.outgoing.contains(start)) {
                    target.outgoing.add(start);
                    start.incoming.add(target);
                }
            }
        } else {
            if (connectionType == CONNECTION_STANDARD) {
                start.outgoing.remove(target);
                target.incoming.remove(start);
            } else if (connectionType == CONNECTION_REVERSE ) {
                start.outgoing.remove(target);
                target.incoming.add(start);
            } else if (connectionType == CONNECTION_DUAL) {
                start.outgoing.remove(target);
                target.incoming.remove(start);
                if (target.outgoing.contains(start)) {
                    target.outgoing.remove(start);
                    start.incoming.remove(target);
                }

            }

        }
        editor.setStale(true);
    }

    public void createDestinationAt(MapNode mapNode, String destinationName, String groupName) {
        if (mapNode != null && destinationName != null && destinationName.length() > 0) {
            if (groupName == null) groupName = "All";
            MapMarker mapMarker = new MapMarker(mapNode, destinationName, groupName);
            this.roadMap.addMapMarker(mapMarker);
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
        if (!multiSelectList.isEmpty()) {
            editor.setStale(true);
            for (MapNode node : multiSelectList) {
                roadMap.removeMapNode(node);
            }
        }
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
        clearMultiSelection();
    }

   public void getAllNodesInArea(Point2D rectangleStartScreen, Point2D rectangleEndScreen) {
        if (this.roadMap == null || this.image == null) {
            //multiSelectList = null;
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
        for (MapNode mapNode : this.roadMap.mapNodes) {
            double currentNodeSize = nodeSize * zoomLevel * 0.5;

            Point2D nodePos = worldPosToScreenPos(mapNode.x, mapNode.z);

            if (screenStartX < nodePos.getX() + currentNodeSize && (screenStartX + width) > nodePos.getX() - currentNodeSize && screenStartY < nodePos.getY() + currentNodeSize && (screenStartY + height) > nodePos.getY() - currentNodeSize) {
                if (multiSelectList.contains(mapNode)) {
                    multiSelectList.remove(mapNode);
                    mapNode.selected = false;
                } else {
                    if (mapNode.flag != NODE_CONTROLPOINT) {
                        multiSelectList.add(mapNode);
                        mapNode.selected = true;
                    }

                }

            }
        }

        if (multiSelectList.size() > 0 ) {
            multiSelect = true;
        }
    }

    public void clearMultiSelection() {
        if (multiSelectList != null && multiSelectList.size() > 0 ) {
            for (MapNode node : multiSelectList) {
                node.selected = false;
            }
            multiSelectList.clear();
        }
        multiSelect = false;
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

    public void mouseButton3Clicked(int x, int y) {
        if (editor.editorState == EDITORSTATE_QUADRATICBEZIER) {
            stopCurveEdit();
        }
        clearMultiSelection();
        this.repaint();
    }

    public void mouseButton1Clicked(int x, int y) {

        movingNode = getNodeAt(x, y);

        if (editor.editorState == AutoDriveEditor.EDITORSTATE_CREATING_PRIMARY) {
            Point2D worldPos = screenPosToWorldPos(x, y);
            createNode((int)worldPos.getX(), (int)worldPos.getY(),NODE_STANDARD);
        }
        if (editor.editorState == AutoDriveEditor.EDITORSTATE_CREATING_DESTINATION) {
            if (movingNode != null) {
                for (int i = 0; i < RoadMap.mapMarkers.size(); i++) {
                    MapMarker mapMarker = RoadMap.mapMarkers.get(i);
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
        if (editor.editorState == AutoDriveEditor.EDITORSTATE_CHANGE_NODE_PRIORITY) {
            MapNode changingNode = getNodeAt(x, y);
            if (changingNode != null) {
                if (changingNode.flag != NODE_CONTROLPOINT) {
                    changeNodePriority(changingNode);
                }
            }
        }
        if (editor.editorState == AutoDriveEditor.EDITORSTATE_CREATE_SUBPRIO_NODE) {
            Point2D worldPos = screenPosToWorldPos(x, y);
            createNode((int)worldPos.getX(), (int)worldPos.getY(),NODE_SUBPRIO);
        }

        if (editor.editorState == AutoDriveEditor.EDITORSTATE_EDITING_DESTINATION) {
            if (movingNode != null) {
                for (int i = 0; i < RoadMap.mapMarkers.size(); i++) {
                    MapMarker mapMarker = RoadMap.mapMarkers.get(i);
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
        if (editor.editorState == AutoDriveEditor.EDITORSTATE_ALIGN_HORIZONTAL) {
            if (multiSelect && multiSelectList != null && movingNode != null) {
                LOG.info("Horizontal Align {} nodes at {}",multiSelectList.size(), movingNode.y);
                for (MapNode node : multiSelectList) {
                    node.z = movingNode.z;
                }
                if (curveCreated) {
                    quadCurve.updateCurve();
                }
                editor.setStale(true);
                clearMultiSelection();
                this.repaint();

            }
        }
        if (editor.editorState == AutoDriveEditor.EDITORSTATE_ALIGN_VERTICAL) {
            if (multiSelect && multiSelectList != null && movingNode != null) {
                LOG.info("Horizontal Align {} nodes at {}",multiSelectList.size(), movingNode.x);
                for (MapNode node : multiSelectList) {
                    node.x = movingNode.x;
                }
                if (curveCreated) {
                    quadCurve.updateCurve();
                }
                editor.setStale(true);
                clearMultiSelection();
                this.repaint();

            }
        }

        if (editor.editorState == AutoDriveEditor.EDITORSTATE_QUADRATICBEZIER) {
            if (movingNode != null) {
                if (selected == null && !curveCreated) {
                    selected = movingNode;
                    LOG.info("selected start node of curve");
                    cleatTextArea();
                    showInTextArea("selected start node of curve, click on end node of curve\n");
                } else if (selected == hoveredNode) {
                    selected = null;
                    LOG.info("curve cancelled");
                    showInTextArea("curve cancelled\n");
                    stopCurveEdit();
                } else {
                    if (!curveCreated) {
                        LOG.info("selected end node of curve");
                        showInTextArea("selected end node of curve, creating curve\n");
                        if (hasJustClicked) {
                            hasJustClicked = false;
                        } else {
                            quadCurve = new QuadCurve(selected, movingNode);
                            quadCurve.setNumInterpolationPoints(AutoDriveEditor.numIterationsSlider.getValue());
                            curveCreated = true;
                            hasJustClicked = true;
                            selected = null;
                        }
                    }
                }
                repaint();
            }
        }
    }

    public void mouseMoved(int x, int y) {
        mousePosX = x;
        mousePosY = y;
        if (editor.editorState == AutoDriveEditor.EDITORSTATE_CONNECTING && selected != null) {
           this.repaint();
        }
        if (editor.editorState == AutoDriveEditor.EDITORSTATE_CREATE_REVERSE_CONNECTION && selected != null) {
            this.repaint();
        }
        if (editor.editorState == AutoDriveEditor.EDITORSTATE_LINEARLINE && selected != null) {
            if (isDraggingRoute) {
                Point2D pointerPos = screenPosToWorldPos(mousePosX, mousePosY);
                linearLine.updateLine((int)pointerPos.getX(), (int)pointerPos.getY());
                this.repaint();
            }
            //this.repaint();
        }
        if (editor.editorState == AutoDriveEditor.EDITORSTATE_QUADRATICBEZIER && selected != null) {
            this.repaint();
        }
        movingNode = getNodeAt(x, y);
        if (movingNode != hoveredNode) {
            hoveredNode = movingNode;
            this.repaint();
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
            if (multiSelect && editor.editorState== AutoDriveEditor.EDITORSTATE_MOVING) {
                for (MapNode node : multiSelectList) {
                    moveNodeBy(node, diffX, diffY);
                }
            } else {
                moveNodeBy(movingNode, diffX, diffY);
            }
        }

        if (isControlNodeSelected) {
            int diffX = x - lastX;
            int diffY = y - lastY;
            lastX = x;
            lastY = y;
            //if (editor.editorState == EDITORSTATE_QUADRATICBEZIER) {
                moveNodeBy(quadCurve.getControlPoint(), diffX, diffY);
                quadCurve.updateCurve();
            //}

        }

        if (editor.editorState == AutoDriveEditor.EDITORSTATE_QUADRATICBEZIER) {
            if (movingNode !=null && curveCreated) {
                quadCurve.updateCurve();
                this.repaint();
            }
        }


        if (editor.editorState == AutoDriveEditor.EDITORSTATE_DELETE_NODES && rectangleStart != null) {
            this.repaint();
        } else if (editor.editorState == AutoDriveEditor.EDITORSTATE_CHANGE_NODE_PRIORITY && rectangleStart != null) {
            this.repaint();
        } else if (editor.editorState == AutoDriveEditor.EDITORSTATE_MOVING && rectangleStart != null) {
            this.repaint();
        } else if (editor.editorState == AutoDriveEditor.EDITORSTATE_ALIGN_HORIZONTAL && rectangleStart != null) {
            this.repaint();
        } else if (editor.editorState == AutoDriveEditor.EDITORSTATE_ALIGN_VERTICAL && rectangleStart != null) {
            this.repaint();
        } else if (editor.editorState == AutoDriveEditor.EDITORSTATE_LINEARLINE && rectangleStart != null) {
            this.repaint();
        }
    }

    public void mouseButton1Pressed(int x, int y) {
        isDragging = true;
        lastX = x;
        lastY = y;
        movingNode = getNodeAt(x, y);
        if (editor.editorState == AutoDriveEditor.EDITORSTATE_CONNECTING) {
            if (movingNode != null && movingNode.flag !=NODE_CONTROLPOINT) {
                if (selected == null) {
                    selected = movingNode;
                } else if (selected == hoveredNode) {
                    selected = null;
                } else {
                    createConnectionBetween(selected, movingNode, connectionType);
                    if (AutoDriveEditor.bContinuousConnections) {
                        selected = movingNode;
                    } else {
                        selected = null;
                    }
                }
                this.repaint();
            }
        }

        if (editor.editorState == AutoDriveEditor.EDITORSTATE_LINEARLINE) {
            if (movingNode != null) {
                if (selected == null) {
                    selected = movingNode;
                    Point2D pointerPos = screenPosToWorldPos(mousePosX, mousePosY);
                    linearLine = new LinearLine(selected, (int)pointerPos.getX(), (int)pointerPos.getY());
                    //pointsArray.clear();
                    isDraggingRoute = true;
                    LOG.info("selected start node, click end node to complete or right click to cancel");
                    cleatTextArea();
                    showInTextArea("selected start node, click end node to complete or right click to cancel\n");
                } else if (selected == hoveredNode) {
                    selected = null;
                    LOG.info("Linear Line cancelled");
                    showInTextArea("Linear Line cancelled\n");
                } else {

                    // TODO - call addnodes - add linear line nodes here

                    LOG.info("Linear Line completed");
                    showInTextArea("Linear Line completed\n");
                    isDraggingRoute = false;
                    selected = null;
                }
                this.repaint();
            }
        }

        if (editor.editorState == AutoDriveEditor.EDITORSTATE_QUADRATICBEZIER) {
            if (curveCreated && quadCurve.getControlPoint() !=null) {
                if (movingNode == quadCurve.getControlPoint()) {
                    isControlNodeSelected = true;
                }
            }
        }

        if (movingNode != null) {
            isDragging = false;
            if (editor.editorState == AutoDriveEditor.EDITORSTATE_MOVING) {
                isDraggingNode = true;
            }
            if (editor.editorState == AutoDriveEditor.EDITORSTATE_DELETE_NODES) {
                removeNode(movingNode);
            }
            if (editor.editorState == AutoDriveEditor.EDITORSTATE_DELETING_DESTINATION) {
                removeDestination(movingNode);
            }
        }
    }

    public void mouseButton3Pressed(int x, int y) {
        if (editor.editorState == AutoDriveEditor.EDITORSTATE_QUADRATICBEZIER) return;
        if (editor.editorState == AutoDriveEditor.EDITORSTATE_LINEARLINE) return;

        LOG.info("{} {}/{}", localeString.getString("console_rect_start"), x, y);
        rectangleStart = new Point2D.Double(x, y);

    }

    public void mouseButton1Released() {
        isDragging = false;
        isDraggingNode = false;
        isControlNodeSelected=false;
    }

    public void mouseButton3Released(int x, int y) {
        if (rectangleStart != null) {

            Point2D rectangleEnd = new Point2D.Double(x, y);
            LOG.info("{} {}/{}", localeString.getString("console_rect_end"), x, y);

            if (editor.editorState == AutoDriveEditor.EDITORSTATE_DELETE_NODES) {
                int result = JOptionPane.showConfirmDialog(this, localeString.getString("dialog_node_area_delete"),localeString.getString("dialog_node_area_delete_title"), JOptionPane.OK_CANCEL_OPTION,JOptionPane.WARNING_MESSAGE);
                if (result == 0) {
                    LOG.info("{}", localeString.getString("console_node_area_remove"));
                    removeAllNodesInScreenArea(rectangleStart, rectangleEnd);
                }

                repaint();
            }
            if (editor.editorState == AutoDriveEditor.EDITORSTATE_CHANGE_NODE_PRIORITY) {

                LOG.info("{}", localeString.getString("console_node_priority_toggle"));
                changeAllNodesPriInScreenArea(rectangleStart, rectangleEnd);
                repaint();
            }
            if (editor.editorState == AutoDriveEditor.EDITORSTATE_MOVING) {

                LOG.info("{}", localeString.getString("console_node_priority_toggle"));
                getAllNodesInArea(rectangleStart, rectangleEnd);
                repaint();
            }
            if (editor.editorState == AutoDriveEditor.EDITORSTATE_ALIGN_HORIZONTAL) {

                LOG.info("{}", localeString.getString("console_node_align_horizontal"));
                getAllNodesInArea(rectangleStart, rectangleEnd);
                repaint();
            }
            if (editor.editorState == AutoDriveEditor.EDITORSTATE_ALIGN_VERTICAL) {

                LOG.info("{}", localeString.getString("console_node_align_vertical"));
                getAllNodesInArea(rectangleStart, rectangleEnd);
                repaint();
            }

        }
        rectangleStart = null;
    }

    public void stopCurveEdit() {
        if (quadCurve != null) {
            hasJustClicked = false;
            curveCreated = false;
            isControlNodeSelected = false;
            this.repaint();
        }
    }

    private void showInTextArea(String text) { AutoDriveEditor.textArea.append(text); }

    private void cleatTextArea() {
        AutoDriveEditor.textArea.selectAll();
        AutoDriveEditor.textArea.removeAll();
    }

    private destInfo showNewMarkerDialog(int id) {

        JTextField destName = new JTextField();
        String[] group = new String[1];

        ArrayList<String> groupArray = new ArrayList<>();
        LinkedList<MapMarker> mapMarkers = RoadMap.mapMarkers;
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
        LinkedList<MapMarker> mapMarkers = RoadMap.mapMarkers;
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

    public void redraw() {
        this.repaint();
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
