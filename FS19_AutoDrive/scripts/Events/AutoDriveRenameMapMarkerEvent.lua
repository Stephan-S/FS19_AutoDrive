AutoDriveRenameMapMarkerEvent = {}
AutoDriveRenameMapMarkerEvent_mt = Class(AutoDriveRenameMapMarkerEvent, Event)

InitEventClass(AutoDriveRenameMapMarkerEvent, "AutoDriveRenameMapMarkerEvent")

function AutoDriveRenameMapMarkerEvent:emptyNew()
	local self = Event:new(AutoDriveRenameMapMarkerEvent_mt)
	self.className = "AutoDriveRenameMapMarkerEvent"
	return self
end

function AutoDriveRenameMapMarkerEvent:new(newName, oldName, markerID)
	local self = AutoDriveRenameMapMarkerEvent:emptyNew()
	self.newName = newName
	self.oldName = oldName
	self.markerID = markerID
	return self
end

function AutoDriveRenameMapMarkerEvent:writeStream(streamId, connection)
	streamWriteStringOrEmpty(streamId, self.newName)
	streamWriteStringOrEmpty(streamId, self.oldName)
	streamWriteUInt8(streamId, self.markerID)
end

function AutoDriveRenameMapMarkerEvent:readStream(streamId, connection)
	local newName = streamReadStringOrEmpty(streamId)
	local oldName = streamReadStringOrEmpty(streamId)
	local markerID = streamReadUInt8(streamId)
	AutoDrive.renameMapMarker(newName, oldName, markerID, false)
	if g_server ~= nil then
		AutoDriveRenameMapMarkerEvent.sendEvent(newName, oldName, markerID, connection)
	end
end

function AutoDriveRenameMapMarkerEvent.sendEvent(newName, oldName, markerID, ignoreConnection)
	local event = AutoDriveRenameMapMarkerEvent:new(newName, oldName, markerID)
	if g_server ~= nil then
		-- Server have to broadcast to all clients except for sender of the rename, if there is one
		g_server:broadcastEvent(event, false, ignoreConnection)
	else
		-- Client have to send to server
		g_client:getServerConnection():sendEvent(event)
	end
end
