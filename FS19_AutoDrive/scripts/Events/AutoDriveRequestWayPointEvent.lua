AutoDriveRequestWayPointEvent = {}
AutoDriveRequestWayPointEvent_mt = Class(AutoDriveRequestWayPointEvent, Event)

InitEventClass(AutoDriveRequestWayPointEvent, "AutoDriveRequestWayPointEvent")

function AutoDriveRequestWayPointEvent:emptyNew()
	local self = Event:new(AutoDriveRequestWayPointEvent_mt)
	self.className = "AutoDriveRequestWayPointEvent"
	return self
end

function AutoDriveRequestWayPointEvent:new()
	local self = AutoDriveRequestWayPointEvent:emptyNew()
	return self
end

function AutoDriveRequestWayPointEvent:writeStream(streamId, connection)
	if g_server == nil then
		--print("Requesting waypoints");
		local user = g_currentMission.userManager:getUserByUserId(g_currentMission.playerUserId)
		streamWriteInt32(streamId, user:getId())
	end
end

function AutoDriveRequestWayPointEvent:readStream(streamId, connection)
	if g_server ~= nil then
		--print("Receiving request for broadcasting waypoints");
		local id = streamReadInt32(streamId)
		AutoDrive.Server.Users[id] = {}
		AutoDrive.Server.Users[id].highestIndex = 1
		AutoDrive.Server.Users[id].ackReceived = true
		AutoDrive.Server.Users[id].keepAlive = 300
		AutoDrive.requestedWaypoints = true
		AutoDrive.requestedWaypointCount = 1
	end
end

function AutoDriveRequestWayPointEvent:sendEvent()
	if g_server == nil then
		g_client:getServerConnection():sendEvent(AutoDriveRequestWayPointEvent:new())
	end
end
