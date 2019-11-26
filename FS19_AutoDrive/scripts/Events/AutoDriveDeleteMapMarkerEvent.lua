AutoDriveDeleteMapMarkerEvent = {}
AutoDriveDeleteMapMarkerEvent_mt = Class(AutoDriveDeleteMapMarkerEvent, Event)

InitEventClass(AutoDriveDeleteMapMarkerEvent, "AutoDriveDeleteMapMarkerEvent")

function AutoDriveDeleteMapMarkerEvent:emptyNew()
	local o = Event:new(AutoDriveDeleteMapMarkerEvent_mt)
	o.className = "AutoDriveDeleteMapMarkerEvent"
	return o
end

function AutoDriveDeleteMapMarkerEvent:new(markerId)
	local o = AutoDriveDeleteMapMarkerEvent:emptyNew()
	o.markerId = markerId
	return o
end

function AutoDriveDeleteMapMarkerEvent:writeStream(streamId, connection)
	streamWriteUInt8(streamId, self.markerId)
end

function AutoDriveDeleteMapMarkerEvent:readStream(streamId, connection)
	self.markerId = streamReadUInt8(streamId)
	self:run(connection)
end

function AutoDriveDeleteMapMarkerEvent:run(connection)
	if g_server ~= nil and connection:getIsServer() == false then
		-- If the event is coming from a client, server have only to broadcast
		AutoDriveDeleteMapMarkerEvent.sendEvent(self.markerId)
		--Dedicated server doesn't seem to receive the broadcasts, even when sent with local=true, so we have to do the action here as well
		if g_dedicatedServerInfo == nil then
			return
		end
	end

	AutoDrive.removeMapMarker(self.markerId, false)
end

function AutoDriveDeleteMapMarkerEvent.sendEvent(markerId)
	local event = AutoDriveDeleteMapMarkerEvent:new(markerId)
	if g_server ~= nil then
		-- Server have to broadcast to all clients and himself
		g_server:broadcastEvent(event, true)
	else
		-- Client have to send to server
		g_client:getServerConnection():sendEvent(event)
	end
end
