AutoDriveCreateMapMarkerEvent = {}
AutoDriveCreateMapMarkerEvent_mt = Class(AutoDriveCreateMapMarkerEvent, Event)

InitEventClass(AutoDriveCreateMapMarkerEvent, "AutoDriveCreateMapMarkerEvent")

function AutoDriveCreateMapMarkerEvent:emptyNew()
	local self = Event:new(AutoDriveCreateMapMarkerEvent_mt)
	self.className = "AutoDriveCreateMapMarkerEvent"
	return self
end

function AutoDriveCreateMapMarkerEvent:new(vehicle, markerName)
	local self = AutoDriveCreateMapMarkerEvent:emptyNew()
	self.vehicle = vehicle
	self.markerName = markerName
	return self
end

function AutoDriveCreateMapMarkerEvent:writeStream(streamId, connection)
	streamWriteInt32(streamId, NetworkUtil.getObjectId(self.vehicle))
	streamWriteStringOrEmpty(streamId, self.markerName)
end

function AutoDriveCreateMapMarkerEvent:readStream(streamId, connection)
	local vehicleId = streamReadInt32(streamId)
	self.vehicle = NetworkUtil.getObject(vehicleId)
	self.markerName = streamReadString(streamId)
	self:run(connection)
end

function AutoDriveCreateMapMarkerEvent:run(connection)
	if g_server ~= nil and connection:getIsServer() == false then
		-- If the event is coming from a client, server have only to broadcast
		AutoDriveCreateMapMarkerEvent.sendEvent(self.vehicle, self.markerName)
	else
		-- If the event is coming from the server, both clients and server have to rename the marker
		AutoDrive.createMapMarker(self.vehicle, self.markerName, false)
	end
end

function AutoDriveCreateMapMarkerEvent.sendEvent(vehicle, markerName)
	local event = AutoDriveCreateMapMarkerEvent:new(vehicle, markerName)
	if g_server ~= nil then
		-- Server have to broadcast to all clients and himself
		g_server:broadcastEvent(event, true)
	else
		-- Client have to send to server
		g_client:getServerConnection():sendEvent(event)
	end
end
