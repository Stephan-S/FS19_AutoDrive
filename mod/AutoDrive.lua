AutoDrive = {};
AutoDrive.Version = "1.0.0.0";
AutoDrive.config_changed = false;

AutoDrive.directory = g_currentModDirectory;
AutoDrive.actions   = { 'ADToggleMouse', 'ADToggleHud'}

function string:split(sep)
    local sep, fields = sep or ":", {}
    local pattern = string.format("([^%s]+)", sep)
    self:gsub(pattern, function(c) fields[#fields+1] = c end)
    return fields
end

function AutoDrive:prerequisitesPresent(specializations)
    return true;
end;

function AutoDrive.registerEventListeners(vehicleType)    
	for _,n in pairs( { "load", "onUpdate", "onRegisterActionEvents", "onDelete", "onDraw" } ) do
	  SpecializationUtil.registerEventListener(vehicleType, n, AutoDrive)
	end 
end

function AutoDrive:onRegisterActionEvents(isSelected, isOnActiveVehicle)   
	-- continue on client side only
	if not self.isClient then
		return
	end
  
	-- only in active vehicle
	if isOnActiveVehicle then
		-- we could have more than one event, so prepare a table to store them  
		if self.ActionEvents == nil then 
		  self.ActionEvents = {}
		else  
		  self:clearActionEventsTable( self.ActionEvents )
		end 

		-- attach our actions
			local __, eventName
			local toggleButton = false;
			__, eventName = InputBinding.registerActionEvent(g_inputBinding, 'ADToggleMouse', self, AutoDrive.onActionCall, toggleButton ,true ,false ,true)
			--print("Registered ADToggleMouse as " .. eventName)
			g_inputBinding:setActionEventTextVisibility(eventName, true)	
			__, eventName = InputBinding.registerActionEvent(g_inputBinding, 'ADToggleHud', self, AutoDrive.onActionCall, toggleButton ,true ,false ,true)
			--print("Registered ADToggleHud as " .. eventName)
			g_inputBinding:setActionEventTextVisibility(eventName, true)		
	end
end

AIVehicleUtil.driveInDirection = function (self, dt, steeringAngleLimit, acceleration, slowAcceleration, slowAngleLimit, allowedToDrive, moveForwards, lx, lz, maxSpeed, slowDownFactor)

	local angle = 0;
    if lx ~= nil and lz ~= nil then
        local dot = lz;
		angle = math.deg(math.acos(dot));
        if angle < 0 then
            angle = angle+180;
        end
        local turnLeft = lx > 0.00001;
        if not moveForwards then
            turnLeft = not turnLeft;
        end
        local targetRotTime = 0;
        if turnLeft then
            --rotate to the left
			targetRotTime = self.maxRotTime*math.min(angle/steeringAngleLimit, 1);
        else
            --rotate to the right
			targetRotTime = self.minRotTime*math.min(angle/steeringAngleLimit, 1);
		end
		if targetRotTime > self.rotatedTime then
			self.rotatedTime = math.min(self.rotatedTime + dt*self:getAISteeringSpeed(), targetRotTime);
		else
			self.rotatedTime = math.max(self.rotatedTime - dt*self:getAISteeringSpeed(), targetRotTime);
		end
    end
    if self.firstTimeRun then
        local acc = acceleration;
        if maxSpeed ~= nil and maxSpeed ~= 0 then
            if math.abs(angle) >= slowAngleLimit then
                maxSpeed = maxSpeed * slowDownFactor;
            end
            self.spec_motorized.motor:setSpeedLimit(maxSpeed);
            if self.spec_drivable.cruiseControl.state ~= Drivable.CRUISECONTROL_STATE_ACTIVE then
                self:setCruiseControlState(Drivable.CRUISECONTROL_STATE_ACTIVE);
            end
        else
            if math.abs(angle) >= slowAngleLimit then
                acc = slowAcceleration;
            end
        end
        if not allowedToDrive then
            acc = 0;
        end
        if not moveForwards then
            acc = -acc;
        end
		--FS 17 Version WheelsUtil.updateWheelsPhysics(self, dt, self.lastSpeedReal, acc, not allowedToDrive, self.requiredDriveMode);
		WheelsUtil.updateWheelsPhysics(self, dt, self.lastSpeedReal*self.movingDirection, acc, not allowedToDrive, true)
    end
end

function AutoDrive:onDelete()	
end;

function AutoDrive:MarkChanged()
	AutoDrive.config_changed = true;
	AutoDrive.handledRecalculation = false;
end;

function AutoDrive:GetChanged()
	return AutoDrive.config_changed;
end;

function AutoDrive:loadMap(name)
	if AutoDrive_printedDebug ~= true then
		--DebugUtil.printTableRecursively(g_currentMission, "	:	",0,2);
		print("Map title: " .. g_currentMission.missionInfo.map.title);
		if g_currentMission.missionInfo.savegameDirectory ~= nil then 
			print("Savegame location: " .. g_currentMission.missionInfo.savegameDirectory);
		else
			if g_currentMission.missionInfo.savegameIndex ~= nil then
				print("Savegame location via index: " .. getUserProfileAppPath() .. "savegame" .. g_currentMission.missionInfo.savegameIndex);
			else
				print("No savegame located");
			end;
		end;
		
		AutoDrive_printedDebug = true;
	end;
	
	AutoDrive.loadedMap = g_currentMission.missionInfo.map.title;
	AutoDrive.loadedMap = string.gsub(AutoDrive.loadedMap, " ", "_");
	AutoDrive.loadedMap = string.gsub(AutoDrive.loadedMap, "%.", "_");	
	print("map " .. AutoDrive.loadedMap .. " was loaded");		
		
	AutoDrive.mapWayPoints = {};
	AutoDrive.mapWayPointsCounter = 0;
	AutoDrive.mapMarker = {};
	AutoDrive.mapMarkerCounter = 0;
	AutoDrive.showMouse = false;					
		
	AutoDrive.Hud = AutoDriveHud:new();
	AutoDrive.Hud:loadHud();

	AutoDrive.Triggers = {};
	AutoDrive.Triggers.tipTriggers = {};
	AutoDrive.Triggers.siloTriggers = {};

	for _,trigger in pairs(g_currentMission.tipTriggers) do
		local triggerLocation = {};
		local x,y,z = getWorldTranslation(trigger.rootNode);
		triggerLocation.x = x;
		triggerLocation.y = y;
		triggerLocation.z = z;
		print("trigger: " .. trigger.stationName .. " pos: " .. x .. "/" .. y .. "/" .. z);
	end;
end;

function init(self)
	self.bDisplay = 1; 
	if self.ad == nil then
		self.ad = {};		
	end;
	
	self.bLongFormat = 0; 
	self.nSubStringLength = 40; 
	self.bDarkColor = 0; 
	self.nDebugOutput = 0; 
	self.bActive = false;
	self.bRoundTrip = false;
	self.bReverseTrack = false;
	self.bDrivingForward = true;
	self.nTargetX = 0;
	self.nTargetZ = 0;
	self.bInitialized = false;
	self.ad.wayPoints = {};
	self.bcreateMode = false;
	self.bcreateModeDual = false;
	self.nCurrentWayPoint = 0;
	self.nlastLogged = 0;
	self.nloggingInterval = 500;
	self.logMessage = "";
	self.nPrintTime = 3000;
	self.ntargetSelected = -1;	
	self.nMapMarkerSelected = -1;
	self.sTargetSelected = "";
	if AutoDrive ~= nil then
		if AutoDrive.mapMarker[1] ~= nil then
			self.ntargetSelected = AutoDrive.mapMarker[1].id;
			self.nMapMarkerSelected = 1;
			self.sTargetSelected = AutoDrive.mapMarker[1].name;
			local translation = AutoDrive:translate(sTargetSelected);
			sTargetSelected = translation;
		end;	
	end;
	self.bTargetMode = true;
	self.nSpeed = 40;
	self.bCreateMapPoints = false;
	self.bShowDebugMapMarker = true;
	self.nSelectedDebugPoint = -1;
	self.bShowSelectedDebugPoint = false;
	self.bChangeSelectedDebugPoint = false;
	self.DebugPointsIterated = {};
	self.bDeadLock = false;
	self.nTimeToDeadLock = 15000;
	self.bDeadLockRepairCounter = 4;
	
	self.bStopAD = false;
	self.bCreateMapMarker = false;
	self.bEnteringMapMarker = false;
	self.sEnteredMapMarkerString = "";
	
	
	self.name = g_i18n:getText("UNKNOWN")
	self.moduleInitialized = true;
	self.currentInput = "";
	self.previousSpeed = self.nSpeed;
	self.speed_override = nil;

	self.requestWayPointTimer = 10000;

	self.bUnloadAtTrigger = false;
	self.bUnloading = false;
	self.bPaused = false;
	self.bUnloadSwitch = false;
	self.unloadType = -1;
	self.bLoading = false;
	self.trailertipping = -1;

	AutoDrive.Recalculation = {};

	self.ntargetSelected_Unload = -1;
	self.nMapMarkerSelected_Unload = -1;
	self.sTargetSelected_Unload = "";
	if AutoDrive ~= nil then
		if AutoDrive.mapMarker[1] ~= nil then
			self.ntargetSelected_Unload = AutoDrive.mapMarker[1].id;
			self.nMapMarkerSelected_Unload = 1;
			self.sTargetSelected_Unload = AutoDrive.mapMarker[1].name;
			local translation = AutoDrive:translate(sTargetSelected_Unload);
			sTargetSelected_Unload = translation;
		end;
	end;

	self.nPauseTimer = 5000;
	self.ad.nToolTipWait = 300;
	self.ad.nToolTipTimer = 6000;
	self.ad.sToolTip = "";
	
	self.bChoosingDestination = false;
	self.sChosenDestination = "";
	self.sEnteredChosenDestination = "";
end;

function AutoDrive:onActionCall(actionName, keyStatus, arg4, arg5, arg6)
	print("AutoDrive onActionCall.." .. actionName);
	--self.printMessage = "Vehicle: " .. self.name;
		--self.nPrintTime = 3000;

		if actionName == "ADSilomode" then			
			--print("sending event to InputHandling");
			AutoDrive:InputHandling(self, "input_silomode");
		end;
		if actionName == "ADRoundtrip" then
			AutoDrive:InputHandling(self, "input_roundtrip");			
		end; 
		
		if actionName == "ADRecord" then
			AutoDrive:InputHandling(self, "input_record");			
		end; 
		
		if actionName == "ADEnDisable" then
			AutoDrive:InputHandling(self, "input_start_stop");			
		end; 
		
		if actionName ==  "ADSelectTarget" then
			AutoDrive:InputHandling(self, "input_nextTarget");			
		end; 
		
		if actionName == "ADSelectPreviousTarget" then
			AutoDrive:InputHandling(self, "input_previousTarget");
		end;

		if actionName == "ADSelectTargetMouseWheel" and AutoDrive.showMouse then
			AutoDrive:InputHandling(self, "input_nextTarget");
		end;

		if actionName == "ADSelectPreviousTargetMouseWheel" and AutoDrive.showMouse then
			AutoDrive:InputHandling(self, "input_previousTarget");
		end;
		
		if actionName == "ADActivateDebug" then 
			AutoDrive:InputHandling(self, "input_debug");			
		end; 
		
		if actionName == "ADDebugShowClosest"  then 
			AutoDrive:InputHandling(self, "input_showNeighbor");			
		end; 
		
		if actionName == "ADDebugSelectNeighbor" then 
			AutoDrive:InputHandling(self, "input_showNeighbor");			
		end; 
		if actionName == "ADDebugCreateConnection" then 
			AutoDrive:InputHandling(self, "input_toggleConnection");			
		end; 
		if actionName == "ADDebugChangeNeighbor" then 
			AutoDrive:InputHandling(self, "input_nextNeighbor");			
		end; 
		if actionName == "ADDebugCreateMapMarker" then 
			AutoDrive:InputHandling(self, "input_createMapMarker");			
		end; 
		
		if actionName == "AD_Speed_up" then 
			AutoDrive:InputHandling(self, "input_increaseSpeed");			
		end;
		
		if actionName == "AD_Speed_down" then 
			AutoDrive:InputHandling(self, "input_decreaseSpeed");			
		end;
		
		if actionName == "ADToggleHud" then 
			AutoDrive:InputHandling(self, "input_toggleHud");			
		end;

		if actionName == "ADToggleMouse" then
			AutoDrive:InputHandling(self, "input_toggleMouse");
		end;

		if actionName == "ADDebugDeleteWayPoint" then 
			AutoDrive:InputHandling(self, "input_removeWaypoint");
		end;
		if actionName == "AD_export_routes" then
			AutoDrive:InputHandling(self, "input_exportRoutes");
		end;
		if actionName == "AD_import_routes" then
			AutoDrive:InputHandling(self, "input_importRoutes");
		end;
		if actionName == "ADDebugDeleteDestination" then
			AutoDrive:InputHandling(self, "input_removeDestination");
		end;
end;

function AutoDrive:deleteMap()
	
	--print("delete map called");
	
	if AutoDrive:GetChanged() == true and g_server ~= nil then
	
		if AutoDrive.adXml ~= nil then
			local adXml = AutoDrive.adXml;
			
			setXMLString(adXml, "AutoDrive.Version", AutoDrive.Version);
			if AutoDrive.handledRecalculation ~= true then
				setXMLString(adXml, "AutoDrive.Recalculation", "true");	
				print("AD: Set to recalculating routes");

			else
				setXMLString(adXml, "AutoDrive.Recalculation", "false");
				print("AD: Set to not recalculating routes");
			end;
			
			
			local idFullTable = {};
			local idString = "";
			
			local xTable = {};
			local xString = "";
			
			local yTable = {};
			local yString = "";
			
			local zTable = {};
			local zString = "";
			
			local outTable = {};
			local outString = "";
			
			local incomingTable = {};
			local incomingString = "";
			
			local out_costTable = {};
			local out_costString = "";
			
			local markerNamesTable = {};
			local markerNames = "";
			
			local markerIDsTable = {};
			local markerIDs = "";
			
			for i,p in pairs(AutoDrive.mapWayPoints) do
			
				--idString = idString .. p.id .. ",";
				idFullTable[i] = p.id;
				--xString = xString .. p.x .. ",";
				xTable[i] = p.x;
				--yString = yString .. p.y .. ",";
				yTable[i] = p.y;
				--zString = zString .. p.z .. ",";
				zTable[i] = p.z;
				
				--outString = outString .. table.concat(p.out, ",") .. ";";
				outTable[i] = table.concat(p.out, ",");
					
				local innerIncomingTable = {};
				local innerIncomingCounter = 1;
				for i2, p2 in pairs(AutoDrive.mapWayPoints) do
					for i3, out2 in pairs(p2.out) do
						if out2 == p.id then
							innerIncomingTable[innerIncomingCounter] = p2.id;
							innerIncomingCounter = innerIncomingCounter + 1;
							--incomingString = incomingString .. p2.id .. ",";
						end;
					end;
				end;
				incomingTable[i] = table.concat(innerIncomingTable, ",");
				--incomingString = incomingString .. ";";
				
				out_costTable[i] = table.concat(p.out_cost, ",");
				--out_costString = out_costString .. table.concat(p.out_cost, ",") .. ";";
					
				local markerCounter = 1;
				local innerMarkerNamesTable = {};
				local innerMarkerIDsTable = {};
				for i2,marker in pairs(p.marker) do
					innerMarkerIDsTable[markerCounter] = marker;
					--markerIDs = markerIDs .. marker .. ",";
					innerMarkerNamesTable[markerCounter] = i2;
					--markerNames = markerNames .. i2 .. ",";
					markerCounter = markerCounter + 1;
				end;
				markerNamesTable[i] = table.concat(innerMarkerNamesTable, ",");
				markerIDsTable[i] = table.concat(innerMarkerIDsTable, ",");
				
				--markerIDs = markerIDs .. ";";
				--markerNames = markerNames .. ";";
			end;
			
			if idFullTable[1] ~= nil then
							
				setXMLString(adXml, "AutoDrive." .. self.loadedMap .. ".waypoints.id" , table.concat(idFullTable, ",") );
				setXMLString(adXml, "AutoDrive." .. self.loadedMap .. ".waypoints.x" , table.concat(xTable, ","));
				setXMLString(adXml, "AutoDrive." .. self.loadedMap .. ".waypoints.y" , table.concat(yTable, ","));
				setXMLString(adXml, "AutoDrive." .. self.loadedMap .. ".waypoints.z" , table.concat(zTable, ","));
				setXMLString(adXml, "AutoDrive." .. self.loadedMap .. ".waypoints.out" , table.concat(outTable, ";"));
				setXMLString(adXml, "AutoDrive." .. self.loadedMap .. ".waypoints.incoming" , table.concat(incomingTable, ";") );
				setXMLString(adXml, "AutoDrive." .. self.loadedMap .. ".waypoints.out_cost" , table.concat(out_costTable, ";"));
				if markerIDsTable[1] ~= nil then
					setXMLString(adXml, "AutoDrive." .. self.loadedMap .. ".waypoints.markerID" , table.concat(markerIDsTable, ";"));
					setXMLString(adXml, "AutoDrive." .. self.loadedMap .. ".waypoints.markerNames" , table.concat(markerNamesTable, ";"));
				end;
			end;
			
			for i in pairs(AutoDrive.mapMarker) do
		
				setXMLFloat(adXml, "AutoDrive." .. self.loadedMap .. ".mapmarker.mm".. i ..".id", AutoDrive.mapMarker[i].id);
				setXMLString(adXml, "AutoDrive." .. self.loadedMap .. ".mapmarker.mm".. i ..".name", AutoDrive.mapMarker[i].name);			
			
			end;
			
			saveXMLFile(adXml);
		end;
	end;
	
end;

function AutoDrive:InputHandling(vehicle, input)

	vehicle.currentInput = input;

	if g_server ~= nil then
		--print("received event in InputHandling. event: " .. input);
	else
		--print("Not the server - sending event to server " .. input);
		AutoDriveInputEvent:sendEvent(vehicle);
	end;

	if vehicle.currentInput ~= nil then
		--print("Checking if vehicle is currently controlled." .. input);
		if vehicle == g_currentMission.controlledVehicle then
			--print("Executing InputHandling with input: " .. input);
			--print("correct vehicle");
			if input == "input_silomode" then

				--DebugUtil.printTableRecursively(g_currentMission.tipTriggers, ":",0,2);
				--DebugUtil.printTableRecursively(g_currentMission.siloTriggers, ":",0,2);

				if vehicle.bTargetMode == true and vehicle.bUnloadAtTrigger == false then
					if g_server ~= nil and g_dedicatedServerInfo == nil then
						vehicle.bReverseTrack = true;
						vehicle.bDrivingForward = true;
						vehicle.bTargetMode = false;
						vehicle.bRoundTrip = false;
						vehicle.savedSpeed = vehicle.nSpeed;
						vehicle.nSpeed = 15;
						vehicle.bUnloadAtTrigger = false;
					else
						vehicle.bReverseTrack = false;
						vehicle.bDrivingForward = true;
						vehicle.bTargetMode = true;
						vehicle.bRoundTrip = false;
						vehicle.bUnloadAtTrigger = true;

						if vehicle.savedSpeed ~= nil then
							vehicle.nSpeed = vehicle.savedSpeed;
							vehicle.savedSpeed = nil;
						end;
					end;
				else
					if vehicle.bReverseTrack == true then
						vehicle.bReverseTrack = false;
						vehicle.bDrivingForward = true;
						vehicle.bTargetMode = true;
						vehicle.bRoundTrip = false;
						vehicle.bUnloadAtTrigger = true;

						if vehicle.savedSpeed ~= nil then
							vehicle.nSpeed = vehicle.savedSpeed;
							vehicle.savedSpeed = nil;
						end;


					else
						if vehicle.bTargetMode == true and vehicle.bUnloadAtTrigger == true then
							vehicle.bReverseTrack = false;
							vehicle.bDrivingForward = true;
							vehicle.bTargetMode = true;
							vehicle.bRoundTrip = false;
							vehicle.bUnloadAtTrigger = false;
							if vehicle.savedSpeed ~= nil then
								vehicle.nSpeed = vehicle.savedSpeed;
								vehicle.savedSpeed = nil;
							end;
						end;
					end;
				end;
			end;

			if input == "input_roundtrip" then
				if vehicle.bRoundTrip == false then
					vehicle.bRoundTrip = true;
					vehicle.nSpeed = 40;
					vehicle.bTargetMode = false;
					vehicle.bReverseTrack = false;
					--print("roundTrip = true");
					vehicle.printMessage = g_i18n:getText("AD_Roundtrip_on");
					vehicle.nPrintTime = 3000;

				else
					vehicle.bRoundTrip = false;
					vehicle.printMessage = g_i18n:getText("AD_Roundtrip_off");
					vehicle.nPrintTime = 3000;
				end;

			end;

			if input == "input_record" and g_server ~= nil and g_dedicatedServerInfo == nil then
				if vehicle.bcreateMode == false then
					vehicle.bcreateMode = true;
					vehicle.bcreateModeDual = false;
					vehicle.nCurrentWayPoint = 0;
					vehicle.bActive = false;
					vehicle.ad.wayPoints = {};
					vehicle.bTargetMode = false;
				else
					if vehicle.bcreateModeDual == false then
						vehicle.bcreateModeDual = true;
					else
						vehicle.bcreateMode = false;
						vehicle.bcreateModeDual = false;
						input = "input_nextTarget";
					end;
				end;

				AutoDrive.Hud:updateSingleButton("input_record", vehicle.bcreateMode)
			end;

			if input == "input_start_stop" then
				if vehicle.bActive == false then
					vehicle.bActive = true;
					vehicle.bcreateMode = false;
					vehicle.forceIsActive = true;
					vehicle.stopMotorOnLeave = false;
					vehicle.disableCharacterOnLeave = true;

					local trailer = nil;
					if vehicle.attachedImplements ~= nil then
						for _, implement in pairs(vehicle.attachedImplements) do
							if implement.object ~= nil then
								if implement.object.typeDesc == g_i18n:getText("typeDesc_tipper") then -- "tipper" then

									trailer = implement.object;
								end;
							end;
						end;
					end;
					if vehicle.bUnloadAtTrigger == true and trailer ~= nil then
						local fillTable = trailer:getCurrentFillTypes();
						if fillTable[1] ~= nil then
							vehicle.unloadType = fillTable[1];
						end;
					end;

					vehicle.nPrintTime = 3000;
				else
					vehicle.nCurrentWayPoint = 0;
					vehicle.bDrivingForward = true;
					vehicle.bActive = false;
					vehicle.bStopAD = true;
					vehicle.bUnloading = false;
					vehicle.bLoading = false;
				end;

				AutoDrive.Hud:updateSingleButton("input_start_stop", vehicle.bActive)
			end;

			if input == "input_nextTarget" then
				if  AutoDrive.mapMarker[1] ~= nil and AutoDrive.mapWayPoints[1] ~= nil then
					if vehicle.nMapMarkerSelected == -1 then
						vehicle.nMapMarkerSelected = 1

						vehicle.ntargetSelected = AutoDrive.mapMarker[vehicle.nMapMarkerSelected].id;
						if vehicle.nSpeed == 15 then
							vehicle.nSpeed = 40;
						end;
						vehicle.sTargetSelected = AutoDrive.mapMarker[vehicle.nMapMarkerSelected].name;
						vehicle.bTargetMode = true;
						vehicle.bRoundTrip = false;
						vehicle.bReverseTrack = false;
						vehicle.bDrivingForward = true;

					else
						vehicle.nMapMarkerSelected = vehicle.nMapMarkerSelected + 1;
						if vehicle.nMapMarkerSelected > AutoDrive.mapMarkerCounter then
							vehicle.nMapMarkerSelected = 1;
						end;
						vehicle.ntargetSelected = AutoDrive.mapMarker[vehicle.nMapMarkerSelected].id;
						vehicle.sTargetSelected = AutoDrive.mapMarker[vehicle.nMapMarkerSelected].name;
						if vehicle.nSpeed == 15 then
							vehicle.nSpeed = 40;
						end;
						vehicle.bTargetMode = true;
					end;
				end;

			end;

			if input == "input_previousTarget" then
				if AutoDrive.mapMarker[1] ~= nil and AutoDrive.mapWayPoints[1] ~= nil then
					if vehicle.nMapMarkerSelected == -1 then
						vehicle.nMapMarkerSelected = AutoDrive.mapMarkerCounter;

						vehicle.ntargetSelected = AutoDrive.mapMarker[vehicle.nMapMarkerSelected].id;
						if vehicle.nSpeed == 15 then
							vehicle.nSpeed = 40;
						end;
						vehicle.sTargetSelected = AutoDrive.mapMarker[vehicle.nMapMarkerSelected].name;
						vehicle.bTargetMode = true;

					else
						vehicle.nMapMarkerSelected = vehicle.nMapMarkerSelected - 1;
						if vehicle.nMapMarkerSelected < 1 then
							vehicle.nMapMarkerSelected = AutoDrive.mapMarkerCounter;
						end;
						vehicle.ntargetSelected = AutoDrive.mapMarker[vehicle.nMapMarkerSelected].id;
						vehicle.sTargetSelected = AutoDrive.mapMarker[vehicle.nMapMarkerSelected].name;
						if vehicle.nSpeed == 15 then
							vehicle.nSpeed = 40;
						end;
						vehicle.bTargetMode = true;
					end;

				end;
			end;

			if input == "input_debug"  then
				if vehicle.bCreateMapPoints == false then
					vehicle.bCreateMapPoints = true;
				else
					vehicle.bCreateMapPoints = false;
				end;

				AutoDrive.Hud:updateSingleButton("input_debug", vehicle.bCreateMapPoints)
			end;

			if input == "input_showClosest" and g_server ~= nil and g_dedicatedServerInfo == nil then
				if vehicle.bShowDebugMapMarker == false then
					vehicle.bShowDebugMapMarker = true;
				else
					vehicle.bShowDebugMapMarker = false;
				end;

				AutoDrive.Hud:updateSingleButton("input_showClosest", vehicle.bShowDebugMapMarker)
			end;

			if input == "input_showNeighbor" and g_server ~= nil and g_dedicatedServerInfo == nil then
				if vehicle.bShowSelectedDebugPoint == false then
					vehicle.bShowSelectedDebugPoint = true;

					local debugCounter = 1;
					for i,point in pairs(AutoDrive.mapWayPoints) do
						local x1,y1,z1 = getWorldTranslation(vehicle.components[1].node);
						local distance = getDistance(point.x,point.z,x1,z1);

						if distance < 15 then
							vehicle.DebugPointsIterated[debugCounter] = point;
							debugCounter = debugCounter + 1;
						end;
					end;
					vehicle.nSelectedDebugPoint = 1;
				else
					vehicle.bShowSelectedDebugPoint = false;
				end;

				AutoDrive.Hud:updateSingleButton("input_showNeighbor", vehicle.bShowSelectedDebugPoint)
			end;

			if input == "input_toggleConnection" and g_server ~= nil and g_dedicatedServerInfo == nil then
				if vehicle.bChangeSelectedDebugPoint == false then
					vehicle.bChangeSelectedDebugPoint = true;
				else
					vehicle.bChangeSelectedDebugPoint = false;
				end;
			end;

			if input == "input_nextNeighbor" then
				if vehicle.bChangeSelectedDebugPointSelection == false then
					vehicle.bChangeSelectedDebugPointSelection = true;
				else
					vehicle.bChangeSelectedDebugPointSelection = false;
				end;

			end;

			if input == "input_createMapMarker" and g_server ~= nil and g_dedicatedServerInfo == nil then
				if vehicle.bShowDebugMapMarker == true then
					if vehicle.bCreateMapMarker == false then
						vehicle.bCreateMapMarker  = true;
						vehicle.bEnteringMapMarker = true;
						vehicle.sEnteredMapMarkerString = "Test_" .. AutoDrive.mapWayPointsCounter;
						g_currentMission.isPlayerFrozen = true;
						vehicle.isBroken = true;
					else
						vehicle.bCreateMapMarker  = false;
						vehicle.bEnteringMapMarker = false;
						vehicle.sEnteredMapMarkerString = "";
						g_currentMission.isPlayerFrozen = false;
						vehicle.isBroken = false;

						vehicle.printMessages = "Not ready";
						vehicle.nPrintTime = 3000;
					end;
				end;

			end;

			if input == "input_increaseSpeed" then
				if vehicle.nSpeed < 100 then
					vehicle.nSpeed = vehicle.nSpeed + 1;
				end;
			end;

			if input == "input_decreaseSpeed" then
				if vehicle.nSpeed > 2 then
					vehicle.nSpeed = vehicle.nSpeed - 1;
				end;

			end;

			if input == "input_toggleHud" then
				AutoDrive.Hud:toggleHud();				
			end;

			if input == "input_toggleMouse" then
				AutoDrive.Hud:toggleMouse();				
			end;

			if input == "input_removeWaypoint" and g_server ~= nil and g_dedicatedServerInfo == nil then
				if vehicle.bShowDebugMapMarker == true and AutoDrive.mapWayPoints[1] ~= nil then
					local closest = AutoDrive:findClosestWayPoint(vehicle)
					AutoDrive:removeMapWayPoint( AutoDrive.mapWayPoints[closest] );
				end;

			end;

			if input == "input_removeDestination" and g_server ~= nil and g_dedicatedServerInfo == nil then
				if vehicle.bShowDebugMapMarker == true and AutoDrive.mapWayPoints[1] ~= nil then
					local closest = AutoDrive:findClosestWayPoint(vehicle)
					AutoDrive:removeMapMarker( AutoDrive.mapWayPoints[closest] );
				end;
			end;

			if input == "input_recalculate" and g_server ~= nil and g_dedicatedServerInfo == nil then
				AutoDrive:ContiniousRecalculation();
			end;

			if input == "input_exportRoutes" then
				AutoDrive:ExportRoutes();
			end;

			if input == "input_importRoutes" then
				AutoDrive:ImportRoutes();
			end;

			if input == "input_nextTarget_Unload" then
				if  AutoDrive.mapMarker[1] ~= nil and AutoDrive.mapWayPoints[1] ~= nil then
					if vehicle.nMapMarkerSelected_Unload == -1 then
						vehicle.nMapMarkerSelected_Unload = 1

						vehicle.ntargetSelected_Unload = AutoDrive.mapMarker[vehicle.nMapMarkerSelected_Unload].id;

						vehicle.sTargetSelected_Unload = AutoDrive.mapMarker[vehicle.nMapMarkerSelected_Unload].name;
					else
						vehicle.nMapMarkerSelected_Unload = vehicle.nMapMarkerSelected_Unload + 1;
						if vehicle.nMapMarkerSelected_Unload > AutoDrive.mapMarkerCounter then
							vehicle.nMapMarkerSelected_Unload = 1;
						end;
						vehicle.ntargetSelected_Unload = AutoDrive.mapMarker[vehicle.nMapMarkerSelected_Unload].id;
						vehicle.sTargetSelected_Unload = AutoDrive.mapMarker[vehicle.nMapMarkerSelected_Unload].name;
					end;
				end;

			end;

			if input == "input_previousTarget_Unload" then
				if AutoDrive.mapMarker[1] ~= nil and AutoDrive.mapWayPoints[1] ~= nil then
					if vehicle.nMapMarkerSelected_Unload == -1 then
						vehicle.nMapMarkerSelected_Unload = AutoDrive.mapMarkerCounter;

						vehicle.ntargetSelected_Unload = AutoDrive.mapMarker[vehicle.nMapMarkerSelected_Unload].id;
						vehicle.sTargetSelected_Unload = AutoDrive.mapMarker[vehicle.nMapMarkerSelected_Unload].name;
					else
						vehicle.nMapMarkerSelected_Unload = vehicle.nMapMarkerSelected_Unload - 1;
						if vehicle.nMapMarkerSelected_Unload < 1 then
							vehicle.nMapMarkerSelected_Unload = AutoDrive.mapMarkerCounter;
						end;
						vehicle.ntargetSelected_Unload = AutoDrive.mapMarker[vehicle.nMapMarkerSelected_Unload].id;
						vehicle.sTargetSelected_Unload = AutoDrive.mapMarker[vehicle.nMapMarkerSelected_Unload].name;
					end;
				end;
			end;

			if input == "input_continue" then
				if vehicle.bPaused == true then
					vehicle.bPaused = false;
				end;
			end;

		end;
	end;
	vehicle.currentInput = "";

end;

function AutoDrive:ContiniousRecalculation()

	if  AutoDrive.Recalculation.continue == true then
		if AutoDrive.Recalculation.initializedWaypoints == false then
			for i2,point in pairs(AutoDrive.mapWayPoints) do
				point.marker = {};
			end;
			AutoDrive.Recalculation.initializedWaypoints = true;
			return 10;
		end;

		local markerFinished = false;
		for i, marker in pairs(AutoDrive.mapMarker) do
			if markerFinished == false then
				if i == AutoDrive.Recalculation.nextMarker then

					local tempAD = AutoDrive:dijkstra(AutoDrive.mapWayPoints, marker.id,"incoming");

					for i2,point in pairs(AutoDrive.mapWayPoints) do

						point.marker[marker.name] = tempAD.pre[point.id];

					end;

					markerFinished = true;
				end;
			else
				AutoDrive.Recalculation.nextMarker = i;
				AutoDrive.Recalculation.handledMarkers = AutoDrive.Recalculation.handledMarkers + 1;
				return 10 + math.ceil((AutoDrive.Recalculation.handledMarkers/AutoDrive.mapMarkerCounter) * 90)
			end;

		end;

		if AutoDrive.adXml ~= nil then
			setXMLString(AutoDrive.adXml, "AutoDrive.Recalculation","false");
			AutoDrive:MarkChanged();
			AutoDrive.handledRecalculation = true;
		end;

		AutoDrive.Recalculation.continue = false;
		return 100;

	else
		AutoDrive.Recalculation = {};
		AutoDrive.Recalculation.continue = true;
		AutoDrive.Recalculation.initializedWaypoints = false;
		AutoDrive.Recalculation.nextMarker = ""
		for i, marker in pairs(AutoDrive.mapMarker) do
			if AutoDrive.Recalculation.nextMarker == "" then
				AutoDrive.Recalculation.nextMarker = i;
			end;
		end;
		AutoDrive.Recalculation.handledMarkers = 0;
		AutoDrive.Recalculation.nextCalculationSkipFrames = 6;

		return 5;
	end;
end

function AutoDrive:onLeave()
	if AutoDrive.showMouse then
		g_inputBinding.setShowMouseCursor(false);
		AutoDrive.showMouse = false;
	end
end;

function AutoDrive:dijkstra(Graph,start,setToUse)
	
	--init
	--initdijkstra(Graph,Start,distance,pre,Q);
	if self.ad == nil then
		self.ad = {};--AutoDrive.ad;
	end;
	
	self.ad.Q = AutoDrive:graphcopy(Graph);
	self.ad.distance = {};
	self.ad.pre = {};
	for i in pairs(Graph) do
		self.ad.distance[i] = -1;
		self.ad.pre[i] = -1;
	end;
	
	self.ad.distance[start] = 0;
	for i in pairs(self.ad.Q[start][setToUse]) do
		--print("out of start: " .. self.ad.Q[start][setToUse][i] );
		self.ad.distance[self.ad.Q[start][setToUse][i]] = 1 --self.ad.Q[start]["out_cost"][i];
		self.ad.pre[self.ad.Q[start][setToUse][i]] = start;
	end;
	--init end
	
	while next(self.ad.Q,nil) ~= nil do
		local shortest = 10000000;
		local shortest_id = -1;
		for i in pairs(self.ad.Q) do
			
			if self.ad.distance[self.ad.Q[i]["id"]] < shortest and self.ad.distance[self.ad.Q[i]["id"]] ~= -1 then
				shortest = self.ad.distance[self.ad.Q[i]["id"]];
				shortest_id = self.ad.Q[i]["id"];
			end;
		end;
		
		if shortest_id == -1 then
			self.ad.Q = {};
		else
			for i in pairs(self.ad.Q[shortest_id][setToUse]) do
				local inQ = false;
				for i2 in pairs(self.ad.Q) do
					if self.ad.Q[i2]["id"] ==  self.ad.Q[shortest_id][setToUse][i] then
						inQ = true;
					end;
				end;
				if inQ == true then
					--distanceupdate
					local alternative = shortest + 1 --self.ad.Q[shortest_id]["out_cost"][i];
					if alternative < self.ad.distance[self.ad.Q[shortest_id][setToUse][i]] or self.ad.distance[self.ad.Q[shortest_id][setToUse][i]] == -1 then
						--print("found shorter alternative for " .. Q[shortest_id][setToUse][i] .. " via " .. shortest_id .. " new distance: " .. alternative );
						self.ad.distance[self.ad.Q[shortest_id][setToUse][i]] = alternative;
						self.ad.pre[self.ad.Q[shortest_id][setToUse][i]] = shortest_id;
					end;
				end;			
			end;
			
			self.ad.Q[shortest_id] = nil;
		end;
		
	end;	
	--print("distance to 3: " .. self.ad.distance[3]);	
	
	for i in pairs(self.ad.pre) do
		--print("pre "..i .. " = ".. self.ad.pre[i]);
	end;
	
	--shortestPath(Graph,self.ad.distance,self.ad.pre,1,3);
	
	return self.ad;
	
end;

function AutoDrive:graphcopy(Graph)
	local Q = {};
	--print("Graphcopy");
	for i in pairs(Graph) do
		--print ("i = " .. i );
		local id = Graph[i]["id"];
		--print ("id = " .. id );
		local out = {};
		local incoming = {};
		local out_cost = {};
		local marker = {};
		
		--print ("out:");
		for i2 in pairs(Graph[i]["out"]) do
			out[i2] = Graph[i]["out"][i2];
			--print(""..i2 .. " : " .. out[i2]);
		end;
		--print("incoming");
		for i3 in pairs(Graph[i]["incoming"]) do
			incoming[i3] = Graph[i]["incoming"][i3];
		end;
		for i4 in pairs(Graph[i]["out_cost"]) do
			out_cost[i4] = Graph[i]["out_cost"][i4];
		end;
		
		
		for i5 in pairs(Graph[i]["marker"]) do
			marker[i5] = Graph[i]["marker"][i5];
		end;
		
		
		Q[i] = createNode(id,out,incoming,out_cost, marker);
		
		Q[i].x = Graph[i].x;
		Q[i].y = Graph[i].y;
		Q[i].z = Graph[i].z;
		
	end;

	return Q;
end;

function createNode(id,out,incoming,out_cost, marker)
	local p = {};
	p["id"] = id;
	p["out"] = out;
	p["incoming"] = incoming;
	p["out_cost"] = out_cost;
	p["marker"] = marker;
	--p["coords"] = coords;
	
	return p;
end

function AutoDrive:FastShortestPath(Graph,start,markerName, markerID)
	
	local wp = {};
	local count = 1;
	local id = start;
	--print("searching path for start id: " .. id .. " and target: " .. markerName .. " id: " .. markerID);
	while id ~= -1 and id ~= nil do
		
		wp[count] = Graph[id];
		count = count+1;
		--print(""..wp[count-1]["id"]);
		if id == markerID then
			id = nil;
		else
			id = AutoDrive.mapWayPoints[id].marker[markerName];
		end;
	end;
	
	local wp_copy = AutoDrive:graphcopy(wp);
	
	--print("shortest path to " .. markerName);
	--for i in pairs(wp) do
		--print(""..wp[i]["id"]);
	--end;
	
	return wp_copy;
end;

function AutoDrive:shortestPath(Graph,distance,pre,start,endNode)
	local wp = {};
	local count = 1;
	local id = Graph[endNode]["id"];
	
	while self.ad.pre[id] ~= -1 do
		for i in pairs(Graph) do
			if Graph[i]["id"] == id then
				wp[count] = Graph[i];  --todo: maybe create copy
			end;
		end;
		count = count+1;
		id = self.ad.pre[id];
	end;

	
	local wp_reversed = {};
	for i in pairs(wp) do
		wp_reversed[count-i] = wp[i];
	end;
	
	local wp_copy = AutoDrive:graphcopy(wp_reversed);
	
	--print("shortest path to " .. Graph[endNode]["id"]);
	for i in pairs(wp) do
		--print(""..wp[i]["id"]);
	end;
	
	return wp_copy;
	
end;


function AutoDrive:mouseEvent(posX, posY, isDown, isUp, button)
	vehicle = g_currentMission.controlledVehicle;
	if vehicle ~= nil and AutoDrive.Hud.showHud == true then
		AutoDrive.Hud:mouseEvent(vehicle, posX, posY, isDown, isUp, button);
	end;
end; 

function AutoDrive:keyEvent(unicode, sym, modifier, isDown) 	
	vehicle = g_currentMission.controlledVehicle
	if vehicle ~= nil then	
		--print("Unicode: " .. unicode .. " sym: " .. sym);	
		if isDown and vehicle.bEnteringMapMarker then 
			if sym == 13 then
				vehicle.bEnteringMapMarker = false;
				vehicle.isBroken = false;
			else
				if sym == 8 then
					vehicle.sEnteredMapMarkerString = string.sub(vehicle.sEnteredMapMarkerString,1,string.len(vehicle.sEnteredMapMarkerString)-1)
				else
					if unicode ~= 0 then
						vehicle.sEnteredMapMarkerString = vehicle.sEnteredMapMarkerString .. string.char(unicode);
					end;
				end;
			end;
		end;
		if isDown and vehicle.bChoosingDestination then
			if sym == 13 then
				vehicle.bChoosingDestination = false;
				vehicle.sChosenDestination = "";
				vehicle.sEnteredChosenDestination = "";
				vehicle.isBroken = false;
				g_currentMission.isPlayerFrozen = false;
			else
				if sym == 8 then
					vehicle.sEnteredChosenDestination = string.sub(vehicle.sEnteredChosenDestination,1,string.len(vehicle.sEnteredChosenDestination)-1)
				else
					if sym == 9 then
						local foundMatch = false;
						local behindCurrent = false;
						local markerID = -1;
						local markerIndex = -1;
						if vehicle.sChosenDestination == "" then
							behindCurrent = true;
						end;
						for _,marker in pairs( AutoDrive.mapMarker) do
							local tempName = vehicle.sChosenDestination;
							if string.find(marker.name, vehicle.sEnteredChosenDestination) == 1 and behindCurrent and not foundMatch then
								vehicle.sChosenDestination = marker.name;
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

								if string.find(marker.name, vehicle.sEnteredChosenDestination) == 1 and not foundMatch then
									vehicle.sChosenDestination = marker.name;
									markerID = marker.id;
									markerIndex = _;
									foundMatch = true;
								end;
							end;
						end;
						if vehicle.sChosenDestination ~= "" then
							vehicle.nMapMarkerSelected = markerIndex;
							vehicle.ntargetSelected = AutoDrive.mapMarker[vehicle.nMapMarkerSelected].id;
							vehicle.sTargetSelected = AutoDrive.mapMarker[vehicle.nMapMarkerSelected].name;
							local translation = AutoDrive:translate(vehicle.sTargetSelected);
							vehicle.sTargetSelected = translation;
						end;

					else
						if unicode ~= 0 then
							vehicle.sEnteredChosenDestination = vehicle.sEnteredChosenDestination .. string.char(unicode);
						end;
					end;
				end;
			end;
		end;	
	end;	
end; 

function AutoDrive:deactivate(self,stopVehicle)				
				self.bActive = false; 
				self.forceIsActive = false;
				self.stopMotorOnLeave = true;
				self.disableCharacterOnLeave = true;
								
				self.bInitialized = false;
				self.nCurrentWayPoint = 0;
				self.bDrivingForward = true;
				self.previousSpeed = 10;
				if self.steeringEnabled == false then
					self.steeringEnabled = true;
				end
				self:setCruiseControlState(Drivable.CRUISECONTROL_STATE_OFF);
end;

function AutoDrive:onUpdate(dt)
	if self.moduleInitialized == nil then
		init(self);
	end;

	if AutoDrive.Recalculation ~= nil then
		if  AutoDrive.Recalculation.continue == true then
			if AutoDrive.Recalculation.nextCalculationSkipFrames <= 0 then
				AutoDrive.recalculationPercentage = AutoDrive:ContiniousRecalculation();
				AutoDrive.Recalculation.nextCalculationSkipFrames = 6;

				AutoDrive.nPrintTime = 10000;
				AutoDrive.printMessage = g_i18n:getText("AD_Recalculationg_routes_status") .. " " .. AutoDrive.recalculationPercentage .. "%";
			else
				AutoDrive.Recalculation.nextCalculationSkipFrames =  AutoDrive.Recalculation.nextCalculationSkipFrames - 1;
			end;

		end;
	end;

	if self.requestWayPointTimer >= 0 then
		self.requestWayPointTimer = self.requestWayPointTimer - dt;
	end;

	if self.currentInput ~= "" and self.isServer then
		--print("I am the server and start input handling. lets see if they think so too");
		AutoDrive:InputHandling(self, self.currentInput);
	end;

	if self.bActive == true and self.isServer then
		self.forceIsActive = true;
		self.stopMotorOnLeave = false;
		self.disableCharacterOnLeave = true;
		if self.isMotorStarted == false then
			self:startMotor();
		end;
		
		self.nTimeToDeadLock = self.nTimeToDeadLock - dt;
		if self.nTimeToDeadLock < 0 and self.nTimeToDeadLock ~= -1 then
			print("Deadlock reached due to timer");
			self.bDeadLock = true;
		end;
		
	else
		self.bDeadLock = false;
		self.nTimeToDeadLock = 15000;
		self.bDeadLockRepairCounter = 4;
	end;
	
	if self.printMessage ~= nil then
		self.nPrintTime = self.nPrintTime - dt;
		if self.nPrintTime < 0 then
			self.nPrintTime = 3000;
			self.printMessage = nil;
		end;
	end;
	
	if self == g_currentMission.controlledVehicle then
		if AutoDrive.printMessage ~= nil then
			AutoDrive.nPrintTime = AutoDrive.nPrintTime - dt;
			if AutoDrive.nPrintTime < 0 then
				AutoDrive.nPrintTime = 3000;
				AutoDrive.printMessage = nil;
			end;
		end;

		if self.ad.sToolTip ~= "" then
			if self.ad.nToolTipWait <= 0 then
				if self.ad.nToolTipTimer > 0 then
					self.ad.nToolTipTimer = self.ad.nToolTipTimer - dt;
				else
					self.ad.sToolTip = "";
				end;
			else
				self.ad.nToolTipWait = self.ad.nToolTipWait - dt;
			end;
		end;		
	end;
		
	local veh = self;
	
	--follow waypoints on route:
	
	if self.bStopAD == true and self.isServer then
		AutoDrive:deactivate(self,false);
		self.bStopAD = false;
		self.bPaused = false;
	end;
	
	if self.components ~= nil and self.isServer then
	
		local x,y,z = getWorldTranslation( self.components[1].node );
		local xl,yl,zl = worldToLocal(veh.components[1].node, x,y,z);
			
		if self.bActive == true and self.bPaused == false then
			if self.steeringEnabled then
				self.steeringEnabled = false;
			end

			if self.bInitialized == false then
				self.nTimeToDeadLock = 15000;
				if self.bTargetMode == true then
					local closest = AutoDrive:findMatchingWayPoint(veh);
					self.ad.wayPoints = AutoDrive:FastShortestPath(AutoDrive.mapWayPoints, closest, AutoDrive.mapMarker[self.nMapMarkerSelected].name, self.ntargetSelected);
					
					DebugUtil.printTableRecursively(self.ad.wayPoints, "--", 0,2);
					
					if self.ad.wayPoints[2] ~= nil then
						self.nCurrentWayPoint = 2;
					else
						self.nCurrentWayPoint = 1;
					end;
				else
					self.nCurrentWayPoint = 1;
				end;

				if self.ad.wayPoints[self.nCurrentWayPoint] ~= nil then
					self.nTargetX = self.ad.wayPoints[self.nCurrentWayPoint].x;
					self.nTargetZ = self.ad.wayPoints[self.nCurrentWayPoint].z;
					self.bInitialized = true;
					self.bDrivingForward = true;

				else
					--print("Autodrive hat ein Problem festgestellt");
					print("Autodrive hat ein Problem beim Initialisieren festgestellt");
					AutoDrive:deactivate(self,true);
				end;
			else
				local min_distance = 1.8;
				if self.typeDesc == "combine" or  self.typeDesc == "harvester" then
					min_distance = 6;
				end;
				if self.typeDesc == "telehandler" then
					min_distance = 3;
				end;

				if getDistance(x,z, self.nTargetX, self.nTargetZ) < min_distance then
					self.previousSpeed = self.speed_override;
					self.nTimeToDeadLock = 15000;

					if self.ad.wayPoints[self.nCurrentWayPoint+1] ~= nil then
						self.nCurrentWayPoint = self.nCurrentWayPoint + 1;
						self.nTargetX = self.ad.wayPoints[self.nCurrentWayPoint].x;
						self.nTargetZ = self.ad.wayPoints[self.nCurrentWayPoint].z;
					else
						print("Last waypoint reached");
						if self.bUnloadAtTrigger == false then
							if self.bRoundTrip == false then
								print("No Roundtrip");
								if self.bReverseTrack == true then
									print("Starting reverse track");
									--reverse driving direction
									if self.bDrivingForward == true then
										self.bDrivingForward = false;
									else
										self.bDrivingForward = true;
									end;
									--reverse waypoints
									local reverseWaypoints = {};
									local _counterWayPoints = 0;
									for n in pairs(self.ad.wayPoints) do
										_counterWayPoints = _counterWayPoints + 1;
									end;
									for n in pairs(self.ad.wayPoints) do
										reverseWaypoints[_counterWayPoints] = self.ad.wayPoints[n];
										_counterWayPoints = _counterWayPoints - 1;
									end;
									for n in pairs(reverseWaypoints) do
										self.ad.wayPoints[n] = reverseWaypoints[n];
									end;
									--start again:
									self.nCurrentWayPoint = 1
									self.nTargetX = self.ad.wayPoints[self.nCurrentWayPoint].x;
									self.nTargetZ = self.ad.wayPoints[self.nCurrentWayPoint].z;

								else
									print("Shutting down");
									AutoDrive.printMessage = g_i18n:getText("AD_Driver_of") .. " " .. self.name .. " " .. g_i18n:getText("AD_has_reached") .. " " .. self.sTargetSelected;
									AutoDrive.nPrintTime = 6000;
									if self.isServer == true then
										xl,yl,zl = worldToLocal(veh.components[1].node, self.nTargetX,y,self.nTargetZ);

										--AIVehicleUtil.driveToPoint(self, dt, 0, false, self.bDrivingForward, xl, zl, 0, false );

										--veh:setCruiseControlState(Drivable.CRUISECONTROL_STATE_OFF);
									end;

									--veh:setCruiseControlState(Drivable.CRUISECONTROL_STATE_OFF);

									AutoDrive:deactivate(self,true);
								end;
							else
								print("Going into next round");
								self.nCurrentWayPoint = 1
								if self.ad.wayPoints[self.nCurrentWayPoint] ~= nil then
									self.nTargetX = self.ad.wayPoints[self.nCurrentWayPoint].x;
									self.nTargetZ = self.ad.wayPoints[self.nCurrentWayPoint].z;

								else
									print("Autodrive hat ein Problem beim Rundkurs festgestellt");
									AutoDrive:deactivate(self,true);
								end;
							end;
						else
							if self.bUnloadSwitch == true then
								self.nTimeToDeadLock = 15000;

								local closest = self.ad.wayPoints[self.nCurrentWayPoint].id;
								self.ad.wayPoints = AutoDrive:FastShortestPath(AutoDrive.mapWayPoints, closest, AutoDrive.mapMarker[self.nMapMarkerSelected].name, self.ntargetSelected);
								self.nCurrentWayPoint = 1;

								self.nTargetX = self.ad.wayPoints[self.nCurrentWayPoint].x;
								self.nTargetZ = self.ad.wayPoints[self.nCurrentWayPoint].z;

								self.bUnloadSwitch = false;
							else
								self.nTimeToDeadLock = 15000;

								local closest = self.ad.wayPoints[self.nCurrentWayPoint].id;
								self.ad.wayPoints = AutoDrive:FastShortestPath(AutoDrive.mapWayPoints, closest, AutoDrive.mapMarker[self.nMapMarkerSelected_Unload].name, AutoDrive.mapMarker[self.nMapMarkerSelected_Unload].id);
								self.nCurrentWayPoint = 1;

								self.nTargetX = self.ad.wayPoints[self.nCurrentWayPoint].x;
								self.nTargetZ = self.ad.wayPoints[self.nCurrentWayPoint].z;

								self.bPaused = true;
								self.bUnloadSwitch = true;
							end;
						end;
					end;
				end;
			end;

			if self.bActive == true then
				if self.isServer == true then

					if self.ad.wayPoints[self.nCurrentWayPoint+1] ~= nil then
						--AutoDrive:addlog("Issuing Drive Request");
						xl,yl,zl = worldToLocal(veh.components[1].node, self.nTargetX,y,self.nTargetZ);

						self.speed_override = -1;
						if self.ad.wayPoints[self.nCurrentWayPoint-1] ~= nil and self.ad.wayPoints[self.nCurrentWayPoint+1] ~= nil then
							local wp_ahead = self.ad.wayPoints[self.nCurrentWayPoint+1];
							local wp_current = self.ad.wayPoints[self.nCurrentWayPoint];
							local wp_ref = self.ad.wayPoints[self.nCurrentWayPoint-1];
							local angle = AutoDrive:angleBetween( 	{x=	wp_ahead.x	-	wp_ref.x, z = wp_ahead.z - wp_ref.z },
																	{x=	wp_current.x-	wp_ref.x, z = wp_current.z - wp_ref.z } )


							if angle < 3 then self.speed_override = self.nSpeed; end;
							if angle >= 3 and angle < 5 then self.speed_override = 38; end;
							if angle >= 5 and angle < 8 then self.speed_override = 32; end;
							if angle >= 8 and angle < 12 then self.speed_override = 25; end;
							if angle >= 12 and angle < 15 then self.speed_override = 15; end;
							if angle >= 15 and angle < 20 then self.speed_override = 14; end;
							if angle >= 20 and angle < 30 then self.speed_override = 9; end;
							if angle >= 30 and angle < 90 then self.speed_override = 4; end;

							--print("Angle: " .. angle .. " speed: " .. speed_override);
							local distance_wps = getDistance(wp_ref.x,wp_ref.z,wp_current.x,wp_current.z);
							local distance_vehicle = getDistance(wp_current.x,wp_current.z,x,z );

							if self.previousSpeed > self.speed_override then
								self.speed_override = self.speed_override + math.min(1,distance_vehicle/distance_wps) * (self.previousSpeed - self.speed_override);
							else
								self.speed_override = self.speed_override - math.min(1,distance_vehicle/distance_wps) * (self.speed_override - self.previousSpeed);
							end;
							--print("Speed override: " .. self.speed_override);

						end;
						if self.speed_override == -1 then self.speed_override = self.nSpeed; end;
						if self.speed_override > self.nSpeed then self.speed_override = self.nSpeed; end;

						local wp_new = nil;

						if wp_new ~= nil then
							xl,yl,zl = worldToLocal(veh.components[1].node, wp_new.x,y,wp_new.z);
						end;

						if self.bUnloadAtTrigger == true then
							local destination = AutoDrive.mapWayPoints[self.ntargetSelected_Unload];
							local start = AutoDrive.mapWayPoints[self.ntargetSelected];
							local distance1 = getDistance(x,z, destination.x, destination.z);
							local distance2 = getDistance(x,z, start.x, start.z);
							if distance1 < 20 or distance2 < 20 then
								if self.speed_override > 12 then
									self.speed_override = 12;
								end;
							end;
						end;

						local finalSpeed = self.speed_override;
						local finalAcceleration = true;
						
						--veh:setCruiseControlState(Drivable.CRUISECONTROL_STATE_ACTIVE);						
						
						self.ad.steeringAngle = 90;
						local lx, lz = AIVehicleUtil.getDriveDirection(veh.components[1].node, self.nTargetX,y,self.nTargetZ);
						print("lx: " .. lx .. " lz: " .. lz);
						AIVehicleUtil.driveInDirection(self, dt, 90, 1, 0.5, 20, true, self.bDrivingForward, lx, lz, finalSpeed, 1);
						--AIVehicleUtil.driveToPoint(self, dt, 1, true, self.bDrivingForward, xl, zl, finalSpeed, false );
					else
						print("Reaching last waypoint - slowing down");
						local finalSpeed = 8;
						local finalAcceleration = true;						
						veh:setCruiseControlState(Drivable.CRUISECONTROL_STATE_ACTIVE);
						xl,yl,zl = worldToLocal(veh.components[1].node, self.nTargetX,y,self.nTargetZ);
						--AIVehicleUtil.driveToPoint(self, dt, 1, true, self.bDrivingForward, xl, zl, finalSpeed, false );
						AIVehicleUtil.driveInDirection(self, dt, 90, 1, 0.5, 20, true, self.bDrivingForward, xl, zl, finalSpeed, 1);
					end;
				end;
			end;
		end;

		if self.bPaused == true then
			self.nTimeToDeadLock = 15000;
			if self.nPauseTimer > 0 then
				if self.isServer == true then
					xl,yl,zl = worldToLocal(veh.components[1].node, self.nTargetX,y,self.nTargetZ);

					--AIVehicleUtil.driveToPoint(self, dt, 0, false, self.bDrivingForward, xl, zl, 0, false );

					--veh:setCruiseControlState(Drivable.CRUISECONTROL_STATE_OFF);
				end;
				self.nPauseTimer = self.nPauseTimer - dt;
			end;
		else
			if self.nPauseTimer < 5000 then
				self.nPauseTimer = 5000;
			end;
		end;

		--if self.typeDesc == "combine" or self.typeDesc == "harvester" then
			--veh.aiSteeringSpeed = 1;
		--else
			--veh.aiSteeringSpeed = 0.4;
		--end;
		--print(" target: " .. self.nTargetX .. "/" .. self.nTargetZ .. " steeringSpeed: " .. veh.aiSteeringSpeed);
	end;
	
	if self.bDeadLock == true and self.bActive == true and self.isServer then
		AutoDrive.printMessage = g_i18n:getText("AD_Driver_of") .. " " .. self.name .. " " .. g_i18n:getText("AD_got_stuck");
		AutoDrive.nPrintTime = 10000;
		
		--deadlock handling
		if self.bDeadLockRepairCounter < 1 then
			AutoDrive.printMessage = g_i18n:getText("AD_Driver_of") .. " " .. self.name .. " " .. g_i18n:getText("AD_got_stuck");
			AutoDrive.nPrintTime = 10000;
			self.bStopAD = true;
			self.bActive = false;
		else
			--print("AD: Trying to recover from deadlock")
			if self.ad.wayPoints[self.nCurrentWayPoint+2] ~= nil then
				self.nCurrentWayPoint = self.nCurrentWayPoint + 1;
				self.nTargetX = self.ad.wayPoints[self.nCurrentWayPoint].x;
				self.nTargetZ = self.ad.wayPoints[self.nCurrentWayPoint].z;

				self.bDeadLock = false;
				self.nTimeToDeadLock = 15000;
				self.bDeadLockRepairCounter = self.bDeadLockRepairCounter - 1;
			end;
		end;
	end;
	
	if veh == g_currentMission.controlledVehicle then
		if veh ~= nil then
			--manually create waypoints in create-mode:
			if self.bcreateMode == true then
				--record waypoints every 6m
				local i = 0;
				for n in pairs(self.ad.wayPoints) do 
					i = i+1;
				end;
				i = i+1;
				
				--first entry
				if i == 1 then
					local x1,y1,z1 = getWorldTranslation(veh.components[1].node);
					self.ad.wayPoints[i] = createVector(x1,y1,z1);
					
					if self.bCreateMapPoints == true then
						AutoDrive:MarkChanged();
						AutoDrive.mapWayPointsCounter = AutoDrive.mapWayPointsCounter + 1;
						AutoDrive.mapWayPoints[AutoDrive.mapWayPointsCounter] = createNode(AutoDrive.mapWayPointsCounter,{},{},{},{});
						AutoDrive.mapWayPoints[AutoDrive.mapWayPointsCounter].x = x1;
						AutoDrive.mapWayPoints[AutoDrive.mapWayPointsCounter].y = y1;
						AutoDrive.mapWayPoints[AutoDrive.mapWayPointsCounter].z = z1;
						
						print("Creating Waypoint #" .. AutoDrive.mapWayPointsCounter);						
					end;
					
					i = i+1;
				else
					if i == 2 then
						local x,y,z = getWorldTranslation(veh.components[1].node);
						local wp = self.ad.wayPoints[i-1];
						if getDistance(x,z,wp.x,wp.z) > 3 then
							self.ad.wayPoints[i] = createVector(x,y,z);
							if self.bCreateMapPoints == true then
								AutoDrive.mapWayPointsCounter = AutoDrive.mapWayPointsCounter + 1;
								if AutoDrive.mapWayPointsCounter > 1 then
									--edit previous point
									AutoDrive.mapWayPoints[AutoDrive.mapWayPointsCounter-1].out[1] = AutoDrive.mapWayPointsCounter;
									AutoDrive.mapWayPoints[AutoDrive.mapWayPointsCounter-1].out_cost[1] = 1;
								end;
								
								--edit current point
								print("Creating Waypoint #" .. AutoDrive.mapWayPointsCounter);
								AutoDrive.mapWayPoints[AutoDrive.mapWayPointsCounter] = createNode(AutoDrive.mapWayPointsCounter,{},{},{},{});
								AutoDrive.mapWayPoints[AutoDrive.mapWayPointsCounter].incoming[1] = AutoDrive.mapWayPointsCounter-1;
								AutoDrive.mapWayPoints[AutoDrive.mapWayPointsCounter].x = x;
								AutoDrive.mapWayPoints[AutoDrive.mapWayPointsCounter].y = y;
								AutoDrive.mapWayPoints[AutoDrive.mapWayPointsCounter].z = z;
							end;
							if self.bcreateModeDual == true then
								AutoDrive.mapWayPoints[AutoDrive.mapWayPointsCounter-1].incoming[1] = AutoDrive.mapWayPointsCounter;
								--edit current point
								AutoDrive.mapWayPoints[AutoDrive.mapWayPointsCounter].out[1] = AutoDrive.mapWayPointsCounter-1;
								AutoDrive.mapWayPoints[AutoDrive.mapWayPointsCounter].out_cost[1] = 1;
							end;

							i = i+1;
						end;
					else
						local x,y,z = getWorldTranslation(veh.components[1].node);
						local wp = self.ad.wayPoints[i-1];
						local wp_ref = self.ad.wayPoints[i-2]
						local angle = AutoDrive:angleBetween( {x=x-wp_ref.x,z=z-wp_ref.z},{x=wp.x-wp_ref.x, z = wp.z - wp_ref.z } )
						--print("Angle between: " .. angle );
						local max_distance = 6;
						if angle < 1 then max_distance = 20; end;
						if angle >= 1 and angle < 2 then max_distance = 12; end;
						if angle >= 2 and angle < 3 then max_distance = 9; end;
						if angle >= 3 and angle < 5 then max_distance = 6; end;
						if angle >= 5 and angle < 8 then max_distance = 4; end;
						if angle >= 8 and angle < 12 then max_distance = 2; end;
						if angle >= 12 and angle < 15 then max_distance = 1; end;
						if angle >= 15 and angle < 50 then max_distance = 0.5; end;

						if getDistance(x,z,wp.x,wp.z) > max_distance then
							self.ad.wayPoints[i] = createVector(x,y,z);
							if self.bCreateMapPoints == true then
								AutoDrive.mapWayPointsCounter = AutoDrive.mapWayPointsCounter + 1;
								if AutoDrive.mapWayPointsCounter > 2 then
									--edit previous point
									local out_index = 1;
									if AutoDrive.mapWayPoints[AutoDrive.mapWayPointsCounter-1].out[out_index] ~= nil then out_index = out_index+1; end;
									AutoDrive.mapWayPoints[AutoDrive.mapWayPointsCounter-1].out[out_index] = AutoDrive.mapWayPointsCounter;
									AutoDrive.mapWayPoints[AutoDrive.mapWayPointsCounter-1].out_cost[out_index] = 1;
								end;
								
								--edit current point
								print("Creating Waypoint #" .. AutoDrive.mapWayPointsCounter);
								AutoDrive.mapWayPoints[AutoDrive.mapWayPointsCounter] = createNode(AutoDrive.mapWayPointsCounter,{},{},{},{});
								AutoDrive.mapWayPoints[AutoDrive.mapWayPointsCounter].incoming[1] = AutoDrive.mapWayPointsCounter-1;
								AutoDrive.mapWayPoints[AutoDrive.mapWayPointsCounter].x = x;
								AutoDrive.mapWayPoints[AutoDrive.mapWayPointsCounter].y = y;
								AutoDrive.mapWayPoints[AutoDrive.mapWayPointsCounter].z = z;
							end;
							if self.bcreateModeDual == true then
								AutoDrive.mapWayPoints[AutoDrive.mapWayPointsCounter-1].incoming[2] = AutoDrive.mapWayPointsCounter;
								--edit current point
								AutoDrive.mapWayPoints[AutoDrive.mapWayPointsCounter].out[1] = AutoDrive.mapWayPointsCounter-1;
								AutoDrive.mapWayPoints[AutoDrive.mapWayPointsCounter].out_cost[1] = 1;
							end;

							i = i+1;
						end;
					end;
				end;
			end;
		end;	
	end;

	if self.bActive == true and self.bUnloadAtTrigger == true and self.isServer == true then
		local trailers = {};
		local trailerCount = 0;
		local trailer = nil;
		if self.attachedImplements ~= nil then
			for _, implement in pairs(self.attachedImplements) do
				if implement.object ~= nil then
					if implement.object.typeDesc == g_i18n:getText("typeDesc_tipper") then
						trailer = implement.object;
						trailers[1] = trailer;
						trailerCount = 1;
						for __,impl in pairs(trailer.attachedImplements) do
							if impl.object ~= nil then
								if impl.object.typeDesc == g_i18n:getText("typeDesc_tipper") then
									trailers[2] = impl.object;
									trailerCount = 2;
									for ___,implement3 in pairs(trailers[2].attachedImplements) do
										if implement3.object ~= nil then
											if implement3.object.typeDesc == g_i18n:getText("typeDesc_tipper") then
												trailers[3] = implement3.object;
												trailerCount = 3;
											end;
										end;
									end;
								end;
							end;
						end;
					end;
				end;
			end;

			--check distance to unloading destination, do not unload too far from it. You never know where the tractor might already drive over an unloading trigger before that
			local x,y,z = getWorldTranslation(veh.components[1].node);
			local destination = AutoDrive.mapWayPoints[self.ntargetSelected_Unload];
			local distance = getDistance(x,z, destination.x, destination.z);
			if distance < 40 then
				--check trailer trigger: trailerTipTriggers
				local globalUnload = false;
				for _,trailer in pairs(trailers) do
					if trailer ~= nil then
						for _,trigger in pairs(g_currentMission.tipTriggers) do

							local allowed,minDistance,bestPoint = trigger:getTipInfoForTrailer(trailer, trailer.preferedTipReferencePointIndex);
							--print("Min distance: " .. minDistance);
							if allowed and minDistance == 0 then
								if trailer.tipping ~= true  then
									--print("toggling tip state for " .. trigger.stationName .. " distance: " .. minDistance );
									trailer:toggleTipState(trigger, bestPoint);
									self.bPaused = true;
									self.bUnloading = true;
									trailer.tipping = true;
								end;
							end;

							if trailer.tipState == Trailer.TIPSTATE_CLOSED and self.bUnloading == true and trailer.tipping == true then
								--print("trailer is unloaded. continue");
								trailer.tipping = false;
							end;

							if trailer.tipping == true or self.bPaused == false then
								globalUnload = true;
							end;

						end;
					end;
				end;
				if (globalUnload == false and self.bUnloading == true) or self.bPaused == false then
					self.bPaused = false;
					self.bUnloading = false;
				end;
			end;

			--check distance to unloading destination, do not unload too far from it. You never know where the tractor might already drive over an unloading trigger before that
			local x,y,z = getWorldTranslation(veh.components[1].node);
			local destination = AutoDrive.mapWayPoints[self.ntargetSelected];
			local distance = getDistance(x,z, destination.x, destination.z);
			if distance < 40 then
				--print("distance < 40");
				local globalLoading = false;

				for _,trailer in pairs(trailers) do
					if trailer ~= nil and self.unloadType ~= -1 then
						--print("Trailer detected. unloadType = " .. self.unloadType .. " level: " .. trailer:getFillLevel(self.unloadType));
						for _,trigger in pairs(g_currentMission.siloTriggers) do

							local valid = trigger:getIsValidTrailer(trailer);
							local level = trigger:getFillLevel(self.unloadType);
							local activatable = trigger.activeTriggers >=4 --trigger:getIsActivatable()
							local correctTrailer = false;
							if trigger.siloTrailer == trailer then correctTrailer = true; end;

							--print("valid: " .. tostring(valid) .. " level: " ..  tostring(level) .. " activatable: " .. tostring(activatable) .. " correctTrailer: " .. tostring(correctTrailer) );
							if valid and level > 0 and activatable and correctTrailer and trailer.bLoading ~= true then --
								if	trailer:getFreeCapacity() > 1 then
									--print("Starting to unload into trailer" );
									trigger:startFill(self.unloadType);
									self.bPaused = true;
									self.bLoading = true;
									trailer.bLoading = true;
								end;
							end;

							if (trailer:getFreeCapacity(self.unloadType) <= 0 or self.bPaused == false) and trailer.bLoading == true and correctTrailer == true then
								--print("trailer is full. continue");
								trigger:stopFill();
								trailer.bLoading = false;
							end;

							if trailer.bLoading == true then
								globalLoading = true;
							end;

						end;
					end;
				end;
				if (globalLoading == false and self.bLoading == true) or self.bPaused == false then
					self.bPaused = false;
					self.bLoading = false;
				end;
			end;

		end;

		if self.bPaused == true and not self.bUnloading and not self.bLoading then
			if trailer == nil or trailer:getFreeCapacity() <= 0 then
				self.bPaused = false;
			end;
		end;

	end;	
end;

function AutoDrive:log(dt)	
	self.nlastLogged = self.nlastLogged + dt;
	if self.nlastLogged >= self.nloggingInterval then
		self.nlastLogged = self.nlastLogged - self.nloggingInterval;
		if self.logMessage ~= "" then
			print(self.logMessage);
			self.logMessage = "";
		end;
	end;
	
end;

function AutoDrive:addlog(text)
	self.logMessage = text;
end;

function createVector(x,y,z)
	local table t = {};
	t["x"] = x;
	t["y"] = y;
	t["z"] = z;
	return t; 
end;

function getDistance(x1,z1,x2,z2)
	return math.sqrt((x1-x2)*(x1-x2) + (z1-z2)*(z1-z2) );
end;

function AutoDrive:findClosestWayPoint(veh)
	--returns waypoint closest to vehicle position
	local x1,y1,z1 = getWorldTranslation(veh.components[1].node);
	local closest = 1;
	if AutoDrive.mapWayPoints[1] ~= nil then

		local distance = getDistance(AutoDrive.mapWayPoints[1].x,AutoDrive.mapWayPoints[1].z,x1,z1);
		for i in pairs(AutoDrive.mapWayPoints) do
			local dis = getDistance(AutoDrive.mapWayPoints[i].x,AutoDrive.mapWayPoints[i].z,x1,z1);
			if dis < distance then
				closest = i;
				distance = dis;
			end;
		end;
	end;
	
	return closest;
end;

function AutoDrive:findMatchingWayPoint(veh)
	--returns waypoint closest to vehicle position and with the most suited heading
	local x1,y1,z1 = getWorldTranslation(veh.components[1].node);
	local rx,ry,rz = localDirectionToWorld(veh.components[1].node, 0,0,1);
	local vehicleVector = {x= math.sin(rx) ,z= math.sin(rz) };

	local candidates = {};
	local candidatesCounter = 0;

	for i in pairs(AutoDrive.mapWayPoints) do
		local dis = getDistance(AutoDrive.mapWayPoints[i].x,AutoDrive.mapWayPoints[i].z,x1,z1);
		if dis < 20 and dis > 1 then
			candidatesCounter = candidatesCounter + 1;
			candidates[candidatesCounter] = i;
		end;
	end;

	if candidatesCounter == 0 then
		return AutoDrive:findClosestWayPoint(veh);
	end;

	local closest = -1;
	local distance = -1;
	local angle = -1;

	for i,id in pairs(candidates) do

		local point = AutoDrive.mapWayPoints[id];
		local nextP = -1;
		if point.out ~= nil then
			if point.out[1] ~= nil then
				nextP = AutoDrive.mapWayPoints[point.out[1]];
			end;
		end;
		if nextP ~= -1 then
			local tempVec = {x= nextP.x - point.x, z= nextP.z - point.z};
			local tempVecToVehicle = { x = point.x - x1, z = point.z - z1 };
			local tempAngle = AutoDrive:angleBetween(vehicleVector, tempVec);
			local tempAngleToVehicle = AutoDrive:angleBetween(vehicleVector, tempVecToVehicle);
			local dis = getDistance(point.x,point.z,x1,z1);

			if closest == -1 and math.abs(tempAngle) < 60 and math.abs(tempAngleToVehicle) < 30 then
				closest = point.id;
				distance = dis;
				angle = tempAngle;
				--print("TempAngle to vehicle: " .. tempAngleToVehicle);
			else
				if math.abs(tempAngle) < math.abs(angle) then
					if math.abs(tempAngleToVehicle) < 30 then
						if math.abs(angle) < 20 then
							if dis < distance then
								closest = point.id;
								distance = dis;
								angle = tempAngle;
								--print("TempAngle to vehicle: " .. tempAngleToVehicle);
							end;
						else
							closest = point.id;
							distance = dis;
							angle = tempAngle;
						end;
					end;
				end;
			end;
		end;
	end;

	if closest == -1 then
		return AutoDrive:findClosestWayPoint(veh);
	end;

	return closest;
end;

function AutoDrive:getWorldDirection(fromX, fromY, fromZ, toX, toY, toZ)
	-- NOTE: if only 2D is needed, pass fromY and toY as 0
	local wdx, wdy, wdz = toX - fromX, toY - fromY, toZ - fromZ;
	local dist = MathUtil.vector3Length(wdx, wdy, wdz); -- length of vector
	if dist and dist > 0.01 then
		wdx, wdy, wdz = wdx/dist, wdy/dist, wdz/dist; -- if not too short: normalize
		return wdx, wdy, wdz, dist;
	end;
	return 0, 0, 0, 0;
end;

function AutoDrive:onDraw()
	if self.moduleInitialized == true then
		if self.nCurrentWayPoint > 0 then
			if self.ad.wayPoints[self.nCurrentWayPoint+1] ~= nil then
				drawDebugLine(self.ad.wayPoints[self.nCurrentWayPoint].x, self.ad.wayPoints[self.nCurrentWayPoint].y+4, self.ad.wayPoints[self.nCurrentWayPoint].z, 0,1,1, self.ad.wayPoints[self.nCurrentWayPoint+1].x, self.ad.wayPoints[self.nCurrentWayPoint+1].y+4, self.ad.wayPoints[self.nCurrentWayPoint+1].z, 1,1,1);
			end;
			if self.ad.wayPoints[self.nCurrentWayPoint-1] ~= nil then
				drawDebugLine(self.ad.wayPoints[self.nCurrentWayPoint-1].x, self.ad.wayPoints[self.nCurrentWayPoint-1].y+4, self.ad.wayPoints[self.nCurrentWayPoint-1].z, 0,1,1, self.ad.wayPoints[self.nCurrentWayPoint].x, self.ad.wayPoints[self.nCurrentWayPoint].y+4, self.ad.wayPoints[self.nCurrentWayPoint].z, 1,1,1);

			end;
		end;
		if self.bcreateMode == true then
			local _drawCounter = 1;
			for n in pairs(self.ad.wayPoints) do
				if self.ad.wayPoints[n+1] ~= nil then
					drawDebugLine(self.ad.wayPoints[n].x, self.ad.wayPoints[n].y+4, self.ad.wayPoints[n].z, 0,1,1, self.ad.wayPoints[n+1].x, self.ad.wayPoints[n+1].y+4, self.ad.wayPoints[n+1].z, 1,1,1);
				else
					drawDebugLine(self.ad.wayPoints[n].x, self.ad.wayPoints[n].y+4, self.ad.wayPoints[n].z, 0,1,1, self.ad.wayPoints[n].x, self.ad.wayPoints[n].y+5, self.ad.wayPoints[n].z, 1,1,1);
				end;
			end;
		end;

		if self.bCreateMapPoints == true then
			if self == g_currentMission.controlledVehicle then				
				--DebugUtil.printTableRecursively(AutoDrive.mapWayPoints, "--", 0, 2);
				for i,point in pairs(AutoDrive.mapWayPoints) do
					local x1,y1,z1 = getWorldTranslation(self.components[1].node);
					local distance = getDistance(point.x,point.z,x1,z1);
					if distance < 50 then

						local node = createTransformGroup("blubMarker");
						setTranslation(node, point.x, point.y + 4 , point.z  );
						DebugUtil.drawDebugNode(node,"blub");
						--DebugUtil.drawDebugCubeAtWorldPos(point.x, point.y + 4 , point.z, 1, 1, 1, 1, 1, 1, 0.2, 0.2, 0.2, 1, 0, 0)
						DebugUtil.drawDebugCubeAtWorldPos(point.x, point.y + 4 , point.z, 1, 0, 0, 0, 1, 0, 0.05, 0.05, 0.05, 1.0, 1.0, 0.0)
						
						local i3dNode =  g_i3DManager:loadSharedI3DFile( AutoDrive.directory .. 'img/debug/' .. "Line" .. '.i3d');
						local itemNode = getChildAt(i3dNode, 0);
						link(getRootNode(), itemNode);
						setRigidBodyType(itemNode, 'NoRigidBody');
						setTranslation(itemNode, 0, 0, 0);
						setVisibility(itemNode, true);
						delete(i3dNode);						

						if point.out ~= nil then
							for i2,neighbor in pairs(point.out) do
								local testDual = false;
								for _,incoming in pairs(point.incoming) do
									if incoming == neighbor then
										testDual = true;
									end;
								end;
								
								target = AutoDrive.mapWayPoints[neighbor];
								if testDual == true then
									--DebugUtil.drawDebugParallelogram(point.x, point.z, (target.x - point.x), 0.2, 0.2, (target.z - point.z), point.y, 1, 0, 0, 1)
									--drawDebugLine(point.x, point.y+4, point.z, 1,0,0, AutoDrive.mapWayPoints[neighbor].x, AutoDrive.mapWayPoints[neighbor].y+4, AutoDrive.mapWayPoints[neighbor].z, 1,0,0);
								else
									--DebugUtil.drawDebugParallelogram(point.x, point.z, (target.x - point.x), 0.2, 0.2, (target.z - point.z), point.y, 1, 1, 0, 1)
									--drawDebugLine(point.x, point.y+4, point.z, 0,1,0, AutoDrive.mapWayPoints[neighbor].x, AutoDrive.mapWayPoints[neighbor].y+4, AutoDrive.mapWayPoints[neighbor].z, 1,1,1);
								end;
								--DebugUtil.drawDebugCube(node, (target.x - point.x), 0.2, (target.z - point.z), 1, 0, 0)
								--DebugUtil.drawDebugCube(node, 1, 1, 1, 1, 0, 0)

								setTranslation(itemNode, point.x, point.y+3, point.z);

								--- Get the direction to the end point
								local dirX, _, dirZ, distToNextPoint = AutoDrive:getWorldDirection(point.x, point.y + 4 , point.z, target.x, target.y+4, target.z);
								--- Get Y rotation
								local rotY = MathUtil.getYRotationFromDirection(dirX, dirZ);
								--- Get X rotation
								local dy = (target.y+4) - (point.y+4);
								local dist2D = MathUtil.vector2Length(target.x - point.x, target.z - point.z);
								local rotX = -MathUtil.getYRotationFromDirection(dy, dist2D);

								--- Set the direction of the line
								setRotation(itemNode, rotX, rotY, 0);
								--- Set the length if the line
								setScale(itemNode, 1, 1, distToNextPoint);

								--- Update line color
								setShaderParameter(itemNode, 'shapeColor', 1,0,0, 1, false);
							end;
						end;
					end;
				end;

				for markerID,marker in pairs(AutoDrive.mapMarker) do
					local x1,y1,z1 = getWorldTranslation(self.components[1].node);
					local x2,y2,z2 = getWorldTranslation(marker.node);
					local distance = getDistance(x2,z2,x1,z1);
					if distance < 50 then
						DebugUtil.drawDebugNode(marker.node,marker.name);
					end;
				end;

				if self.bShowDebugMapMarker == true and AutoDrive.mapWayPoints[1] ~= nil then
					local closest = AutoDrive:findClosestWayPoint(self);
					local x1,y1,z1 = getWorldTranslation(self.components[1].node);
					drawDebugLine(x1, y1, z1, 0,0,1, AutoDrive.mapWayPoints[closest].x, AutoDrive.mapWayPoints[closest].y+4, AutoDrive.mapWayPoints[closest].z, 0,0,1);

					if self.bCreateMapMarker == true and self.bEnteringMapMarker == false then
						AutoDrive.mapMarkerCounter = AutoDrive.mapMarkerCounter + 1;
						local node = createTransformGroup(self.sEnteredMapMarkerString);
						setTranslation(node, AutoDrive.mapWayPoints[closest].x, AutoDrive.mapWayPoints[closest].y + 4 , AutoDrive.mapWayPoints[closest].z  );

						AutoDrive.mapMarker[AutoDrive.mapMarkerCounter] = {id=closest, name= self.sEnteredMapMarkerString, node=node};
						self.bCreateMapMarker = false;
						AutoDrive:MarkChanged();
						g_currentMission.isPlayerFrozen = false;
						self.isBroken = false;
					end;

					if self.bShowSelectedDebugPoint == true then
						if self.DebugPointsIterated[self.nSelectedDebugPoint] ~= nil then

							drawDebugLine(x1, y1, z1, 1,1,1, self.DebugPointsIterated[self.nSelectedDebugPoint].x, self.DebugPointsIterated[self.nSelectedDebugPoint].y+4, self.DebugPointsIterated[self.nSelectedDebugPoint].z, 1,1,1);
						else
							self.nSelectedDebugPoint = 1;
						end;

						if self.bChangeSelectedDebugPoint == true then

							local out_counter = 1;
							local exists = false;
							for i in pairs(AutoDrive.mapWayPoints[closest].out) do
								if exists == true then
									--print ("Entry exists "..i.. " out_counter: "..out_counter);
									AutoDrive.mapWayPoints[closest].out[out_counter] = AutoDrive.mapWayPoints[closest].out[i];
									AutoDrive.mapWayPoints[closest].out_cost[out_counter] = AutoDrive.mapWayPoints[closest].out_cost[i];
									out_counter = out_counter +1;
								else
									if AutoDrive.mapWayPoints[closest].out[i] == self.DebugPointsIterated[self.nSelectedDebugPoint].id then

										AutoDrive:MarkChanged()
										AutoDrive.mapWayPoints[closest].out[i] = nil;
										AutoDrive.mapWayPoints[closest].out_cost[i] = nil;

										if g_currentMission.autoLoadedMap ~= nil and AutoDrive.adXml ~= nil then
											removeXMLProperty(AutoDrive.adXml, "AutoDrive." .. g_currentMission.autoLoadedMap .. ".waypoints.wp".. closest ..".out" .. i) ;
											removeXMLProperty(AutoDrive.adXml, "AutoDrive." .. g_currentMission.autoLoadedMap .. ".waypoints.wp".. closest ..".out_cost" .. i) ;
										end;

										local incomingExists = false;
										for _,i2 in pairs(AutoDrive.mapWayPoints[self.nSelectedDebugPoint].incoming) do
											if i2 == closest or incomingExists then
												incomingExists = true;
												if AutoDrive.mapWayPoints[self.nSelectedDebugPoint].incoming[_ + 1] ~= nil then
													AutoDrive.mapWayPoints[self.nSelectedDebugPoint].incoming[_] = AutoDrive.mapWayPoints[self.nSelectedDebugPoint].incoming[_ + 1];
													AutoDrive.mapWayPoints[self.nSelectedDebugPoint].incoming[_ + 1] = nil;
												else
													AutoDrive.mapWayPoints[self.nSelectedDebugPoint].incoming[_] = nil;
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
								AutoDrive.mapWayPoints[closest].out[out_counter] = self.DebugPointsIterated[self.nSelectedDebugPoint].id;
								AutoDrive.mapWayPoints[closest].out_cost[out_counter] = 1;

								local incomingCounter = 1;
								for _,id in pairs(self.DebugPointsIterated[self.nSelectedDebugPoint].incoming) do
									incomingCounter = incomingCounter + 1;
								end;
								self.DebugPointsIterated[self.nSelectedDebugPoint].incoming[incomingCounter] = AutoDrive.mapWayPoints[closest].id;

								AutoDrive:MarkChanged()
							end;
							self.bChangeSelectedDebugPoint = false;
						end;

						if self.bChangeSelectedDebugPointSelection == true then
							self.nSelectedDebugPoint = self.nSelectedDebugPoint + 1;
							self.bChangeSelectedDebugPointSelection = false;
						end;
					end;
				end;
			end;
		end;


		if self == g_currentMission.controlledVehicle then

			if AutoDrive.printMessage ~= nil then
				local adFontSize = 0.014;
				local adPosX = 0.03; -- + g_currentMission.helpBoxWidth
				local adPosY = 0.975;
				setTextColor(1,1,1,1);
				renderText(adPosX, adPosY, adFontSize, AutoDrive.printMessage);
				--self.printMessage = nil;
			end;

			if self.printMessage ~= nil and AutoDrive.printMessage == nil then
				local adFontSize = 0.014;
				local adPosX = 0.03; -- + g_currentMission.helpBoxWidth
				local adPosY = 0.975;
				setTextColor(1,1,1,1);
				renderText(adPosX, adPosY, adFontSize, self.printMessage);
				--self.printMessage = nil;
			end;
		end;

		if AutoDrive.Hud ~= nil then
			if AutoDrive.Hud.showHud == true then
				AutoDrive.Hud:drawHud(self);
			end;
		end;
	end;
end; 

function getFillType_new(fillType, implementTypeName)
	local sFillType = g_i18n:getText("UNKNOWN"); 
	
	if FillUtil.fillTypeIndexToDesc[fillType] ~= nil then
		output1 =  FillUtil.fillTypeIndexToDesc[fillType].nameI18N
		if string.find(output1, "Missing") then
			sFillType = g_i18n:getText("UNKNOWN"); 
		else
			sFillType = output1;
		end;
	end;
	
	return sFillType;
end; 

function round(num, idp) 
	if Utils.getNoNil(num, 0) > 0 then 
		local mult = 10^(idp or 0); 
		return math.floor(num * mult + 0.5) / mult; 
	else 
		return 0; 
	end; 
end; 

function getPercentage(capacity, level) 
	return level / capacity * 100; 
end;

function AutoDrive:angleBetween(vec1, vec2)

	local scalarproduct_top = vec1.x * vec2.x + vec1.z * vec2.z;
	local scalarproduct_down = math.sqrt(vec1.x * vec1.x + vec1.z*vec1.z) * math.sqrt(vec2.x * vec2.x + vec2.z*vec2.z)
	local scalarproduct = scalarproduct_top / scalarproduct_down;

	return math.deg(math.acos(scalarproduct));
end

addModEventListener(AutoDrive);