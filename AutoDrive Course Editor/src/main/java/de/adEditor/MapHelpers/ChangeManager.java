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
            /*LOG.info("Insert {} , size {}",storeNode.id, roadMap.mapNodes.size());
            roadMap.insertMapNode(storeNode, otherNodesInList, otherNodesOutList);*/
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
    // Connection Changer
    //

    public static class LinearLineChanger implements Changeable{
        private final MapNode fromNode;
        private final int fromNodeIDbackup;
        private final LinkedList<MapNode> fromIncomingBackup;
        private final LinkedList<MapNode> fromOutgoingBackup;
        private final MapNode toNode;
        private final int toNodeIDbackup;
        private final LinkedList<MapNode> toIncomingBackup;
        private final LinkedList<MapNode> toOutgoingBackup;
        private final LinkedList<MapNode> autoGeneratedNodes;
        private final int connectionType;

        //TODO: save/restore isStale() status

        public LinearLineChanger(MapNode from, MapNode to, LinkedList<MapNode> inbetweenNodes, int type){
            super();
            this.fromNode = from;
            this.fromNodeIDbackup = from.id;
            this.fromIncomingBackup = new LinkedList<>();
            this.fromOutgoingBackup = new LinkedList<>();
            this.toNode = to;
            this.toNodeIDbackup = to.id;
            this.toIncomingBackup = new LinkedList<>();
            this.toOutgoingBackup = new LinkedList<>();
            this.autoGeneratedNodes = (LinkedList<MapNode>) inbetweenNodes.clone();
            this.connectionType=type;

            copyList(from.incoming, this.fromIncomingBackup);;
            copyList(from.outgoing,  this.fromOutgoingBackup);
            copyList(to.incoming, this.toIncomingBackup);
            copyList(to.outgoing, this.toOutgoingBackup);
        }

        public void undo(){

            if (autoGeneratedNodes.size() <= 2 ) {
                restoreList(this.fromIncomingBackup, this.fromNode.incoming);
                restoreList(this.fromOutgoingBackup, this.fromNode.outgoing);
                restoreList(this.toIncomingBackup, this.toNode.incoming);
                restoreList(this.toOutgoingBackup, this.toNode.outgoing);
            } else {
                for (int j = 1; j < this.autoGeneratedNodes.size() - 1; j++) {
                    MapNode toDelete = this.autoGeneratedNodes.get(j);
                    // removeMapNode deletes all the connections coming to/from this node
                    // but adjusts the node id's,  so we have to manually restore the id
                    // later if we have to redo()
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
                for (int j = 1; j < this.autoGeneratedNodes.size() - 1; j++) {
                    MapNode newNode = this.autoGeneratedNodes.get(j);
                    newNode.id = roadMap.mapNodes.size() +1;
                    newNode.incoming.clear();
                    newNode.outgoing.clear();
                    roadMap.mapNodes.add(newNode);
                }
            }
            //LinearLine.connectNodes(this.autoGeneratedNodes, this.connectionType);
            MapPanel.getMapPanel().repaint();
        }

        public void copyList(LinkedList<MapNode> fromList, LinkedList<MapNode> toList) {
            toList.clear();
            for (int fi = 0; fi <= fromList.size() - 1 ; fi++) {
                MapNode mapNode = fromList.get(fi);
                if (!toList.contains(mapNode)) {
                    toList.add(mapNode);
                }
            }
        }

        public void restoreList(LinkedList<MapNode> fromList, LinkedList<MapNode> toList) {
            toList.clear();
            for (int fi = 0; fi <= fromList.size() - 1 ; fi++) {
                MapNode mapNode = fromList.get(fi);
                if (!toList.contains(mapNode)) {
                    toList.add(mapNode);
                }
            }
        }
    }

    //
    // Quadratic Curve Changer
    //

    public static class QuadCurveChanger implements Changeable{

        private final MapNode curveStart;
        private final MapNode curveEnd;
        private LinkedList<MapNode> curveNodeList;
        private final int connectionType;

        public QuadCurveChanger(MapNode start, MapNode end, LinkedList<MapNode> curveNodes, int conType){
            super();

            this.curveStart = start;
            this.curveEnd = end;
            this.curveNodeList = new LinkedList<>();
            this.connectionType = conType;

            for (int i = 0; i <= curveNodes.size() - 1; i++) {
                MapNode mapNode = curveNodes.get(i);
                this.curveNodeList.add(mapNode);
            }

            /*copyList(satrt.incoming, this.fromIncomingBackup);;
            copyList(from.outgoing,  this.fromOutgoingBackup);
            copyList(to.incoming, this.toIncomingBackup);
            copyList(to.outgoing, this.toOutgoingBackup);*/
        }

        public void undo(){

            for (int i = 1; i <= this.curveNodeList.size() - 2 ; i++) {
                MapNode mapNode = this.curveNodeList.get(i);
                roadMap.removeMapNode(mapNode);
            }
            MapPanel.getMapPanel().repaint();
        }

        public void redo(){

            for (int i = 1; i <= this.curveNodeList.size() - 2 ; i++) {
                MapNode newNode = this.curveNodeList.get(i);
                newNode.incoming.clear();
                newNode.outgoing.clear();
                roadMap.mapNodes.add(newNode);
            }
            QuadCurve.connectNodes(this.curveNodeList);

            MapPanel.getMapPanel().repaint();
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


}