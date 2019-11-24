--
-- AutoDrive Enter filter for destinations shown in drop down menus GUI
-- V1.1.0.0
--
-- @author Stephan Schlosser
-- @date 09/06/2019

ADEnterDestinationFilterGui = {}

local ADEnterDestinationFilterGui_mt = Class(ADEnterDestinationFilterGui, ScreenElement)

function ADEnterDestinationFilterGui:new(target)
    local o = ScreenElement:new(target, ADEnterDestinationFilterGui_mt)
    o.returnScreenName = ""
    o.textInputElement = nil
    return o
end

function ADEnterDestinationFilterGui:onCreateTitleElement(element)
    element:setText(g_i18n:getText("gui_ad_enterDestinationFilterTitle"))
end

function ADEnterDestinationFilterGui:onCreateTextElement(element)
    element:setText(g_i18n:getText("gui_ad_enterDestinationFilterText"))
end

function ADEnterDestinationFilterGui:onCreateInputElement(element)
    self.textInputElement = element
    element.text = ""
end

function ADEnterDestinationFilterGui:onOpen()
    ADEnterDestinationFilterGui:superClass().onOpen(self)
    FocusManager:setFocus(self.textInputElement)
    self.textInputElement.blockTime = 0
    self.textInputElement:onFocusActivate()
    self.textInputElement:setText(g_currentMission.controlledVehicle.ad.destinationFilterText)
end

function ADEnterDestinationFilterGui:onClickOk()
    ADEnterDestinationFilterGui:superClass().onClickOk(self)
    g_currentMission.controlledVehicle.ad.destinationFilterText = self.textInputElement.text;
    self:onClickBack()
end

function ADEnterDestinationFilterGui:onClickResetButton()
    self.textInputElement:setText("");
end

function ADEnterDestinationFilterGui:onClickBack()
    ADEnterDestinationFilterGui:superClass().onClickBack(self)
end

function ADEnterDestinationFilterGui:onClose()
    ADEnterDestinationFilterGui:superClass().onClose(self)
end
