package de.adEditor;

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
import javax.xml.transform.TransformerException;
import javax.xml.transform.TransformerFactory;
import javax.xml.transform.dom.DOMSource;
import javax.xml.transform.stream.StreamResult;
import javax.xml.xpath.XPath;
import javax.xml.xpath.XPathConstants;
import javax.xml.xpath.XPathExpressionException;
import javax.xml.xpath.XPathFactory;
import java.awt.*;
import java.awt.event.InputEvent;
import java.awt.event.KeyEvent;
import java.awt.event.WindowAdapter;
import java.awt.event.WindowEvent;
import java.awt.image.BufferedImage;
import java.io.File;
import java.io.IOException;
import java.net.URL;
import java.util.LinkedList;
import java.util.Map;
import java.util.TreeMap;

import static de.adEditor.ADUtils.LOG;
import static de.adEditor.GUIUtils.*;

/* TODO:
    (1) Change map scrolling to either middle mouse button and/or keyboard
        - Avoids annoying map scrolls by accident when trying to connecting nodes but node selection fails
    (2) Marker group editing and add ability to specify group on new marker creation
    (3) Add more menu items?
    (5) Fix map refresh on window resizing...
    (6) New button icons ( replacing my age 5 art skills :-P )
    (7) Misc things i can't think of right now :-)
 */

public class AutoDriveEditor extends JFrame {
    public static final int EDITORSTATE_NOOP = -1;
    public static final int EDITORSTATE_MOVING = 0;
    public static final int EDITORSTATE_DELETING = 1;
    public static final int EDITORSTATE_CONNECTING = 2;
    public static final int EDITORSTATE_CREATING_PRIMARY = 3;
    public static final int EDITORSTATE_DELETING_DESTINATION = 4;
    public static final int EDITORSTATE_CREATING_DESTINATION = 5;
    public static final int EDITORSTATE_CHANGE_PRIORITY = 6;
    public static final int EDITORSTATE_CREATING_SECONDARY = 7;
    public static final int EDITORSTATE_CREATING_REVERSE_CONNECTION = 8;
    public static final int EDITORSTATE_EDITING_DESTINATION_GROUPS = 9;

    public static final String MOVE_NODES = "Move Nodes";
    public static final String CONNECT_NODES = "Connect Nodes";
    public static final String REMOVE_NODES = "Remove Nodes";
    public static final String REMOVE_DESTINATIONS = "Remove Destinations";
    public static final String CREATE_PRIMARY_NODES = "Create Primary Node";
    public static final String CREATE_DESTINATIONS = "Create Destinations";
    public static final String CHANGE_NODE_PRIORITY = "Change Priority";
    public static final String CREATE_SECONDARY_NODES = "Create Secondary Node";
    public static final String CREATE_REVERSE_NODES = "Create Reverse Connection";
    public static final String EDIT_DESTINATIONS_GROUPS = "Manage Destination Groups";
    public static final String AUTO_DRIVE_COURSE_EDITOR_TITLE = "AutoDrive Course Editor 0.2 Beta";

    private final MapPanel mapPanel;
    private final JButton loadImageButton;
    private final JToggleButton removeNode;
    private final JToggleButton removeDestination;
    private final JToggleButton moveNode;
    private final JToggleButton connectNodes;
    private final JToggleButton createPrimaryNode;
    private final JToggleButton createDestination;
    private final JToggleButton changePriority;
    private final JToggleButton createSecondaryNode;
    private final JToggleButton createReverseConnection;
    private final JToggleButton manageDestination;

    public EditorListener editorListener = new EditorListener(this);

    public int editorState = EDITORSTATE_NOOP;
    public File xmlConfigFile;
    private boolean stale = false;
    private boolean hasFlagTag = false; // indicates if the loaded XML file has the <flags> tag in the <waypoints> element
    public static BufferedImage tractorImage;
    public static boolean bContinuousConnections = false; // default value

    public AutoDriveEditor() {
        super();

        LOG.info("Starting AutoDrive Editor.....");

        setTitle(createTitle());
        setTractorIcon();
        addWindowListener(new WindowAdapter() {
            @Override
            public void windowClosing(WindowEvent e) {
                if (isStale()) {
                    int response = JOptionPane.showConfirmDialog(null, "There are unsaved changes. Should they be saved now?", "AutoDrive", JOptionPane.YES_NO_OPTION, JOptionPane.QUESTION_MESSAGE);
                    if (response == JOptionPane.YES_OPTION) {
                        saveMap(null);
                    }
                }
                super.windowClosing(e);
            }
        });
        setLayout(new BorderLayout());

        // create a new panel with GridBagLayout manager
        mapPanel = new MapPanel(this);

        // set border for the panel
        mapPanel.setBorder(BorderFactory.createTitledBorder(
                BorderFactory.createEtchedBorder(), "Map Panel"));

        // add the panel to this frame
        add(mapPanel, BorderLayout.CENTER);

        //EditorListener editorListener = new EditorListener(this);

        JPanel buttonPanel = new JPanel(new FlowLayout(FlowLayout.CENTER));

        // init menu bar

        JMenuBar menuBar;
        JMenuItem menuItem;
        JMenu fileMenu, optionsMenu, helpMenu;
        JCheckBoxMenuItem cbMenuItem;

        menuBar = new JMenuBar();

        fileMenu = new JMenu("File");
        fileMenu.setMnemonic(KeyEvent.VK_F);
        fileMenu.getAccessibleContext().setAccessibleDescription("File Control");
        menuBar.add(fileMenu);

        menuItem = new JMenuItem("Load Config");
        menuItem.setAccelerator(KeyStroke.getKeyStroke(KeyEvent.VK_L, InputEvent.ALT_DOWN_MASK));
        menuItem.getAccessibleContext().setAccessibleDescription("Loads a config");
        menuItem.addActionListener(editorListener);
        fileMenu.add(menuItem);

        menuItem = new JMenuItem("Save Config");
        menuItem.setAccelerator(KeyStroke.getKeyStroke(KeyEvent.VK_S, InputEvent.ALT_DOWN_MASK));
        menuItem.getAccessibleContext().setAccessibleDescription("Saves a config");
        menuItem.addActionListener(editorListener);
        fileMenu.add(menuItem);

        menuItem = new JMenuItem("Save As");
        menuItem.setAccelerator(KeyStroke.getKeyStroke(KeyEvent.VK_A, InputEvent.ALT_DOWN_MASK));
        menuItem.getAccessibleContext().setAccessibleDescription("Saves a config to a different location");
        menuItem.addItemListener(editorListener);
        fileMenu.add(menuItem);

        optionsMenu = new JMenu("Options");
        optionsMenu.setMnemonic(KeyEvent.VK_O);
        optionsMenu.getAccessibleContext().setAccessibleDescription("Options");
        menuBar.add(optionsMenu);

        cbMenuItem = new JCheckBoxMenuItem("Continuous Connections" );
        cbMenuItem.setMnemonic(KeyEvent.VK_C);
        cbMenuItem.setSelected(bContinuousConnections);
        cbMenuItem.addItemListener(editorListener);
        optionsMenu.add(cbMenuItem);

        helpMenu = new JMenu("Help");
        helpMenu.setMnemonic(KeyEvent.VK_H);
        helpMenu.getAccessibleContext().setAccessibleDescription("Help Items");
        menuBar.add(helpMenu);

        menuItem = new JMenuItem("About");
        menuItem.setAccelerator(KeyStroke.getKeyStroke(KeyEvent.VK_X, InputEvent.ALT_DOWN_MASK));
        menuItem.getAccessibleContext().setAccessibleDescription("About The Editor");
        menuItem.addActionListener(editorListener);
        helpMenu.add(menuItem);


        // GUI init

        JPanel mapBox = new JPanel();
        mapBox.setBorder(BorderFactory.createTitledBorder("Map and zoom factor"));
        buttonPanel.add(mapBox);

        loadImageButton = makeButton("Load Image","Load map image from disk ( must be 2048x2048 .PNG format)","Load Map", mapBox, editorListener);

        ButtonGroup zoomGroup = new ButtonGroup();

        makeRadioButton(" 1x","OneTimesMap","Change scale to 1x map size",true, mapBox, zoomGroup, editorListener);
        makeRadioButton(" 4x","FourTimesMap","Change scale to 4x map size",false, mapBox, zoomGroup, editorListener);
        makeRadioButton(" 16x","SixteenTimesMap","Change scale to 16x map size",false, mapBox, zoomGroup, editorListener);

        JPanel nodeBox = new JPanel();
        nodeBox.setBorder(BorderFactory.createTitledBorder("Nodes"));
        buttonPanel.add(nodeBox);

        moveNode = makeToggleButton("movenode",MOVE_NODES,"Move route nodes","Move Nodes", nodeBox, editorListener);
        connectNodes = makeToggleButton("connectnodes",CONNECT_NODES,"Connect nodes together","Connect Nodes", nodeBox, editorListener);
        removeNode = makeToggleButton("deletenodes",REMOVE_NODES,"Remove nodes ( hold right mouse to area select )","Delete Nodes", nodeBox, editorListener);
        createPrimaryNode = makeToggleButton("createprimary",CREATE_PRIMARY_NODES,"Create a primary node","Create Primary Node", nodeBox, editorListener);
        changePriority = makeToggleButton("swappriority",CHANGE_NODE_PRIORITY,"Swap a nodes priority ( hold right mouse to area select )","Node Priority", nodeBox, editorListener);
        createSecondaryNode = makeToggleButton("createsecondary",CREATE_SECONDARY_NODES,"Create a secondary node","Create Secondary Node", nodeBox, editorListener);
        createReverseConnection = makeToggleButton("createreverse",CREATE_REVERSE_NODES,"Create a reverse connection","Create Reverse Connection", nodeBox, editorListener);

        JPanel markerBox = new JPanel();
        markerBox.setBorder(BorderFactory.createTitledBorder("Markers"));
        buttonPanel.add(markerBox);

        createDestination = makeToggleButton("addmarker",CREATE_DESTINATIONS,"Create map marker","Create Map Marker", markerBox, editorListener);
        removeDestination = makeToggleButton("deletemarker",REMOVE_DESTINATIONS,"Delete a map marker","Delete Map Marker", markerBox, editorListener);
        manageDestination = makeToggleButton("markergroup",EDIT_DESTINATIONS_GROUPS,"Edit Marker groups (coming soon)","Edit Marker Groups", markerBox, editorListener);

        updateButtons();
        nodeBoxSetEnabled(false);
        mapBoxSetEnabled(false);

        this.setJMenuBar(menuBar);
        this.add(buttonPanel, BorderLayout.NORTH);

        pack();
        setLocationRelativeTo(null);
        this.setDefaultCloseOperation(JFrame.EXIT_ON_CLOSE);
    }

    private void setTractorIcon() {
        try {
            URL url = AutoDriveEditor.class.getResource("/tractor.png");
            if (url != null) {
                tractorImage = ImageIO.read(url);
                setIconImage(tractorImage);
            }
        } catch (IOException e) {
            LOG.error(e.getMessage(), e);
        }
    }

    public static BufferedImage getTractorIcon() {
        return tractorImage;
    }

    private void nodeBoxSetEnabled(boolean enabled) {
        moveNode.setEnabled(enabled);
        connectNodes.setEnabled(enabled);
        removeNode.setEnabled(enabled);
        removeDestination.setEnabled(enabled);
        createPrimaryNode.setEnabled(enabled);
        createDestination.setEnabled(enabled);
        changePriority.setEnabled(enabled);
        createSecondaryNode.setEnabled(enabled);
        createReverseConnection.setEnabled(enabled);

        // Temporary disable marker groups editing until it is complete
        manageDestination.setEnabled(enabled);

    }

    private void mapBoxSetEnabled(boolean enabled) {
        loadImageButton.setEnabled(enabled);
    }

    public void updateButtons() {
        moveNode.setSelected(false);
        connectNodes.setSelected(false);
        removeNode.setSelected(false);
        removeDestination.setSelected(false);
        createPrimaryNode.setSelected(false);
        createDestination.setSelected(false);
        changePriority.setSelected(false);
        createSecondaryNode.setSelected(false);
        createReverseConnection.setSelected(false);

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
            case EDITORSTATE_CREATING_PRIMARY:
                createPrimaryNode.setSelected(true);
                break;
            case EDITORSTATE_DELETING_DESTINATION:
                removeDestination.setSelected(true);
                break;
            case EDITORSTATE_CREATING_DESTINATION:
                createDestination.setSelected(true);
                break;
            case EDITORSTATE_CHANGE_PRIORITY:
                changePriority.setSelected(true);
                break;
            case EDITORSTATE_CREATING_SECONDARY:
                createSecondaryNode.setSelected(true);
                break;
            case EDITORSTATE_CREATING_REVERSE_CONNECTION:
                createReverseConnection.setSelected(true);
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

        SwingUtilities.invokeLater(() -> {
            GlobalExceptionHandler globalExceptionHandler = new GlobalExceptionHandler();
            Thread.setDefaultUncaughtExceptionHandler(globalExceptionHandler);
            new AutoDriveEditor().setVisible(true);
        });
    }

    public void loadConfigFile(File fXmlFile) {
        LOG.info("loadFile: {}", fXmlFile.getAbsolutePath());

        try {
            mapPanel.setRoadMap(loadXmlConfigFile(fXmlFile));
            setTitle(AUTO_DRIVE_COURSE_EDITOR_TITLE + " - " + fXmlFile.getAbsolutePath());
            xmlConfigFile = fXmlFile;
        } catch (Exception e) {
            LOG.error(e.getMessage(), e);
            JOptionPane.showMessageDialog(this, "The AutoDrive Config could not be loaded.", "AutoDrive", JOptionPane.ERROR_MESSAGE);
        }
    }

    private RoadMap loadXmlConfigFile(File fXmlFile) throws ParserConfigurationException, IOException, SAXException {
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
                    Node node = idNodeList.item(markerIndex).getChildNodes().item(0);
                    String markerNodeId = node.getNodeValue();

                    node = nameNodeList.item(markerIndex).getChildNodes().item(0);
                    String markerName = node.getNodeValue();

                    node = groupNodeList.item(markerIndex).getChildNodes().item(0);
                    String markerGroup = node.getNodeValue();

                    MapNode dummyNode = new MapNode((int)Double.parseDouble(markerNodeId), 0, 0, 0, 0);
                    MapMarker mapMarker = new MapMarker(dummyNode, markerName, markerGroup);
                    mapMarkerTree.put((int)Double.parseDouble(markerNodeId), mapMarker);
                }
            }
        }

        NodeList nList = doc.getElementsByTagName("waypoints");

        LinkedList<MapNode> nodes = new LinkedList<>();
        for (int temp = 0; temp < nList.getLength(); temp++) {

            Node nNode = nList.item(temp);

            LOG.info("Current Element :{}", nNode.getNodeName());

            if (nNode.getNodeType() == Node.ELEMENT_NODE) {
                Element eElement = (Element) nNode;

                NodeList nodeList = eElement.getElementsByTagName("id").item(0).getChildNodes();
                Node node = nodeList.item(0);
                String idString = node.getNodeValue();
                String[] ids = idString.split(",");

                nodeList = eElement.getElementsByTagName("x").item(0).getChildNodes();
                node = nodeList.item(0);
                String xString = node.getNodeValue();
                String[] xValues = xString.split(",");

                nodeList = eElement.getElementsByTagName("y").item(0).getChildNodes();
                node = nodeList.item(0);
                String yString = node.getNodeValue();
                String[] yValues = yString.split(",");

                nodeList = eElement.getElementsByTagName("z").item(0).getChildNodes();
                node = nodeList.item(0);
                String zString = node.getNodeValue();
                String[] zValues = zString.split(",");

                nodeList = eElement.getElementsByTagName("out").item(0).getChildNodes();
                node = nodeList.item(0);
                String outString = node.getNodeValue();
                String[] outValueArrays = outString.split(";");

                nodeList = eElement.getElementsByTagName("incoming").item(0).getChildNodes();
                node = nodeList.item(0);
                String incomingString = node.getNodeValue();
                String[] incomingValueArrays = incomingString.split(";");



                if (eElement.getElementsByTagName("flags").item(0) != null ) {
                    nodeList = eElement.getElementsByTagName("flags").item(0).getChildNodes();
                    node = nodeList.item(0);
                    String flagsString = node.getNodeValue();
                    String[] flagsValue = flagsString.split(",");
                    hasFlagTag = true;

                    for (int i=0; i<ids.length; i++) {
                        int id = Integer.parseInt(ids[i]);
                        double x = Double.parseDouble(xValues[i]);
                        double y = Double.parseDouble(yValues[i]);
                        double z = Double.parseDouble(zValues[i]);
                        int flag = Integer.parseInt(flagsValue[i]);

                        MapNode mapNode = new MapNode(id, x, y, z, flag);
                        nodes.add(mapNode);
                    }
                } else {
                    LOG.info("outdated config format detected, no <flags> element found. Save config from ingame or editor to add it");
                    hasFlagTag = false;
                    JOptionPane.showMessageDialog(this, "This config file was saved with a older version of AutoDrive. Please update to the latest version and reload and save ingame to enable all the new features", "AutoDrive", JOptionPane.WARNING_MESSAGE);
                    for (int i=0; i<ids.length; i++) {
                        int id = Integer.parseInt(ids[i]);
                        double x = Double.parseDouble(xValues[i]);
                        double y = Double.parseDouble(yValues[i]);
                        double z = Double.parseDouble(zValues[i]);
                        int flag = 0;

                        MapNode mapNode = new MapNode(id, x, y, z, flag);
                        nodes.add(mapNode);
                    }
                }


                for (Map.Entry<Integer, MapMarker> entry : mapMarkerTree.entrySet())
                {
                    mapMarkers.add(new MapMarker(nodes.get(entry.getKey()-1), entry.getValue().name, entry.getValue().group));
                }

                for (int i=0; i<ids.length; i++) {
                    MapNode mapNode = nodes.get(i);
                    String[] outNodes = outValueArrays[i].split(",");
                    for (String outNode : outNodes) {
                        if (Integer.parseInt(outNode) != -1) {
                            mapNode.outgoing.add(nodes.get(Integer.parseInt(outNode) - 1));
                        }
                    }
                }

                for (int i=0; i<ids.length; i++) {
                    MapNode mapNode = nodes.get(i);
                    String[] incomingNodes = incomingValueArrays[i].split(",");
                    for (String incomingNode : incomingNodes) {
                        if (Integer.parseInt(incomingNode) != -1) {
                            mapNode.incoming.add(nodes.get(Integer.parseInt(incomingNode)-1));
                        }
                    }
                }
            }
        }

        RoadMap roadMap = new RoadMap();
        roadMap.mapNodes = nodes;
        RoadMap.mapMarkers = mapMarkers;

        NodeList mapNameNode = doc.getElementsByTagName("MapName");
        Element mapNameElement = (Element) mapNameNode.item(0);
        NodeList fstNm = mapNameElement.getChildNodes();
        String mapName =(fstNm.item(0)).getNodeValue();
        LOG.info("Loaded config for map: {}", mapName);

        String mapPath = "/mapImages/" + mapName + ".png";
        URL url = AutoDriveEditor.class.getResource(mapPath);

        BufferedImage image = null;
        try {
            if (url !=null) image = ImageIO.read(url);
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
                        mapBoxSetEnabled(true);
                        LOG.info("Editor has no map file for map: {}", mapName);
                    }
                }
            }
        }

        if (image != null) {
            mapPanel.setImage(image);
        }

        if (mapPanel.getImage() != null) {
            mapPanel.setPreferredSize(new Dimension(1024, 768));
            mapPanel.setMinimumSize(new Dimension(1024, 768));
            pack();
            repaint();
            mapPanel.repaint();
        }

        //saveConfigButton.setEnabled(true);
        nodeBoxSetEnabled(true);
        editorState = EDITORSTATE_MOVING;
        updateButtons();

        LOG.info("loadFile end.");
        return roadMap;

    }

    // this way to save a file under a new name is ugly but works :-/

    public void saveMap(String newName) {
        LOG.info("SaveMap called");
        RoadMap roadMap = mapPanel.getRoadMap();

        try
        {
            if (xmlConfigFile == null) return;
            saveXmlConfig(xmlConfigFile, roadMap, newName);
            setStale(false);
            JOptionPane.showMessageDialog(this, xmlConfigFile.getName() + " has been successfully saved.", "AutoDrive", JOptionPane.INFORMATION_MESSAGE);
        } catch (Exception e) {
            LOG.error(e.getMessage(), e);
            JOptionPane.showMessageDialog(this, "The AutoDrive Config could not be saved.", "AutoDrive", JOptionPane.ERROR_MESSAGE);
        }
    }

    public void saveXmlConfig(File file, RoadMap roadMap, String newName) throws ParserConfigurationException, IOException, SAXException, TransformerException, XPathExpressionException {

        DocumentBuilderFactory docFactory = DocumentBuilderFactory.newInstance();
        DocumentBuilder docBuilder = docFactory.newDocumentBuilder();
        Document doc = docBuilder.parse(file);

        Node AutoDrive = doc.getFirstChild();
        //Element root = doc.getDocumentElement();

        Node waypoints = doc.getElementsByTagName("waypoints").item(0);

        // If no <flags> tag was detected on config load, create it

        if (!hasFlagTag) {
            Element flagtag = doc.createElement("flags");
            waypoints.appendChild(flagtag);
        }



        // loop the staff child node
        NodeList list = waypoints.getChildNodes();

        for (int i = 0; i < list.getLength(); i++) {
            Node node = list.item(i);

            if ("id".equals(node.getNodeName())) {
                StringBuilder ids = new StringBuilder();
                for (int j = 0; j < roadMap.mapNodes.size(); j++) {
                    MapNode mapNode = roadMap.mapNodes.get(j);
                    ids.append(mapNode.id);
                    if (j < (roadMap.mapNodes.size() - 1)) {
                        ids.append(",");
                    }
                }
                node.setTextContent(ids.toString());
            }
            if ("x".equals(node.getNodeName())) {
                StringBuilder xPositions = new StringBuilder();
                for (int j = 0; j < roadMap.mapNodes.size(); j++) {
                    MapNode mapNode = roadMap.mapNodes.get(j);
                    xPositions.append(mapNode.x);
                    if (j < (roadMap.mapNodes.size() - 1)) {
                        xPositions.append(",");
                    }
                }
                node.setTextContent(xPositions.toString());
            }
            if ("y".equals(node.getNodeName())) {
                StringBuilder yPositions = new StringBuilder();
                for (int j = 0; j < roadMap.mapNodes.size(); j++) {
                    MapNode mapNode = roadMap.mapNodes.get(j);
                    yPositions.append(mapNode.y);
                    if (j < (roadMap.mapNodes.size() - 1)) {
                        yPositions.append(",");
                    }
                }
                node.setTextContent(yPositions.toString());
            }
            if ("z".equals(node.getNodeName())) {
                StringBuilder zPositions = new StringBuilder();
                for (int j = 0; j < roadMap.mapNodes.size(); j++) {
                    MapNode mapNode = roadMap.mapNodes.get(j);
                    zPositions.append(mapNode.z);
                    if (j < (roadMap.mapNodes.size() - 1)) {
                        zPositions.append(",");
                    }
                }
                node.setTextContent(zPositions.toString());
            }
            if ("incoming".equals(node.getNodeName())) {
                StringBuilder incomingString = new StringBuilder();
                for (int j = 0; j < roadMap.mapNodes.size(); j++) {
                    MapNode mapNode = roadMap.mapNodes.get(j);
                    StringBuilder incomingsPerNode = new StringBuilder();
                    for (int incomingIndex = 0; incomingIndex < mapNode.incoming.size(); incomingIndex++) {
                        MapNode incomingNode = mapNode.incoming.get(incomingIndex);
                        incomingsPerNode.append(incomingNode.id);
                        if (incomingIndex < (mapNode.incoming.size() - 1)) {
                            incomingsPerNode.append(",");
                        }
                    }
                    if (incomingsPerNode.toString().isEmpty()) {
                        incomingsPerNode = new StringBuilder("-1");
                    }
                    incomingString.append(incomingsPerNode);
                    if (j < (roadMap.mapNodes.size() - 1)) {
                        incomingString.append(";");
                    }
                }
                node.setTextContent(incomingString.toString());
            }
            if ("out".equals(node.getNodeName())) {
                StringBuilder outgoingString = new StringBuilder();
                for (int j = 0; j < roadMap.mapNodes.size(); j++) {
                    MapNode mapNode = roadMap.mapNodes.get(j);
                    StringBuilder outgoingPerNode = new StringBuilder();
                    for (int outgoingIndex = 0; outgoingIndex < mapNode.outgoing.size(); outgoingIndex++) {
                        MapNode outgoingNode = mapNode.outgoing.get(outgoingIndex);
                        outgoingPerNode.append(outgoingNode.id);
                        if (outgoingIndex < (mapNode.outgoing.size() - 1)) {
                            outgoingPerNode.append(",");
                        }
                    }
                    if (outgoingPerNode.toString().isEmpty()) {
                        outgoingPerNode = new StringBuilder("-1");
                    }
                    outgoingString.append(outgoingPerNode);
                    if (j < (roadMap.mapNodes.size() - 1)) {
                        outgoingString.append(";");
                    }
                }
                node.setTextContent(outgoingString.toString());
            }
            if ("flags".equals(node.getNodeName())) {
                StringBuilder flags = new StringBuilder();
                for (int j = 0; j < roadMap.mapNodes.size(); j++) {
                    MapNode mapNode = roadMap.mapNodes.get(j);
                    flags.append(mapNode.flag);
                    if (j < (roadMap.mapNodes.size() - 1)) {
                        flags.append(",");
                    }
                }
                node.setTextContent(flags.toString());
            }
        }



        for (int markerIndex = 1; markerIndex < RoadMap.mapMarkers.size() + 100; markerIndex++) {
            Element element = (Element) doc.getElementsByTagName("mm" + (markerIndex)).item(0);
            if (element != null) {
                Element parent = (Element) element.getParentNode();
                while (parent.hasChildNodes())
                    parent.removeChild(parent.getFirstChild());
            }
        }


        NodeList testwaypoints = doc.getElementsByTagName("mapmarker");

        if (RoadMap.mapMarkers.size() > 0 && testwaypoints.getLength() == 0 ) {
            LOG.info("New map markers to save, but no <mapmarker> tag in loaded XML.. creating tag for output file");
            Element test = doc.createElement("mapmarker");
            AutoDrive.appendChild(test);
        }

        NodeList markerList = doc.getElementsByTagName("mapmarker");
        Node markerNode = markerList.item(0);
        int mapMarkerCount = 1;
        for (MapMarker mapMarker : RoadMap.mapMarkers) {
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

        // write the content into xml file
        TransformerFactory transformerFactory = TransformerFactory.newInstance();
        Transformer transformer = transformerFactory.newTransformer();
        transformer.setOutputProperty(OutputKeys.ENCODING, "UTF-8");
        transformer.setOutputProperty(OutputKeys.INDENT, "yes");
        transformer.setOutputProperty("{http://xml.apache.org/xslt}indent-amount", "2");

        DOMSource source = new DOMSource(doc);

        // Clean all the empty whitespaces from XML before save

        XPath xp = XPathFactory.newInstance().newXPath();
        NodeList nl = (NodeList) xp.evaluate("//text()[normalize-space(.)='']", doc, XPathConstants.NODESET);

        for (int i=0; i < nl.getLength(); ++i) {
            Node node = nl.item(i);
            node.getParentNode().removeChild(node);
        }

        StreamResult result;

        if (newName == null) {
            result = new StreamResult(xmlConfigFile);
        } else {
            result = new StreamResult(new File(newName));
        }
        transformer.transform(source, result);

        LOG.info("Done save");
    }

    public void updateMapZoomFactor(int zoomFactor) {
        mapPanel.setMapZoomFactor(zoomFactor);
        mapPanel.repaint();
    }

    private String createTitle() {
        StringBuilder sb = new StringBuilder();
        sb.append(AUTO_DRIVE_COURSE_EDITOR_TITLE);
        if (xmlConfigFile != null) {
            sb.append(" - ").append(xmlConfigFile.getAbsolutePath()).append(isStale() ? " *" : "");
        }
        return sb.toString();
    }

    public MapPanel getMapPanel() {
        return mapPanel;
    }

    public boolean isStale() {
        return stale;
    }

    public void setStale(boolean stale) {
        if (isStale() != stale) {
            this.stale = stale;
            setTitle(createTitle());
        }
    }
}
