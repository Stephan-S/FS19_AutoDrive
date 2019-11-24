AutoDriveRequestWayPointEvent = {}
AutoDriveRequestWayPointEvent_mt = Class(AutoDriveRequestWayPointEvent, Event)

InitEventClass(AutoDriveRequestWayPointEvent, "AutoDriveRequestWayPointEvent")

function AutoDriveRequestWayPointEvent:emptyNew()
	local o = Event:new(AutoDriveRequestWayPointEvent_mt)
	o.className = "AutoDriveRequestWayPointEvent"
	return o
end

function AutoDriveRequestWayPointEvent:new()
	local o = AutoDriveRequestWayPointEvent:emptyNew()
	return o
end

function AutoDriveRequestWayPointEvent:writeStream(streamId, connection)
	if g_server == nil then
		--g_logManager:devInfo("Requesting waypoints");
		local user = g_currentMission.userManager:getUserByUserId(g_currentMission.playerUserId)
		streamWriteInt32(streamId, user:getId())
	end
end

function AutoDriveRequestWayPointEvent:readStream(streamId, connection)
	if g_server ~= nil then
		--g_logManager:devInfo("Receiving request for broadcasting waypoints");
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
