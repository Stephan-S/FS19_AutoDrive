--
-- AutoDrive Enter Group Name GUI
-- V1.0.0.0
--
-- @author Stephan Schlosser
-- @date 09/06/2019

adEnterGroupNameGui = {};

local adEnterGroupNameGui_mt = Class(adEnterGroupNameGui, ScreenElement);

function adEnterGroupNameGui:new(target, custom_mt)
    local self = ScreenElement:new(target, adEnterGroupNameGui_mt);
    self.returnScreenName = "";
    self.textInputElement = nil;
    return self;	
end;

function adEnterGroupNameGui:onOpen()
    adEnterGroupNameGui:superClass().onOpen(self);
    FocusManager:setFocus(self.textInputElement);
    self.textInputElement:setText("");
    self.textInputElement:onFocusActivate()
end;

function adEnterGroupNameGui:onClickOk()
    adEnterGroupNameGui:superClass().onClickOk(self);
    local enteredName = self.textInputElement.text;

    if enteredName:len() > 1 then
        if AutoDrive.groups[enteredName] == nil then
            AutoDrive.groupCounter = AutoDrive.groupCounter + 1;
            AutoDrive.groups[enteredName] = AutoDrive.groupCounter;

            for _,vehicle in pairs(g_currentMission.vehicles) do
                if (vehicle.ad ~= nil) then
                    if vehicle.ad.groups[enteredName] == nil then
                        vehicle.ad.groups[enteredName] = false;
                    end;
                end;
            end;  
            AutoDrive.Hud.lastUIScale = 0;     
        end;
    end;
    
    self:onClickBack();
end;

function adEnterGroupNameGui:onClickResetButton()
    self.textInputElement.text = "";
end;

function adEnterGroupNameGui:onClose()
    adEnterGroupNameGui:superClass().onClose(self);
end;

function adEnterGroupNameGui:onClickBack()
    adEnterGroupNameGui:superClass().onClickBack(self);
end;

function adEnterGroupNameGui:onCreateInputElement(element)
    self.textInputElement = element;   
    element.text = "";
end;

function adEnterGroupNameGui:onEnterPressed()
    --self:onClickOk();
end;

function adEnterGroupNameGui:onEscPressed()
    --self:onClose()();
end;