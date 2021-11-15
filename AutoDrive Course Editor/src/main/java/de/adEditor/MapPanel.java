package de.adEditor;

import javax.swing.*;
import java.awt.*;
import java.awt.event.ComponentAdapter;
import java.awt.event.ComponentEvent;
import java.awt.geom.Point2D;
import java.awt.geom.Rectangle2D;
import java.awt.image.BufferedImage;
import java.awt.image.RasterFormatException;
import java.text.Collator;
import java.util.ArrayList;
import java.util.Collections;
import java.util.LinkedList;
import java.util.concurrent.locks.Lock;
import java.util.concurrent.locks.ReentrantLock;

import de.adEditor.MapHelpers.*;

import static de.adEditor.ADUtils.*;
import static de.adEditor.AutoDriveEditor.*;
import static de.adEditor.GUIBuilder.*;
import static de.adEditor.MapHelpers.ChangeManager.*;

public class MapPanel extends JPanel{

    public static final int NODE_STANDARD = 0;
    public static final int NODE_SUBPRIO = 1;
    public static final int NODE_CONTROLPOINT = 2;

    public static final int CONNECTION_STANDARD = 0;
    public static final int CONNECTION_SUBPRIO = 1; // never used as subprio routes are based on a nodes .flag value
    public static final int CONNECTION_DUAL = 2;
    public static final int CONNECTION_REVERSE = 3;

    private static BufferedImage image;
    public static Image resizedImage;
    public static boolean showTime = false;

    public Thread nodeDraw;
    public Thread connectionDraw;
    private static Lock drawlock = new ReentrantLock();

    private static double x = 0.5;
    private static double y = 0.5;
    private static double zoomLevel = 1.0;
    private double lastZoomLevel = 1.0;
    private static int mapZoomFactor = 1;
    private static double nodeSize = 1.0;
    private AutoDriveEditor editor;
    public static boolean stale = false;

    public static RoadMap roadMap;
    public static  MapNode hoveredNode = null;
    private MapNode movingNode = null;
    private static MapNode selected = null;

    private static int mousePosX = 0;
    private static int mousePosY = 0;

    private boolean isDragging = false;
    public static  boolean isDraggingNode = false;
    private int lastX = 0;
    private int lastY = 0;

    private static Point2D rectangleStart;
    public boolean isMultiSelectAllowed = false;

    private static boolean isMultipleSelected = false;
    public static LinkedList<MapNode> multiSelectList  = new LinkedList<>();

    public boolean isDraggingRoute = false;
    private static boolean isControlNodeSelected = false;
    public static boolean isQuadCurveCreated = false;
    public static boolean isCubicCurveCreated = false;
    public static QuadCurve quadCurve;
    public static CubicCurve cubicCurve;
    public static LinearLine linearLine;
    public static int connectionType = 0; // 0 = regular , 1 = dual, 2 = reverse

    public static int createRegularConnectionState = 0;
    public static int createDualConnectionState = 0;
    public static int createReverseConnectionState = 0;

    public static LinkedList<NodeLinks> deleteNodeList = new LinkedList<>();
    public static int moveDiffX, moveDiffY;

    private static Color BROWN = new Color(152, 104, 50 );


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
                // Part 2 of work around for map resize bug.. force a refresh of all the values
                // used to redraw the map.
                moveMapBy(0,0);
                repaint();
            }
        });
    }

    //
    // The NodeDraw thread is 2 or 3 times quicker to execute that connectionDraw(), so we try and spread
    // some of the draw load around by doing the curve/line/rectangle drawing here
    //

    static class NodeDrawThread implements Runnable {

        private Graphics gRef = null;
        private int width;
        private int height;

        public NodeDrawThread(Graphics graphics, int panelWidth, int panelHeight) {
            gRef = graphics;
            this.width = panelWidth;
            this.height = panelHeight;
        }

        static class TextDisplayStore {
            String Text;
            Point2D coord;
            Color colour;

            public TextDisplayStore(String text, Point2D textCoord, Color textColour) {
                this.Text = text;
                this.coord = textCoord;
                this.colour = textColour;
            }
        }

        @Override
        public void run() {

            long startTime = 0;

            if (PROFILE) {
                startTime = System.currentTimeMillis();
            }


            ArrayList<TextDisplayStore> textList = new ArrayList<>();

            int sizeScaled = (int) (nodeSize * zoomLevel);
            int sizeScaledHalf = (int) (sizeScaled * 0.5);
            double currentNodeSize = nodeSize * zoomLevel * 0.5;

            if (gRef != null) {

                LinkedList<MapNode> mapNodes = roadMap.mapNodes;

                //
                // Draw all nodes in visible area of map
                // The original code would draw all the nodes even if they were not visible
                //

                for (MapNode mapNode : mapNodes) {
                    Point2D nodePos = worldPosToScreenPos(mapNode.x, mapNode.z);
                    if (0 < nodePos.getX() + currentNodeSize && (width) > nodePos.getX() - currentNodeSize && 0 < nodePos.getY() + currentNodeSize && (height) > nodePos.getY() - currentNodeSize) {
                        if (mapNode.selected && mapNode.flag == 0) {
                            gRef.drawImage(nodeImageSelected, (int) (nodePos.getX() - sizeScaledHalf), (int) (nodePos.getY() - sizeScaledHalf), sizeScaled, sizeScaled, null);
                        } else if (mapNode.selected && mapNode.flag == 1) {
                            gRef.drawImage(subPrioNodeImageSelected, (int) (nodePos.getX() - sizeScaledHalf), (int) (nodePos.getY() - sizeScaledHalf), sizeScaled, sizeScaled, null);
                        } else if (mapNode.flag == 1) {
                            gRef.drawImage(subPrioNodeImage, (int) (nodePos.getX() - sizeScaledHalf), (int) (nodePos.getY() - sizeScaledHalf), sizeScaled, sizeScaled, null);
                        } else {
                            gRef.drawImage(nodeImage, (int) (nodePos.getX() - sizeScaledHalf), (int) (nodePos.getY() - sizeScaledHalf), sizeScaled, sizeScaled, null);
                        }

                        // show the node ID if we in debug mode .. the higher the node count, the more text spam there is :-P
                        // It will affect editor speed, the more nodes the worse it will get, you have been warned :)

                        if (bDebugShowID) {
                            textList.add(new TextDisplayStore(String.valueOf(mapNode.id), nodePos, Color.WHITE));
                        }
                    }

                }

                // do we draw the node hover-over image and add the marker name/group to the draw list

                if (hoveredNode != null) {
                    Point2D hoverNodePos = worldPosToScreenPos(hoveredNode.x, hoveredNode.z);
                    if (hoveredNode.flag == NODE_STANDARD) {
                        gRef.drawImage(nodeImageSelected, (int) (hoverNodePos.getX() - sizeScaledHalf), (int) (hoverNodePos.getY() - sizeScaledHalf), sizeScaled, sizeScaled, null);
                    } else if (hoveredNode.flag == NODE_SUBPRIO) {
                        gRef.drawImage(subPrioNodeImageSelected, (int) (hoverNodePos.getX() - sizeScaledHalf), (int) (hoverNodePos.getY() - sizeScaledHalf), sizeScaled, sizeScaled, null);
                    }
                    for (MapMarker mapMarker : roadMap.mapMarkers) {
                        if (hoveredNode.id == mapMarker.mapNode.id) {
                            String text = mapMarker.name + " ( " + mapMarker.group + " )";
                            Point2D nodePosMarker = worldPosToScreenPos(mapMarker.mapNode.x - 1, mapMarker.mapNode.z - 1);
                            textList.add( new TextDisplayStore( text, nodePosMarker, Color.WHITE));
                        }
                    }
                    if (DEBUG) {
                        String text = "x = " + hoveredNode.x + " , z = " + hoveredNode.z + " , flags = " + hoveredNode.flag;
                        Point2D nodePosMarker = worldPosToScreenPos(hoveredNode.x + 1, hoveredNode.z);
                        textList.add( new TextDisplayStore( text, nodePosMarker, Color.WHITE));
                    }
                }

                // iterate over all the markers and add the names to the draw list

                LinkedList<MapMarker> mapMarkers = roadMap.mapMarkers;
                for (MapMarker mapMarker : mapMarkers) {
                    if (roadMap.mapNodes.contains(mapMarker.mapNode)) {
                        Point2D nodePos = worldPosToScreenPos(mapMarker.mapNode.x - 1, mapMarker.mapNode.z - 1);
                        textList.add(new TextDisplayStore(mapMarker.name, nodePos, Color.WHITE));
                    }
                }

                // display all the text we need to render

                for(int i = 0; i <= textList.size() -1; i++ ) {
                    TextDisplayStore list = textList.get(i);

                    drawlock.lock();
                    try {
                        gRef.setColor(list.colour);
                        gRef.drawString(list.Text, (int) list.coord.getX(), (int) list.coord.getY());
                    } finally {
                        drawlock.unlock();
                    }
                }
            }

            // Draw any liner lines

            if (selected != null) {
                if (editorState == EDITORSTATE_CONNECTING) {

                    Color colour = Color.GREEN;

                    if (linearLine.lineNodeList.size() > 1) {
                        for (int j = 0; j < linearLine.lineNodeList.size() -1; j++) { // skip the starting node of the array
                            MapNode firstPos = linearLine.lineNodeList.get(j);
                            MapNode secondPos = linearLine.lineNodeList.get(j+1);

                            Point2D startNodePos = worldPosToScreenPos(firstPos.x, firstPos.y);
                            Point2D endNodePos = worldPosToScreenPos(secondPos.x, secondPos.y);

                            // don't draw the circle for the last node in the array
                            if (j < linearLine.lineNodeList.size() - 1 ) {
                                gRef.drawImage(curveNodeImage, (int) (startNodePos.getX() - sizeScaledHalf), (int) (startNodePos.getY() - sizeScaledHalf), sizeScaled, sizeScaled, null);
                            }
                            if ( connectionType == CONNECTION_DUAL ) {
                                colour = Color.BLUE;
                            } else if ( connectionType == CONNECTION_REVERSE ) {
                                colour = Color.CYAN;
                            }
                            gRef.setColor(colour);
                            drawArrowBetween(gRef, startNodePos, endNodePos, connectionType == CONNECTION_DUAL);

                        }
                    }  else {
                        if (linearLine.lineNodeList.size() == 1) {
                            if ( connectionType == CONNECTION_DUAL ) {
                                colour = Color.BLUE;
                            } else if ( connectionType == CONNECTION_REVERSE ) {
                                colour = Color.CYAN;
                            }

                            Point2D startNodePos = worldPosToScreenPos(linearLine.getLineStartNode().x, linearLine.getLineStartNode().z);
                            Point2D mousePos = new Point2D.Double(mousePosX,mousePosY);

                            drawlock.lock();
                            try {
                                gRef.setColor(colour);
                                drawArrowBetween(gRef, startNodePos, mousePos, connectionType == CONNECTION_DUAL);
                            } finally {
                                drawlock.unlock();
                            }
                        }
                    }
                } else {

                    Point2D startNodePos = worldPosToScreenPos(selected.x, selected.z);
                    Point2D mousePos = new Point2D.Double(mousePosX,mousePosY);

                    drawlock.lock();
                    try {
                        gRef.setColor(Color.WHITE);
                        drawArrowBetween(gRef, startNodePos, mousePos, false);
                    } finally {
                        drawlock.unlock();
                    }
                }
            }

            // Draw the quad curve connection preview

            if (quadCurve != null) {
                if (isQuadCurveCreated) {
                    // draw control point
                    Point2D nodePos = worldPosToScreenPos(quadCurve.getControlPoint().x, quadCurve.getControlPoint().z);
                    if (quadCurve.getControlPoint().selected || hoveredNode == quadCurve.getControlPoint()) {
                        gRef.drawImage(controlPointImageSelected, (int) (nodePos.getX() - sizeScaledHalf), (int) (nodePos.getY() - sizeScaledHalf), sizeScaled, sizeScaled, null);
                    } else {
                          gRef.drawImage(controlPointImage, (int) (nodePos.getX() - sizeScaledHalf), (int) (nodePos.getY() - sizeScaledHalf), sizeScaled, sizeScaled, null);
                    }

                    //draw interpolation points for curve
                    Color colour = Color.GREEN;
                    for (int j = 0; j < quadCurve.curveNodesList.size() - 1; j++) {

                        MapNode currentcoord = quadCurve.curveNodesList.get(j);
                        MapNode nextcoored = quadCurve.curveNodesList.get(j + 1);

                        Point2D currentNodePos = worldPosToScreenPos(currentcoord.x, currentcoord.z);
                        Point2D nextNodePos = worldPosToScreenPos(nextcoored.x, nextcoored.z);

                        //don't draw the first node as it already been drawn
                        if (j != 0) {
                            if (quadCurve.getNodeType() == NODE_STANDARD) {
                                gRef.drawImage(curveNodeImage,(int) (currentNodePos.getX() - sizeScaledHalf), (int) (currentNodePos.getY() - sizeScaledHalf), sizeScaled, sizeScaled, null);
                            } else {
                                gRef.drawImage(subPrioNodeImage,(int) (currentNodePos.getX() - (sizeScaledHalf / 2 )), (int) (currentNodePos.getY() - (sizeScaledHalf / 2 )), sizeScaledHalf, sizeScaledHalf, null);
                            }
                        }

                        if (quadCurve.isReversePath()) {
                            colour = Color.CYAN;
                        } else if (quadCurve.isDualPath() && quadCurve.getNodeType() == NODE_STANDARD) {
                            colour = Color.BLUE;
                        } else if (quadCurve.isDualPath() && quadCurve.getNodeType() == NODE_SUBPRIO) {
                            colour = BROWN;
                        } else if (currentcoord.flag == 1) {
                            colour = Color.ORANGE;
                        }

                        drawlock.lock();
                        try {
                            gRef.setColor(colour);
                            drawArrowBetween(gRef, currentNodePos, nextNodePos, quadCurve.isDualPath()) ;
                        } finally {
                            drawlock.unlock();
                        }
                    }
                }
            }

            // Draw the cubic curve connection preview

            if (cubicCurve != null) {
                if (isCubicCurveCreated) {
                    // draw control point
                    Point2D nodePos = worldPosToScreenPos(cubicCurve.getControlPoint1().x, cubicCurve.getControlPoint1().z);
                    if (cubicCurve.getControlPoint1().selected || hoveredNode == cubicCurve.getControlPoint1()) {
                        gRef.drawImage(controlPointImageSelected, (int) (nodePos.getX() - sizeScaledHalf), (int) (nodePos.getY() - sizeScaledHalf), sizeScaled, sizeScaled, null);
                    } else {
                        gRef.drawImage(controlPointImage, (int) (nodePos.getX() - sizeScaledHalf), (int) (nodePos.getY() - sizeScaledHalf), sizeScaled, sizeScaled, null);
                    }

                    nodePos = worldPosToScreenPos(cubicCurve.getControlPoint2().x, cubicCurve.getControlPoint2().z);
                    if (cubicCurve.getControlPoint2().selected || hoveredNode == cubicCurve.getControlPoint2()) {
                        gRef.drawImage(controlPointImageSelected, (int) (nodePos.getX() - sizeScaledHalf), (int) (nodePos.getY() - sizeScaledHalf), sizeScaled, sizeScaled, null);
                    } else {
                        gRef.drawImage(controlPointImage, (int) (nodePos.getX() - sizeScaledHalf), (int) (nodePos.getY() - sizeScaledHalf), sizeScaled, sizeScaled, null);
                    }

                    //draw interpolation points for curve
                    Color colour = Color.GREEN;
                    for (int j = 0; j < cubicCurve.curveNodesList.size() - 1; j++) {

                        MapNode currentcoord = cubicCurve.curveNodesList.get(j);
                        MapNode nextcoored = cubicCurve.curveNodesList.get(j + 1);

                        Point2D currentNodePos = worldPosToScreenPos(currentcoord.x, currentcoord.z);
                        Point2D nextNodePos = worldPosToScreenPos(nextcoored.x, nextcoored.z);

                        //don't draw the first node as it already been drawn
                        if (j != 0) {
                            if (cubicCurve.getNodeType() == NODE_STANDARD) {
                                gRef.drawImage(curveNodeImage,(int) (currentNodePos.getX() - sizeScaledHalf), (int) (currentNodePos.getY() - sizeScaledHalf), sizeScaled, sizeScaled, null);
                            } else {
                                gRef.drawImage(subPrioNodeImage,(int) (currentNodePos.getX() - (sizeScaledHalf / 2 )), (int) (currentNodePos.getY() - (sizeScaledHalf / 2 )), sizeScaledHalf, sizeScaledHalf, null);
                            }
                        }

                        if (cubicCurve.isReversePath()) {
                            colour = Color.CYAN;
                        } else if (cubicCurve.isDualPath() && cubicCurve.getNodeType() == NODE_STANDARD) {
                            colour = Color.BLUE;
                        } else if (cubicCurve.isDualPath() && cubicCurve.getNodeType() == NODE_SUBPRIO) {
                            colour = BROWN;
                        } else if (currentcoord.flag == 1) {
                            colour = Color.ORANGE;
                        }

                        drawlock.lock();
                        try {
                            gRef.setColor(colour);
                            drawArrowBetween(gRef, currentNodePos, nextNodePos, cubicCurve.isDualPath()) ;
                        } finally {
                            drawlock.unlock();
                        }
                    }
                }
            }

            // draw the right button selection rectangle

            if (rectangleStart != null) {

                int width = (int) (mousePosX - rectangleStart.getX());
                int height = (int) (mousePosY - rectangleStart.getY());
                int recX = Double.valueOf(rectangleStart.getX()).intValue();
                int recY = Double.valueOf(rectangleStart.getY()).intValue();
                if (width < 0) {
                    recX += width;
                    width = -width;
                }
                if (height < 0) {
                    recY += height;
                    height = -height;
                }

                drawlock.lock();
                try {
                    gRef.setColor(Color.WHITE);
                    gRef.drawRect(recX, recY, width, height);
                } finally {
                    drawlock.unlock();
                }
            }

            if (PROFILE) {
                String text = "Finished Node Rendering in " + (System.currentTimeMillis() - startTime) + " ms";
                showInTextArea(text,false);
            }

        }
    }

    //
    // The connection drawing thread finishes last in almost all cases, so we keep this as small as possible
    // we only draw the connections in the visible area (plus some extra padding so we don't see the
    // connections clipping.
    //

    static class ConnectionDrawThread implements Runnable {

        private Graphics gRef = null;
        private final int width;
        private final int height;
        private ConnectionDrawThread(Graphics graphics, int panelWidth, int panelHeight) {
            this.gRef = graphics;
            this.width = panelWidth;
            this.height = panelHeight;
        }

        @Override
        public void run() {

            long startTime = 0;

            if (PROFILE) {
                startTime = System.currentTimeMillis();
            }

            double currentNodeSize = nodeSize * zoomLevel * 0.5;

            if (gRef != null) {

                Color drawColour;

                LinkedList<MapNode> nodes = roadMap.mapNodes;
                for (MapNode mapNode : nodes) {
                    LinkedList<MapNode> mapNodes = mapNode.outgoing;
                    Point2D nodePos = worldPosToScreenPos(mapNode.x, mapNode.z);

                    if (0 - (40 * zoomLevel) < nodePos.getX() && width + (40 * zoomLevel) > nodePos.getX() && 0 - (40 * zoomLevel) < nodePos.getY() && height + (40 * zoomLevel) > nodePos.getY()) {
                        for (MapNode outgoing : mapNodes) {
                            boolean dual = RoadMap.isDual(mapNode, outgoing);
                            boolean reverse = RoadMap.isReverse(mapNode, outgoing);

                            if (dual && mapNode.flag == 1) {
                                drawColour = BROWN;
                            } else if (dual) {
                                drawColour = Color.BLUE;
                            } else if (reverse) {
                                drawColour = Color.CYAN;
                            } else if (mapNode.flag == 1) {
                                drawColour = Color.ORANGE;
                            } else {
                                drawColour = Color.GREEN;
                            }


                            Point2D outPos = worldPosToScreenPos(outgoing.x, outgoing.z);

                            drawlock.lock();
                            try {
                                gRef.setColor(drawColour);
                                drawArrowBetween(gRef, nodePos, outPos, dual);
                            } finally {
                                drawlock.unlock();
                            }
                        }
                    }
                }
            }
            if (PROFILE) {
                String text = "Finished Connection Rendering in " + (System.currentTimeMillis() - startTime) + " ms (" + zoomLevel +")";
                showInTextArea(text,false);
            }
        }
    }

    @Override
    protected void paintComponent(Graphics g) {
        super.paintComponent(g);





        if (PROFILE) {
            startTimer();
            showInTextArea("", true);
        }

        if (image != null) {
            g.clipRect(0, 0, this.getWidth(), this.getHeight());

            g.drawImage(resizedImage, 0, 0, this); // see javadoc for more info on the parameters

            int sizeScaled = (int) (nodeSize * zoomLevel);
            int sizeScaledHalf = (int) (sizeScaled * 0.5);

            if (roadMap != null) {
                connectionDraw = new Thread(new ConnectionDrawThread(g, this.getWidth(), this.getHeight()));
                connectionDraw.start();

                nodeDraw = new Thread( new NodeDrawThread(g, this.getWidth(), this.getHeight()));
                nodeDraw.start();

                try {
                    nodeDraw.join();
                    connectionDraw.join();

                } catch (InterruptedException e) {
                    e.printStackTrace();
                }
            }
        }
        if (PROFILE) {
            LOG.info("PaintComponent() finished in {} ms", stopTimer());
        }
    }

    private void resizeMap() throws RasterFormatException {

        if (PROFILE) {
            startTimer();
        }

        if (image != null) {
            int widthScaled = (int) (this.getWidth() / zoomLevel);
            int heightScaled = (int) (this.getHeight() / zoomLevel);

            // Part 1 of work around for map resize bug.. increase the zoomLevel
            // if widthScaled and heightScaled are bigger than the map image dimensions
            //
            // This will get us close, but the zoomLevel is still off by a small
            // amount and just moving the map in any direction will force MoveMapBy()
            // to run again and recalculate all the values so when run again ResizeMap()
            // will calculate it correctly.

            if ( (int) x + widthScaled > image.getWidth() ) {
                while ( widthScaled > image.getWidth() ) {
                    double step = -1 * (zoomLevel * 0.1);
                    if (DEBUG) LOG.info("widthScaled is out of bounds ( {} ) .. increasing zoomLevel by {}", widthScaled, step);
                    zoomLevel -= step;
                    widthScaled = (int) (this.getWidth() / zoomLevel);
                }
                if (DEBUG) LOG.info("widthScaled is {}", widthScaled);
            }

            if ( (int) y + heightScaled > image.getHeight() ) {
                while ( heightScaled > image.getHeight() ) {
                    double step = -1 * (zoomLevel * 0.1);
                    if (DEBUG) LOG.info("heightScaled is out of bounds ( {} ) .. increasing zoomLevel by {}", heightScaled, step);
                    zoomLevel -= step;
                    heightScaled = (int) (this.getHeight() / zoomLevel);
                }
                if (DEBUG) LOG.info("heightScaled is {}", heightScaled);
            }

            double calcX = ((this.getWidth() * 0.5) / zoomLevel) / image.getWidth();
            double calcY = ((this.getHeight() * 0.5) / zoomLevel) / image.getHeight();

            x = Math.min(x, 1 - calcX);
            x = Math.max(x, calcX);
            y = Math.min(y, 1 - calcY);
            y = Math.max(y, calcY);


            int centerX = (int) (x * image.getWidth());
            int centerY = (int) (y * image.getHeight());

            int offsetX = (centerX - (widthScaled / 2));
            int offsetY = (centerY - (heightScaled / 2));
            try {
                Image croppedImage = image.getSubimage(offsetX, offsetY, widthScaled, heightScaled);
                resizedImage = new BufferedImage(this.getWidth(), this.getHeight(), BufferedImage.TYPE_INT_RGB);
                Graphics2D g2 = (Graphics2D) resizedImage.getGraphics();

                g2.setRenderingHint(RenderingHints.KEY_ANTIALIASING, RenderingHints.VALUE_ANTIALIAS_OFF);
                g2.setRenderingHint(RenderingHints.KEY_ALPHA_INTERPOLATION, RenderingHints.VALUE_ALPHA_INTERPOLATION_SPEED);
                g2.setRenderingHint(RenderingHints.KEY_COLOR_RENDERING, RenderingHints.VALUE_COLOR_RENDER_SPEED);
                g2.setRenderingHint(RenderingHints.KEY_DITHERING, RenderingHints.VALUE_DITHER_DISABLE);
                g2.setRenderingHint(RenderingHints.KEY_FRACTIONALMETRICS, RenderingHints.VALUE_FRACTIONALMETRICS_OFF);
                g2.setRenderingHint(RenderingHints.KEY_INTERPOLATION, RenderingHints.VALUE_INTERPOLATION_NEAREST_NEIGHBOR);
                g2.setRenderingHint(RenderingHints.KEY_RENDERING, RenderingHints.VALUE_RENDER_SPEED);
                g2.setRenderingHint(RenderingHints.KEY_STROKE_CONTROL, RenderingHints.VALUE_STROKE_PURE);
                g2.setRenderingHint(RenderingHints.KEY_TEXT_ANTIALIASING, RenderingHints.VALUE_TEXT_ANTIALIAS_OFF);

                g2.drawImage(croppedImage, 0, 0, this.getWidth(), this.getHeight(), null);
                g2.dispose();
            } catch (Exception e) {
                LOG.info("## MapPanel.ResizeMap() ## Exception in getSubImage()");
                LOG.info("## MapPanel.ResizeMap() ## x = {} , y = {} , offsetX = {} , offsetY = {}  -- width = {} , height = {} , zoomlevel = {} , widthScaled = {} , heightScaled = {}", x, y, offsetX, offsetY, this.getWidth(), this.getHeight(), zoomLevel, widthScaled, heightScaled);
                e.printStackTrace();
            }

            if (PROFILE) {
                LOG.info("Finished ResizeMap() in {} ms", stopTimer());
            }

        }
    }

    public void moveMapBy(int diffX, int diffY) {
        if ((roadMap == null) || (image == null)) {
            return;
        }
        x -= diffX / (zoomLevel * image.getWidth());
        y -= diffY / (zoomLevel * image.getHeight());

        resizeMap();
        this.repaint();
    }

    public void increaseZoomLevelBy(int rotations) {
        double step = rotations * (zoomLevel * 0.1);
        if ((roadMap == null) || (image == null)) {
            return;
        }

        int widthScaled = (int) (this.getWidth() / zoomLevel);
        int heightScaled = (int) (this.getHeight() / zoomLevel);

        if (((this.getWidth()/(zoomLevel - step)) > image.getWidth()) || ((this.getHeight()/(zoomLevel - step)) > image.getHeight())){
            return;
        }

        if ((zoomLevel - step) < 30) {
            zoomLevel -= step;
            resizeMap();
            this.repaint();
        }
    }

    public void moveNodeBy(MapNode node, int diffX, int diffY) {

        double scaledDiffX = (diffX * mapZoomFactor) / zoomLevel;
        double scaledDiffY = (diffY * mapZoomFactor) / zoomLevel;

        if (isQuadCurveCreated) {
            if (node == quadCurve.getCurveStartNode()) {
                quadCurve.setCurveStartNode(node);
            } else if (node == quadCurve.getCurveEndNode()) {
                quadCurve.setCurveEndNode(node);
            }
            if (node == quadCurve.getControlPoint()) {
                quadCurve.updateControlPoint(scaledDiffX, scaledDiffY);
            }
        }

        if (isCubicCurveCreated) {
            if (node == cubicCurve.getCurveStartNode()) {
                cubicCurve.setCurveStartNode(node);
            } else if (node == cubicCurve.getCurveEndNode()) {
                cubicCurve.setCurveEndNode(node);
            }
            if (node == cubicCurve.getControlPoint1()) {
                cubicCurve.updateControlPoint1(scaledDiffX, scaledDiffY);
            }
            if (node == cubicCurve.getControlPoint2()) {
                cubicCurve.updateControlPoint2(scaledDiffX, scaledDiffY);
            }
        }

        node.x += scaledDiffX;
        node.z += scaledDiffY;
        this.repaint();

    }

    public MapNode getNodeAt(double posX, double posY) {

        MapNode selected = null;

        if ((roadMap != null) && (image != null)) {

            Point2D outPos;
            double currentNodeSize = nodeSize * zoomLevel * 0.5;

            // make sure we prioritize returning control nodes over regular nodes

            for (MapNode mapNode : roadMap.mapNodes) {
                outPos = worldPosToScreenPos(mapNode.x, mapNode.z);
                if (posX < outPos.getX() + currentNodeSize && posX > outPos.getX() - currentNodeSize && posY < outPos.getY() + currentNodeSize && posY > outPos.getY() - currentNodeSize) {
                    selected = mapNode;
                    break;
                }
            }

            if (isQuadCurveCreated) {
                outPos = worldPosToScreenPos(quadCurve.getControlPoint().x, quadCurve.getControlPoint().z);
                if (posX < outPos.getX() + currentNodeSize && posX > outPos.getX() - currentNodeSize && posY < outPos.getY() + currentNodeSize && posY > outPos.getY() - currentNodeSize) {
                    return quadCurve.getControlPoint();
                }
            }
            if (isCubicCurveCreated) {
                outPos = worldPosToScreenPos(cubicCurve.getControlPoint1().x, cubicCurve.getControlPoint1().z);
                if (posX < outPos.getX() + currentNodeSize && posX > outPos.getX() - currentNodeSize && posY < outPos.getY() + currentNodeSize && posY > outPos.getY() - currentNodeSize) {
                    return cubicCurve.getControlPoint1();
                }
                outPos = worldPosToScreenPos(cubicCurve.getControlPoint2().x, cubicCurve.getControlPoint2().z);
                if (posX < outPos.getX() + currentNodeSize && posX > outPos.getX() - currentNodeSize && posY < outPos.getY() + currentNodeSize && posY > outPos.getY() - currentNodeSize) {
                    return cubicCurve.getControlPoint2();
                }
            }
        }
        return selected;
    }

    public void removeNodes() {
        for (NodeLinks nodeLinks : deleteNodeList) {
            MapNode inList = nodeLinks.node;
            roadMap.removeMapNode(inList);
        }
        setStale(true);
        hoveredNode = null;
        this.repaint();
    }

    public void removeDestination(MapNode toDelete) {
        MapMarker destinationToDelete = null;
        LinkedList<MapMarker> mapMarkers = roadMap.mapMarkers;
        for (MapMarker mapMarker : mapMarkers) {
            if (mapMarker.mapNode.id == toDelete.id) {
                destinationToDelete = mapMarker;
            }
        }
        if (destinationToDelete != null) {
            changeManager.addChangeable( new ChangeManager.MarkerRemoveChanger(destinationToDelete));
            roadMap.removeMapMarker(destinationToDelete);
            setStale(true);
            this.repaint();
        }
    }

    public void createNode(double screenX, double screenY, int flag) {
        if ((roadMap == null) || (image == null)) {
            return;
        }
        MapNode mapNode = new MapNode(roadMap.mapNodes.size()+1, screenX, -1, screenY, flag, false); //flag = 0 causes created node to be regular by default
        roadMap.mapNodes.add(mapNode);
        this.repaint();
        changeManager.addChangeable( new AddNodeChanger(mapNode) );
        MapPanel.getMapPanel().setStale(true);
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

    public static Point2D worldPosToScreenPos(double worldX, double worldY) {

        int centerPointOffset = 1024 * mapZoomFactor;

        worldX += centerPointOffset;
        worldY += centerPointOffset;

        double scaledX = (worldX/mapZoomFactor) * zoomLevel;
        double scaledY = (worldY/mapZoomFactor) * zoomLevel;

        double centerXScaled = (x * (image.getWidth()*zoomLevel));
        double centerYScaled = (y * (image.getHeight()*zoomLevel));

        double topLeftX = centerXScaled - ((double) mapPanel.getWidth() /2);
        double topLeftY = centerYScaled - ((double) mapPanel.getHeight()/2);

        return new Point2D.Double(scaledX - topLeftX,scaledY - topLeftY);
    }

    public static void createConnectionBetween(MapNode start, MapNode target, int type) {
        if (start == target) {
            return;
        }

        if (!start.outgoing.contains(target)) {
            start.outgoing.add(target);

            if (type == CONNECTION_STANDARD) {
                if (!target.incoming.contains(start))
                target.incoming.add(start);
            } else if (type == CONNECTION_REVERSE ) {
                start.incoming.remove(target);
                target.incoming.remove(start);
                target.outgoing.remove(start);
            } else if (type == CONNECTION_DUAL) {
                if (!target.incoming.contains(start)) {
                    target.incoming.add(start);
                }
                if (!target.outgoing.contains(start)) {
                    target.outgoing.add(start);
                }
                if (!start.incoming.contains(target)) {
                    start.incoming.add(target);
                }
            }
        } else {
            if (type == CONNECTION_STANDARD) {
                start.outgoing.remove(target);
                target.incoming.remove(start);
            } else if (type == CONNECTION_REVERSE ) {
                start.outgoing.remove(target);
                start.incoming.remove(target);
                target.outgoing.remove(start);
                target.incoming.remove(start);

            } else if (type == CONNECTION_DUAL) {
                start.outgoing.remove(target);
                start.incoming.remove(target);
                target.incoming.remove(start);
                target.outgoing.remove(start);
            }
        }
    }

    public void createDestinationAt(MapNode mapNode, String destinationName, String groupName) {
        if (mapNode != null && destinationName != null && destinationName.length() > 0) {
            if (groupName == null) groupName = "All";
            MapMarker mapMarker = new MapMarker(mapNode, destinationName, groupName);
            changeManager.addChangeable( new ChangeManager.MarkerAddChanger(mapMarker));
            roadMap.addMapMarker(mapMarker);
            setStale(true);
        }
    }

    public void changeNodePriority(MapNode nodeToChange) {
        nodeToChange.flag = 1 - nodeToChange.flag;
        changeManager.addChangeable( new ChangeManager.NodePriorityChanger(nodeToChange));
        setStale(true);
        this.repaint();
    }

    public void removeAllNodesInScreenArea(Point2D rectangleStartScreen, Point2D rectangleEndScreen) {

        getAllNodesInArea(rectangleStartScreen, rectangleEndScreen);
        LOG.info("{}", localeString.getString("console_node_area_remove"));
        for (MapNode node : multiSelectList) {
            addToDeleteList(node);
            if (DEBUG) LOG.info("Added ID {} to delete list", node.id);
        }
        changeManager.addChangeable( new RemoveNodeChanger(deleteNodeList));
        removeNodes();
        deleteNodeList.clear();
        clearMultiSelection();
    }

    public void changeAllNodesPriInScreenArea(Point2D rectangleStartScreen, Point2D rectangleEndScreen) {

        getAllNodesInArea(rectangleStartScreen, rectangleEndScreen);
        if (!multiSelectList.isEmpty()) {
            for (MapNode node : multiSelectList) {
                node.flag = 1 - node.flag;
            }
        }
        changeManager.addChangeable( new ChangeManager.NodePriorityChanger(multiSelectList));
        setStale(true);
        clearMultiSelection();
    }

   public void getAllNodesInArea(Point2D rectangleStartScreen, Point2D rectangleEndScreen) {
       if ((roadMap == null) || (this.image == null)) {
           return;
       }
       int screenStartX = (int) rectangleStartScreen.getX();
       int screenStartY = (int) rectangleStartScreen.getY();
       int width = (int) (rectangleEndScreen.getX() - rectangleStartScreen.getX());
       int height = (int) (rectangleEndScreen.getY() - rectangleStartScreen.getY());

       Rectangle2D rectangle = ADUtils.getNormalizedRectangleFor(screenStartX, screenStartY, width, height);
       screenStartX = (int) rectangle.getX();
       screenStartY = (int) rectangle.getY();
       width = (int) rectangle.getWidth();
       height = (int) rectangle.getHeight();
       double currentNodeSize = nodeSize * zoomLevel * 0.5;

       LinkedList<MapNode> toChange = new LinkedList<>();
       for (MapNode mapNode : roadMap.mapNodes) {

           Point2D nodePos = worldPosToScreenPos(mapNode.x, mapNode.z);

           if (screenStartX < nodePos.getX() + currentNodeSize && (screenStartX + width) > nodePos.getX() - currentNodeSize && screenStartY < nodePos.getY() + currentNodeSize && (screenStartY + height) > nodePos.getY() - currentNodeSize) {

               if (multiSelectList.contains(mapNode)) {
                   multiSelectList.remove(mapNode);
                   mapNode.selected = false;
               } else {
                   multiSelectList.add(mapNode);
                   mapNode.selected = true;
               }
           }
       }

       if (isQuadCurveCreated) {
           MapNode controlPoint = quadCurve.getControlPoint();
           Point2D nodePos = worldPosToScreenPos(controlPoint.x, controlPoint.z);
           if (screenStartX < nodePos.getX() + currentNodeSize && (screenStartX + width) > nodePos.getX() - currentNodeSize && screenStartY < nodePos.getY() + currentNodeSize && (screenStartY + height) > nodePos.getY() - currentNodeSize) {
               if (multiSelectList.contains(controlPoint)) {
                   multiSelectList.remove(controlPoint);
                   controlPoint.selected = false;
               } else {
                   multiSelectList.add(controlPoint);
                   controlPoint.selected = true;
               }
           }
       }

       if (isCubicCurveCreated) {
           MapNode controlPoint1 = cubicCurve.getControlPoint1();
           MapNode controlPoint2 = cubicCurve.getControlPoint2();

           Point2D nodePos1 = worldPosToScreenPos(controlPoint1.x, controlPoint1.z);
           if (screenStartX < nodePos1.getX() + currentNodeSize && (screenStartX + width) > nodePos1.getX() - currentNodeSize && screenStartY < nodePos1.getY() + currentNodeSize && (screenStartY + height) > nodePos1.getY() - currentNodeSize) {
               if (multiSelectList.contains(controlPoint1)) {
                   multiSelectList.remove(controlPoint1);
                   controlPoint1.selected = false;
               } else {
                   multiSelectList.add(controlPoint1);
                   controlPoint1.selected = true;
               }
           }
           Point2D nodePos2 = worldPosToScreenPos(controlPoint1.x, controlPoint1.z);
           if (screenStartX < nodePos2.getX() + currentNodeSize && (screenStartX + width) > nodePos2.getX() - currentNodeSize && screenStartY < nodePos2.getY() + currentNodeSize && (screenStartY + height) > nodePos2.getY() - currentNodeSize) {
               if (multiSelectList.contains(controlPoint2)) {
                   multiSelectList.remove(controlPoint2);
                   controlPoint2.selected = false;
               } else {
                   multiSelectList.add(controlPoint2);
                   controlPoint2.selected = true;
               }
           }
       }

       if (multiSelectList.size() > 0) {
           isMultipleSelected = true;
       }

       if (DEBUG) LOG.info("Selected {} nodes", multiSelectList.size());
   }

    public static void clearMultiSelection() {
        if (multiSelectList != null && multiSelectList.size() > 0 ) {
            for (MapNode node : multiSelectList) {
                node.selected = false;
            }
            multiSelectList.clear();
        }
        isMultipleSelected = false;
    }

    public static void drawArrowBetween(Graphics g, Point2D start, Point2D target, boolean dual) {
        double vecX = start.getX() - target.getX();
        double vecY = start.getY() - target.getY();

        double angleRad = Math.atan2(vecY, vecX);

        angleRad = normalizeAngle(angleRad);

        double arrowLength = 1.3 * zoomLevel;

        double arrowLeft = normalizeAngle(angleRad + Math.toRadians(-20));
        double arrowLeftX = target.getX() + Math.cos(arrowLeft) * arrowLength;
        double arrowLeftY = target.getY() + Math.sin(arrowLeft) * arrowLength;

        double arrowRight = normalizeAngle(angleRad + Math.toRadians(20));
        double arrowRightX = target.getX() + Math.cos(arrowRight) * arrowLength;
        double arrowRightY = target.getY() + Math.sin(arrowRight) * arrowLength;

        // calculate where to start the line based around the circumference of the node

        double distCos = ((nodeSize * zoomLevel) * 0.5) * Math.cos(angleRad);
        double distSin = ((nodeSize * zoomLevel) * 0.5) * Math.sin(angleRad);

        double startX = start.getX() + -distCos;
        double startY = start.getY() + -distSin;

        // calculate where to finish the line based around the circumference of the node
        double endX = target.getX() + distCos;
        double endY = target.getY() + distSin;

        g.drawLine((int) startX, (int) startY, (int) endX, (int) endY);
        g.drawLine((int) endX, (int) endY, (int) arrowLeftX, (int) arrowLeftY);
        g.drawLine((int) endX, (int) endY, (int) arrowRightX, (int) arrowRightY);

        if (dual) {
            angleRad = normalizeAngle(angleRad+Math.PI);

            arrowLeft = normalizeAngle(angleRad + Math.toRadians(-20));
            arrowRight = normalizeAngle(angleRad + Math.toRadians(20));

            arrowLeftX = start.getX() + Math.cos(arrowLeft) * arrowLength;
            arrowLeftY = start.getY() + Math.sin(arrowLeft) * arrowLength;
            arrowRightX = start.getX() + Math.cos(arrowRight) * arrowLength;
            arrowRightY = start.getY() + Math.sin(arrowRight) * arrowLength;

            g.drawLine((int) startX, (int) startY, (int) arrowLeftX, (int) arrowLeftY);
            g.drawLine((int) startX, (int) startY, (int) arrowRightX, (int) arrowRightY);
        }
    }

    public void stopCurveEdit() {
        if (quadCurve != null) {
            quadCurve.clear();
            isQuadCurveCreated = false;
            isControlNodeSelected = false;
            quadCurve = null;

        }
        if (cubicCurve!= null) {
            cubicCurve.clear();
            isCubicCurveCreated = false;
            isControlNodeSelected = false;
            cubicCurve = null;
        }
    }

    //
    // Mouse movement and drag detection
    //

    public void mouseMoved(int x, int y) {
        if (image != null) {
            mousePosX = x;
            mousePosY = y;

            if (editorState == EDITORSTATE_CONNECTING && selected != null) {
                if (isDraggingRoute) {
                    Point2D pointerPos = screenPosToWorldPos(mousePosX, mousePosY);
                    linearLine.updateLine(pointerPos.getX(), pointerPos.getY());
                    this.repaint();
                }
            }
            if (editorState == EDITORSTATE_QUADRATICBEZIER && selected != null) {
                this.repaint();
            }
            if (editorState == EDITORSTATE_CUBICBEZIER && selected != null) {
                this.repaint();
            }
            movingNode = getNodeAt(x, y);
            if (movingNode != hoveredNode) {
                hoveredNode = movingNode;
                this.repaint();
            }
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
            moveDiffX += diffX;
            moveDiffY += diffY;
            if (editorState== EDITORSTATE_MOVING) {
                for (MapNode node : multiSelectList) {
                    moveNodeBy(node, diffX, diffY);
                }
            }
        }

        if (isControlNodeSelected) {
            int diffX = x - lastX;
            int diffY = y - lastY;
            lastX = x;
            lastY = y;

            if (quadCurve != null && movingNode == quadCurve.getControlPoint()) {
                moveNodeBy(quadCurve.getControlPoint(), diffX, diffY);
                quadCurve.updateCurve();
            }
            if (cubicCurve != null) {
                if ( movingNode == cubicCurve.getControlPoint1()) {
                    moveNodeBy(cubicCurve.getControlPoint1(), diffX, diffY);
                    cubicCurve.updateCurve();
                }
                if ( movingNode == cubicCurve.getControlPoint2()) {
                    moveNodeBy(cubicCurve.getControlPoint2(), diffX, diffY);
                    cubicCurve.updateCurve();
                }

            }
        }

        if (editorState == EDITORSTATE_QUADRATICBEZIER) {
            if (movingNode !=null && isQuadCurveCreated) {
                if (quadCurve != null) {
                    quadCurve.updateCurve();
                }
                this.repaint();
            }
        }

        if (editorState == EDITORSTATE_CUBICBEZIER) {
            if (movingNode !=null && isCubicCurveCreated) {
                if (cubicCurve != null) {
                    cubicCurve.updateCurve();
                }
                this.repaint();
            }
        }

        if (rectangleStart != null) {
            switch (editorState) {
                case EDITORSTATE_DELETE_NODES:
                case EDITORSTATE_CHANGE_NODE_PRIORITY:
                case EDITORSTATE_MOVING:
                case EDITORSTATE_ALIGN_HORIZONTAL:
                case EDITORSTATE_ALIGN_VERTICAL:
                case EDITORSTATE_CNP_SELECT:
                    this.repaint();
            }
        }
    }

    //
    // Left mouse button click/pressed/released states
    //

    public void mouseButton1Clicked(int x, int y) {

        movingNode = getNodeAt(x, y);

        if (editorState == EDITORSTATE_CREATE_PRIMARY_NODE) {
            Point2D worldPos = screenPosToWorldPos(x, y);
            createNode(worldPos.getX(), worldPos.getY(),NODE_STANDARD);
        }

        if (editorState == EDITORSTATE_CHANGE_NODE_PRIORITY) {
            MapNode changingNode = getNodeAt(x, y);
            if (changingNode != null) {
                if (changingNode.flag != NODE_CONTROLPOINT) {
                    changeNodePriority(changingNode);
                }
            }
        }

        if (editorState == EDITORSTATE_CREATE_SUBPRIO_NODE) {
            Point2D worldPos = screenPosToWorldPos(x, y);
            createNode(worldPos.getX(), worldPos.getY(),NODE_SUBPRIO);
        }

        if (editorState == EDITORSTATE_CREATING_DESTINATION) {
            if (movingNode != null) {
                for (int i = 0; i < roadMap.mapMarkers.size(); i++) {
                    MapMarker mapMarker = roadMap.mapMarkers.get(i);
                    if (mapMarker.mapNode == movingNode) {
                        LOG.info("{}", localeString.getString("console_marker_add_exists"));
                        return;
                    }
                }
                destInfo info = showNewMarkerDialog(movingNode.id);
                if (info != null && info.getName() != null) {
                    LOG.info("{} {} - Name = {} , Group = {}", localeString.getString("console_marker_add"), movingNode.id, info.getName(), info.getGroup());
                    createDestinationAt(movingNode, info.getName(), info.getGroup());
                    this.repaint();
                }
            }
        }

        if (editorState == EDITORSTATE_EDITING_DESTINATION) {
            if (movingNode != null) {
                for (int i = 0; i < roadMap.mapMarkers.size(); i++) {
                    MapMarker mapMarker = roadMap.mapMarkers.get(i);
                    if (mapMarker.mapNode == movingNode) {
                        destInfo info = showEditMarkerDialog(mapMarker.mapNode.id, mapMarker.name, mapMarker.group);
                        if (info != null && info.getName() != null) {
                            LOG.info("{} {} - old name = {} , old group = {}", localeString.getString("console_marker_modify"), movingNode.id, info.getName(), info.getGroup());
                            changeManager.addChangeable( new MarkerEditChanger(mapMarker.mapNode, movingNode.id, mapMarker.name, info.getName(), mapMarker.group, info.getGroup()));
                            mapMarker.name = info.getName();
                            mapMarker.group = info.getGroup();
                            setStale(true);
                        }
                    }
                }
            }
        }
        if (editorState == EDITORSTATE_ALIGN_HORIZONTAL) {
            if (DEBUG) LOG.info("{} , {} , {}", isMultipleSelected, multiSelectList.size(), movingNode);
            if (isMultipleSelected && multiSelectList != null && movingNode != null) {
                LOG.info("Horizontal Align {} nodes at {}",multiSelectList.size(), movingNode.y);
                changeManager.addChangeable( new AlignmentChanger(multiSelectList, 0, movingNode.z));
                for (MapNode node : multiSelectList) {
                    node.z = movingNode.z;
                }
                if (isQuadCurveCreated) {
                    quadCurve.updateCurve();
                }
                setStale(true);
                clearMultiSelection();
                this.repaint();
            }
        }

        if (editorState == EDITORSTATE_ALIGN_VERTICAL) {
            if (isMultipleSelected && multiSelectList != null && movingNode != null) {
                LOG.info("Vertical Align {} nodes at {}",multiSelectList.size(), movingNode.x);
                changeManager.addChangeable( new AlignmentChanger(multiSelectList, movingNode.x, 0));
                for (MapNode node : multiSelectList) {
                    node.x = movingNode.x;
                }
                if (isQuadCurveCreated) {
                    quadCurve.updateCurve();
                }
                setStale(true);
                clearMultiSelection();
                this.repaint();

            }
        }

        if (editorState == EDITORSTATE_QUADRATICBEZIER) {
            if (movingNode != null) {
                if (selected == null && !isQuadCurveCreated) {
                    selected = movingNode;
                    GUIBuilder.showInTextArea(localeString.getString("quadcurve_start"), true);
                } else if (selected == hoveredNode) {
                    selected = null;
                    GUIBuilder.showInTextArea(localeString.getString("quadcurve_cancel"), true);
                    stopCurveEdit();
                    this.repaint();
                } else {
                    if (!isQuadCurveCreated) {
                        GUIBuilder.showInTextArea(localeString.getString("quadcurve_complete"), true);
                        quadCurve = new QuadCurve(selected, movingNode);
                        quadCurve.setNumInterpolationPoints(GUIBuilder.numIterationsSlider.getValue());
                        isQuadCurveCreated = true;
                        selected = null;
                    }
                }
                this.repaint();
            }
        }

        if (editorState == EDITORSTATE_CUBICBEZIER) {
            if (movingNode != null) {
                if (selected == null && !isCubicCurveCreated) {
                    selected = movingNode;
                    GUIBuilder.showInTextArea(localeString.getString("quadcurve_start"), true);
                } else if (selected == hoveredNode) {
                    selected = null;
                    GUIBuilder.showInTextArea(localeString.getString("quadcurve_cancel"), true);
                    stopCurveEdit();
                    this.repaint();
                } else {
                    if (!isCubicCurveCreated) {
                        GUIBuilder.showInTextArea(localeString.getString("quadcurve_complete"), true);
                        cubicCurve = new CubicCurve(selected, movingNode);
                        cubicCurve.setNumInterpolationPoints(GUIBuilder.numIterationsSlider.getValue());
                        isCubicCurveCreated = true;
                        selected = null;
                    }
                }
                this.repaint();
            }
        }
    }

    public void mouseButton1Pressed(int x, int y) {
        if (!bMiddleMouseMove) isDragging = true;
        lastX = x;
        lastY = y;
        movingNode = getNodeAt(x, y);

        if (editorState == EDITORSTATE_CONNECTING) {
            if (movingNode != null) {
                if (selected == null) {
                    selected = movingNode;
                    Point2D pointerPos = screenPosToWorldPos(mousePosX, mousePosY);
                    linearLine = new LinearLine(selected, pointerPos.getX(), pointerPos.getY());
                    isDraggingRoute = true;
                    GUIBuilder.showInTextArea(localeString.getString("linearline_start"), true);
                } else if (selected == hoveredNode) {
                    selected = null;
                    GUIBuilder.showInTextArea(localeString.getString("linearline_cancel"), true);
                } else {
                    int nodeType = 0;
                    if (connectionType == CONNECTION_STANDARD) {
                        nodeType = createRegularConnectionState;
                    } else if (connectionType == CONNECTION_DUAL) {
                        nodeType = createDualConnectionState;
                    } else if (connectionType == CONNECTION_REVERSE) {
                        nodeType = createReverseConnectionState;
                    }

                    linearLine.commit(movingNode, connectionType, nodeType);
                    GUIBuilder.showInTextArea(localeString.getString("linearline_complete"), true);
                    linearLine.clear();
                    MapPanel.getMapPanel().setStale(true);

                    if (AutoDriveEditor.bContinuousConnections) {
                        selected = movingNode;
                        Point2D pointerPos = screenPosToWorldPos(mousePosX, mousePosY);
                        linearLine = new LinearLine(movingNode, pointerPos.getX(), pointerPos.getY());
                    } else {
                        isDraggingRoute = false;
                        selected = null;
                    }
                }
                this.repaint();
            }
        }

        if (editorState == EDITORSTATE_QUADRATICBEZIER) {
            if (isQuadCurveCreated && movingNode == quadCurve.getControlPoint()) {
                    isControlNodeSelected = true;
            }
        }

        if (editorState == EDITORSTATE_CUBICBEZIER) {
            if (isCubicCurveCreated) {
                if (movingNode == cubicCurve.getControlPoint1() || movingNode == cubicCurve.getControlPoint2()) {
                    isControlNodeSelected = true;
                }
            }
        }

        if (movingNode != null) {
            isDragging = false;
            if (editorState == EDITORSTATE_MOVING) {
                moveDiffX = 0;
                moveDiffY = 0;
                isDraggingNode = true;
                if (!multiSelectList.contains(movingNode)) {
                    multiSelectList.add(movingNode);
                }
            }
            if (editorState == EDITORSTATE_DELETE_NODES) {
                addToDeleteList(movingNode);
                changeManager.addChangeable( new RemoveNodeChanger(deleteNodeList));
                removeNodes();
                deleteNodeList.clear();
                clearMultiSelection();
            }
            if (editorState == EDITORSTATE_DELETING_DESTINATION) {
                removeDestination(movingNode);
            }
        }
    }

    public void mouseButton1Released(int x, int y) {
        if (!bMiddleMouseMove) isDragging = false;
        if (isDraggingNode) {
            changeManager.addChangeable( new MoveNodeChanger(multiSelectList, moveDiffX, moveDiffY));
            setStale(true);
            clearMultiSelection();
        }
        isDraggingNode = false;
        isControlNodeSelected=false;
    }

    //
    // Middle mouse button click/pressed/released states
    //

    public void mouseButton2Clicked(int x, int y) {}

    public void mouseButton2Pressed(int x, int y) {
        if (bMiddleMouseMove) {
            isDragging = true;
            lastX = x;
            lastY = y;
        }

    }

    public void mouseButton2Released() {
        if (bMiddleMouseMove) isDragging = false;
    }

    //
    // Right mouse button click/pressed/released states
    //

    public void mouseButton3Clicked(int x, int y) {
        clearMultiSelection();
        this.repaint();
    }

    public void mouseButton3Pressed(int x, int y) {

        if (editorState == EDITORSTATE_CONNECTING) {
            selected = null;
            if (linearLine != null ) linearLine.clear();
            GUIBuilder.showInTextArea("",true);
            this.repaint();
            return;
        }

        if (isMultiSelectAllowed) {
            rectangleStart = new Point2D.Double(x, y);
            LOG.info("{} {}/{}", localeString.getString("console_rect_start"), x, y);
        }
    }

    public void mouseButton3Released(int x, int y) {
        if (rectangleStart != null) {

            Point2D rectangleEnd = new Point2D.Double(x, y);
            LOG.info("{} {}/{}", localeString.getString("console_rect_end"), x, y);
            LOG.info("Rectangle centre = {} , {}", rectangleEnd.getX() - rectangleStart.getX(), rectangleEnd.getY() - rectangleStart.getY());

            switch (editorState) {
                case EDITORSTATE_DELETE_NODES:
                    removeAllNodesInScreenArea(rectangleStart, rectangleEnd);
                    this.repaint();
                    break;
                case EDITORSTATE_CHANGE_NODE_PRIORITY:
                    LOG.info("{}", localeString.getString("console_node_priority_toggle"));
                    changeAllNodesPriInScreenArea(rectangleStart, rectangleEnd);
                    this.repaint();
                    break;
                case EDITORSTATE_MOVING:
                    LOG.info("{}", localeString.getString("console_node_priority_toggle"));
                    getAllNodesInArea(rectangleStart, rectangleEnd);
                    this.repaint();
                    break;
                case EDITORSTATE_ALIGN_HORIZONTAL:
                    LOG.info("{}", localeString.getString("console_node_align_horizontal"));
                    getAllNodesInArea(rectangleStart, rectangleEnd);
                    this.repaint();
                    break;
                case EDITORSTATE_ALIGN_VERTICAL:
                    LOG.info("{}", localeString.getString("console_node_align_vertical"));
                    getAllNodesInArea(rectangleStart, rectangleEnd);
                    this.repaint();
                    break;
                case EDITORSTATE_CNP_SELECT:
                    getAllNodesInArea(rectangleStart, rectangleEnd);
                    this.repaint();
            }
            rectangleStart = null;
        }
    }

    public static void addToDeleteList(MapNode node) {
        LinkedList<MapNode> otherNodesInLinks = new LinkedList<>();
        LinkedList<MapNode> otherNodesOutLinks = new LinkedList<>();

        LinkedList<MapNode> roadmapNodes = roadMap.mapNodes;
        for (MapNode mapNode : roadmapNodes) {
            if (mapNode != node) {
                if (mapNode.outgoing.contains(node)) {
                    otherNodesOutLinks.add(mapNode);
                }
                if (mapNode.incoming.contains(node)) {
                    otherNodesInLinks.add(mapNode);
                }
            }

        }
        MapMarker linkedMarker = null;
        LinkedList<MapMarker> mapMarkers = roadMap.mapMarkers;
        for (MapMarker mapMarker : mapMarkers) {
            if (mapMarker.mapNode == node) {
                if (DEBUG) LOG.info("## MapNode ID {} has a linked MapMarker ## storing in case undo system needs it", node.id);
                linkedMarker = mapMarker;
            }
        }
        // NOTE.. linkedMarker is safe to be passed as null, just means no marker is linked to that node
        deleteNodeList.add(new NodeLinks(node, otherNodesInLinks, otherNodesOutLinks, linkedMarker));
    }


    //
    // Dialogs for marker add/edit
    //

    private destInfo showNewMarkerDialog(int id) {

        JTextField destName = new JTextField();
        String[] group = new String[1];

        ArrayList<String> groupArray = new ArrayList<>();
        LinkedList<MapMarker> mapMarkers = roadMap.mapMarkers;
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
        LinkedList<MapMarker> mapMarkers = roadMap.mapMarkers;
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

   //
   // getter and setters
   //

    public static MapPanel getMapPanel() {
        return mapPanel;
    }

    public BufferedImage getImage() {
        return image;
    }

    public void setImage(BufferedImage loadedImage) {
        if (loadedImage != null) {
            LOG.info("Selected Image size is {} x {}",loadedImage.getWidth(), loadedImage.getHeight());
            if (loadedImage.getWidth() != 2048 || loadedImage.getHeight() != 2048 ) {
                int response = JOptionPane.showConfirmDialog(null, "" + localeString.getString("dialog_mapimage_incorrect_size1") + "\n\n" + localeString.getString("dialog_mapimage_incorrect_size2"), "AutoDrive", JOptionPane.DEFAULT_OPTION, JOptionPane.ERROR_MESSAGE);
                LOG.info("{} ... {}", localeString.getString("dialog_mapimage_incorrect_size1"), localeString.getString("dialog_mapimage_incorrect_size2"));
                return;
            }
            GraphicsEnvironment ge = GraphicsEnvironment.getLocalGraphicsEnvironment();
            GraphicsDevice gd = ge.getDefaultScreenDevice();
            GraphicsConfiguration gc = gd.getDefaultConfiguration();
            this.image = gc.createCompatibleImage(loadedImage.getWidth(), loadedImage.getHeight());
            Graphics2D g2d = (Graphics2D) this.image.getGraphics();

            // actually draw the image and dispose of context no longer needed
            g2d.drawImage(loadedImage, 0, 0, null);
            g2d.dispose();
            //..this.image = image;
            if (!oldConfigFormat) {
                GUIBuilder.updateGUIButtons(true);
                GUIBuilder.saveMenuEnabled(true);
                GUIBuilder.editMenuEnabled(true);
            }
        }
    }

    public RoadMap getRoadMap() {
        return roadMap;
    }

    public void setRoadMap(RoadMap roadMap) {
        MapPanel.roadMap = roadMap;
    }

    public void setMapZoomFactor(int mapZoomFactor) {
        this.mapZoomFactor = mapZoomFactor;
    }

    public boolean isStale() {
        return stale;
    }

    public void setStale(boolean newStale) {
        if (isStale() != newStale) {
            stale = newStale;
            editor.setTitle(createTitle());
        }
    }

    //
    //
    //

    public static class NodeLinks {

        public MapNode node;
        public int nodeIDbackup;
        public LinkedList<MapNode> otherIncoming;
        public LinkedList<MapNode> otherOutgoing;
        public MapMarker linkedMarker;

        public NodeLinks(MapNode mapNode, LinkedList<MapNode> in, LinkedList<MapNode> out, MapMarker marker) {
            this.node = mapNode;
            this.nodeIDbackup = mapNode.id;
            this.otherIncoming = new LinkedList<>();
            this.otherOutgoing = new LinkedList<>();
            this.linkedMarker = marker;

            for (int i = 0; i <= in.size() - 1 ; i++) {
                MapNode inNode = in.get(i);
                if (!this.otherIncoming.contains(inNode)) this.otherIncoming.add(inNode);
            }
            for (int i = 0; i <= out.size() - 1 ; i++) {
                MapNode outNode = out.get(i);
                if (!this.otherOutgoing.contains(outNode)) this.otherOutgoing.add(outNode);
            }
        }
    }
}
