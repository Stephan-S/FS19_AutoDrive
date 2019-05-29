AutoDrive.settings = {};

AutoDrive.settings.pipeOffset = {  
    values= {0, 0.25, 0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0, 2.25, 2.5, 2.75, 3.0, 3.25, 3.5, 3.75, 4.0, 4.25, 4.5, 4.75, 5.0},
    texts= {"0 m", "0.25 m", "0.5 m", "0.75 m", "1.0 m", "1.25 m", "1.5 m", "1.75 m", "2.0 m", "2.25 m", "2.5 m", "2.75 m", "3.0 m", "3.25 m", "3.5 m", "3.75 m", "4.0 m", "4.25 m", "4.5 m", "4.75 m", "5.0 m"},
    default= 4,
    current= 4,
    text= "gui_ad_pipe_offset",
    tooltip= "gui_ad_pipe_offset",
    translate= false
};

AutoDrive.settings.lookAheadTurning = {     
    values= {2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15},
    texts= {"2 m", "3 m", "4 m", "5 m", "6 m", "7 m", "8 m", "9 m", "10 m", "11 m", "12 m", "13 m", "14 m", "15 m"},
    default= 4,
    current= 4,
    text= "gui_ad_lookahead_turning",
    tooltip= "gui_ad_lookahead_turning_tooltip",
    translate= false
};

AutoDrive.settings.lookAheadBraking = {   
    values= {5, 7.5, 10, 12.5, 15, 17.5, 20, 25, 30, 35, 40, 50, 60, 70, 80, 90, 100},
    texts= {"5m", "7.5m", "10m", "12.5m", "15m", "17.5m", "20m", "25m", "30m", "35m", "40m", "50m", "60m", "70m", "80m", "90m", "100m"},
    default= 7,
    current= 7,
    text= "gui_ad_lookahead_braking",
    tooltip= "gui_ad_lookahead_braking_tooltip",
    translate= false
};

AutoDrive.settings.useFastestRoute = {  
    values= {false, true},                                    
    texts= {"gui_ad_no", "gui_ad_yes"},                                    
    default= 1,                                    
    current= 1,                                    
    text= "gui_ad_useFastestRoute",                                    
    tooltip= "gui_ad_useFastestRoute_tooltip",
    translate= true
};

AutoDrive.settings.avoidMarkers = {  
    values= {false, true},                                    
    texts= {"gui_ad_no", "gui_ad_yes"},                                    
    default= 1,                                    
    current= 1,                                    
    text= "gui_ad_avoidMarkers",                                    
    tooltip= "gui_ad_avoidMarkers_tooltip",
    translate= true
};

AutoDrive.settings.mapMarkerDetour = {  
    values= {0, 10, 50, 100, 200, 300, 500, 1000, 10000},                                    
    texts= {"0m", "10m", "50m", "100m", "200m", "500m", "1000m", "10000m"},                                    
    default= 1,                                    
    current= 1,                                    
    text= "gui_ad_mapMarkerDetour",                                    
    tooltip= "gui_ad_mapMarkerDetour_tooltip",
    translate= false
};

AutoDrive.settings.continueOnEmptySilo = {  
    values= {false, true},                                    
    texts= {"gui_ad_wait", "gui_ad_drive"},                                    
    default= 1,                                    
    current= 1,                                    
    text= "gui_ad_siloEmpty",                                    
    tooltip= "gui_ad_siloEmpty_tooltip",
    translate= true
};

AutoDrive.settings.autoConnectStart = {  
    values= {false, true},                                    
    texts= {"gui_ad_no", "gui_ad_yes"},                                    
    default= 2,                                    
    current= 2,                                    
    text= "gui_ad_autoConnect_start",                                    
    tooltip= "gui_ad_autoConnect_start_tooltip",
    translate= true
};

AutoDrive.settings.autoConnectEnd = {  
    values= {false, true},                                    
    texts= {"gui_ad_no", "gui_ad_yes"},                                    
    default= 1,                                    
    current= 1,                                    
    text= "gui_ad_autoConnect_end",                                    
    tooltip= "gui_ad_autoConnect_end_tooltip",
    translate= true
};

AutoDrive.settings.parkInField = {  
    values= {false, true},                                    
    texts= {"gui_ad_no", "gui_ad_yes"},                                    
    default= 2,                                    
    current= 2,                                    
    text= "gui_ad_parkInField",                                    
    tooltip= "gui_ad_parkInField_tooltip",
    translate= true
};

AutoDrive.settings.unloadFillLevel = {  
    values= {0.5, 0.6, 0.7, 0.8, 0.85, 0.90, 0.95, 0.99, 1},                                    
    texts= {"50%", "60%", "70%", "80%", "85%", "90%", "95%", "99%", "100%"},                                    
    default= 5,                                    
    current= 5,                                    
    text= "gui_ad_unloadFillLevel",                                    
    tooltip= "gui_ad_unloadFillLevel_tooltip",
    translate= false
};

AutoDrive.settings.findDriver = {  
    values= {false, true},                                    
    texts= {"gui_ad_no", "gui_ad_yes"},                                    
    default= 2,                                    
    current= 2,                                    
    text= "gui_ad_findDriver",                                    
    tooltip= "gui_ad_findDriver_tooltip",
    translate= true
};

AutoDrive.settings.guiScale = {  
    values= {0, 1, 0.95, 0.9, 0.85, 0.8, 0.75, 0.7, 0.65, 0.6, 0.55, 0.5, 0.45, 0.4},
    texts= {"Default", "100%", "95%", "90%", "85%", "80%", "75%", "70%", "65%", "60%", "55%", "50%", "45%", "40%"},
    default= 1,
    current= 1,
    text= "gui_ad_gui_scale",
    tooltip= "gui_ad_gui_scale_tooltip",
    translate= false
};

AutoDrive.settings.exitField = {  
    values= {0, 1, 2},                                    
    texts= {"gui_ad_default", "gui_ad_after_start", "gui_ad_closest"},                                    
    default= 1,                                    
    current= 1,                                    
    text= "gui_ad_exitField",                                    
    tooltip= "gui_ad_exitField_tooltip",
    translate= true
};

AutoDrive.settings.showHelp = {  
    values= {false, true},                                    
    texts= {"gui_ad_no", "gui_ad_yes"},                                    
    default= 2,                                    
    current= 2,                                    
    text= "gui_ad_showHelp",                                    
    tooltip= "gui_ad_showHelp_tooltip",
    translate= true
};

AutoDrive.settings.driverWages = {  
    values= {0, 0.5, 1, 2.5, 5.0, 10.0},
    texts= {"0%", "50%", "100%", "250%", "500%", "1000%"},
    default= 3,
    current= 3,
    text= "gui_ad_driverWages",
    tooltip= "gui_ad_driverWages_tooltip",
    translate= false
};

function AutoDrive:getSetting(settingName)
    if AutoDrive.settings[settingName] ~= nil then
        local setting = AutoDrive.settings[settingName]
        return setting.values[setting.current];
    end;
end;