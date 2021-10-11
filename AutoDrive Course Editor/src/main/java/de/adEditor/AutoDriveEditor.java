package de.adEditor;

import de.adEditor.MapHelpers.MapMarker;
import de.adEditor.MapHelpers.MapNode;
import de.adEditor.MapHelpers.RoadMap;
import org.w3c.dom.Document;
import org.w3c.dom.Element;
import org.w3c.dom.Node;
import org.w3c.dom.NodeList;
import org.xml.sax.SAXException;

import javax.imageio.ImageIO;
import javax.swing.*;
import javax.swing.border.BevelBorder;
import javax.swing.border.Border;
import javax.swing.event.ChangeEvent;
import javax.swing.event.ChangeListener;
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
import java.util.*;

import static de.adEditor.ADUtils.*;
import static de.adEditor.GUIUtils.*;
import static de.adEditor.MapPanel.*;

/* TODO:
    (1) New features?
    (2) Undo function
    (2) Fix map refresh on window resizing...
    (3) New button icons
 */

public class AutoDriveEditor extends JFrame {

    public static final String AUTO_DRIVE_COURSE_EDITOR_TITLE = "AutoDrive Course Editor 0.2 Beta";

    public static final int EDITORSTATE_NOOP = -1;
    public static final int EDITORSTATE_MOVING = 0;
    public static final int EDITORSTATE_CONNECTING = 1;
    public static final int EDITORSTATE_CREATE_PRIMARY_NODE = 2;
    public static final int EDITORSTATE_CHANGE_NODE_PRIORITY = 3;
    public static final int EDITORSTATE_CREATE_SUBPRIO_NODE = 4;
    public static final int EDITORSTATE_DELETE_NODES = 5;
    public static final int EDITORSTATE_CREATING_DESTINATION = 6;
    public static final int EDITORSTATE_EDITING_DESTINATION = 7;
    public static final int EDITORSTATE_DELETING_DESTINATION = 8;
    public static final int EDITORSTATE_ALIGN_HORIZONTAL = 9;
    public static final int EDITORSTATE_ALIGN_VERTICAL = 10;
    public static final int EDITORSTATE_CNP_SELECT = 11;
    public static final int EDITORSTATE_CNP_CUT = 12;
    public static final int EDITORSTATE_CNP_COPY = 13;
    public static final int EDITORSTATE_CNP_PASTE = 14;

    public static final int EDITORSTATE_LINEARLINE = 13;
    public static final int EDITORSTATE_QUADRATICBEZIER = 14;


    public static final String MENU_LOAD_CONFIG = "Load Config";
    public static final String MENU_SAVE_CONFIG = "Save Config";
    public static final String MENU_SAVE_SAVEAS = "Save As";
    public static final String MENU_LOAD_IMAGE = "Load Map";
    public static final String MENU_ZOOM_1x = "1x";
    public static final String MENU_ZOOM_4x = "4x";
    public static final String MENU_ZOOM_16x = "16x";
    public static final String MENU_CHECKBOX_CONTINUECONNECT = "Continuous Connections";
    public static final String MENU_ABOUT = "About";



    public static final String BUTTON_MOVE_NODES = "Move Nodes";
    public static final String BUTTON_CONNECT_NODES = "Connect Nodes";
    public static final String BUTTON_CREATE_PRIMARY_NODE = "Create Primary Node";
    public static final String BUTTON_CHANGE_NODE_PRIORITY = "Change Priority";
    public static final String BUTTON_CREATE_SUBPRIO_NODE = "Create Secondary Node";
    public static final String BUTTON_CREATE_REVERSE_CONNECTION = "Create Reverse Connection";
    public static final String BUTTON_CREATE_DUAL_CONNECTION = "Create Dual Connection";
    public static final String BUTTON_REMOVE_NODES = "Remove Nodes";
    public static final String BUTTON_CREATE_DESTINATIONS = "Create Destinations";
    public static final String BUTTON_EDIT_DESTINATIONS_GROUPS = "Manage Destination Groups";
    public static final String BUTTON_DELETE_DESTINATIONS = "Remove Destinations";
    public static final String BUTTON_COPYPASTE_SELECT = "CopyPaste Select";
    public static final String BUTTON_COPYPASTE_CUT = "CopyPaste Cut";
    public static final String BUTTON_COPYPASTE_COPY = "CopyPaste Copy";
    public static final String BUTTON_COPYPASTE_PASTE = "CopyPaste Paste";

    // OCD modes

    public static final String BUTTON_ALIGN_HORIZONTAL = "Horizontally Align Nodes";
    public static final String BUTTON_ALIGN_VERTICAL = "Vertically Align Nodes";

    public static final String BUTTON_CREATE_LINEARLINE = "Linear Line";
    public static final String BUTTON_CREATE_QUADRATICBEZIER = "Quadratic Bezier";
    public static final String BUTTON_COMMIT_CURVE = "Confirm Curve";
    public static final String BUTTON_CANCEL_CURVE = "Cancel Curve";
    public static final String RADIOBUTTON_PATHTYPE_REGULAR = "Regular";
    public static final String RADIOBUTTON_PATHTYPE_SUBPRIO = "SubPrio";
    public static final String RADIOBUTTON_PATHTYPE_REVERSE = "Reverse";
    public static final String RADIOBUTTON_PATHTYPE_DUAL = "Dual";



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
    private JToggleButton createDualConnection;
    private JToggleButton editDestination;
    private JToggleButton alignHorizontal;
    private JToggleButton alignVertical;
    private JToggleButton linearLine;
    private JToggleButton quadBezier;
    private JToggleButton commitCurve;
    private JToggleButton cancelCurve;
    private JToggleButton select;
    private JToggleButton cut;
    private JToggleButton copy;
    private JToggleButton paste;

    public static JSlider numIterationsSlider;
    public static JPanel curvePanel;
    public static JTextArea textArea;
    public static JRadioButton curvePathRegular;
    public static JRadioButton curvePathSubPrio;
    public static JRadioButton curvePathReverse;
    public static JRadioButton curvePathDual;


    public EditorListener editorListener = new EditorListener(this);
    public static ResourceBundle localeString;
    public static Locale locale;

    public int editorState = EDITORSTATE_NOOP;
    public File xmlConfigFile;
    private boolean stale = false;
    private boolean hasFlagTag = false; // indicates if the loaded XML file has the <flags> tag in the <waypoints> element

    public static BufferedImage tractorImage;
    public static ImageIcon markerIcon;
    public static BufferedImage nodeImage;

    public static boolean bContinuousConnections = false; // default value

    public AutoDriveEditor() {
        super();

        localeString = ADUtils.getLocale();
        locale = Locale.getDefault();

        LOG.info(localeString.getString("console_start"));

        setTitle(createTitle());
        loadIcons();
        //setTractorIcon();
        //setMarkerIcon();
        //getNodeIcon();
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

        //
        // init menu bar
        //

        JMenuBar menuBar;
        JMenuItem menuItem;
        JMenu fileMenu, mapMenu, optionsMenu, helpMenu, subMenu;

        menuBar = new JMenuBar();

        // Create the file Menu
        fileMenu = makeMenu("menu_file", KeyEvent.VK_F, "menu_file_accstring", menuBar);
        makeMenuItem("menu_file_loadconfig",  "menu_file_loadconfig_accstring", KeyEvent.VK_L, InputEvent.ALT_DOWN_MASK, fileMenu, editorListener, MENU_LOAD_CONFIG, true );
        saveConfigMenuItem = makeMenuItem("menu_file_saveconfig",  "menu_file_saveconfig_accstring", KeyEvent.VK_S, InputEvent.ALT_DOWN_MASK, fileMenu, editorListener, MENU_SAVE_CONFIG, false );
        saveConfigAsMenuItem = makeMenuItem("menu_file_saveasconfig", "menu_file_saveasconfig_accstring",  KeyEvent.VK_A, InputEvent.ALT_DOWN_MASK,fileMenu, editorListener,MENU_SAVE_SAVEAS, false );

        // Create the Map Menu and it's scale sub menu
        mapMenu = makeMenu("menu_map", KeyEvent.VK_M, "menu_map_accstring", menuBar);
        loadImageButton = makeMenuItem("menu_map_loadimage", "menu_map_loadimage_accstring", KeyEvent.VK_M, InputEvent.ALT_DOWN_MASK,mapMenu,editorListener, MENU_LOAD_IMAGE, false );
        mapMenu.addSeparator();
        subMenu = makeSubMenu("menu_map_scale", KeyEvent.VK_M, "menu_map_scale_accstring", mapMenu);
        ButtonGroup menuZoomGroup = new ButtonGroup();
        makeRadioButtonMenuItem("menu_map_scale_1x", "menu_map_scale_1x_accstring",KeyEvent.VK_1, InputEvent.ALT_DOWN_MASK, subMenu, editorListener,  MENU_ZOOM_1x,true, menuZoomGroup, true);
        makeRadioButtonMenuItem("menu_map_scale_4x", "menu_map_scale_4x_accstring",KeyEvent.VK_2, InputEvent.ALT_DOWN_MASK, subMenu, editorListener,  MENU_ZOOM_4x,true, menuZoomGroup, false);
        makeRadioButtonMenuItem("menu_map_scale_16x", "menu_map_scale_16x_accstring",KeyEvent.VK_3, InputEvent.ALT_DOWN_MASK, subMenu, editorListener, MENU_ZOOM_16x, true, menuZoomGroup, false);

        // Create the Options menu

        optionsMenu = makeMenu("menu_options", KeyEvent.VK_O, "menu_options_accstring", menuBar);
        makeCheckBoxMenuItem("menu_conconnect", "menu_conconnect_accstring", KeyEvent.VK_C, bContinuousConnections, optionsMenu, editorListener, MENU_CHECKBOX_CONTINUECONNECT);

        // Create the Help menu

        helpMenu = makeMenu("menu_help", KeyEvent.VK_H, "menu_help_accstring", menuBar);
        makeMenuItem("menu_help_about", "menu_help_about_accstring", KeyEvent.VK_X, InputEvent.ALT_DOWN_MASK, helpMenu,editorListener, MENU_ABOUT, true );

        //
        // GUI init
        //

        // Create node panel
        JPanel nodeBox = new JPanel();
        nodeBox.setBorder(BorderFactory.createTitledBorder(localeString.getString("panel_nodes")));
        buttonPanel.add(nodeBox);

        moveNode = makeImageToggleButton("movenode", "movenode_selected", BUTTON_MOVE_NODES,"nodes_move_tooltip","nodes_move_alt", nodeBox, editorListener);
        connectNodes = makeImageToggleButton("connectnodes", "connectnodes_selected", BUTTON_CONNECT_NODES,"nodes_connect_tooltip","nodes_connect_alt", nodeBox, editorListener);
        createPrimaryNode = makeImageToggleButton("createprimary","createprimary_selected", BUTTON_CREATE_PRIMARY_NODE,"nodes_createprimary_tooltip","nodes_createprimary_alt", nodeBox, editorListener);
        createDualConnection = makeImageToggleButton("createdual","createdual_selected", BUTTON_CREATE_DUAL_CONNECTION,"nodes_createdual_tooltip","nodes_createdual_alt", nodeBox, editorListener);
        changePriority = makeImageToggleButton("swappriority","swappriority_selected", BUTTON_CHANGE_NODE_PRIORITY,"nodes_priority_tooltip","nodes_priority_alt", nodeBox, editorListener);
        createSecondaryNode = makeImageToggleButton("createsecondary","createsecondary_selected", BUTTON_CREATE_SUBPRIO_NODE,"nodes_createsecondary_tooltip","nodes_createsecondary_alt", nodeBox, editorListener);
        createReverseConnection = makeImageToggleButton("createreverse","createreverse_selected", BUTTON_CREATE_REVERSE_CONNECTION,"nodes_createreverse_tooltip","nodes_createreverse_alt", nodeBox, editorListener);

        nodeBox.add(Box.createRigidArea(new Dimension(8, 0)));
        removeNode = makeImageToggleButton("deletenodes","deletenodes_selected", BUTTON_REMOVE_NODES,"nodes_remove_tooltip","nodes_remove_alt", nodeBox, editorListener);

        //
        // Create markers panel
        //

        JPanel markerBox = new JPanel();
        markerBox.setBorder(BorderFactory.createTitledBorder(localeString.getString("panel_markers")));
        buttonPanel.add(markerBox);

        createDestination = makeImageToggleButton("addmarker","addmarker_selected", BUTTON_CREATE_DESTINATIONS,"markers_add_tooltip","markers_add_alt", markerBox, editorListener);
        editDestination = makeImageToggleButton("editmarker","editmarker_selected", BUTTON_EDIT_DESTINATIONS_GROUPS,"markers_edit_tooltip","markers_edit_alt", markerBox, editorListener);
        markerBox.add(Box.createRigidArea(new Dimension(8, 0)));
        removeDestination = makeImageToggleButton("deletemarker","deletemarker_selected", BUTTON_DELETE_DESTINATIONS,"markers_delete_tooltip","markers_delete_alt", markerBox, editorListener);

        //
        // Create alignment panel
        //

        JPanel alignBox = new JPanel();
        alignBox.setBorder(BorderFactory.createTitledBorder(localeString.getString("panel_align")));
        buttonPanel.add(alignBox);

        alignHorizontal = makeImageToggleButton("horizontalalign","horizontalalign_selected", BUTTON_ALIGN_HORIZONTAL,"align_horizontal_tooltip","align_horizontal_alt", alignBox, editorListener);
        alignVertical = makeImageToggleButton("verticalalign","verticalalign_selected", BUTTON_ALIGN_VERTICAL,"align_vertical_tooltip","align_vertical_alt", alignBox, editorListener);
        alignBox.add(Box.createRigidArea(new Dimension(16, 0)));

        //
        // copy/paste panel
        //

        JPanel copyBox = new JPanel();
        copyBox.setBorder(BorderFactory.createTitledBorder(localeString.getString("panel_copypaste")));
        copyBox.setVisible(false);
        buttonPanel.add(copyBox);

        select = makeImageToggleButton("select","select_selected", BUTTON_COPYPASTE_SELECT, "copypaste_select_tooltip","copypaste_select_alt", copyBox, editorListener);
        cut = makeImageToggleButton("cut","cut_selected", BUTTON_COPYPASTE_CUT, "copypaste_cut_tooltip","copypaste_cut_alt", copyBox, editorListener);
        copy = makeImageToggleButton("copy","copy_selected", BUTTON_COPYPASTE_COPY, "copypaste_copy_tooltip","copypaste_copy_alt", copyBox, editorListener);
        paste = makeImageToggleButton("paste","paste_selected", BUTTON_COPYPASTE_PASTE, "copypaste_paste_tooltip","copypaste_paste_alt", copyBox, editorListener);

        //
        // create experimental panel
        //

        JPanel testBox = new JPanel();
        testBox.setBorder(BorderFactory.createTitledBorder(localeString.getString("panel_helper")));
        buttonPanel.add(testBox);

        linearLine = makeImageToggleButton("linearline", BUTTON_CREATE_LINEARLINE,"helper_linearline_tooltip","helper_linearline_alt", testBox, editorListener);
        quadBezier = makeImageToggleButton("quadcurve","quadcurve_selected", BUTTON_CREATE_QUADRATICBEZIER,"helper_quadbezier_tooltip","helper_quadbezier_alt", testBox, editorListener);
        testBox.add(Box.createRigidArea(new Dimension(48, 0)));

        //
        // TEST - console area?
        //

        JPanel textPanel = new JPanel(new BorderLayout());
        textArea = new JTextArea("this is just a test\n ",3,0);
        JScrollPane scrollPane = new JScrollPane(textArea);
        textArea.setEditable(false);
        textPanel.add(scrollPane, BorderLayout.CENTER);
        this.add(textPanel, BorderLayout.PAGE_END);

        //
        // curve panel (hidden by default)
        //

        curvePanel = new JPanel();
        curvePanel.setLayout(new BoxLayout(curvePanel, BoxLayout.X_AXIS)); //create container ( left to right layout)
        curvePanel.setBorder(BorderFactory.createCompoundBorder(BorderFactory.createRaisedBevelBorder(), BorderFactory.createLoweredBevelBorder()));
        curvePanel.setVisible(false);
        curvePanel.setOpaque(true);
        curvePanel.setBackground(new Color(25,25,25,128));

        // create panel for slider using vertical layout
        JPanel slidePanel = new JPanel();
        slidePanel.setLayout(new BoxLayout(slidePanel, BoxLayout.Y_AXIS));
        slidePanel.setBorder(BorderFactory.createEmptyBorder());
        slidePanel.setOpaque(false);

        JLabel label = new JLabel(localeString.getString("panel_slider_label"));
        label.setForeground(Color.ORANGE);

        numIterationsSlider = new JSlider(JSlider.HORIZONTAL,0, 50, 10);
        numIterationsSlider.setVisible(true);
        numIterationsSlider.setOpaque(false);
        numIterationsSlider.setForeground(Color.ORANGE);
        numIterationsSlider.setMajorTickSpacing(10);
        numIterationsSlider.setPaintTicks(true);
        numIterationsSlider.setPaintLabels(true);
        numIterationsSlider.addChangeListener(editorListener);

        // create a panel for path radiobuttons using GridLayout
        JPanel curveRadioPanel = new JPanel();
        curveRadioPanel.setLayout(new GridLayout(2,2));
        curveRadioPanel.setBorder(BorderFactory.createBevelBorder(BevelBorder.RAISED, new Color(64,64,64), new Color(32,32,32)));
        curveRadioPanel.setOpaque(false);
        //curveRadioPanel.setBackground(new Color(30,30,55));

        ButtonGroup pathNodeGroup = new ButtonGroup();

        curvePathRegular = makeRadioButton("panel_slider_radio_regular", RADIOBUTTON_PATHTYPE_REGULAR,"panel_slider_radio_regular_tooltip", Color.ORANGE,true, false, curveRadioPanel, pathNodeGroup, null, editorListener);
        curvePathSubPrio = makeRadioButton("panel_slider_radio_subprio", RADIOBUTTON_PATHTYPE_SUBPRIO,"panel_slider_radio_subprio_tooltip", Color.ORANGE,false, false,curveRadioPanel, pathNodeGroup, null, editorListener);
        //ButtonGroup pathTypeGroup = new ButtonGroup();
        curvePathReverse = makeRadioButton("panel_slider_radio_reverse", RADIOBUTTON_PATHTYPE_REVERSE,"panel_slider_radio_reverse_tooltip", Color.ORANGE,false, false,curveRadioPanel, null, null, editorListener);
        curvePathDual = makeRadioButton("panel_slider_radio_dual", RADIOBUTTON_PATHTYPE_DUAL,"panel_slider_radio_dual_tooltip", Color.ORANGE,false, false,curveRadioPanel, null, null, editorListener);

        curvePanel.add(curveRadioPanel);
        slidePanel.add(label);
        slidePanel.add(numIterationsSlider);
        curvePanel.add(slidePanel);

        curvePanel.add(Box.createRigidArea(new Dimension(8, 0)));
        commitCurve = makeImageToggleButton("confirm","confirm_select", BUTTON_COMMIT_CURVE,"panel_slider_confirm","panel_slider_confirm_alt", curvePanel, editorListener);
        curvePanel.add(Box.createRigidArea(new Dimension(8, 0)));
        cancelCurve = makeImageToggleButton("cancel","cancel_select", BUTTON_CANCEL_CURVE,"panel_slider_cancel","panel_slider_cancel_alt", curvePanel, editorListener);
        curvePanel.add(Box.createRigidArea(new Dimension(8, 0)));
        mapPanel.add( new GUIUtils.AlphaContainer(curvePanel));

        //
        // update all gui components

        updateButtons();
        nodeBoxSetEnabled(false);
        markerBoxSetEnabled(false);
        alignBoxSetEnabled(false);
        copypasteBoxSetEnabled(false);
        experimentalBoxSetEnabled(false);

        this.setJMenuBar(menuBar);
        this.add(buttonPanel, BorderLayout.PAGE_START);

        pack();
        setLocationRelativeTo(null);
        this.setDefaultCloseOperation(JFrame.EXIT_ON_CLOSE);
    }

    private void loadIcons() {
        //AD Tractor icon for main window
        tractorImage = getIcon("tractor.png");
        setIconImage(tractorImage);
        // Marker Icon for Destination dialogs
        BufferedImage markerImage = getIcon("marker.png");
        markerIcon = new ImageIcon(markerImage);
        // test icon to replace g.fillArc
        nodeImage = getIcon("editor/node.png");
        //markerIcon = new ImageIcon(markerImage);

    }

    /*private void setTractorIcon() {
        tractorImage = getIcon("tractor.png");
        setIconImage(tractorImage);
    }

    private void setMarkerIcon() {
        BufferedImage markerImage = getIcon("marker.png");
        markerIcon = new ImageIcon(markerImage);
    }

    private void getNodeIcon() {
        nodeImage = getIcon("editor/node.png");
        //markerIcon = new ImageIcon(markerImage);
    }*/

    public static ImageIcon getMarkerIcon() {
        return markerIcon;
    }

    private void nodeBoxSetEnabled(boolean enabled) {
        moveNode.setEnabled(enabled);
        connectNodes.setEnabled(enabled);
        createPrimaryNode.setEnabled(enabled);
        changePriority.setEnabled(enabled);
        createSecondaryNode.setEnabled(enabled);
        createReverseConnection.setEnabled(enabled);
        removeNode.setEnabled(enabled);
        createDualConnection.setEnabled(enabled);
    }
    private void markerBoxSetEnabled(boolean enabled) {
        createDestination.setEnabled(enabled);
        editDestination.setEnabled(enabled);
        removeDestination.setEnabled(enabled);
    }

    private void alignBoxSetEnabled(boolean enabled) {
        alignHorizontal.setEnabled(enabled);
        alignVertical.setEnabled(enabled);
    }

    private void copypasteBoxSetEnabled(boolean enabled) {
        select.setEnabled(enabled);
        cut.setEnabled(enabled);
        copy.setEnabled(enabled);
        paste.setEnabled(enabled);
    }

    private void experimentalBoxSetEnabled(boolean enabled) {
        quadBezier.setEnabled(enabled);
        linearLine.setEnabled(enabled);
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
        createPrimaryNode.setSelected(false);
        changePriority.setSelected(false);
        createSecondaryNode.setSelected(false);
        createReverseConnection.setSelected(false);
        createDualConnection.setSelected(false);
        removeNode.setSelected(false);

        createDestination.setSelected(false);
        editDestination.setSelected(false);
        removeDestination.setSelected(false);

        alignHorizontal.setSelected(false);
        alignVertical.setSelected(false);

        select.setSelected(false);
        cut.setSelected(false);
        copy.setSelected(false);
        paste.setSelected(false);

        quadBezier.setSelected(false);
        linearLine.setSelected(false);



        switch (editorState) {
            case EDITORSTATE_MOVING:
                moveNode.setSelected(true);
                break;
            case EDITORSTATE_CONNECTING:
                if (connectionType == CONNECTION_STANDARD) {
                    connectNodes.setSelected(true);
                } else if (connectionType == CONNECTION_SUBPRIO) {
                    changePriority.setSelected(true);
                } else if (connectionType == CONNECTION_REVERSE) {
                    createReverseConnection.setSelected(true);
                } else if (connectionType == CONNECTION_DUAL) {
                    createDualConnection.setSelected(true);
                }
                break;
            case EDITORSTATE_CREATE_PRIMARY_NODE:
                createPrimaryNode.setSelected(true);
                break;
            case EDITORSTATE_CHANGE_NODE_PRIORITY:
                changePriority.setSelected(true);
                break;
            case EDITORSTATE_CREATE_SUBPRIO_NODE:
                createSecondaryNode.setSelected(true);
                break;
            case EDITORSTATE_DELETE_NODES:
                removeNode.setSelected(true);
                break;
            case EDITORSTATE_CREATING_DESTINATION:
                createDestination.setSelected(true);
                break;
            case EDITORSTATE_EDITING_DESTINATION:
                editDestination.setSelected(true);
                break;
            case EDITORSTATE_DELETING_DESTINATION:
                removeDestination.setSelected(true);
                break;
            case EDITORSTATE_ALIGN_HORIZONTAL:
                alignHorizontal.setSelected(true);
                break;
            case EDITORSTATE_ALIGN_VERTICAL:
                alignVertical.setSelected(true);
                break;
            case EDITORSTATE_CNP_SELECT:
                select.setSelected(true);
                break;
            case EDITORSTATE_QUADRATICBEZIER:
                quadBezier.setSelected(true);
            case EDITORSTATE_LINEARLINE:
                linearLine.setSelected(true);
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
                    LOG.info("{}", localeString.getString("console_config_old"));
                    hasFlagTag = false;
                    JOptionPane.showMessageDialog(this, localeString.getString("dialog_config_old"), "AutoDrive", JOptionPane.WARNING_MESSAGE);
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

        RoadMap roadMap = new RoadMap();
        roadMap.mapNodes = nodes;
        RoadMap.mapMarkers = mapMarkers;

        NodeList mapNameNode = doc.getElementsByTagName("MapName");
        Element mapNameElement = (Element) mapNameNode.item(0);

        String mapName, mapPath;
        URL url;

        if ( mapNameElement != null) {
            NodeList fstNm = mapNameElement.getChildNodes();
             mapName=(fstNm.item(0)).getNodeValue();
            LOG.info("{}: {}", localeString.getString("console_config_load"), mapName);
            mapPath = "/mapImages/" + mapName + ".png";
            url = AutoDriveEditor.class.getResource(mapPath);
        } else {
            mapName=null;
            mapPath=null;
            url=null;
        }



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
            /*mapPanel.setPreferredSize(new Dimension(1024, 768));
            mapPanel.setMinimumSize(new Dimension(1024, 768));*/
            repaint();
            //mapPanel.repaint();
        }

        mapMenuEnabled(true);
        saveMenuEnabled(true);

        nodeBoxSetEnabled(true);
        markerBoxSetEnabled(true);
        alignBoxSetEnabled(true);
        copypasteBoxSetEnabled(true);
        experimentalBoxSetEnabled(true);
        editorState = EDITORSTATE_NOOP;
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
