package de.adEditor.MapHelpers;

import de.adEditor.MapPanel;

import java.util.LinkedList;

import static de.adEditor.ADUtils.LOG;

public class RoadMap {

    public LinkedList<MapNode> mapNodes;
    public LinkedList<MapMarker> mapMarkers;

    public RoadMap () {
        mapMarkers = new LinkedList<>();
        mapNodes = new LinkedList<>();
    }

    public void addMapMarker(MapMarker mapMarker) {
        mapMarkers.add(mapMarker);
    }

    public void insertMapNode(MapNode toAdd, LinkedList<MapNode> otherNodesInList, LinkedList<MapNode> otherNodesOutList) {

        // starting at the index of where we need to insert the node
        // increment the ID's of all nodes to the right of the mapNodes by +1
        // so when we insert the nod the id's match the index

        LinkedList<MapNode> nodes = mapNodes;
        for (int i = toAdd.id - 1 ; i <= nodes.size() - 1 ; i++) {
            MapNode mapNode = nodes.get(i);
            //LOG.info("changing index {} ({}) -- {} to {}",i,i + 1,  mapNode.id, mapNode.id + 1);
            mapNode.id++;
        }
        // insert the MapNode into the list
        //LOG.info("inserting index {} -- ID {}", toAdd.id - 1, toAdd.id );
        mapNodes.add(toAdd.id -1 , toAdd);

        //now we need to restore all the connections to/from it

        // restore all the outgoing connections

        if (otherNodesInList != null) {
            for (int i = 0; i <= otherNodesInList.size() - 1; i++) {
                MapNode inNode = otherNodesInList.get(i);
                if (!inNode.incoming.contains(toAdd)) inNode.incoming.add(toAdd);
            }
        }

        if (otherNodesOutList != null) {
            for (int i = 0; i <= otherNodesOutList.size() - 1; i++) {
                MapNode outNode = otherNodesOutList.get(i);
                if (!outNode.outgoing.contains(toAdd)) outNode.outgoing.add(toAdd);
            }
        }
    }

    public void removeMapNode(MapNode toDelete) {
        if (MapPanel.quadCurve != null && MapPanel.isQuadCurveCreated) {
            if (toDelete == MapPanel.quadCurve.getCurveStartNode() || toDelete == MapPanel.quadCurve.getCurveEndNode()) {
                LOG.info("Cannot delete the start or end nodes of curve until it is confirmed or cancelled");
                return;
            }
        }
        boolean deleted = false;
        if (mapNodes.contains(toDelete)) {
            mapNodes.remove(toDelete);
            deleted = true;
        }

        LinkedList<MapNode> nodes = mapNodes;
        for (int i = 0; i < nodes.size(); i++) {
            MapNode mapNode = nodes.get(i);
            if (mapNode.outgoing.contains(toDelete)) {
                mapNode.outgoing.remove(toDelete);
            }
            if (mapNode.incoming.contains(toDelete)) {
                mapNode.incoming.remove(toDelete);
            }
            if (deleted && mapNode.id > toDelete.id) {
                mapNode.id--;
            }
        }

        LinkedList<MapMarker> mapMarkersToDelete = new LinkedList<>();
        for (MapMarker mapMarker : mapMarkers) {
            if (mapMarker.mapNode == toDelete) {

                mapMarkersToDelete.add(mapMarker);
            }
        }
        for (MapMarker mapMarker : mapMarkersToDelete) {
            removeMapMarker(mapMarker);
            mapMarkers.remove(mapMarker);
        }
    }

    public void removeMapMarker(MapMarker mapMarker) {
        LinkedList<MapMarker> mapMarkersToKeep = new LinkedList<>();
        for (MapMarker mapMarkerIter : mapMarkers) {
            if (mapMarkerIter.mapNode.id != mapMarker.mapNode.id) {
                mapMarkersToKeep.add(mapMarkerIter);
            }
        }
        mapMarkers = mapMarkersToKeep;
    }

    public static boolean isDual(MapNode start, MapNode target) {
        LinkedList<MapNode> nodes = start.outgoing;
        for (MapNode outgoing : nodes) {
            if (outgoing == target) {
                LinkedList<MapNode> mapNodeLinkedList = target.outgoing;
                for (MapNode outgoingTarget : mapNodeLinkedList) {
                    if (outgoingTarget == start) {
                        return true;
                    }
                }
            }
        }

        return false;
    }

    public static boolean isReverse(MapNode start, MapNode target) {
        LinkedList<MapNode> startnodes = target.incoming;
        if (startnodes.size() >0) {
            for (MapNode incoming : startnodes) {
                if (incoming.id == start.id) {
                    return false;
                }
            }
        }
        LinkedList<MapNode> outnodes = start.outgoing;
        for (MapNode outgoing : outnodes) {
            if (outgoing.id == target.id) {
                return true;
            }
        }
        return false;
    }
}
