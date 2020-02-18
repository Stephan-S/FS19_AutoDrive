package de.adEditor;

import org.xml.sax.SAXException;

import javax.imageio.ImageIO;
import javax.swing.*;
import javax.xml.parsers.ParserConfigurationException;
import java.awt.event.ActionEvent;
import java.awt.event.ActionListener;
import java.io.IOException;

public class EditorListener implements ActionListener {

    public AutoDriveEditor editor;

    final JFileChooser fc = new JFileChooser();

    public EditorListener (AutoDriveEditor editor) {
        this.editor = editor;
    }

    @Override
    public void actionPerformed(ActionEvent e) {
        System.out.println("ActionCommand: " + e.getActionCommand());
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
                    editor.mapPanel.roadMap = editor.loadFile(editor.loadedFile.getAbsolutePath());
                    editor.pack();
                    editor.repaint();
                    editor.mapPanel.repaint();
                } catch (ParserConfigurationException | SAXException | IOException e1) {
                    e1.printStackTrace();
                }
            }
        }
        if (e.getActionCommand().equals("Load Image")) {
            int returnVal = fc.showOpenDialog(editor);

            if (returnVal == JFileChooser.APPROVE_OPTION) {
                try {
                    editor.mapPanel.image = ImageIO.read(fc.getSelectedFile());
                    editor.pack();
                    editor.repaint();
                    editor.mapPanel.repaint();
                } catch (IOException e1) {
                    e1.printStackTrace();
                }
            }
        }
        if (e.getActionCommand().equals("FourTimesMap")) {
            editor.isFourTimesMap = editor.fourTimesMap.isSelected();
        }
        if (e.getActionCommand().equals("SixteenTimesMap")) {
            editor.isSixteenTimesMap = editor.sixteenTimesMap.isSelected();
        }
    }
}
