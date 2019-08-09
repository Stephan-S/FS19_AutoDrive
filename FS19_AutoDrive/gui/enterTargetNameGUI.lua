--
-- AutoDrive Enter Target Name GUI
-- V1.0.0.0
--
-- @author Stephan Schlosser
-- @date 08/08/2019

adEnterTargetNameGui = {};

local adEnterTargetNameGui_mt = Class(adEnterTargetNameGui, ScreenElement);

function adEnterTargetNameGui:new(target, custom_mt)
    local self = ScreenElement:new(target,adEnterTargetNameGui_mt);
    self.returnScreenName = "";
    self.textInputElement = nil;
    return self;	
end;

function adEnterTargetNameGui:onOpen()
    adEnterTargetNameGui:superClass().onOpen(self);
    FocusManager:setFocus(self.textInputElement);
    self.textInputElement:setText("" .. AutoDrive.mapWayPointsCounter);
    self.textInputElement:onFocusActivate()
    FocusManager:setFocus(self.textInputElement);
end;

function adEnterTargetNameGui:onClickOk()
    adEnterTargetNameGui:superClass().onClickOk(self);
    local enteredName = self.textInputElement.text;

    if enteredName:len() > 1 then
        if g_currentMission.controlledVehicle ~= nil and g_currentMission.controlledVehicle.ad ~= nil then    
            local closest = AutoDrive:findClosestWayPoint(g_currentMission.controlledVehicle);
            if closest ~= nil and closest ~= -1 and AutoDrive.mapWayPoints[closest] ~= nil then
                AutoDrive.mapMarkerCounter = AutoDrive.mapMarkerCounter + 1;
                local node = createTransformGroup(enteredName);
                setTranslation(node, AutoDrive.mapWayPoints[closest].x, AutoDrive.mapWayPoints[closest].y + 4 , AutoDrive.mapWayPoints[closest].z  );
        
                AutoDrive.mapMarker[AutoDrive.mapMarkerCounter] = {id=closest, name= enteredName, node=node};
                AutoDrive:MarkChanged();


                if g_server ~= nil then
                    AutoDrive:broadCastUpdateToClients();
                else
                    AutoDriveCreateMapMarkerEvent:sendEvent(g_currentMission.controlledVehicle, closest, enteredName);
                end;
            end;
        end;       
    end;    
    
    self:onClickBack();
end;

function adEnterTargetNameGui:onClickResetButton()
    self.textInputElement:setText("" .. AutoDrive.mapWayPointsCounter);
end;

function adEnterTargetNameGui:onClose()
    adEnterTargetNameGui:superClass().onClose(self);
end;

function adEnterTargetNameGui:onClickBack()
    adEnterTargetNameGui:superClass().onClickBack(self);
end;

function adEnterTargetNameGui:onCreateInputElement(element)
    self.textInputElement = element;   
    element.text = "";
end;

function adEnterTargetNameGui:onEnterPressed()
    --self:onClickOk();
end;

function adEnterTargetNameGui:onEscPressed()
    self:onClose()();
end;