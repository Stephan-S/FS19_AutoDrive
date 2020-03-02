package de.adEditor;

import java.util.LinkedList;

public class MapNode {

    public LinkedList<MapNode> incoming;
    public LinkedList<MapNode> outgoing;
    public double x, y, z;
    public int id;

    public MapNode(int id, double x, double y, double z) {
        this.id = id;
        this.x = x;
        this.y = y;
        this.z = z;
        this.incoming = new LinkedList<>();
        this.outgoing = new LinkedList<>();
    }



}
