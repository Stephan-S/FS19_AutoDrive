package de.adEditor;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.xml.sax.SAXException;

import javax.imageio.ImageIO;
import javax.swing.*;
import javax.xml.parsers.ParserConfigurationException;
import java.awt.*;
import java.awt.event.ActionEvent;
import java.awt.event.ActionListener;
import java.io.IOException;

public class EditorListener implements ActionListener {

    private static Logger LOG = LoggerFactory.getLogger(EditorListener.class);
    public AutoDriveEditor editor;

    final JFileChooser fc = new JFileChooser();

    public EditorListener (AutoDriveEditor editor) {
        this.editor = editor;
    }

    @Override
    public void actionPerformed(ActionEvent e) {
        LOG.info("ActionCommand: {}", e.getActionCommand());
        if (e.getActionCommand().equals("Save")) {
            int returnVal = fc.showSaveDialog(editor);

            if (returnVal == JFileChooser.APPROVE_OPTION) {
                editor.savedFile = fc.getSelectedFile();
                editor.saveMap(editor.loadedFile.getAbsolutePath(), editor.savedFile.getAbsolutePath());
            }
        }
        if (e.getActionCommand().equals(AutoDriveEditor.MOVE_NODES)) {
            this.editor.editorState = AutoDriveEditor.EDITORSTATE_MOVING;
        }
        if (e.getActionCommand().equals(AutoDriveEditor.REMOVE_NODES)) {
            this.editor.editorState = AutoDriveEditor.EDITORSTATE_DELETING;
        }
        if (e.getActionCommand().equals(AutoDriveEditor.REMOVE_DESTINATIONS)) {
            this.editor.editorState = AutoDriveEditor.EDITORSTATE_DELETING_DESTINATION;
        }
        if (e.getActionCommand().equals(AutoDriveEditor.CONNECT_NODES)) {
            this.editor.editorState = AutoDriveEditor.EDITORSTATE_CONNECTING;
        }
        if (e.getActionCommand().equals(AutoDriveEditor.CREATE_NODES)) {
            this.editor.editorState = AutoDriveEditor.EDITORSTATE_CREATING;
        }
        if (e.getActionCommand().equals(AutoDriveEditor.CREATE_DESTINATIONS)) {
            this.editor.editorState = AutoDriveEditor.EDITORSTATE_CREATING_DESTINATION;
        }
        editor.updateButtons();
        if (e.getActionCommand().equals("Load")) {
            int returnVal = fc.showOpenDialog(editor);

            if (returnVal == JFileChooser.APPROVE_OPTION) {
                editor.loadedFile = fc.getSelectedFile();
                try {
                    editor.getMapPanel().setRoadMap(editor.loadFile(editor.loadedFile.getAbsolutePath()));
                    editor.pack();
                    editor.repaint();
                    editor.getMapPanel().repaint();
                } catch (ParserConfigurationException | SAXException | IOException e1) {
                    LOG.error(e1.getMessage(), e1);
                }
            }
        }
        if (e.getActionCommand().equals("Load Image")) {
            int returnVal = fc.showOpenDialog(editor);

            if (returnVal == JFileChooser.APPROVE_OPTION) {
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
        }
        if (e.getActionCommand().equals("OneTimesMap")) {
            editor.updateMapZoomFactor(1);
        }
        if (e.getActionCommand().equals("FourTimesMap")) {
            editor.updateMapZoomFactor(2);
        }
        if (e.getActionCommand().equals("SixteenTimesMap")) {
            editor.updateMapZoomFactor(4);
        }
    }
}
