package de.adEditor;

import javax.swing.*;
import javax.swing.border.BevelBorder;
import java.awt.*;
import java.awt.event.InputEvent;
import java.awt.event.KeyEvent;

import static de.adEditor.ADUtils.LOG;
import static de.adEditor.GUIUtils.*;
import static de.adEditor.AutoDriveEditor.*;
import static de.adEditor.MapPanel.*;

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

    public static final String MENU_LOAD_CONFIG = "Load Config";
    public static final String MENU_SAVE_CONFIG = "Save Config";
    public static final String MENU_SAVE_SAVEAS = "Save As";
    public static final String MENU_LOAD_IMAGE = "Load Map";
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

    public static MapPanel mapPanel;
    public static JMenuBar menuBar;
    public static JMenuItem loadImageButton;
    public static JMenuItem saveConfigMenuItem;
    public static JMenuItem saveConfigAsMenuItem;
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
        JMenu fileMenu, editMenu, mapMenu, optionsMenu, helpMenu, subMenu;

        menuBar = new JMenuBar();

        // Create the file Menu

        fileMenu = makeMenu("menu_file", KeyEvent.VK_F, "menu_file_accstring", menuBar);
        makeMenuItem("menu_file_loadconfig",  "menu_file_loadconfig_accstring", KeyEvent.VK_L, InputEvent.ALT_DOWN_MASK, fileMenu, editorListener, MENU_LOAD_CONFIG, true );
        saveConfigMenuItem = makeMenuItem("menu_file_saveconfig",  "menu_file_saveconfig_accstring", KeyEvent.VK_S, InputEvent.ALT_DOWN_MASK, fileMenu, editorListener, MENU_SAVE_CONFIG, false );
        saveConfigAsMenuItem = makeMenuItem("menu_file_saveasconfig", "menu_file_saveasconfig_accstring",  KeyEvent.VK_A, InputEvent.ALT_DOWN_MASK,fileMenu, editorListener,MENU_SAVE_SAVEAS, false );

        // Create the edit menu

        editMenu = makeMenu("menu_edit", KeyEvent.VK_E, "menu_edit_accstring", menuBar);

        // Disabled due not implemented yet

        makeMenuItem("menu_edit_undo",  "menu_edit_undo_accstring", KeyEvent.VK_Z, InputEvent.CTRL_DOWN_MASK, editMenu, editorListener, MENU_EDIT_UNDO, true );
        makeMenuItem("menu_edit_redo",  "menu_edit_redo_accstring", KeyEvent.VK_Z, InputEvent.SHIFT_DOWN_MASK, editMenu, editorListener, MENU_EDIT_REDO, true );
        makeMenuItem("menu_edit_cut",  "menu_edit_cut_accstring", KeyEvent.VK_X, InputEvent.ALT_DOWN_MASK, editMenu, editorListener, MENU_EDIT_CUT, false );
        makeMenuItem("menu_edit_copy",  "menu_edit_copy_accstring", KeyEvent.VK_C, InputEvent.ALT_DOWN_MASK, editMenu, editorListener, MENU_EDIT_COPY, false );
        makeMenuItem("menu_edit_paste",  "menu_edit_paste_accstring", KeyEvent.VK_V, InputEvent.ALT_DOWN_MASK, editMenu, editorListener, MENU_EDIT_PASTE, false );


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
        makeCheckBoxMenuItem("menu_conconnect", "menu_conconnect_accstring", KeyEvent.VK_5, bContinuousConnections, optionsMenu, editorListener, MENU_CHECKBOX_CONTINUECONNECT);
        makeCheckBoxMenuItem("menu_middlemousemove", "menu_middlemousemove_accstring", KeyEvent.VK_6, bMiddleMouseMove, optionsMenu, editorListener, MENU_CHECKBOX_MIDDLEMOUSEMOVE);

        // Create the Help menu

        helpMenu = makeMenu("menu_help", KeyEvent.VK_H, "menu_help_accstring", menuBar);
        makeMenuItem("menu_help_about", "menu_help_about_accstring", KeyEvent.VK_H, InputEvent.ALT_DOWN_MASK, helpMenu,editorListener, MENU_ABOUT, true );


    }

    public static MapPanel createMapPanel(AutoDriveEditor editor, EditorListener listener) {

        mapPanel = new MapPanel(editor);
        // set border for the panel
        mapPanel.setBorder(BorderFactory.createTitledBorder(
                BorderFactory.createEtchedBorder(), localeString.getString("panels_map")));

        mapPanel.add( new GUIUtils.AlphaContainer(initCurvePanel(listener)));

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
        curvePanel.setLayout(new BoxLayout(curvePanel, BoxLayout.X_AXIS)); //create container ( left to right layout)
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
        interpSliderPanel.setLayout(new BoxLayout(interpSliderPanel, BoxLayout.Y_AXIS));
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
        LOG.info(text);
        textArea.append(text + "\n");
    }

    public static void updateGUIButtons(boolean enabled) {
        updateButtons();
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
        // temporary, buttons do nothing at the moment
        enabled = false;
        //
        select.setEnabled(enabled);
        cut.setEnabled(enabled);
        copy.setEnabled(enabled);
        paste.setEnabled(enabled);
    }

    private static void curveCommitCancelEnabled(boolean enabled) {
        commitCurve.setEnabled(enabled);
        cancelCurve.setEnabled(enabled);
        if (enabled) {
            commitCurve.setToolTipText(localeString.getString("panel_slider_confirm"));
            cancelCurve.setToolTipText(localeString.getString("panel_slider_cancel"));
        } else {
            commitCurve.setToolTipText(localeString.getString("panel_slider_confirm_disabled"));
            cancelCurve.setToolTipText(localeString.getString("panel_slider_cancel_disabled"));
        }
    }

    public static void mapMenuEnabled(boolean enabled) {
        loadImageButton.setEnabled(enabled);
    }

    public static void saveMenuEnabled(boolean enabled) {
        saveConfigMenuItem.setEnabled(enabled);
        saveConfigAsMenuItem.setEnabled(enabled);
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
        }
    }
}
