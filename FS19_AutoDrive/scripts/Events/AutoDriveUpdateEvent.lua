AutoDriveUpdateEvent = {}
AutoDriveUpdateEvent_mt = Class(AutoDriveUpdateEvent, Event)

InitEventClass(AutoDriveUpdateEvent, "AutoDriveUpdateEvent")

function AutoDriveUpdateEvent:emptyNew()
	local o = Event:new(AutoDriveUpdateEvent_mt)
	o.className = "AutoDriveUpdateEvent"
	return o
end

function AutoDriveUpdateEvent:new(vehicle)
	if AutoDrive == nil then
		return
	end
	local o = AutoDriveUpdateEvent:emptyNew()
	o.vehicle = vehicle

	o.isActive = vehicle.ad.isActive
	o.isStopping = vehicle.ad.isStopping
	o.drivingForward = vehicle.ad.drivingForward
	o.initialized = vehicle.ad.initialized
	o.wayPoints = vehicle.ad.wayPoints
	o.wayPointsChanged = vehicle.ad.wayPointsChanged
	o.creationMode = vehicle.ad.creationMode
	o.creationModeDual = vehicle.ad.creationModeDual
	o.currentWayPoint = vehicle.ad.currentWayPoint
	o.targetSelected = vehicle.ad.targetSelected
	o.mapMarkerSelected = vehicle.ad.mapMarkerSelected
	o.nameOfSelectedTarget = vehicle.ad.nameOfSelectedTarget

	o.mode = vehicle.ad.mode
	o.targetSpeed = vehicle.ad.targetSpeed
	o.createMapPoints = vehicle.ad.createMapPoints
	o.showClosestPoint = vehicle.ad.showClosestPoint
	o.selectedDebugPoint = vehicle.ad.selectedDebugPoint
	o.showSelectedDebugPoint = vehicle.ad.showSelectedDebugPoint
	o.changeSelectedDebugPoint = vehicle.ad.changeSelectedDebugPoint
	o.iteratedDebugPoints = vehicle.ad.iteratedDebugPoints
	o.inDeadLock = vehicle.ad.inDeadLock
	o.timeTillDeadLock = vehicle.ad.timeTillDeadLock
	o.inDeadLockRepairCounter = vehicle.ad.inDeadLockRepairCounter

	o.name = vehicle.ad.driverName

	o.moduleInitialized = vehicle.ad.moduleInitialized
	o.currentInput = vehicle.ad.currentInput

	o.isUnloading = vehicle.ad.isUnloading
	o.isPaused = vehicle.ad.isPaused
	o.onRouteToSecondTarget = vehicle.ad.onRouteToSecondTarget
	o.isLoading = vehicle.ad.isLoading
	o.unloadFillTypeIndex = vehicle.ad.unloadFillTypeIndex
	o.startedLoadingAtTrigger = vehicle.ad.startedLoadingAtTrigger
	o.combineState = vehicle.ad.combineState

	o.targetSelected_Unload = vehicle.ad.targetSelected_Unload
	o.mapMarkerSelected_Unload = vehicle.ad.mapMarkerSelected_Unload
	o.nameOfSelectedTarget_Unload = vehicle.ad.nameOfSelectedTarget_Unload

	o.onRouteToPark = vehicle.ad.onRouteToPark

	o.enableAI = vehicle.ad.enableAI
	o.disableAI = vehicle.ad.disableAI

	o.mapWayPointsCounter = AutoDrive.mapWayPointsCounter;

	return o
end

function AutoDriveUpdateEvent:writeStream(streamId, connection)
	if AutoDrive == nil then
		return
	end
	streamWriteInt32(streamId, NetworkUtil.getObjectId(self.vehicle))

	if self.reason == "currentWayPoint" then
		streamWriteInt8(streamId, 1)
		streamWriteInt16(streamId, self.currentWayPoint)
		return
	end

	streamWriteInt8(streamId, 0)

	streamWriteBool(streamId, self.isActive)
	streamWriteBool(streamId, self.isStopping)
	streamWriteBool(streamId, self.drivingForward)
	streamWriteBool(streamId, self.initialized)

	streamWriteBool(streamId, self.wayPointsChanged)

	if self.wayPointsChanged then
		self.wayPointsString = ""
		for _, point in pairs(self.wayPoints) do
			if self.wayPointsString == "" then
				self.wayPointsString = self.wayPointsString .. point.id
			else
				self.wayPointsString = self.wayPointsString .. "," .. point.id
			end
		end
		AutoDrive.streamWriteStringOrEmpty(streamId, self.wayPointsString)
		self.vehicle.ad.wayPointsChanged = false
	end

	streamWriteBool(streamId, self.creationMode)
	streamWriteBool(streamId, self.creationModeDual)
	AutoDrive.streamWriteInt16Or1337(streamId, self.currentWayPoint)
	AutoDrive.streamWriteInt16Or1337(streamId, self.targetSelected)
	AutoDrive.streamWriteInt16Or1337(streamId, self.mapMarkerSelected)
	AutoDrive.streamWriteStringOrEmpty(streamId, self.nameOfSelectedTarget)

	streamWriteInt8(streamId, self.mode)
	streamWriteUInt8(streamId, self.targetSpeed)
	streamWriteBool(streamId, self.createMapPoints)
	streamWriteBool(streamId, self.showClosestPoint)
	streamWriteInt32(streamId, self.selectedDebugPoint)
	streamWriteBool(streamId, self.showSelectedDebugPoint)
	streamWriteBool(streamId, self.changeSelectedDebugPoint)

	self.debugPointsIteratedString = ""
	for _, point in pairs(self.iteratedDebugPoints) do
		if self.debugPointsIteratedString == "" then
			self.debugPointsIteratedString = self.debugPointsIteratedString .. point.id
		else
			self.debugPointsIteratedString = self.debugPointsIteratedString .. "," .. point.id
		end
	end
	AutoDrive.streamWriteStringOrEmpty(streamId, self.debugPointsIteratedString)

	streamWriteBool(streamId, self.inDeadLock)
	streamWriteFloat32(streamId, self.timeTillDeadLock)
	streamWriteInt8(streamId, self.inDeadLockRepairCounter)

	AutoDrive.streamWriteStringOrEmpty(streamId, self.name)

	streamWriteBool(streamId, self.moduleInitialized)
	AutoDrive.streamWriteStringOrEmpty(streamId, self.currentInput)

	streamWriteBool(streamId, self.isUnloading)
	streamWriteBool(streamId, self.isPaused)
	streamWriteBool(streamId, self.onRouteToSecondTarget)
	streamWriteBool(streamId, self.isLoading)
	streamWriteUInt16(streamId, self.unloadFillTypeIndex)
	streamWriteBool(streamId, self.startedLoadingAtTrigger)
	streamWriteInt8(streamId, self.combineState)

	AutoDrive.streamWriteInt16Or1337(streamId, self.targetSelected_Unload)
	AutoDrive.streamWriteInt16Or1337(streamId, self.mapMarkerSelected_Unload)
	AutoDrive.streamWriteStringOrEmpty(streamId, self.nameOfSelectedTarget_Unload)

	streamWriteBool(streamId, self.onRouteToPark)

	streamWriteInt8(streamId, self.enableAI)
	streamWriteInt8(streamId, self.disableAI)

	streamWriteInt32(streamId, self.mapWayPointsCounter)

	AutoDrive.streamWriteStringOrEmpty(streamId, AutoDrive.print.currentMessage)
	AutoDrive.streamWriteInt32OrEmpty(streamId, NetworkUtil.getObjectId(AutoDrive.print.referencedVehicle))
	--g_logManager:devInfo("event writeStream")
end

function AutoDriveUpdateEvent:readStream(streamId, connection)
	if AutoDrive == nil then
		return
	end

	local id = streamReadInt32(streamId)
	local vehicle = NetworkUtil.getObject(id)

	local updateMode = streamReadInt8(streamId)
	if updateMode == 1 then
		local currentWayPoint = streamReadInt16(streamId)
		if vehicle == nil or vehicle.ad == nil then
			return
		end
		vehicle.ad.currentWayPoint = currentWayPoint
		return
	end

	local isActive = streamReadBool(streamId)
	local isStopping = streamReadBool(streamId)
	local drivingForward = streamReadBool(streamId)
	local initialized = streamReadBool(streamId)

	local wayPointsChanged = streamReadBool(streamId)

	local wayPoints = {}
	if wayPointsChanged == true then
		local wayPointsString = AutoDrive.streamReadStringOrEmpty(streamId)
		local wayPointID = StringUtil.splitString(",", wayPointsString)
		for i, wpId in pairs(wayPointID) do
			if wpId ~= "" then
				wayPoints[i] = AutoDrive.mapWayPoints[tonumber(id)]
			end
		end
	end

	local creationMode = streamReadBool(streamId)
	local creationModeDual = streamReadBool(streamId)
	local currentWayPoint = AutoDrive.streamReadInt16Or1337(streamId)
	local targetSelected = AutoDrive.streamReadInt16Or1337(streamId)
	local mapMarkerSelected = AutoDrive.streamReadInt16Or1337(streamId)
	local nameOfSelectedTarget = AutoDrive.streamReadStringOrEmpty(streamId)

	local mode = streamReadInt8(streamId)
	local targetSpeed = streamReadUInt8(streamId)
	local createMapPoints = streamReadBool(streamId)
	local showClosestPoint = streamReadBool(streamId)
	local selectedDebugPoint = streamReadInt32(streamId)
	local showSelectedDebugPoint = streamReadBool(streamId)
	local changeSelectedDebugPoint = streamReadBool(streamId)

	local DebugPointsIteratedString = AutoDrive.streamReadStringOrEmpty(streamId)
	local DebugPointsID = StringUtil.splitString(",", DebugPointsIteratedString)
	local iteratedDebugPoints = {}
	for i, pId in pairs(DebugPointsID) do
		if pId ~= "" then
			iteratedDebugPoints[i] = AutoDrive.mapWayPoints[tonumber(pId)]
		end
	end

	local inDeadLock = streamReadBool(streamId)
	local timeTillDeadLock = streamReadFloat32(streamId)
	local inDeadLockRepairCounter = streamReadInt8(streamId)

	local name = AutoDrive.streamReadStringOrEmpty(streamId)

	local moduleInitialized = streamReadBool(streamId)
	local currentInput = AutoDrive.streamReadStringOrEmpty(streamId)

	local isUnloading = streamReadBool(streamId)
	local isPaused = streamReadBool(streamId)
	local onRouteToSecondTarget = streamReadBool(streamId)
	local isLoading = streamReadBool(streamId)
	local unloadFillTypeIndex = streamReadUInt16(streamId)
	local startedLoadingAtTrigger = streamReadBool(streamId)
	local combineState = streamReadInt8(streamId)

	local targetSelected_Unload = AutoDrive.streamReadInt16Or1337(streamId)
	local mapMarkerSelected_Unload = AutoDrive.streamReadInt16Or1337(streamId)
	local nameOfSelectedTarget_Unload = AutoDrive.streamReadStringOrEmpty(streamId)

	local onRouteToPark = streamReadBool(streamId)

	local enableAI = streamReadInt8(streamId)
	local disableAI = streamReadInt8(streamId)

	local mapWayPointsCounter = streamReadInt32(streamId)

	local AD_currentMessage = AutoDrive.streamReadStringOrEmpty(streamId)

	if g_server ~= nil then
		vehicle.ad.currentInput = currentInput
	else
		if vehicle == nil or vehicle.ad == nil then
			--g_logManager:devInfo("Vehicle is nil in update message");
			return
		end
		vehicle.ad.isActive = isActive
		vehicle.ad.isStopping = isStopping
		vehicle.ad.drivingForward = drivingForward
		vehicle.ad.initialized = initialized
		vehicle.ad.wayPointsChanged = wayPointsChanged
		if wayPointsChanged == true then
			vehicle.ad.wayPoints = wayPoints
		end
		vehicle.ad.creationMode = creationMode
		vehicle.ad.creationModeDual = creationModeDual
		if currentWayPoint ~= 1337 then
			vehicle.ad.currentWayPoint = currentWayPoint
		end
		if targetSelected ~= 1337 then
			vehicle.ad.targetSelected = targetSelected
		end
		if mapMarkerSelected ~= 1337 then
			vehicle.ad.mapMarkerSelected = mapMarkerSelected
		end
		vehicle.ad.nameOfSelectedTarget = nameOfSelectedTarget

		vehicle.ad.mode = mode
		vehicle.ad.targetSpeed = targetSpeed
		vehicle.ad.createMapPoints = createMapPoints
		vehicle.ad.showClosestPoint = showClosestPoint
		if selectedDebugPoint ~= 1337 then
			vehicle.ad.selectedDebugPoint = selectedDebugPoint
		end
		vehicle.ad.showSelectedDebugPoint = showSelectedDebugPoint
		vehicle.ad.changeSelectedDebugPoint = changeSelectedDebugPoint
		vehicle.ad.iteratedDebugPoints = iteratedDebugPoints
		vehicle.ad.inDeadLock = inDeadLock
		vehicle.ad.timeTillDeadLock = timeTillDeadLock
		vehicle.ad.inDeadLockRepairCounter = inDeadLockRepairCounter

		vehicle.ad.driverName = name

		vehicle.ad.moduleInitialized = moduleInitialized
		vehicle.ad.currentInput = currentInput

		vehicle.ad.isUnloading = isUnloading
		vehicle.ad.isPaused = isPaused
		vehicle.ad.onRouteToSecondTarget = onRouteToSecondTarget
		vehicle.ad.isLoading = isLoading
		vehicle.ad.unloadFillTypeIndex = unloadFillTypeIndex
		vehicle.ad.startedLoadingAtTrigger = startedLoadingAtTrigger
		vehicle.ad.combineState = combineState

		if targetSelected_Unload ~= 1337 then
			vehicle.ad.targetSelected_Unload = targetSelected_Unload
		end
		if mapMarkerSelected_Unload ~= 1337 then
			vehicle.ad.mapMarkerSelected_Unload = mapMarkerSelected_Unload
		end
		vehicle.ad.nameOfSelectedTarget_Unload = nameOfSelectedTarget_Unload

		vehicle.ad.onRouteToPark = onRouteToPark

		vehicle.ad.enableAI = enableAI
		vehicle.ad.disableAI = disableAI

		AutoDrive.mapWayPointsCounter = mapWayPointsCounter;

		AutoDrive.print.currentMessage = AD_currentMessage
		local refVehicleInt = streamReadInt32(streamId)
		if refVehicleInt ~= 0 then
			local referencedVehicle = NetworkUtil.getObject(id)
			if referencedVehicle ~= nil then
				AutoDrive.print.referencedVehicle = referencedVehicle
			end
		end
	end

	if g_server ~= nil then
		g_server:broadcastEvent(AutoDriveUpdateEvent:new(vehicle), nil, nil, vehicle)
	end
end

function AutoDriveUpdateEvent:sendEvent(vehicle)
	if g_server ~= nil then
		g_server:broadcastEvent(AutoDriveUpdateEvent:new(vehicle), nil, nil, vehicle)
	else
		g_client:getServerConnection():sendEvent(AutoDriveUpdateEvent:new(vehicle))
	end
end

function AutoDriveUpdateEvent:compareTo(oldEvent)
	local remained = true
	local reason = ""
	remained = remained and self.vehicle == oldEvent.vehicle
	if self.vehicle ~= oldEvent.vehicle then
		reason = reason .. " vehicle"
	end
	remained = remained and self.isActive == oldEvent.isActive
	if self.isActive ~= oldEvent.isActive then
		reason = reason .. " isActive"
	end
	remained = remained and self.isStopping == oldEvent.isStopping
	if self.isStopping ~= oldEvent.isStopping then
		reason = reason .. " isStopping"
	end
	remained = remained and self.drivingForward == oldEvent.drivingForward
	if self.drivingForward ~= oldEvent.drivingForward then
		reason = reason .. " drivingForward"
	end
	remained = remained and self.initialized == oldEvent.initialized
	if self.initialized ~= oldEvent.initialized then
		reason = reason .. " initialized"
	end
	remained = remained and self.wayPointsChanged == oldEvent.wayPointsChanged
	if self.wayPointsChanged ~= oldEvent.wayPointsChanged then
		reason = reason .. " wayPointsChanged"
	end
	remained = remained and self.creationMode == oldEvent.creationMode
	if self.creationMode ~= oldEvent.creationMode then
		reason = reason .. " creationMode"
	end
	remained = remained and self.creationModeDual == oldEvent.creationModeDual
	if self.creationModeDual ~= oldEvent.creationModeDual then
		reason = reason .. " creationModeDual"
	end
	remained = remained and self.currentWayPoint == oldEvent.currentWayPoint
	if self.currentWayPoint ~= oldEvent.currentWayPoint then
		reason = reason .. " currentWayPoint"
	end
	remained = remained and self.targetSelected == oldEvent.targetSelected
	if self.targetSelected ~= oldEvent.targetSelected then
		reason = reason .. " targetSelected"
	end
	remained = remained and self.mapMarkerSelected == oldEvent.mapMarkerSelected
	if self.mapMarkerSelected ~= oldEvent.mapMarkerSelected then
		reason = reason .. " mapMarkerSelected"
	end
	remained = remained and self.nameOfSelectedTarget == oldEvent.nameOfSelectedTarget
	if self.nameOfSelectedTarget ~= oldEvent.nameOfSelectedTarget then
		reason = reason .. " nameOfSelectedTarget"
	end
	remained = remained and self.mode == oldEvent.mode
	if self.mode ~= oldEvent.mode then
		reason = reason .. " mode"
	end
	remained = remained and self.targetSpeed == oldEvent.targetSpeed
	if self.targetSpeed ~= oldEvent.targetSpeed then
		reason = reason .. " targetSpeed"
	end
	remained = remained and self.createMapPoints == oldEvent.createMapPoints
	if self.createMapPoints ~= oldEvent.createMapPoints then
		reason = reason .. " createMapPoints"
	end
	remained = remained and self.showClosestPoint == oldEvent.showClosestPoint
	if self.showClosestPoint ~= oldEvent.showClosestPoint then
		reason = reason .. " showClosestPoint"
	end
	remained = remained and self.selectedDebugPoint == oldEvent.selectedDebugPoint
	if self.selectedDebugPoint ~= oldEvent.selectedDebugPoint then
		reason = reason .. " selectedDebugPoint"
	end
	remained = remained and self.showSelectedDebugPoint == oldEvent.showSelectedDebugPoint
	if self.showSelectedDebugPoint ~= oldEvent.showSelectedDebugPoint then
		reason = reason .. " showSelectedDebugPoint"
	end
	remained = remained and self.changeSelectedDebugPoint == oldEvent.changeSelectedDebugPoint
	if self.changeSelectedDebugPoint ~= oldEvent.changeSelectedDebugPoint then
		reason = reason .. " changeSelectedDebugPoint"
	end
	remained = remained and self.iteratedDebugPoints == oldEvent.iteratedDebugPoints
	if self.iteratedDebugPoints ~= oldEvent.iteratedDebugPoints then
		reason = reason .. " iteratedDebugPoints"
	end
	remained = remained and self.inDeadLock == oldEvent.inDeadLock
	if self.inDeadLock ~= oldEvent.inDeadLock then
		reason = reason .. " inDeadLock"
	end
	remained = remained and self.inDeadLockRepairCounter == oldEvent.inDeadLockRepairCounter
	if self.inDeadLockRepairCounter ~= oldEvent.inDeadLockRepairCounter then
		reason = reason .. " inDeadLockRepairCounter"
	end
	remained = remained and self.name == oldEvent.name
	if self.name ~= oldEvent.name then
		reason = reason .. " name"
	end
	remained = remained and self.moduleInitialized == oldEvent.moduleInitialized
	if self.moduleInitialized ~= oldEvent.moduleInitialized then
		reason = reason .. " moduleInitialized"
	end
	remained = remained and self.currentInput == oldEvent.currentInput
	if self.currentInput ~= oldEvent.currentInput then
		reason = reason .. " currentInput"
	end
	remained = remained and self.isUnloading == oldEvent.isUnloading
	if self.isUnloading ~= oldEvent.isUnloading then
		reason = reason .. " isUnloading"
	end
	remained = remained and self.isPaused == oldEvent.isPaused
	if self.isPaused ~= oldEvent.isPaused then
		reason = reason .. " isPaused"
	end
	remained = remained and self.onRouteToSecondTarget == oldEvent.onRouteToSecondTarget
	if self.onRouteToSecondTarget ~= oldEvent.onRouteToSecondTarget then
		reason = reason .. " onRouteToSecondTarget"
	end
	remained = remained and self.isLoading == oldEvent.isLoading
	if self.isLoading ~= oldEvent.isLoading then
		reason = reason .. " isLoading"
	end
	remained = remained and self.unloadFillTypeIndex == oldEvent.unloadFillTypeIndex
	if self.unloadFillTypeIndex ~= oldEvent.unloadFillTypeIndex then
		reason = reason .. " unloadFillTypeIndex"
	end
	remained = remained and self.targetSelected_Unload == oldEvent.targetSelected_Unload
	if self.targetSelected_Unload ~= oldEvent.targetSelected_Unload then
		reason = reason .. " targetSelected_Unload"
	end
	remained = remained and self.mapMarkerSelected_Unload == oldEvent.mapMarkerSelected_Unload
	if self.mapMarkerSelected_Unload ~= oldEvent.mapMarkerSelected_Unload then
		reason = reason .. " mapMarkerSelected_Unload"
	end
	remained = remained and self.nameOfSelectedTarget_Unload == oldEvent.nameOfSelectedTarget_Unload
	if self.nameOfSelectedTarget_Unload ~= oldEvent.nameOfSelectedTarget_Unload then
		reason = reason .. " nameOfSelectedTarget_Unload"
	end
	remained = remained and self.enableAI == oldEvent.enableAI
	if self.enableAI ~= oldEvent.enableAI then
		reason = reason .. " enableAI"
	end
	remained = remained and self.disableAI == oldEvent.disableAI
	if self.disableAI ~= oldEvent.disableAI then
		reason = reason .. " disableAI"
	end
	remained = remained and self.startedLoadingAtTrigger == oldEvent.startedLoadingAtTrigger
	if self.startedLoadingAtTrigger ~= oldEvent.startedLoadingAtTrigger then
		reason = reason .. " startedLoadingAtTrigger"
	end
	remained = remained and self.combineState == oldEvent.combineState
	if self.combineState ~= oldEvent.combineState then
		reason = reason .. " combineState"
	end
	remained = remained and self.onRouteToPark == oldEvent.onRouteToPark
	if self.onRouteToPark ~= oldEvent.onRouteToPark then
		reason = reason .. " onRouteToPark"
	end
	remained = remained and self.mapWayPointsCounter == oldEvent.mapWayPointsCounter
	if self.mapWayPointsCounter ~= oldEvent.mapWayPointsCounter then
		reason = reason .. " mapWayPointsCounter"
	end

	if reason ~= "" then
		--g_logManager:devInfo("Vehicle " .. self.vehicle.ad.driverName .. " sends update. Reason: " .. reason);
		self.reason = reason
	end

	return remained
end
