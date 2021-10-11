package de.adEditor;

import javax.imageio.ImageIO;
import javax.swing.*;
import javax.swing.event.ChangeEvent;
import javax.swing.event.ChangeListener;
import javax.swing.filechooser.FileNameExtensionFilter;
import java.awt.event.ActionEvent;
import java.awt.event.ActionListener;
import java.awt.event.ItemEvent;
import java.awt.event.ItemListener;
import java.io.File;
import java.io.IOException;

import static de.adEditor.ADUtils.LOG;
import static de.adEditor.AutoDriveEditor.*;
import static de.adEditor.MapPanel.*;

public class EditorListener implements ActionListener, ItemListener, ChangeListener {

    public AutoDriveEditor editor;

    public EditorListener (AutoDriveEditor editor) {
        this.editor = editor;
    }

    @Override
    public void actionPerformed(ActionEvent e) {

        LOG.info("ActionCommand: {}", e.getActionCommand());

        JFileChooser fc = new JFileChooser();

        switch (e.getActionCommand()) {
            case MENU_LOAD_CONFIG:
                if (editor.isStale()) {
                    int response = JOptionPane.showConfirmDialog(null, localeString.getString("dialog_unsaved"), "AutoDrive", JOptionPane.YES_NO_OPTION, JOptionPane.QUESTION_MESSAGE);
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
                    editor.getMapPanel().stopCurveEdit();
                    File fileName = fc.getSelectedFile();
                    editor.loadConfigFile(fileName);
                    editor.getMapPanel().moveMapBy(0,0); // hacky way to get map image to refresh
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
            case MENU_LOAD_IMAGE:
                fc.setDialogTitle(localeString.getString("dialog_load_image_title"));
                fc.setFileSelectionMode(JFileChooser.FILES_ONLY);

                if (fc.showOpenDialog(editor) == JFileChooser.APPROVE_OPTION) {
                    try {
                        editor.getMapPanel().setImage(ImageIO.read(fc.getSelectedFile()));
                        editor.getMapPanel().moveMapBy(0,0); // hacky way to get map image to refresh

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
                this.editor.editorState = EDITORSTATE_MOVING;
                break;
            case BUTTON_REMOVE_NODES:
                this.editor.editorState = EDITORSTATE_DELETE_NODES;
                break;
            case BUTTON_DELETE_DESTINATIONS:
                this.editor.editorState = EDITORSTATE_DELETING_DESTINATION;
                break;
            case BUTTON_CONNECT_NODES:
                this.editor.editorState = EDITORSTATE_CONNECTING;
                connectionType=CONNECTION_STANDARD;
                break;
            case BUTTON_CREATE_PRIMARY_NODE:
                this.editor.editorState = EDITORSTATE_CREATE_PRIMARY_NODE;
                break;
            case BUTTON_CREATE_DESTINATIONS:
                this.editor.editorState = EDITORSTATE_CREATING_DESTINATION;
                break;
            case BUTTON_CHANGE_NODE_PRIORITY:
                this.editor.editorState = EDITORSTATE_CHANGE_NODE_PRIORITY;
                break;
            case BUTTON_CREATE_SUBPRIO_NODE:
                this.editor.editorState = EDITORSTATE_CREATE_SUBPRIO_NODE;
                break;
            case BUTTON_CREATE_REVERSE_CONNECTION:
                this.editor.editorState = EDITORSTATE_CONNECTING;
                connectionType=CONNECTION_REVERSE;
                break;
            case BUTTON_CREATE_DUAL_CONNECTION:
                this.editor.editorState = EDITORSTATE_CONNECTING;
                connectionType=CONNECTION_DUAL;
                break;
            case BUTTON_EDIT_DESTINATIONS_GROUPS:
                this.editor.editorState = EDITORSTATE_EDITING_DESTINATION;
                break;
            case BUTTON_ALIGN_HORIZONTAL:
                this.editor.editorState = EDITORSTATE_ALIGN_HORIZONTAL;
                break;
            case BUTTON_ALIGN_VERTICAL:
                this.editor.editorState = EDITORSTATE_ALIGN_VERTICAL;
                break;
            case BUTTON_CREATE_LINEARLINE:
                this.editor.editorState = EDITORSTATE_LINEARLINE;
                break;
            case BUTTON_CREATE_QUADRATICBEZIER:
                this.editor.editorState = EDITORSTATE_QUADRATICBEZIER;
                break;
            case BUTTON_CANCEL_CURVE:
                if (editor.editorState == EDITORSTATE_QUADRATICBEZIER && quadCurve.isCurveCreated()) {
                    editor.getMapPanel().stopCurveEdit();
                }
                break;
            case BUTTON_COMMIT_CURVE:
                if (editor.editorState == EDITORSTATE_QUADRATICBEZIER && quadCurve.isCurveCreated()) {
                    quadCurve.commitCurve(NODE_STANDARD);
                    // TODO : add quad bezier nodes to network
                    editor.getMapPanel().stopCurveEdit();
                    editor.setStale(true);
                }
                break;
            case BUTTON_COPYPASTE_SELECT:
                this.editor.editorState = EDITORSTATE_CNP_SELECT;
                JToggleButton tBtn = (JToggleButton)e.getSource();
                if (tBtn.isSelected()) {
                    System.out.println("button selected");
                } else {
                    System.out.println("button not selected");
                }
                break;
        }
        editor.updateButtons();
    }

    @Override
    public void itemStateChanged(ItemEvent e) {
        AbstractButton button = (AbstractButton) e.getItem();
        switch (button.getActionCommand()) {
            case MENU_CHECKBOX_CONTINUECONNECT:
                AutoDriveEditor.bContinuousConnections = button.isSelected();
                break;
            case RADIOBUTTON_PATHTYPE_REGULAR:
                quadCurve.setNodeType(NODE_STANDARD);
                break;
            case RADIOBUTTON_PATHTYPE_SUBPRIO:
                quadCurve.setNodeType(NODE_SUBPRIO);
                break;
            case RADIOBUTTON_PATHTYPE_REVERSE:
                //LOG.info("reverse = {}", button.isSelected());
                if (button.isSelected()) {
                    curvePathDual.setSelected(false);
                    quadCurve.setDualPath(false);
                }
                quadCurve.setReversePath(button.isSelected());
                break;
            case RADIOBUTTON_PATHTYPE_DUAL:
                //LOG.info("dual = {}", button.isSelected());
                if (button.isSelected()) {
                    curvePathReverse.setSelected(false);
                    quadCurve.setReversePath(false);
                }
                quadCurve.setDualPath(button.isSelected());
                break;
        }
    }

    private void showAbout() {
        JOptionPane.showMessageDialog(editor, "<html><center>Editor version : 0.2 Beta<br>Build info : Java 11 SDK - IntelliJ IDEA 2021.2.1 Community Edition<br><br><u>AutoDrive Development Team</u><br><br><b>Stephan (Founder & Modder)</b><br><br>TyKonKet (Modder)<br>Oliver (Modder)<br>Axel (Co-Modder)<br>Aletheist (Co-Modder)<br>Willi (Supporter & Tester)<br>Iwan1803 (Community Manager & Supporter)", "AutoDrive Editor", JOptionPane.PLAIN_MESSAGE);
    }


    @Override
    public void stateChanged(ChangeEvent e) {
        JSlider source = (JSlider)e.getSource();
        if (source.getValueIsAdjusting()) {
            int value = source.getValue();
            if (MapPanel.quadCurve != null) {
                if (value < 2) value = 2;
                MapPanel.quadCurve.setNumInterpolationPoints(value);
                editor.getMapPanel().repaint();
            }
        }
    }
}


