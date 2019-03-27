function AutoDrive:handleKeyEvents(vehicle, unicode, sym, modifier, isDown)
    if isDown and vehicle.ad.choosingDestination then
        AutoDrive:handleKeyEventsForDestination(vehicle, unicode, sym, modifier, isDown);
    elseif isDown and vehicle.ad.enteringMapMarker then
        AutoDrive:handleKeyEventForMapMarkerInput(vehicle, unicode, sym, modifier, isDown)
    end;   	
end;

function AutoDrive:handleKeyEventsForDestination(vehicle, unicode, sym, modifier, isDown)
    if sym == 13 then
        vehicle.ad.choosingDestination = false;
        vehicle.ad.chosenDestination = "";
        vehicle.ad.enteredChosenDestination = "";
        vehicle.isBroken = false;
        g_currentMission.isPlayerFrozen = false;
        g_inputBinding:revertContext(true);
    elseif sym == 8 then
        vehicle.ad.enteredChosenDestination = string.sub(vehicle.ad.enteredChosenDestination,1,string.len(vehicle.ad.enteredChosenDestination)-1)
    elseif sym == 9 then
        local foundMatch = false;
        local behindCurrent = false;
        local markerID = -1;
        local markerIndex = -1;
        if vehicle.ad.chosenDestination == "" then
            behindCurrent = true;
        end;
        for _,marker in pairs( AutoDrive.mapMarker) do
            local tempName = vehicle.ad.chosenDestination;
            if string.find(marker.name, vehicle.ad.enteredChosenDestination) == 1 and behindCurrent and not foundMatch then
                vehicle.ad.chosenDestination = marker.name;
                markerID = marker.id;
                markerIndex = _;
                foundMatch = true;
            end;
            if tempName == marker.name then
                behindCurrent = true;
            end;
        end;
        if behindCurrent == true and foundMatch == false then
            foundMatch = false;
            for _,marker in pairs( AutoDrive.mapMarker) do

                if string.find(marker.name, vehicle.ad.enteredChosenDestination) == 1 and not foundMatch then
                    vehicle.ad.chosenDestination = marker.name;
                    markerID = marker.id;
                    markerIndex = _;
                    foundMatch = true;
                end;
            end;
        end;
        if vehicle.ad.chosenDestination ~= "" then
            vehicle.ad.mapMarkerSelected = markerIndex;
            vehicle.ad.targetSelected = AutoDrive.mapMarker[vehicle.ad.mapMarkerSelected].id;
            vehicle.ad.nameOfSelectedTarget = AutoDrive.mapMarker[vehicle.ad.mapMarkerSelected].name;
        end;
    elseif unicode ~= 0 then
        vehicle.ad.enteredChosenDestination = vehicle.ad.enteredChosenDestination .. string.char(unicode);
    end;
end;

function AutoDrive:handleKeyEventForMapMarkerInput(vehicle, unicode, sym, modifier, isDown)    
    if sym == 13 then
        AutoDrive:finishCreatingMapMarker(vehicle)
    elseif sym == 8 then
        if vehicle.ad.enteredMapMarkerString == ("" .. AutoDrive.mapWayPointsCounter) then
            vehicle.ad.enteredMapMarkerString = "";
        else
            vehicle.ad.enteredMapMarkerString = string.sub(vehicle.ad.enteredMapMarkerString,1,string.len(vehicle.ad.enteredMapMarkerString)-1)
        end;
    elseif unicode ~= 0 then
        if vehicle.ad.enteredMapMarkerString == ("" .. AutoDrive.mapWayPointsCounter) then
            vehicle.ad.enteredMapMarkerString = "";
        end;
        
        vehicle.ad.enteredMapMarkerString = vehicle.ad.enteredMapMarkerString .. string.char(unicode);        
    end;
end;