--
-- AutoDrive GUI
-- V1.0.0.0
--
-- @author Stephan Schlosser
-- @date 08/04/2019

ADSettings = {}

local ADSettings_mt = Class(ADSettings, TabbedMenu)

ADSettings.CONTROLS = {"autoDriveSettings", "autoDriveVehicleSettings", "autoDriveCombineUnloadSettings"}

function ADSettings:new()
    local o = TabbedMenu:new(nil, ADSettings_mt, g_messageCenter, g_i18n, g_gui.inputManager)
    o.returnScreenName = ""
    o.settingElements = {}

    o:registerControls(ADSettings.CONTROLS)

    o.activePageID = 1
    return o
end

function ADSettings:onGuiSetupFinished()
    ADSettings:superClass().onGuiSetupFinished(self)

    self:setupPages()
end

function ADSettings:onClose()
    self:applySettings()
    ADSettings:superClass().onClose(self)
end

function ADSettings:onOpen()
    ADSettings:superClass().onOpen(self)

    self.inputDisableTime = 200
end

function ADSettings:setupPages()
    local alwaysVisiblePredicate = self:makeIsAlwaysVisiblePredicate()

    local orderedPages = {
        {self.autoDriveSettings, alwaysVisiblePredicate, AutoDrive.directory .. "textures/GUI_Icons.dds", ADSettings.TAB_UV.SETTINGS_GENERAL, "autoDriveSettings"},
        {self.autoDriveVehicleSettings, alwaysVisiblePredicate, g_baseUIFilename, ADSettings.TAB_UV.SETTINGS_VEHICLE, "autoDriveVehicleSettings"},
        {self.autoDriveCombineUnloadSettings, alwaysVisiblePredicate, AutoDrive.directory .. "textures/GUI_Icons.dds", ADSettings.TAB_UV.SETTINGS_UNLOAD, "autoDriveCombineUnloadSettings"}
    }

    for i, pageDef in ipairs(orderedPages) do
        local page, predicate, uiFilename, iconUVs, _ = unpack(pageDef)
        self:registerPage(page, i, predicate)

        page.callBackParent = self
        page.callBackParentWithID = i

        local normalizedUVs = getNormalizedUVs(iconUVs)
        self:addPageTab(page, uiFilename, normalizedUVs) -- use the global here because the value changes with resolution settings
    end
end

function ADSettings:makeIsAlwaysVisiblePredicate()
    return function()
        return true
    end
end

--- Page tab UV coordinates for display elements.
ADSettings.TAB_UV = {
    SETTINGS_GENERAL = {385, 0, 128, 128},
    SETTINGS_VEHICLE = {0, 209, 65, 65},
    SETTINGS_UNLOAD = {0, 0, 128, 128},
    SETTINGS_LOAD = {0, 129, 128, 128},
    SETTINGS_NAVIGATION = {0, 257, 128, 128}
}

--- Define default properties and retrieval collections for menu buttons.
function ADSettings:setupMenuButtonInfo()
    local onButtonBackFunction = self.clickBackCallback

    self.defaultMenuButtonInfo = {
        {inputAction = InputAction.MENU_BACK, text = self.l10n:getText("button_back"), callback = onButtonBackFunction, showWhenPaused = true},
        {inputAction = InputAction.MENU_ACCEPT, text = self.l10n:getText("button_ok"), callback = self:makeSelfCallback(self.onClickOK), showWhenPaused = true},
        {inputAction = InputAction.MENU_CANCEL, text = self.l10n:getText("button_reset"), callback = self:makeSelfCallback(self.onClickReset), showWhenPaused = true}
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

function ADSettings:onClickBack()
    -- We can't call applySettings here or we will apply setting two times
    --self:applySettings()
    ADSettings:superClass().onClickBack(self)
end

function ADSettings:onClickOK()
    --ADSettings:superClass().onClickOk(self);
    self:onClickBack()
end

function ADSettings:applySettings()
    local page = self:getActivePage()
    if page == nil then
        return
    end

    for settingName, settingElement in pairs(page.settingElements) do
        local value = settingElement:getState()
        if AutoDrive.settings[settingName] ~= nil then
            local setting = AutoDrive.settings[settingName]
            setting.current = value
            if setting ~= nil and setting.isVehicleSpecific and g_currentMission.controlledVehicle ~= nil then
                setting = g_currentMission.controlledVehicle.ad.settings[settingName]
                setting.current = value
            end
        end
    end

    AutoDrive.Hud.lastUIScale = 0
    AutoDriveUpdateSettingsEvent.sendEvent(g_currentMission.controlledVehicle)
    AutoDriveUserDataEvent.sendToServer()
end

function ADSettings:onClickReset()
    self:resetCurrentPageGUISettings()
end

function ADSettings:resetCurrentPageGUISettings()
    local page = self:getActivePage()
    if page == nil then
        return
    end

    for settingName, settingElement in pairs(page.settingElements) do
        if AutoDrive.settings[settingName] ~= nil then
            local setting = AutoDrive.settings[settingName]
            if setting ~= nil and setting.isVehicleSpecific and g_currentMission.controlledVehicle ~= nil then
                setting = g_currentMission.controlledVehicle.ad.settings[settingName]
            end

            page:updateGUISettings(settingName, setting.default)
        end
    end
end

function ADSettings:getActivePage()
    return self[ADSettings.CONTROLS[self.activePageID]]
end
