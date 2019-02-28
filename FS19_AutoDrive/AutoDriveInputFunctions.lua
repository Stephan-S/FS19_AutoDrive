function AutoDrive:InputHandling(vehicle, input)
	--print("AutoDrive InputHandling.." .. input);
	vehicle.ad.currentInput = input;
	if vehicle.ad.currentInput == nil then
		return;
	end;

	if g_server == nil then
		AutoDrive:InputHandlingClientOnly(vehicle, input)	
	end;

	AutoDrive:InputHandlingClientAndServer(vehicle, input)	

	if g_server == nil then
		if vehicle.ad.currentInput ~= nil then
			AutoDriveUpdateEvent:sendEvent(vehicle);
		end;
		return;
	end;		

	AutoDrive:InputHandlingServerOnly(vehicle, input)

	vehicle.ad.currentInput = "";
end;

function AutoDrive:InputHandlingClientOnly(vehicle, input)
	if input == "input_uploadRoutes" then
		local user = g_currentMission.userManager:getUserByUserId(g_currentMission.playerUserId);
		if user:getIsMasterUser() then
			print("User is admin and allowed to upload course");
			AutoDrive.playerSendsMapToServer = true;
			AutoDrive.requestedWaypointCount = 1;
		else
			print("User is no admin and is not allowed to upload course");
		end;
	end;	

	if input == "input_recalculate" then --make sure the hud button shows active recalculation when server is busy
		AutoDrive.Recalculation.continue = true;
	end;
end

function AutoDrive:InputHandlingClientAndServer(vehicle, input)
	if input == "input_createMapMarker" and (g_dedicatedServerInfo == nil) then
		AutoDrive:inputCreateMapMarker(vehicle);
	end;

	if input == "input_start_stop" then
		if AutoDrive.mapWayPoints == nil or AutoDrive.mapWayPoints[1] == nil or vehicle.ad.targetSelected == -1 then
			return;
		end;
		if AutoDrive:isActive(vehicle) then
			AutoDrive:disableAutoDriveFunctions(vehicle)
			--AutoDrive:stopAD(vehicle);
		else
			AutoDrive:startAD(vehicle);
		end;

		AutoDrive.Hud:updateSingleButton("input_start_stop", vehicle.ad.isActive)
	end;

	if input == "input_exportRoutes" then
		AutoDrive:ExportRoutes();
	end;

	if input == "input_importRoutes" then
		AutoDrive:ImportRoutes();
	end;
	
	if input == "input_toggleHud" then
		AutoDrive.Hud:toggleHud(vehicle);				
	end;

	if input == "input_toggleMouse" then
		AutoDrive.Hud:toggleMouse(vehicle);				
	end;
end;

function AutoDrive:InputHandlingServerOnly(vehicle, input)	
	if input == "input_silomode" then
		AutoDrive:inputSiloMode(vehicle);
	end;

	if input == "input_record" then
		AutoDrive:inputRecord(vehicle)
	end;
	
	if input == "input_nextTarget" then
		AutoDrive:inputNextTarget(vehicle)
	end;

	if input == "input_previousTarget" then
		AutoDrive:inputPreviousTarget(vehicle)
	end;

	if input == "input_debug"  then
		if vehicle.ad.createMapPoints == false then
			vehicle.ad.createMapPoints = true;
		else
			vehicle.ad.createMapPoints = false;
		end;

		AutoDrive.Hud:updateSingleButton("input_debug", vehicle.ad.createMapPoints)
	end;

	if input == "input_showClosest" then
		AutoDrive:inputShowClosest(vehicle);

		AutoDrive.Hud:updateSingleButton("input_showClosest", vehicle.ad.showClosestPoint)
	end;

	if input == "input_showNeighbor" then
		AutoDrive:inputShowNeighbors(vehicle)		
	end;

	if input == "input_toggleConnection" then
		local closest = AutoDrive:findClosestWayPoint(vehicle);
		AutoDrive:toggleConnectionBetween(AutoDrive.mapWayPoints[closest], vehicle.ad.iteratedDebugPoints[vehicle.ad.selectedDebugPoint]);
	end;

	if input == "input_nextNeighbor" then
		AutoDrive:nextSelectedDebugPoint(vehicle);
	end;	

	if input == "input_increaseSpeed" then
		if vehicle.ad.targetSpeed < 100 then
			vehicle.ad.targetSpeed = vehicle.ad.targetSpeed + 1;
		end;
	end;

	if input == "input_decreaseSpeed" then
		if vehicle.ad.targetSpeed > 2 then
			vehicle.ad.targetSpeed = vehicle.ad.targetSpeed - 1;
		end;

	end;	

	if input == "input_removeWaypoint" then
		if vehicle.ad.showClosestPoint == true and AutoDrive.mapWayPoints[1] ~= nil then
			local closest = AutoDrive:findClosestWayPoint(vehicle)
			AutoDrive:removeMapWayPoint( AutoDrive.mapWayPoints[closest] );
		end;

	end;

	if input == "input_removeDestination" then
		if vehicle.ad.showClosestPoint == true and AutoDrive.mapWayPoints[1] ~= nil then
			local closest = AutoDrive:findClosestWayPoint(vehicle)
			AutoDrive:removeMapMarker( AutoDrive.mapWayPoints[closest] );
		end;
	end;

	if input == "input_recalculate" then
		AutoDrive:ContiniousRecalculation();
	end;	

	if input == "input_nextTarget_Unload" then
		if  AutoDrive.mapMarker[1] ~= nil and AutoDrive.mapWayPoints[1] ~= nil then
			if vehicle.ad.mapMarkerSelected_Unload == -1 then
				vehicle.ad.mapMarkerSelected_Unload = 1

				vehicle.ad.targetSelected_Unload = AutoDrive.mapMarker[vehicle.ad.mapMarkerSelected_Unload].id;

				vehicle.ad.nameOfSelectedTarget_Unload = AutoDrive.mapMarker[vehicle.ad.mapMarkerSelected_Unload].name;
			else
				vehicle.ad.mapMarkerSelected_Unload = vehicle.ad.mapMarkerSelected_Unload + 1;
				if vehicle.ad.mapMarkerSelected_Unload > AutoDrive.mapMarkerCounter then
					vehicle.ad.mapMarkerSelected_Unload = 1;
				end;
				vehicle.ad.targetSelected_Unload = AutoDrive.mapMarker[vehicle.ad.mapMarkerSelected_Unload].id;
				vehicle.ad.nameOfSelectedTarget_Unload = AutoDrive.mapMarker[vehicle.ad.mapMarkerSelected_Unload].name;
			end;
		end;

	end;

	if input == "input_previousTarget_Unload" then
		if AutoDrive.mapMarker[1] ~= nil and AutoDrive.mapWayPoints[1] ~= nil then
			if vehicle.ad.mapMarkerSelected_Unload == -1 then
				vehicle.ad.mapMarkerSelected_Unload = AutoDrive.mapMarkerCounter;

				vehicle.ad.targetSelected_Unload = AutoDrive.mapMarker[vehicle.ad.mapMarkerSelected_Unload].id;
				vehicle.ad.nameOfSelectedTarget_Unload = AutoDrive.mapMarker[vehicle.ad.mapMarkerSelected_Unload].name;
			else
				vehicle.ad.mapMarkerSelected_Unload = vehicle.ad.mapMarkerSelected_Unload - 1;
				if vehicle.ad.mapMarkerSelected_Unload < 1 then
					vehicle.ad.mapMarkerSelected_Unload = AutoDrive.mapMarkerCounter;
				end;
				vehicle.ad.targetSelected_Unload = AutoDrive.mapMarker[vehicle.ad.mapMarkerSelected_Unload].id;
				vehicle.ad.nameOfSelectedTarget_Unload = AutoDrive.mapMarker[vehicle.ad.mapMarkerSelected_Unload].name;
			end;
		end;
	end;

	if input == "input_nextFillType" then		
		vehicle.ad.unloadFillTypeIndex = vehicle.ad.unloadFillTypeIndex + 1;
		if g_fillTypeManager:getFillTypeByIndex(vehicle.ad.unloadFillTypeIndex) == nil then
			vehicle.ad.unloadFillTypeIndex = 2;
		end;		
	end;

	if input == "input_previousFillType" then
		vehicle.ad.unloadFillTypeIndex = vehicle.ad.unloadFillTypeIndex - 1;
		if vehicle.ad.unloadFillTypeIndex <= 1 then
			while g_fillTypeManager:getFillTypeByIndex(vehicle.ad.unloadFillTypeIndex) ~= nil do 
				vehicle.ad.unloadFillTypeIndex = vehicle.ad.unloadFillTypeIndex + 1;
			end;
			vehicle.ad.unloadFillTypeIndex = vehicle.ad.unloadFillTypeIndex - 1;
		end;
	end;

	if input == "input_continue" then
		if vehicle.ad.isPaused == true then
			vehicle.ad.isPaused = false;
		end;
	end;
end;

function AutoDrive:inputSiloMode(vehicle)
    vehicle.ad.mode = vehicle.ad.mode + 1;
    if vehicle.ad.mode > AutoDrive.MODE_DELIVERTO then
        vehicle.ad.mode = 1;
    end;
    AutoDrive:enableCurrentMode(vehicle);
end;

function AutoDrive:enableCurrentMode(vehicle)
    if vehicle.ad.mode == AutoDrive.MODE_DRIVETO then
        vehicle.ad.drivingForward = true;
    elseif vehicle.ad.mode == AutoDrive.MODE_DELIVERTO then
        vehicle.ad.drivingForward = true;
    elseif vehicle.ad.mode == AutoDrive.MODE_PICKUPANDDELIVER then
        vehicle.ad.drivingForward = true;  
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
            vehicle.ad.nameOfSelectedTarget = AutoDrive.mapMarker[vehicle.ad.mapMarkerSelected].name;
        else
            vehicle.ad.mapMarkerSelected = vehicle.ad.mapMarkerSelected + 1;
            if vehicle.ad.mapMarkerSelected > AutoDrive.mapMarkerCounter then
                vehicle.ad.mapMarkerSelected = 1;
            end;
            vehicle.ad.targetSelected = AutoDrive.mapMarker[vehicle.ad.mapMarkerSelected].id;
            vehicle.ad.nameOfSelectedTarget = AutoDrive.mapMarker[vehicle.ad.mapMarkerSelected].name;            
        end;
    end;
end;

function AutoDrive:inputPreviousTarget(vehicle)
    if AutoDrive.mapMarker[1] ~= nil and AutoDrive.mapWayPoints[1] ~= nil then
        if vehicle.ad.mapMarkerSelected == -1 then
            vehicle.ad.mapMarkerSelected = AutoDrive.mapMarkerCounter;

            vehicle.ad.targetSelected = AutoDrive.mapMarker[vehicle.ad.mapMarkerSelected].id;
            vehicle.ad.nameOfSelectedTarget = AutoDrive.mapMarker[vehicle.ad.mapMarkerSelected].name;
        else
            vehicle.ad.mapMarkerSelected = vehicle.ad.mapMarkerSelected - 1;
            if vehicle.ad.mapMarkerSelected < 1 then
                vehicle.ad.mapMarkerSelected = AutoDrive.mapMarkerCounter;
            end;
            vehicle.ad.targetSelected = AutoDrive.mapMarker[vehicle.ad.mapMarkerSelected].id;
            vehicle.ad.nameOfSelectedTarget = AutoDrive.mapMarker[vehicle.ad.mapMarkerSelected].name;
        end;
    end;
end;

function AutoDrive:toggleConnectionBetween(startNode, targetNode)
    local out_counter = 1;
    local exists = false;
    for i in pairs(startNode.out) do
        if exists == true then
            startNode.out[out_counter] = startNode.out[i];
            out_counter = out_counter +1;
        else
            if startNode.out[i] == targetNode.id then
                AutoDrive:MarkChanged()
                startNode.out[i] = nil;

                if AutoDrive.loadedMap ~= nil and AutoDrive.adXml ~= nil then
                    removeXMLProperty(AutoDrive.adXml, "AutoDrive." .. AutoDrive.loadedMap .. ".waypoints.wp".. startNode.id ..".out" .. i) ;
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

        local incomingCounter = 1;
        for _,id in pairs(targetNode.incoming) do
            incomingCounter = incomingCounter + 1;
        end;
        targetNode.incoming[incomingCounter] = startNode.id;

        AutoDrive:MarkChanged()
    end;		

    AutoDriveCourseEditEvent:sendEvent(startNode);
    AutoDriveCourseEditEvent:sendEvent(targetNode);		
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
    
    if g_server ~= nil then
        AutoDrive:broadCastUpdateToClients();
    else
        AutoDriveCreateMapMarkerEvent:sendEvent(vehicle, closest, vehicle.ad.enteredMapMarkerString);
	end;
end;

function AutoDrive:inputShowNeighbors(vehicle)
    if vehicle.ad.showSelectedDebugPoint == false then
        vehicle.ad.showSelectedDebugPoint = true;

        local debugCounter = 1;

        local x1,y1,z1 = getWorldTranslation(vehicle.components[1].node);
        for i,point in pairs(AutoDrive.mapWayPoints) do
            local distance = AutoDrive:getDistance(point.x,point.z,x1,z1);

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

function AutoDrive:inputShowClosest(vehicle)
    vehicle.ad.showClosestPoint = not vehicle.ad.showClosestPoint;
end;

function AutoDrive:inputCreateMapMarker(vehicle)
    if AutoDrive:findClosestWayPoint(vehicle) == nil then
        return;
    end;
    if vehicle.ad.showClosestPoint == true then
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