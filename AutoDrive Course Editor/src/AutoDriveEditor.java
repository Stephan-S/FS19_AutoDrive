import javax.imageio.ImageIO;
import javax.swing.*;
import java.awt.*;
import java.awt.event.MouseMotionAdapter;
import java.awt.image.BufferedImage;
import java.io.File;
import java.io.IOException;
import javax.xml.parsers.DocumentBuilderFactory;
import javax.xml.parsers.DocumentBuilder;
import javax.xml.parsers.ParserConfigurationException;
import javax.xml.transform.OutputKeys;
import javax.xml.transform.Transformer;
import javax.xml.transform.TransformerFactory;
import javax.xml.transform.dom.DOMSource;
import javax.xml.transform.stream.StreamResult;

import org.w3c.dom.Document;
import org.w3c.dom.NodeList;
import org.w3c.dom.Node;
import org.w3c.dom.Element;
import org.xml.sax.SAXException;

import java.io.File;
import java.net.URL;
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

    public MapNode selected = null;

    public boolean isFourTimesMap = false;

    public int editorState = EDITORSTATE_MOVING;

    public EditorListener editorListener;

    public MouseListener mouseListener;

    public File loadedFile, savedFile;

    public AutoDriveEditor() {
        super("AutoDrive Course Editor 0.1");

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
        moveNode.setActionCommand("Move Nodes");
        buttonPanel.add(moveNode);

        connectNodes = new JToggleButton("Connect Nodes");
        connectNodes.addActionListener(this.editorListener);
        connectNodes.setActionCommand("Connect Nodes");
        buttonPanel.add(connectNodes);

        removeNode = new JToggleButton("Delete Nodes");
        removeNode.addActionListener(this.editorListener);
        removeNode.setActionCommand("Remove Nodes");
        buttonPanel.add(removeNode);

        removeDestination = new JToggleButton("Delete Destination");
        removeDestination.addActionListener(this.editorListener);
        removeDestination.setActionCommand("Remove Destinations");
        buttonPanel.add(removeDestination);

        createNode = new JToggleButton("Create Nodes");
        createNode.addActionListener(this.editorListener);
        createNode.setActionCommand("Create Nodes");
        buttonPanel.add(createNode);

        createDestination = new JToggleButton("Create Destination");
        createDestination.addActionListener(this.editorListener);
        createDestination.setActionCommand("Create Destinations");
        buttonPanel.add(createDestination);

        fourTimesMap = new JToggleButton("Four times Map");
        fourTimesMap.addActionListener(this.editorListener);
        fourTimesMap.setActionCommand("FourTimesMap");
        buttonPanel.add(fourTimesMap);

        saveButton = new JButton("Save");
        saveButton.addActionListener(this.editorListener);
        saveButton.setActionCommand("Save");
        buttonPanel.add(saveButton);

        this.add(buttonPanel, BorderLayout.NORTH);


        this.mouseListener = new MouseListener(mapPanel);

        mapPanel.addMouseListener(mouseListener);
        mapPanel.addMouseMotionListener(mouseListener);
        mapPanel.addMouseWheelListener(mouseListener);

        pack();
        setLocationRelativeTo(null);
        this.setDefaultCloseOperation(JFrame.EXIT_ON_CLOSE);
    }


    public static void main(String[] args) {
        // set look and feel to the system look and feel
        try {
            UIManager.setLookAndFeel(UIManager.getSystemLookAndFeelClassName());
        } catch (Exception ex) {
            ex.printStackTrace();
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

        System.out.println("Root element :" + doc.getDocumentElement().getNodeName());

        NodeList markerList = doc.getElementsByTagName("mapmarker");
        LinkedList<MapMarker> mapMarkers = new LinkedList<>();

        TreeMap<Integer, String> mapMarkerTree = new TreeMap<>();
        for (int temp = 0; temp < markerList.getLength(); temp++) {
            Node markerNode = markerList.item(temp);
            if (markerNode.getNodeType() == Node.ELEMENT_NODE) {
                Element eElement = (Element) markerNode;

                NodeList idNodeList = eElement.getElementsByTagName("id");
                NodeList nameNodeList = eElement.getElementsByTagName("name");

                for (int markerIndex = 0; markerIndex<idNodeList.getLength(); markerIndex++ ) {
                    Node node = (Node) idNodeList.item(markerIndex).getChildNodes().item(0);
                    String markerNodeId = node.getNodeValue();

                    node = (Node) nameNodeList.item(markerIndex).getChildNodes().item(0);
                    String markerName = node.getNodeValue();
                    mapMarkerTree.put((int)Double.parseDouble(markerNodeId), markerName);
                }
            }
        }

        NodeList nList = doc.getElementsByTagName("waypoints");

        System.out.println("----------------------------");

        LinkedList<MapNode> nodes = new LinkedList<>();
        for (int temp = 0; temp < nList.getLength(); temp++) {

            Node nNode = nList.item(temp);

            System.out.println("\nCurrent Element :" + nNode.getNodeName());

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

                nodeList = eElement.getElementsByTagName("markerID").item(0).getChildNodes();
                node = (Node) nodeList.item(0);
                String markerIdsString = node.getNodeValue();
                String[] markerIdsArrays = markerIdsString.split(";");


                for (int i=0; i<ids.length; i++) {
                    int id = Integer.parseInt(ids[i]);
                    double x = Double.parseDouble(xValues[i]);
                    double y = Double.parseDouble(yValues[i]);
                    double z = Double.parseDouble(zValues[i]);

                    if (isFourTimesMap) {
                        x = (x)/2.0;
                        z = (z)/2.0;
                    }

                    MapNode mapNode = new MapNode(id, x, y, z);
                    nodes.add(mapNode);
                }


                for (Map.Entry<Integer, String> entry : mapMarkerTree.entrySet())
                {
                    mapMarkers.add(new MapMarker(nodes.get(entry.getKey()-1), entry.getValue()));
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

                for (int i=0; i<ids.length && i < markerIdsArrays.length ; i++) {
                    MapNode mapNode = nodes.get(i);
                    String[] markerIDs = markerIdsArrays[i].split(",");

                    boolean allTargetsSame = false;
                    int targetIndex = 0;
                    for (int markerIndex=0; markerIndex<markerIDs.length; markerIndex++) {
                        if(markerIDs[markerIndex].equals("=")) {
                            allTargetsSame = true;
                        }
                        else {
                            targetIndex = Integer.parseInt(markerIDs[markerIndex]);
                        }
                    }

                    if (allTargetsSame) {
                        MapNode markerTarget = null;
                        if(targetIndex != -1) {
                            markerTarget = nodes.get(targetIndex-1);
                        }
                        for (MapMarker iter : mapMarkers) {
                            mapNode.directions.put(iter , markerTarget);
                        }
                    }
                    else {
                        for (int markerIndex = 0; markerIndex < markerIDs.length; markerIndex++) {
                            MapNode markerTarget = null;
                            if (Integer.parseInt(markerIDs[markerIndex]) - 1 >= 0) {
                                if (Integer.parseInt(markerIDs[markerIndex]) < nodes.size()) {
                                    markerTarget = nodes.get(Integer.parseInt(markerIDs[markerIndex]) - 1);
                                } else {
                                    markerTarget = null;
                                }
                            }
                            if (mapMarkers.size() > markerIndex) {
                                mapNode.directions.put(mapMarkers.get(markerIndex), markerTarget);
                            }
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
        System.out.println("Loaded config for map: " + mapNameNode.getNodeName());

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
                        System.out.println("Editor has no map file for map: " + mapName);
                    }
                }
            }
        }

        if (image != null) {
            mapPanel.image = image;
            mapPanel.setPreferredSize(new Dimension(1024, 768));
            mapPanel.setMinimumSize(new Dimension(1024, 768));
            pack();
            repaint();
            mapPanel.repaint();
        }

        return roadMap;

    }

    public void saveMap(String oldPath, String newPath) {
        System.out.println("SaveMap called");
        try {
            String filepath = oldPath;
            DocumentBuilderFactory docFactory = DocumentBuilderFactory.newInstance();
            DocumentBuilder docBuilder = docFactory.newDocumentBuilder();
            Document doc = docBuilder.parse(filepath);

            Node AutoDrive = doc.getFirstChild();
            Element root = doc.getDocumentElement();
            Node recalculation = doc.getElementsByTagName("Recalculation").item(0);
            recalculation.setTextContent("true");

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
                        if (isFourTimesMap) {
                            xPositions += mapNode.x * 2.0;
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

                if ("markerID".equals(node.getNodeName())) {
                    String markerString = "";
                    for (int j=0; j<mapPanel.roadMap.mapNodes.size(); j++) {
                        MapNode mapNode = mapPanel.roadMap.mapNodes.get(j);
                        String markerPerNode = "";
                        int markerIndex = 0;
                        boolean allTheSame = true;
                        int lastId = -1;
                        for (Map.Entry<MapMarker, MapNode> entry : mapNode.directions.entrySet()) {
                            MapNode markerTargetNode = entry.getValue();
                            if (markerTargetNode != null) {
                                markerPerNode += entry.getValue().id;
                                allTheSame = allTheSame && (lastId == -1 || lastId == entry.getValue().id);
                                lastId = entry.getValue().id;
                            }
                            else {
                                markerPerNode += "-1";
                            }
                            if (markerIndex<(mapNode.directions.size()-1)) {
                                markerPerNode += ",";
                            }
                            markerIndex++;

                        }
                        if (markerPerNode == "") {
                            markerPerNode = "-1";
                        }
                        if(allTheSame) {
                            markerString += "=," + lastId;
                        }
                        else {
                            markerString += markerPerNode;
                        }
                        if (j < (mapPanel.roadMap.mapNodes.size()-1)) {
                            markerString = markerString + ";";
                        }
                    }
                    node.setTextContent(markerString);
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

                markerNode.appendChild(newMapMarker);
                mapMarkerCount += 1;
            }

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
            e.printStackTrace();
        }

        System.out.println("Done");
    }



}
