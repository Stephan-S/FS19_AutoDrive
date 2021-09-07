package de.adEditor;

import javax.swing.*;
import javax.swing.event.TreeSelectionEvent;
import javax.swing.event.TreeSelectionListener;
import javax.swing.tree.*;
import java.awt.*;
import java.awt.event.WindowAdapter;
import java.awt.event.WindowEvent;
import java.net.URL;
import java.util.Collections;
import java.util.Comparator;
import java.util.Enumeration;

import static de.adEditor.ADUtils.LOG;

public class GUIUtils {

    public static JFrame frame;

    public static JToggleButton makeToggleButton(String imageName, String actionCommand, String toolTipText, String altText, JPanel panel, EditorListener editorListener, boolean hasBorder) {
        JToggleButton toggleButton = new JToggleButton();

        //Load image
        String imgLocation = "/editor/" + imageName + ".png";
        URL imageURL = AutoDriveEditor.class.getResource(imgLocation);

        toggleButton.setActionCommand(actionCommand);
        toggleButton.setToolTipText(toolTipText);
        toggleButton.addActionListener(editorListener);
        toggleButton.setBorderPainted(hasBorder);

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

    public static JCheckBoxMenuItem makeCheckBoxMenuItem (String text, int keyEvent, Boolean selected, JMenu menu, EditorListener editorListener) {
        JCheckBoxMenuItem cbMenuItem = new JCheckBoxMenuItem(text);
        cbMenuItem.setMnemonic(keyEvent);
        cbMenuItem.setSelected(selected);
        cbMenuItem.addItemListener(editorListener);
        menu.add(cbMenuItem);

        return cbMenuItem;
    }

    public static JMenu makeMenu(String menuName, int event, String accString, JMenuBar menu) {
        JMenu fileMenu = new JMenu(menuName);
        fileMenu.setMnemonic(event);
        fileMenu.getAccessibleContext().setAccessibleDescription(accString);
        menu.add(fileMenu);
        return fileMenu;
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

    public static void createFrame() {
        EventQueue.invokeLater(new Runnable() {

            class SimpleTreeNode extends DefaultMutableTreeNode
            {
                private final Comparator comparator;

                public SimpleTreeNode(Object userObject, Comparator comparator)
                {
                    super(userObject);
                    this.comparator = comparator;
                }

                public SimpleTreeNode(Object userObject)
                {
                    this(userObject,null);
                }

                @Override
                public void add(MutableTreeNode newChild)
                {
                    super.add(newChild);
                    if (this.comparator != null)
                    {
                        Collections.sort(this.children,nodeComparator);
                    }
                }

                @Override
                public void insert(MutableTreeNode newChild, int childIndex)    {
                    super.insert(newChild, childIndex);
                    //LOG.info("level = {}", super.getLevel());
                    if (newChild.isLeaf()) {
                        //LOG.info("{}", this.children);
                        Collections.sort(this.children, nodeComparator);
                    }
                }

                protected Comparator nodeComparator = new Comparator () {
                    @Override
                    public int compare(Object o1, Object o2) {
                        return o1.toString().compareToIgnoreCase(o2.toString());
                    }

                    @Override
                    @SuppressWarnings("EqualsWhichDoesntCheckParameterClass")
                    public boolean equals(Object obj)    {
                        return false;
                    }

                    @Override
                    public int hashCode() {
                        int hash = 7;
                        return hash;
                    }
                };
            }

            @Override
            public void run() {


                frame = new JFrame("Manage Markers");
                frame.setDefaultCloseOperation(JFrame.DISPOSE_ON_CLOSE);
                frame.setSize(600, 600);
                frame.setIconImage(AutoDriveEditor.getTractorIcon());
                try {
                    UIManager.setLookAndFeel(UIManager.getSystemLookAndFeelClassName());
                } catch (Exception e) {
                    e.printStackTrace();
                }

                MarkerTree treePanel = new MarkerTree();
                frame.add(treePanel);
                frame.pack();
                frame.setLocationRelativeTo(null);
                frame.setVisible(true);

                // make sure we reset frame to null on exit
                frame.addWindowListener( new WindowAdapter()
                {
                    public void windowClosing(WindowEvent e)
                    {
                        frame = null;
                    }
                });


            }

            class MarkerTree extends JPanel implements TreeSelectionListener {

                private JTree tree;
                public SimpleTreeNode top;


                //Optionally play with line styles.  Possible values are
                //"Angled" (the default), "Horizontal", and "None".
                private String lineStyle = "Horizontal";



                public MarkerTree() {
                    super(new FlowLayout(FlowLayout.LEFT));
                    RoadMap.Initiater.addListener(new Responder());
                    top = new SimpleTreeNode("Root");

                    createMarkerTreeNodes();

                    //Create a tree that allows one selection at a time.
                    tree = new JTree(top);
                    tree.setDragEnabled(true);
                    tree.setRootVisible(true);
                    tree.getSelectionModel().setSelectionMode(TreeSelectionModel.SINGLE_TREE_SELECTION);
                    tree.addTreeSelectionListener(this);
                    tree.putClientProperty("JTree.lineStyle", lineStyle);



                    JScrollPane scrollTree = new JScrollPane(tree); //Create a scrollpane and add the tree to it

                    JSplitPane splitPane = new JSplitPane(JSplitPane.HORIZONTAL_SPLIT);

                    splitPane.setPreferredSize(new Dimension(480, 300));
                    splitPane.setDividerLocation(220);
                    splitPane.setLeftComponent(scrollTree); //Add the tree to the left component

                    JPanel controls = new JPanel();

                    //JButton makeButton("Load Image","Load map image from disk ( must be 2048x2048 .PNG format)","Load Map", controls,null);
                    splitPane.setRightComponent(controls);

                    add(splitPane);
                }

                /**
                 * Required by TreeSelectionListener interface.
                 */
                public void valueChanged(TreeSelectionEvent e) {
                    SimpleTreeNode node = (SimpleTreeNode)
                            tree.getLastSelectedPathComponent();

                    if (node == null) return;

                    Object nodeInfo = node.getUserObject();
                    LOG.info("name = {} - leaf = {} - Level = {} ",nodeInfo, node.isLeaf(), node.getLevel());
                    LOG.info("name = {}",node.getDepth());
                }

                class MarkerInfo {
                    public final int markerID;
                    public final String markerName;
                    public final String markerGroup;

                    public MarkerInfo(int id, String name, String group) {
                        markerID = id;
                        markerName = name;
                        markerGroup = group;
                    }

                    public String toString() {
                        return markerName;
                    }
                }

                private SimpleTreeNode getNodeGroup(SimpleTreeNode rootNode, String groupStr) {
                    SimpleTreeNode node;
                    Enumeration<TreeNode> e = rootNode.breadthFirstEnumeration();
                    while (e.hasMoreElements()) {
                        node = (SimpleTreeNode) e.nextElement();
                        if (groupStr.equals(node.getUserObject().toString()) && !node.isLeaf()) {
                            return node;
                        }
                    }
                    //LOG.info("False");
                    return null;
                }

                public void createMarkerTreeNodes() {
                    SimpleTreeNode defaultGroup = null;
                    SimpleTreeNode newGroup;
                    SimpleTreeNode newName;
                    int numgroups = 0;

                    top.removeAllChildren();

                    for (int i = 0; i < RoadMap.mapMarkers.size(); i++) {
                        MapMarker mapMarker = RoadMap.mapMarkers.get(i);
                        if ("All".equals(mapMarker.group)) {
                            newName = new SimpleTreeNode(new MarkerInfo(mapMarker.mapNode.id, mapMarker.name, mapMarker.group));
                            top.add(newName);
                        }
                    }

                    SimpleTreeNode group = new SimpleTreeNode("Groups");
                    for (int i = 0; i < RoadMap.mapMarkers.size(); i++) {
                        MapMarker mapMarker = RoadMap.mapMarkers.get(i);

                        //LOG.info("Searching for node {}",mapMarker.group);

                        if (!"All".equals(mapMarker.group)) { // if (mapMarker.group == "All") doesnt work ??? :-/
                            SimpleTreeNode returnNode = getNodeGroup(group, mapMarker.group);
                            if (returnNode != null) {
                                //LOG.info("adding {} to group {}", mapMarker.name, mapMarker.group);
                                returnNode.add(new SimpleTreeNode(new MarkerInfo(mapMarker.mapNode.id, mapMarker.name, mapMarker.group)));
                                numgroups++;
                            } else {
                                //LOG.info("Creating new group {}", mapMarker.group);
                                newGroup = new SimpleTreeNode(mapMarker.group);
                                group.add(newGroup);
                                numgroups++;
                                //LOG.info("adding {} to {}", mapMarker.name, mapMarker.group);
                                newName = new SimpleTreeNode(new MarkerInfo(mapMarker.mapNode.id, mapMarker.name, mapMarker.group));
                                newGroup.add(newName);
                            }
                        }
                    }

                    if (numgroups > 0)  top.add(group);

                    LOG.info("tree = {}", tree);

                    if (tree != null) {
                        DefaultTreeModel model = (DefaultTreeModel)tree.getModel();
                        //SimpleTreeNode root = (SimpleTreeNode)model.getRoot();
                        model.reload();
                        //tree.expandPath(tree.getPathForRow(0));
                    }
                }

                public void sortMarkerTreeNodes() {
                    SimpleTreeNode defaultGroup = null;
                    SimpleTreeNode newGroup = null;
                    SimpleTreeNode newName = null;
                    int numgroups = 0;

                    for (int i = 0; i < RoadMap.mapMarkers.size(); i++) {
                        MapMarker mapMarker = RoadMap.mapMarkers.get(i);
                        if ("All".equals(mapMarker.group)) {
                            newName = new SimpleTreeNode(new MarkerInfo(mapMarker.mapNode.id, mapMarker.name, mapMarker.group));
                            top.add(newName);
                        }
                    }



                }



                class Responder implements EventListener, RoadMap.EventListener {
                    @Override
                    public void mapMarkersUpdate() {
                        createMarkerTreeNodes();
                    }
                }




            }


        });

    }

    interface EventListener {
        void mapMarkersUpdate();
    }
}
