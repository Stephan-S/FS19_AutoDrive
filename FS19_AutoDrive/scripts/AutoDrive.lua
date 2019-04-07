AutoDrive = {};
AutoDrive.Version = "1.0.0.5";
AutoDrive.config_changed = false;

AutoDrive.directory = g_currentModDirectory;
AutoDrive.actions   = { 'ADToggleMouse', 'ADToggleHud', 'ADEnDisable', 'ADSelectTarget', 'ADSelectPreviousTarget', 'ADSelectTargetUnload',
						'ADSelectPreviousTargetUnload', 'ADActivateDebug', 'ADDebugShowClosest', 'ADDebugSelectNeighbor',
						'ADDebugChangeNeighbor', 'ADDebugCreateConnection', 'ADDebugCreateMapMarker', 'ADDebugDeleteWayPoint',
						'ADDebugForceUpdate', 'ADDebugDeleteDestination', 'ADSilomode' }

AutoDrive.drawHeight = 0.3;

AutoDrive.MODE_DRIVETO = 1;
AutoDrive.MODE_PICKUPANDDELIVER = 2;
AutoDrive.MODE_DELIVERTO = 3;
AutoDrive.MODE_UNLOAD = 4;

AutoDrive.WAYPOINTS_PER_PACKET = 25;

function AutoDrive:prerequisitesPresent(specializations)
    return true;
end;

function AutoDrive.registerEventListeners(vehicleType)    
	for _,n in pairs( { "load", "onUpdate", "onRegisterActionEvents", "onDelete", "onDraw", "onLeaveVehicle"} ) do
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
		__, eventName = InputBinding.registerActionEvent(g_inputBinding, 'ADSilomode', self, AutoDrive.onActionCall, toggleButton ,true ,false ,true)
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
		__, eventName = InputBinding.registerActionEvent(g_inputBinding, 'AD_export_routes', self, AutoDrive.onActionCall, toggleButton ,true ,false ,true)
		g_inputBinding:setActionEventTextVisibility(eventName, false)		
		__, eventName = InputBinding.registerActionEvent(g_inputBinding, 'AD_import_routes', self, AutoDrive.onActionCall, toggleButton ,true ,false ,true)
		g_inputBinding:setActionEventTextVisibility(eventName, false)		
		__, eventName = InputBinding.registerActionEvent(g_inputBinding, 'AD_upload_routes', self, AutoDrive.onActionCall, toggleButton ,true ,false ,true)
		g_inputBinding:setActionEventTextVisibility(eventName, false)	
	end
end

function AutoDrive:onDelete()		
end;

function AutoDrive:loadMap(name)	
	source(Utils.getFilename("scripts/AutoDriveFunc.lua", AutoDrive.directory))
	source(Utils.getFilename("scripts/AutoDriveTrailerUtil.lua", AutoDrive.directory))
	source(Utils.getFilename("scripts/AutoDriveXML.lua", AutoDrive.directory))
	source(Utils.getFilename("scripts/AutoDriveInputFunctions.lua", AutoDrive.directory))
	source(Utils.getFilename("scripts/AutoDriveGraphHandling.lua", AutoDrive.directory))
	source(Utils.getFilename("scripts/AutoDriveLineDraw.lua", AutoDrive.directory))
	source(Utils.getFilename("scripts/AutoDriveDriveFuncs.lua", AutoDrive.directory))
	source(Utils.getFilename("scripts/AutoDriveKeyEvents.lua", AutoDrive.directory))
	source(Utils.getFilename("scripts/AutoDriveTrigger.lua", AutoDrive.directory))
	source(Utils.getFilename("scripts/AutoDriveDijkstra.lua", AutoDrive.directory))
	source(Utils.getFilename("scripts/AutoDriveUtilFuncs.lua", AutoDrive.directory))
	source(Utils.getFilename("scripts/AutoDriveMultiplayer.lua", AutoDrive.directory))
	source(Utils.getFilename("scripts/AutoDrivePathPlanning.lua", AutoDrive.directory))
	source(Utils.getFilename("scripts/AutoDriveCombineMode.lua", AutoDrive.directory))
	source(Utils.getFilename("scripts/FieldDataCallback.lua", AutoDrive.directory))
	source(Utils.getFilename("scripts/AutoDrivePathFinder.lua", AutoDrive.directory))
	source(Utils.getFilename("scripts/PathFinderCallBack.lua", AutoDrive.directory))

	if AutoDrive_printedDebug ~= true then
		--DebugUtil.printTableRecursively(g_currentMission, "	:	",0,2);
		print("Map title: " .. g_currentMission.missionInfo.map.title);
		if g_currentMission.missionInfo.savegameDirectory ~= nil then 
			--print("Savegame location: " .. g_currentMission.missionInfo.savegameDirectory);
		else
			if g_currentMission.missionInfo.savegameIndex ~= nil then
				--print("Savegame location via index: " .. getUserProfileAppPath() .. "savegame" .. g_currentMission.missionInfo.savegameIndex);
			else
				--print("No savegame located");
			end;
		end;
		
		AutoDrive_printedDebug = true;
	end;
	
	AutoDrive.loadedMap = g_currentMission.missionInfo.map.title;
	AutoDrive.loadedMap = string.gsub(AutoDrive.loadedMap, " ", "_");
	AutoDrive.loadedMap = string.gsub(AutoDrive.loadedMap, "%.", "_");
	AutoDrive.loadedMap = string.gsub(AutoDrive.loadedMap, ",", "_");		
	AutoDrive.loadedMap = string.gsub(AutoDrive.loadedMap, ":", "_");	
	AutoDrive.loadedMap = string.gsub(AutoDrive.loadedMap, ";", "_");	
	print("map " .. AutoDrive.loadedMap .. " was loaded");		
		
	AutoDrive.mapWayPoints = {};
	AutoDrive.mapWayPointsCounter = 0;
	AutoDrive.mapMarker = {};
	AutoDrive.mapMarkerCounter = 0;
	AutoDrive.showMouse = false;					
		
	AutoDrive.lastSetSpeed = 50;

	AutoDrive.print = {};
	AutoDrive.print.currentMessage = nil;
	AutoDrive.print.nextMessage = nil;
	AutoDrive.print.showMessageFor = 6000;
	AutoDrive.print.currentMessageActiveSince = 0;
	AutoDrive.requestedWaypoints = false;
	AutoDrive.requestedWaypointCount = 1;
	AutoDrive.playerSendsMapToServer = false;

	AutoDrive:loadStoredXML();

	AutoDrive:initLineDrawing();
	
	AutoDrive.Hud = AutoDriveHud:new();
	AutoDrive.Hud:loadHud();

	-- Save Configuration when saving savegame
	FSBaseMission.saveSavegame = Utils.appendedFunction(FSBaseMission.saveSavegame, AutoDrive.saveSavegame);

	
	LoadTrigger.onActivateObject = Utils.overwrittenFunction(LoadTrigger.onActivateObject,AutoDrive.onActivateObject)
	LoadTrigger.getIsActivatable = Utils.overwrittenFunction(LoadTrigger.getIsActivatable,AutoDrive.getIsActivatable)

	if g_server ~= nil then
		AutoDrive.Server = {};
		AutoDrive.Server.Users = {};
	else
		AutoDrive.highestIndex = 1;
	end;

	AutoDrive.waitingUnloadDrivers = {}
end;

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
	self.ad.isStopping = false;
	self.ad.drivingForward = true;
	self.ad.targetX = 0;
	self.ad.targetZ = 0;
	self.ad.initialized = false;
	self.ad.wayPoints = {};
	self.ad.wayPointsChanged = true;
	self.ad.creationMode = false;
	self.ad.creationModeDual = false;
	self.ad.currentWayPoint = 0;
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
	self.ad.targetSpeed = AutoDrive.lastSetSpeed;
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
	self.ad.speedOverride = -1;

	self.ad.isUnloading = false;
	self.ad.isPaused = false;
	self.ad.unloadSwitch = false;
	self.ad.isLoading = false;
	self.ad.unloadFillTypeIndex = 2;
	self.ad.isPausedCauseTraffic = false;

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

	self.ad.nToolTipWait = 300;
	self.ad.nToolTipTimer = 6000;
	self.ad.sToolTip = "";

	self.ad.destinationPrintTimer = 0;
	
	self.ad.choosingDestination = false;
	self.ad.chosenDestination = "";
	self.ad.enteredChosenDestination = "";

	if AutoDrive.showingHud ~= nil then
		self.ad.showingHud = AutoDrive.showingHud;
	else
		self.ad.showingHud = true;
	end;
	self.ad.showingMouse = false;

	self.ad.requestWayPointTimer = 10000;

	--variables the server sets so that the clients can act upon it:
	self.ad.disableAI = 0;
	self.ad.enableAI = 0;

	self.ad.combineState = AutoDrive.COMBINE_UNINITIALIZED;
	self.ad.currentCombine = nil;
	self.ad.currentDriver = nil;

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
	if actionName == "AD_upload_routes" then
		AutoDrive:InputHandling(self, "input_uploadRoutes");
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

function AutoDrive:onLeaveVehicle()	
	local storedshowingHud = self.ad.showingHud;
	local storedMouse = self.ad.showingMouse;
	if (AutoDrive.showMouse) then
		AutoDrive.Hud:toggleMouse(self);
	end;
	self.ad.showingHud = storedshowingHud
	self.ad.showingMouse = storedMouse;
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

	if self.ad.currentInput ~= "" and self.isServer then
		AutoDrive:InputHandling(self, self.ad.currentInput);
	end;
	
	AutoDrive:handleRecalculation(self);	
	AutoDrive:handleRecording(self);
	AutoDrive:handleDriving(self, dt);
	AutoDrive:handleYPositionIntegrityCheck(self);
	AutoDrive:handleClientIntegrity(self);
	AutoDrive:handleMultiplayer(self, dt);
	
	if self.typeDesc == "harvester" then
		AutoDrive:handleCombineHarvester(self, dt)
	end;

	if self.ad.destinationPrintTimer > 0 then
		self.ad.destinationPrintTimer = self.ad.destinationPrintTimer - dt;
	end;

	AutoDrive.runThisFrame = true;
end;

function AutoDrive:onDraw()
	if self.ad.moduleInitialized == false then
		return;
	end;

	if self.ad ~= nil then
		if self.ad.showingHud ~= AutoDrive.Hud.showHud then
			AutoDrive.Hud:toggleHud(self);
		end;
		if self.ad.showingMouse ~= AutoDrive.showMouse then
			AutoDrive.Hud:toggleMouse(self);
		end
	end;
	
	if self.ad.currentWayPoint > 0 and self.ad.wayPoints ~= nil then
		if self.ad.wayPoints[self.ad.currentWayPoint+1] ~= nil then
			AutoDrive:drawLine(self.ad.wayPoints[self.ad.currentWayPoint], self.ad.wayPoints[self.ad.currentWayPoint+1], 1, 1, 1, 1);
		end;
	end;

	--if self.ad.mode == AutoDrive.MODE_UNLOAD and self.ad.combineState ~= AutoDrive.COMBINE_UNINITIALIZED then
		--if ADTableLength(self.ad.wayPoints) > 1 then
			--for i=2, ADTableLength(self.ad.wayPoints), 1 do
				--AutoDrive:drawLine(self.ad.wayPoints[i-1], self.ad.wayPoints[i], 1, 1, 1, 1);
			--end;
		--end;
	--end;

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
		else
			AutoDrive.Hud:drawMinimalHud(vehicle);
		end;
	end;
end;

function AutoDrive:onDrawCreationMode(vehicle)
	local x1,y1,z1 = getWorldTranslation(vehicle.components[1].node);
	for i,point in pairs(AutoDrive.mapWayPoints) do
		local distance = AutoDrive:getDistance(point.x,point.z,x1,z1);
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
					if target ~= nil then
						if testDual == true then
							AutoDrive:drawLine(point, AutoDrive.mapWayPoints[neighbor], 0, 0, 1, 1);
						else
							local deltaX = AutoDrive.mapWayPoints[neighbor].x - point.x
							local deltaY = AutoDrive.mapWayPoints[neighbor].y - point.y
							local deltaZ = AutoDrive.mapWayPoints[neighbor].z - point.z
							AutoDrive:drawLine(point, AutoDrive.mapWayPoints[neighbor], 0, 1, 0, 1);

							local vecX = point.x - AutoDrive.mapWayPoints[neighbor].x;
							local vecZ = point.z - AutoDrive.mapWayPoints[neighbor].z;

							local angleRad = math.atan2(vecZ, vecX);

							angleRad = normalizeAngle(angleRad);

							local arrowLength = 0.3;

							local arrowLeft = normalizeAngle(angleRad + math.rad(-20));
							local arrowRight = normalizeAngle(angleRad + math.rad(20));

							local arrowLeftX = AutoDrive.mapWayPoints[neighbor].x + math.cos(arrowLeft) * arrowLength;
							local arrowLeftZ = AutoDrive.mapWayPoints[neighbor].z + math.sin(arrowLeft) * arrowLength;

							local arrowRightX = AutoDrive.mapWayPoints[neighbor].x + math.cos(arrowRight) * arrowLength;
							local arrowRightZ = AutoDrive.mapWayPoints[neighbor].z + math.sin(arrowRight) * arrowLength;

							local arrowPointLeft = {};
							arrowPointLeft.x = arrowLeftX;
							arrowPointLeft.y = AutoDrive.mapWayPoints[neighbor].y;
							arrowPointLeft.z = arrowLeftZ;

							local arrowPointRight = {};
							arrowPointRight.x = arrowRightX;
							arrowPointRight.y = AutoDrive.mapWayPoints[neighbor].y;
							arrowPointRight.z = arrowRightZ;
							
							AutoDrive:drawLine(arrowPointLeft, AutoDrive.mapWayPoints[neighbor], 0, 1, 0, 1);
							AutoDrive:drawLine(arrowPointRight, AutoDrive.mapWayPoints[neighbor], 0, 1, 0, 1);
						end;
					end;
				end;
			end;
		end;
	end;

	for markerID,marker in pairs(AutoDrive.mapMarker) do
		local x1,y1,z1 = getWorldTranslation(vehicle.components[1].node);
		local x2,y2,z2 = getWorldTranslation(marker.node);
		local distance = AutoDrive:getDistance(x2,z2,x1,z1);
		if distance < 50 then
			DebugUtil.drawDebugNode(marker.node,marker.name);
		end;
	end;

	if vehicle.ad.showClosestPoint == true and AutoDrive.mapWayPoints[1] ~= nil then
		local closest = AutoDrive:findClosestWayPoint(vehicle);
		local x1,y1,z1 = getWorldTranslation(vehicle.components[1].node);
		
		if vehicle.ad.showClosestPoint == true then					
			AutoDrive:drawLine(AutoDrive:createVector(x1,y1+4,z1), AutoDrive.mapWayPoints[closest], 1, 0, 0, 1);
		end;
	end;

	if vehicle.ad.showSelectedDebugPoint == true and AutoDrive.mapWayPoints[1] ~= nil then
		local closest = AutoDrive:findClosestWayPoint(vehicle);
		local x1,y1,z1 = getWorldTranslation(vehicle.components[1].node);
		if vehicle.ad.showSelectedDebugPoint == true then
			if vehicle.ad.iteratedDebugPoints[vehicle.ad.selectedDebugPoint] ~= nil then
				AutoDrive:drawLine(AutoDrive:createVector(x1,y1+4,z1), vehicle.ad.iteratedDebugPoints[vehicle.ad.selectedDebugPoint], 1, 1, 0, 1);
			end;
		end;
	end;
end;

function AutoDrive:MarkChanged()
	AutoDrive.config_changed = true;
	AutoDrive.handledRecalculation = false;
end;

function AutoDrive:GetChanged()
	return AutoDrive.config_changed;
end;

function normalizeAngle(inputAngle)
	if inputAngle > (2*math.pi) then
			inputAngle = inputAngle - (2*math.pi);	
	else
			if inputAngle < -(2*math.pi) then
				inputAngle = inputAngle + (2*math.pi);
			end;
	end;

	return inputAngle;
end;

function normalizeAngle2(inputAngle)
	if inputAngle > (2*math.pi) then
			inputAngle = inputAngle - (2*math.pi);	
	else
			if inputAngle < 0 then
				inputAngle = inputAngle + (2*math.pi);
			end;
	end;

	return inputAngle;
end;

addModEventListener(AutoDrive);