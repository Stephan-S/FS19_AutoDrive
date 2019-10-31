--
-- AutoDrive Enter Driver Name GUI
-- V1.1.0.0
--
-- @author Stephan Schlosser
-- @date 09/06/2019

adEnterDriverNameGui = {}

local adEnterDriverNameGui_mt = Class(adEnterDriverNameGui, ScreenElement)

function adEnterDriverNameGui:new(target, custom_mt)
    local self = ScreenElement:new(target, adEnterDriverNameGui_mt)
    self.returnScreenName = ""
    self.textInputElement = nil
    return self
end

function adEnterDriverNameGui:onCreateTitleElement(element)
    element:setText(g_i18n:getText("gui_ad_enterDriverNameTitle"))
end

function adEnterDriverNameGui:onCreateTextElement(element)
    element:setText(g_i18n:getText("gui_ad_enterDriverNameText"))
end

function adEnterDriverNameGui:onCreateInputElement(element)
    self.textInputElement = element
    element.text = ""
end

function adEnterDriverNameGui:onOpen()
    adEnterDriverNameGui:superClass().onOpen(self)
    FocusManager:setFocus(self.textInputElement)
    self.textInputElement.blockTime = 0
    self.textInputElement:onFocusActivate()
    if g_currentMission.controlledVehicle ~= nil and g_currentMission.controlledVehicle.ad ~= nil then
        self.textInputElement:setText(g_currentMission.controlledVehicle.ad.driverName)
    end
end

function adEnterDriverNameGui:onClickOk()
    adEnterDriverNameGui:superClass().onClickOk(self)
    local enteredName = self.textInputElement.text

    if enteredName:len() > 1 then
        if g_currentMission.controlledVehicle ~= nil and g_currentMission.controlledVehicle.ad ~= nil then
            g_currentMission.controlledVehicle.ad.driverName = self.textInputElement.text
            AutoDriveUpdateNameEvent:sendEvent(g_currentMission.controlledVehicle)
        end
    end

    self:onClickBack()
end

function adEnterDriverNameGui:onClickResetButton()
    if g_currentMission.controlledVehicle ~= nil and g_currentMission.controlledVehicle.ad ~= nil then
        self.textInputElement:setText(g_currentMission.controlledVehicle.ad.driverName)
    end
end

function adEnterDriverNameGui:onClickBack()
    adEnterDriverNameGui:superClass().onClickBack(self)
end

function adEnterDriverNameGui:onClose()
    adEnterDriverNameGui:superClass().onClose(self)
end
