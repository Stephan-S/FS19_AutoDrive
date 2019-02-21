AutoDrive = {};
AutoDrive.Version = "1.0.0.0";
AutoDrive.config_changed = false;

AutoDrive.directory = g_currentModDirectory;
AutoDrive.actions   = { 'ADToggleMouse', 'ADToggleHud', 'ADEnDisable', 'ADSelectTarget', 'ADSelectPreviousTarget', 'ADSelectTargetUnload',
						'ADSelectPreviousTargetUnload', 'ADActivateDebug', 'ADDebugShowClosest', 'ADDebugSelectNeighbor',
						'ADDebugChangeNeighbor', 'ADDebugCreateConnection', 'ADDebugCreateMapMarker', 'ADDebugDeleteWayPoint',
						'ADDebugForceUpdate', 'ADDebugDeleteDestination' }

AutoDrive.drawHeight = 0.3;

AutoDrive.MODE_DRIVETO = 1;
AutoDrive.MODE_COMPACTSILO = 2;
AutoDrive.MODE_PICKUPANDDELIVER = 3;
AutoDrive.MODE_DELIVERTO = 4;

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
		  --self:clearActionEventsTable( self.ActionEvents )
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
		__, eventName = InputBinding.registerActionEvent(g_inputBinding, 'ADSelectNextFillType', self, AutoDrive.onActionCall, toggleButton ,true ,false ,true)
		g_inputBinding:setActionEventTextVisibility(eventName, false)	
		__, eventName = InputBinding.registerActionEvent(g_inputBinding, 'ADSelectPreviousFillType', self, AutoDrive.onActionCall, toggleButton ,true ,false ,true)
		g_inputBinding:setActionEventTextVisibility(eventName, false)		
		__, eventName = InputBinding.registerActionEvent(g_inputBinding, 'ADRecord', self, AutoDrive.onActionCall, toggleButton ,true ,false ,true)
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
		

	AutoDrive.print = {};
	AutoDrive.print.currentMessage = nil;
	AutoDrive.print.nextMessage = nil;
	AutoDrive.print.showMessageFor = 3000;
	AutoDrive.print.currentMessageActiveSince = 0;

	AutoDrive:loadStoredXML();

	AutoDrive:initLineDrawing();
	
	AutoDrive.Hud = AutoDriveHud:new();
	AutoDrive.Hud:loadHud();

	-- Save Configuration when saving savegame
	FSBaseMission.saveSavegame = Utils.appendedFunction(FSBaseMission.saveSavegame, AutoDrive.saveSavegame);

	
	LoadTrigger.onActivateObject = Utils.overwrittenFunction(LoadTrigger.onActivateObject,AutoDrive.onActivateObject)
	LoadTrigger.getIsActivatable = Utils.overwrittenFunction(LoadTrigger.getIsActivatable,AutoDrive.getIsActivatable)
end;

function AutoDrive:onActivateObject(superFunc,vehicle)
	if vehicle~= nil then
		--if i'm in the vehicle, all is good and I can use the normal function, if not, i have to cheat:
		if g_currentMission.controlledVehicle ~= vehicle then
			--print("Called on AI Vehicle");
			local oldControlledVehicle = nil;
			if vehicle.ad ~= nil and vehicle.ad.oldControlledVehicle == nil then
				vehicle.ad.oldControlledVehicle = g_currentMission.controlledVehicle;
			else
				oldControlledVehicle = g_currentMission.controlledVehicle;
			end;
			g_currentMission.controlledVehicle = vehicle;

			superFunc(self, vehicle);
			--print("Called on AI Vehicle - Done");

			if vehicle.ad ~= nil and vehicle.ad.oldControlledVehicle ~= nil then
				g_currentMission.controlledVehicle = vehicle.ad.oldControlledVehicle;
				vehicle.ad.oldControlledVehicle = nil;
			else
				if oldControlledVehicle ~= nil then
					g_currentMission.controlledVehicle = oldControlledVehicle
				end;								
			end;
			return;
		else
			--print("Called on Player Vehicle");
		end
	end
	superFunc(self, vehicle);
end

-- LoadTrigger doesn't allow filling non controlled tools
function AutoDrive:getIsActivatable(superFunc,objectToFill)
	--when the trigger is filling, it uses this function without objectToFill
	if objectToFill ~= nil then
		local vehicle = objectToFill:getRootVehicle()
		if vehicle ~= nil and vehicle.ad ~= nil and vehicle.ad.isActive then
			--if i'm in the vehicle, all is good and I can use the normal function, if not, i have to cheat:
			if g_currentMission.controlledVehicle ~= vehicle then
				--print("getIsActivatable - Called on AI Vehicle");
				local oldControlledVehicle = nil;
				if vehicle.ad ~= nil and vehicle.ad.oldControlledVehicle == nil then
					vehicle.ad.oldControlledVehicle = g_currentMission.controlledVehicle;
				else
					oldControlledVehicle = g_currentMission.controlledVehicle;
				end;
				g_currentMission.controlledVehicle = vehicle or objectToFill;
				local result = superFunc(self,objectToFill);
				if vehicle.ad ~= nil and vehicle.ad.oldControlledVehicle ~= nil then
					g_currentMission.controlledVehicle = vehicle.ad.oldControlledVehicle;
					vehicle.ad.oldControlledVehicle = nil;
				else
					if oldControlledVehicle ~= nil then
						g_currentMission.controlledVehicle = oldControlledVehicle
					end;								
				end;
				return result;
			else
				--print("getIsActivatable - Called on Player Vehicle");
			end
		end
	else
		--print("getIsActivatable - Called with  objectToFill == nil");
	end
	return superFunc(self,objectToFill);
end

function AutoDrive:saveSavegame()
	if AutoDrive:GetChanged() == true or AutoDrive.HudChanged then
		AutoDrive:saveToXML(AutoDrive.adXml);	
		AutoDrive.config_changed = false;
		AutoDrive.HudChanged = false;
	else
		if AutoDrive.adXml ~= nil then
			saveXMLFile(AutoDrive.adXml);
		end;
	end;
end;

function init(self)
	if self.ad == nil then
		self.ad = {};		
	end;
	 
	self.ad.isActive = false;
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
	self.ad.mode = AutoDrive.MODE_DRIVETO;
	self.ad.targetSpeed = 40;
	self.ad.createMapPoints = false;
	self.ad.showClosestPoint = true;
	self.ad.selectedDebugPoint = -1;
	self.ad.showSelectedDebugPoint = false;
	self.ad.changeSelectedDebugPoint = false;
	self.ad.iteratedDebugPoints = {};
	self.ad.inDeadLock = false;
	self.ad.timeTillDeadLock = 15000;
	self.ad.inDeadLockRepairCounter = 4;
	
	self.ad.creatingMapMarker = false;
	self.ad.enteringMapMarker = false;
	self.ad.enteredMapMarkerString = "";
	
	
	self.name = g_i18n:getText("UNKNOWN")
	if self.getName ~= nil then
		self.name = self:getName();
	end;
	self.ad.moduleInitialized = true;
	self.ad.currentInput = "";
	self.ad.lastSpeed = self.ad.targetSpeed;
	self.ad.speedOverride = nil;

	self.ad.isUnloading = false;
	self.ad.isPaused = false;
	self.ad.unloadSwitch = false;
	self.ad.isLoading = false;
	self.ad.unloadFillTypeIndex = 2;

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
		AutoDrive:InputHandling(self, "input_showClosest");			
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
	if actionName == "ADSelectNextFillType" then
		AutoDrive:InputHandling(self, "input_nextFillType");
	end;
	if actionName == "ADSelectPreviousFillType" then
		AutoDrive:InputHandling(self, "input_previousFillType");
	end;
end;

function AutoDrive:InputHandling(vehicle, input)
	--print("AutoDrive InputHandling.." .. input);
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

	if input == "input_record" and g_server ~= nil and g_dedicatedServerInfo == nil then
		AutoDrive:inputRecord(vehicle)
	end;

	if input == "input_start_stop" then
		if AutoDrive:isActive(vehicle) then
			AutoDrive:disableAutoDriveFunctions(vehicle)
			--AutoDrive:stopAD(vehicle);
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
		AutoDrive:inputShowClosest(vehicle);

		AutoDrive.Hud:updateSingleButton("input_showClosest", vehicle.ad.showClosestPoint)
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
		if vehicle.ad.showClosestPoint == true and AutoDrive.mapWayPoints[1] ~= nil then
			local closest = AutoDrive:findClosestWayPoint(vehicle)
			AutoDrive:removeMapWayPoint( AutoDrive.mapWayPoints[closest] );
		end;

	end;

	if input == "input_removeDestination" and g_server ~= nil and g_dedicatedServerInfo == nil then
		if vehicle.ad.showClosestPoint == true and AutoDrive.mapWayPoints[1] ~= nil then
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
		
		
		Q[i] = createNode(id, Graph[i].x, Graph[i].y, Graph[i].z, out,incoming,out_cost, marker);		
	end;
	return Q;
end;

function createNode(id,x,y,z,out,incoming,out_cost, marker)
	local p = {};
	p["x"] = x;
	p["y"] = y;
	p["z"] = z;
	p["id"] = id;
	p["out"] = out;
	p["incoming"] = incoming;
	p["out_cost"] = out_cost;
	p["marker"] = marker;
	
	return p;
end

function AutoDrive:FastShortestPath(Graph,start,markerName, markerID)
	
	local wp = {};
	local count = 1;
	local id = start;
	while id ~= -1 and id ~= nil do		
		wp[count] = Graph[id];
		count = count+1;
		if id == markerID then
			id = nil;
		else
			id = AutoDrive.mapWayPoints[id].marker[markerName];
		end;
	end;
	
	local wp_copy = AutoDrive:graphcopy(wp);

	--local path = "Path: " .. start;
	--local last = wp[count-1];
	--for i,wp in pairs(wp_copy) do
	--	path = path .. " -> " .. wp.id;	
	--end;
	--print(path);
	--DebugUtil.printTableRecursively(last,":", 0, 1);		
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
end;

function AutoDrive:mouseEvent(posX, posY, isDown, isUp, button)
	local vehicle = g_currentMission.controlledVehicle;

	if vehicle ~= nil and AutoDrive.Hud.showHud == true then
		AutoDrive.Hud:mouseEvent(vehicle, posX, posY, isDown, isUp, button);
	end;
end; 

function AutoDrive:keyEvent(unicode, sym, modifier, isDown) 
	local vehicle = g_currentMission.controlledVehicle

	if vehicle == nil or vehicle.ad == nil then
		return;
	end;
		
	AutoDrive:handleKeyEvents(vehicle, unicode, sym, modifier, isDown);
end; 

function AutoDrive:onUpdate(dt)
	if self.ad == nil then
		init(self);
	end;

	if self.ad.oldControlledVehicle ~= nil then
		--print("Reinstalling controlled vehicle")
		g_currentMission.controlledVehicle = self.ad.oldControlledVehicle;
		self.ad.oldControlledVehicle = nil;
		AutoDrive.oldControlledVehicle = nil;
	end;

	if self.ad.currentInput ~= "" and self.isServer then
		--print("I am the server and start input handling. let's see if they think so too");
		AutoDrive:InputHandling(self, self.ad.currentInput);
	end;
	
	AutoDrive:handleRecalculation(self);	
	AutoDrive:handleRecording(self);
	AutoDrive:handleDriving(self, dt);
	AutoDrive:log(self, dt);	
	AutoDrive:handleIntegrityCheck(self);
end;

function AutoDrive:log(vehicle, dt)	
	vehicle.nlastLogged = vehicle.nlastLogged + dt;
	if vehicle.nlastLogged >= vehicle.nloggingInterval then
		vehicle.nlastLogged = vehicle.nlastLogged - vehicle.nloggingInterval;
		if vehicle.logMessage ~= "" then
			print(vehicle.logMessage);
			vehicle.logMessage = "";
		end;
	end;
	
end;

function AutoDrive:addlog(text)
	self.logMessage = text;
end;

function createVector(x,y,z)
	local t = {x=x, y=y, z=z};
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
		local nextP = nil;
		local outIndex = 1;
		if point.out ~= nil then			
			if point.out[outIndex] ~= nil then
				nextP = AutoDrive.mapWayPoints[point.out[outIndex]];
			end;

			while nextP ~= nil do
				local vecToNextPoint 	= {x = nextP.x - point.x, 	z = nextP.z - point.z};
				local vecToVehicle 		= {x = point.x - x1, 		z = point.z - z1 };
				local angleToNextPoint 	= AutoDrive:angleBetween(vehicleVector, vecToNextPoint);
				local angleToVehicle 	= AutoDrive:angleBetween(vehicleVector, vecToVehicle);
				local dis = getDistance(point.x,point.z,x1,z1);

				if closest == -1 and (math.abs(angleToNextPoint) < 60 and math.abs(angleToVehicle) < 30) then
					closest = point.id;
					distance = dis;
					angle = angleToNextPoint;
					--print("TempAngle to vehicle: " .. angleToVehicle);
				else
					if math.abs(angleToNextPoint) < math.abs(angle) then
						if math.abs(angleToVehicle) < 60 then
							if math.abs(angle) < 20 then
								if dis < distance then
									closest = point.id;
									distance = dis;
									angle = angleToNextPoint;
									--print("TempAngle to vehicle: " .. angleToVehicle);
								end;
							else
								closest = point.id;
								distance = dis;
								angle = angleToNextPoint;
							end;
						end;
					end;
				end;

				outIndex = outIndex + 1;
				if point.out[outIndex] ~= nil then
					nextP = AutoDrive.mapWayPoints[point.out[outIndex]];
				else
					nextP = nil;
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
	if self.ad.creationMode == true and self.ad.createMapPoints == false and self == g_currentMission.controlledVehicle then
		local _drawCounter = 1;
		for n in pairs(self.ad.wayPoints) do
			if self.ad.wayPoints[n+1] ~= nil then				
				AutoDrive:drawLine(self.ad.wayPoints[n], self.ad.wayPoints[n+1], newColor(1,1,1,1));
			else
				--AutoDrive:drawLine(self.ad.wayPoints[n], createVector(self.ad.wayPoints[n].x, self.ad.wayPoints[n].y+0.3, self.ad.wayPoints[n].z), newColor(1,1,1,1));
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

	if AutoDrive.print.currentMessage ~= nil then
		local adFontSize = 0.014;
		local adPosX = 0.03;
		local adPosY = 0.975;
		setTextColor(1,1,1,1);
		setTextAlignment(RenderText.ALIGN_LEFT);
		renderText(adPosX, adPosY, adFontSize, AutoDrive.print.currentMessage);
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

	if vehicle.ad.showClosestPoint == true and AutoDrive.mapWayPoints[1] ~= nil then
		local closest = AutoDrive:findClosestWayPoint(vehicle);
		local x1,y1,z1 = getWorldTranslation(vehicle.components[1].node);
		
		if vehicle.ad.showClosestPoint == true then					
			AutoDrive:drawLine(createVector(x1,y1+4,z1), AutoDrive.mapWayPoints[closest], newColor(1,0,0,1));
		end;
	end;

	if vehicle.ad.showSelectedDebugPoint == true and AutoDrive.mapWayPoints[1] ~= nil then
		local closest = AutoDrive:findClosestWayPoint(vehicle);
		local x1,y1,z1 = getWorldTranslation(vehicle.components[1].node);
		if vehicle.ad.showSelectedDebugPoint == true then
			if vehicle.ad.iteratedDebugPoints[vehicle.ad.selectedDebugPoint] ~= nil then
				AutoDrive:drawLine(createVector(x1,y1+4,z1), vehicle.ad.iteratedDebugPoints[vehicle.ad.selectedDebugPoint], newColor(1,1,0,1));
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
	local color = {r=r, g=g, b=b, a=a};
	return color;
end;

function AutoDrive:handleIntegrityCheck(vehicle)
	if AutoDrive.handledIntegrity ~= true then
		for _,wp in pairs(AutoDrive.mapWayPoints) do
			if wp.y == -1 then
				wp.y = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, wp.x, 1, wp.z)
			end;
		end;
		AutoDrive.handledIntegrity = true;
	end;
end;

addModEventListener(AutoDrive);