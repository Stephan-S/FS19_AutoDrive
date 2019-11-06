--
-- AutoDrive GUI
-- V1.0.0.0
--
-- @author Stephan Schlosser
-- @date 08/04/2019

adSettingsPage = {}

local adSettingsPage_mt = Class(adSettingsPage, TabbedMenuFrameElement)

adSettingsPage.CONTROLS = {
    CONTAINER = "container"
}

function adSettingsPage:new(target, custom_mt)
    local self = TabbedMenuFrameElement:new(target, adSettingsPage_mt)
    self.returnScreenName = ""
    self.settingElements = {}
    self:registerControls(adSettingsPage.CONTROLS)
    return self
end

function adSettingsPage:onFrameOpen()
    adSettingsPage:superClass().onFrameOpen(self)
    FocusManager:setFocus(self.backButton)
    self:updateMyGUISettings()
    self.callBackParent.activePageID = self.callBackParentWithID
end

function adSettingsPage:onFrameClose()
    adSettingsPage:superClass().onFrameClose(self)
end

function adSettingsPage:onCreateAutoDriveSetting(element)
    self.settingElements[element.name] = element
    local setting = AutoDrive.settings[element.name]
    element.labelElement.text = g_i18n:getText(setting.text)
    element.toolTipText = g_i18n:getText(setting.tooltip)

    local labels = {}
    for i = 1, #setting.texts, 1 do
        if setting.translate == true then
            labels[i] = g_i18n:getText(setting.texts[i])
        else
            labels[i] = setting.texts[i]
        end
    end
    element:setTexts(labels)
end

function adSettingsPage:copyAttributes(src)
    adSettingsPage:superClass().copyAttributes(self, src)

    self.ui = src.ui
    self.i18n = src.i18n
end

function adSettingsPage:initialize()
end

--- Get the frame's main content element's screen size.
function adSettingsPage:getMainElementSize()
    return self.container.size
end

--- Get the frame's main content element's screen position.
function adSettingsPage:getMainElementPosition()
    return self.container.absPosition
end

function adSettingsPage:updateToolTipBoxVisibility(box)
    local hasText = box.text ~= nil and box.text ~= ""
    box:setVisible(hasText)
end

function adSettingsPage:updateMyGUISettings()
    for settingName, settingElement in pairs(self.settingElements) do
        if AutoDrive.settings[settingName] ~= nil then
            local setting = AutoDrive.settings[settingName]
            if setting ~= nil and setting.isVehicleSpecific and g_currentMission.controlledVehicle ~= nil then
                setting = g_currentMission.controlledVehicle.ad.settings[settingName]
            end
            self:updateGUISettings(settingName, setting.current)
        end
    end
end

function adSettingsPage:updateGUISettings(settingName, index)
    self.settingElements[settingName]:setState(index, false)
end
