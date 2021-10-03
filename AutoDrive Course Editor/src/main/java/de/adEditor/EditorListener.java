package de.adEditor;

import javax.imageio.ImageIO;
import javax.swing.*;
import javax.swing.event.ChangeEvent;
import javax.swing.event.ChangeListener;
import javax.swing.filechooser.FileNameExtensionFilter;
import java.awt.*;
import java.awt.event.ActionEvent;
import java.awt.event.ActionListener;
import java.awt.event.ItemEvent;
import java.awt.event.ItemListener;
import java.io.File;
import java.io.IOException;

import static de.adEditor.ADUtils.LOG;
import static de.adEditor.AutoDriveEditor.localeString;
import static de.adEditor.MapPanel.quadCurve;

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
            case AutoDriveEditor.MOVE_NODES:
                this.editor.editorState = AutoDriveEditor.EDITORSTATE_MOVING;
                break;
            case AutoDriveEditor.REMOVE_NODES:
                this.editor.editorState = AutoDriveEditor.EDITORSTATE_DELETING;
                break;
            case AutoDriveEditor.REMOVE_DESTINATIONS:
                this.editor.editorState = AutoDriveEditor.EDITORSTATE_DELETING_DESTINATION;
                break;
            case AutoDriveEditor.CONNECT_NODES:
                this.editor.editorState = AutoDriveEditor.EDITORSTATE_CONNECTING;
                break;
            case AutoDriveEditor.CREATE_PRIMARY_NODES:
                this.editor.editorState = AutoDriveEditor.EDITORSTATE_CREATING_PRIMARY;
                break;
            case AutoDriveEditor.CREATE_DESTINATIONS:
                this.editor.editorState = AutoDriveEditor.EDITORSTATE_CREATING_DESTINATION;
                break;
            case AutoDriveEditor.CHANGE_NODE_PRIORITY:
                this.editor.editorState = AutoDriveEditor.EDITORSTATE_CHANGE_PRIORITY;
                break;
            case AutoDriveEditor.CREATE_SECONDARY_NODES:
                this.editor.editorState = AutoDriveEditor.EDITORSTATE_CREATING_SECONDARY;
                break;
            case AutoDriveEditor.CREATE_REVERSE_NODES:
                this.editor.editorState = AutoDriveEditor.EDITORSTATE_CREATING_REVERSE_CONNECTION;
                break;
            case AutoDriveEditor.EDIT_DESTINATIONS_GROUPS:
                this.editor.editorState = AutoDriveEditor.EDITORSTATE_EDITING_DESTINATION;
                break;
            case "1x":
                editor.updateMapZoomFactor(1);
                break;
            case "4x":
                editor.updateMapZoomFactor(2);
                break;
            case "16x":
                editor.updateMapZoomFactor(4);
                break;
            case "Load Config":
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
                    File fileName = fc.getSelectedFile();
                    editor.loadConfigFile(fileName);
                    editor.pack();
                    editor.repaint();
                    editor.getMapPanel().repaint();
                }
                break;
            case "Save Config":
                editor.saveMap(null);
                break;
            case "Load Map Image":
                fc.setDialogTitle(localeString.getString("dialog_load_image_title"));
                fc.setFileSelectionMode(JFileChooser.FILES_ONLY);

                if (fc.showOpenDialog(editor) == JFileChooser.APPROVE_OPTION) {
                    try {
                        editor.getMapPanel().setImage(ImageIO.read(fc.getSelectedFile()));
                        editor.getMapPanel().setPreferredSize(new Dimension(1024, 768));
                        editor.getMapPanel().setMinimumSize(new Dimension(1024, 768));
                        editor.getMapPanel().revalidate();
                        editor.getMapPanel().moveMapBy(0,0); // hacky way to get map image to refresh
                        //editor.pack();

                    } catch (IOException e1) {
                        LOG.error(e1.getMessage(), e1);
                    }
                }
                break;
            case "Save As":
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
            case AutoDriveEditor.ALIGN_HORIZONTAL:
                this.editor.editorState = AutoDriveEditor.EDITORSTATE_ALIGN_HORIZONTAL;
                break;
            case AutoDriveEditor.ALIGN_VERTICAL:
                this.editor.editorState = AutoDriveEditor.EDITORSTATE_ALIGN_VERTICAL;
                break;
            case "About":
                showAbout();
                break;
            case AutoDriveEditor.CREATE_LINEARLINE:
                this.editor.editorState = AutoDriveEditor.EDITORSTATE_LINEARLINE;
                break;
            case AutoDriveEditor.CREATE_QUADRATICBEZIER:
                this.editor.editorState = AutoDriveEditor.EDITORSTATE_QUADRATICBEZIER;
                break;
            case AutoDriveEditor.CANCEL_CURVE:
                if (editor.editorState == AutoDriveEditor.EDITORSTATE_QUADRATICBEZIER && quadCurve.isCurveCreated()) {
                    quadCurve.clear();
                    editor.getMapPanel().stopCurveEdit();
                }
                break;
            case AutoDriveEditor.COMMIT_CURVE:
                if (editor.editorState == AutoDriveEditor.EDITORSTATE_QUADRATICBEZIER && quadCurve.isCurveCreated()) {
                    // TODO : add quad bezier nodes to network
                    quadCurve.clear();
                    editor.getMapPanel().stopCurveEdit();
                }
        }

        editor.updateButtons();
    }

    @Override
    public void itemStateChanged(ItemEvent e) {
        AbstractButton button = (AbstractButton) e.getItem();
        LOG.info("ItemCommand: {}", button.getText());
        switch (button.getText()) {
            case "Continuous Connections":
                AutoDriveEditor.bContinuousConnections = button.isSelected();
                break;
        }
    }

    @Override
    public void stateChanged(ChangeEvent e) {

    }

    private void showAbout() {
        JOptionPane.showMessageDialog(editor, "<html><center>Editor version : 0.2 Beta<br>Build info : Java 11 SDK - IntelliJ IDEA 2021.2.1 Community Edition<br><br><u>AutoDrive Development Team</u><br><br><b>Stephan (Founder & Modder)</b><br><br>TyKonKet (Modder)<br>Oliver (Modder)<br>Axel (Co-Modder)<br>Aletheist (Co-Modder)<br>Willi (Supporter & Tester)<br>Iwan1803 (Community Manager & Supporter)", "AutoDrive Editor", JOptionPane.PLAIN_MESSAGE);
    }


}


