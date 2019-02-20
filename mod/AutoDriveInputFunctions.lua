function AutoDrive:inputSiloMode(vehicle)
    if vehicle.ad.targetMode == true and vehicle.ad.unloadAtTrigger == false then
        if g_server ~= nil and g_dedicatedServerInfo == nil then
            vehicle.ad.reverseTrack = true;
            vehicle.ad.drivingForward = true;
            vehicle.ad.targetMode = false;
            vehicle.ad.roundTrip = false;
            vehicle.savedSpeed = vehicle.ad.targetSpeed;
            vehicle.ad.targetSpeed = 15;
            vehicle.ad.unloadAtTrigger = false;
        end;
    else
        if vehicle.ad.reverseTrack == true then
            vehicle.ad.reverseTrack = false;
            vehicle.ad.drivingForward = true;
            vehicle.ad.targetMode = true;
            vehicle.ad.roundTrip = false;
            vehicle.ad.unloadAtTrigger = true;

            if vehicle.savedSpeed ~= nil then
                vehicle.ad.targetSpeed = vehicle.savedSpeed;
                vehicle.savedSpeed = nil;
            end;
        else
            if vehicle.ad.targetMode == true and vehicle.ad.unloadAtTrigger == true then
                vehicle.ad.reverseTrack = false;
                vehicle.ad.drivingForward = true;
                vehicle.ad.targetMode = true;
                vehicle.ad.roundTrip = false;
                vehicle.ad.unloadAtTrigger = false;
                if vehicle.savedSpeed ~= nil then
                    vehicle.ad.targetSpeed = vehicle.savedSpeed;
                    vehicle.savedSpeed = nil;
                end;
            end;
        end;
    end;
end;

function AutoDrive:inputRoundTrip(vehicle)
    if vehicle.ad.roundTrip == false then
        vehicle.ad.roundTrip = true;
        vehicle.ad.targetSpeed = 40;
        vehicle.ad.targetMode = false;
        vehicle.ad.reverseTrack = false;

    else
        vehicle.ad.roundTrip = false;
    end;
end;

function AutoDrive:inputRecord(vehicle)
    if vehicle.ad.creationMode == false then
        vehicle.ad.creationMode = true;
        vehicle.ad.creationModeDual = false;
        vehicle.ad.currentWayPoint = 0;
        vehicle.ad.isActive = false;
        vehicle.ad.wayPoints = {};

        AutoDrive:disableAutoDriveFunctions(vehicle)
    else
        if vehicle.ad.creationModeDual == false then
            vehicle.ad.creationModeDual = true;
        else
            vehicle.ad.creationMode = false;
            vehicle.ad.creationModeDual = false;
            --AutoDrive:inputNextTarget(vehicle);
        end;
    end;

    AutoDrive.Hud:updateSingleButton("input_record", vehicle.ad.creationMode)
end;

function AutoDrive:inputNextTarget(vehicle)
    if  AutoDrive.mapMarker[1] ~= nil and AutoDrive.mapWayPoints[1] ~= nil then
        if vehicle.ad.mapMarkerSelected == -1 then
            vehicle.ad.mapMarkerSelected = 1

            vehicle.ad.targetSelected = AutoDrive.mapMarker[vehicle.ad.mapMarkerSelected].id;
            if vehicle.ad.targetSpeed == 15 then
                vehicle.ad.targetSpeed = 40;
            end;
            vehicle.ad.nameOfSelectedTarget = AutoDrive.mapMarker[vehicle.ad.mapMarkerSelected].name;
            vehicle.ad.targetMode = true;
            vehicle.ad.roundTrip = false;
            vehicle.ad.reverseTrack = false;
            vehicle.ad.drivingForward = true;
        else
            vehicle.ad.mapMarkerSelected = vehicle.ad.mapMarkerSelected + 1;
            if vehicle.ad.mapMarkerSelected > AutoDrive.mapMarkerCounter then
                vehicle.ad.mapMarkerSelected = 1;
            end;
            vehicle.ad.targetSelected = AutoDrive.mapMarker[vehicle.ad.mapMarkerSelected].id;
            vehicle.ad.nameOfSelectedTarget = AutoDrive.mapMarker[vehicle.ad.mapMarkerSelected].name;
            if vehicle.ad.targetSpeed == 15 then
                vehicle.ad.targetSpeed = 40;
            end;
            vehicle.ad.targetMode = true;
        end;
    end;
end;

function AutoDrive:inputPreviousTarget(vehicle)
    if AutoDrive.mapMarker[1] ~= nil and AutoDrive.mapWayPoints[1] ~= nil then
        if vehicle.ad.mapMarkerSelected == -1 then
            vehicle.ad.mapMarkerSelected = AutoDrive.mapMarkerCounter;

            vehicle.ad.targetSelected = AutoDrive.mapMarker[vehicle.ad.mapMarkerSelected].id;
            if vehicle.ad.targetSpeed == 15 then
                vehicle.ad.targetSpeed = 40;
            end;
            vehicle.ad.nameOfSelectedTarget = AutoDrive.mapMarker[vehicle.ad.mapMarkerSelected].name;
            vehicle.ad.targetMode = true;

        else
            vehicle.ad.mapMarkerSelected = vehicle.ad.mapMarkerSelected - 1;
            if vehicle.ad.mapMarkerSelected < 1 then
                vehicle.ad.mapMarkerSelected = AutoDrive.mapMarkerCounter;
            end;
            vehicle.ad.targetSelected = AutoDrive.mapMarker[vehicle.ad.mapMarkerSelected].id;
            vehicle.ad.nameOfSelectedTarget = AutoDrive.mapMarker[vehicle.ad.mapMarkerSelected].name;
            if vehicle.ad.targetSpeed == 15 then
                vehicle.ad.targetSpeed = 40;
            end;
            vehicle.ad.targetMode = true;
        end;
    end;
end;

function AutoDrive:toggleConnectionBetween(startNode, targetNode)
    local out_counter = 1;
    local exists = false;
    for i in pairs(startNode.out) do
        if exists == true then
            startNode.out[out_counter] = startNode.out[i];
            startNode.out_cost[out_counter] = startNode.out_cost[i];
            out_counter = out_counter +1;
        else
            if startNode.out[i] == targetNode.id then
                AutoDrive:MarkChanged()
                startNode.out[i] = nil;
                startNode.out_cost[i] = nil;

                if AutoDrive.loadedMap ~= nil and AutoDrive.adXml ~= nil then
                    removeXMLProperty(AutoDrive.adXml, "AutoDrive." .. AutoDrive.loadedMap .. ".waypoints.wp".. startNode.id ..".out" .. i) ;
                    removeXMLProperty(AutoDrive.adXml, "AutoDrive." .. AutoDrive.loadedMap .. ".waypoints.wp".. startNode.id ..".out_cost" .. i) ;
                end;

                local incomingExists = false;
                for _,i2 in pairs(targetNode.incoming) do
                    if i2 == startNode.id or incomingExists then
                        incomingExists = true;
                        if targetNode.incoming[_ + 1] ~= nil then
                            targetNode.incoming[_] = targetNode.incoming[_ + 1];
                            targetNode.incoming[_ + 1] = nil;
                        else
                            targetNode.incoming[_] = nil;
                        end;
                    end;
                end;

                exists = true;
            else
                out_counter = out_counter +1;
            end;
        end;
    end;
       
    if exists == false then
        startNode.out[out_counter] = targetNode.id;
        startNode.out_cost[out_counter] = 1;

        local incomingCounter = 1;
        for _,id in pairs(targetNode.incoming) do
            incomingCounter = incomingCounter + 1;
        end;
        targetNode.incoming[incomingCounter] = startNode.id;

        AutoDrive:MarkChanged()
    end;				
end;

function AutoDrive:nextSelectedDebugPoint(vehicle)
    vehicle.ad.selectedDebugPoint = vehicle.ad.selectedDebugPoint + 1;
    if vehicle.ad.iteratedDebugPoints[vehicle.ad.selectedDebugPoint] == nil then
        vehicle.ad.selectedDebugPoint = 1;
    end;
end;

function AutoDrive:finishCreatingMapMarker(vehicle)
    local closest = AutoDrive:findClosestWayPoint(vehicle);
    AutoDrive.mapMarkerCounter = AutoDrive.mapMarkerCounter + 1;
    local node = createTransformGroup(vehicle.ad.enteredMapMarkerString);
    setTranslation(node, AutoDrive.mapWayPoints[closest].x, AutoDrive.mapWayPoints[closest].y + 4 , AutoDrive.mapWayPoints[closest].z  );

    AutoDrive.mapMarker[AutoDrive.mapMarkerCounter] = {id=closest, name= vehicle.ad.enteredMapMarkerString, node=node};
    vehicle.ad.creatingMapMarker = false;
    AutoDrive:MarkChanged();
    g_currentMission.isPlayerFrozen = false;
    vehicle.isBroken = false;    
    vehicle.ad.enteringMapMarker = false;
    g_inputBinding:revertContext(true);
end;

function AutoDrive:inputShowNeighbors(vehicle)
    if vehicle.ad.showSelectedDebugPoint == false then
        vehicle.ad.showSelectedDebugPoint = true;

        local debugCounter = 1;

        local x1,y1,z1 = getWorldTranslation(vehicle.components[1].node);
        for i,point in pairs(AutoDrive.mapWayPoints) do
            local distance = getDistance(point.x,point.z,x1,z1);

            if distance < 15 then
                vehicle.ad.iteratedDebugPoints[debugCounter] = point;
                debugCounter = debugCounter + 1;
            end;
        end;
        vehicle.ad.selectedDebugPoint = 2;

        vehicle.ad.iteratedDebugPoints = AutoDrive:sortNodesByDistance(x1, z1, vehicle.ad.iteratedDebugPoints);
        
        local leastIncomingRoads = 1;
        local nodeWithLeastIncomingRoads = nil;        
        for i,point in pairs(vehicle.ad.iteratedDebugPoints) do
            if ADTableLength(point.incoming) < leastIncomingRoads then
                leastIncomingRoads = ADTableLength(point.incoming);
                nodeWithLeastIncomingRoads = i;
            end;
        end;
        
        if nodeWithLeastIncomingRoads ~= nil then
            vehicle.ad.selectedDebugPoint = nodeWithLeastIncomingRoads;
        end;
    else
        vehicle.ad.showSelectedDebugPoint = false;
    end;
        
    AutoDrive.Hud:updateSingleButton("input_showNeighbor", vehicle.ad.showSelectedDebugPoint)
end;

function AutoDrive:inputCreateMapMarker(vehicle)
    if vehicle.ad.showMapMarker == true then
        if vehicle.ad.creatingMapMarker == false then
            vehicle.ad.creatingMapMarker  = true;
            vehicle.ad.enteringMapMarker = true;
            vehicle.ad.enteredMapMarkerString = "" .. AutoDrive.mapWayPointsCounter;
            g_currentMission.isPlayerFrozen = true;
            vehicle.isBroken = true;				
            g_inputBinding:setContext("AutoDrive.Input_MapMarker", true, false);
        else
            vehicle.ad.creatingMapMarker  = false;
            vehicle.ad.enteringMapMarker = false;
            vehicle.ad.enteredMapMarkerString = "";
            g_currentMission.isPlayerFrozen = false;
            vehicle.isBroken = false;
            g_inputBinding:revertContext(true);
        end;
    end;
end;