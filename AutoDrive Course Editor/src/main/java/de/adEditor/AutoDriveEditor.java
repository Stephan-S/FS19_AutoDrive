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
import java.net.MalformedURLException;
import java.net.URL;
import java.net.URLClassLoader;
import java.util.*;

import static de.adEditor.ADUtils.*;
import static de.adEditor.GUIUtils.*;

/* TODO:
    (1) New features?
    (2) Fix map refresh on window resizing...
    (3) New button icons
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
    public static final int EDITORSTATE_EDITING_DESTINATION = 9;

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

    private MapPanel mapPanel;
    private JMenuItem loadImageButton;
    private JMenuItem saveConfigMenuItem;
    private JMenuItem saveConfigAsMenuItem;
    private JToggleButton removeNode;
    private JToggleButton removeDestination;
    private JToggleButton moveNode;
    private JToggleButton connectNodes;
    private JToggleButton createPrimaryNode;
    private JToggleButton createDestination;
    private JToggleButton changePriority;
    private JToggleButton createSecondaryNode;
    private JToggleButton createReverseConnection;
    private JToggleButton manageDestination;

    public EditorListener editorListener = new EditorListener(this);

    public int editorState = EDITORSTATE_NOOP;
    public File xmlConfigFile;
    private boolean stale = false;
    private boolean hasFlagTag = false; // indicates if the loaded XML file has the <flags> tag in the <waypoints> element
    public static BufferedImage tractorImage;
    public static ImageIcon markerIcon;
    public static boolean bContinuousConnections = false; // default value
    public static ResourceBundle localeString;
    public static Locale locale;

    public AutoDriveEditor() {
        super();

        localeString = ADUtils.getLocale();
        locale = Locale.getDefault();

        LOG.info(localeString.getString("console_start"));

        setTitle(createTitle());
        setTractorIcon();
        setMarkerIcon();
        setPreferredSize(new Dimension(1024,768));
        addWindowListener(new WindowAdapter() {
            @Override
            public void windowClosing(WindowEvent e) {
                if (isStale()) {
                    int response = JOptionPane.showConfirmDialog(null, localeString.getString("dialog_unsaved"), "AutoDrive", JOptionPane.YES_NO_OPTION, JOptionPane.QUESTION_MESSAGE);
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
                BorderFactory.createEtchedBorder(), localeString.getString("panels_map")));

        // add the panel to this frame
        add(mapPanel, BorderLayout.CENTER);

        //EditorListener editorListener = new EditorListener(this);

        JPanel buttonPanel = new JPanel(new FlowLayout(FlowLayout.CENTER));

        // init menu bar

        JMenuBar menuBar;
        JMenuItem menuItem;
        JMenu fileMenu, mapMenu, optionsMenu, helpMenu, subMenu;

        menuBar = new JMenuBar();

        // Create the file Menu

        fileMenu = makeNewMenu("menu_file", KeyEvent.VK_F, "menu_file_accstring", menuBar);

        makeMenuItem("menu_file_loadconfig", KeyEvent.VK_L, InputEvent.ALT_DOWN_MASK, "menu_file_loadconfig_accstring", fileMenu, editorListener,  true );
        saveConfigMenuItem = makeMenuItem("menu_file_saveconfig", KeyEvent.VK_S, InputEvent.ALT_DOWN_MASK, "menu_file_saveconfig_accstring", fileMenu, editorListener,  false );
        saveConfigAsMenuItem = makeMenuItem("menu_file_saveasconfig", KeyEvent.VK_A, InputEvent.ALT_DOWN_MASK, "menu_file_saveasconfig_accstring", fileMenu, editorListener,  false );

        // Create the Map Menu and it's scale sub menu

        mapMenu = makeNewMenu("menu_map", KeyEvent.VK_M, "menu_map_accstring", menuBar);

        loadImageButton = makeMenuItem("menu_map_loadimage", KeyEvent.VK_M, InputEvent.ALT_DOWN_MASK, "menu_map_loadimage_accstring", mapMenu,editorListener,  false );
        mapMenu.addSeparator();

        subMenu = makeSubMenu("menu_map_scale", KeyEvent.VK_M, "menu_map_scale_accstring", mapMenu);

        ButtonGroup menuZoomGroup = new ButtonGroup();

        makeRadioButtonMenuItem("menu_map_scale_1x", KeyEvent.VK_1, InputEvent.ALT_DOWN_MASK, "menu_map_scale_1x_accstring", subMenu, editorListener, true, menuZoomGroup, true);
        makeRadioButtonMenuItem("menu_map_scale_4x", KeyEvent.VK_2, InputEvent.ALT_DOWN_MASK, "menu_map_scale_4x_accstring", subMenu, editorListener, true, menuZoomGroup, false);
        makeRadioButtonMenuItem("menu_map_scale_16x", KeyEvent.VK_3, InputEvent.ALT_DOWN_MASK, "menu_map_scale_16x_accstring", subMenu, editorListener, true, menuZoomGroup, false);

        // Create the Options menu

        optionsMenu = makeNewMenu("menu_options", KeyEvent.VK_O, "menu_options_accstring", menuBar);

        makeCheckBoxMenuItem("menu_conconnect", KeyEvent.VK_C, "menu_conconnect_accstring", bContinuousConnections, optionsMenu, editorListener);

        // Create the Help menu

        helpMenu = makeNewMenu("menu_help", KeyEvent.VK_H, "menu_help_accstring", menuBar);

        makeMenuItem("menu_help_about", KeyEvent.VK_X, InputEvent.ALT_DOWN_MASK, "menu_help_about_accstring", helpMenu,editorListener,  true );


        // GUI init


        // Create node panel
        JPanel nodeBox = new JPanel();
        nodeBox.setBorder(BorderFactory.createTitledBorder(localeString.getString("panel_nodes")));
        buttonPanel.add(nodeBox);

        moveNode = makeToggleButton("movenode",MOVE_NODES,"nodes_move_tooltip","nodes_move_alt", nodeBox, editorListener);
        connectNodes = makeToggleButton("connectnodes",CONNECT_NODES,"nodes_connect_tooltip","nodes_connect_alt", nodeBox, editorListener);
        removeNode = makeToggleButton("deletenodes",REMOVE_NODES,"nodes_remove_tooltip","nodes_remove_alt", nodeBox, editorListener);
        createPrimaryNode = makeToggleButton("createprimary",CREATE_PRIMARY_NODES,"nodes_createprimary_tooltip","nodes_createprimary_alt", nodeBox, editorListener);
        changePriority = makeToggleButton("swappriority",CHANGE_NODE_PRIORITY,"nodes_priority_tooltip","nodes_priority_alt", nodeBox, editorListener);
        createSecondaryNode = makeToggleButton("createsecondary",CREATE_SECONDARY_NODES,"nodes_createsecondary_tooltip","nodes_createsecondary_alt", nodeBox, editorListener);
        createReverseConnection = makeToggleButton("createreverse",CREATE_REVERSE_NODES,"nodes_createreverse_tooltip","nodes_createreverse_alt", nodeBox, editorListener);

        // Create markers panel
        JPanel markerBox = new JPanel();
        markerBox.setBorder(BorderFactory.createTitledBorder("Markers"));
        buttonPanel.add(markerBox);

        createDestination = makeToggleButton("addmarker",CREATE_DESTINATIONS,"markers_add_tooltip","markers_add_alt", markerBox, editorListener);
        removeDestination = makeToggleButton("deletemarker",REMOVE_DESTINATIONS,"markers_delete_tooltip","markers_delete_alt", markerBox, editorListener);
        manageDestination = makeToggleButton("markergroup",EDIT_DESTINATIONS_GROUPS,"markers_edit_tooltip","markers_edit_alt", markerBox, editorListener);

        updateButtons();
        nodeBoxSetEnabled(false);

        this.setJMenuBar(menuBar);
        this.add(buttonPanel, BorderLayout.NORTH);

        pack();
        setLocationRelativeTo(null);
        this.setDefaultCloseOperation(JFrame.EXIT_ON_CLOSE);
    }

    private void setTractorIcon() {
        tractorImage = getIcon("tractor.png");
        setIconImage(tractorImage);
    }

    private void setMarkerIcon() {
        BufferedImage markerImage = getIcon("marker.png");
        markerIcon = new ImageIcon(markerImage);
    }

    public static ImageIcon getMarkerIcon() {
        return markerIcon;
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
        manageDestination.setEnabled(enabled);

    }

    private void mapMenuEnabled(boolean enabled) {
        loadImageButton.setEnabled(enabled);
    }

    private void saveMenuEnabled(boolean enabled) {
        saveConfigMenuItem.setEnabled(enabled);
        saveConfigAsMenuItem.setEnabled(enabled);
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
            JOptionPane.showMessageDialog(this, localeString.getString("dialog_config_loadfailed"), "AutoDrive", JOptionPane.ERROR_MESSAGE);
        }
    }

    private RoadMap loadXmlConfigFile(File fXmlFile) throws ParserConfigurationException, IOException, SAXException {
        DocumentBuilderFactory dbFactory = DocumentBuilderFactory.newInstance();
        DocumentBuilder dBuilder = dbFactory.newDocumentBuilder();
        Document doc = dBuilder.parse(fXmlFile);
        doc.getDocumentElement().normalize();

        LOG.info("{} :{}", localeString.getString("console_root_node"), doc.getDocumentElement().getNodeName());

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
                    LOG.info("{}", localeString.getString("console_config_old"));
                    hasFlagTag = false;
                    JOptionPane.showMessageDialog(this, localeString.getString("dialog_config_old"), "AutoDrive", JOptionPane.WARNING_MESSAGE);
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
        LOG.info("{}: {}", localeString.getString("console_config_load"), mapName);

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
                        loadImageButton.setEnabled(true);
                        LOG.info("{}}: {}", localeString.getString("console_editor_no_map"), mapName);
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

        mapMenuEnabled(true);
        saveMenuEnabled(true);

        nodeBoxSetEnabled(true);
        editorState = EDITORSTATE_MOVING;
        updateButtons();

        LOG.info("{}", localeString.getString("console_config_load_end"));
        return roadMap;

    }

    // this way to save a file under a new name is ugly but works :-/

    public void saveMap(String newName) {
        LOG.info("{}", localeString.getString("console_config_save_start"));
        RoadMap roadMap = mapPanel.getRoadMap();

        try
        {
            if (xmlConfigFile == null) return;
            saveXmlConfig(xmlConfigFile, roadMap, newName);
            setStale(false);
            JOptionPane.showMessageDialog(this, xmlConfigFile.getName() + " " + localeString.getString("dialog_save_success"), "AutoDrive", JOptionPane.INFORMATION_MESSAGE);
        } catch (Exception e) {
            LOG.error(e.getMessage(), e);
            JOptionPane.showMessageDialog(this, localeString.getString("dialog_save_fail"), "AutoDrive", JOptionPane.ERROR_MESSAGE);
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
            LOG.info("{}", localeString.getString("console_markers_new"));
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

        // write the content into xml file

        StreamResult result;

        if (newName == null) {
            result = new StreamResult(xmlConfigFile);
        } else {
            result = new StreamResult(new File(newName));
        }
        transformer.transform(source, result);

        LOG.info("{}", localeString.getString("console_config_save_end"));
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
