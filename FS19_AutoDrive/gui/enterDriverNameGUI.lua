--
-- AutoDrive Enter Driver Name GUI
-- V1.1.0.0
--
-- @author Stephan Schlosser
-- @date 09/06/2019

ADEnterDriverNameGui = {}

local ADEnterDriverNameGui_mt = Class(ADEnterDriverNameGui, ScreenElement)

function ADEnterDriverNameGui:new(target)
    local o = ScreenElement:new(target, ADEnterDriverNameGui_mt)
    o.returnScreenName = ""
    o.textInputElement = nil
    return o
end

function ADEnterDriverNameGui:onCreateTitleElement(element)
    element:setText(g_i18n:getText("gui_ad_enterDriverNameTitle"))
end

function ADEnterDriverNameGui:onCreateTextElement(element)
    element:setText(g_i18n:getText("gui_ad_enterDriverNameText"))
end

function ADEnterDriverNameGui:onCreateInputElement(element)
    self.textInputElement = element
    element.text = ""
end

function ADEnterDriverNameGui:onOpen()
    ADEnterDriverNameGui:superClass().onOpen(self)
    FocusManager:setFocus(self.textInputElement)
    self.textInputElement.blockTime = 0
    self.textInputElement:onFocusActivate()
    self.textInputElement:setText(g_currentMission.controlledVehicle.ad.driverName)
end

function ADEnterDriverNameGui:onClickOk()
    ADEnterDriverNameGui:superClass().onClickOk(self)
    AutoDrive.renameDriver(g_currentMission.controlledVehicle, self.textInputElement.text)
    self:onClickBack()
end

function ADEnterDriverNameGui:onClickResetButton()
    if g_currentMission.controlledVehicle ~= nil and g_currentMission.controlledVehicle.ad ~= nil then
        self.textInputElement:setText(g_currentMission.controlledVehicle.ad.driverName)
    end
end

function ADEnterDriverNameGui:onClickBack()
    ADEnterDriverNameGui:superClass().onClickBack(self)
end

function ADEnterDriverNameGui:onClose()
    ADEnterDriverNameGui:superClass().onClose(self)
end
