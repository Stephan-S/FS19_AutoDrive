AutoDriveChangeMapMarkerGroupEvent = {}
AutoDriveChangeMapMarkerGroupEvent_mt = Class(AutoDriveChangeMapMarkerGroupEvent, Event)

InitEventClass(AutoDriveChangeMapMarkerGroupEvent, "AutoDriveChangeMapMarkerGroupEvent")

function AutoDriveChangeMapMarkerGroupEvent:emptyNew()
	local o = Event:new(AutoDriveChangeMapMarkerGroupEvent_mt)
	o.className = "AutoDriveChangeMapMarkerGroupEvent"
	return o
end

function AutoDriveChangeMapMarkerGroupEvent:new(groupName, markerId)
	local o = AutoDriveChangeMapMarkerGroupEvent:emptyNew()
	o.groupName = groupName
	o.markerId = markerId
	return o
end

function AutoDriveChangeMapMarkerGroupEvent:writeStream(streamId, connection)
	AutoDrive.streamWriteStringOrEmpty(streamId, self.groupName)
	streamWriteUInt8(streamId, self.markerId)
end

function AutoDriveChangeMapMarkerGroupEvent:readStream(streamId, connection)
	self.groupName = AutoDrive.streamReadStringOrEmpty(streamId)
	self.markerId = streamReadUInt8(streamId)
	self:run(connection)
end

function AutoDriveChangeMapMarkerGroupEvent:run(connection)
	if g_server ~= nil and connection:getIsServer() == false then
		-- If the event is coming from a client, server have only to broadcast
		AutoDriveChangeMapMarkerGroupEvent.sendEvent(self.groupName, self.markerId)
		--Dedicated server doesn't seem to receive the broadcasts, even when sent with local=true, so we have to do the action here as well
		if g_dedicatedServerInfo == nil then
			return
		end
	end

	-- If the event is coming from the server, both clients and server have to change the marker group
	AutoDrive.changeMapMarkerGroup(self.groupName, self.markerId, false)
end

function AutoDriveChangeMapMarkerGroupEvent.sendEvent(groupName, markerId)
	local event = AutoDriveChangeMapMarkerGroupEvent:new(groupName, markerId)
	if g_server ~= nil then
		-- Server have to broadcast to all clients and himself
		g_server:broadcastEvent(event, true)
	else
		-- Client have to send to server
		g_client:getServerConnection():sendEvent(event)
	end
end
