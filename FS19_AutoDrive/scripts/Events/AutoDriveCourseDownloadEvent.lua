AutoDriveCourseDownloadEvent = {}
AutoDriveCourseDownloadEvent_mt = Class(AutoDriveCourseDownloadEvent, Event)

InitEventClass(AutoDriveCourseDownloadEvent, "AutoDriveCourseDownloadEvent")

function AutoDriveCourseDownloadEvent:emptyNew()
	local o = Event:new(AutoDriveCourseDownloadEvent_mt)
	o.className = "AutoDriveCourseDownloadEvent"
	return o
end

function AutoDriveCourseDownloadEvent:new()
	local o = AutoDriveCourseDownloadEvent:emptyNew()
	return o
end

function AutoDriveCourseDownloadEvent:writeStream(streamId, connection)
	if g_server ~= nil or AutoDrive.playerSendsMapToServer == true then
		streamWriteInt32(streamId, AutoDrive.requestedWaypointCount)

		streamWriteInt32(streamId, ADGraphManager:getWayPointCount())

		AutoDrive:writeWaypointsToStream(streamId, AutoDrive.requestedWaypointCount, math.min(AutoDrive.requestedWaypointCount + (AutoDrive.WAYPOINTS_PER_PACKET - 1), ADGraphManager:getWayPointCount()))

		--g_logManager:devInfo("Broadcasting waypoints from " .. AutoDrive.requestedWaypointCount .. " to " ..  math.min(AutoDrive.requestedWaypointCount + (AutoDrive.WAYPOINTS_PER_PACKET -1), ADGraphManager:getWayPointCount()));

		if g_server ~= nil then
			for _, user in pairs(AutoDrive.Server.Users) do
				user.ackReceived = false
			end
		end

		if (AutoDrive.requestedWaypointCount + AutoDrive.WAYPOINTS_PER_PACKET) >= ADGraphManager:getWayPointCount() then
			--g_logManager:devInfo("Writing map markers now..");
			AutoDrive:writeMapMarkersToStream(streamId)
			AutoDrive:writeGroupsToStream(streamId)
		else
			streamWriteInt32(streamId, 0)
		end
	end
end

function AutoDriveCourseDownloadEvent:readStream(streamId, connection)
	local lowestID = streamReadInt32(streamId)
	AutoDrive.totalNumberOfWayPointsToReceive = streamReadInt32(streamId)
	local numberOfWayPoints = streamReadInt32(streamId)

	if AutoDrive.receivedWaypoints ~= true then
		AutoDrive.receivedWaypoints = true
		if numberOfWayPoints > 0 then
			ADGraphManager:resetWayPoints()
		end
	end

	if lowestID == 1 then
		ADGraphManager:resetWayPoints()
		ADGraphManager:resetMapMarkers()
	end

	AutoDrive:readWayPointsFromStream(streamId, numberOfWayPoints)

	AutoDrive.highestIndex = math.max(1, ADGraphManager:getHighestConsecutiveIndex())

	local numberOfMapMarkers = streamReadInt32(streamId)

	if (numberOfMapMarkers ~= nil) and (numberOfMapMarkers > 0) then
		ADGraphManager:resetMapMarkers()

		AutoDrive:readMapMarkerFromStream(streamId, numberOfMapMarkers)
		AutoDrive:readGroupsFromStream(streamId)
		if AutoDrive.Hud ~= nil then
			AutoDrive.Hud.lastUIScale = 0
		end
	end

	if g_server == nil then
		AutoDriveAcknowledgeCourseUpdateEvent:sendEvent(AutoDrive.highestIndex)
	end
end

function AutoDriveCourseDownloadEvent:sendEvent()
	if g_server ~= nil then
		g_server:broadcastEvent(AutoDriveCourseDownloadEvent:new(), nil, nil, nil)
		AutoDrive.requestedWaypointCount = math.min(AutoDrive.requestedWaypointCount + AutoDrive.WAYPOINTS_PER_PACKET, ADGraphManager:getWayPointCount())
	else
		g_client:getServerConnection():sendEvent(AutoDriveCourseDownloadEvent:new())
		AutoDrive.requestedWaypointCount = math.min(AutoDrive.requestedWaypointCount + AutoDrive.WAYPOINTS_PER_PACKET, ADGraphManager:getWayPointCount())
	end
end
