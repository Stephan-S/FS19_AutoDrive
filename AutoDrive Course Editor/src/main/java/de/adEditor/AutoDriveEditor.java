package de.adEditor;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.w3c.dom.Document;
import org.w3c.dom.Element;
import org.w3c.dom.Node;
import org.w3c.dom.NodeList;
import org.xml.sax.SAXException;

import javax.imageio.ImageIO;
import javax.swing.*;
import javax.xml.parsers.DocumentBuilder;
import javax.xml.parsers.DocumentBuilderFactory;
import javax.xml.parsers.ParserConfigurationException;
import javax.xml.transform.OutputKeys;
import javax.xml.transform.Transformer;
import javax.xml.transform.TransformerFactory;
import javax.xml.transform.dom.DOMSource;
import javax.xml.transform.stream.StreamResult;
import java.awt.*;
import java.awt.image.BufferedImage;
import java.io.File;
import java.io.IOException;
import java.io.UnsupportedEncodingException;
import java.net.URL;
import java.net.URLDecoder;
import java.util.LinkedList;
import java.util.Map;
import java.util.TreeMap;

public class AutoDriveEditor extends JFrame {
    public static final int EDITORSTATE_MOVING = 0;
    public static final int EDITORSTATE_DELETING = 1;
    public static final int EDITORSTATE_CONNECTING = 2;
    public static final int EDITORSTATE_CREATING = 3;
    public static final int EDITORSTATE_DELETING_DESTINATION = 4;
    public static final int EDITORSTATE_CREATING_DESTINATION = 5;
    public static final String MOVE_NODES = "Move Nodes";
    public static final String CONNECT_NODES = "Connect Nodes";
    public static final String REMOVE_NODES = "Remove Nodes";
    public static final String REMOVE_DESTINATIONS = "Remove Destinations";
    public static final String CREATE_NODES = "Create Nodes";
    public static final String CREATE_DESTINATIONS = "Create Destinations";


    public MapPanel mapPanel;
    public JPanel buttonPanel;
    public JButton saveButton;
    public JButton loadRoadMapButton;
    public JButton loadImageButton;
    public JToggleButton removeNode;
    public JToggleButton removeDestination;
    public JToggleButton moveNode;
    public JToggleButton connectNodes;
    public JToggleButton createNode;
    public JToggleButton createDestination;
    public JToggleButton fourTimesMap;
    public JToggleButton sixteenTimesMap;

    public MapNode selected = null;

    public boolean isFourTimesMap = false;
    public boolean isSixteenTimesMap = false;

    public int editorState = EDITORSTATE_MOVING;

    public EditorListener editorListener;

    public MouseListener mouseListener;

    public File loadedFile, savedFile;

    private static Logger LOG = LoggerFactory.getLogger(AutoDriveEditor.class);


    public AutoDriveEditor() {
        super("AutoDrive Course Editor 0.1");

        LOG.info("AutoDrive start.............................................................................................");
        this.setLayout(new BorderLayout());

        // create a new panel with GridBagLayout manager
        mapPanel = new MapPanel(this);

        // set border for the panel
        mapPanel.setBorder(BorderFactory.createTitledBorder(
                BorderFactory.createEtchedBorder(), "Map Panel"));

        // add the panel to this frame
        add(mapPanel, BorderLayout.CENTER);

        this.editorListener = new EditorListener(this);

        buttonPanel = new JPanel(new FlowLayout());

        loadRoadMapButton = new JButton("Load Config");
        loadRoadMapButton.addActionListener(this.editorListener);
        loadRoadMapButton.setActionCommand("Load");
        buttonPanel.add(loadRoadMapButton);

        loadImageButton = new JButton("Load Map");
        loadImageButton.addActionListener(this.editorListener);
        loadImageButton.setActionCommand("Load Image");
        buttonPanel.add(loadImageButton);

        moveNode = new JToggleButton("Move Nodes");
        moveNode.addActionListener(this.editorListener);
        moveNode.setActionCommand(MOVE_NODES);
        buttonPanel.add(moveNode);

        connectNodes = new JToggleButton("Connect Nodes");
        connectNodes.addActionListener(this.editorListener);
        connectNodes.setActionCommand(CONNECT_NODES);
        connectNodes.setName(CONNECT_NODES);
        buttonPanel.add(connectNodes);

        removeNode = new JToggleButton("Delete Nodes");
        removeNode.addActionListener(this.editorListener);
        removeNode.setActionCommand(REMOVE_NODES);
        buttonPanel.add(removeNode);

        removeDestination = new JToggleButton("Delete Destination");
        removeDestination.addActionListener(this.editorListener);
        removeDestination.setActionCommand(REMOVE_DESTINATIONS);
        buttonPanel.add(removeDestination);

        createNode = new JToggleButton("Create Node");
        createNode.addActionListener(this.editorListener);
        createNode.setActionCommand(CREATE_NODES);
        buttonPanel.add(createNode);

        createDestination = new JToggleButton("Create Destination");
        createDestination.addActionListener(this.editorListener);
        createDestination.setActionCommand(CREATE_DESTINATIONS);
        buttonPanel.add(createDestination);

        fourTimesMap = new JToggleButton(" 4x");
        fourTimesMap.addActionListener(this.editorListener);
        fourTimesMap.setActionCommand("FourTimesMap");
        buttonPanel.add(fourTimesMap);

        sixteenTimesMap = new JToggleButton(" 16x");
        sixteenTimesMap.addActionListener(this.editorListener);
        sixteenTimesMap.setActionCommand("SixteenTimesMap");
        buttonPanel.add(sixteenTimesMap);

        saveButton = new JButton("Save");
        saveButton.addActionListener(this.editorListener);
        saveButton.setActionCommand("Save");
        buttonPanel.add(saveButton);

        updateButtons();

        this.add(buttonPanel, BorderLayout.NORTH);


        this.mouseListener = new MouseListener(mapPanel);

        mapPanel.addMouseListener(mouseListener);
        mapPanel.addMouseMotionListener(mouseListener);
        mapPanel.addMouseWheelListener(mouseListener);

        pack();
        setLocationRelativeTo(null);
        this.setDefaultCloseOperation(JFrame.EXIT_ON_CLOSE);
    }

    public void updateButtons() {
        moveNode.setSelected(false);
        connectNodes.setSelected(false);
        removeNode.setSelected(false);
        removeDestination.setSelected(false);
        createNode.setSelected(false);
        createDestination.setSelected(false);

        switch (editorState) {
            case EDITORSTATE_MOVING:
                moveNode.setSelected(true);
                break;
            case EDITORSTATE_DELETING:
                removeNode.setSelected(true);
                break;
            case EDITORSTATE_CONNECTING:
                connectNodes.setSelected(true);
                break;
            case EDITORSTATE_CREATING:
                createNode.setSelected(true);
                break;
            case EDITORSTATE_DELETING_DESTINATION:
                removeDestination.setSelected(true);
                break;
            case EDITORSTATE_CREATING_DESTINATION:
                createDestination.setSelected(true);
                break;
        }
    }

    public static void main(String[] args) {
        // set look and feel to the system look and feel
        try {
            UIManager.setLookAndFeel(UIManager.getSystemLookAndFeelClassName());
        } catch (Exception ex) {
            LOG.error(ex.getMessage(), ex);
        }

        SwingUtilities.invokeLater(new Runnable() {
            @Override
            public void run() {
                new AutoDriveEditor().setVisible(true);
            }
        });
    }

    public RoadMap loadFile(String path) throws ParserConfigurationException, IOException, SAXException {
        File fXmlFile = new File(path);
        DocumentBuilderFactory dbFactory = DocumentBuilderFactory.newInstance();
        DocumentBuilder dBuilder = dbFactory.newDocumentBuilder();
        Document doc = dBuilder.parse(fXmlFile);
        doc.getDocumentElement().normalize();

        LOG.info("Root element :{}", doc.getDocumentElement().getNodeName());

        NodeList markerList = doc.getElementsByTagName("mapmarker");
        LinkedList<MapMarker> mapMarkers = new LinkedList<>();

        TreeMap<Integer, MapMarker> mapMarkerTree = new TreeMap<>();
        for (int temp = 0; temp < markerList.getLength(); temp++) {
            Node markerNode = markerList.item(temp);
            if (markerNode.getNodeType() == Node.ELEMENT_NODE) {
                Element eElement = (Element) markerNode;

                NodeList idNodeList = eElement.getElementsByTagName("id");
                NodeList nameNodeList = eElement.getElementsByTagName("name");
                NodeList groupNodeList = eElement.getElementsByTagName("group");

                for (int markerIndex = 0; markerIndex<idNodeList.getLength(); markerIndex++ ) {
                    Node node = (Node) idNodeList.item(markerIndex).getChildNodes().item(0);
                    String markerNodeId = node.getNodeValue();

                    node = (Node) nameNodeList.item(markerIndex).getChildNodes().item(0);
                    String markerName = node.getNodeValue();

                    node = (Node) groupNodeList.item(markerIndex).getChildNodes().item(0);
                    String markerGroup = node.getNodeValue();

                    MapNode dummyNode = new MapNode((int)Double.parseDouble(markerNodeId), 0, 0, 0);
                    MapMarker mapMarker = new MapMarker(dummyNode, markerName, markerGroup);
                    mapMarkerTree.put((int)Double.parseDouble(markerNodeId), mapMarker);
                }
            }
        }

        NodeList nList = doc.getElementsByTagName("waypoints");

        LOG.info("----------------------------");

        LinkedList<MapNode> nodes = new LinkedList<>();
        for (int temp = 0; temp < nList.getLength(); temp++) {

            Node nNode = nList.item(temp);

            LOG.info("Current Element :{}", nNode.getNodeName());

            if (nNode.getNodeType() == Node.ELEMENT_NODE) {
                Element eElement = (Element) nNode;

                NodeList nodeList = eElement.getElementsByTagName("id").item(0).getChildNodes();
                Node node = (Node) nodeList.item(0);
                String idString = node.getNodeValue();
                String[] ids = idString.split(",");

                nodeList = eElement.getElementsByTagName("x").item(0).getChildNodes();
                node = (Node) nodeList.item(0);
                String xString = node.getNodeValue();
                String[] xValues = xString.split(",");

                nodeList = eElement.getElementsByTagName("y").item(0).getChildNodes();
                node = (Node) nodeList.item(0);
                String yString = node.getNodeValue();
                String[] yValues = yString.split(",");

                nodeList = eElement.getElementsByTagName("z").item(0).getChildNodes();
                node = (Node) nodeList.item(0);
                String zString = node.getNodeValue();
                String[] zValues = zString.split(",");

                nodeList = eElement.getElementsByTagName("out").item(0).getChildNodes();
                node = (Node) nodeList.item(0);
                String outString = node.getNodeValue();
                String[] outValueArrays = outString.split(";");

                nodeList = eElement.getElementsByTagName("incoming").item(0).getChildNodes();
                node = (Node) nodeList.item(0);
                String incomingString = node.getNodeValue();
                String[] incomingValueArrays = incomingString.split(";");

                for (int i=0; i<ids.length; i++) {
                    int id = Integer.parseInt(ids[i]);
                    double x = Double.parseDouble(xValues[i]);
                    double y = Double.parseDouble(yValues[i]);
                    double z = Double.parseDouble(zValues[i]);

                    if (isFourTimesMap && !isSixteenTimesMap) {
                        x = (x)/2.0;
                        z = (z)/2.0;
                    }
                    if (isSixteenTimesMap && !isFourTimesMap) {
                        x = (x)/4.0;
                        z = (z)/4.0;
                    }

                    MapNode mapNode = new MapNode(id, x, y, z);
                    nodes.add(mapNode);
                }


                for (Map.Entry<Integer, MapMarker> entry : mapMarkerTree.entrySet())
                {
                    mapMarkers.add(new MapMarker(nodes.get(entry.getKey()-1), entry.getValue().name, entry.getValue().group));
                }

                for (int i=0; i<ids.length; i++) {
                    MapNode mapNode = nodes.get(i);
                    String[] outNodes = outValueArrays[i].split(",");
                    for (int out=0; out<outNodes.length; out++) {
                        if (Integer.parseInt(outNodes[out]) != -1) {
                            mapNode.outgoing.add(nodes.get(Integer.parseInt(outNodes[out]) - 1));
                        }
                    }
                }

                for (int i=0; i<ids.length; i++) {
                    MapNode mapNode = nodes.get(i);
                    String[] incomingNodes = incomingValueArrays[i].split(",");
                    for (int incoming=0; incoming<incomingNodes.length; incoming++) {
                        if (Integer.parseInt(incomingNodes[incoming]) != -1) {
                            mapNode.incoming.add(nodes.get(Integer.parseInt(incomingNodes[incoming])-1));
                        }
                    }
                }
            }
        }

        RoadMap roadMap = new RoadMap();
        roadMap.mapNodes = nodes;
        roadMap.mapMarkers = mapMarkers;

        Node ADNode = doc.getElementsByTagName("AutoDrive").item(0);
        NodeList adNodes = ADNode.getChildNodes();
        Node mapNameNode = nList.item(0).getParentNode();
        String mapName = mapNameNode.getNodeName();
        LOG.info("Loaded config for map: {}", mapNameNode.getNodeName());

        String mapPath = "/mapImages/" + mapName + ".png";
        URL url = AutoDriveEditor.class.getResource(mapPath);

        BufferedImage image = null;
        try {
            image = ImageIO.read(url);
        } catch (Exception e) {
            try {
                mapPath = "./mapImages/" + mapName + ".png";
                image = ImageIO.read(new File(mapPath));
            } catch (Exception e1) {
                try {
                    mapPath = "./src/mapImages/" + mapName + ".png";
                    image = ImageIO.read(new File(mapPath));
                } catch (Exception e2) {
                    try {
                        mapPath = "./" + mapName + ".png";
                        image = ImageIO.read(new File(mapPath));
                    } catch (Exception e3) {
                        LOG.info("Editor has no map file for map: {}", mapName);
                    }
                }
            }
        }

        if (image != null) {
            mapPanel.image = image;
        }

        if (mapPanel.image != null) {
            mapPanel.setPreferredSize(new Dimension(1024, 768));
            mapPanel.setMinimumSize(new Dimension(1024, 768));
            pack();
            repaint();
            mapPanel.repaint();
        }

        return roadMap;

    }

    public void saveMap(String oldPath, String newPath) {
        LOG.info("SaveMap called");
        try {
            String filepath = oldPath;
            File file = null;
            try {
                filepath = URLDecoder.decode(filepath, "UTF-8");
                file = new File(filepath);
            } catch(UnsupportedEncodingException e) {
                LOG.error(e.getMessage(), e);
            }
            DocumentBuilderFactory docFactory = DocumentBuilderFactory.newInstance();
            DocumentBuilder docBuilder = docFactory.newDocumentBuilder();
            Document doc = null;
            if (file != null) {
                doc = docBuilder.parse(file);
            }
            else {
                doc = docBuilder.parse(filepath);
            }

            Node AutoDrive = doc.getFirstChild();
            Element root = doc.getDocumentElement();

            Node waypoints = doc.getElementsByTagName("waypoints").item(0);


            // loop the staff child node
            NodeList list = waypoints.getChildNodes();

            for (int i = 0; i < list.getLength(); i++) {
                Node node = list.item(i);

                if ("id".equals(node.getNodeName())) {
                    String ids = "";
                    for (int j=0; j<mapPanel.roadMap.mapNodes.size(); j++) {
                        MapNode mapNode = mapPanel.roadMap.mapNodes.get(j);
                        ids += mapNode.id;
                        if (j < (mapPanel.roadMap.mapNodes.size()-1)) {
                            ids = ids + ",";
                        }
                    }
                    node.setTextContent(ids);
                }
                if ("x".equals(node.getNodeName())) {
                    String xPositions = "";
                    for (int j=0; j<mapPanel.roadMap.mapNodes.size(); j++) {
                        MapNode mapNode = mapPanel.roadMap.mapNodes.get(j);
                        if (isFourTimesMap || isSixteenTimesMap) {
                            if (isFourTimesMap) {
                                xPositions += mapNode.x * 2.0;
                            }
                            else {
                                xPositions += mapNode.x * 4.0;
                            }
                        }
                        else {
                            xPositions += mapNode.x;
                        }
                        if (j < (mapPanel.roadMap.mapNodes.size()-1)) {
                            xPositions = xPositions + ",";
                        }
                    }
                    node.setTextContent(xPositions);
                }
                if ("y".equals(node.getNodeName())) {
                    String yPositions = "";
                    for (int j=0; j<mapPanel.roadMap.mapNodes.size(); j++) {
                        MapNode mapNode = mapPanel.roadMap.mapNodes.get(j);
                        yPositions += mapNode.y;
                        if (j < (mapPanel.roadMap.mapNodes.size()-1)) {
                            yPositions = yPositions + ",";
                        }
                    }
                    node.setTextContent(yPositions);
                }
                if ("z".equals(node.getNodeName())) {
                    String zPositions = "";
                    for (int j=0; j<mapPanel.roadMap.mapNodes.size(); j++) {
                        MapNode mapNode = mapPanel.roadMap.mapNodes.get(j);
                        if (isFourTimesMap) {
                            zPositions += mapNode.z * 2.0;
                        }
                        else {
                            zPositions += mapNode.z;
                        }
                        if (j < (mapPanel.roadMap.mapNodes.size()-1)) {
                            zPositions = zPositions + ",";
                        }
                    }
                    node.setTextContent(zPositions);
                }
                if ("incoming".equals(node.getNodeName())) {
                    String incomingString = "";
                    for (int j=0; j<mapPanel.roadMap.mapNodes.size(); j++) {
                        MapNode mapNode = mapPanel.roadMap.mapNodes.get(j);
                        String incomingsPerNode = "";
                        for (int incomingIndex = 0; incomingIndex < mapNode.incoming.size(); incomingIndex++) {
                            MapNode incomingNode = mapNode.incoming.get(incomingIndex);
                            incomingsPerNode += incomingNode.id;
                            if (incomingIndex<(mapNode.incoming.size()-1)) {
                                incomingsPerNode += ",";
                            }
                        }
                        if (incomingsPerNode == "") {
                            incomingsPerNode = "-1";
                        }
                        incomingString += incomingsPerNode;
                        if (j < (mapPanel.roadMap.mapNodes.size()-1)) {
                            incomingString = incomingString + ";";
                        }
                    }
                    node.setTextContent(incomingString);
                }
                if ("out".equals(node.getNodeName())) {
                    String outgoingString = "";
                    for (int j=0; j<mapPanel.roadMap.mapNodes.size(); j++) {
                        MapNode mapNode = mapPanel.roadMap.mapNodes.get(j);
                        String outgoingPerNode = "";
                        for (int outgoingIndex = 0; outgoingIndex < mapNode.outgoing.size(); outgoingIndex++) {
                            MapNode outgoingNode = mapNode.outgoing.get(outgoingIndex);
                            outgoingPerNode += outgoingNode.id;
                            if (outgoingIndex<(mapNode.outgoing.size()-1)) {
                                outgoingPerNode += ",";
                            }
                        }
                        if (outgoingPerNode == "") {
                            outgoingPerNode = "-1";
                        }
                        outgoingString += outgoingPerNode;
                        if (j < (mapPanel.roadMap.mapNodes.size()-1)) {
                            outgoingString = outgoingString + ";";
                        }
                    }
                    node.setTextContent(outgoingString);
                }
            }

            for (int markerIndex = 1; markerIndex < mapPanel.roadMap.mapMarkers.size()+100; markerIndex++) {
                Element element = (Element) doc.getElementsByTagName("mm" + (markerIndex)).item(0);
               // if (element != null) {
                  //  element.getParentNode().removeChild(element);
                //}
                if (element != null) {
                    Element parent = (Element) element.getParentNode();
                    while (parent.hasChildNodes())
                        parent.removeChild(parent.getFirstChild());
                }
            }

            NodeList markerList = doc.getElementsByTagName("mapmarker");
            Node markerNode = markerList.item(0);
            int mapMarkerCount = 1;
            for (MapMarker mapMarker : mapPanel.roadMap.mapMarkers) {
                Element newMapMarker = doc.createElement("mm" + mapMarkerCount);

                Element markerID = doc.createElement("id");
                markerID.appendChild(doc.createTextNode("" + mapMarker.mapNode.id));
                newMapMarker.appendChild(markerID);

                Element markerName = doc.createElement("name");
                markerName.appendChild(doc.createTextNode(mapMarker.name));
                newMapMarker.appendChild(markerName);

                Element markerGroup = doc.createElement("group");
                markerGroup.appendChild(doc.createTextNode(mapMarker.group));
                newMapMarker.appendChild(markerGroup);

                markerNode.appendChild(newMapMarker);
                mapMarkerCount += 1;
            }


            Node mapNameNode = waypoints.getParentNode();
            String newMapName = mapNameNode.getNodeValue();
            if (newPath.contains("AutoDrive_") && newPath.contains("_config")) {
                int newPathStartIndex = newPath.lastIndexOf("AutoDrive_");
                newPathStartIndex += "AutoDrive_".length();
                int newPathEndIndex = newPath.lastIndexOf("_config");
                if (newPath.endsWith("_init_config")) {
                    newPathEndIndex = newPath.lastIndexOf("_init_config");
                }
                newMapName = newPath.substring(newPathStartIndex, newPathEndIndex);
                LOG.info("Found new map name in: {} : {}", newPath , newMapName);
            }
            doc.renameNode(mapNameNode, null, newMapName);

            // write the content into xml file
            filepath = newPath;
            TransformerFactory transformerFactory = TransformerFactory.newInstance();
            Transformer transformer = transformerFactory.newTransformer();
            transformer.setOutputProperty(OutputKeys.ENCODING, "UTF-8");
            transformer.setOutputProperty(OutputKeys.INDENT, "yes");
            transformer.setOutputProperty("{http://xml.apache.org/xslt}indent-amount", "2");

            DOMSource source = new DOMSource(doc);
            StreamResult result = new StreamResult(new File(filepath));
            transformer.transform(source, result);
        } catch (Exception e) {
            LOG.error(e.getMessage(), e);
        }

        LOG.info("Done save");
    }



}
