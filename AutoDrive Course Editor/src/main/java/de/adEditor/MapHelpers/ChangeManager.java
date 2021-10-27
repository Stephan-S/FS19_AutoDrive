package de.adEditor.MapHelpers;

import de.adEditor.MapPanel;

import java.util.LinkedList;

import static de.adEditor.ADUtils.LOG;
import static de.adEditor.MapPanel.*;


/**
 * Manages a Queue of Changables to perform undo and/or redo operations. Clients can add implementations of the Changeable
 * class to this class, and it will manage undo/redo as a Queue.
 *
 * @author Greg Cope
 *
 */



public class ChangeManager {

    // Interface to implement a Changeable type of action - either undo or redo.
    // @author Greg COpe

    public interface Changeable {
        // Undoes an action
        void undo();

        // Redoes an action
        void redo();
    }

    //the current index node
    private Node currentIndex;
    //the parent node far left node.
    private final Node parentNode = new Node();
    /**
     * Creates a new ChangeManager object which is initially empty.
     */
    public ChangeManager(){
        currentIndex = parentNode;
    }

     // Creates a new ChangeManager which is a duplicate of the parameter in both contents and current index.

    public ChangeManager(ChangeManager manager){
        this();
        currentIndex = manager.currentIndex;
    }

     // Clears all Changables contained in this manager.

    public void clear(){
        currentIndex = parentNode;
    }

     // Add a Changeable to manage.

    public void addChangeable(Changeable changeable){
        Node node = new Node(changeable);
        currentIndex.right = node;
        node.left = currentIndex;
        currentIndex = node;
    }

     // Return if undo can be performed.

    public boolean canUndo() {
        return currentIndex != parentNode;
    }

     // Return if redo can be performed.

    public boolean canRedo(){
        return currentIndex.right != null;
    }

     // Undoes the Changeable at the current index.

    public void undo(){
        //validate
        if ( !canUndo() ){
            LOG.info("Reached Beginning of Undo History.");
            return;
            //throw new IllegalStateException("Cannot undo. Index is out of range.");
        }
        //undo
        if (currentIndex.changeable != null) {
            currentIndex.changeable.undo();
        } else {
            LOG.info("Unable to Undo");
        }
        //set index
        moveLeft();
    }

    /**
     * Moves the internal pointer of the backed linked list to the left.
     * @throws IllegalStateException If the left index is null.
     */

    private void moveLeft(){
        if ( currentIndex.left == null ){
            throw new IllegalStateException("Internal index set to null.");
        }
        currentIndex = currentIndex.left;
    }

    /**
     * Moves the internal pointer of the backed linked list to the right.
     * @throws IllegalStateException If the right index is null.
     */

    private void moveRight(){
        if ( currentIndex.right == null ){
            throw new IllegalStateException("Internal index set to null.");
        }
        currentIndex = currentIndex.right;
    }

    /**
     * Redoes the Changable at the current index.
     * @throws IllegalStateException if canRedo returns false.
     */

    public void redo(){
        //validate
        if ( !canRedo() ){
            LOG.info("Reached End of Undo History.");
            return;
        }
        //reset index
        moveRight();
        //redo
        if (currentIndex.changeable != null) {
            currentIndex.changeable.redo();
        } else {
            LOG.info("Unable to Redo");
        }
    }

    /**
     * Inner class to implement a doubly linked list for our queue of Changeables.
     * @author Greg Cope
     *
     */

    private static class Node {
        private Node left = null;
        private Node right = null;
        private final Changeable changeable;

        public Node(Changeable c){
            changeable = c;
        }

        public Node(){
            changeable = null;
        }
    }

    //
    //  Move Nodes
    //

    public static class MoveNodeChanger implements Changeable{
        private final LinkedList<MapNode> moveNodes;
        private final int diffX;
        private final int diffY;

        public MoveNodeChanger(LinkedList<MapNode> mapNodesMoved, int movedX, int movedY){
            super();
            this.moveNodes = new LinkedList<>();
            this.diffX = movedX;
            this.diffY = movedY;
            for (int i = 0; i <= mapNodesMoved.size() - 1 ; i++) {
                MapNode mapNode = mapNodesMoved.get(i);
                this.moveNodes.add(mapNode);
            }
        }

        public void undo(){
            for (int i = 0; i <= this.moveNodes.size() - 1 ; i++) {
                MapNode mapNode = this.moveNodes.get(i);
                LOG.info("Moved {}", mapNode);
                MapPanel.getMapPanel().moveNodeBy(mapNode, -this.diffX, -this.diffY);
            }
            MapPanel.getMapPanel().repaint();
        }

        public void redo(){
            for (int i = 0; i <= this.moveNodes.size() - 1 ; i++) {
                MapNode mapNode = this.moveNodes.get(i);
                MapPanel.getMapPanel().moveNodeBy(mapNode, this.diffX, this.diffY);
            }
            MapPanel.getMapPanel().repaint();
        }
    }

    //
    // Add node
    //

    public static class AddNodeChanger implements Changeable{
        private final MapNode storeNode;

        public AddNodeChanger(MapNode node){
            super();
            this.storeNode = node;
        }

        public void undo(){
            roadMap.removeMapNode(storeNode);
            MapPanel.getMapPanel().repaint();
        }

        public void redo(){
            roadMap.insertMapNode(storeNode, null, null);
            MapPanel.getMapPanel().repaint();
        }
    }

    //
    // Delete Node
    //

    public static class RemoveNodeChanger implements Changeable{

        private LinkedList<NodeLinks> nodeListToDelete = new LinkedList<>();

        public RemoveNodeChanger(LinkedList<NodeLinks> nodeLinks){
            super();
            this.nodeListToDelete =  (LinkedList<NodeLinks>) nodeLinks.clone();
        }

        public void undo(){
            for (int j = 0; j < this.nodeListToDelete.size(); j++) {
                NodeLinks insertNode = this.nodeListToDelete.get(j);
                //LOG.info("Insert {} ({})",insertNode.node.id,insertNode.nodeIDbackup);
                if (insertNode.node.id != insertNode.nodeIDbackup) {
                    LOG.info("## RemoveNode Undo ## ID mismatch.. correcting ID {} -> ID {}", insertNode.node.id, insertNode.nodeIDbackup);
                    insertNode.node.id = insertNode.nodeIDbackup;
                }
                roadMap.insertMapNode(insertNode.node, insertNode.otherIncoming, insertNode.otherOutgoing);
            }
            MapPanel.getMapPanel().repaint();
        }

        public void redo(){
            for (int j = 0; j < this.nodeListToDelete.size(); j++) {
                MapNode toDelete = this.nodeListToDelete.get(j).node;
                roadMap.removeMapNode(toDelete);
            }
            MapPanel.getMapPanel().repaint();
        }
    }

    //
    // Linear Line Changer
    //

    public static class LinearLineChanger implements Changeable{

        private final MapNodeStore fromNode;
        private final MapNodeStore toNode;
        private final LinkedList<MapNodeStore> autoGeneratedNodes;
        private final int connectionType;

        //TODO: save/restore isStale() status

        public LinearLineChanger(MapNode from, MapNode to, LinkedList<MapNode> inbetweenNodes, int type){
            super();
            this.fromNode = new MapNodeStore(from);
            this.toNode = new MapNodeStore(to);
            this.autoGeneratedNodes = new LinkedList<>();
            this.connectionType=type;

            for (int j = 0; j < inbetweenNodes.size(); j++) {
                MapNode toStore = inbetweenNodes.get(j);
                autoGeneratedNodes.add(new MapNodeStore(toStore));
            }
        }

        public void undo(){

            if (this.autoGeneratedNodes.size() <= 2 ) {
                this.fromNode.restoreConnections();
                this.toNode.restoreConnections();
            } else {
                for (int j = 1; j < this.autoGeneratedNodes.size() - 1 ; j++) {
                    MapNodeStore storedNode = this.autoGeneratedNodes.get(j);
                    MapNode toDelete = storedNode.getMapNode();
                    MapPanel.roadMap.removeMapNode(toDelete);
                    if (MapPanel.hoveredNode == toDelete) {
                        MapPanel.hoveredNode = null;
                    }
                }
            }
            MapPanel.getMapPanel().repaint();
        }

        public void redo(){

            if (this.autoGeneratedNodes.size() > 2 ) {
                for (int i = 1; i < this.autoGeneratedNodes.size() - 1 ; i++) {
                    MapNodeStore storedNode = this.autoGeneratedNodes.get(i);
                    storedNode.clearConnections();
                    // during the undo process, removeMapNode deletes all the connections coming
                    // to/from this node but adjusts the node id's,  so we have to manually restore
                    // the id, .getMapNode() will check this for us and correct if necessary before
                    // passing us the node info.
                    MapNode newNode = storedNode.getMapNode();
                    roadMap.insertMapNode(newNode, null,null);
                }
            }
            LinearLine.connectNodes(getLineLinkedList(), this.connectionType);
            MapPanel.getMapPanel().repaint();
        }

        public LinkedList<MapNode> getLineLinkedList() {
            LinkedList<MapNode> list = new LinkedList<>();
            for (int i = 0; i <= this.autoGeneratedNodes.size() - 1 ; i++) {
                MapNodeStore nodeBackup = this.autoGeneratedNodes.get(i);
                list.add(nodeBackup.mapNode);
            }
            return list;
        }
    }

    //
    // Quadratic Curve Changer
    //

    public static class QuadCurveChanger implements Changeable{

        private final LinkedList<MapNodeStore> storedCurveNodeList;
        private final boolean isReversePath;
        private final boolean isDualPath;

        public QuadCurveChanger(LinkedList<MapNode> curveNodes, boolean isReverse, boolean isDual){
            super();

            this.storedCurveNodeList = new LinkedList<>();
            this.isReversePath = isReverse;
            this.isDualPath = isDual;

            for (int i = 0; i <= curveNodes.size() -1 ; i++) {
                MapNode mapNode = curveNodes.get(i);
                LOG.info("Adding ID {}", mapNode.id);
                this.storedCurveNodeList.add(new MapNodeStore(mapNode));
            }
        }

        public void undo(){
            for (int i = 1; i <= this.storedCurveNodeList.size() - 2 ; i++) {
                MapNodeStore curveNode = this.storedCurveNodeList.get(i);
                roadMap.removeMapNode(curveNode.getMapNode());
                if (curveNode.hasChangedID()) curveNode.resetID();
            }
            MapPanel.getMapPanel().repaint();
        }

        public void redo(){

            for (int i = 1; i <= this.storedCurveNodeList.size() - 2 ; i++) {
                MapNodeStore curveNode = this.storedCurveNodeList.get(i);
                curveNode.clearConnections();
                roadMap.insertMapNode(curveNode.getMapNode(), null,null);
                if (curveNode.hasChangedID()) curveNode.resetID();
            }
            QuadCurve.connectNodes(getCurveLinkedList(), this.isReversePath, this.isDualPath);
            MapPanel.getMapPanel().repaint();
        }

        public LinkedList<MapNode> getCurveLinkedList() {
            LinkedList<MapNode> list = new LinkedList<>();
            for (int i = 0; i <= this.storedCurveNodeList.size() - 1 ; i++) {
                MapNodeStore nodeBackup = this.storedCurveNodeList.get(i);
                list.add(nodeBackup.mapNode);
            }
            return list;
        }
    }

    //
    // Node Priority Changer
    //

    public static class NodePriorityChanger implements Changeable{
        private final LinkedList<MapNode> nodesPriorityChanged;

        public NodePriorityChanger(LinkedList<MapNode> mapNodesChanged){
            super();
            this.nodesPriorityChanged = new LinkedList<>();
            for (int i = 0; i <= mapNodesChanged.size() - 1 ; i++) {
                MapNode mapNode = mapNodesChanged.get(i);
                this.nodesPriorityChanged.add(mapNode);
            }
        }

        public void undo(){
            for (int i = 0; i <= this.nodesPriorityChanged.size() - 1 ; i++) {
                MapNode mapNode = this.nodesPriorityChanged.get(i);
                mapNode.flag = 1 - mapNode.flag;
            }
            MapPanel.getMapPanel().repaint();
        }

        public void redo(){
            for (int i = 0; i <= this.nodesPriorityChanged.size() - 1 ; i++) {
                MapNode mapNode = this.nodesPriorityChanged.get(i);
                mapNode.flag = 1 - mapNode.flag;
            }
            MapPanel.getMapPanel().repaint();
        }
    }

    private static class MapNodeStore {
        private final MapNode mapNode;
        private final int mapNodeIDBackup;
        private final LinkedList<MapNode> incomingBackup;
        private final LinkedList<MapNode> outgoingBackup;

        public MapNodeStore(MapNode node) {
            this.mapNode = node;
            this.mapNodeIDBackup = node.id;
            this.incomingBackup = new LinkedList<>();
            this.outgoingBackup = new LinkedList<>();
            backupConnections();
        }

        public MapNode getMapNode() {
            if (this.hasChangedID()) this.resetID();
            return this.mapNode;
        }

        public void resetID() { this.mapNode.id = this.mapNodeIDBackup; }

        public boolean hasChangedID() { return this.mapNode.id != this.mapNodeIDBackup; }

        public void clearConnections() {
            clearIncoming();
            clearOutgoing();
        }

        public void clearIncoming() { this.mapNode.incoming.clear(); }

        public void clearOutgoing() { this.mapNode.outgoing.clear(); }

        public void backupConnections() {
            copyList(this.mapNode.incoming, this.incomingBackup);
            copyList(this.mapNode.outgoing, this.outgoingBackup);
        }

        public void restoreConnections() {
            copyList(this.incomingBackup, this.mapNode.incoming);
            copyList(this.outgoingBackup, this.mapNode.outgoing);
        }

        public void backupIncoming() { copyList(this.mapNode.incoming, this.incomingBackup); }

        public void restoreIncoming() { copyList(this.incomingBackup, this.mapNode.incoming); }

        public void backupOutgoing() { copyList(this.mapNode.outgoing, this.outgoingBackup); }

        public void restoreOutgoing() { copyList(this.outgoingBackup, this.mapNode.outgoing); }

        private void copyList(LinkedList<MapNode> from, LinkedList<MapNode> to) {
            to.clear();
            // use .clone() ??
            for (int i = 0; i <= from.size() - 1 ; i++) {
                MapNode mapNode = from.get(i);
                to.add(mapNode);
            }
        }
    }


}