package de.adEditor;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import javax.imageio.ImageIO;
import javax.swing.*;
import javax.swing.filechooser.FileNameExtensionFilter;
import java.awt.geom.Point2D;
import java.awt.geom.Rectangle2D;
import java.awt.image.BufferedImage;
import java.io.File;
import java.io.FileInputStream;
import java.io.IOException;
import java.net.MalformedURLException;
import java.net.URL;
import java.net.URLClassLoader;
import java.nio.file.Files;
import java.nio.file.Paths;
import java.util.Locale;
import java.util.ResourceBundle;

import static de.adEditor.AutoDriveEditor.localeString;
import static java.util.Locale.getDefault;

public class ADUtils {

    public static Logger LOG = LoggerFactory.getLogger(AutoDriveEditor.class);

    public static Rectangle2D getNormalizedRectangleFor(double x, double y, double width, double height) {
        if (width < 0) {
            x = x + width;
            width = -width;
        }
        if (height < 0) {
            y = y + height;
            height = -height;
        }
        return new Rectangle2D.Double(x,y,width,height);
    }

    public static double normalizeAngle(double input) {
        if (input > (2*Math.PI)) {
            input = input - (2*Math.PI);
        }
        else {
            if (input < -(2*Math.PI)) {
                input = input + (2*Math.PI);
            }
        }

        return input;
    }

    public static File getSelectedFileWithExtension(JFileChooser c) {
        File file = c.getSelectedFile();
        if (c.getFileFilter() instanceof FileNameExtensionFilter) {
            String[] exts = ((FileNameExtensionFilter)c.getFileFilter()).getExtensions();
            String nameLower = file.getName().toLowerCase();
            for (String ext : exts) { // check if it already has a valid extension
                if (nameLower.endsWith('.' + ext.toLowerCase())) {
                    return file; // if yes, return as-is
                }
            }
            // if not, append the first extension from the selected filter
            file = new File(file.toString() + '.' + exts[0]);
        }
        return file;
    }

    public static BufferedImage getIcon(String name) {
        try {
            URL url = AutoDriveEditor.class.getResource("/" + name);
            if (url != null) {
                return ImageIO.read(url);
            }
        } catch (IOException e) {
            LOG.error(e.getMessage(), e);
        }
        return null;
    }

    public static ResourceBundle getLocale(){

        String localePath = null;
        String localeName = null;
        String classPath = null;
        File newFile;
        URL url;

        try {

            ResourceBundle bundle = ResourceBundle.getBundle("locale.AutoDriveEditor", Locale.getDefault());
            LOG.info("'AutoDriveEditor_{}.properties' loaded", Locale.getDefault());
            return bundle;
        } catch (Exception e) {
            LOG.info("'AutoDriveEditor_{}.properties' not found. looking in folders", Locale.getDefault());
            localePath = "./locale/AutoDriveEditor_" + Locale.getDefault() + ".properties";
            if (Paths.get(localePath).toFile().exists()) {
                classPath = "./locale/";
                //LOG.info("Found locale file {}", localePath);
            }

            localePath = "./src/locale/AutoDriveEditor_" + Locale.getDefault() + ".properties";
            if (Paths.get(localePath).toFile().exists()) {
                classPath = "./src/locale/";
                //LOG.info("Found locale file {}", localePath);
            }

            localePath = "./AutoDriveEditor_" + Locale.getDefault() + ".properties";
            if (Paths.get(localePath).toFile().exists()) {
                classPath = "./";
                //LOG.info("Found locale file {}", localePath);
            }

            localePath = "./src/main/resources/locale/AutoDriveEditor_" + Locale.getDefault() + ".properties";
            if (Paths.get(localePath).toFile().exists()) {
                classPath = "./src/main/resources/locale/";
                //LOG.info("Found locale file {}", localePath);
            }

            if (classPath != null) {
                File file = new File(classPath);
                URL[] urls = new URL[0];
                try {
                    urls = new URL[]{file.toURI().toURL()};
                } catch (MalformedURLException ex) {
                    ex.printStackTrace();
                }
                ClassLoader loader = new URLClassLoader(urls);
                ResourceBundle bundle = ResourceBundle.getBundle("AutoDriveEditor", Locale.getDefault(), loader);
                LOG.info("loading external locale File for {}", Locale.getDefault());
                return bundle;
            } else {
                LOG.info("Locale file not found..loading default locale for {}", new Locale("en", "US"));
                ResourceBundle bundle = ResourceBundle.getBundle("locale.AutoDriveEditor", new Locale("en", "US"));
                return bundle;
            }
        }
    }
}
