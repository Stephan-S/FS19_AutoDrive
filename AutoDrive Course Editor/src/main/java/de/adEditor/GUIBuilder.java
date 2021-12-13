package de.adEditor;

import javax.swing.*;
import javax.swing.border.BevelBorder;
import java.awt.*;
import java.awt.event.InputEvent;
import java.awt.event.KeyEvent;
import java.awt.event.MouseEvent;
import java.awt.event.MouseMotionListener;
import java.awt.geom.AffineTransform;
import java.awt.geom.Point2D;

import de.adEditor.MapHelpers.CopyPasteManager;

import static de.adEditor.ADUtils.LOG;
import static de.adEditor.GUIUtils.*;
import static de.adEditor.AutoDriveEditor.*;
import static de.adEditor.MapPanel.*;
import static java.lang.Math.PI;
import static javax.swing.BoxLayout.*;

public class GUIBuilder {

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
    public static final int EDITORSTATE_QUADRATICBEZIER = 15;
    public static final int EDITORSTATE_CUBICBEZIER = 16;


    public static final String MENU_LOAD_CONFIG = "Load Config";
    public static final String MENU_SAVE_CONFIG = "Save Config";
    public static final String MENU_SAVE_SAVEAS = "Save As";
    public static final String MENU_EXIT = "Exit";
    public static final String MENU_LOAD_IMAGE = "Load Map Image";
    public static final String MENU_SAVE_IMAGE = "Save Map Image";
    public static final String MENU_IMPORT_DDS = "Import DDS";
    public static final String MENU_EDIT_UNDO = "Undo";
    public static final String MENU_EDIT_REDO = "Redo";
    public static final String MENU_EDIT_CUT = "Cut";
    public static final String MENU_EDIT_COPY = "Copy";
    public static final String MENU_EDIT_PASTE = "Paste";
    public static final String MENU_ZOOM_1x = "1x";
    public static final String MENU_ZOOM_4x = "4x";
    public static final String MENU_ZOOM_16x = "16x";
    public static final String MENU_CHECKBOX_CONTINUECONNECT = "Continuous Connections";
    public static final String MENU_CHECKBOX_MIDDLEMOUSEMOVE = "Middle Mouse Move";
    public static final String MENU_GRID_SET = "Grid Set";
    public static final String MENU_GRID_SHOW = "Grid Show";
    public static final String MENU_GRID_SNAP = "Grid Snap";
    public static final String MENU_GRID_SNAP_SUBS = "Grid Snap Subs";
    public static final String MENU_ROTATE_SET = "Set Rotate Step";
    public static final String MENU_ROTATE_CLOCKWISE_NINTY ="Rotate 90 Clockwise";
    public static final String MENU_ROTATE_ANTICLOCKWISE_NINTY ="Rotate 90 Anticlockwise";
    public static final String MENU_ROTATE_CLOCKWISE="Rotate Clockwise";
    public static final String MENU_ROTATE_ANTICLOCKWISE="Rotate Anticlockwise";
    public static final String MENU_ABOUT = "About";

    public static final String MENU_DEBUG_SHOWID = "DEBUG ID";
    public static final String MENU_DEBUG_FILEIO = "DEBUG CONFIG";
    public static final String MENU_DEBUG_SELECTED_LOCATION = "DEBUG SELECTED LOCATION";
    public static final String MENU_DEBUG_PROFILE = "DEBUG PROFILE";
    public static final String MENU_DEBUG_UNDO = "DEBUG UNDO/REDO SYSTEM";
    public static final String MENU_DEBUG_ZOOMSCALE = "ZOOMSCALE";
    //public static final String MENU_DEBUG_TEST = "TEST";
    public static final String MENU_DEBUG_TEST = "TEST";


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
    public static final String BUTTON_CREATE_CUBICBEZIER = "Cubic Bezier";
    public static final String BUTTON_COMMIT_CURVE = "Confirm Curve";
    public static final String BUTTON_CANCEL_CURVE = "Cancel Curve";
    public static final String RADIOBUTTON_PATHTYPE_REGULAR = "Regular";
    public static final String RADIOBUTTON_PATHTYPE_SUBPRIO = "SubPrio";
    public static final String RADIOBUTTON_PATHTYPE_REVERSE = "Reverse";
    public static final String RADIOBUTTON_PATHTYPE_DUAL = "Dual";

    public static MapPanel mapPanel;
    public static JMenuBar menuBar;
    public static JMenuItem loadImageMenuItem;
    public static JMenuItem importDDSMenuItem;
    public static JMenuItem saveImageMenuItem;
    public static JMenuItem saveConfigMenuItem;
    public static JMenuItem saveConfigAsMenuItem;
    public static JMenuItem undoMenuItem;
    public static JMenuItem redoMenuItem;
    public static JMenuItem cutMenuItem;
    public static JMenuItem copyMenuItem;
    public static JMenuItem pasteMenuItem;
    public static JMenuItem zoomOneX;
    public static JMenuItem zoomFourX;
    public static JMenuItem zoomSixteenX;
    public static JMenuItem gridSnapMenuItem;
    public static JMenuItem gridSnapSubDivisionMenuItem;

    public static JMenuItem rClockwiseMenuItem;
    public static JMenuItem r90ClockwiseMenuItem;
    public static JMenuItem rAntiClockwiseMenuItem;
    public static JMenuItem r90AntiClockwiseMenuItem;


    public static boolean bShowGrid;
    public static boolean bGridSnap;
    public static boolean bGridSnapSubs;


    public static boolean bDebugShowID;
    public static boolean bDebugFileIO;
    public static boolean bDebugShowSelectedLocation;
    public static boolean bDebugProfile;
    public static boolean bDebugUndoRedo;
    public static boolean bDebugZoomScale;
    public static boolean bDebugTest;

    public static JPanel nodeBox;
    public static JToggleButton removeNode;
    public static JToggleButton removeDestination;
    public static JToggleButton moveNode;
    public static JToggleButton createRegularConnection;
    public static JToggleButton createPrimaryNode;
    public static JToggleButton createDestination;
    public static JToggleButton changePriority;
    public static JToggleButton createSecondaryNode;
    public static JToggleButton createReverseConnection;
    public static JToggleButton createDualConnection;
    public static JToggleButton editDestination;
    public static JToggleButton alignHorizontal;
    public static JToggleButton alignVertical;
    public static JToggleButton linearLine;
    public static JToggleButton quadBezier;
    public static JToggleButton cubicBezier;
    public static JToggleButton commitCurve;
    public static JToggleButton cancelCurve;
    public static JToggleButton select;
    public static JToggleButton cut;
    public static JToggleButton copy;
    public static JToggleButton paste;

    public static JSlider numIterationsSlider;
    public static JPanel curvePanel;
    public static JTextArea textArea;
    public static JRadioButton curvePathRegular;
    public static JRadioButton curvePathSubPrio;
    public static JRadioButton curvePathReverse;
    public static JRadioButton curvePathDual;

    public static int quadSliderMax = 50;
    public static int quadSliderDefault = 10;

    public static void createMenu(EditorListener editorListener) {
        JMenuItem menuItem;
        JMenu fileMenu, editMenu, mapMenu, optionsMenu, helpMenu, subMenu, gridMenu, rotationMenu, debugMenu;

        menuBar = new JMenuBar();

        // Create the file Menu

        fileMenu = makeMenu("menu_file", KeyEvent.VK_F, "menu_file_accstring", menuBar);
        makeMenuItem("menu_file_loadconfig",  "menu_file_loadconfig_accstring", KeyEvent.VK_L, InputEvent.ALT_DOWN_MASK, fileMenu, editorListener, MENU_LOAD_CONFIG, true );
        saveConfigMenuItem = makeMenuItem("menu_file_saveconfig",  "menu_file_saveconfig_accstring", KeyEvent.VK_S, InputEvent.ALT_DOWN_MASK, fileMenu, editorListener, MENU_SAVE_CONFIG, false );
        saveConfigAsMenuItem = makeMenuItem("menu_file_saveasconfig", "menu_file_saveasconfig_accstring",  KeyEvent.VK_A, InputEvent.ALT_DOWN_MASK,fileMenu, editorListener,MENU_SAVE_SAVEAS, false );
        makeMenuItem("menu_file_exit",  "menu_file_exit_accstring", KeyEvent.VK_Q, InputEvent.ALT_DOWN_MASK, fileMenu, editorListener, MENU_EXIT, true );

        // Create the edit menu

        editMenu = makeMenu("menu_edit", KeyEvent.VK_E, "menu_edit_accstring", menuBar);

        // Create the Undo/Redo menu

        undoMenuItem = makeMenuItem("menu_edit_undo",  "menu_edit_undo_accstring", KeyEvent.VK_Z, InputEvent.CTRL_DOWN_MASK, editMenu, editorListener, MENU_EDIT_UNDO, false );
        redoMenuItem = makeMenuItem("menu_edit_redo",  "menu_edit_redo_accstring", KeyEvent.VK_Z, InputEvent.SHIFT_DOWN_MASK, editMenu, editorListener, MENU_EDIT_REDO, false );
        cutMenuItem = makeMenuItem("menu_edit_cut",  "menu_edit_cut_accstring", KeyEvent.VK_X, InputEvent.CTRL_DOWN_MASK, editMenu, editorListener, BUTTON_COPYPASTE_CUT, false );
        copyMenuItem = makeMenuItem("menu_edit_copy",  "menu_edit_copy_accstring", KeyEvent.VK_C, InputEvent.CTRL_DOWN_MASK, editMenu, editorListener, BUTTON_COPYPASTE_COPY, false );
        pasteMenuItem = makeMenuItem("menu_edit_paste",  "menu_edit_paste_accstring", KeyEvent.VK_V, InputEvent.CTRL_DOWN_MASK, editMenu, editorListener, BUTTON_COPYPASTE_PASTE, false );


        // Create the Map Menu and it's scale sub menu

        mapMenu = makeMenu("menu_map", KeyEvent.VK_M, "menu_map_accstring", menuBar);
        loadImageMenuItem = makeMenuItem("menu_map_loadimage", "menu_map_loadimage_accstring", KeyEvent.VK_M, InputEvent.ALT_DOWN_MASK,mapMenu,editorListener, MENU_LOAD_IMAGE, false );

        mapMenu.addSeparator();
        subMenu = makeSubMenu("menu_map_scale", KeyEvent.VK_M, "menu_map_scale_accstring", mapMenu);
        ButtonGroup menuZoomGroup = new ButtonGroup();
        zoomOneX = makeRadioButtonMenuItem("menu_map_scale_1x", "menu_map_scale_1x_accstring",KeyEvent.VK_1, InputEvent.ALT_DOWN_MASK, subMenu, editorListener,  MENU_ZOOM_1x,true, menuZoomGroup, true);
        zoomFourX = makeRadioButtonMenuItem("menu_map_scale_4x", "menu_map_scale_4x_accstring",KeyEvent.VK_2, InputEvent.ALT_DOWN_MASK, subMenu, editorListener,  MENU_ZOOM_4x,true, menuZoomGroup, false);
        zoomSixteenX = makeRadioButtonMenuItem("menu_map_scale_16x", "menu_map_scale_16x_accstring",KeyEvent.VK_3, InputEvent.ALT_DOWN_MASK, subMenu, editorListener, MENU_ZOOM_16x, true, menuZoomGroup, false);
        mapMenu.addSeparator();
        importDDSMenuItem = makeMenuItem("menu_import_dds", "menu_import_dds_accstring", KeyEvent.VK_I, InputEvent.ALT_DOWN_MASK, mapMenu, editorListener, MENU_IMPORT_DDS, false);
        saveImageMenuItem = makeMenuItem("menu_map_saveimage", "menu_map_saveimage_accstring", KeyEvent.VK_B, InputEvent.ALT_DOWN_MASK, mapMenu, editorListener, MENU_SAVE_IMAGE, false);

        // create the Options menu

        optionsMenu = makeMenu("menu_options", KeyEvent.VK_O, "menu_options_accstring", menuBar);
        makeCheckBoxMenuItem("menu_conconnect", "menu_conconnect_accstring", KeyEvent.VK_4, bContinuousConnections, optionsMenu, editorListener, MENU_CHECKBOX_CONTINUECONNECT);
        makeCheckBoxMenuItem("menu_middlemousemove", "menu_middlemousemove_accstring", KeyEvent.VK_5, bMiddleMouseMove, optionsMenu, editorListener, MENU_CHECKBOX_MIDDLEMOUSEMOVE);

        // create the grid snap menu

        gridMenu = makeMenu("menu_grid", KeyEvent.VK_G, "menu_grid_accstring", menuBar);
        makeCheckBoxMenuItem("menu_grid_show", "menu_grid_show_accstring", KeyEvent.VK_G, InputEvent.CTRL_DOWN_MASK, bShowGrid, gridMenu, editorListener, MENU_GRID_SHOW);
        gridSnapMenuItem = makeCheckBoxMenuItem("menu_grid_snap", "menu_grid_snap_accstring", KeyEvent.VK_S, bGridSnap, gridMenu, editorListener, MENU_GRID_SNAP);
        gridSnapSubDivisionMenuItem = makeCheckBoxMenuItem("menu_grid_snap_subdivide", "menu_grid_snap_subdivide_accstring", KeyEvent.VK_D, bGridSnapSubs, gridMenu, editorListener, MENU_GRID_SNAP_SUBS);
        gridMenu.addSeparator();
        makeMenuItem("menu_grid_set_size", "menu_grid_set_size_accstring", KeyEvent.VK_F, InputEvent.ALT_DOWN_MASK, gridMenu, editorListener, MENU_GRID_SET, true );

        // Create the Rotation Menu

        rotationMenu = makeMenu("menu_rotate", KeyEvent.VK_R, "menu_rotate_accstring", menuBar);
        makeMenuItem("menu_rotate_set_step", "menu_rotate_set_step_accstring", KeyEvent.VK_Y, InputEvent.SHIFT_DOWN_MASK, rotationMenu, editorListener, MENU_ROTATE_SET, true );
        rClockwiseMenuItem = makeMenuItem("menu_rotate_clockwise", "menu_rotate_clockwise_accstring", KeyEvent.VK_T, InputEvent.CTRL_DOWN_MASK, rotationMenu, editorListener, MENU_ROTATE_CLOCKWISE, false );
        r90ClockwiseMenuItem = makeMenuItem("menu_rotate_clockwise_ninty", "menu_rotate_clockwise_ninty_accstring", KeyEvent.VK_T, InputEvent.SHIFT_DOWN_MASK, rotationMenu, editorListener, MENU_ROTATE_CLOCKWISE_NINTY, false );
        rAntiClockwiseMenuItem = makeMenuItem("menu_rotate_anticlockwise", "menu_rotate_anticlockwise_accstring", KeyEvent.VK_R, InputEvent.CTRL_DOWN_MASK, rotationMenu, editorListener, MENU_ROTATE_ANTICLOCKWISE, false );
        r90AntiClockwiseMenuItem = makeMenuItem("menu_rotate_anticlockwise_ninty", "menu_rotate_anticlockwise_ninty_accstring", KeyEvent.VK_R, InputEvent.SHIFT_DOWN_MASK, rotationMenu, editorListener, MENU_ROTATE_ANTICLOCKWISE_NINTY, false );

        // Create the Help menu

        helpMenu = makeMenu("menu_help", KeyEvent.VK_H, "menu_help_accstring", menuBar);
        makeMenuItem("menu_help_about", "menu_help_about_accstring", KeyEvent.VK_H, InputEvent.ALT_DOWN_MASK, helpMenu,editorListener, MENU_ABOUT, true );

        if (DEBUG) {
            debugMenu = makeMenu("menu_debug", KeyEvent.VK_D, "menu_debug_accstring", menuBar);
            makeCheckBoxMenuItem("menu_debug_showID", "menu_debug_showID_accstring", KeyEvent.VK_6, InputEvent.ALT_DOWN_MASK, bDebugShowID, debugMenu, editorListener, MENU_DEBUG_SHOWID);

            makeCheckBoxMenuItem("menu_debug_showselectedlocation", "menu_debug_showselectedlocation_accstring", KeyEvent.VK_7, InputEvent.ALT_DOWN_MASK, bDebugShowSelectedLocation, debugMenu, editorListener, MENU_DEBUG_SELECTED_LOCATION);
            makeCheckBoxMenuItem("menu_debug_profile", "menu_debug_profile_accstring", bDebugProfile, debugMenu, editorListener, MENU_DEBUG_PROFILE);
            makeCheckBoxMenuItem("menu_debug_zoom", "menu_debug_zoom_accstring", bDebugZoomScale, debugMenu, editorListener, MENU_DEBUG_ZOOMSCALE);
            makeCheckBoxMenuItem("menu_debug_test", "menu_debug_test_accstring", bDebugTest, debugMenu, editorListener, MENU_DEBUG_TEST);
            debugMenu.addSeparator();
            makeCheckBoxMenuItem("menu_debug_fileio", "menu_debug_fileio_accstring", bDebugFileIO, debugMenu, editorListener, MENU_DEBUG_FILEIO);
            makeCheckBoxMenuItem("menu_debug_undo", "menu_debug_undo_accstring", bDebugUndoRedo, debugMenu, editorListener, MENU_DEBUG_UNDO);

        }


    }

    public static MapPanel createMapPanel(AutoDriveEditor editor, EditorListener listener) {

        mapPanel = new MapPanel(editor);
        //mapPanel.setLayout(new BorderLayout());
        // set border for the panel
        mapPanel.setBorder(BorderFactory.createTitledBorder(
                BorderFactory.createEtchedBorder(), localeString.getString("panels_map")));

        mapPanel.add( new GUIUtils.AlphaContainer(initCurvePanel(listener)));

        //JRotation rot = new JRotation();
        //mapPanel.add(rot);

        return mapPanel;

    }

    public static JPanel createButtonPanel(EditorListener editorListener) {

        JPanel buttonPanel = new JPanel(new FlowLayout(FlowLayout.CENTER));

        //
        // Create node panel
        //

        nodeBox = new JPanel();
        nodeBox.setBorder(BorderFactory.createTitledBorder(localeString.getString("panel_nodes")));
        buttonPanel.add(nodeBox);

        moveNode = makeImageToggleButton("movenode", "movenode_selected", BUTTON_MOVE_NODES,"nodes_move_tooltip","nodes_move_alt", nodeBox, editorListener);
        createRegularConnection = makeStateChangeImageToggleButton("connectregular", "connectregular_selected", BUTTON_CONNECT_NODES,"nodes_connect_tooltip","nodes_connect_alt", nodeBox, editorListener);
        createPrimaryNode = makeImageToggleButton("createprimary","createprimary_selected", BUTTON_CREATE_PRIMARY_NODE,"nodes_createprimary_tooltip","nodes_createprimary_alt", nodeBox, editorListener);
        createDualConnection = makeStateChangeImageToggleButton("connectdual","connectdual_selected", BUTTON_CREATE_DUAL_CONNECTION,"nodes_createdual_tooltip","nodes_createdual_alt", nodeBox, editorListener);
        changePriority = makeImageToggleButton("swappriority","swappriority_selected", BUTTON_CHANGE_NODE_PRIORITY,"nodes_priority_tooltip","nodes_priority_alt", nodeBox, editorListener);
        createSecondaryNode = makeImageToggleButton("createsecondary","createsecondary_selected", BUTTON_CREATE_SUBPRIO_NODE,"nodes_createsecondary_tooltip","nodes_createsecondary_alt", nodeBox, editorListener);
        createReverseConnection = makeStateChangeImageToggleButton("connectreverse","connectreverse_selected", BUTTON_CREATE_REVERSE_CONNECTION,"nodes_createreverse_tooltip","nodes_createreverse_alt", nodeBox, editorListener);

        nodeBox.add(Box.createRigidArea(new Dimension(8, 0)));
        quadBezier = makeImageToggleButton("quadcurve","quadcurve_selected", BUTTON_CREATE_QUADRATICBEZIER,"helper_quadbezier_tooltip","helper_quadbezier_alt", nodeBox, editorListener);
        cubicBezier = makeImageToggleButton("cubiccurve","cubiccurve_selected", BUTTON_CREATE_CUBICBEZIER,"helper_cubicbezier_tooltip","helper_cubicbezier_alt", nodeBox, editorListener);
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
        copyBox.setVisible(true);
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
        testBox.setVisible(false);
        buttonPanel.add(testBox);


        testBox.add(Box.createRigidArea(new Dimension(48, 0)));

        return buttonPanel;
   }

    public static JPanel initCurvePanel(EditorListener editorListener) {

        //
        // curve panel (hidden by default)
        //

        curvePanel = new JPanel();
        curvePanel.setLayout(new BoxLayout(curvePanel, X_AXIS)); //create container ( left to right layout)
        curvePanel.setBorder(BorderFactory.createCompoundBorder(BorderFactory.createRaisedBevelBorder(), BorderFactory.createLoweredBevelBorder()));
        curvePanel.setVisible(false);
        curvePanel.setOpaque(true);
        curvePanel.setBackground(new Color(25,25,25,128));

        // create a panel for path radiobuttons using GridLayout

        JPanel curveRadioPanel = new JPanel();
        curveRadioPanel.setLayout(new GridLayout(2,2));
        curveRadioPanel.setBorder(BorderFactory.createBevelBorder(BevelBorder.RAISED, new Color(64,64,64), new Color(32,32,32)));
        curveRadioPanel.setOpaque(false);

        ButtonGroup pathNodeGroup = new ButtonGroup();

        curvePathRegular = makeRadioButton("panel_slider_radio_regular", RADIOBUTTON_PATHTYPE_REGULAR,"panel_slider_radio_regular_tooltip", Color.ORANGE,true, false, curveRadioPanel, pathNodeGroup, null, editorListener);
        curvePathSubPrio = makeRadioButton("panel_slider_radio_subprio", RADIOBUTTON_PATHTYPE_SUBPRIO,"panel_slider_radio_subprio_tooltip", Color.ORANGE,false, false,curveRadioPanel, pathNodeGroup, null, editorListener);
        curvePathReverse = makeRadioButton("panel_slider_radio_reverse", RADIOBUTTON_PATHTYPE_REVERSE,"panel_slider_radio_reverse_tooltip", Color.ORANGE,false, false,curveRadioPanel, null, null, editorListener);
        curvePathDual = makeRadioButton("panel_slider_radio_dual", RADIOBUTTON_PATHTYPE_DUAL,"panel_slider_radio_dual_tooltip", Color.ORANGE,false, false,curveRadioPanel, null, null, editorListener);

        curvePanel.add(curveRadioPanel);

        // create panel for slider using vertical layout

        JPanel interpSliderPanel = new JPanel();
        interpSliderPanel.setLayout(new BoxLayout(interpSliderPanel, Y_AXIS));
        interpSliderPanel.setBorder(BorderFactory.createEmptyBorder());
        interpSliderPanel.setOpaque(false);


        // add padding before the label to centre it
        interpSliderPanel.add(Box.createRigidArea(new Dimension(72, 5)));
        JLabel textLabel = new JLabel(localeString.getString("panel_slider_label"));
        textLabel.setForeground(Color.ORANGE);
        interpSliderPanel.add(textLabel);

        numIterationsSlider = new JSlider(JSlider.HORIZONTAL,0, quadSliderMax, quadSliderDefault);
        numIterationsSlider.setVisible(true);
        numIterationsSlider.setOpaque(false);
        numIterationsSlider.setForeground(Color.ORANGE);
        numIterationsSlider.setMajorTickSpacing(10);
        numIterationsSlider.setPaintTicks(true);
        numIterationsSlider.setPaintLabels(true);
        numIterationsSlider.addChangeListener(editorListener);
        interpSliderPanel.add(numIterationsSlider);
        curvePanel.add(interpSliderPanel);

        curvePanel.add(Box.createRigidArea(new Dimension(8, 0)));
        commitCurve = makeImageToggleButton("confirm","confirm_select", BUTTON_COMMIT_CURVE,"panel_slider_confirm_curve","panel_slider_confirm_curve_alt", curvePanel, editorListener);
        curvePanel.add(Box.createRigidArea(new Dimension(8, 0)));
        cancelCurve = makeImageToggleButton("cancel","cancel_select", BUTTON_CANCEL_CURVE,"panel_slider_cancel_curve","panel_slider_cancel_curve_alt", curvePanel, editorListener);
        curvePanel.add(Box.createRigidArea(new Dimension(8, 0)));



        return curvePanel;
    }

    public void initLinerLinePanel(EditorListener editorListener) {

    }

    public static JPanel initTextPanel() {
        JPanel textPanel = new JPanel(new BorderLayout());
        textArea = new JTextArea("Welcome to the AutoDrive Editor... Load a config to start editing..\n ",3,0);
        JScrollPane scrollPane = new JScrollPane(textArea);
        textArea.setEditable(false);
        textPanel.add(scrollPane, BorderLayout.CENTER);
        return textPanel;
    }

    public static void showInTextArea(String text, boolean clearAll) {
        if (clearAll) {
            textArea.selectAll();
            textArea.replaceSelection("");
        }
        //LOG.info(text);
        textArea.append(text + "\n");
    }

    public static void updateGUIButtons(boolean enabled) {
        updateButtons();
        if (AutoDriveEditor.oldConfigFormat) {
            editorState = GUIBuilder.EDITORSTATE_NOOP;

            saveMenuEnabled(false);
            editMenuEnabled(false);
            enabled = false;
        }
        nodeBoxSetEnabled(enabled);
        markerBoxSetEnabled(enabled);
        alignBoxSetEnabled(enabled);
        copypasteBoxSetEnabled(enabled);
    }

    private static void nodeBoxSetEnabled(boolean enabled) {
        moveNode.setEnabled(enabled);
        createRegularConnection.setEnabled(enabled);
        createPrimaryNode.setEnabled(enabled);
        changePriority.setEnabled(enabled);
        createSecondaryNode.setEnabled(enabled);
        createReverseConnection.setEnabled(enabled);
        removeNode.setEnabled(enabled);
        createDualConnection.setEnabled(enabled);
        quadBezier.setEnabled(enabled);
        cubicBezier.setEnabled(enabled);
    }
    private static void markerBoxSetEnabled(boolean enabled) {
        createDestination.setEnabled(enabled);
        editDestination.setEnabled(enabled);
        removeDestination.setEnabled(enabled);
    }

    private static void alignBoxSetEnabled(boolean enabled) {
        alignHorizontal.setEnabled(enabled);
        alignVertical.setEnabled(enabled);
    }

    private static void copypasteBoxSetEnabled(boolean enabled) {
        select.setEnabled(enabled);
        cut.setEnabled(enabled);
        copy.setEnabled(enabled);
        paste.setEnabled(enabled);
    }

    public static void mapMenuEnabled(boolean enabled) {
        loadImageMenuItem.setEnabled(enabled);
        importDDSMenuItem.setEnabled(enabled);
    }

    public static void saveImageEnabled(boolean enabled) {
        saveImageMenuItem.setEnabled(enabled);
    }


    public static void saveMenuEnabled(boolean enabled) {
        saveConfigMenuItem.setEnabled(enabled);
        saveConfigAsMenuItem.setEnabled(enabled);
    }

    public static void editMenuEnabled(boolean enabled) {
        undoMenuItem.setEnabled(enabled);
        redoMenuItem.setEnabled(enabled);
        cutMenuItem.setEnabled(enabled);
        copyMenuItem.setEnabled(enabled);
        pasteMenuItem.setEnabled(enabled);
    }

    public static void rotationMenuEnabled(boolean enabled) {
        rClockwiseMenuItem.setEnabled(enabled);
        r90ClockwiseMenuItem.setEnabled(enabled);
        rAntiClockwiseMenuItem.setEnabled(enabled);
        r90AntiClockwiseMenuItem.setEnabled(enabled);
    }

    public static void updateButtons() {
        moveNode.setSelected(false);
        createRegularConnection.setSelected(false);
        createPrimaryNode.setSelected(false);
        changePriority.setSelected(false);
        createSecondaryNode.setSelected(false);
        createReverseConnection.setSelected(false);
        createDualConnection.setSelected(false);
        removeNode.setSelected(false);
        quadBezier.setSelected(false);
        cubicBezier.setSelected(false);

        createDestination.setSelected(false);
        editDestination.setSelected(false);
        removeDestination.setSelected(false);

        alignHorizontal.setSelected(false);
        alignVertical.setSelected(false);

        select.setSelected(false);
        cut.setSelected(false);
        copy.setSelected(false);
        paste.setSelected(false);

        switch (AutoDriveEditor.editorState) {
            case EDITORSTATE_MOVING:
                moveNode.setSelected(true);
                showInTextArea("Left click ( or area select ) and drag to move", true);
                break;
            case EDITORSTATE_CONNECTING:
                if (connectionType == CONNECTION_STANDARD) {
                    createRegularConnection.setSelected(true);
                } else if (connectionType == CONNECTION_SUBPRIO) {
                    changePriority.setSelected(true);
                } else if (connectionType == CONNECTION_REVERSE) {
                    createReverseConnection.setSelected(true);
                } else if (connectionType == CONNECTION_DUAL) {
                    createDualConnection.setSelected(true);
                }
                showInTextArea("click on start node then on end node to create a connection", true);
                break;
            case EDITORSTATE_CREATE_PRIMARY_NODE:
                createPrimaryNode.setSelected(true);
                showInTextArea("click on map to create a primary node", true);
                break;
            case EDITORSTATE_CHANGE_NODE_PRIORITY:
                changePriority.setSelected(true);
                showInTextArea("click on a node to change it's priority, or area select to swap multiple nodes", true);
                break;
            case EDITORSTATE_CREATE_SUBPRIO_NODE:
                createSecondaryNode.setSelected(true);
                showInTextArea("click on map to create a secondary node", true);
                break;
            case EDITORSTATE_DELETE_NODES:
                removeNode.setSelected(true);
                showInTextArea("click to delete a node, or area select to delete multiple nodes", true);
                break;
            case EDITORSTATE_CREATING_DESTINATION:
                createDestination.setSelected(true);
                showInTextArea("click on a node to create a map marker", true);
                break;
            case EDITORSTATE_EDITING_DESTINATION:
                editDestination.setSelected(true);
                showInTextArea("click on a marker to edit", true);
                break;
            case EDITORSTATE_DELETING_DESTINATION:
                removeDestination.setSelected(true);
                showInTextArea("click on a node to delete it's map marker", true);
                break;
            case EDITORSTATE_ALIGN_HORIZONTAL:
                alignHorizontal.setSelected(true);
                showInTextArea("Hold Right click and drag to area select nodes, then click node to align too", true);
                break;
            case EDITORSTATE_ALIGN_VERTICAL:
                alignVertical.setSelected(true);
                showInTextArea("Hold Right click and drag to area select nodes, then click node to align too", true);
                break;
            case EDITORSTATE_CNP_SELECT:
                select.setSelected(true);
                showInTextArea("Hold Right click and drag to area select", true);
                break;
            case EDITORSTATE_QUADRATICBEZIER:
                quadBezier.setSelected(true);
                showInTextArea("click start node, then end node to create curve", true);
                break;
            case EDITORSTATE_CUBICBEZIER:
                cubicBezier.setSelected(true);
                showInTextArea("click start node, then end node to create curve", true);
                break;
        }
    }

    //@SuppressWarnings("serial")
    static class JRotation extends JPanel implements MouseMotionListener {

        private double rotation = 0;
        private double angle = 0;
        private double lastAngle = 0;
        private double lastDegree = 0;
        private int lastrot = 0;
        public double getRotation() {
            return rotation;
        }

        public JRotation() {
            setPreferredSize(new Dimension(100, 100));
            addMouseMotionListener(this);
        }

        public static Point2D rotate(Graphics g, Point2D point, Point2D centre, double angle) {
            int width = getMapPanel().getWidth();
            int height = getMapPanel().getHeight();

            int sizeScaled = (int) (nodeSize * zoomLevel);
            int sizeScaledHalf = (int) (sizeScaled * 0.5);
            double currentNodeSize = nodeSize * zoomLevel * 0.5;
            Point2D result = new Point2D.Double();
            AffineTransform rotation = new AffineTransform();
            //angle = ADUtils.normalizeAngle(angle);
            double angleInRadians = Math.toRadians(angle);
            rotation.rotate(angle, centre.getX(), centre.getY());
            rotation.transform(new Point2D.Double(point.getX(), point.getY()), result);
            g.drawImage(nodeImage, (int) (result.getX() - (nodeImage.getWidth() / 4)), (int) (result.getY() - (nodeImage.getWidth() / 4)), nodeImage.getWidth() / 2, nodeImage.getHeight() / 2, null);
            //  g.drawImage(nodeImage,(int) (point.getX() - (getMapPanel().sizeScaledHalf / 2 )), (int) (point.getY() - (sizeScaledHalf / 2 )), sizeScaledHalf, sizeScaledHalf, null);
            return result;

        }

        @Override
        protected void paintComponent(Graphics g) {
            Graphics2D g2 = (Graphics2D)g.create();
            g2.setRenderingHint(RenderingHints.KEY_ANTIALIASING, RenderingHints.VALUE_ANTIALIAS_ON);
            //g2.setPaint(Color.white);
            //g2.fillRect(0, 0, getWidth(), getHeight());
            g2.drawImage(rotateRing, 0, 0, rotateRing.getWidth(), rotateRing.getHeight(), null);
            rotate(g2, new Point2D.Double(50, 7), new Point2D.Double(getPreferredSize().getWidth() / 2, getPreferredSize().getHeight() / 2), angle);
            //g2.rotate(-rotation);0

            //g2.setPaint(Color.black);
            //AffineTransform t = g2.getTransform();
            //g2.translate(getWidth()/2, getHeight()/2);
            //g2.rotate(Math.toDegrees(rotation));

            //g2.drawLine(0, 0, 0, -40);
            //g2.drawImage(nodeImage, -7, -50, nodeImage.getWidth() / 2, nodeImage.getHeight() / 2, null);
            //g2.setTransform(t);
        }

        @Override
        public void mouseDragged(MouseEvent e) {
            double step = 0;
            int x = e.getX();
            int y = e.getY();
            int midX = getWidth() / 2;
            int midY = getHeight() / 2;

            angle = Math.atan2(midY - y, midX - x) - PI / 2;
            if (angle < 0) // between -PI/2 and 0
                angle += 2*PI;

            step = Math.toDegrees(angle) - lastAngle;
            CopyPasteManager.rotateSelected(step);
            lastAngle = Math.toDegrees(angle);

            mapPanel.repaint();
        }

        @Override
        public void mouseMoved(MouseEvent e) {

        }

        public static float LerpDegrees(float start, float end, float amount)
        {
            float difference = Math.abs(end - start);
            if (difference > 180)
            {
                // We need to add on to one of the values.
                if (end > start)
                {
                    // We'll add it on to start...
                    start += 360;
                }
                else
                {
                    // Add it on to end.
                    end += 360;
                }
            }

            // Interpolate it.
            float value = (start + ((end - start) * amount));

            // Wrap it..
            float rangeZero = 360;

            if (value >= 0 && value <= 360)
                return value;

            return (value % rangeZero);
        }
    }
}
