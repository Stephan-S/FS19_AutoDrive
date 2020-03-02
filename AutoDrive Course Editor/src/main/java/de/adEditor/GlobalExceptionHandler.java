package de.adEditor;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

class GlobalExceptionHandler implements Thread.UncaughtExceptionHandler {

    private static Logger LOGGER = LoggerFactory.getLogger(GlobalExceptionHandler.class);

    public void uncaughtException(Thread t, Throwable e) {
        LOGGER.info(e.getMessage(), e);
    }
}
