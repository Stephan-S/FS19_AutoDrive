import org.xml.sax.SAXException;

import javax.imageio.ImageIO;
import javax.swing.*;
import javax.xml.parsers.ParserConfigurationException;
import java.awt.event.ActionEvent;
import java.awt.event.ActionListener;
import java.awt.geom.Point2D;
import java.io.File;
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
        if (e.getActionCommand() == "Save") {
            int returnVal = fc.showSaveDialog(editor);

            if (returnVal == JFileChooser.APPROVE_OPTION) {
                editor.savedFile = fc.getSelectedFile();
                editor.saveMap(editor.loadedFile.getAbsolutePath(), editor.savedFile.getAbsolutePath());
            }
            else {
                this.editor.saveMap("C:\\Users\\Stephan\\Downloads\\AutoDrive_config.xml", "C:\\Users\\Stephan\\Downloads\\AutoDrive_config_new.xml");
            }
        }
        if (e.getActionCommand() == "Move Nodes") {
            this.editor.editorState = AutoDriveEditor.EDITORSTATE_MOVING;
        }
        if (e.getActionCommand() == "Remove Nodes") {
            this.editor.editorState = AutoDriveEditor.EDITORSTATE_DELETING;
        }
        if (e.getActionCommand() == "Remove Destinations") {
            this.editor.editorState = AutoDriveEditor.EDITORSTATE_DELETING_DESTINATION;
        }
        if (e.getActionCommand() == "Connect Nodes") {
            this.editor.editorState = AutoDriveEditor.EDITORSTATE_CONNECTING;
        }
        if (e.getActionCommand() == "Create Nodes") {
            this.editor.editorState = AutoDriveEditor.EDITORSTATE_CREATING;
        }
        if (e.getActionCommand() == "Create Destinations") {
            this.editor.editorState = AutoDriveEditor.EDITORSTATE_CREATING_DESTINATION;
        }
        if (e.getActionCommand() == "Load") {
            int returnVal = fc.showOpenDialog(editor);

            if (returnVal == JFileChooser.APPROVE_OPTION) {
                editor.loadedFile = fc.getSelectedFile();
                try {
                    editor.mapPanel.roadMap = editor.loadFile(editor.loadedFile.getAbsolutePath());
                    editor.pack();
                    editor.repaint();
                    editor.mapPanel.repaint();
                } catch (ParserConfigurationException e1) {
                    e1.printStackTrace();
                } catch (IOException e1) {
                    e1.printStackTrace();
                } catch (SAXException e1) {
                    e1.printStackTrace();
                }
            }
        }
        if (e.getActionCommand() == "Load Image") {
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
        if (e.getActionCommand() == "FourTimesMap") {
            editor.isFourTimesMap = editor.fourTimesMap.isSelected();
        }
    }
}
