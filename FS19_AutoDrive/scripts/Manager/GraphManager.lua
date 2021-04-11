ADGraphManager = {}

function ADGraphManager:load()
	self.wayPoints = {}
	self.mapMarkers = {}
	self.groups = {}
	self.groups["All"] = 1
	self.changes = false
	self.preparedWayPoints = false
end

function ADGraphManager:markChanges()
	self.changes = true
	self.preparedWayPoints = false
end

function ADGraphManager:resetChanges()
	self.changes = false
end

function ADGraphManager:hasChanges()
	return self.changes
end

function ADGraphManager:areWayPointsPrepared()
	return self.preparedWayPoints
end

-- Calling functions expect a linear, continuous array
function ADGraphManager:getWayPoints()
	return self.wayPoints
end

function ADGraphManager:getWayPointById(wayPointId)
	return self.wayPoints[wayPointId]
end

function ADGraphManager:resetWayPoints()
	self.wayPoints = {}
	self:markChanges()
end

function ADGraphManager:setWayPoints(wayPoints)
	self.wayPoints = wayPoints
	self:markChanges()
end

function ADGraphManager:getWayPointsCount()
	return #self.wayPoints
end

function ADGraphManager:setWayPoint(newPoint)
	self.wayPoints[newPoint.id] = newPoint
	self:markChanges()
end

function ADGraphManager:getMapMarkers()
	return self.mapMarkers
end

function ADGraphManager:getMapMarkerById(mapMarkerId)
	return self.mapMarkers[mapMarkerId]
end

function ADGraphManager:getMapMarkerByWayPointId(wayPointId)
	for _, mapMarker in pairs(self.mapMarkers) do
		if mapMarker.id == wayPointId then
			return mapMarker
		end
	end
	return nil
end

function ADGraphManager:getMapMarkerByName(mapMarkerName)
	for _, mapMarker in pairs(self.mapMarkers) do
		if mapMarker.name == mapMarkerName then
			return mapMarker
		end
	end
	return nil
end

function ADGraphManager:getMapMarkersInGroup(groupName)
	local markersInGroup = {}

	for _, mapMarker in pairs(self.mapMarkers) do
		if mapMarker.group == groupName then
			table.insert(markersInGroup, mapMarker)
		end
	end

	local sort_func = function(a, b)
		a = tostring(a.name):lower()
		b = tostring(b.name):lower()
		local patt = "^(.-)%s*(%d+)$"
		local _, _, col1, num1 = a:find(patt)
		local _, _, col2, num2 = b:find(patt)
		if (col1 and col2) and col1 == col2 then
			return tonumber(num1) < tonumber(num2)
		end
		return a < b
	end

	table.sort(markersInGroup, sort_func)

	return markersInGroup
end

function ADGraphManager:resetMapMarkers()
	self.mapMarkers = {}
end

function ADGraphManager:setMapMarkers(mapMarkers)
	self.mapMarkers = mapMarkers
end

function ADGraphManager:setMapMarker(mapMarker)
	self.mapMarkers[mapMarker.markerIndex] = mapMarker
end

function ADGraphManager:getPathTo(vehicle, waypointId)
	local wp = {}
	local closestWaypoint = self:findMatchingWayPointForVehicle(vehicle)
	if closestWaypoint ~= nil then
		wp = self:pathFromTo(closestWaypoint, waypointId)
	end

	return wp
end

function ADGraphManager:pathFromTo(startWaypointId, targetWaypointId)
	local wp = {}
	if startWaypointId ~= nil and self.wayPoints[startWaypointId] ~= nil and targetWaypointId ~= nil and self.wayPoints[targetWaypointId] ~= nil then
		if startWaypointId == targetWaypointId then
			table.insert(wp, self.wayPoints[targetWaypointId])
		else
			-- wp = ADPathCalculator:GetPath(startWaypointId, targetWaypointId)
			wp = AutoDrive:dijkstraLiveShortestPath(startWaypointId, targetWaypointId)
		end
	end
	return wp
end

function ADGraphManager:pathFromToMarker(startWaypointId, markerId)
	local wp = {}
	if startWaypointId ~= nil and self.wayPoints[startWaypointId] ~= nil and self.mapMarkers[markerId] ~= nil and self.mapMarkers[markerId].id ~= nil then
		local targetId = self.mapMarkers[markerId].id
		if targetId == startWaypointId then
			table.insert(wp, 1, self.wayPoints[targetId])
			return wp
		else
			-- wp = ADPathCalculator:GetPath(startWaypointId, targetId)
			wp = AutoDrive:dijkstraLiveShortestPath(startWaypointId, targetId)
		end
	end
	return wp
end

function ADGraphManager:FastShortestPath(start, markerName, markerId)
	local wp = {}
	local start_id = start
	local target_id = 0

	if start_id == nil or start_id == 0 then
		return wp
	end

	for i in pairs(self.mapMarkers) do
		if self.mapMarkers[i].name == markerName then
			target_id = self.mapMarkers[i].id
			break
		end
	end

	if target_id == 0 then
		return wp
	end

	if target_id == start_id then
		table.insert(wp, 1, self.wayPoints[target_id])
		return wp
	end

	-- wp = ADPathCalculator:GetPath(start_id, target_id)
	wp = AutoDrive:dijkstraLiveShortestPath(start_id, target_id)
	return wp
end

function ADGraphManager:getDistanceFromNetwork(vehicle)
	local _, distance = vehicle:getClosestWayPoint()
	return distance
end

function ADGraphManager:checkYPositionIntegrity()
	for _, wp in pairs(self.wayPoints) do
		if wp.y == -1 then
			wp.y = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, wp.x, 1, wp.z)
		end
	end
end

function ADGraphManager:removeWayPoint(wayPointId, sendEvent)
	if wayPointId ~= nil and wayPointId >= 0 and self.wayPoints[wayPointId] ~= nil then
		if sendEvent == nil or sendEvent == true then
			-- Propagating way point deletion all over the network
			AutoDriveDeleteWayPointEvent.sendEvent(wayPointId)
		else
			-- Deleting map marker if there is one on this waypoint, 'sendEvent' must be false because the event propagation has already happened
			self:removeMapMarkerByWayPoint(wayPointId, false)

			local wayPoint = self.wayPoints[wayPointId]

			-- Removing incoming node reference on all out nodes
			for _, id in pairs(wayPoint.out) do
				local incomingId = table.indexOf(self.wayPoints[id].incoming, wayPoint.id)
				if incomingId ~= nil then
					table.remove(self.wayPoints[id].incoming, incomingId)
				end
			end

			-- Removing out node reference on all incoming nodes
			for _, id in pairs(wayPoint.incoming) do
				local outId = table.indexOf(self.wayPoints[id].out, wayPoint.id)
				if outId ~= nil then
					table.remove(self.wayPoints[id].out, outId)
				end
			end

			if #wayPoint.incoming == 0 then
				-- This is a reverse node, so we can't rely on the incoming table
				for _, wp in pairs(self.wayPoints) do
					if table.contains(wp.out, wayPoint.id) then
						table.removeValue(wp.out, wayPoint.id)
					end
				end
			end

			-- Removing waypoint from waypoints array and invalidate it by setting id to -1
			local wp = table.remove(self.wayPoints, wayPoint.id)
			if wp ~= nil then
				wp.id = -1
			end

			-- Adjusting ids for all succesive nodes :(
			for _, wp in pairs(self.wayPoints) do
				if wp.id > wayPointId then
					wp.id = wp.id - 1
				end
				for i, outId in pairs(wp.out) do
					if outId > wayPointId then
						wp.out[i] = outId - 1
					end
				end
				for i, incomingId in pairs(wp.incoming) do
					if incomingId > wayPointId then
						wp.incoming[i] = incomingId - 1
					end
				end
			end

			-- Adjusting way point id in markers
			for _, marker in pairs(self.mapMarkers) do
				if marker.id > wayPointId then
					marker.id = marker.id - 1
				end
			end

			-- Resetting HUD
			AutoDrive.Hud.lastUIScale = 0

			self:markChanges()
		end
	end
end

function ADGraphManager:renameMapMarker(newName, markerId, sendEvent)
	if newName:len() > 1 and markerId >= 0 then
		if sendEvent == nil or sendEvent == true then
			-- Propagating marker rename all over the network
			AutoDriveRenameMapMarkerEvent.sendEvent(newName, markerId)
		else
			-- Saving old map marker name
			local oldName = self.mapMarkers[markerId].name
			-- Renaming map marker
			self.mapMarkers[markerId].name = newName

			-- Calling external interop listeners
			AutoDrive:notifyDestinationListeners()

			-- Resetting HUD
			AutoDrive.Hud.lastUIScale = 0

			self:markChanges()
		end
	end
end

function ADGraphManager:createMapMarkerOnClosest(vehicle, markerName, sendEvent)
	if vehicle ~= nil and markerName:len() > 1 then
		-- Finding closest waypoint
		local closest, _ = vehicle:getClosestWayPoint()
		if closest ~= nil and closest ~= -1 and self.wayPoints[closest] ~= nil then
			self:createMapMarker(closest, markerName, sendEvent)
		end
	end
end

function ADGraphManager:createMapMarker(markerId, markerName, sendEvent)
	if markerId ~= nil and markerId >= 0 and markerName:len() > 1 then
		if sendEvent == nil or sendEvent == true then
			-- Propagating marker creation all over the network
			AutoDriveCreateMapMarkerEvent.sendEvent(markerId, markerName)
		else
			-- Creating the new map marker
			self.mapMarkers[#self.mapMarkers + 1] = {id = markerId, markerIndex = (#self.mapMarkers + 1), name = markerName, group = "All"}

			-- Calling external interop listeners
			AutoDrive:notifyDestinationListeners()

			-- Resetting HUD
			AutoDrive.Hud.lastUIScale = 0

			self:markChanges()
		end
	end
end

function ADGraphManager:addGroup(groupName, sendEvent)
	if groupName:len() > 1 and self.groups[groupName] == nil then
		if sendEvent == nil or sendEvent == true then
			-- Propagating group creation all over the network
			AutoDriveGroupsEvent.sendEvent(groupName, AutoDriveGroupsEvent.TYPE_ADD)
		else
			self.groups[groupName] = table.count(self.groups) + 1
			for _, vehicle in pairs(g_currentMission.vehicles) do
				if (vehicle.ad ~= nil and vehicle.ad.groups ~= nil) then
					if vehicle.ad.groups[groupName] == nil then
						vehicle.ad.groups[groupName] = false
					end
				end
			end
			-- Resetting HUD
			if AutoDrive.Hud ~= nil then
				AutoDrive.Hud.lastUIScale = 0
			end
			self:markChanges()
		end
	end
end

function ADGraphManager:removeGroup(groupName, sendEvent)
	if self.groups[groupName] ~= nil then
		if sendEvent == nil or sendEvent == true then
			-- Propagating group creation all over the network
			AutoDriveGroupsEvent.sendEvent(groupName, AutoDriveGroupsEvent.TYPE_REMOVE)
		else
			local groupId = self.groups[groupName]
			-- Removing group from the groups list
			self.groups[groupName] = nil
			-- Removing group from the vehicles groups list
			for _, vehicle in pairs(g_currentMission.vehicles) do
				if (vehicle.ad ~= nil and vehicle.ad.groups ~= nil) then
					if vehicle.ad.groups[groupName] ~= nil then
						vehicle.ad.groups[groupName] = nil
					end
				end
			end
			-- Moving all markers in the deleted group to default group
			for markerID, mapMarker in pairs(self:getMapMarkers()) do
				if mapMarker.group == groupName then
					mapMarker.group = "All"
				end
			end
			-- Resetting other goups id
			for gName, gId in pairs(self.groups) do
				if groupId <= gId then
					self.groups[gName] = gId - 1
				end
			end
			-- Resetting HUD
			AutoDrive.Hud.lastUIScale = 0
			self:markChanges()
		end
	end
end

function ADGraphManager:changeMapMarkerGroup(groupName, markerId, sendEvent)
	if groupName:len() > 1 and self.groups[groupName] ~= nil and markerId >= 0 then
		if sendEvent == nil or sendEvent == true then
			-- Propagating marker group change all over the network
			AutoDriveChangeMapMarkerGroupEvent.sendEvent(groupName, markerId)
		else
			-- Changing the group name of the marker
			self.mapMarkers[markerId].group = groupName
			self:markChanges()
		end
	end
end

function ADGraphManager:getGroups()
	return self.groups
end

function ADGraphManager:setGroups(groups, updateVehicles)
	self.groups = groups
	if updateVehicles then
		for _, vehicle in pairs(g_currentMission.vehicles) do
			if vehicle.ad ~= nil then
				if vehicle.ad.groups == nil then
					vehicle.ad.groups = {}
				end
				local newGroups = {}
				for groupName, _ in pairs(ADGraphManager:getGroups()) do
					newGroups[groupName] = vehicle.ad.groups[groupName] or false
				end
				vehicle.ad.groups = newGroups
			end
		end
	end
end

function ADGraphManager:getGroupByName(groupName)
	return self.groups[groupName]
end

function ADGraphManager:removeMapMarker(markerId, sendEvent)
	if markerId ~= nil and markerId >= 0 then
		if sendEvent == nil or sendEvent == true then
			-- Propagating marker deletion all over the network
			AutoDriveDeleteMapMarkerEvent.sendEvent(markerId)
		else
			if self.mapMarkers[markerId] ~= nil then
				table.remove(self.mapMarkers, markerId)
				--Readjust stored markerIndex values to point to corrected ID
				for markerID, marker in pairs(self.mapMarkers) do
					marker.markerIndex = markerID
				end

				if g_server ~= nil then
					-- Removing references to it on all vehicles
					for _, vehicle in pairs(g_currentMission.vehicles) do
						if vehicle.ad ~= nil and vehicle.ad.stateModule ~= nil and vehicle.ad.stateModule.getParkDestinationAtJobFinished ~= nil then
							local parkDestinationAtJobFinished = vehicle.ad.stateModule:getParkDestinationAtJobFinished()
							if parkDestinationAtJobFinished ~= nil and parkDestinationAtJobFinished >= markerId then
								if parkDestinationAtJobFinished == markerId then
									vehicle.ad.stateModule:setParkDestinationAtJobFinished(-1)
								else
									vehicle.ad.stateModule:setParkDestinationAtJobFinished(math.max(parkDestinationAtJobFinished - 1, 1))
								end
							end
						end
					end
					-- handle all vehicles and tools park destination
					for _, vehicle in pairs(g_currentMission.vehicles) do
						if vehicle.advd ~= nil and vehicle.advd.getParkDestination ~= nil and vehicle.advd.setParkDestination ~= nil then
							local parkDestination = vehicle.advd:getParkDestination(vehicle)
							if parkDestination ~= nil and parkDestination >= markerId then
								if parkDestination == markerId then
                                    vehicle.advd:setParkDestination(vehicle, -1)
								else
                                    vehicle.advd:setParkDestination(vehicle, math.max(parkDestination - 1, 1))
								end
							end
						end
					end
				end
			end

			-- Calling external interop listeners
			AutoDrive:notifyDestinationListeners()

			-- Resetting HUD
			AutoDrive.Hud.lastUIScale = 0

			self:markChanges()
		end
	end
end

function ADGraphManager:removeMapMarkerByWayPoint(wayPointId, sendEvent)
	if wayPointId ~= nil and wayPointId >= 0 then
		-- Finding the map waypoint where the marker should be
		local wayPoint = self.wayPoints[wayPointId]
		for markerId, marker in pairs(self.mapMarkers) do
			-- Checking if the waypoint id matches the marker id
			if marker.id == wayPoint.id then
				self:removeMapMarker(markerId, sendEvent)
				break
			end
		end
	end
end

function ADGraphManager:toggleConnectionBetween(startNode, endNode, reverseDirection, sendEvent)
	if startNode == nil or endNode == nil then
		return
	end
	if sendEvent == nil or sendEvent == true then
		-- Propagating connection toggling all over the network
		AutoDriveToggleConnectionEvent.sendEvent(startNode, endNode, reverseDirection)
	else
		if table.contains(startNode.out, endNode.id) or table.contains(endNode.incoming, startNode.id) then
			table.removeValue(startNode.out, endNode.id)
			table.removeValue(endNode.incoming, startNode.id)
		else
			table.insert(startNode.out, endNode.id)
			if not reverseDirection then
				table.insert(endNode.incoming, startNode.id)
			end
		end

		self:markChanges()
	end
end

function ADGraphManager:createWayPoint(x, y, z, sendEvent)
	if sendEvent == nil or sendEvent == true then
		-- Propagating waypoint creation all over the network
		AutoDriveCreateWayPointEvent.sendEvent(x, y, z)
	else
		local prevId = self:getWayPointsCount()
		local newId = prevId + 1
		local newWp = self:createNode(newId, x, y, z, {}, {})
		self:setWayPoint(newWp)
		self:markChanges()
	end
end

function ADGraphManager:changeWayPointPosition(wayPonitId)
	local wayPoint = self:getWayPointById(wayPonitId)
	if wayPoint ~= nil then
		self:moveWayPoint(wayPonitId, wayPoint.x, wayPoint.y, wayPoint.z)
	end
end

function ADGraphManager:moveWayPoint(wayPonitId, x, y, z, sendEvent)
	local wayPoint = self:getWayPointById(wayPonitId)
	if wayPoint ~= nil then
		if sendEvent == nil or sendEvent == true then
			-- Propagating waypoint moving all over the network
			AutoDriveMoveWayPointEvent.sendEvent(wayPonitId, x, y, z)
		else
			wayPoint.x = x
			wayPoint.y = y
			wayPoint.z = z
			self:markChanges()
		end
	end
end

function ADGraphManager:recordWayPoint(x, y, z, connectPrevious, dual, isReverse, previousId, sendEvent)
	previousId = previousId or 0
	local previous
	if connectPrevious then
		if previousId == nil or previousId == 0 then
			previousId = self:getWayPointsCount()
		end
		previous = self:getWayPointById(previousId)
	end
	if g_server ~= nil then
		if sendEvent ~= false then
			-- Propagating waypoint recording to clients
			AutoDriveRecordWayPointEvent.sendEvent(x, y, z, connectPrevious, dual, isReverse, previousId)
		end
	else
		if sendEvent ~= false then
			g_logManager:devWarning("ADGraphManager:recordWayPoint() must be called only on the server.")
			return
		end
	end
	local newId = self:getWayPointsCount() + 1
	local newWp = self:createNode(newId, x, y, z, {}, {})
	self:setWayPoint(newWp)
	if connectPrevious then
		self:toggleConnectionBetween(previous, newWp, isReverse, false)
		if dual then
			self:toggleConnectionBetween(newWp, previous, isReverse, false)
		end
	end
	self:markChanges()
	return newWp
end

function ADGraphManager:isDualRoad(start, target)
	if start == nil or target == nil or start.incoming == nil or target.id == nil then
		return false
	end
	for _, incoming in pairs(start.incoming) do
		if incoming == target.id then
			return true
		end
	end
	return false
end

function ADGraphManager:isReverseRoad(start, target)
	if start == nil or target == nil or start.incoming == nil or target.id == nil then
		return false
	end
	return not table.contains(target.incoming, start.id)
end

function ADGraphManager:getDistanceBetweenNodes(start, target)
	local euclidianDistance = MathUtil.vector2Length(self.wayPoints[start].x - self.wayPoints[target].x, self.wayPoints[start].z - self.wayPoints[target].z)

	local distance = euclidianDistance

	if AutoDrive.getSetting("mapMarkerDetour") > 0 then
		for _, mapMarker in pairs(self.mapMarkers) do
			if mapMarker.id == start then
				distance = distance + AutoDrive.getSetting("mapMarkerDetour")
				break
			end
		end
	end

	return distance
end

function ADGraphManager:getDriveTimeBetweenNodes(start, target, past, maxDrivingSpeed, arrivalTime)
	--changed setToUse to defined 3 point for angle calculation
	local wp_ahead = self.wayPoints[target]
	local wp_current = self.wayPoints[start]

	if wp_ahead == nil or wp_current == nil then
		return 0
	end

	local angle = 0

	if past ~= nil then
		local wp_ref = self.wayPoints[past]
		if wp_ref ~= nil then
			angle = math.abs(AutoDrive.angleBetween({x = wp_ahead.x - wp_current.x, z = wp_ahead.z - wp_current.z}, {x = wp_current.x - wp_ref.x, z = wp_current.z - wp_ref.z}))
		end
	end

	local driveTime = 0
	local drivingSpeed = 50

	if angle < 3 then
		drivingSpeed = 50
	elseif angle < 5 then
		drivingSpeed = 38
	elseif angle < 8 then
		drivingSpeed = 27
	elseif angle < 12 then
		drivingSpeed = 20
	elseif angle < 15 then
		drivingSpeed = 13
	elseif angle < 20 then
		drivingSpeed = 10
	elseif angle < 30 then
		drivingSpeed = 7
	else
		drivingSpeed = 4
	end

	if maxDrivingSpeed ~= nil then
		drivingSpeed = math.min(drivingSpeed, maxDrivingSpeed)
	end

	local drivingDistance = MathUtil.vector2Length(wp_ahead.x - wp_current.x, wp_ahead.z - wp_current.z)

	driveTime = (drivingDistance) / (drivingSpeed * (1000 / 3600))

	--avoid map marker

	if not arrivalTime == true then --only for djikstra, for live travel timer we ignore it
		if AutoDrive.getSetting("mapMarkerDetour") > 0 then
			for _, mapMarker in pairs(self.mapMarkers) do
				if mapMarker.id == start then
					driveTime = driveTime + (AutoDrive.getSetting("mapMarkerDetour") / (20 / 3.6))
					break
				end
			end
		end
	end

	return driveTime, angle
end

function ADGraphManager:getDriveTimeForWaypoints(wps, currentWaypoint, maxDrivingSpeed)
	local totalTime = 0

	if wps ~= nil and currentWaypoint ~= nil and wps[currentWaypoint + 1] ~= nil and wps[currentWaypoint] ~= nil and wps[currentWaypoint - 1] == nil then
		totalTime = totalTime + self:getDriveTimeBetweenNodes(wps[currentWaypoint].id, wps[currentWaypoint + 1].id, nil, maxDrivingSpeed, true) --first segment, only 2 points, no angle
		currentWaypoint = currentWaypoint + 1
	end
	while wps ~= nil and wps[currentWaypoint - 1] ~= nil and currentWaypoint ~= nil and wps[currentWaypoint + 1] ~= nil do
		if wps[currentWaypoint] ~= nil then
			totalTime = totalTime + self:getDriveTimeBetweenNodes(wps[currentWaypoint].id, wps[currentWaypoint + 1].id, wps[currentWaypoint - 1].id, maxDrivingSpeed, true) --continuous segments, 3 points for angle
		end
		currentWaypoint = currentWaypoint + 1
	end
	return totalTime * 1.15
end

function ADGraphManager:getHighestConsecutiveIndex()
	local toCheckFor = 0
	local consecutive = true
	while consecutive == true do
		toCheckFor = toCheckFor + 1
		consecutive = false
		if self.wayPoints[toCheckFor] ~= nil then
			if self.wayPoints[toCheckFor].id == toCheckFor then
				consecutive = true
			end
		end
	end

	return (toCheckFor - 1)
end

function ADGraphManager:findMatchingWayPointForVehicle(vehicle)
	local startNode = vehicle.ad.frontNode
	--returns waypoint closest to vehicle position and with the most suited heading
	local x1, _, z1 = getWorldTranslation(startNode)
	local rx, _, rz = localDirectionToWorld(startNode, 0, 0, 1)
	local vehicleVector = {x = rx, z = rz}
	local point = {x = x1, z = z1}

	local bestPoint, distance = self:findMatchingWayPoint(point, vehicleVector, vehicle:getWayPointIdsInRange(1, 20))

	if bestPoint == -1 then
		return vehicle:getClosestNotReversedWayPoint()
	end

	return bestPoint, distance
end

function ADGraphManager:findMatchingWayPoint(point, direction, candidates)
	candidates = candidates or {}

	local closest = -1
	local distance = -1
	local lastAngleToPoint = -1
	local lastAngleToVehicle = -1
	for _, id in pairs(candidates) do
		local toCheck = self.wayPoints[id]
		local nextP = nil
		local outIndex = 1
		if toCheck.out ~= nil then
			if toCheck.out[outIndex] ~= nil then
				nextP = self.wayPoints[toCheck.out[outIndex]]
			end

			while nextP ~= nil do
				local vecToNextPoint = {x = nextP.x - toCheck.x, z = nextP.z - toCheck.z}
				local vecToVehicle = {x = toCheck.x - point.x, z = toCheck.z - point.z}
				local angleToNextPoint = AutoDrive.angleBetween(direction, vecToNextPoint)
				local angleToVehicle = AutoDrive.angleBetween(direction, vecToVehicle)
				local dis = MathUtil.vector2Length(toCheck.x - point.x, toCheck.z - point.z)
				if closest == -1 and (math.abs(angleToNextPoint) < 60 and math.abs(angleToVehicle) < 30) and #toCheck.incoming > 0 then
					closest = toCheck.id
					distance = dis
					lastAngleToPoint = angleToNextPoint
					lastAngleToVehicle = angleToVehicle
				else
					if #toCheck.incoming > 0 and (math.abs(angleToNextPoint) + math.abs(angleToVehicle)) < (math.abs(lastAngleToPoint) + math.abs(lastAngleToVehicle)) and (math.abs(angleToNextPoint) < 60 and math.abs(angleToVehicle) < 30) then
						closest = toCheck.id
						distance = dis
						lastAngleToPoint = angleToNextPoint
						lastAngleToVehicle = angleToVehicle
					end
				end

				outIndex = outIndex + 1
				if toCheck.out[outIndex] ~= nil then
					nextP = self.wayPoints[toCheck.out[outIndex]]
				else
					nextP = nil
				end
			end
		end
	end

	return closest, distance
end

function ADGraphManager:getWayPointsInRange(point, rangeMin, rangeMax)
	local inRange = {}

	for _, wp in pairs(self.wayPoints) do
		local dis = MathUtil.vector2Length(wp.x - point.x, wp.z - point.z)
		if dis < rangeMax and dis > rangeMin then
			table.insert(inRange, wp.id)
		end
	end

	return inRange
end

function ADGraphManager:createNode(id, x, y, z, out, incoming)
	return {
		id = id,
		x = x,
		y = y,
		z = z,
		out = out,
		incoming = incoming
	}
end

function ADGraphManager:prepareWayPoints()
	local network = self:getWayPoints()
	for id, wp in ipairs(network) do
		wp.transitMapping = {}
		wp.inverseTransitMapping = {}
		if #wp.incoming > 0 then --and #wp.out > 0
			for outIndex, outId in ipairs(wp.out) do
				wp.inverseTransitMapping[outId] = {}
			end

			for inIndex, inId in ipairs(wp.incoming) do
				local inPoint = network[inId]
				wp.transitMapping[inId] = {}
				for outIndex, outId in ipairs(wp.out) do
					local outPoint = network[outId]
					local angle = math.abs(AutoDrive.angleBetween({x = outPoint.x - wp.x, z = outPoint.z - wp.z}, {x = wp.x - inPoint.x, z = wp.z - inPoint.z}))
					--print("prep4: " .. outId .. " angle: " .. angle)

					if angle <= 90 then
						table.insert(wp.transitMapping[inId], outId)
						table.insert(wp.inverseTransitMapping[outId], inId)
					else
						--Also for reverse routes - but only checked on demand, if angle check fails
						local isReverseStart = not table.contains(outPoint.incoming, wp.id)
						local isReverseEnd = table.contains(outPoint.incoming, wp.id) and not table.contains(wp.incoming, inPoint.id)
						if isReverseStart or isReverseEnd then
							table.insert(wp.transitMapping[inId], outId)
							table.insert(wp.inverseTransitMapping[outId], inId)
						end
					end
				end
			end
		end
	end
	self.preparedWayPoints = true
end

-- create map markers for waypoints without out connection
function ADGraphManager:createMarkersAtOpenEnds()
	local network = self:getWayPoints()
	local overallnumberWP = self:getWayPointsCount()
	local debugGroupName = "AD_Debug"

	if overallnumberWP < 3 then
		return
	end

	-- Removing all old map hotspots
	if AutoDrive.mapHotspotsBuffer ~= nil then
        for _, mh in pairs(AutoDrive.mapHotspotsBuffer) do
            g_currentMission:removeMapHotspot(mh)
            mh:delete()
        end
    end
	AutoDrive.mapHotspotsBuffer = {}

	if AutoDrive.getDebugChannelIsSet(AutoDrive.DC_ROADNETWORKINFO) then
		-- create markers for open ends
		local count = 1
		local mapMarkerCounter = #self:getMapMarkers() + 1
		for i, wp in pairs(network) do
			if #wp.out == 0 then
				if wp ~= nil then
					local debugMapMarkerName = tostring(count)

					if self:getGroupByName(debugGroupName) == nil then
						self:addGroup(debugGroupName)
					end

					-- create the mapMarker
					if self:getMapMarkerById(mapMarkerCounter) == nil then
						local mapMarker = {}
						mapMarker.name = debugMapMarkerName
						mapMarker.group = debugGroupName
						mapMarker.markerIndex = mapMarkerCounter
						mapMarker.id = wp.id
						mapMarker.isADDebug = true
						self:setMapMarker(mapMarker)
					end

					count = count + 1
					mapMarkerCounter = mapMarkerCounter + 1
				end
			end
		end
	else
		-- remove debug markers from AD list
		local debugGroupMarkers = self:getMapMarkersInGroup(debugGroupName) -- use a copy of the debug marker list as removeMapMarker will reorder all marker index
		for _, marker in pairs(debugGroupMarkers) do
			-- remove the markers
			if marker.isADDebug == true then
				self:removeMapMarker(marker.markerIndex)
			end
		end

		-- remove the debug group
		if self:getGroupByName(debugGroupName) ~= nil then
			self:removeGroup(debugGroupName)
		end
	end

	-- adding hotspots
	for index, marker in ipairs(self:getMapMarkers()) do
		if (marker.isADDebug == nil) or (marker.isADDebug == true and AutoDrive.getDebugChannelIsSet(AutoDrive.DC_ROADNETWORKINFO)) then
			-- create hotspots for AD all map markers, but Debug markers only if setting is active
			local width, height = getNormalizedScreenValues(9, 9)
			local mh = MapHotspot:new("mapMarkerHotSpot", MapHotspot.CATEGORY_DEFAULT)

			if marker.isADDebug == true then
				mh:delete()
				mh = MapHotspot:new("mapMarkerHotSpot", MapHotspot.CATEGORY_MISSION)
				mh:setImage(g_autoDriveUIFilename, getNormalizedUVs({780, 780, 234, 234}))
			else
				mh:setImage(g_autoDriveUIFilename, getNormalizedUVs({0, 512, 128, 128}))
			end

			mh:setSize(width, height)
			mh:setTextOptions(0)
			mh.isADMarker = true
			table.insert(AutoDrive.mapHotspotsBuffer, mh)

			mh:setText(marker.name)
			local wp = self:getWayPointById(marker.id)
			if wp ~= nil then
				mh:setWorldPosition(wp.x, wp.z)
				mh.enabled = true
				mh.markerID = index
				g_currentMission:addMapHotspot(mh)
			end
		end
	end
end
