--
-- AutoDrive GUI
-- V1.0.0.0
--
-- @author Stephan Schlosser
-- @date 08/04/2019

adSettingsGui = {};

local adSettingsGui_mt = Class(adSettingsGui, ScreenElement);

function adSettingsGui:new(target, custom_mt)
    local self = ScreenElement:new(target, adSettingsGui_mt);
    self.returnScreenName = "";
    self.settingElements = {};
    return self;	
end;

function adSettingsGui:onOpen()
    adSettingsGui:superClass().onOpen(self);
    FocusManager:setFocus(self.backButton);
    adSettingsGui:updateAllGUISettings();
end;

function adSettingsGui:onClose()
    adSettingsGui:superClass().onClose(self);
end;

function adSettingsGui:onClickBack()
    adSettingsGui:superClass().onClickBack(self);
	AutoDrive:guiClosed();
end;

function adSettingsGui:onClickOk()
    adSettingsGui:superClass().onClickOk(self);
    for settingName, setting in pairs(AutoDrive.settings) do
        setting.current = self.settingElements[settingName]:getState();
        if setting.isVehicleSpecific and g_currentMission.controlledVehicle ~= nil then
            g_currentMission.controlledVehicle.ad.settings[settingName].current = self.settingElements[settingName]:getState();
        end;
    end;
    AutoDriveUpdateSettingsEvent:sendEvent();
    self:onClickBack();
end;

function adSettingsGui:onClickResetButton()
    adSettingsGui:resetAllGUISettings(); 
end;

function AutoDrive:guiClosed()
    adSettingsGui:updateAllGUISettings();   
end;

function adSettingsGui:onIngameMenuHelpTextChanged(element)
end;

function adSettingsGui:onCreateadSettingsGuiHeader(element)
	element.text = g_i18n:getText('gui_ad_Setting');
end;

function adSettingsGui:onCreateAutoDriveSetting(element)     
    self.settingElements[element.name] = element;
    local setting = AutoDrive.settings[element.name];
	element.labelElement.text = g_i18n:getText(setting.text);
	element.toolTipText = g_i18n:getText(setting.tooltip);

    local labels = {};
    for i = 1, #setting.texts, 1 do
        if setting.translate == true then
            labels[i] = g_i18n:getText(setting.texts[i]);
        else 
            labels[i] = setting.texts[i];
        end;
    end;	
    element:setTexts(labels);
end;

function adSettingsGui:updateAllGUISettings()
    for settingName, setting in pairs(AutoDrive.settings) do
        local value = setting.current;
        if setting.isVehicleSpecific and g_currentMission.controlledVehicle ~= nil then
            value = g_currentMission.controlledVehicle.ad.settings[settingName].current;
        end;            
        AutoDrive.gui.adSettingsGui:updateGUISettings(settingName, value);
    end;
end;

function adSettingsGui:resetAllGUISettings()
    for settingName, setting in pairs(AutoDrive.settings) do
        local value = setting.default;
        if setting.isVehicleSpecific and g_currentMission.controlledVehicle ~= nil then
            value = g_currentMission.controlledVehicle.ad.settings[settingName].default;
        end;            
        AutoDrive.gui.adSettingsGui:updateGUISettings(settingName, value);
    end;
end;

function adSettingsGui:updateGUISettings(settingName, index)
    self.settingElements[settingName]:setState(index, false);
end;