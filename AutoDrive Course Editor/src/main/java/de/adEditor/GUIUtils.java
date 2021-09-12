package de.adEditor;

import javax.swing.*;
import java.net.URL;

public class GUIUtils {

    public static JFrame frame;

    public static JButton makeButton(String actionCommand,String toolTipText,String altText, JPanel panel, EditorListener editorListener) {
        JButton button = new JButton();
        button.setActionCommand(actionCommand);
        button.setToolTipText(toolTipText);
        button.addActionListener(editorListener);
        button.setText(altText);
        panel.add(button);

        return button;
    }

    public static JToggleButton makeToggleButton(String imageName,String actionCommand,String toolTipText,String altText, JPanel panel, EditorListener editorListener) {
        JToggleButton toggleButton = new JToggleButton();

        //Load image
        String imgLocation = "/editor/" + imageName + ".png";
        URL imageURL = AutoDriveEditor.class.getResource(imgLocation);

        toggleButton.setActionCommand(actionCommand);
        toggleButton.setToolTipText(toolTipText);
        toggleButton.addActionListener(editorListener);

        if (imageURL != null) {  //image found
            toggleButton.setIcon(new ImageIcon(imageURL, altText));
            toggleButton.setBorder(BorderFactory.createEmptyBorder());
            toggleButton.setRolloverEnabled(true);
        } else {                 //no image found
            toggleButton.setText(altText);
        }

        panel.add(toggleButton);

        return toggleButton;
    }

    public static JRadioButton makeRadioButton(String text,String actionCommand,String toolTipText,boolean selected, JPanel panel, ButtonGroup group, EditorListener editorListener) {
        JRadioButton radioButton = new JRadioButton(text);
        radioButton.setActionCommand(actionCommand);
        radioButton.setToolTipText(toolTipText);
        radioButton.setSelected(selected);
        radioButton.addActionListener(editorListener);
        panel.add(radioButton);
        group.add(radioButton);

        return radioButton;
    }

    public static JCheckBoxMenuItem makeCheckBoxMenuItem (String text, int keyEvent, Boolean isSelected, JMenu menu, EditorListener editorListener) {
        JCheckBoxMenuItem cbMenuItem = new JCheckBoxMenuItem(text, isSelected);
        cbMenuItem.setMnemonic(keyEvent);
        cbMenuItem.setSelected(isSelected);
        cbMenuItem.addItemListener(editorListener);
        menu.add(cbMenuItem);

        return cbMenuItem;
    }

    public static JMenu makeNewMenu(String menuName, int keyEvent, String accString, JMenuBar parentMenu) {
        JMenu newMenu = new JMenu(menuName);
        newMenu.setMnemonic(keyEvent);
        newMenu.getAccessibleContext().setAccessibleDescription(accString);
        parentMenu.add(newMenu);
        return newMenu;
    }

    public static JMenu makeSubMenu(String menuName, int keyEvent, String accString, JMenu parentMenu) {
        JMenu newMenu = new JMenu(menuName);
        newMenu.setMnemonic(keyEvent);
        newMenu.getAccessibleContext().setAccessibleDescription(accString);
        parentMenu.add(newMenu);
        return newMenu;
    }

    public static JMenuItem makeMenuItem(String menuName, int keyEvent, int inputEvent, String accString, JMenu menu, EditorListener listener, Boolean enabled) {
        JMenuItem menuItem = new JMenuItem(menuName);
        menuItem.setAccelerator(KeyStroke.getKeyStroke(keyEvent, inputEvent));
        menuItem.getAccessibleContext().setAccessibleDescription(accString);
        menuItem.setEnabled(enabled);
        menuItem.addActionListener(listener);
        menu.add(menuItem);
        return menuItem;
    }

    // if no button group is required, set buttonGroup to null and isGroupDefault will be ignored

    public static JRadioButtonMenuItem makeRadioButtonMenuItem(String menuName, int keyEvent, int inputEvent, String accString, JMenu menu, EditorListener listener, Boolean enabled, ButtonGroup buttonGroup, boolean isGroupDefault) {
        JRadioButtonMenuItem menuItem = new JRadioButtonMenuItem(menuName);
        menuItem.setAccelerator(KeyStroke.getKeyStroke(keyEvent, inputEvent));
        menuItem.getAccessibleContext().setAccessibleDescription(accString);
        menuItem.setEnabled(enabled);
        menuItem.addActionListener(listener);
        if (buttonGroup != null) {
            buttonGroup.add(menuItem);
            if (isGroupDefault) {
                //ButtonModel groupDefault = menuItem.getModel();
                buttonGroup.setSelected(menuItem.getModel(), true);
            }
        }
        menu.add(menuItem);
        return menuItem;
    }
}
