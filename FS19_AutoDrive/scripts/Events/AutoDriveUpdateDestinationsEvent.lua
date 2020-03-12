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

	o.firstMarker = vehicle.ad.stateModule:getFirstMarkerId()
	o.secondMarker = vehicle.ad.stateModule:getSecondMarkerId()

	o.unloadFillTypeIndex = vehicle.ad.stateModule:getFillType()

	return o
end

function AutoDriveUpdateDestinationsEvent:writeStream(streamId, connection)
	if AutoDrive == nil then
		return
	end
	streamWriteInt32(streamId, NetworkUtil.getObjectId(self.vehicle))

	streamWriteInt16(streamId, self.firstMarker)
	streamWriteInt16(streamId, self.secondMarker)

	streamWriteUInt16(streamId, self.unloadFillTypeIndex)
end

function AutoDriveUpdateDestinationsEvent:readStream(streamId, connection)
	if AutoDrive == nil then
		return
	end

	local id = streamReadInt32(streamId)
	local vehicle = NetworkUtil.getObject(id)

	local firstMarker = streamReadInt16(streamId)
	local secondMarker = streamReadInt16(streamId)

	local unloadFillTypeIndex = streamReadUInt16(streamId)

	vehicle.ad.stateModule:setFirstMarker(firstMarker)
	vehicle.ad.stateModule:setSecondMarker(secondMarker)

	vehicle.ad.stateModule:setFillType(unloadFillTypeIndex)

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
