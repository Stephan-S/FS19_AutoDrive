ADGraphManager = {}

function ADGraphManager:new()
    local o = {}
    setmetatable(o, self)
    self.__index = self
    o.wayPoints = {}
    o.numberOfWayPoints = 0 -- maybe this value can be stored to prevent #self.wayPoints calls, we'll see
    o.mapMarker = {}
    o.groups = {}
    return o
end

-- Calling functions expect a linear, continuous array
function ADGraphManager:getWayPoints()
    return self.wayPoints
end

function ADGraphManager:getWayPointById(wayPointID)
    return self.wayPoints[waypointID]
end

function ADGraphManager:resetWayPoints()
    self.wayPoints = {}
end

function ADGraphManager:setWayPoints(wayPoints)
    self.wayPoints = wayPoints
end

function ADGraphManager:getWayPointCount()
    return #self.wayPoints
end

function ADGraphManager:setWayPoint(newPoint)
    self.wayPoints[newPoint.id] = newPoint
end

function ADGraphManager:getMapMarker()
    return self.mapMarker
end

function ADGraphManager:getMarkerByID(mapMarkerID)
    return self.mapMarker[mapMarkerID]
end

function ADGraphManager:getMapMarkerByWayPointID(wayPointID)
    for _, mapMarker in pairs(self.mapMarker) do
        if mapMarker.id == wayPointID then
            return mapMarker
        end
    end
    return nil
end

function ADGraphManager:getMapMarkerByName(mapMarkerName)
    for _, mapMarker in pairs(self.mapMarker) do
        if mapMarker.name == mapMarkerName then
            return mapMarker
        end
    end
    return nil
end

function ADGraphManager:resetMapMarkers()
    self.mapMarker = {}
end

function ADGraphManager:setMapMarkers(mapMarkers)
    self.mapMarker = mapMarkers
end

function ADGraphManager:setMapMarker(mapMarker)
    self.mapMarker[mapMarker.markerIndex] = mapMarker
end

function ADGraphManager:getPathTo(vehicle, waypointID)
    local wp = {}
    local closestWaypoint = self:findMatchingWayPointForVehicle(vehicle)
    if closestWaypoint ~= nil then
        wp = self:pathFromTo(closestWaypoint, waypointID)
    end
        
    return wp
end

function ADGraphManager:pathFromTo(startWaypointID, targetWaypointID)
    local wp = {}
    if startWaypointID ~= nil and self.wayPoints[startWaypointID] ~= nil and targetWaypointID ~= nil and self.wayPoints[targetWaypointID] ~= nil then
        if startWaypointID == targetWaypointID then
            table.insert(wp, self.wayPoints[targetWaypointID])
        else
            wp = AutoDrive:dijkstraLiveShortestPath(self.wayPoints, startWaypointID, targetWaypointID)
        end
    end
    return wp
end

function ADGraphManager:pathFromToMarker(startWaypointID, markerID)
    local wp = {}
    if startWaypointID ~= nil and self.wayPoints[startWaypointID] ~= nil and self.mapMarker[markerID] ~= nil and self.mapMarker[markerID].id ~= nil then
        local targetID = self.mapMarker[markerID].id
        if targetID == startWaypointID then
            table.insert(wp, 1, self.wayPoints[targetID])
            return wp
        else
            wp = AutoDrive:dijkstraLiveShortestPath(self.wayPoints, startWaypointID, targetID)
        end        
    end
    return wp
end

function ADGraphManager:FastShortestPath(start, markerName, markerID)
	local wp = {}
	local start_id = start
	local target_id = 0

	if start_id == nil or start_id == 0 then
		return wp
	end

	for i in pairs(self.mapMarker) do
		if self.mapMarker[i].name == markerName then
			target_id = self.mapMarker[i].id
			break
		end
	end

	if target_id == 0 then
		return wp
	end

	if target_id == start_id then
		table.insert(wp, 1, Graph[target_id])
		return wp
	end

	wp = AutoDrive:dijkstraLiveShortestPath(self.wayPoints, start_id, target_id)

	return wp
end

function ADGraphManager:getDistanceFromNetwork(vehicle)
    local distance = math.huge
    local x, y, z = getWorldTranslation(vehicle.components[1].node)
    local closest = self:findClosestWayPoint(vehicle)
    if closest ~= nil and self.wayPoints[closest] ~= nil then
        distance = MathUtil.vector2Length(x - self.wayPoints[closest].x, z - self.wayPoints[closest].z)
    end
    print("ADGraphManager:getDistanceFromNetwork(vehicle): " .. distance .. " closest: " .. closest)
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

			-- Removing waypoint from waypoints array
			table.remove(self.wayPoints, wayPoint)
			self.wayPointsCounter = self.wayPointsCounter - 1

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
			for _, marker in pairs(AutoDrive.mapMarker) do
				if marker.id > wayPointId then
					marker.id = marker.id - 1
				end
			end

			-- Resetting HUD
			AutoDrive.Hud.lastUIScale = 0

			if g_server ~= nil then
				-- On the server we must mark the change
				AutoDrive.MarkChanged()
			end
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
			local oldName = self.mapMarker[markerId].name
			-- Renaming map marker
			self.mapMarker[markerId].name = newName

			if g_currentMission.controlledVehicle ~= nil and g_currentMission.controlledVehicle.ad ~= nil and g_currentMission.controlledVehicle.ad.nameOfSelectedTarget == oldName then
				-- nameOfSelectedTarget must be updated only if we are renaming the marker selected on the pullDownList
				g_currentMission.controlledVehicle.ad.nameOfSelectedTarget = newName
			end

			-- Calling external interop listeners
			AutoDrive:notifyDestinationListeners()

			-- Resetting HUD
			AutoDrive.Hud.lastUIScale = 0

			if g_server ~= nil then
				-- On the server we must mark the change
				AutoDrive.MarkChanged()
			end
		end
	end
end

function ADGraphManager:createMapMarkerOnClosest(vehicle, markerName, sendEvent)
	if vehicle ~= nil and markerName:len() > 1 then
		-- Finding closest waypoint
		local closest, _ = self:findClosestWayPoint(vehicle)
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
			local wayPoint = self.wayPoints[markerId]

			-- Creating the new map marker
			self.mapMarker[#self.mapMarker + 1] = {id = markerId, markerIndex = #self.mapMarker, name = markerName, group = "All"})

			-- Calling external interop listeners
			AutoDrive:notifyDestinationListeners()

			-- Resetting HUD
			AutoDrive.Hud.lastUIScale = 0

			if g_server ~= nil then
				-- On the server we must mark the change
				AutoDrive.MarkChanged()
			end
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
			self.mapMarker[markerId].group = groupName
		end
	end
end

function ADGraphManager:removeMapMarker(markerId, sendEvent)
	if markerId ~= nil and markerId >= 0 then
		if sendEvent == nil or sendEvent == true then
			-- Propagating marker deletion all over the network
			AutoDriveDeleteMapMarkerEvent.sendEvent(markerId)
		else
			if self.mapMarker[markerId] ~= nil then
				table.remove(self.mapMarker, markerId)

				-- Removing references to it on all vehicles
				for _, vehicle in pairs(g_currentMission.vehicles) do
					if vehicle.ad ~= nil then
						if vehicle.ad.parkDestination ~= nil and vehicle.ad.parkDestination >= markerId then
							vehicle.ad.parkDestination = -1
						end
						if vehicle.ad.mapMarkerSelected ~= nil and vehicle.ad.mapMarkerSelected >= markerId then
							vehicle.ad.mapMarkerSelected = math.max(vehicle.ad.mapMarkerSelected - 1, 1)
							vehicle.ad.targetSelected = self.mapMarker[vehicle.ad.mapMarkerSelected].id
							vehicle.ad.nameOfSelectedTarget = self.mapMarker[vehicle.ad.mapMarkerSelected].name
						end
						if vehicle.ad.mapMarkerSelected_Unload ~= nil and vehicle.ad.mapMarkerSelected_Unload >= markerId then
							vehicle.ad.mapMarkerSelected_Unload = math.max(vehicle.ad.mapMarkerSelected_Unload - 1, 1)
							vehicle.ad.targetSelected_Unload = self.mapMarker[vehicle.ad.mapMarkerSelected_Unload].id
							vehicle.ad.nameOfSelectedTarget_Unload = self.mapMarker[vehicle.ad.mapMarkerSelected_Unload].name
						end
					end
				end

				if g_server ~= nil then
					removeXMLProperty(AutoDrive.adXml, "AutoDrive." .. AutoDrive.loadedMap .. ".mapmarker.mm" .. (#self.mapMarker +1))
				end
			end

			-- Calling external interop listeners
			AutoDrive:notifyDestinationListeners()

			-- Resetting HUD
			AutoDrive.Hud.lastUIScale = 0

			if g_server ~= nil then
				-- On the server we must mark the change
				AutoDrive.MarkChanged()
			end
		end
	end
end

function ADGraphManager:removeMapMarkerByWayPoint(wayPointId, sendEvent)
	if wayPointId ~= nil and wayPointId >= 0 then
		-- Finding the map waypoint where the marker should be
		local wayPoint = self.wayPoints[wayPointId]
		for markerId, marker in pairs(self.mapMarker) do
			-- Checking if the waypoint id matches the marker id
			if marker.id == wayPoint.id then
				AutoDrive.removeMapMarker(markerId, sendEvent)
				break
			end
		end
	end
end

function ADGraphManager:toggleConnectionBetween(startNode, endNode, sendEvent)
	if sendEvent == nil or sendEvent == true then
		-- Propagating connection toggling all over the network
		AutoDriveToggleConnectionEvent.sendEvent(startNode, endNode)
	else
		if table.contains(startNode.out, endNode.id) or table.contains(endNode.incoming, startNode.id) then
			table.removeValue(startNode.out, endNode.id)
			table.removeValue(endNode.incoming, startNode.id)
		else
			table.insert(startNode.out, endNode.id)
			table.insert(endNode.incoming, startNode.id)
		end

		if g_server ~= nil then
			-- On the server we must mark the change
			AutoDrive.MarkChanged()
		end
	end
end

function ADGraphManager:createWayPoint(vehicle, x, y, z, connectPrevious, dual)
	AutoDrive.MarkChanged()
	if vehicle.ad.createMapPoints == true then
		if #self.wayPoints > 1 and connectPrevious then
			--edit previous point
			local out_index = #self.wayPoints[#self.wayPoints].out
			self.wayPoints[#self.wayPoints].out[out_index+1] = #self.wayPoints + 1
		end

        --edit current point
        table.insert(self.wayPoints, self:createNode(#self.wayPoints+1, x, y, z, {}, {}, {}))
		self.wayPoints[#self.wayPoints].incoming[1] = #self.wayPoints - 1
	end
	if vehicle.ad.creationModeDual == true and connectPrevious then
		local incomingNodes = #self.wayPoints[#self.wayPoints-1].incoming
		self.wayPoints[#self.wayPoints-1].incoming[incomingNodes] = #self.wayPoints
		--edit current point
		self.wayPoints[#self.wayPoints].out[1] =  #self.wayPoints - 1
	end

	AutoDriveCourseEditEvent:sendEvent(self.wayPoints[#self.wayPoints])
	if (self.wayPoints[A#self.wayPoints - 1] ~= nil) then
		AutoDriveCourseEditEvent:sendEvent(self.wayPoints[#self.wayPoints - 1])
	end

	return self.wayPoints[#self.wayPoints]
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

function ADGraphManager:getDistanceBetweenNodes(start, target)
	local euclidianDistance = AutoDrive.getDistance(self.wayPoints[start].x, self.wayPoints[start].z, self.wayPoints[target].x, self.wayPoints[target].z)

	local distance = euclidianDistance

	if AutoDrive.getSetting("avoidMarkers") then
		for _, mapMarker in pairs(self.mapMarker) do
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

	local drivingDistance = AutoDrive.getDistance(wp_ahead.x, wp_ahead.z, wp_current.x, wp_current.z)

	driveTime = (drivingDistance) / (drivingSpeed * (1000 / 3600))

	--avoid map marker

	if not arrivalTime == true then --only for djikstra, for live travel timer we ignore it
		if AutoDrive.getSetting("avoidMarkers") then
			for _, mapMarker in pairs(self.mapMarker) do
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

function ADGraphManager:findClosestWayPoint(vehicle)
	if vehicle.ad.closest ~= nil then
		return vehicle.ad.closest, vehicle.ad.closestDistance
	end

	local startNode = vehicle.ad.frontNode
	if AutoDrive.getSetting("autoConnectStart") or not AutoDrive.experimentalFeatures.redLinePosition then
		startNode = vehicle.components[1].node
	end

	--returns waypoint closest to vehicle position
	local x1, _, z1 = getWorldTranslation(startNode)
	local closest = -1
	local minDistance = math.huge
	if self.wayPoints[1] ~= nil then
		for _, wp in pairs(self.wayPoints) do
			local distance = AutoDrive.getDistance(wp.x, wp.z, x1, z1)
			if distance < minDistance then
				closest = wp.id
				minDistance = distance
			end
		end
	end

	vehicle.ad.closest = closest
	vehicle.ad.closestDistance = minDistance

	return closest, minDistance
end

function ADGraphManager:findMatchingWayPointForVehicle(vehicle)
	local startNode = vehicle.ad.frontNode
	if AutoDrive.getSetting("autoConnectStart") or not AutoDrive.experimentalFeatures.redLinePosition then
		startNode = vehicle.components[1].node
	end
	--returns waypoint closest to vehicle position and with the most suited heading
	local x1, _, z1 = getWorldTranslation(startNode)
	local rx, _, rz = localDirectionToWorld(startNode, 0, 0, 1)
	local vehicleVector = {x = rx, z = rz}
	local point = {x = x1, z = z1}

	local bestPoint, distance = self:findMatchingWayPoint(point, vehicleVector, 1, 20)

	if bestPoint == -1 then
		return self:findClosestWayPoint(vehicle)
	end

	return bestPoint, distance
end

function ADGraphManager:findMatchingWayPoint(point, direction, rangeMin, rangeMax)
	local candidates = self:getWayPointsInRange(point, rangeMin, rangeMax)

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
				local dis = AutoDrive.getDistance(toCheck.x, toCheck.z, point.x, point.z)
				if closest == -1 and (math.abs(angleToNextPoint) < 60 and math.abs(angleToVehicle) < 30) then
					closest = toCheck.id
					distance = dis
					lastAngleToPoint = angleToNextPoint
					lastAngleToVehicle = angleToVehicle
				else
					if (math.abs(angleToNextPoint) + math.abs(angleToVehicle)) < (math.abs(lastAngleToPoint) + math.abs(lastAngleToVehicle)) and (math.abs(angleToNextPoint) < 60 and math.abs(angleToVehicle) < 30) then
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
		local dis = AutoDrive.getDistance(wp.x, wp.z, point.x, point.z)
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