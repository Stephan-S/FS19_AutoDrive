--
-- AutoDrive GUI
-- V1.0.0.0
--
-- @author Stephan Schlosser
-- @date 08/04/2019

ADSettings = {}

local ADSettings_mt = Class(ADSettings, TabbedMenu)

ADSettings.CONTROLS = {"autoDriveSettings", "autoDriveUserSettings", "autoDriveVehicleSettings", "autoDriveCombineUnloadSettings", "autoDriveDebugSettings", "autoDriveExperimentalFeaturesSettings", "autoDriveEnvironmentSettings"}

--- Page tab UV coordinates for display elements.
ADSettings.TAB_UV = {
    SETTINGS_GENERAL = {385, 0, 128, 128},
    SETTINGS_VEHICLE = {0, 209, 65, 65},
    SETTINGS_USER = {457, 210, 60, 60},
    SETTINGS_UNLOAD = {0, 0, 128, 128},
    SETTINGS_LOAD = {0, 129, 128, 128},
    SETTINGS_NAVIGATION = {0, 257, 128, 128},
    SETTINGS_DEBUG = {0, 128, 128, 128},
    SETTINGS_EXPFEAT = {128, 128, 128, 128},
    SETTINGS_ENVIRONMENT = {65, 144, 65, 65}
}

ADSettings.ICON_UV = {
    GLOBAL = {12, 157, 40, 40},
    VEHICLE = {136, 151, 51, 51},
    USER = {462, 215, 50, 50}
}

ADSettings.ICON_COLOR = {
    DEFAULT = {1, 1, 1, 1},
    CHANGED = {0.9910, 0.3865, 0.0100, 1}
}

function ADSettings:new()
    local o = TabbedMenu:new(nil, ADSettings_mt, g_messageCenter, g_i18n, g_gui.inputManager)
    o.returnScreenName = ""
    o:registerControls(ADSettings.CONTROLS)
    return o
end

function ADSettings:onGuiSetupFinished()
    ADSettings:superClass().onGuiSetupFinished(self)
    self:setupPages()
end

function ADSettings:setupPages()
    local alwaysEnabled = function()
        return true
    end

    local developmentControlsEnabled = function()
        return AutoDrive.developmentControls
    end

    local vehicleEnabled = function()
        if g_currentMission ~= nil and g_currentMission.controlledVehicle ~= nil and g_currentMission.controlledVehicle.ad ~= nil then
            return true
        end
        return false
    end

    local combineEnabled = function()
        if vehicleEnabled() and g_currentMission.controlledVehicle.ad.isCombine then
            return true
        end
        return false
    end

    local orderedPages = {
        {self.autoDriveSettings, alwaysEnabled, g_autoDriveUIFilename, ADSettings.TAB_UV.SETTINGS_GENERAL, false},
        {self.autoDriveUserSettings, alwaysEnabled, g_baseUIFilename, ADSettings.TAB_UV.SETTINGS_USER, false},
        {self.autoDriveVehicleSettings, vehicleEnabled, g_baseUIFilename, ADSettings.TAB_UV.SETTINGS_VEHICLE, false},
        {self.autoDriveCombineUnloadSettings, combineEnabled, g_autoDriveUIFilename, ADSettings.TAB_UV.SETTINGS_UNLOAD, false},
        {self.autoDriveEnvironmentSettings, vehicleEnabled, g_baseUIFilename, ADSettings.TAB_UV.SETTINGS_ENVIRONMENT, false},
        {self.autoDriveDebugSettings, developmentControlsEnabled, g_autoDriveUIFilename, ADSettings.TAB_UV.SETTINGS_DEBUG, true},
        {self.autoDriveExperimentalFeaturesSettings, alwaysEnabled, g_autoDriveUIFilename, ADSettings.TAB_UV.SETTINGS_EXPFEAT, true}
    }

    for i, pageDef in ipairs(orderedPages) do
        local page, predicate, uiFilename, iconUVs, isAutonomous = unpack(pageDef)
        local normalizedIconUVs = getNormalizedUVs(iconUVs)
        self:registerPage(page, i, predicate)
        self:addPageTab(page, uiFilename, normalizedIconUVs) -- use the global here because the value changes with resolution settings
        page.isAutonomous = isAutonomous
        page.headerIcon:setImageFilename(uiFilename)
        page.headerIcon:setImageUVs(nil, unpack(normalizedIconUVs))
        if page.setupMenuButtonInfo ~= nil then
            page:setupMenuButtonInfo(self)
        end
    end
end

function ADSettings:onOpen()
    ADSettings:superClass().onOpen(self)
    self.inputDisableTime = 200
end

function ADSettings:onClose()
    for _, pageName in pairs(ADSettings.CONTROLS) do
        self:resetPage(self[pageName])
    end
    AutoDrive.Hud.lastUIScale = 0
    ADSettings:superClass().onClose(self)
end

--- Define default properties and retrieval collections for menu buttons.
function ADSettings:setupMenuButtonInfo()
    self.defaultMenuButtonInfo = {
        {inputAction = InputAction.MENU_BACK, text = self.l10n:getText("button_back"), callback = self:makeSelfCallback(self.onClickBack), showWhenPaused = true},
        {inputAction = InputAction.MENU_ACCEPT, text = self.l10n:getText("button_apply"), callback = self:makeSelfCallback(self.onClickOK), showWhenPaused = true},
        {inputAction = InputAction.MENU_CANCEL, text = self.l10n:getText("button_reset"), callback = self:makeSelfCallback(self.onClickReset), showWhenPaused = true},
        {inputAction = InputAction.MENU_ACTIVATE, text = self.l10n:getText("gui_ad_restoreButtonText"), callback = self:makeSelfCallback(self.onClickRestore), showWhenPaused = true}
    }
end

function ADSettings:onClickOK()
    self:applySettings()
    ADSettings:superClass().onClickBack(self)
end

function ADSettings:onClickBack()
    if self:pagesHasChanges() then
        g_gui:showYesNoDialog({text = g_i18n:getText("gui_ad_settingsClosingDialog_text"), title = g_i18n:getText("gui_ad_settingsClosingDialog_title"), callback = self.onClickBackDialogCallback, target = self})
    else
        self:onClickBackDialogCallback(true)
    end
end

function ADSettings:onClickBackDialogCallback(yes)
    if yes then
        ADSettings:superClass().onClickBack(self)
    end
end

function ADSettings:onClickReset()
    local page = self:getActivePage()
    if page == nil or page.isAutonomous then
        return
    end
    self:resetPage(page)
end

function ADSettings:onClickRestore()
    local page = self:getActivePage()
    if page == nil or page.isAutonomous then
        return
    end
    self:restorePage(page)
end

function ADSettings:applySettings()
    if self:pagesHasChanges() then
        local userSpecificHasChanges = false

        for settingName, setting in pairs(AutoDrive.settings) do
            if setting.isVehicleSpecific and g_currentMission.controlledVehicle ~= nil and g_currentMission.controlledVehicle.ad ~= nil and g_currentMission.controlledVehicle.ad.settings[settingName] ~= nil then
                setting = g_currentMission.controlledVehicle.ad.settings[settingName]
            end
            if setting.new ~= nil and setting.new ~= setting.current then
                -- We could even print this with our debug system, but since GIANTS itself prints every changed config, for the moment we will do the same
                g_logManager:devInfo('Setting \'%s\' changed from "%s" to "%s"', settingName, setting.values[setting.current], setting.values[setting.new])
                setting.current = setting.new
                if setting.isUserSpecific then
                    userSpecificHasChanges = true
                end
            end
        end

        if userSpecificHasChanges then
            AutoDrive.setEditorMode(AutoDrive.EDITOR_OFF)
            ADUserDataManager:sendToServer()
        end

        AutoDriveUpdateSettingsEvent.sendEvent(g_currentMission.controlledVehicle)
    end
end

function ADSettings:resetPage(page)
    if page == nil or page.isAutonomous then
        return
    end
    if page:hasChanges() then
        for settingName, _ in pairs(page.settingElements) do
            if AutoDrive.settings[settingName] ~= nil then
                local setting = AutoDrive.settings[settingName]
                if setting.isVehicleSpecific and g_currentMission.controlledVehicle ~= nil and g_currentMission.controlledVehicle.ad ~= nil and g_currentMission.controlledVehicle.ad.settings[settingName] ~= nil then
                    setting = g_currentMission.controlledVehicle.ad.settings[settingName]
                end
                setting.new = setting.current
                page:loadGUISetting(settingName, setting.current)
            end
        end
    end
end

function ADSettings:restorePage(page)
    if page == nil or page.isAutonomous then
        return
    end
    for settingName, _ in pairs(page.settingElements) do
        if AutoDrive.settings[settingName] ~= nil then
            local setting = AutoDrive.settings[settingName]
            -- We will restore only global settings to prevent confusion but we could even restore vehicle settings if it will be requested in future
            if not setting.isVehicleSpecific then
                setting.new = setting.default
                page:loadGUISetting(settingName, setting.default)
            end
        end
    end
end

function ADSettings:getActivePage()
    return self[ADSettings.CONTROLS[self.currentPageId]]
end

function ADSettings:pagesHasChanges()
    for _, pageName in pairs(ADSettings.CONTROLS) do
        if not self[pageName].isAutonomous and self[pageName]:hasChanges() then
            return true
        end
    end
    return false
end

function ADSettings:forceLoadGUISettings()
    for _, pageName in pairs(ADSettings.CONTROLS) do
        if self[pageName].loadGUISettings ~= nil then
            self[pageName]:loadGUISettings()
        end
    end
end
