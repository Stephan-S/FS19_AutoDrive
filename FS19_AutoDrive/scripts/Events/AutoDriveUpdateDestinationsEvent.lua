AutoDriveUpdateDestinationsEvent = {}
AutoDriveUpdateDestinationsEvent_mt = Class(AutoDriveUpdateDestinationsEvent, Event)

InitEventClass(AutoDriveUpdateDestinationsEvent, "AutoDriveUpdateDestinationsEvent")

function AutoDriveUpdateDestinationsEvent:emptyNew()
	local o = Event:new(AutoDriveUpdateDestinationsEvent_mt)
	o.className = "AutoDriveUpdateDestinationsEvent"
	return o
end

function AutoDriveUpdateDestinationsEvent:new(vehicle)
	local o = AutoDriveUpdateDestinationsEvent:emptyNew()

	o.vehicle = vehicle

	o.targetSelected = vehicle.ad.targetSelected
	o.mapMarkerSelected = vehicle.ad.mapMarkerSelected
	o.nameOfSelectedTarget = vehicle.ad.nameOfSelectedTarget

	o.targetSelected_Unload = vehicle.ad.targetSelected_Unload
	o.mapMarkerSelected_Unload = vehicle.ad.mapMarkerSelected_Unload
	o.nameOfSelectedTarget_Unload = vehicle.ad.nameOfSelectedTarget_Unload

	o.unloadFillTypeIndex = vehicle.ad.unloadFillTypeIndex

	return o
end

function AutoDriveUpdateDestinationsEvent:writeStream(streamId, connection)
	if AutoDrive == nil then
		return
	end
	streamWriteInt32(streamId, NetworkUtil.getObjectId(self.vehicle))

	streamWriteInt16(streamId, self.targetSelected)
	streamWriteInt16(streamId, self.mapMarkerSelected)
	AutoDrive.streamWriteStringOrEmpty(streamId, self.nameOfSelectedTarget)

	streamWriteInt16(streamId, self.targetSelected_Unload)
	streamWriteInt16(streamId, self.mapMarkerSelected_Unload)
	AutoDrive.streamWriteStringOrEmpty(streamId, self.nameOfSelectedTarget_Unload)

	streamWriteUInt16(streamId, self.unloadFillTypeIndex)
end

function AutoDriveUpdateDestinationsEvent:readStream(streamId, connection)
	if AutoDrive == nil then
		return
	end

	local id = streamReadInt32(streamId)
	local vehicle = NetworkUtil.getObject(id)

	local targetSelected = streamReadInt16(streamId)
	local mapMarkerSelected = streamReadInt16(streamId)
	local nameOfSelectedTarget = AutoDrive.streamReadStringOrEmpty(streamId)

	local targetSelected_Unload = streamReadInt16(streamId)
	local mapMarkerSelected_Unload = streamReadInt16(streamId)
	local nameOfSelectedTarget_Unload = AutoDrive.streamReadStringOrEmpty(streamId)

	local unloadFillTypeIndex = streamReadUInt16(streamId)

	vehicle.ad.targetSelected = targetSelected
	vehicle.ad.mapMarkerSelected = mapMarkerSelected
	vehicle.ad.nameOfSelectedTarget = nameOfSelectedTarget

	vehicle.ad.targetSelected_Unload = targetSelected_Unload
	vehicle.ad.mapMarkerSelected_Unload = mapMarkerSelected_Unload
	vehicle.ad.nameOfSelectedTarget_Unload = nameOfSelectedTarget_Unload

	vehicle.ad.unloadFillTypeIndex = unloadFillTypeIndex

	if g_server ~= nil then
		g_server:broadcastEvent(AutoDriveUpdateDestinationsEvent:new(vehicle), nil, nil, vehicle)
	end
end

function AutoDriveUpdateDestinationsEvent:sendEvent(vehicle)
	if g_server ~= nil then
		g_server:broadcastEvent(AutoDriveUpdateDestinationsEvent:new(vehicle), nil, nil, vehicle)
	else
		g_client:getServerConnection():sendEvent(AutoDriveUpdateDestinationsEvent:new(vehicle))
	end
end
