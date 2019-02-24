AutoDriveUpdateEvent = {};
AutoDriveUpdateEvent_mt = Class(AutoDriveUpdateEvent, Event);

InitEventClass(AutoDriveUpdateEvent, "AutoDriveUpdateEvent");

function AutoDriveUpdateEvent:emptyNew()
    local self = Event:new(AutoDriveUpdateEvent_mt);
    self.className="AutoDriveUpdateEvent";
    return self;
end;

function AutoDriveUpdateEvent:new(vehicle)
	if AutoDrive == nil then
		return;
	end;
    local self = AutoDriveUpdateEvent:emptyNew()
	self.vehicle = vehicle;
		
	self.isActive = vehicle.ad.isActive;
	self.isStopping = vehicle.ad.isStopping;
	self.drivingForward = vehicle.ad.drivingForward;
	self.targetX = vehicle.ad.targetX;
	self.targetZ = vehicle.ad.targetZ;
	self.initialized = vehicle.ad.initialized;
	self.wayPoints = vehicle.ad.wayPoints;
	self.creationMode = vehicle.ad.creationMode;
	self.creationModeDual = vehicle.ad.creationModeDual;
	self.currentWayPoint = vehicle.ad.currentWayPoint;
	self.targetSelected = vehicle.ad.targetSelected;	
	self.mapMarkerSelected = vehicle.ad.mapMarkerSelected;
	self.nameOfSelectedTarget = vehicle.ad.nameOfSelectedTarget;
		
	self.mode = vehicle.ad.mode;
	self.targetSpeed = vehicle.ad.targetSpeed;
	self.createMapPoints = vehicle.ad.createMapPoints;
	self.showClosestPoint = vehicle.ad.showClosestPoint;
	self.selectedDebugPoint = vehicle.ad.selectedDebugPoint;
	self.showSelectedDebugPoint = vehicle.ad.showSelectedDebugPoint;
	self.changeSelectedDebugPoint = vehicle.ad.changeSelectedDebugPoint;
	self.iteratedDebugPoints = vehicle.ad.iteratedDebugPoints;
	self.inDeadLock = vehicle.ad.inDeadLock;
	self.timeTillDeadLock = vehicle.ad.timeTillDeadLock;
	self.inDeadLockRepairCounter = vehicle.ad.inDeadLockRepairCounter;
			
	self.name = vehicle.name;

	self.moduleInitialized = vehicle.ad.moduleInitialized;
	self.currentInput = vehicle.ad.currentInput;
	--print("Received currentInput: " .. self.currentInput .. " in update event");
	self.lastSpeed = vehicle.ad.lastSpeed;
	self.speedOverride = vehicle.ad.speedOverride;

	self.isUnloading = vehicle.ad.isUnloading;
	self.isPaused = vehicle.ad.isPaused;
	self.unloadSwitch = vehicle.ad.unloadSwitch;
	self.isLoading = vehicle.ad.isLoading;
	self.unloadFillTypeIndex = vehicle.ad.unloadFillTypeIndex;

	self.targetSelected_Unload = vehicle.ad.targetSelected_Unload;
	self.mapMarkerSelected_Unload = vehicle.ad.mapMarkerSelected_Unload;
	self.nameOfSelectedTarget_Unload = vehicle.ad.nameOfSelectedTarget_Unload;

	self.nToolTipWait = vehicle.ad.nToolTipWait;
	self.nToolTipTimer = vehicle.ad.nToolTipTimer;
	self.sToolTip = vehicle.ad.sToolTip;
	
	self.choosingDestination = vehicle.ad.choosingDestination;
	self.chosenDestination = vehicle.ad.chosenDestination;
	self.enteredChosenDestination = vehicle.ad.enteredChosenDestination;

	self.enableAI = vehicle.ad.enableAI;
	self.disableAI = vehicle.ad.disableAI;

	self.showingHud = vehicle.ad.showingHud;
	self.showingMouse = vehicle.ad.showingMouse;
		
	--print("event new")
    return self;
end;

function AutoDriveUpdateEvent:writeStream(streamId, connection)
	if AutoDrive == nil then
		return;
	end;
	streamWriteInt32(streamId, NetworkUtil.getObjectId(self.vehicle));
	
	streamWriteBool(streamId, self.isActive);
	streamWriteBool(streamId, self.isStopping);
	streamWriteBool(streamId, self.drivingForward);
	streamWriteFloat32(streamId, self.targetX);
	streamWriteFloat32(streamId, self.targetZ);
	streamWriteBool(streamId, self.initialized);

	self.wayPointsString = "";
	for i, point in pairs(self.wayPoints) do 
		if self.wayPointsString == "" then
			self.wayPointsString = self.wayPointsString .. point.id;
		else
			self.wayPointsString = self.wayPointsString .. "," .. point.id;
		end;
	end;

	streamWriteStringOrEmpty(streamId, self.wayPointsString);
	streamWriteBool(streamId, self.creationMode);
	streamWriteBool(streamId, self.creationModeDual);
	streamWriteInt16(streamId, self.currentWayPoint);
	streamWriteInt16(streamId, self.targetSelected);
	streamWriteInt16(streamId, self.mapMarkerSelected);
	streamWriteStringOrEmpty(streamId, self.nameOfSelectedTarget);
		
	streamWriteInt8(streamId, self.mode);
	streamWriteInt16(streamId, self.targetSpeed);
	streamWriteBool(streamId, self.createMapPoints);
	streamWriteBool(streamId, self.showClosestPoint);
	streamWriteInt16(streamId, self.selectedDebugPoint);
	streamWriteBool(streamId, self.showSelectedDebugPoint);
	streamWriteBool(streamId, self.changeSelectedDebugPoint);

	self.debugPointsIteratedString = "";
	for i, point in pairs(self.iteratedDebugPoints) do 
		if self.debugPointsIteratedString == "" then
			self.debugPointsIteratedString = self.debugPointsIteratedString .. point.id;
		else			
			self.debugPointsIteratedString = self.debugPointsIteratedString .. "," .. point.id;
		end;
	end;
	streamWriteStringOrEmpty(streamId, self.debugPointsIteratedString);

	streamWriteBool(streamId, self.inDeadLock);
	streamWriteFloat32(streamId, self.timeTillDeadLock);
	streamWriteInt8(streamId, self.inDeadLockRepairCounter);
			
	streamWriteStringOrEmpty(streamId, self.name);

	streamWriteBool(streamId, self.moduleInitialized);
	streamWriteStringOrEmpty(streamId, self.currentInput);
	streamWriteFloat32(streamId, self.lastSpeed);
	streamWriteFloat32(streamId, self.speedOverride);

	streamWriteBool(streamId, self.isUnloading);
	streamWriteBool(streamId, self.isPaused);
	streamWriteBool(streamId, self.unloadSwitch);
	streamWriteBool(streamId, self.isLoading);
	streamWriteInt8(streamId, self.unloadFillTypeIndex);

	streamWriteInt16(streamId, self.targetSelected_Unload);
	streamWriteInt16(streamId, self.mapMarkerSelected_Unload);
	streamWriteStringOrEmpty(streamId, self.nameOfSelectedTarget_Unload)

	streamWriteFloat32(streamId, self.nToolTipWait);
	streamWriteFloat32(streamId, self.nToolTipTimer);
	streamWriteStringOrEmpty(streamId, self.sToolTip);
	
	streamWriteBool(streamId, self.choosingDestination);
	streamWriteStringOrEmpty(streamId, self.chosenDestination);
	streamWriteStringOrEmpty(streamId, self.enteredChosenDestination);

	streamWriteInt8(streamId, self.enableAI);
	streamWriteInt8(streamId, self.disableAI);

	streamWriteBool(streamId, self.showingHud);
	streamWriteBool(streamId, self.showingMouse);
	
	streamWriteBool(streamId, AutoDrive.Hud.showHud);
	streamWriteBool(streamId, AutoDrive.showMouse);

	-- print("event writeStream")
end;

function AutoDriveUpdateEvent:readStream(streamId, connection)
	--print("Received AutoDriveUpdateEvent");
	if AutoDrive == nil then
		return;
	end;
	
	local id = streamReadInt32(streamId);
	local vehicle = NetworkUtil.getObject(id);
	
	local isActive = streamReadBool(streamId);
	local isStopping = streamReadBool(streamId);
	local drivingForward = streamReadBool(streamId);
	local targetX = streamReadFloat32(streamId);
	local targetZ = streamReadFloat32(streamId);
	local initialized = streamReadBool(streamId);
	
	local wayPointsString = streamReadStringOrEmpty(streamId);
	local wayPointID =  StringUtil.splitString(",", wayPointsString);
	local wayPoints = {};
	for i,id in pairs(wayPointID) do
		if id ~= "" then
			wayPoints[i] = AutoDrive.mapWayPoints[tonumber(id)];
		end;
	end;

	local creationMode = streamReadBool(streamId);
	local creationModeDual = streamReadBool(streamId);
	local currentWayPoint = streamReadInt16(streamId);
	local targetSelected = streamReadInt16(streamId);
	local mapMarkerSelected = streamReadInt16(streamId);
	local nameOfSelectedTarget = streamReadStringOrEmpty(streamId);
		
	
	local mode = streamReadInt8(streamId);
	local targetSpeed = streamReadInt16(streamId);
	local createMapPoints = streamReadBool(streamId);
	local showClosestPoint = streamReadBool(streamId);
	local selectedDebugPoint = streamReadInt16(streamId);
	local showSelectedDebugPoint = streamReadBool(streamId);
	local changeSelectedDebugPoint = streamReadBool(streamId);

	local DebugPointsIteratedString = streamReadStringOrEmpty(streamId);	
	--print("Reading DebugPointsIteratedString: " .. DebugPointsIteratedString .. " in update event");
	local DebugPointsID = StringUtil.splitString(",", DebugPointsIteratedString);
	local iteratedDebugPoints = {};
	for i,id in pairs(DebugPointsID) do
		if id ~= "" then
			iteratedDebugPoints[i] = AutoDrive.mapWayPoints[tonumber(id)];
			--print("iteratedDebugPoints[" .. i .. "].id: " .. iteratedDebugPoints[i].id);
		end;
	end;
	
	local inDeadLock = streamReadBool(streamId);
	local timeTillDeadLock = streamReadFloat32(streamId);
	local inDeadLockRepairCounter = streamReadInt8(streamId);
		
	local name = streamReadStringOrEmpty(streamId);
	
	local moduleInitialized = streamReadBool(streamId);
	local currentInput = streamReadStringOrEmpty(streamId);
	local lastSpeed = streamReadFloat32(streamId);
	local speedOverride = streamReadFloat32(streamId);

	
	local isUnloading = streamReadBool(streamId);	
	local isPaused = streamReadBool(streamId);
	local unloadSwitch = streamReadBool(streamId);
	local isLoading = streamReadBool(streamId);
	local unloadFillTypeIndex = streamReadInt8(streamId);
	
	local targetSelected_Unload = streamReadInt16(streamId);
	local mapMarkerSelected_Unload = streamReadInt16(streamId);
	local nameOfSelectedTarget_Unload = streamReadStringOrEmpty(streamId);

	
	local nToolTipWait = streamReadFloat32(streamId);
	local nToolTipTimer = streamReadFloat32(streamId);
	local sToolTip = streamReadStringOrEmpty(streamId);
	
	local choosingDestination = streamReadBool(streamId);
	local chosenDestination = streamReadStringOrEmpty(streamId);
	local enteredChosenDestination = streamReadStringOrEmpty(streamId);

	local enableAI = streamReadInt8(streamId);
	local disableAI = streamReadInt8(streamId);
	
	local showingHud = streamReadBool(streamId);
	local showingMouse = streamReadBool(streamId);

	local AD_showingHud = streamReadBool(streamId);
	local AD_showingMouse = streamReadBool(streamId);
		
	if g_server ~= nil then
		vehicle.ad.currentInput = currentInput;
	else
		if vehicle == nil or vehicle.ad == nil then
			--print("Vehicle is nil in update message");
			return;
		end;
		vehicle.ad.isActive = isActive;
		vehicle.ad.isStopping = isStopping;
		vehicle.ad.drivingForward = drivingForward;
		vehicle.ad.targetX = targetX;
		vehicle.ad.targetZ = targetZ;
		vehicle.ad.initialized = initialized;
		vehicle.ad.wayPoints = wayPoints;
		vehicle.ad.creationMode = creationMode;
		vehicle.ad.creationModeDual = creationModeDual;
		vehicle.ad.currentWayPoint = currentWayPoint;
		vehicle.ad.targetSelected = targetSelected;	
		vehicle.ad.mapMarkerSelected = mapMarkerSelected;
		vehicle.ad.nameOfSelectedTarget = nameOfSelectedTarget;
			
		vehicle.ad.mode = mode;
		vehicle.ad.targetSpeed = targetSpeed;
		vehicle.ad.createMapPoints = createMapPoints;
		vehicle.ad.showClosestPoint = showClosestPoint;
		vehicle.ad.selectedDebugPoint = selectedDebugPoint;
		vehicle.ad.showSelectedDebugPoint = showSelectedDebugPoint;
		vehicle.ad.changeSelectedDebugPoint = changeSelectedDebugPoint;
		vehicle.ad.iteratedDebugPoints = iteratedDebugPoints;
		vehicle.ad.inDeadLock = inDeadLock;
		vehicle.ad.timeTillDeadLock = timeTillDeadLock;
		vehicle.ad.inDeadLockRepairCounter = inDeadLockRepairCounter;
					
		vehicle.ad.name = name;

		vehicle.ad.moduleInitialized = moduleInitialized;
		vehicle.ad.currentInput = currentInput;
		vehicle.ad.lastSpeed = lastSpeed;
		vehicle.ad.speedOverride = speedOverride;

		vehicle.ad.isUnloading = isUnloading;
		vehicle.ad.isPaused = isPaused;
		vehicle.ad.unloadSwitch = unloadSwitch;
		vehicle.ad.isLoading = isLoading;
		vehicle.ad.unloadFillTypeIndex = unloadFillTypeIndex;

		vehicle.ad.targetSelected_Unload = targetSelected_Unload;
		vehicle.ad.mapMarkerSelected_Unload = mapMarkerSelected_Unload;
		vehicle.ad.nameOfSelectedTarget_Unload = nameOfSelectedTarget_Unload;

		vehicle.ad.nToolTipWait = nToolTipWait;
		vehicle.ad.nToolTipTimer = nToolTipTimer;
		vehicle.ad.sToolTip = sToolTip;
		
		vehicle.ad.choosingDestination = choosingDestination;
		vehicle.ad.chosenDestination = chosenDestination;
		vehicle.ad.enteredChosenDestination = enteredChosenDestination;

		vehicle.ad.enableAI = enableAI;
		vehicle.ad.disableAI = disableAI;

		vehicle.ad.showingHud = showingHud;
		vehicle.ad.showingMouse = showingMouse;

		--AutoDrive.showHud = showHud;
		--AutoDrive.showMouse = showMouse;
	end;
		
	if g_server ~= nil then	
		g_server:broadcastEvent(AutoDriveUpdateEvent:new(vehicle), nil, nil, vehicle);
		-- print("broadcasting")
	end;
end;

function AutoDriveUpdateEvent:sendEvent(vehicle)
	if g_server ~= nil then	
		g_server:broadcastEvent(AutoDriveUpdateEvent:new(vehicle), nil, nil, vehicle);
		--print("broadcasting Update event")
	else
		g_client:getServerConnection():sendEvent(AutoDriveUpdateEvent:new(vehicle));
		--print("sending Update event to server...")
	end;
end;

function streamReadStringOrEmpty(streamID) 
	local string = streamReadString(streamID);
	if string == nil or string == "nil" then
		string = "";
	end;
	return string;
end;

function streamWriteStringOrEmpty(streamID, string) 	
	if string == nil or string == "" then
		string = "nil";
	end;
	streamWriteString(streamID, string);
end;