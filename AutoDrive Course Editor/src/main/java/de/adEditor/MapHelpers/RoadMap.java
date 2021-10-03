package de.adEditor.MapHelpers;

import java.util.LinkedList;

public class RoadMap {

    public LinkedList<MapNode> mapNodes;
    public static LinkedList<MapMarker> mapMarkers;

    public RoadMap () {
        mapMarkers = new LinkedList<>();
        this.mapNodes = new LinkedList<>();
    }

    public void addMapMarker(MapMarker mapMarker) {
        mapMarkers.add(mapMarker);
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
