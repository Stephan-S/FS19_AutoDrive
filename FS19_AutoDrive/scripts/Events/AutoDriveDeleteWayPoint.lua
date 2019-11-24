AutoDriveDeleteWayPoint = {}
AutoDriveDeleteWayPoint_mt = Class(AutoDriveDeleteWayPoint, Event)

InitEventClass(AutoDriveDeleteWayPoint, "AutoDriveDeleteWayPoint")

function AutoDriveDeleteWayPoint:emptyNew()
	local o = Event:new(AutoDriveDeleteWayPoint_mt)
	o.className = "AutoDriveDeleteWayPoint"
	return o
end

function AutoDriveDeleteWayPoint:new(wayPointId)
	local o = AutoDriveDeleteWayPoint:emptyNew()
	o.wayPointId = wayPointId
	return o
end

function AutoDriveDeleteWayPoint:writeStream(streamId, connection)
	streamWriteUIntN(streamId, self.wayPointId, 17)
end

function AutoDriveDeleteWayPoint:readStream(streamId, connection)
	self.wayPointId = streamReadUIntN(streamId, 17)
	self:run(connection)
end

function AutoDriveDeleteWayPoint:run(connection)
	if g_server ~= nil and connection:getIsServer() == false then
		-- If the event is coming from a client, server have only to broadcast
		AutoDriveDeleteWayPoint.sendEvent(self.wayPointId)
	else
		-- If the event is coming from the server, both clients and server have to delete the way point
		AutoDrive.removeMapWayPoint(self.wayPointId, false)
	end
end

function AutoDriveDeleteWayPoint.sendEvent(wayPointId)
	local event = AutoDriveDeleteWayPoint:new(wayPointId)
	if g_server ~= nil then
		-- Server have to broadcast to all clients and himself
		g_server:broadcastEvent(event, true)
	else
		-- Client have to send to server
		g_client:getServerConnection():sendEvent(event)
	end
end
