AutoDrive = {};
AutoDrive.Version = "1.0.0.0";
AutoDrive.config_changed = false;

AutoDrive.directory = g_currentModDirectory;
AutoDrive.actions   = { 'ADToggleMouse', 'ADToggleHud', 'ADEnDisable', 'ADSelectTarget', 'ADSelectPreviousTarget', 'ADSelectTargetUnload',
						'ADSelectPreviousTargetUnload', 'ADActivateDebug', 'ADDebugShowClosest', 'ADDebugSelectNeighbor',
						'ADDebugChangeNeighbor', 'ADDebugCreateConnection', 'ADDebugCreateMapMarker', 'ADDebugDeleteWayPoint',
						'ADDebugForceUpdate', 'ADDebugDeleteDestination' }

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
	for _,n in pairs( { "load", "onUpdate", "onRegisterActionEvents", "onDelete", "onDraw", "onLeaveVehicle", "onEnterVehicle" } ) do
	  SpecializationUtil.registerEventListener(vehicleType, n, AutoDrive)
	end 
end

function AutoDrive:onRegisterActionEvents(isSelected, isOnActiveVehicle)   
	-- continue on client side only
	if not self.isClient then
		return
	end

	local registerEvents = isOnActiveVehicle;
	if self.ad ~= nil then
		registerEvents = registerEvents or self == g_currentMission.controlledVehicle; -- or self.ad.isActive;
	end;

	-- only in active vehicle
	if registerEvents then
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
			g_inputBinding:setActionEventTextVisibility(eventName, true)	
			__, eventName = InputBinding.registerActionEvent(g_inputBinding, 'ADToggleHud', self, AutoDrive.onActionCall, toggleButton ,true ,false ,true)
			g_inputBinding:setActionEventTextVisibility(eventName, true)
			__, eventName = InputBinding.registerActionEvent(g_inputBinding, 'ADEnDisable', self, AutoDrive.onActionCall, toggleButton ,true ,false ,true)
			g_inputBinding:setActionEventTextVisibility(eventName, true)
			__, eventName = InputBinding.registerActionEvent(g_inputBinding, 'ADSelectTarget', self, AutoDrive.onActionCall, toggleButton ,true ,false ,true)
			g_inputBinding:setActionEventTextVisibility(eventName, true)
			__, eventName = InputBinding.registerActionEvent(g_inputBinding, 'ADSelectPreviousTarget', self, AutoDrive.onActionCall, toggleButton ,true ,false ,true)
			g_inputBinding:setActionEventTextVisibility(eventName, false)
			__, eventName = InputBinding.registerActionEvent(g_inputBinding, 'ADSelectTargetUnload', self, AutoDrive.onActionCall, toggleButton ,true ,false ,true)
			g_inputBinding:setActionEventTextVisibility(eventName, false)
			__, eventName = InputBinding.registerActionEvent(g_inputBinding, 'ADSelectPreviousTargetUnload', self, AutoDrive.onActionCall, toggleButton ,true ,false ,true)
			g_inputBinding:setActionEventTextVisibility(eventName, false)
			__, eventName = InputBinding.registerActionEvent(g_inputBinding, 'ADActivateDebug', self, AutoDrive.onActionCall, toggleButton ,true ,false ,true)
			g_inputBinding:setActionEventTextVisibility(eventName, true)
			__, eventName = InputBinding.registerActionEvent(g_inputBinding, 'ADDebugShowClosest', self, AutoDrive.onActionCall, toggleButton ,true ,false ,true)
			g_inputBinding:setActionEventTextVisibility(eventName, false)
			__, eventName = InputBinding.registerActionEvent(g_inputBinding, 'ADDebugSelectNeighbor', self, AutoDrive.onActionCall, toggleButton ,true ,false ,true)
			g_inputBinding:setActionEventTextVisibility(eventName, false)
			__, eventName = InputBinding.registerActionEvent(g_inputBinding, 'ADDebugChangeNeighbor', self, AutoDrive.onActionCall, toggleButton ,true ,false ,true)
			g_inputBinding:setActionEventTextVisibility(eventName, false)
			__, eventName = InputBinding.registerActionEvent(g_inputBinding, 'ADDebugCreateConnection', self, AutoDrive.onActionCall, toggleButton ,true ,false ,true)
			g_inputBinding:setActionEventTextVisibility(eventName, false)
			__, eventName = InputBinding.registerActionEvent(g_inputBinding, 'ADDebugCreateMapMarker', self, AutoDrive.onActionCall, toggleButton ,true ,false ,true)
			g_inputBinding:setActionEventTextVisibility(eventName, false)
			__, eventName = InputBinding.registerActionEvent(g_inputBinding, 'ADDebugDeleteWayPoint', self, AutoDrive.onActionCall, toggleButton ,true ,false ,true)
			g_inputBinding:setActionEventTextVisibility(eventName, false)
			__, eventName = InputBinding.registerActionEvent(g_inputBinding, 'ADDebugForceUpdate', self, AutoDrive.onActionCall, toggleButton ,true ,false ,true)
			g_inputBinding:setActionEventTextVisibility(eventName, false)
			__, eventName = InputBinding.registerActionEvent(g_inputBinding, 'ADDebugDeleteDestination', self, AutoDrive.onActionCall, toggleButton ,true ,false ,true)
			g_inputBinding:setActionEventTextVisibility(eventName, false)			
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
	source(Utils.getFilename("AutoDriveFunc.lua", AutoDrive.directory))
	source(Utils.getFilename("AutoDriveTrailerUtil.lua", AutoDrive.directory))
	source(Utils.getFilename("AutoDriveXML.lua", AutoDrive.directory))
	source(Utils.getFilename("AutoDriveInputFunctions.lua", AutoDrive.directory))
	source(Utils.getFilename("AutoDriveGraphHandling.lua", AutoDrive.directory))
	source(Utils.getFilename("AutoDriveLineDraw.lua", AutoDrive.directory))
	source(Utils.getFilename("AutoDriveDriveFuncs.lua", AutoDrive.directory))
	source(Utils.getFilename("AutoDriveKeyEvents.lua", AutoDrive.directory))
	source(Utils.getFilename("AutoDriveTrigger.lua", AutoDrive.directory))
	source(Utils.getFilename("AutoDriveDijkstra.lua", AutoDrive.directory))
	source(Utils.getFilename("AutoDriveUtilFuncs.lua", AutoDrive.directory))

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

	AutoDrive:loadStoredXML();

	AutoDrive:initLineDrawing();

	-- Save Configuration when saving savegame
	FSBaseMission.saveSavegame = Utils.appendedFunction(FSBaseMission.saveSavegame, AutoDrive.saveSavegame);
end;

function AutoDrive:saveSavegame()
	if AutoDrive:GetChanged() == true then
		AutoDrive:saveToXML(AutoDrive.adXml);
	else
		if AutoDrive.adXml ~= nil then
			saveXMLFile(AutoDrive.adXml);
		end;
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
	self.ad.isActive = false;
	self.ad.roundTrip = false;
	self.ad.reverseTrack = false;
	self.ad.drivingForward = true;
	self.ad.targetX = 0;
	self.ad.targetZ = 0;
	self.ad.initialized = false;
	self.ad.wayPoints = {};
	self.ad.creationMode = false;
	self.ad.creationModeDual = false;
	self.ad.currentWayPoint = 0;
	self.nlastLogged = 0;
	self.nloggingInterval = 500;
	self.logMessage = "";
	self.nPrintTime = 3000;
	self.ad.targetSelected = -1;	
	self.ad.mapMarkerSelected = -1;
	self.ad.nameOfSelectedTarget = "";
	if AutoDrive ~= nil then
		if AutoDrive.mapMarker[1] ~= nil then
			self.ad.targetSelected = AutoDrive.mapMarker[1].id;
			self.ad.mapMarkerSelected = 1;
			self.ad.nameOfSelectedTarget = AutoDrive.mapMarker[1].name;
		end;	
	end;
	self.ad.targetMode = true;
	self.ad.targetSpeed = 40;
	self.ad.createMapPoints = false;
	self.ad.showMapMarker = true;
	self.ad.selectedDebugPoint = -1;
	self.ad.showSelectedDebugPoint = false;
	self.ad.changeSelectedDebugPoint = false;
	self.ad.iteratedDebugPoints = {};
	self.ad.inDeadLock = false;
	self.ad.timeTillDeadLock = 15000;
	self.ad.inDeadLockRepairCounter = 4;
	
	self.ad.stopAD = false;
	self.ad.creatingMapMarker = false;
	self.ad.enteringMapMarker = false;
	self.ad.enteredMapMarkerString = "";
	
	
	self.name = g_i18n:getText("UNKNOWN")
	self.ad.moduleInitialized = true;
	self.ad.currentInput = "";
	self.ad.lastSpeed = self.ad.targetSpeed;
	self.ad.speedOverride = nil;

	self.ad.unloadAtTrigger = false;
	self.ad.isUnloading = false;
	self.ad.isPaused = false;
	self.ad.unloadSwitch = false;
	self.ad.unloadType = -1;
	self.ad.isLoading = false;

	AutoDrive.Recalculation = {};

	self.ad.targetSelected_Unload = -1;
	self.ad.mapMarkerSelected_Unload = -1;
	self.ad.nameOfSelectedTarget_Unload = "";
	if AutoDrive ~= nil then
		if AutoDrive.mapMarker[1] ~= nil then
			self.ad.targetSelected_Unload = AutoDrive.mapMarker[1].id;
			self.ad.mapMarkerSelected_Unload = 1;
			self.ad.nameOfSelectedTarget_Unload = AutoDrive.mapMarker[1].name;
		end;
	end;

	self.ad.pauseTimer = 5000;
	self.ad.nToolTipWait = 300;
	self.ad.nToolTipTimer = 6000;
	self.ad.sToolTip = "";
	
	self.ad.choosingDestination = false;
	self.ad.chosenDestination = "";
	self.ad.enteredChosenDestination = "";

	self.ad.showingHud = true;
	self.ad.showingMouse = false;

	if AutoDrive.searchedTriggers ~= true then
		AutoDrive:getAllTriggers();
		AutoDrive.searchedTriggers = true;
	end;
end;

function AutoDrive:onActionCall(actionName, keyStatus, arg4, arg5, arg6)
	--print("AutoDrive onActionCall.." .. actionName);

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

function AutoDrive:InputHandling(vehicle, input)
	vehicle.ad.currentInput = input;

	if g_server == nil then
		AutoDriveInputEvent:sendEvent(vehicle);
	end;

	if vehicle.ad.currentInput == nil then
		return;
	end;
		
	if vehicle ~= g_currentMission.controlledVehicle then
		return;
	end;
			
	if input == "input_silomode" then
		AutoDrive:inputSiloMode(vehicle);
	end;

	if input == "input_roundtrip" then
		AutoDrive:inputRoundTrip(vehicle)
	end;

	if input == "input_record" and g_server ~= nil and g_dedicatedServerInfo == nil then
		AutoDrive:inputRecord(vehicle)
	end;

	if input == "input_start_stop" then
		if AutoDrive:isActive(vehicle) then
			AutoDrive:stopAD(vehicle);
		else
			AutoDrive:startAD(vehicle);
		end;

		AutoDrive.Hud:updateSingleButton("input_start_stop", vehicle.ad.isActive)
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

	if input == "input_showClosest" and g_server ~= nil and g_dedicatedServerInfo == nil then
		if vehicle.ad.showMapMarker == false then
			vehicle.ad.showMapMarker = true;
		else
			vehicle.ad.showMapMarker = false;
		end;

		AutoDrive.Hud:updateSingleButton("input_showClosest", vehicle.ad.showMapMarker)
	end;

	if input == "input_showNeighbor" and g_server ~= nil and g_dedicatedServerInfo == nil then
		AutoDrive:inputShowNeighbors(vehicle)		
	end;

	if input == "input_toggleConnection" and g_server ~= nil and g_dedicatedServerInfo == nil then
		local closest = AutoDrive:findClosestWayPoint(vehicle);
		AutoDrive:toggleConnectionBetween(AutoDrive.mapWayPoints[closest], vehicle.ad.iteratedDebugPoints[vehicle.ad.selectedDebugPoint]);
	end;

	if input == "input_nextNeighbor" then
		AutoDrive:nextSelectedDebugPoint(vehicle);
	end;

	if input == "input_createMapMarker" and g_server ~= nil and g_dedicatedServerInfo == nil then
		AutoDrive:inputCreateMapMarker(vehicle);
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

	if input == "input_toggleHud" then
		AutoDrive.Hud:toggleHud(vehicle);				
	end;

	if input == "input_toggleMouse" then
		AutoDrive.Hud:toggleMouse(vehicle);				
	end;

	if input == "input_removeWaypoint" and g_server ~= nil and g_dedicatedServerInfo == nil then
		if vehicle.ad.showMapMarker == true and AutoDrive.mapWayPoints[1] ~= nil then
			local closest = AutoDrive:findClosestWayPoint(vehicle)
			AutoDrive:removeMapWayPoint( AutoDrive.mapWayPoints[closest] );
		end;

	end;

	if input == "input_removeDestination" and g_server ~= nil and g_dedicatedServerInfo == nil then
		if vehicle.ad.showMapMarker == true and AutoDrive.mapWayPoints[1] ~= nil then
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

	if input == "input_continue" then
		if vehicle.ad.isPaused == true then
			vehicle.ad.isPaused = false;
		end;
	end;

	vehicle.ad.currentInput = "";

end;

function AutoDrive:graphcopy(Graph)
	local Q = {};
	for i in pairs(Graph) do
		local id = Graph[i]["id"];
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
	for i in pairs(wp) do
		--print(""..wp[i]["id"]);
	end;
	
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

function AutoDrive:onLeaveVehicle()
	self.ad.showingHud = AutoDrive.Hud.showHud;
	self.ad.showingMouse = AutoDrive.showMouse;

end;

function AutoDrive:onEnterVehicle()
	if self.ad.showingHud ~= AutoDrive.Hud.showHud then
		AutoDrive.Hud.toggleHud(self);
	end;
	if self.ad.showingMouse ~= AutoDrive.showMouse then
		AutoDrive.Hud:toggleMouse(self);
	end

	if self ~= g_currentMission.controlledVehicle then
		print("I am not the controlled vehicle");
		g_currentMission.controlledVehicle = self;
	end;
end;

function AutoDrive:mouseEvent(posX, posY, isDown, isUp, button)
	vehicle = g_currentMission.controlledVehicle;
	if vehicle ~= nil and AutoDrive.Hud.showHud == true then
		AutoDrive.Hud:mouseEvent(vehicle, posX, posY, isDown, isUp, button);
	end;
end; 

function AutoDrive:keyEvent(unicode, sym, modifier, isDown) 
	vehicle = g_currentMission.controlledVehicle
	if vehicle == nil or vehicle.ad == nil then
		return;
	end;
		
	AutoDrive:handleKeyEvents(vehicle, unicode, sym, modifier, isDown);
end; 

function AutoDrive:onUpdate(dt)
	if self.ad == nil then
		init(self);
	end;

	if self.ad.currentInput ~= "" and self.isServer then
		--print("I am the server and start input handling. let's see if they think so too");
		AutoDrive:InputHandling(self, self.ad.currentInput);
	end;
	
	AutoDrive:handleRecalculation(self);	
	AutoDrive:handleRecording(self);
	AutoDrive:handleDriving(self, dt);		
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
	if self.ad.moduleInitialized == false then
		return;
	end;
	
	if self.ad.currentWayPoint > 0 then
		if self.ad.wayPoints[self.ad.currentWayPoint+1] ~= nil then
			AutoDrive:drawLine(self.ad.wayPoints[self.ad.currentWayPoint], self.ad.wayPoints[self.ad.currentWayPoint+1], newColor(1,1,1,1));
		end;
		if self.ad.wayPoints[self.ad.currentWayPoint-1] ~= nil then
			AutoDrive:drawLine(self.ad.wayPoints[self.ad.currentWayPoint-1], self.ad.wayPoints[self.ad.currentWayPoint], newColor(1,1,1,1));
		end;
	end;
	if self.ad.creationMode == true then
		local _drawCounter = 1;
		for n in pairs(self.ad.wayPoints) do
			if self.ad.wayPoints[n+1] ~= nil then				
				AutoDrive:drawLine(self.ad.wayPoints[n], self.ad.wayPoints[n+1], newColor(1,1,1,1));
			else
				AutoDrive:drawLine(self.ad.wayPoints[n], newPoint(self.ad.wayPoints[n].x, self.ad.wayPoints[n].y+2, self.ad.wayPoints[n].z), newColor(1,1,1,1));
			end;
		end;
	end;

	if self == g_currentMission.controlledVehicle then
		AutoDrive:onDrawControlledVehicle(self);
	end;
	
	if self.ad.createMapPoints == true and self == g_currentMission.controlledVehicle then
		AutoDrive:onDrawCreationMode(self);
	end;		
end; 

function AutoDrive:onDrawControlledVehicle(vehicle)
	AutoDrive:drawJobs();

	if AutoDrive.printMessage ~= nil then
		local adFontSize = 0.014;
		local adPosX = 0.03;
		local adPosY = 0.975;
		setTextColor(1,1,1,1);
		setTextAlignment(RenderText.ALIGN_LEFT);
		renderText(adPosX, adPosY, adFontSize, AutoDrive.printMessage);
	end;

	if vehicle.printMessage ~= nil and AutoDrive.printMessage == nil then
		local adFontSize = 0.014;
		local adPosX = 0.03;
		local adPosY = 0.975;
		setTextColor(1,1,1,1);
		setTextAlignment(RenderText.ALIGN_LEFT);
		renderText(adPosX, adPosY, adFontSize, vehicle.printMessage);
	end;

	if AutoDrive.Hud ~= nil then
		if AutoDrive.Hud.showHud == true then
			AutoDrive.Hud:drawHud(vehicle);
		end;
	end;
end;

function AutoDrive:onDrawCreationMode(vehicle)
	local x1,y1,z1 = getWorldTranslation(vehicle.components[1].node);
	for i,point in pairs(AutoDrive.mapWayPoints) do
		local distance = getDistance(point.x,point.z,x1,z1);
		if distance < 50 then
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
						AutoDrive:drawLine(point, AutoDrive.mapWayPoints[neighbor], newColor(0,0,1,1));
					else
						AutoDrive:drawLine(point, AutoDrive.mapWayPoints[neighbor], newColor(0,1,0,1));
					end;
				end;
			end;
		end;
	end;

	for markerID,marker in pairs(AutoDrive.mapMarker) do
		local x1,y1,z1 = getWorldTranslation(vehicle.components[1].node);
		local x2,y2,z2 = getWorldTranslation(marker.node);
		local distance = getDistance(x2,z2,x1,z1);
		if distance < 50 then
			DebugUtil.drawDebugNode(marker.node,marker.name);
		end;
	end;

	if vehicle.ad.showMapMarker == true and AutoDrive.mapWayPoints[1] ~= nil then
		local closest = AutoDrive:findClosestWayPoint(vehicle);
		local x1,y1,z1 = getWorldTranslation(vehicle.components[1].node);					
		AutoDrive:drawLine(newPoint(x1,y1,z1), AutoDrive.mapWayPoints[closest], newColor(1,0,0,1));

		if vehicle.ad.showSelectedDebugPoint == true then
			if vehicle.ad.iteratedDebugPoints[vehicle.ad.selectedDebugPoint] ~= nil then
				AutoDrive:drawLine(newPoint(x1,y1,z1), vehicle.ad.iteratedDebugPoints[vehicle.ad.selectedDebugPoint], newColor(1,1,0,1));
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

function newColor(r, g, b, a)
	local color = {};
	color["r"] = r;
	color["g"] = g;
	color["b"] = b;
	color["a"] = a;
	return color;
end;

function newPoint(x, y, z)
	local point = {}
	point["x"] = x;
	point["y"] = y;
	point["z"] = z;
	return point;
end;

addModEventListener(AutoDrive);