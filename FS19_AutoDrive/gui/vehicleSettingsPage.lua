--
-- AutoDrive GUI
-- V1.0.0.0
--
-- @author Stephan Schlosser
-- @date 08/04/2019

adVehicleSettingsPage = {}

local adVehicleSettingsPage_mt = Class(adVehicleSettingsPage, TabbedMenuFrameElement)

adVehicleSettingsPage.CONTROLS = {
    CONTAINER = "container"
}

function adVehicleSettingsPage:new(target, custom_mt)
    local self = TabbedMenuFrameElement:new(target, adVehicleSettingsPage_mt)
    self.returnScreenName = ""
    self.settingElements = {}
    self:registerControls(adVehicleSettingsPage.CONTROLS)
    return self
end

function adVehicleSettingsPage:onFrameOpen()
    adVehicleSettingsPage:superClass().onFrameOpen(self)
    FocusManager:setFocus(self.backButton)
    self:updateMyGUISettings()
    self.callBackParent.activePageID = self.callBackParentWithID
end

function adVehicleSettingsPage:onFrameClose()
    adVehicleSettingsPage:superClass().onFrameClose(self)
end

function adVehicleSettingsPage:onCreateAutoDriveSetting(element)
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

function adVehicleSettingsPage:copyAttributes(src)
    adVehicleSettingsPage:superClass().copyAttributes(self, src)

    self.ui = src.ui
    self.i18n = src.i18n
end

function adVehicleSettingsPage:initialize()
end

--- Get the frame's main content element's screen size.
function adVehicleSettingsPage:getMainElementSize()
    return self.container.size
end

--- Get the frame's main content element's screen position.
function adVehicleSettingsPage:getMainElementPosition()
    return self.container.absPosition
end

function adVehicleSettingsPage:updateToolTipBoxVisibility(box)
    local hasText = box.text ~= nil and box.text ~= ""
    box:setVisible(hasText)
end

function adVehicleSettingsPage:updateMyGUISettings()
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

function adVehicleSettingsPage:updateGUISettings(settingName, index)
    self.settingElements[settingName]:setState(index, false)
end
