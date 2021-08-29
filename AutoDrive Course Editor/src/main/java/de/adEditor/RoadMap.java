package de.adEditor;

import java.util.LinkedList;

public class RoadMap {

    public LinkedList<MapNode> mapNodes;
    public LinkedList<MapMarker> mapMarkers;

    public RoadMap () {
        this.mapMarkers = new LinkedList<>();
        this.mapNodes = new LinkedList<>();
    }

    public void addMapNode(MapNode mapNode) {
        this.mapNodes.add(mapNode);
    }

    public void addMapMarker(MapMarker mapMarker) {
        this.mapMarkers.add(mapMarker);
    }

    public void removeMapNode(MapNode toDelete) {
        boolean deleted = false;
        if (mapNodes.contains(toDelete)) {
            mapNodes.remove(toDelete);
            deleted = true;
        }

        for (MapNode mapNode : this.mapNodes) {
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
        for (MapMarker mapMarker : this.mapMarkers) {
            if (mapMarker.mapNode == toDelete) {

                mapMarkersToDelete.add(mapMarker);
            }
        }
        for (MapMarker mapMarker : mapMarkersToDelete) {
            removeMapMarker(mapMarker);
            this.mapMarkers.remove(mapMarker);
        }
    }

    public void removeMapMarker(MapMarker mapMarker) {
        LinkedList<MapMarker> mapMarkersToKeep = new LinkedList<>();
        for (MapMarker mapMarkerIter : this.mapMarkers) {
            if (mapMarkerIter.mapNode.id != mapMarker.mapNode.id) {
                mapMarkersToKeep.add(mapMarkerIter);
            }
        }
        this.mapMarkers = mapMarkersToKeep;
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
