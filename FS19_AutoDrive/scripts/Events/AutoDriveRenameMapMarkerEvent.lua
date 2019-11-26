AutoDriveRenameMapMarkerEvent = {}
AutoDriveRenameMapMarkerEvent_mt = Class(AutoDriveRenameMapMarkerEvent, Event)

InitEventClass(AutoDriveRenameMapMarkerEvent, "AutoDriveRenameMapMarkerEvent")

function AutoDriveRenameMapMarkerEvent:emptyNew()
	local o = Event:new(AutoDriveRenameMapMarkerEvent_mt)
	o.className = "AutoDriveRenameMapMarkerEvent"
	return o
end

function AutoDriveRenameMapMarkerEvent:new(newName, markerId)
	local o = AutoDriveRenameMapMarkerEvent:emptyNew()
	o.newName = newName
	o.markerId = markerId
	return o
end

function AutoDriveRenameMapMarkerEvent:writeStream(streamId, connection)
	AutoDrive.streamWriteStringOrEmpty(streamId, self.newName)
	streamWriteUInt8(streamId, self.markerId)
end

function AutoDriveRenameMapMarkerEvent:readStream(streamId, connection)
	self.newName = AutoDrive.streamReadStringOrEmpty(streamId)
	self.markerId = streamReadUInt8(streamId)
	self:run(connection)
end

function AutoDriveRenameMapMarkerEvent:run(connection)
	if g_server ~= nil and connection:getIsServer() == false then
		-- If the event is coming from a client, server have only to broadcast
		AutoDriveRenameMapMarkerEvent.sendEvent(self.newName, self.markerId)
		--Dedicated server doesn't seem to receive the broadcasts, even when sent with local=true, so we have to do the action here as well
		if g_dedicatedServerInfo == nil then
			return
		end
	end

	-- If the event is coming from the server, both clients and server have to rename the marker
	AutoDrive.renameMapMarker(self.newName, self.markerId, false)
end

function AutoDriveRenameMapMarkerEvent.sendEvent(newName, markerId)
	local event = AutoDriveRenameMapMarkerEvent:new(newName, markerId)
	if g_server ~= nil then
		-- Server have to broadcast to all clients and himself
		g_server:broadcastEvent(event, true)
	else
		-- Client have to send to server
		g_client:getServerConnection():sendEvent(event)
	end
end
