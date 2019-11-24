--
-- AutoDrive GUI
-- V1.0.0.0
--
-- @author Stephan Schlosser
-- @date 08/04/2019

ADVehicleSettingsPage = {}

local ADVehicleSettingsPage_mt = Class(ADVehicleSettingsPage, TabbedMenuFrameElement)

ADVehicleSettingsPage.CONTROLS = {
    CONTAINER = "container"
}

function ADVehicleSettingsPage:new(target)
    local o = TabbedMenuFrameElement:new(target, ADVehicleSettingsPage_mt)
    o.returnScreenName = ""
    o.settingElements = {}
    o:registerControls(ADVehicleSettingsPage.CONTROLS)
    return o
end

function ADVehicleSettingsPage:onFrameOpen()
    ADVehicleSettingsPage:superClass().onFrameOpen(self)
    FocusManager:setFocus(self.backButton)
    self:updateMyGUISettings()
    self.callBackParent.activePageID = self.callBackParentWithID
end

function ADVehicleSettingsPage:onFrameClose()
    ADVehicleSettingsPage:superClass().onFrameClose(self)
end

function ADVehicleSettingsPage:onCreateAutoDriveSetting(element)
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

function ADVehicleSettingsPage:copyAttributes(src)
    ADVehicleSettingsPage:superClass().copyAttributes(self, src)

    self.ui = src.ui
    self.i18n = src.i18n
end

function ADVehicleSettingsPage:initialize()
end

--- Get the frame's main content element's screen size.
function ADVehicleSettingsPage:getMainElementSize()
    return self.container.size
end

--- Get the frame's main content element's screen position.
function ADVehicleSettingsPage:getMainElementPosition()
    return self.container.absPosition
end

function ADVehicleSettingsPage:updateToolTipBoxVisibility(box)
    local hasText = box.text ~= nil and box.text ~= ""
    box:setVisible(hasText)
end

function ADVehicleSettingsPage:updateMyGUISettings()
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

function ADVehicleSettingsPage:updateGUISettings(settingName, index)
    self.settingElements[settingName]:setState(index, false)
end
