package de.adEditor;

public class MapMarker implements Comparable {

    public MapNode mapNode;
    public String name;
    public String group;

    public MapMarker (MapNode mapNode, String name, String group) {
        this.name = name;
        this.mapNode = mapNode;
        this.group = group;
    }


    @Override
    public int compareTo(Object o) {
        if (o instanceof MapMarker) {
            MapMarker other = (MapMarker) o;
            if (other.name.equals(name) && other.mapNode.id == mapNode.id) {
                return 0;
            }
        }

        return 1;
    }

    @Override
    public boolean equals(Object o) {

        // If the object is compared with itself then return true
        if (o == this) {
            return true;
        }

        if (o instanceof MapMarker) {
            MapMarker other = (MapMarker) o;
            if (other.name.equals(name) && other.mapNode.id == mapNode.id) {
                return true;
            }
        }

        return false;
    }

    @Override
    public int hashCode() {
        int result = 17;
        result = 31 * result + mapNode.id;
        return result;
    }
}
