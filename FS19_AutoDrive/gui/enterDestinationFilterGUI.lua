--
-- AutoDrive Enter filter for destinations shown in drop down menus GUI
-- V1.1.0.0
--
-- @author Stephan Schlosser
-- @date 09/06/2019

adEnterDestinationFilterGui = {}

local adEnterDestinationFilterGui_mt = Class(adEnterDestinationFilterGui, ScreenElement)

function adEnterDestinationFilterGui:new(target, custom_mt)
    local self = ScreenElement:new(target, adEnterDestinationFilterGui_mt)
    self.returnScreenName = ""
    self.textInputElement = nil
    return self
end

function adEnterDestinationFilterGui:onCreateTitleElement(element)
    element:setText(g_i18n:getText("gui_ad_enterDestinationFilterTitle"))
end

function adEnterDestinationFilterGui:onCreateTextElement(element)
    element:setText(g_i18n:getText("gui_ad_enterDestinationFilterText"))
end

function adEnterDestinationFilterGui:onCreateInputElement(element)
    self.textInputElement = element
    element.text = ""
end

function adEnterDestinationFilterGui:onOpen()
    adEnterDestinationFilterGui:superClass().onOpen(self)
    FocusManager:setFocus(self.textInputElement)
    self.textInputElement.blockTime = 0
    self.textInputElement:onFocusActivate()
    self.textInputElement:setText(g_currentMission.controlledVehicle.ad.destinationFilterText)
end

function adEnterDestinationFilterGui:onClickOk()
    adEnterDestinationFilterGui:superClass().onClickOk(self)
    g_currentMission.controlledVehicle.ad.destinationFilterText = self.textInputElement.text;
    self:onClickBack()
end

function adEnterDestinationFilterGui:onClickResetButton()
    self.textInputElement:setText("");
end

function adEnterDestinationFilterGui:onClickBack()
    adEnterDestinationFilterGui:superClass().onClickBack(self)
end

function adEnterDestinationFilterGui:onClose()
    adEnterDestinationFilterGui:superClass().onClose(self)
end
