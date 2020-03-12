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

	o.moduleInitialized = vehicle.ad.moduleInitialized
	o.currentInput = vehicle.ad.currentInput
	
	--ToDo: Do we still need that with the current mp sync process? It was a crude workaround before
	o.enableAI = vehicle.ad.enableAI
	o.disableAI = vehicle.ad.disableAI

	return o
end

function AutoDriveUpdateEvent:writeStream(streamId, connection)
	if AutoDrive == nil then
		return
	end
	streamWriteInt32(streamId, NetworkUtil.getObjectId(self.vehicle))

	streamWriteBool(streamId, self.moduleInitialized)
	AutoDrive.streamWriteStringOrEmpty(streamId, self.currentInput)

	streamWriteInt8(streamId, self.enableAI)
	streamWriteInt8(streamId, self.disableAI)
end

function AutoDriveUpdateEvent:readStream(streamId, connection)
	if AutoDrive == nil then
		return
	end

	local id = streamReadInt32(streamId)
	local vehicle = NetworkUtil.getObject(id)

	local moduleInitialized = streamReadBool(streamId)
	local currentInput = AutoDrive.streamReadStringOrEmpty(streamId)

	local enableAI = streamReadInt8(streamId)
	local disableAI = streamReadInt8(streamId)

	if g_server ~= nil then
		vehicle.ad.currentInput = currentInput
	else
		if vehicle == nil or vehicle.ad == nil then
			return
		end
		vehicle.ad.moduleInitialized = moduleInitialized
		vehicle.ad.currentInput = currentInput

		vehicle.ad.enableAI = enableAI
		vehicle.ad.disableAI = disableAI
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
	remained = remained and self.moduleInitialized == oldEvent.moduleInitialized
	if self.moduleInitialized ~= oldEvent.moduleInitialized then
		reason = reason .. " moduleInitialized"
	end
	remained = remained and self.currentInput == oldEvent.currentInput
	if self.currentInput ~= oldEvent.currentInput then
		reason = reason .. " currentInput"
	end
	remained = remained and self.enableAI == oldEvent.enableAI
	if self.enableAI ~= oldEvent.enableAI then
		reason = reason .. " enableAI"
	end
	remained = remained and self.disableAI == oldEvent.disableAI
	if self.disableAI ~= oldEvent.disableAI then
		reason = reason .. " disableAI"
	end

	if reason ~= "" then
		--g_logManager:info("Vehicle " .. self.vehicle.ad.driverName .. " sends update. Reason: " .. reason)
		self.reason = reason
	end

	return remained
end
