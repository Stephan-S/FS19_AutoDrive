package de.adEditor;

import javax.swing.*;
import java.net.URL;

import static de.adEditor.AutoDriveEditor.localeString;

public class GUIUtils {

    public static JFrame frame;

    public static JButton makeButton(String actionCommand,String toolTipText,String altText, JPanel panel, EditorListener editorListener) {
        JButton button = new JButton();
        button.setActionCommand(actionCommand);
        button.setToolTipText(localeString.getString(toolTipText));
        button.addActionListener(editorListener);
        button.setText(localeString.getString(altText));
        panel.add(button);

        return button;
    }

    public static JToggleButton makeToggleButton(String imageName,String actionCommand,String toolTipText,String altText, JPanel panel, EditorListener editorListener) {
        JToggleButton toggleButton = new JToggleButton();

        //Load image
        String imgLocation = "/editor/" + imageName + ".png";
        URL imageURL = AutoDriveEditor.class.getResource(imgLocation);

        toggleButton.setActionCommand(actionCommand);
        toggleButton.setToolTipText(localeString.getString(toolTipText));
        toggleButton.addActionListener(editorListener);

        if (imageURL != null) {  //image found
            toggleButton.setIcon(new ImageIcon(imageURL, altText));
            toggleButton.setBorder(BorderFactory.createEmptyBorder());
            toggleButton.setRolloverEnabled(true);
        } else {                 //no image found
            toggleButton.setText(localeString.getString(altText));
        }

        panel.add(toggleButton);

        return toggleButton;
    }

    public static JRadioButton makeRadioButton(String text,String actionCommand,String toolTipText,boolean selected, JPanel panel, ButtonGroup group, EditorListener editorListener) {
        JRadioButton radioButton = new JRadioButton(localeString.getString(text));
        radioButton.setActionCommand(actionCommand);
        radioButton.setToolTipText(localeString.getString(toolTipText));
        radioButton.setSelected(selected);
        radioButton.addActionListener(editorListener);
        panel.add(radioButton);
        group.add(radioButton);

        return radioButton;
    }

    public static JCheckBoxMenuItem makeCheckBoxMenuItem (String text, int keyEvent, String accString, Boolean isSelected, JMenu menu, EditorListener editorListener) {
        JCheckBoxMenuItem cbMenuItem = new JCheckBoxMenuItem(localeString.getString(text), isSelected);
        cbMenuItem.setMnemonic(keyEvent);
        cbMenuItem.setSelected(isSelected);
        cbMenuItem.getAccessibleContext().setAccessibleDescription(localeString.getString(accString));
        cbMenuItem.addItemListener(editorListener);
        menu.add(cbMenuItem);

        return cbMenuItem;
    }

    public static JMenu makeNewMenu(String menuName, int keyEvent, String accString, JMenuBar parentMenu) {
        JMenu newMenu = new JMenu(localeString.getString(menuName));
        newMenu.setMnemonic(keyEvent);
        newMenu.getAccessibleContext().setAccessibleDescription(localeString.getString(accString));
        parentMenu.add(newMenu);
        return newMenu;
    }

    public static JMenu makeSubMenu(String menuName, int keyEvent, String accString, JMenu parentMenu) {
        JMenu newMenu = new JMenu(localeString.getString(menuName));
        newMenu.setMnemonic(keyEvent);
        newMenu.getAccessibleContext().setAccessibleDescription(localeString.getString(accString));
        parentMenu.add(newMenu);
        return newMenu;
    }

    public static JMenuItem makeMenuItem(String menuName, int keyEvent, int inputEvent, String accString, JMenu menu, EditorListener listener, Boolean enabled) {
        JMenuItem menuItem = new JMenuItem(localeString.getString(menuName));
        menuItem.setAccelerator(KeyStroke.getKeyStroke(keyEvent, inputEvent));
        menuItem.getAccessibleContext().setAccessibleDescription(localeString.getString(accString));
        menuItem.setEnabled(enabled);
        menuItem.addActionListener(listener);
        menu.add(menuItem);
        return menuItem;
    }

    // if no button group is required, set buttonGroup to null and isGroupDefault will be ignored

    public static JRadioButtonMenuItem makeRadioButtonMenuItem(String menuName, int keyEvent, int inputEvent, String accString, JMenu menu, EditorListener listener, Boolean enabled, ButtonGroup buttonGroup, boolean isGroupDefault) {
        JRadioButtonMenuItem menuItem = new JRadioButtonMenuItem(localeString.getString(menuName));
        menuItem.setAccelerator(KeyStroke.getKeyStroke(keyEvent, inputEvent));
        menuItem.getAccessibleContext().setAccessibleDescription(localeString.getString(accString));
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
