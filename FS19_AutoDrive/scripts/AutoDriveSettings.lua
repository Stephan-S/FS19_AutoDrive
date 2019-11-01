AutoDrive.settings = {};

AutoDrive.settings.pipeOffset = {
    values= {-5.0, -4.75, -4.5, -4.25, -4.0, -3.75, -3.5, -3.25, -3.0, -2.75, -2.5, -2.25, -2.0, -1.75, -1.5, -1.25, -1.0, -0.75, -0.5, -0.25, 0,
    0.25, 0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0, 2.25, 2.5, 2.75, 3.0, 3.25, 3.5, 3.75, 4.0, 4.25, 4.5, 4.75, 5.0},
    texts= {"-5.0m", "-4.75m", "-4.5m", "-4.25m", "-4.0m", "-3.75m", "-3.5m", "-3.25m", "-3.0m", "-2.75m", "-2.5m", "-2.25m", "-2.0m", "-1.75m", "-1.5m",
    "-1.25m", "-1.0m", "-0.75m", "-0.5m", "-0.25m", "0 m",
    "0.25 m", "0.5 m", "0.75 m", "1.0 m", "1.25 m", "1.5 m", "1.75 m", "2.0 m", "2.25 m", "2.5 m", "2.75 m", "3.0 m", "3.25 m",
    "3.5 m", "3.75 m", "4.0 m", "4.25 m", "4.5 m", "4.75 m", "5.0 m"},
    default= 24,
    current= 24,
    text= "gui_ad_pipe_offset",
    tooltip= "gui_ad_pipe_offset",
    translate= false,
    isVehicleSpecific = true
};

AutoDrive.settings.trailerOffset = {  
    values= {-5.0, -4.75, -4.5, -4.25, -4.0, -3.75, -3.5, -3.25, -3.0, -2.75, -2.5, -2.25, -2.0, -1.75, -1.5, -1.25, -1.0, -0.75, -0.5, -0.25, 0,
     0.25, 0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0, 2.25, 2.5, 2.75, 3.0, 3.25, 3.5, 3.75, 4.0, 4.25, 4.5, 4.75, 5.0},
    texts= {"-5.0m", "-4.75m", "-4.5m", "-4.25m", "-4.0m", "-3.75m", "-3.5m", "-3.25m", "-3.0m", "-2.75m", "-2.5m", "-2.25m", "-2.0m", "-1.75m", "-1.5m",
     "-1.25m", "-1.0m", "-0.75m", "-0.5m", "-0.25m", "0 m",
     "0.25 m", "0.5 m", "0.75 m", "1.0 m", "1.25 m", "1.5 m", "1.75 m", "2.0 m", "2.25 m", "2.5 m", "2.75 m", "3.0 m", "3.25 m",
     "3.5 m", "3.75 m", "4.0 m", "4.25 m", "4.5 m", "4.75 m", "5.0 m"},
    default= 21,
    current= 21,
    text= "gui_ad_trailerOffset",
    tooltip= "gui_ad_trailerOffset_tooltip",
    translate= false,
    isVehicleSpecific = true
};

AutoDrive.settings.lookAheadTurning = {     
    values= {2, 3, 4, 5, 6, 7, 8},
    texts= {"2 m", "3 m", "4 m", "5 m", "6 m", "7 m", "8 m"},
    default= 4,
    current= 4,
    text= "gui_ad_lookahead_turning",
    tooltip= "gui_ad_lookahead_turning_tooltip",
    translate= false,
    isVehicleSpecific = false
};

AutoDrive.settings.lookAheadBraking = {   
    values= {5, 7.5, 10, 12.5, 15, 17.5, 20, 25, 30, 35, 40, 50, 60, 70, 80, 90, 100},
    texts= {"5m", "7.5m", "10m", "12.5m", "15m", "17.5m", "20m", "25m", "30m", "35m", "40m", "50m", "60m", "70m", "80m", "90m", "100m"},
    default= 7,
    current= 7,
    text= "gui_ad_lookahead_braking",
    tooltip= "gui_ad_lookahead_braking_tooltip",
    translate= false,
    isVehicleSpecific = false
};

AutoDrive.settings.useFastestRoute = {  
    values= {false, true},                                    
    texts= {"gui_ad_no", "gui_ad_yes"},                                    
    default= 1,                                    
    current= 1,                                    
    text= "gui_ad_useFastestRoute",                                    
    tooltip= "gui_ad_useFastestRoute_tooltip",
    translate= true,
    isVehicleSpecific = false
};

AutoDrive.settings.avoidMarkers = {  
    values= {false, true},                                    
    texts= {"gui_ad_no", "gui_ad_yes"},                                    
    default= 1,                                    
    current= 1,                                    
    text= "gui_ad_avoidMarkers",                                    
    tooltip= "gui_ad_avoidMarkers_tooltip",
    translate= true,
    isVehicleSpecific = false
};

AutoDrive.settings.mapMarkerDetour = {  
    values= {0, 10, 50, 100, 200, 300, 500, 1000, 10000},                                    
    texts= {"0m", "10m", "50m", "100m", "200m", "500m", "1000m", "10000m"},                                    
    default= 1,                                    
    current= 1,                                    
    text= "gui_ad_mapMarkerDetour",                                    
    tooltip= "gui_ad_mapMarkerDetour_tooltip",
    translate= false,
    isVehicleSpecific = false
};

AutoDrive.settings.continueOnEmptySilo = {  
    values= {false, true},                                    
    texts= {"gui_ad_wait", "gui_ad_drive"},                                    
    default= 1,                                    
    current= 1,                                    
    text= "gui_ad_siloEmpty",                                    
    tooltip= "gui_ad_siloEmpty_tooltip",
    translate= true,
    isVehicleSpecific = false
};

AutoDrive.settings.autoConnectStart = {  
    values= {false, true},                                    
    texts= {"gui_ad_no", "gui_ad_yes"},                                    
    default= 2,                                    
    current= 2,                                    
    text= "gui_ad_autoConnect_start",                                    
    tooltip= "gui_ad_autoConnect_start_tooltip",
    translate= true,
    isVehicleSpecific = false
};

AutoDrive.settings.autoConnectEnd = {  
    values= {false, true},                                    
    texts= {"gui_ad_no", "gui_ad_yes"},                                    
    default= 1,                                    
    current= 1,                                    
    text= "gui_ad_autoConnect_end",                                    
    tooltip= "gui_ad_autoConnect_end_tooltip",
    translate= true,
    isVehicleSpecific = false
};

AutoDrive.settings.parkInField = {  
    values= {false, true},                                    
    texts= {"gui_ad_no", "gui_ad_yes"},                                    
    default= 2,                                    
    current= 2,                                    
    text= "gui_ad_parkInField",                                    
    tooltip= "gui_ad_parkInField_tooltip",
    translate= true,
    isVehicleSpecific = true
};

AutoDrive.settings.unloadFillLevel = {  
    values= {0.0, 0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.85, 0.90, 0.95, 0.99, 1},                                    
    texts= {"0%", "10%", "20%", "30%", "40%", "50%", "60%", "70%", "80%", "85%", "90%", "95%", "99%", "100%"},                                    
    default= 10,                                    
    current= 10,                                    
    text= "gui_ad_unloadFillLevel",                                    
    tooltip= "gui_ad_unloadFillLevel_tooltip",
    translate= false,
    isVehicleSpecific = true
};

AutoDrive.settings.findDriver = {  
    values= {false, true},                                    
    texts= {"gui_ad_no", "gui_ad_yes"},                                    
    default= 2,                                    
    current= 2,                                    
    text= "gui_ad_findDriver",                                    
    tooltip= "gui_ad_findDriver_tooltip",
    translate= true,
    isVehicleSpecific = false
};

AutoDrive.settings.guiScale = {  
    values= {0, 1, 0.95, 0.9, 0.85, 0.8, 0.75, 0.7, 0.65, 0.6, 0.55, 0.5, 0.45, 0.4},
    texts= {"Default", "100%", "95%", "90%", "85%", "80%", "75%", "70%", "65%", "60%", "55%", "50%", "45%", "40%"},
    default= 1,
    current= 1,
    text= "gui_ad_gui_scale",
    tooltip= "gui_ad_gui_scale_tooltip",
    translate= false,
    isVehicleSpecific = false
};

AutoDrive.settings.exitField = {  
    values= {0, 1, 2},                                    
    texts= {"gui_ad_default", "gui_ad_after_start", "gui_ad_closest"},                                    
    default= 1,                                    
    current= 1,                                    
    text= "gui_ad_exitField",                                    
    tooltip= "gui_ad_exitField_tooltip",
    translate= true,
    isVehicleSpecific = false
};

AutoDrive.settings.showHelp = {  
    values= {false, true},                                    
    texts= {"gui_ad_no", "gui_ad_yes"},                                    
    default= 2,                                    
    current= 2,                                    
    text= "gui_ad_showHelp",                                    
    tooltip= "gui_ad_showHelp_tooltip",
    translate= true,
    isVehicleSpecific = false
};

AutoDrive.settings.driverWages = {  
    values= {0, 0.5, 1, 2.5, 5.0, 10.0},
    texts= {"0%", "50%", "100%", "250%", "500%", "1000%"},
    default= 3,
    current= 3,
    text= "gui_ad_driverWages",
    tooltip= "gui_ad_driverWages_tooltip",
    translate= false,
    isVehicleSpecific = false
};

AutoDrive.settings.smoothField = {  
    values= {false, true},                                    
    texts= {"gui_ad_no", "gui_ad_yes"},                                    
    default= 2,                                    
    current= 2,                                    
    text= "gui_ad_smoothField",                                    
    tooltip= "gui_ad_smoothField_tooltip",
    translate= true,
    isVehicleSpecific = false
};

AutoDrive.settings.recalculationSpeed = {  
    values= {0.5, 1, 1.5, 2, 5, 10, 25, 50, 100, 250, 500, 1000},                                    
    texts= {"x0.5", "x1", "x1.5", "x2", "x5", "x10", "x25", "x100", "x250", "x500", "x1000"},                                    
    default= 2,                                    
    current= 2,                                    
    text= "gui_ad_recalculationSpeed",                                    
    tooltip= "gui_ad_recalculationSpeed_tooltip",
    translate= false,
    isVehicleSpecific = false
};

AutoDrive.settings.showNextPath = {  
    values= {false, true},                                    
    texts= {"gui_ad_no", "gui_ad_yes"},                                    
    default= 2,                                    
    current= 2,                                             
    text= "gui_ad_showNextPath",                                    
    tooltip= "gui_ad_showNextPath_tooltip",
    translate= true,
    isVehicleSpecific = false
};

AutoDrive.settings.avoidFruit = {  
    values= {false, true},                                    
    texts= {"gui_ad_no", "gui_ad_yes"},                                    
    default= 2,                                    
    current= 2,                                             
    text= "gui_ad_avoidFruit",                                    
    tooltip= "gui_ad_avoidFruit_tooltip",
    translate= true,
    isVehicleSpecific = true
};

AutoDrive.settings.pathFinderTime = {  
    values= {0.25, 0.5, 1.0, 1.5, 2, 3},                                    
    texts= {"x0.25", "x0.5", "x1.0", "x1.5", "x2", "x3"},                                    
    default= 3,                                    
    current= 3,                                    
    text= "gui_ad_pathFinderTime",                                    
    tooltip= "gui_ad_pathFinderTime_tooltip",
    translate= false,
    isVehicleSpecific = false
};

AutoDrive.settings.lineHeight = {  
    values= {0, 4},                                    
    texts= {"gui_ad_ground", "gui_ad_aboveDriver"},                                    
    default= 1,                                    
    current= 1,                                    
    text= "gui_ad_lineHeight",                                    
    tooltip= "gui_ad_lineHeight_tooltip",
    translate= true,
    isVehicleSpecific = false
};

AutoDrive.settings.enableTrafficDetection = {  
    values= {false, true},                                    
    texts= {"gui_ad_no", "gui_ad_yes"},                                    
    default= 1,                                    
    current= 1,                                    
    text= "gui_ad_enableTrafficDetection",                                    
    tooltip= "gui_ad_enableTrafficDetection_tooltip",
    translate= true,
    isVehicleSpecific = false
};

AutoDrive.settings.refillSeedAndFertilizer = {  
    values= {false, true},                                    
    texts= {"gui_ad_no", "gui_ad_yes"},                                    
    default= 2,                                    
    current= 2,                                    
    text= "gui_ad_refillSeedAndFertilizer",                                    
    tooltip= "gui_ad_refillSeedAndFertilizer_tooltip",
    translate= true,
    isVehicleSpecific = false
};

AutoDrive.settings.shovelWidth = {  
    values= {0, 0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9, 1.0, 1.1, 1.2, 1.3, 1.4, 1.5, 1.6, 1.7, 1.8, 1.9, 2.0},                                    
    texts= {"0m", "0.1m", "0.2m", "0.3m", "0.4m", "0.5m", "0.6m", "0.7m", "0.8m", "0.9m", "1.0m", "1.1m", "1.2m", "1.3m", "1.4m", "1.5m", "1.6m", "1.7m", "1.8m", "1.9m", "2.0m"},                                    
    default= 1,                                    
    current= 1,                                    
    text= "gui_ad_shovelWidth",                                    
    tooltip= "gui_ad_shovelWidth_tooltip",
    translate= false,
    isVehicleSpecific = true
};

AutoDrive.settings.useFolders = {  
    values= {false, true},                                    
    texts= {"gui_ad_no", "gui_ad_yes"},                                    
    default= 1,                                    
    current= 1,                                    
    text= "gui_ad_useFolders",                                    
    tooltip= "gui_ad_useFolders_tooltip",
    translate= true,
    isVehicleSpecific = false
};

AutoDrive.settings.preCallDriver = {  
    values= {false, true},                                    
    texts= {"gui_ad_no", "gui_ad_yes"},                                    
    default= 1,                                    
    current= 1,                                    
    text= "gui_ad_preCallDriver",                                    
    tooltip= "gui_ad_preCallDriver_tooltip",
    translate= true,
    isVehicleSpecific = false
};

AutoDrive.settings.preCallLevel = {  
    values= {0, 0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.85, 0.90, 0.95},                                    
    texts= {"0%", "10%", "20%", "30%", "40%", "50%", "60%", "70%", "80%", "85%", "90%", "95%"},                                    
    default= 7,                                    
    current= 7,                                    
    text= "gui_ad_preCallLevel",                                    
    tooltip= "gui_ad_preCallLevel_tooltip",
    translate= false,
    isVehicleSpecific = false
};

AutoDrive.settings.chaseCombine = {  
    values= {false, true},                                    
    texts= {"gui_ad_no", "gui_ad_yes"},                                    
    default= 1,                                    
    current= 1,                                    
    text= "gui_ad_chaseCombine",                                    
    tooltip= "gui_ad_chaseCombine_tooltip",
    translate= true,
    isVehicleSpecific = false
};

AutoDrive.settings.distributeToFolder = {  
    values= {false, true},                                    
    texts= {"gui_ad_no", "gui_ad_yes"},                                    
    default= 1,                                    
    current= 1,                                    
    text= "gui_ad_distributeToFolder",                                    
    tooltip= "gui_ad_distributeToFolder_tooltip",
    translate= true,
    isVehicleSpecific = true
};

AutoDrive.settings.maxTriggerDistance = {     
    values= {10, 25, 50, 100, 200},
    texts= {"10 m", "25 m", "50 m", "100 m", "200 m"},
    default= 2,
    current= 2,
    text= "gui_ad_maxTriggerDistance",
    tooltip= "gui_ad_maxTriggerDistance_tooltip",
    translate= false,
    isVehicleSpecific = false
};

AutoDrive.settings.useBeaconLights = {  
    values= {false, true},                                    
    texts= {"gui_ad_no", "gui_ad_yes"},                                    
    default= 1,                                    
    current= 1,                                    
    text= "gui_ad_useBeaconLights",                                    
    tooltip= "gui_ad_useBeaconLights_tooltip",
    translate= true,
    isVehicleSpecific = false
};

AutoDrive.settings.restrictToField = {  
    values= {false, true},                                    
    texts= {"gui_ad_no", "gui_ad_yes"},                                    
    default= 2,                                    
    current= 2,                                    
    text= "gui_ad_restrictToField",                                    
    tooltip= "gui_ad_restrictToField_tooltip",
    translate= true,
    isVehicleSpecific = false
};

AutoDrive.settings.showTooltips = {  
    values= {false, true},                                    
    texts= {"gui_ad_no", "gui_ad_yes"},                                    
    default= 2,                                    
    current= 2,                                    
    text= "gui_ad_showTooltips",                                    
    tooltip= "gui_ad_showTooltips_tooltip",
    translate= true,
    isVehicleSpecific = false
};

function AutoDrive:getSetting(settingName, vehicle)
    if AutoDrive.settings[settingName] ~= nil then
        local setting = AutoDrive.settings[settingName]
        if setting.isVehicleSpecific and vehicle ~= nil and vehicle.ad.settings ~= nil then --try loading vehicle specific setting first, if available
            if vehicle.ad.settings[settingName] ~= nil then
                setting = vehicle.ad.settings[settingName];
            end;
        end;
        if setting.values[setting.current] == nil then
            setting.current = setting.default;
        end;
        return setting.values[setting.current];
    end;
end;

function AutoDrive:copySettingsToVehicle(vehicle)
    if vehicle.ad.settings == nil then
        vehicle.ad.settings = {};
    end;
    for settingName, setting in pairs(AutoDrive.settings) do
        if setting.isVehicleSpecific then
            local settingVehicle = {};
            settingVehicle.values = setting.values;
            settingVehicle.texts = setting.texts;
            settingVehicle.default = setting.default;
            settingVehicle.current = setting.current;
            settingVehicle.text = setting.text;
            settingVehicle.tooltip = setting.tooltip;
            settingVehicle.translate = setting.translate;
            vehicle.ad.settings[settingName] = settingVehicle;
        end;
    end;
end;

function AutoDrive:readVehicleSettingsFromXML(vehicle, xmlFile, key)
    vehicle.ad.settings = {}
    for settingName, setting in pairs(AutoDrive.settings) do
        if setting.isVehicleSpecific then
            local settingVehicle = {};
            settingVehicle.values = setting.values;
            settingVehicle.default = setting.default;
            settingVehicle.current = setting.current;
            vehicle.ad.settings[settingName] = settingVehicle;

            local storedSetting = getXMLInt(xmlFile, key.."#" .. settingName);
            if storedSetting ~= nil then
				vehicle.ad.settings[settingName].current = storedSetting;
			end;
        end;
    end;
end;