--
-- AutoDrive GUI
-- V1.0.0.0
--
-- @author Stephan Schlosser
-- @date 08/04/2019

adSettings = {};

local adSettings_mt = Class(adSettings, TabbedMenu);


adSettings.CONTROLS = {"autoDriveSettings", "autoDriveVehicleSettings", "autoDriveCombineUnloadSettings" }


function adSettings:new(target, custom_mt)
    local self = TabbedMenu:new(nil, adSettings_mt, g_messageCenter,  g_i18n, g_gui.inputManager);
    self.returnScreenName = "";
    self.settingElements = {};

    self:registerControls(adSettings.CONTROLS)

    self.activePageID = 1;
    return self;	
end;

function adSettings:onGuiSetupFinished()
    adSettings:superClass().onGuiSetupFinished(self)

    self:setupPages()
end

function adSettings:onClose()
    self:applySettings();
    adSettings:superClass().onClose(self);
end;

function adSettings:onOpen()
    adSettings:superClass().onOpen(self)

    self.inputDisableTime = 200
end

function adSettings:setupPages()
    local alwaysVisiblePredicate = self:makeIsAlwaysVisiblePredicate()

    local orderedPages = {
        { self.autoDriveSettings, alwaysVisiblePredicate, AutoDrive.directory .. "textures/GUI_Icons.dds", adSettings.TAB_UV.SETTINGS_GENERAL, "autoDriveSettings" },
        { self.autoDriveVehicleSettings, alwaysVisiblePredicate, g_baseUIFilename, adSettings.TAB_UV.SETTINGS_VEHICLE, "autoDriveVehicleSettings" },
        { self.autoDriveCombineUnloadSettings, alwaysVisiblePredicate, AutoDrive.directory .. "textures/GUI_Icons.dds", adSettings.TAB_UV.SETTINGS_UNLOAD, "autoDriveCombineUnloadSettings" },
    }

    for i, pageDef in ipairs(orderedPages) do
        local page, predicate, uiFilename, iconUVs, name = unpack(pageDef)
        self:registerPage(page, i, predicate)

        page.callBackParent = self;
        page.callBackParentWithID = i;

        local normalizedUVs = getNormalizedUVs(iconUVs)
        self:addPageTab(page, uiFilename, normalizedUVs) -- use the global here because the value changes with resolution settings
    end
end

function adSettings:makeIsAlwaysVisiblePredicate()
    return function()
        return true
    end
end

--- Page tab UV coordinates for display elements.
adSettings.TAB_UV = {
    SETTINGS_GENERAL = { 385, 0, 128, 128 },
    SETTINGS_VEHICLE = { 0, 209, 65, 65 },
    SETTINGS_UNLOAD = { 0, 0, 128, 128 },
    SETTINGS_LOAD = { 0, 129, 128, 128 },
    SETTINGS_NAVIGATION = { 0, 257, 128, 128 }
}

--- Define default properties and retrieval collections for menu buttons.
function adSettings:setupMenuButtonInfo()
    local onButtonBackFunction = self.clickBackCallback

    self.defaultMenuButtonInfo = {
        { inputAction = InputAction.MENU_BACK, text = self.l10n:getText("button_back"), callback = onButtonBackFunction, showWhenPaused = true },
        { inputAction = InputAction.MENU_ACCEPT, text = self.l10n:getText("button_ok"), callback = self:makeSelfCallback(self.onClickOK), showWhenPaused = true},
        { inputAction = InputAction.MENU_CANCEL, text = self.l10n:getText("button_reset"), callback = self:makeSelfCallback(self.onClickReset), showWhenPaused = true }
    }

    --self.defaultMenuButtonInfoByActions[InputAction.MENU_BACK] = self.defaultMenuButtonInfo[1]
    --self.defaultMenuButtonInfoByActions[InputAction.MENU_ACCEPT] = self.defaultMenuButtonInfo[2]
    --self.defaultMenuButtonInfoByActions[InputAction.MENU_CANCEL] = self.defaultMenuButtonInfo[3]

    --self.defaultButtonActionCallbacks = {
        --[InputAction.MENU_BACK] = onButtonBackFunction
        -- [InputAction.MENU_ACCEPT] = self.onClickOK,
        -- [InputAction.MENU_CANCEL] = self.onClickReset
    --}
end

function adSettings:onClickBack()    
    self:applySettings();
    adSettings:superClass().onClickBack(self);
end;

function adSettings:onClickOK()
    --adSettings:superClass().onClickOk(self);
    self:onClickBack();
end;

function adSettings:applySettings()
    local page = self:getActivePage()
    if page == nil then
        return;
    end;

    for settingName, settingElement in pairs(page.settingElements) do
        local value = settingElement:getState();
        if AutoDrive.settings[settingName] ~= nil then
            local setting = AutoDrive.settings[settingName];
            setting.current = value;
            if setting ~= nil and setting.isVehicleSpecific and g_currentMission.controlledVehicle ~= nil then
                setting = g_currentMission.controlledVehicle.ad.settings[settingName];
                setting.current = value;
            end;
        end;
    end;

    AutoDrive.Hud.lastUIScale = 0; 
    AutoDriveUpdateSettingsEvent:sendEvent();
end;

function adSettings:onClickReset()
    self:resetCurrentPageGUISettings();
end;

function adSettings:resetCurrentPageGUISettings() 
    local page = self:getActivePage()
    if page == nil then
        return;
    end;

    for settingName, settingElement in pairs(page.settingElements) do
        if AutoDrive.settings[settingName] ~= nil then
            local setting = AutoDrive.settings[settingName];
            if setting ~= nil and setting.isVehicleSpecific and g_currentMission.controlledVehicle ~= nil then
                setting = g_currentMission.controlledVehicle.ad.settings[settingName];
            end;
            
            page:updateGUISettings(settingName, setting.default);
        end;
    end;
end;

function adSettings:getActivePage()
    return self[adSettings.CONTROLS[self.activePageID]];
end;