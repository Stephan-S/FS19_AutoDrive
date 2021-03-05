AutoDriveRecordWayPointEvent = {}
AutoDriveRecordWayPointEvent_mt = Class(AutoDriveRecordWayPointEvent, Event)

InitEventClass(AutoDriveRecordWayPointEvent, "AutoDriveRecordWayPointEvent")

function AutoDriveRecordWayPointEvent:emptyNew()
	local o = Event:new(AutoDriveRecordWayPointEvent_mt)
	o.className = "AutoDriveRecordWayPointEvent"
	return o
end

function AutoDriveRecordWayPointEvent:new(x, y, z, connectPrevious, dual, isReverse, previousId)
	local o = AutoDriveRecordWayPointEvent:emptyNew()
	o.x = x
	o.y = y
	o.z = z
	o.connectPrevious = connectPrevious or false
	o.dual = dual or false
	o.isReverse = isReverse
	o.previousId = previousId
	return o
end

function AutoDriveRecordWayPointEvent:writeStream(streamId, connection)
	streamWriteFloat32(streamId, self.x)
	streamWriteFloat32(streamId, self.y)
	streamWriteFloat32(streamId, self.z)
	streamWriteBool(streamId, self.connectPrevious)
	streamWriteBool(streamId, self.dual)
	streamWriteBool(streamId, self.isReverse)
	streamWriteFloat32(streamId, self.previousId)
end

function AutoDriveRecordWayPointEvent:readStream(streamId, connection)
	self.x = streamReadFloat32(streamId)
	self.y = streamReadFloat32(streamId)
	self.z = streamReadFloat32(streamId)
	self.connectPrevious = streamReadBool(streamId)
	self.dual = streamReadBool(streamId)
	self.isReverse = streamReadBool(streamId)
	self.previousId = streamReadFloat32(streamId)
	self:run(connection)
end

function AutoDriveRecordWayPointEvent:run(connection)
	if connection:getIsServer() then
		-- If the event is coming from the server, clients have to record the way point
		ADGraphManager:recordWayPoint(self.x, self.y, self.z, self.connectPrevious, self.dual, self.isReverse, self.previousId, false)
	end
end

function AutoDriveRecordWayPointEvent.sendEvent(x, y, z, connectPrevious, dual, isReverse, previousId)
	if g_server ~= nil then
		-- Server have to broadcast to all clients
		g_server:broadcastEvent(AutoDriveRecordWayPointEvent:new(x, y, z, connectPrevious, dual, isReverse, previousId))
	end
end
