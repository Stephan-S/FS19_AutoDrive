package de.adEditor;

import javax.imageio.ImageIO;
import javax.swing.*;
import javax.swing.event.ChangeEvent;
import javax.swing.event.ChangeListener;
import javax.swing.filechooser.FileNameExtensionFilter;
import java.awt.event.*;
import java.awt.event.MouseListener;
import java.io.File;
import java.io.IOException;

import static de.adEditor.ADUtils.LOG;
import static de.adEditor.AutoDriveEditor.*;
import static de.adEditor.MapPanel.*;
import static de.adEditor.GUIBuilder.*;


public class EditorListener implements ActionListener, ItemListener, ChangeListener, MouseListener {

    public AutoDriveEditor editor;

    public EditorListener (AutoDriveEditor editor) {
        this.editor = editor;
    }

    @Override
    public void actionPerformed(ActionEvent e) {

        LOG.info("ActionCommand: {}", e.getActionCommand());

        JFileChooser fc = new JFileChooser();
        GUIBuilder.getMapPanel().isMultiSelectAllowed = false;

        switch (e.getActionCommand()) {
            case MENU_LOAD_CONFIG:
                if (editor.isStale()) {
                    int response = JOptionPane.showConfirmDialog(null, localeString.getString("dialog_exit_unsaved"), "AutoDrive", JOptionPane.YES_NO_OPTION, JOptionPane.QUESTION_MESSAGE);
                    if (response == JOptionPane.YES_OPTION) {
                        editor.saveMap(null);
                    }
                }
                fc.setDialogTitle(localeString.getString("dialog_load_config_title"));
                fc.setFileSelectionMode(JFileChooser.FILES_ONLY);
                fc.setAcceptAllFileFilterUsed(false);
                FileNameExtensionFilter filter = new FileNameExtensionFilter("AutoDrive config", "xml");
                fc.addChoosableFileFilter(filter);

                if (fc.showOpenDialog(editor) == JFileChooser.APPROVE_OPTION) {
                    GUIBuilder.getMapPanel().stopCurveEdit();
                    File fileName = fc.getSelectedFile();
                    editor.loadConfigFile(fileName);
                    GUIBuilder.getMapPanel().moveMapBy(0,0); // hacky way to get map image to refresh
                }
                break;
            case MENU_SAVE_CONFIG:
                editor.saveMap(null);
                break;
            case MENU_SAVE_SAVEAS:
                if (editor.xmlConfigFile == null) break;
                fc.setDialogTitle(localeString.getString("dialog_save_destination"));
                fc.setFileSelectionMode(JFileChooser.FILES_ONLY);
                fc.setAcceptAllFileFilterUsed(false);
                FileNameExtensionFilter savefilter = new FileNameExtensionFilter("AutoDrive config", "xml");
                fc.setSelectedFile(editor.xmlConfigFile);
                fc.addChoosableFileFilter(savefilter);

                if (fc.showSaveDialog(editor) == JFileChooser.APPROVE_OPTION) {
                    LOG.info("{} {}", localeString.getString("console_config_saveas"), ADUtils.getSelectedFileWithExtension(fc));
                    editor.saveMap(ADUtils.getSelectedFileWithExtension(fc).toString());

                }
                break;
            case MENU_EDIT_CUT:
                break;
            case MENU_EDIT_COPY:
                break;
            case MENU_EDIT_PASTE:
                break;
            case MENU_LOAD_IMAGE:
                fc.setDialogTitle(localeString.getString("dialog_load_image_title"));
                fc.setFileSelectionMode(JFileChooser.FILES_ONLY);

                if (fc.showOpenDialog(editor) == JFileChooser.APPROVE_OPTION) {
                    try {
                        GUIBuilder.getMapPanel().setImage(ImageIO.read(fc.getSelectedFile()));
                        GUIBuilder.getMapPanel().moveMapBy(0,0); // hacky way to get map image to refresh

                    } catch (IOException e1) {
                        LOG.error(e1.getMessage(), e1);
                    }
                }
                break;
            case MENU_ZOOM_1x:
                editor.updateMapZoomFactor(1);
                break;
            case MENU_ZOOM_4x:
                editor.updateMapZoomFactor(2);
                break;
            case MENU_ZOOM_16x:
                editor.updateMapZoomFactor(4);
                break;
            case MENU_ABOUT:
                showAbout();
                break;
            case BUTTON_MOVE_NODES:
                editorState = EDITORSTATE_MOVING;
                GUIBuilder.getMapPanel().isMultiSelectAllowed = true;
                break;
            case BUTTON_CONNECT_NODES:
                editorState = EDITORSTATE_CONNECTING;
                connectionType=CONNECTION_STANDARD;
                break;
            case BUTTON_CREATE_PRIMARY_NODE:
                editorState = EDITORSTATE_CREATE_PRIMARY_NODE;
                break;
            case BUTTON_CREATE_DUAL_CONNECTION:
                editorState = EDITORSTATE_CONNECTING;
                connectionType=CONNECTION_DUAL;
                break;
            case BUTTON_CHANGE_NODE_PRIORITY:
                editorState = EDITORSTATE_CHANGE_NODE_PRIORITY;
                GUIBuilder.getMapPanel().isMultiSelectAllowed = true;
                break;
            case BUTTON_CREATE_SUBPRIO_NODE:
                editorState = EDITORSTATE_CREATE_SUBPRIO_NODE;
                break;
            case BUTTON_CREATE_REVERSE_CONNECTION:
                editorState = EDITORSTATE_CONNECTING;
                connectionType=CONNECTION_REVERSE;
                break;
            case BUTTON_REMOVE_NODES:
                editorState = EDITORSTATE_DELETE_NODES;
                GUIBuilder.getMapPanel().isMultiSelectAllowed = true;
                break;
            case BUTTON_CREATE_DESTINATIONS:
                editorState = EDITORSTATE_CREATING_DESTINATION;
                break;
            case BUTTON_EDIT_DESTINATIONS_GROUPS:
                editorState = EDITORSTATE_EDITING_DESTINATION;
                break;
            case BUTTON_DELETE_DESTINATIONS:
                editorState = EDITORSTATE_DELETING_DESTINATION;
                GUIBuilder.getMapPanel().isMultiSelectAllowed = true;
                break;
            case BUTTON_ALIGN_HORIZONTAL:
                editorState = EDITORSTATE_ALIGN_HORIZONTAL;
                GUIBuilder.getMapPanel().isMultiSelectAllowed = true;
                break;
            case BUTTON_ALIGN_VERTICAL:
                editorState = EDITORSTATE_ALIGN_VERTICAL;
                GUIBuilder.getMapPanel().isMultiSelectAllowed = true;
                break;
            case BUTTON_CREATE_QUADRATICBEZIER:
                editorState = EDITORSTATE_QUADRATICBEZIER;
                break;
            case BUTTON_COMMIT_CURVE:
                quadCurve.commitCurve();
                GUIBuilder.getMapPanel().stopCurveEdit();
                GUIBuilder.getMapPanel().repaint();
                editor.setStale(true);
                break;
            case BUTTON_CANCEL_CURVE:
                GUIBuilder.getMapPanel().stopCurveEdit();
                GUIBuilder.getMapPanel().repaint();
                break;
            case BUTTON_COPYPASTE_SELECT:
                editorState = EDITORSTATE_CNP_SELECT;
                GUIBuilder.getMapPanel().isMultiSelectAllowed = true;
                JToggleButton tBtn = (JToggleButton)e.getSource();
                if (tBtn.isSelected()) {
                    System.out.println("button selected");

                } else {
                    System.out.println("button not selected");
                }
                break;
        }
        GUIBuilder.updateButtons();
    }

    @Override
    public void itemStateChanged(ItemEvent e) {
        AbstractButton button = (AbstractButton) e.getItem();
        switch (button.getActionCommand()) {
            case MENU_CHECKBOX_CONTINUECONNECT:
                AutoDriveEditor.bContinuousConnections = button.isSelected();
                break;
            case MENU_CHECKBOX_MIDDLEMOUSEMOVE:
                AutoDriveEditor.bMiddleMouseMove = button.isSelected();
                break;
            case RADIOBUTTON_PATHTYPE_REGULAR:
                quadCurve.setNodeType(NODE_STANDARD);
                mapPanel.repaint();
                break;
            case RADIOBUTTON_PATHTYPE_SUBPRIO:
                quadCurve.setNodeType(NODE_SUBPRIO);
                mapPanel.repaint();
                break;
            case RADIOBUTTON_PATHTYPE_REVERSE:
                if (button.isSelected()) {
                    GUIBuilder.curvePathDual.setSelected(false);
                    quadCurve.setDualPath(false);
                }
                quadCurve.setReversePath(button.isSelected());
                mapPanel.repaint();
                break;
            case RADIOBUTTON_PATHTYPE_DUAL:
                if (button.isSelected()) {
                    GUIBuilder.curvePathReverse.setSelected(false);
                    quadCurve.setReversePath(false);
                }
                quadCurve.setDualPath(button.isSelected());
                mapPanel.repaint();
                break;
        }
    }

    private void showAbout() {
        JOptionPane.showMessageDialog(editor, "<html><center>Editor version : " + AUTODRIVE_INTERNAL_VERSION + "<br>Build info : Java 11 SDK - IntelliJ IDEA 2021.2.3 Community Edition<br><br><u>AutoDrive Development Team</u><br><br><b>Stephan (Founder & Modder)</b><br><br>TyKonKet (Modder)<br>Oliver (Modder)<br>Axel (Co-Modder)<br>Aletheist (Co-Modder)<br>Willi (Supporter & Tester)<br>Iwan1803 (Community Manager & Supporter)", "AutoDrive Editor", JOptionPane.PLAIN_MESSAGE);
    }


    @Override
    public void stateChanged(ChangeEvent e) {
        JSlider source = (JSlider)e.getSource();
        if (source.getValueIsAdjusting()) {
            int value = source.getValue();
            if (MapPanel.quadCurve != null) {
                if (value < 2) value = 2;
                MapPanel.quadCurve.setNumInterpolationPoints(value);
                GUIBuilder.getMapPanel().repaint();
            }
        }
    }

    // These mouse events are only triggered by StateChangeJToggleButtons
    // with a right click on button.
    // all other mouse functions are still handled by the MouseListener

    @Override
    public void mouseClicked(MouseEvent e) {
        if (SwingUtilities.isRightMouseButton(e) && e.getClickCount() == 1) {
            JToggleButton toggleStateButton = (JToggleButton) e.getSource();
            if (toggleStateButton.isEnabled()) {
                //toggleStateButton.setEnabled(false);
                if (toggleStateButton == GUIBuilder.createRegularConnection) {
                    createRegularConnectionState = 1 - createRegularConnectionState;
                    if (createRegularConnectionState == NODE_STANDARD) { // == 0
                        createRegularConnection.setIcon(regularConnectionIcon);
                        createRegularConnection.setSelectedIcon(regularConnectionSelectedIcon);
                    } else {
                        createRegularConnection.setIcon(regularConnectionSubPrioIcon);
                        createRegularConnection.setSelectedIcon(regularConnectionSubPrioSelectedIcon);
                    }
                } else if (toggleStateButton == createDualConnection) {
                    createDualConnectionState = 1 - createDualConnectionState;
                    if (createDualConnectionState == NODE_STANDARD) { // == 0
                        createDualConnection.setIcon(dualConnectionIcon);
                        createDualConnection.setSelectedIcon(dualConnectionSelectedIcon);
                    } else {
                        createDualConnection.setIcon(dualConnectionSubPrioIcon);
                        createDualConnection.setSelectedIcon(dualConnectionSubPrioSelectedIcon);
                    }
                } else if (toggleStateButton == createReverseConnection) {
                    createReverseConnectionState = 1 - createReverseConnectionState;
                    if (createReverseConnectionState == NODE_STANDARD) { // == 0
                        createReverseConnection.setIcon(reverseConnectionIcon);
                        createReverseConnection.setSelectedIcon(reverseConnectionSelectedIcon);
                    } else {
                        createReverseConnection.setIcon(reverseConnectionSubPrioIcon);
                        createReverseConnection.setSelectedIcon(reverseConnectionSubPrioSelectedIcon);
                    }
                }
            }
        }
    }

    @Override
    public void mousePressed(MouseEvent e) {}

    @Override
    public void mouseReleased(MouseEvent e) {}

    @Override
    public void mouseEntered(MouseEvent e) {}

    @Override
    public void mouseExited(MouseEvent e) {}
}


