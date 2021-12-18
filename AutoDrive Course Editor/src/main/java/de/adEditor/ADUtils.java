package de.adEditor;


import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import javax.imageio.ImageIO;
import javax.swing.*;
import javax.swing.filechooser.FileNameExtensionFilter;
import java.awt.*;
import java.awt.geom.Rectangle2D;
import java.awt.image.BufferedImage;
import java.io.*;
import java.net.MalformedURLException;
import java.net.URISyntaxException;
import java.net.URL;
import java.net.URLClassLoader;
import java.nio.file.Paths;
import java.util.Locale;
import java.util.ResourceBundle;

import de.adEditor.MapHelpers.DDSReader;
import static de.adEditor.AutoDriveEditor.localeString;
import static de.adEditor.GUIBuilder.bDebugFileIO;
import static de.adEditor.MapPanel.isUsingConvertedImage;

public class ADUtils {

    public static Logger LOG = LoggerFactory.getLogger(AutoDriveEditor.class);
    public static long profiletimer = 0;
    public static long totalTime = 0;

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
        double xPI = (2*Math.PI);
        if (input > xPI) {
            input -= xPI;
        }
        else {
            if (input < -xPI ) {
                input += xPI;
            }
        }

        return input;
    }

    public static File getSelectedFileWithExtension(JFileChooser c) {
        File file = c.getSelectedFile();
        if (c.getFileFilter() instanceof FileNameExtensionFilter) {
            String[] extension = ((FileNameExtensionFilter)c.getFileFilter()).getExtensions();
            String nameLower = file.getName().toLowerCase();
            for (String ext : extension) { // check if it already has a valid extension
                if (nameLower.endsWith('.' + ext.toLowerCase())) {
                    return file; // if yes, return as-is
                }
            }
            // if not, append the first extension from the selected filter
            file = new File(file.toString() + '.' + extension[0]);
        }
        return file;
    }

    public static BufferedImage getImage(String name) {
        try {
            URL url = AutoDriveEditor.class.getResource("/editor/" + name);
            if (url != null) {
                BufferedImage file = ImageIO.read(url);
                GraphicsEnvironment ge = GraphicsEnvironment.getLocalGraphicsEnvironment();
                GraphicsDevice gd = ge.getDefaultScreenDevice();
                GraphicsConfiguration gc = gd.getDefaultConfiguration();
                BufferedImage image = gc.createCompatibleImage(file.getWidth(), file.getHeight(), Transparency.BITMASK);
                Graphics2D g = (Graphics2D) image.getGraphics();
                g.setRenderingHint(RenderingHints.KEY_ANTIALIASING, RenderingHints.VALUE_ANTIALIAS_OFF);
                g.setRenderingHint(RenderingHints.KEY_ALPHA_INTERPOLATION, RenderingHints.VALUE_ALPHA_INTERPOLATION_SPEED);
                g.setRenderingHint(RenderingHints.KEY_COLOR_RENDERING, RenderingHints.VALUE_COLOR_RENDER_SPEED);
                g.setRenderingHint(RenderingHints.KEY_DITHERING, RenderingHints.VALUE_DITHER_DISABLE);
                g.setRenderingHint(RenderingHints.KEY_FRACTIONALMETRICS, RenderingHints.VALUE_FRACTIONALMETRICS_OFF);
                g.setRenderingHint(RenderingHints.KEY_INTERPOLATION, RenderingHints.VALUE_INTERPOLATION_NEAREST_NEIGHBOR);
                g.setRenderingHint(RenderingHints.KEY_RENDERING, RenderingHints.VALUE_RENDER_SPEED);
                g.setRenderingHint(RenderingHints.KEY_STROKE_CONTROL, RenderingHints.VALUE_STROKE_PURE);
                g.setRenderingHint(RenderingHints.KEY_TEXT_ANTIALIASING, RenderingHints.VALUE_TEXT_ANTIALIAS_OFF);
                g.drawImage(file,0,0,null);
                //g.dispose();
                return image;
            }
        } catch (IOException e) {
            LOG.error(e.getMessage(), e);
        }
        return null;
    }

    public static ImageIcon getIcon(String name) {
        try {
            URL url = AutoDriveEditor.class.getResource("/editor/" + name);
            if (url != null) {
                BufferedImage newImage = ImageIO.read(url);
                return new ImageIcon(newImage);
            }
        } catch (IOException e) {
            LOG.error(e.getMessage(), e);
        }
        return null;
    }

    public static ResourceBundle getLocale(){

        String localePath;
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
            }

            localePath = "./src/locale/AutoDriveEditor_" + Locale.getDefault() + ".properties";
            if (Paths.get(localePath).toFile().exists()) {
                classPath = "./src/locale/";
            }

            localePath = "./AutoDriveEditor_" + Locale.getDefault() + ".properties";
            if (Paths.get(localePath).toFile().exists()) {
                classPath = "./";
            }

            localePath = "./src/main/resources/locale/AutoDriveEditor_" + Locale.getDefault() + ".properties";
            if (Paths.get(localePath).toFile().exists()) {
                classPath = "./src/main/resources/locale/";
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
                return ResourceBundle.getBundle("locale.AutoDriveEditor", new Locale("en", "US"));
            }
        }
    }

    public static File copyURLToFile(URL url, File file) {

        try {
            InputStream input = url.openStream();
            if (file.exists()) {
                if (file.isDirectory())
                    throw new IOException("File '" + file + "' is a directory");

                if (!file.canWrite())
                    throw new IOException("File '" + file + "' cannot be written");
            } else {
                File parent = file.getParentFile();
                if ((parent != null) && (!parent.exists()) && (!parent.mkdirs())) {
                    throw new IOException("File '" + file + "' could not be created");
                }
            }

            FileOutputStream output = new FileOutputStream(file);

            byte[] buffer = new byte[4096];
            int n = 0;
            while (-1 != (n = input.read(buffer))) {
                output.write(buffer, 0, n);
            }

            input.close();
            output.close();

            LOG.info("File '{}' downloaded successfully!", file);
            return file;
        }
        catch(IOException ioEx) {
            ioEx.printStackTrace();
            return null;
        }
    }

    public static String getCurrentLocation() {

        //
        // only works with JDK 11 and above
        //

        try {
            String launchPath;
            String jarPath = AutoDriveEditor.class
                    .getProtectionDomain()
                    .getCodeSource()
                    .getLocation()
                    .toURI()
                    .getPath();
            if (bDebugFileIO) LOG.info("JAR Path : {}", jarPath);
            launchPath = jarPath.substring(0, jarPath.lastIndexOf("/") + 1);
            if (bDebugFileIO) LOG.info("Path : " + launchPath);
            return launchPath;
        } catch (URISyntaxException uriSyntaxException) {
            uriSyntaxException.printStackTrace();
        }
        return null;
    }

    public static void startTimer() { profiletimer = System.currentTimeMillis(); }

    public static long stopTimer() { return System.currentTimeMillis() - profiletimer; }

    public static Boolean importFromFS19(String filename) {

        try {
            createDDSBufferImage(filename, 0 , 0);
        } catch (IOException e) {
            e.printStackTrace();
            return false;
        }

        isUsingConvertedImage = true;
        GUIBuilder.saveImageEnabled(true);
        return true;
    }

    public static Boolean importFromFS22(String filename) {

        try {
            createDDSBufferImage(filename, 1024, 1024);
        } catch (IOException e) {
            e.printStackTrace();
            return false;
        }
        isUsingConvertedImage = true;
        GUIBuilder.saveImageEnabled(true);
        return true;
    }

    public static void createDDSBufferImage(String filename, int offsetX, int offsetY) throws IOException {
        LOG.info("Creating Bufferimage from {}", filename );

        // load the DDS file into a buffer
        FileInputStream fis = new FileInputStream(filename);
        byte [] buffer = new byte[fis.available()];
        fis.read(buffer);
        fis.close();

        // convert the DDS file in buffer to an BufferImage
        int [] pixels = DDSReader.read(buffer, DDSReader.ARGB, 0);
        int width = DDSReader.getWidth(buffer);
        int height = DDSReader.getHeight(buffer);
        BufferedImage image = new BufferedImage(width, height, BufferedImage.TYPE_INT_ARGB);
        image.setRGB(0, 0, width, height, pixels, 0, width);
        LOG.info(" {} , {}", image.getWidth(), image.getHeight());

        // Scale the BufferImage to a size the editor can use ( 2048 x 2048 )

        GraphicsEnvironment ge = GraphicsEnvironment.getLocalGraphicsEnvironment();
        GraphicsDevice gd = ge.getDefaultScreenDevice();
        GraphicsConfiguration gc = gd.getDefaultConfiguration();

        BufferedImage scaledImage = gc.createCompatibleImage( 2048, 2048, Transparency.OPAQUE);
        Graphics2D g = (Graphics2D) scaledImage.getGraphics();
        g.setRenderingHint(RenderingHints.KEY_ANTIALIASING, RenderingHints.VALUE_ANTIALIAS_ON);
        g.setRenderingHint(RenderingHints.KEY_ALPHA_INTERPOLATION, RenderingHints.VALUE_ALPHA_INTERPOLATION_SPEED);
        g.setRenderingHint(RenderingHints.KEY_COLOR_RENDERING, RenderingHints.VALUE_COLOR_RENDER_QUALITY);
        g.setRenderingHint(RenderingHints.KEY_DITHERING, RenderingHints.VALUE_DITHER_ENABLE);
        g.setRenderingHint(RenderingHints.KEY_FRACTIONALMETRICS, RenderingHints.VALUE_FRACTIONALMETRICS_ON);
        g.setRenderingHint(RenderingHints.KEY_INTERPOLATION, RenderingHints.VALUE_INTERPOLATION_BILINEAR);
        g.setRenderingHint(RenderingHints.KEY_RENDERING, RenderingHints.VALUE_RENDER_QUALITY);
        g.setRenderingHint(RenderingHints.KEY_STROKE_CONTROL, RenderingHints.VALUE_STROKE_DEFAULT);
        g.setRenderingHint(RenderingHints.KEY_TEXT_ANTIALIASING, RenderingHints.VALUE_TEXT_ANTIALIAS_DEFAULT);
        g.setRenderingHint(RenderingHints.KEY_RESOLUTION_VARIANT, RenderingHints.VALUE_RESOLUTION_VARIANT_SIZE_FIT);
        if (offsetX != 0 || offsetY != 0) {
            BufferedImage crop = image.getSubimage(offsetX, offsetY, 2048, 2048);
            g.drawImage( crop, 0, 0, 2048, 2048, null);
        } else {
            g.drawImage( image, 0, 0, 2048, 2048, null);
        }
        g.dispose();

        // set the converted and resized image as the map image


        MapPanel.getMapPanel().setImage(scaledImage);
        MapPanel.forceMapImageRedraw();
        MapPanel.isUsingConvertedImage = true;
    }

    public static void saveMapImage(String filePath) {
        try {
            //String location = getCurrentLocation();
            //String path = location + "mapImages/" + fileName + ".png";
            File outputFile = new File(filePath);

            if (outputFile.exists()) {
                if (outputFile.isDirectory())
                    throw new IOException("File '" + outputFile + "' is a directory");

                if (!outputFile.canWrite())
                    throw new IOException("File '" + outputFile + "' cannot be written");
            } else {
                File parent = outputFile.getParentFile();
                if ((parent != null) && (!parent.exists()) && (!parent.mkdirs())) {
                    throw new IOException("File '" + outputFile + "' could not be created");
                }
            }
            ImageIO.write(MapPanel.getMapPanel().getImage(), "png", outputFile);
            LOG.info("{} {}", localeString.getString("console_map_saveimage_done"), outputFile.getAbsolutePath());
        } catch (IOException e) {
            e.printStackTrace();
        }

    }
}
