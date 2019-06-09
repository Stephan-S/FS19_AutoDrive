--
-- AutoDrive Enter Driver Name GUI
-- V1.0.0.0
--
-- @author Stephan Schlosser
-- @date 09/06/2019

adEnterDriverNameGui = {};

local adEnterDriverNameGui_mt = Class(adEnterDriverNameGui, ScreenElement);

function adEnterDriverNameGui:new(target, custom_mt)
    local self = ScreenElement:new(target, adEnterDriverNameGui_mt);
    self.returnScreenName = "";
    self.textInputElement = nil;
    return self;	
end;

function adEnterDriverNameGui:onOpen()
    adEnterDriverNameGui:superClass().onOpen(self);
    FocusManager:setFocus(self.textInputElement);
    self.textInputElement.text = g_currentMission.controlledVehicle.ad.driverName;
    self.textInputElement:onFocusActivate()
end;

function adEnterDriverNameGui:onClickOk()
    adEnterDriverNameGui:superClass().onClickOk(self);
    local enteredName = self.textInputElement.text;

    if enteredName:len() > 1 then
        g_currentMission.controlledVehicle.ad.driverName = self.textInputElement.text;
    end;
    
    self:onClickBack();
end;

function adEnterDriverNameGui:onClickResetButton()
    self.textInputElement.text = g_currentMission.controlledVehicle.ad.driverName;
end;

function adEnterDriverNameGui:onClose()
    adEnterDriverNameGui:superClass().onClose(self);
end;

function adEnterDriverNameGui:onClickBack()
    adEnterDriverNameGui:superClass().onClickBack(self);
end;

function adEnterDriverNameGui:onCreateInputElement(element)
    self.textInputElement = element;   
    element.text = "";
end;

function adEnterDriverNameGui:onEnterPressed()
    self:onClickOk();
end;

function adEnterDriverNameGui:onEscPressed()
    self:onClose()();
end;