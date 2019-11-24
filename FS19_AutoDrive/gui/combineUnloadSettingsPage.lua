--
-- AutoDrive GUI
-- V1.0.0.0
--
-- @author Stephan Schlosser
-- @date 08/04/2019

ADCombineUnloadSettingsPage = {}

local ADCombineUnloadSettingsPage_mt = Class(ADCombineUnloadSettingsPage, TabbedMenuFrameElement)

ADCombineUnloadSettingsPage.CONTROLS = {
    CONTAINER = "container"
}

function ADCombineUnloadSettingsPage:new(target)
    local o = TabbedMenuFrameElement:new(target, ADCombineUnloadSettingsPage_mt)
    o.returnScreenName = ""
    o.settingElements = {}
    o:registerControls(ADCombineUnloadSettingsPage.CONTROLS)
    return o
end

function ADCombineUnloadSettingsPage:onFrameOpen()
    ADCombineUnloadSettingsPage:superClass().onFrameOpen(self)
    FocusManager:setFocus(self.backButton)
    self:updateMyGUISettings()
    --self.callBackParent:applySettings()
    self.callBackParent.activePageID = self.callBackParentWithID
end

function ADCombineUnloadSettingsPage:onFrameClose()
    ADCombineUnloadSettingsPage:superClass().onFrameClose(self)
end

function ADCombineUnloadSettingsPage:onCreateAutoDriveSetting(element)
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

function ADCombineUnloadSettingsPage:copyAttributes(src)
    ADCombineUnloadSettingsPage:superClass().copyAttributes(self, src)

    self.ui = src.ui
    self.i18n = src.i18n
end

function ADCombineUnloadSettingsPage:initialize()
end

--- Get the frame's main content element's screen size.
function ADCombineUnloadSettingsPage:getMainElementSize()
    return self.container.size
end

--- Get the frame's main content element's screen position.
function ADCombineUnloadSettingsPage:getMainElementPosition()
    return self.container.absPosition
end

function ADCombineUnloadSettingsPage:updateToolTipBoxVisibility(box)
    local hasText = box.text ~= nil and box.text ~= ""
    box:setVisible(hasText)
end

function ADCombineUnloadSettingsPage:updateMyGUISettings()
    for settingName, _ in pairs(self.settingElements) do
        if AutoDrive.settings[settingName] ~= nil then
            local setting = AutoDrive.settings[settingName]
            if setting ~= nil and setting.isVehicleSpecific and g_currentMission.controlledVehicle ~= nil then
                setting = g_currentMission.controlledVehicle.ad.settings[settingName]
            end
            self:updateGUISettings(settingName, setting.current)
        end
    end
end

function ADCombineUnloadSettingsPage:updateGUISettings(settingName, index)
    self.settingElements[settingName]:setState(index, false)
end
