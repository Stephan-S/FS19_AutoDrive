--
-- AutoDrive GUI
-- V1.0.0.0
--
-- @author Stephan Schlosser
-- @date 08/04/2019

adCombineUnloadSettingsPage = {}

local adCombineUnloadSettingsPage_mt = Class(adCombineUnloadSettingsPage, TabbedMenuFrameElement)

adCombineUnloadSettingsPage.CONTROLS = {
    CONTAINER = "container"
}

function adCombineUnloadSettingsPage:new(target, custom_mt)
    local self = TabbedMenuFrameElement:new(target, adCombineUnloadSettingsPage_mt)
    self.returnScreenName = ""
    self.settingElements = {}
    self:registerControls(adCombineUnloadSettingsPage.CONTROLS)
    return self
end

function adCombineUnloadSettingsPage:onFrameOpen()
    adCombineUnloadSettingsPage:superClass().onFrameOpen(self)
    FocusManager:setFocus(self.backButton)
    self:updateMyGUISettings()
    self.callBackParent:applySettings()
    self.callBackParent.activePageID = self.callBackParentWithID
end

function adCombineUnloadSettingsPage:onFrameClose()
    adCombineUnloadSettingsPage:superClass().onFrameClose(self)
end

function adCombineUnloadSettingsPage:onCreateAutoDriveSetting(element)
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

function adCombineUnloadSettingsPage:copyAttributes(src)
    adCombineUnloadSettingsPage:superClass().copyAttributes(self, src)

    self.ui = src.ui
    self.i18n = src.i18n
end

function adCombineUnloadSettingsPage:initialize()
end

--- Get the frame's main content element's screen size.
function adCombineUnloadSettingsPage:getMainElementSize()
    return self.container.size
end

--- Get the frame's main content element's screen position.
function adCombineUnloadSettingsPage:getMainElementPosition()
    return self.container.absPosition
end

function adCombineUnloadSettingsPage:updateToolTipBoxVisibility(box)
    local hasText = box.text ~= nil and box.text ~= ""
    box:setVisible(hasText)
end

function adCombineUnloadSettingsPage:updateMyGUISettings()
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

function adCombineUnloadSettingsPage:updateGUISettings(settingName, index)
    self.settingElements[settingName]:setState(index, false)
end
