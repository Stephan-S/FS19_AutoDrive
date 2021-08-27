package de.adEditor;

import org.apache.logging.log4j.core.util.FileUtils;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import javax.imageio.ImageIO;
import javax.swing.*;
import javax.swing.filechooser.FileNameExtensionFilter;
import java.awt.*;
import java.awt.event.ActionEvent;
import java.awt.event.ActionListener;
import java.io.File;
import java.io.IOException;
import java.nio.file.Files;

public class EditorListener implements ActionListener {

    private static Logger LOG = LoggerFactory.getLogger(EditorListener.class);
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
                this.editor.editorState = AutoDriveEditor.EDITORSTATE_EDITING_DESTINATION_GROUPS;
                break;
            case "OneTimesMap":
                editor.updateMapZoomFactor(1);
                break;
            case "FourTimesMap":
                editor.updateMapZoomFactor(2);
                break;
            case "SixteenTimesMap":
                editor.updateMapZoomFactor(4);
                break;
            case "Load Config":
                fc.setDialogTitle("Select AutoDrive Config");
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
            case "Load Image":
                if (fc.showOpenDialog(editor) == JFileChooser.APPROVE_OPTION) {
                    try {
                        editor.getMapPanel().setImage(ImageIO.read(fc.getSelectedFile()));
                        editor.getMapPanel().setPreferredSize(new Dimension(1024, 768));
                        editor.getMapPanel().setMinimumSize(new Dimension(1024, 768));
                        editor.getMapPanel().revalidate();
                        editor.pack();
                    } catch (IOException e1) {
                        LOG.error(e1.getMessage(), e1);
                    }
                }
                break;
            case "Save As":
                if (editor.xmlConfigFile == null) break;
                LOG.info("current filename is {}",editor.xmlConfigFile);
                fc.setDialogTitle("Select Save Destination");
                fc.setFileSelectionMode(JFileChooser.FILES_ONLY);
                fc.setAcceptAllFileFilterUsed(false);
                FileNameExtensionFilter savefilter = new FileNameExtensionFilter("AutoDrive config", "xml");
                fc.setSelectedFile(editor.xmlConfigFile);
                fc.addChoosableFileFilter(savefilter);

                if (fc.showSaveDialog(editor) == JFileChooser.APPROVE_OPTION) {
                    LOG.info("new save filename is {}", editor.getSelectedFileWithExtension(fc));
                    //LOG.info("xmlConfigFile = ", editor.xmlConfigFile);
                    editor.saveMap(editor.getSelectedFileWithExtension(fc).toString());

                }
                break;
            case "About":
                showAbout();
                break;
        }

        editor.updateButtons();
    }

    private void showAbout() {
        JOptionPane.showMessageDialog(editor, "Current editor version - 0.2 Beta\n\nCredits...... Coming Soon!", "AutoDrive Editor", JOptionPane.INFORMATION_MESSAGE);
    }
}


