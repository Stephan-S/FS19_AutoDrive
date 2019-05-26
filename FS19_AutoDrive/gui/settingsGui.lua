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
    for settingName, setting in pairs(AutoDrive.settings) do
        AutoDrive.gui.adSettingsGui:updateGUISettings(settingName, setting.current);
    end;
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
    end;
    AutoDriveUpdateSettingsEvent:sendEvent();
    self:onClickBack();
end;

function adSettingsGui:onClickResetButton()
    for settingName, setting in AutoDrive.settings do
        AutoDrive.gui.adSettingsGui:updateGUISettings(settingName, setting.default);
    end;
end;

function AutoDrive:guiClosed()
	for settingName, setting in pairs(AutoDrive.settings) do
        AutoDrive.gui.adSettingsGui:updateGUISettings(settingName, setting.current);
    end;
end;

function adSettingsGui:onIngameMenuHelpTextChanged(element)
end;

function adSettingsGui:onCreateadSettingsGuiHeader(element)
	element.text = g_i18n:getText('gui_ad_Setting');
end;

function adSettingsGui:onCreateAutoDriveSetting(element, settingName)    
    self.settingElements[settingName] = element;
    local setting = AutoDrive.settings[settingName];
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

function adSettingsGui:updateGUISettings(settingName, index)
    self.settingElements[settingName]:setState(index, false);
end;

function adSettingsGui:onCreateAutoDriveSettingPipeOffset(element)
    self:onCreateAutoDriveSetting(element, "pipeOffset");
end;

function adSettingsGui:onCreateAutoDriveSettingLookAheadTurning(element)
    self:onCreateAutoDriveSetting(element, "lookAheadTurning");
end;

function adSettingsGui:onCreateAutoDriveSettingLookAheadBraking(element)
    self:onCreateAutoDriveSetting(element, "lookAheadBraking");
end;

function adSettingsGui:onCreateAutoDriveSettingUseFastestRoute(element)
    self:onCreateAutoDriveSetting(element, "useFastestRoute");
end;

function adSettingsGui:onCreateAutoDriveSettingAvoidMarkers(element)
    self:onCreateAutoDriveSetting(element, "avoidMarkers");
end;

function adSettingsGui:onCreateAutoDriveSettingMapMarkerDetour(element)
    self:onCreateAutoDriveSetting(element, "mapMarkerDetour");
end;

function adSettingsGui:onCreateAutoDriveSettingContinueOnEmptySilo(element)
    self:onCreateAutoDriveSetting(element, "continueOnEmptySilo");
end;

function adSettingsGui:onCreateAutoDriveSettingAutoConnectStart(element)
    self:onCreateAutoDriveSetting(element, "autoConnectStart");
end;

function adSettingsGui:onCreateAutoDriveSettingAutoConnectEnd(element)
    self:onCreateAutoDriveSetting(element, "autoConnectEnd");
end;

function adSettingsGui:onCreateAutoDriveSettingUnloadFillLevel(element)
    self:onCreateAutoDriveSetting(element, "unloadFillLevel");
end;

function adSettingsGui:onCreateAutoDriveSettingParkInField(element)
    self:onCreateAutoDriveSetting(element, "parkInField");
end;

function adSettingsGui:onCreateAutoDriveSettingFindDriver(element)
    self:onCreateAutoDriveSetting(element, "findDriver");
end;

function adSettingsGui:onCreateAutoDriveSettingGUIScale(element)
    self:onCreateAutoDriveSetting(element, "guiScale");
end;