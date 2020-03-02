package de.adEditor;

import java.awt.event.MouseEvent;
import java.awt.event.MouseMotionListener;
import java.awt.event.MouseWheelEvent;
import java.awt.event.MouseWheelListener;

public class MouseListener implements java.awt.event.MouseListener, MouseMotionListener, MouseWheelListener {

    private MapPanel mapPanel;

    public MouseListener(MapPanel mapPanel) {
        this.mapPanel = mapPanel;
    }

    @Override
    public void mouseClicked(MouseEvent e) {
        if (e.getButton() == MouseEvent.BUTTON1) {
            mapPanel.mouseButton1Clicked(e.getX(), e.getY());
        }
    }

    @Override
    public void mousePressed(MouseEvent e) {
        if (e.getButton() == MouseEvent.BUTTON1) {
            mapPanel.mouseButton1Pressed(e.getX(), e.getY());
        }
        if (e.getButton() == MouseEvent.BUTTON3) {
            mapPanel.mouseButton3Pressed(e.getX(), e.getY());
        }
    }

    @Override
    public void mouseReleased(MouseEvent e) {
        if (e.getButton() == MouseEvent.BUTTON1) {
            mapPanel.mouseButton1Released();
        }
        if (e.getButton() == MouseEvent.BUTTON3) {
            mapPanel.mouseButton3Released(e.getX(), e.getY());
        }
    }

    @Override
    public void mouseEntered(MouseEvent e) {
    }

    @Override
    public void mouseExited(MouseEvent e) {
    }

    @Override
    public void mouseDragged(MouseEvent e) {
        mapPanel.mouseDragged(e.getX(), e.getY());
    }

    @Override
    public void mouseMoved(MouseEvent e) {
        mapPanel.mouseMoved(e.getX(), e.getY());
    }

    @Override
    public void mouseWheelMoved(MouseWheelEvent e) {
        mapPanel.increaseZoomLevelBy(e.getWheelRotation());
    }
}
