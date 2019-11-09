AutoDriveRenameMapMarkerEvent = {}
AutoDriveRenameMapMarkerEvent_mt = Class(AutoDriveRenameMapMarkerEvent, Event)

InitEventClass(AutoDriveRenameMapMarkerEvent, "AutoDriveRenameMapMarkerEvent")

function AutoDriveRenameMapMarkerEvent:emptyNew()
	local self = Event:new(AutoDriveRenameMapMarkerEvent_mt)
	self.className = "AutoDriveRenameMapMarkerEvent"
	return self
end

function AutoDriveRenameMapMarkerEvent:new(newName, markerId)
	local self = AutoDriveRenameMapMarkerEvent:emptyNew()
	self.newName = newName
	self.markerId = markerId
	return self
end

function AutoDriveRenameMapMarkerEvent:writeStream(streamId, connection)
	streamWriteStringOrEmpty(streamId, self.newName)
	streamWriteUInt8(streamId, self.markerId)
end

function AutoDriveRenameMapMarkerEvent:readStream(streamId, connection)
	self.newName = streamReadStringOrEmpty(streamId)
	self.markerId = streamReadUInt8(streamId)
	self:run(connection)
end

function AutoDriveRenameMapMarkerEvent:run(connection)
	if g_server ~= nil and connection:getIsServer() == false then
		-- If the event is coming from a client, server have only to broadcast
		AutoDriveRenameMapMarkerEvent.sendEvent(self.newName, self.markerId)
	else
		-- If the event is coming from the server, both clients and server have to rename the marker
		AutoDrive.renameMapMarker(self.newName, self.markerId, false)
	end
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
