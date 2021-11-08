package de.adEditor;

import de.adEditor.MapHelpers.ChangeManager;
import de.adEditor.MapHelpers.MapMarker;
import de.adEditor.MapHelpers.MapNode;
import de.adEditor.MapHelpers.RoadMap;
import org.w3c.dom.*;
import org.xml.sax.SAXException;

import javax.imageio.ImageIO;
import javax.swing.*;
import javax.xml.parsers.DocumentBuilder;
import javax.xml.parsers.DocumentBuilderFactory;
import javax.xml.parsers.ParserConfigurationException;
import javax.xml.transform.*;
import javax.xml.transform.dom.DOMSource;
import javax.xml.transform.stream.StreamResult;
import javax.xml.xpath.XPath;
import javax.xml.xpath.XPathConstants;
import javax.xml.xpath.XPathExpressionException;
import javax.xml.xpath.XPathFactory;
import java.awt.*;
import java.awt.event.WindowAdapter;
import java.awt.event.WindowEvent;
import java.awt.image.BufferedImage;
import java.io.File;
import java.io.FileOutputStream;
import java.io.IOException;
import java.net.URL;
import java.util.*;

import static de.adEditor.ADUtils.*;
import static de.adEditor.GUIBuilder.quadSliderDefault;
import static de.adEditor.GUIBuilder.quadSliderMax;
import static de.adEditor.MapPanel.getMapPanel;

/* TODO:
    (1) New features?
    (2) Undo function - In Progress
    (2) Fix map refresh on window resizing - Partial Fix Found 7/11/21
    (3) New button icons
 */

public class AutoDriveEditor extends JFrame {

    public static final String AUTODRIVE_COURSE_EDITOR_TITLE = "AutoDrive Course Editor 0.3.0 Beta";
    public static final String AUTODRIVE_INTERNAL_VERSION = "0.3.0-beta";
    private String lastRunVersion;
    public static boolean DEBUG = false;
    public static boolean EXPERIMENTAL = false;

    public EditorListener editorListener;
    public static ResourceBundle localeString;
    public static Locale locale;

    public static int editorState = GUIBuilder.EDITORSTATE_NOOP;
    public static File xmlConfigFile;
    private boolean hasFlagTag = false; // indicates if the loaded XML file has the <flags> tag in the <waypoints> element
    public static boolean oldConfigFormat = false;

    public static BufferedImage tractorImage;
    public static BufferedImage nodeImage;
    public static BufferedImage nodeImageSelected;
    public static BufferedImage subPrioNodeImage;
    public static BufferedImage subPrioNodeImageSelected;
    public static BufferedImage controlPointImage;
    public static BufferedImage controlPointImageSelected;
    public static BufferedImage curveNodeImage;

    public static ImageIcon markerIcon;
    public static ImageIcon regularConnectionIcon;
    public static ImageIcon regularConnectionSelectedIcon;
    public static ImageIcon regularConnectionSubPrioIcon;
    public static ImageIcon regularConnectionSubPrioSelectedIcon;
    public static ImageIcon dualConnectionIcon;
    public static ImageIcon dualConnectionSelectedIcon;
    public static ImageIcon dualConnectionSubPrioIcon;
    public static ImageIcon dualConnectionSubPrioSelectedIcon;
    public static ImageIcon reverseConnectionIcon;
    public static ImageIcon reverseConnectionSelectedIcon;
    public static ImageIcon reverseConnectionSubPrioIcon;
    public static ImageIcon reverseConnectionSubPrioSelectedIcon;

    public static boolean bContinuousConnections = false; // default value
    public static boolean bMiddleMouseMove = false; // default value
    public static int controlPointMoveScaler = 1; // default value
    public static int linearLineNodeDistance = 12;

    public static ChangeManager changeManager;

    public AutoDriveEditor() {
        super();

        localeString = ADUtils.getLocale();
        locale = Locale.getDefault();

        LOG.info(localeString.getString("console_start"));

        setTitle(createTitle());
        loadIcons();
        loadEditorXMLConfig();
        setPreferredSize(new Dimension(1024,768));
        addWindowListener(new WindowAdapter() {
            @Override
            public void windowClosing(WindowEvent e) {
                if (MapPanel.getMapPanel().isStale()) {
                    int response = JOptionPane.showConfirmDialog(null, localeString.getString("dialog_exit_unsaved"), "AutoDrive", JOptionPane.YES_NO_OPTION, JOptionPane.QUESTION_MESSAGE);
                    if (response == JOptionPane.YES_OPTION) {
                        saveMap(null);
                    }
                }
                saveEditorXMLConfig();
                super.windowClosing(e);
            }
        });
        setLayout(new BorderLayout());

        editorListener = new EditorListener(this);

        // init menu bar
        GUIBuilder.createMenu(editorListener);
        setJMenuBar(GUIBuilder.menuBar);

        this.add(GUIBuilder.createButtonPanel(editorListener), BorderLayout.PAGE_START);
        this.add(GUIBuilder.createMapPanel(this, editorListener), BorderLayout.CENTER);
        this.add(GUIBuilder.initTextPanel(), BorderLayout.PAGE_END);

        GUIBuilder.editMenuEnabled(false);
        GUIBuilder.updateGUIButtons(false);
        pack();
        setLocationRelativeTo(null);
        this.setDefaultCloseOperation(JFrame.EXIT_ON_CLOSE);
        if (lastRunVersion != null && !lastRunVersion.equals(AUTODRIVE_INTERNAL_VERSION)) {
            LOG.info("Version Updated Detected");
            // TODO display new version notes
        }

        changeManager = new ChangeManager();

    }

    private void loadIcons() {
        //AD Tractor icon for main window
        tractorImage = getImage("tractor.png");
        setIconImage(tractorImage);
        // Marker Icon for Destination dialogs
        markerIcon = getIcon("marker.png");
        // node images for MapPanel
        nodeImage = getImage("node.png");
        nodeImageSelected = getImage("node_selected.png");
        subPrioNodeImage = getImage("subprionode.png");
        subPrioNodeImageSelected = getImage("subprionode_selected.png");
        controlPointImage = getImage("controlpoint.png");
        controlPointImageSelected = getImage("controlpoint_selected.png");
        curveNodeImage = getImage("curvenode.png");

        // icons for dual state buttons

        regularConnectionIcon = getIcon("connectregular.png");
        regularConnectionSelectedIcon = getIcon("connectregular_selected.png");
        regularConnectionSubPrioIcon = getIcon("connectregular_subprio.png");
        regularConnectionSubPrioSelectedIcon = getIcon("connectregular_subprio_selected.png");

        dualConnectionIcon = getIcon("connectdual.png");
        dualConnectionSelectedIcon = getIcon("connectdual_selected.png");
        dualConnectionSubPrioIcon = getIcon("connectdual_subprio.png");
        dualConnectionSubPrioSelectedIcon = getIcon("connectdual_subprio_selected.png");

        reverseConnectionIcon = getIcon("connectreverse.png");
        reverseConnectionSelectedIcon = getIcon("connectreverse_selected.png");
        reverseConnectionSubPrioIcon = getIcon("connectreverse_subprio.png");
        reverseConnectionSubPrioSelectedIcon = getIcon("connectreverse_subprio_selected.png");
    }

    public static ImageIcon getMarkerIcon() {
        return markerIcon;
    }

    public static void main(String[] args) {
        // set look and feel to the system look and feel
        try {
            UIManager.setLookAndFeel(UIManager.getSystemLookAndFeelClassName());
        } catch (Exception ex) {
            LOG.error(ex.getMessage(), ex);
        }

        LOG.info("Java Runtime Version {}", Runtime.version().feature());

        for (int i=0;i<args.length;i++) {
            if (Objects.equals(args[i], "-DEBUG")) {
                DEBUG = true;
                LOG.info("##");
                LOG.info("## WARNING ..... Debug mode active, editor performance may be slower then normal");
                LOG.info("##");
            }
            if (Objects.equals(args[i], "-EXPERIMENTAL")) {
                EXPERIMENTAL = true;
                LOG.info("##");
                LOG.info("## WARNING ..... Experimental features are unlocked, config corruption is possible.. USE --ONLY-- ON BACKUP CONFIGS!!");
                LOG.info("##");
            }
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
            getMapPanel().setRoadMap(loadXmlConfigFile(fXmlFile));
            setTitle(AUTODRIVE_COURSE_EDITOR_TITLE + " - " + fXmlFile.getAbsolutePath());
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

        if (getTextValue(null, doc.getDocumentElement(), "markerID") != null) {
            JOptionPane.showConfirmDialog(null, "" + localeString.getString("console_config_unsupported1") + "\n\n" + localeString.getString("console_config_unsupported2"), "AutoDrive", JOptionPane.DEFAULT_OPTION, JOptionPane.WARNING_MESSAGE);
            LOG.info("## {}",localeString.getString("console_config_unsupported1"));
            LOG.info("## {}",localeString.getString("console_config_unsupported2"));
            oldConfigFormat = true;
        } else {
            String configversion = getTextValue(null, doc.getDocumentElement(), "version");
            LOG.info("{} {}", localeString.getString("console_config_version"), configversion);
            oldConfigFormat = false;
        }

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

                    MapNode dummyNode = new MapNode((int)Double.parseDouble(markerNodeId), 0, 0, 0, 0, false);
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
                if ( node !=null ) {
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

                            MapNode mapNode = new MapNode(id, x, y, z, flag, false);
                            nodes.add(mapNode);
                        }
                    } else {
                        hasFlagTag = false;
                        for (int i=0; i<ids.length; i++) {
                            int id = Integer.parseInt(ids[i]);
                            double x = Double.parseDouble(xValues[i]);
                            double y = Double.parseDouble(yValues[i]);
                            double z = Double.parseDouble(zValues[i]);
                            int flag = 0;

                            MapNode mapNode = new MapNode(id, x, y, z, flag, false);
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
        }

        RoadMap roadMap = new RoadMap();
        roadMap.mapNodes = nodes;
        roadMap.mapMarkers = mapMarkers;

        NodeList mapNameNode = doc.getElementsByTagName("MapName");
        Element mapNameElement = (Element) mapNameNode.item(0);

        String mapName, mapPath;
        URL url;

        if ( mapNameElement != null) {
            NodeList fstNm = mapNameElement.getChildNodes();
             mapName=(fstNm.item(0)).getNodeValue();
            LOG.info("{} : {}", localeString.getString("console_config_load"), mapName);
            mapPath = "/mapImages/" + mapName + ".png";
            url = AutoDriveEditor.class.getResource(mapPath);
        } else {
            mapName=null;
            mapPath=null;
            url=null;
        }

        BufferedImage image = null;
        String location = getCurrentLocation();

        if (mapName != null) {
            try {
                image = ImageIO.read(url);
            } catch (Exception e) {
                try {
                    LOG.info("failed to load map image from JAR .. trying alternate locations");
                    if (location != null) {
                        mapPath = location + "mapImages/" + mapName + ".png";
                    } else {
                        mapPath = "./mapImages/" + mapName + ".png";
                    }
                    image = ImageIO.read(new File(mapPath));
                } catch (Exception e1) {
                    LOG.info("failed to load map image from {}", mapPath.substring(1));
                    try {
                        if (location != null) {
                            mapPath = location + "src/main/resources/mapImages/" + mapName + ".png";
                        } else {
                            mapPath = "./src/mapImages/" + mapName + ".png";
                        }
                        image = ImageIO.read(new File(mapPath));
                    } catch (Exception e2) {
                        LOG.info("failed to load map image from {}", mapPath.substring(1));
                        try {
                            if (location != null) {
                                mapPath = location + mapName + ".png";
                            } else {
                                mapPath = "./" + mapName + ".png";
                            }
                            image = ImageIO.read(new File(mapPath));
                        } catch (Exception e3) {
                            LOG.info("failed to load map image from {}", mapPath.substring(1));
                            GUIBuilder.loadImageButton.setEnabled(true);
                            LOG.info("{}", localeString.getString("console_editor_no_map"));
                            JOptionPane.showConfirmDialog(null, "" + localeString.getString("dialog_mapimage_not_found"), "File Not Found - " + mapName + ".png", JOptionPane.DEFAULT_OPTION, JOptionPane.WARNING_MESSAGE);
                            if (EXPERIMENTAL) {

                                //
                                // This is proof of concept test code - This may get removed at any point
                                //

                                //where to download file

                                String fullPath;
                                if (location != null) {
                                    String gitPath = "https://github.com/KillBait/FS19_AutoDrive_MapImages/raw/main/mapImages/" + mapName + ".png";
                                    LOG.info("trying GitHub repository - {}",gitPath);
                                    URL gitUrl = new URL(gitPath);

                                    fullPath = location + "mapImages/" + mapName + ".png";
                                    File file = new File(fullPath);

                                    if (DEBUG) LOG.info("Saving to {}", fullPath);

                                    File mapImage = ADUtils.copyURLToFile(gitUrl, file);

                                    if (mapImage != null) {
                                        image = ImageIO.read(mapImage);
                                    } else {
                                        fullPath = "/mapImages/Blank.png";
                                        url = AutoDriveEditor.class.getResource(fullPath);
                                        if (url != null) {
                                            image = ImageIO.read(url);
                                        }
                                    }
                                } else {
                                    if (DEBUG) LOG.info("getCurrentLocation returned null - using blank.png");
                                    fullPath = "/mapImages/Blank.png";
                                    url = AutoDriveEditor.class.getResource(fullPath);
                                    if (url != null) {
                                        image = ImageIO.read(url);
                                    }
                                }
                            }
                        }
                    }
                }
            }
        } else {
            LOG.info("Cannot reliably extract map name - using blank.png");
            mapPath = "/mapImages/Blank.png";
            url = AutoDriveEditor.class.getResource(mapPath);
            image = ImageIO.read(url);
        }

        if (image != null) {
            getMapPanel().setImage(image);
            GUIBuilder.updateGUIButtons(true);
        }

        if (getMapPanel().getImage() != null) {
            getMapPanel().repaint();
        }


        GUIBuilder.mapMenuEnabled(true);



        editorState = GUIBuilder.EDITORSTATE_NOOP;

        LOG.info("{}", localeString.getString("console_config_load_end"));
        return roadMap;

    }

    // this way to save a file under a new name is ugly but works :-/

    public void saveMap(String newName) {
        LOG.info("{}", localeString.getString("console_config_save_start"));
        RoadMap roadMap = getMapPanel().getRoadMap();

        try
        {
            if (xmlConfigFile == null) return;
            saveXmlConfig(xmlConfigFile, roadMap, newName);
            MapPanel.getMapPanel().setStale(false);
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



        for (int markerIndex = 1; markerIndex < roadMap.mapMarkers.size() + 100; markerIndex++) {
            Element element = (Element) doc.getElementsByTagName("mm" + (markerIndex)).item(0);
            if (element != null) {
                Element parent = (Element) element.getParentNode();
                while (parent.hasChildNodes())
                    parent.removeChild(parent.getFirstChild());
            }
        }


        NodeList testwaypoints = doc.getElementsByTagName("mapmarker");

        if (roadMap.mapMarkers.size() > 0 && testwaypoints.getLength() == 0 ) {
            LOG.info("{}", localeString.getString("console_markers_new"));
            Element test = doc.createElement("mapmarker");
            AutoDrive.appendChild(test);
        }

        NodeList markerList = doc.getElementsByTagName("mapmarker");
        Node markerNode = markerList.item(0);
        int mapMarkerCount = 1;
        for (MapMarker mapMarker : roadMap.mapMarkers) {
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
            File newFile = new File(newName);
            LOG.info("Saving config as {}",newName);
            result = new StreamResult(newFile);
            xmlConfigFile = newFile;
            setTitle(createTitle());
        }
        transformer.transform(source, result);

        LOG.info("{}", localeString.getString("console_config_save_end"));
    }

    public void loadEditorXMLConfig() {
        DocumentBuilderFactory docFactory = DocumentBuilderFactory.newInstance();
        try {
            DocumentBuilder docBuilder = docFactory.newDocumentBuilder();
            Document doc = docBuilder.parse("EditorConfig.xml");
            Element e = doc.getDocumentElement();

            lastRunVersion = getTextValue(lastRunVersion, e, "Version");
            bContinuousConnections = getBooleanValue(bContinuousConnections, e, "Continuous_Connection");
            bMiddleMouseMove = getBooleanValue(bMiddleMouseMove, e, "MiddleMouseMove");
            linearLineNodeDistance = getIntegerValue(linearLineNodeDistance, e, "LinearLineNodeDistance");
            quadSliderMax = getIntegerValue(quadSliderMax, e, "QuadSliderMaximum");
            quadSliderDefault = getIntegerValue(quadSliderDefault, e, "QuadSliderDefault");
            controlPointMoveScaler = getIntegerValue(controlPointMoveScaler, e, "ControlPointMoveScaler");

        } catch (ParserConfigurationException | SAXException pce) {
            LOG.error("## Exception in loading Editor config ## SAX/Parser Exception");
            System.out.println(pce.getMessage());
        } catch (IOException ioe) {
            LOG.warn(localeString.getString("console_editor_config_load_not_found"));
        }
    }

    public void saveEditorXMLConfig() {
        DocumentBuilderFactory docFactory = DocumentBuilderFactory.newInstance();
        try {
            DocumentBuilder docBuilder = docFactory.newDocumentBuilder();
            Document doc = docBuilder.newDocument();
            Element root = doc.createElement("EditorConfig");

            setTextValue("Version", doc, AUTODRIVE_INTERNAL_VERSION, root);
            setBooleanValue("Continuous_Connection", doc, bContinuousConnections, root);
            setBooleanValue("MiddleMouseMove", doc, bMiddleMouseMove, root);
            setIntegerValue("LinearLineNodeDistance", doc, linearLineNodeDistance, root);
            setIntegerValue("QuadSliderMaximum", doc, quadSliderMax, root);
            setIntegerValue("QuadSliderDefault", doc, quadSliderDefault, root);
            setIntegerValue("ControlPointMoveScaler", doc, controlPointMoveScaler, root);


            doc.appendChild(root);

            try {
                Transformer transformer = TransformerFactory.newInstance().newTransformer();
                transformer.setOutputProperty(OutputKeys.INDENT, "yes");
                transformer.setOutputProperty(OutputKeys.METHOD, "xml");
                transformer.setOutputProperty(OutputKeys.ENCODING, "UTF-8");
                transformer.setOutputProperty("{http://xml.apache.org/xslt}indent-amount", "4");

                DOMSource source = new DOMSource(doc);
                StreamResult result;

                try {
                    result = new StreamResult(new FileOutputStream("EditorConfig.xml"));
                    transformer.transform(source, result);
                    LOG.info("{}", localeString.getString("console_editor_config_save_end"));
                } catch (IOException ioe) {
                    LOG.error( localeString.getString("console_editor_config_save_error"));
                }

            } catch (TransformerFactoryConfigurationError | TransformerException | IllegalArgumentException transformerFactoryConfigurationError) {
                transformerFactoryConfigurationError.printStackTrace();
            }
        } catch (ParserConfigurationException | DOMException e) {
            LOG.error("## Exception in saving Editor config ## SAX/Parser Exception");
            e.printStackTrace();

    }
    }

    private void setTextValue(String tag, Document doc, String textNode, Element element) {
        Element e;
        e = doc.createElement(tag);
        e.appendChild(doc.createTextNode(textNode));
        element.appendChild(e);
    }

    private void setBooleanValue(String tag, Document doc, Boolean bool, Element element) {
        Element e;
        e = doc.createElement(tag);
        e.appendChild(doc.createTextNode(String.valueOf(bool)));
        element.appendChild(e);
    }

    private void setIntegerValue(String tag, Document doc, int value, Element element) {
        Element e;
        e = doc.createElement(tag);
        e.appendChild(doc.createTextNode(String.valueOf(value)));
        element.appendChild(e);
    }

    private String getTextValue(String def, Element doc, String tag) {
        String value = def;
        NodeList nl;
        nl = doc.getElementsByTagName(tag);
        if (nl.getLength() > 0 && nl.item(0).hasChildNodes()) {
            value = nl.item(0).getFirstChild().getNodeValue();
        }
        return value;
    }

    private Boolean getBooleanValue(Boolean def, Element doc, String tag) {
        Boolean value = def;
        NodeList nl;
        nl = doc.getElementsByTagName(tag);
        if (nl.getLength() > 0 && nl.item(0).hasChildNodes()) {
            value = Boolean.valueOf(nl.item(0).getFirstChild().getNodeValue());
        }
        return value;
    }

    private Integer getIntegerValue(int def, Element doc, String tag) {
        int value = def;
        NodeList nl;
        nl = doc.getElementsByTagName(tag);
        if (nl.getLength() > 0 && nl.item(0).hasChildNodes()) {
            value = Integer.parseInt(nl.item(0).getFirstChild().getNodeValue());
        }
        return value;
    }

    public void updateMapZoomFactor(int zoomFactor) {
        getMapPanel().setMapZoomFactor(zoomFactor);
        getMapPanel().repaint();
    }

    public static String createTitle() {
        StringBuilder sb = new StringBuilder();
        sb.append(AUTODRIVE_COURSE_EDITOR_TITLE);
        if (xmlConfigFile != null) {
            sb.append(" - ").append(xmlConfigFile.getAbsolutePath()).append(MapPanel.getMapPanel().isStale() ? " *" : "");
        }
        return sb.toString();
    }
}
