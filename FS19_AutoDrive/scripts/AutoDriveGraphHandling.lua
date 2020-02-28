function AutoDrive.removeMapWayPoint(wayPointId, sendEvent)
	if wayPointId ~= nil and wayPointId >= 0 then
		if sendEvent == nil or sendEvent == true then
			-- Propagating way point deletion all over the network
			AutoDriveDeleteWayPointEvent.sendEvent(wayPointId)
		else
			-- Deleting map marker if there is one on this waypoint, 'sendEvent' must be false because the event propagation have already happened
			AutoDrive.removeMapMarkerByWayPoint(wayPointId, false)

			local mapWayPoint = AutoDrive.mapWayPoints[wayPointId]
			local mapWayPoints = AutoDrive.mapWayPoints

			-- Removing incoming node reference on all out nodes
			for _, id in pairs(mapWayPoint.out) do
				local incomingId = table.indexOf(mapWayPoints[id].incoming, mapWayPoint.id)
				if incomingId ~= nil then
					table.remove(mapWayPoints[id].incoming, incomingId)
				end
			end

			-- Removing out node reference on all incoming nodes
			for _, id in pairs(mapWayPoint.incoming) do
				local outId = table.indexOf(mapWayPoints[id].out, mapWayPoint.id)
				if outId ~= nil then
					table.remove(mapWayPoints[id].out, outId)
				end
			end

			-- Removing waypoint from waypoints array
			table.remove(mapWayPoints, wayPointId)
			AutoDrive.mapWayPointsCounter = AutoDrive.mapWayPointsCounter - 1

			-- Adjusting ids for all succesive nodes :(
			for _, wp in pairs(mapWayPoints) do
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

function AutoDrive.renameMapMarker(newName, markerId, sendEvent)
	if newName:len() > 1 and markerId >= 0 then
		if sendEvent == nil or sendEvent == true then
			-- Propagating marker rename all over the network
			AutoDriveRenameMapMarkerEvent.sendEvent(newName, markerId)
		else
			-- Saving old map marker name
			local oldName = AutoDrive.mapMarker[markerId].name
			-- Renaming map marker
			AutoDrive.mapMarker[markerId].name = newName

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

function AutoDrive.createMapMarkerOnClosest(vehicle, markerName, sendEvent)
	if vehicle ~= nil and markerName:len() > 1 then
		-- Finding closest waypoint
		local closest, _ = AutoDrive:findClosestWayPoint(vehicle)
		if closest ~= nil and closest ~= -1 and AutoDrive.mapWayPoints[closest] ~= nil then
			AutoDrive.createMapMarker(closest, markerName, sendEvent)
		end
	end
end

function AutoDrive.createMapMarker(markerId, markerName, sendEvent)
	if markerId ~= nil and markerId >= 0 and markerName:len() > 1 then
		if sendEvent == nil or sendEvent == true then
			-- Propagating marker creation all over the network
			AutoDriveCreateMapMarkerEvent.sendEvent(markerId, markerName)
		else
			local mapWayPoint = AutoDrive.mapWayPoints[markerId]

			-- Creating the transform for the new map marker
			local node = createTransformGroup(markerName)
			setTranslation(node, mapWayPoint.x, mapWayPoint.y + 4, mapWayPoint.z)

			-- Increasing the map makers count
			AutoDrive.mapMarkerCounter = AutoDrive.mapMarkerCounter + 1

			-- Creating the new map marker
			AutoDrive.mapMarker[AutoDrive.mapMarkerCounter] = {id = markerId, name = markerName, node = node, group = "All"}

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

function AutoDrive.changeMapMarkerGroup(groupName, markerId, sendEvent)
	if groupName:len() > 1 and AutoDrive.groups[groupName] ~= nil and markerId >= 0 then
		if sendEvent == nil or sendEvent == true then
			-- Propagating marker group change all over the network
			AutoDriveChangeMapMarkerGroupEvent.sendEvent(groupName, markerId)
		else
			-- Changing the group name of the marker
			AutoDrive.mapMarker[markerId].group = groupName
		end
	end
end

function AutoDrive.removeMapMarkerByWayPoint(wayPointId, sendEvent)
	if wayPointId ~= nil and wayPointId >= 0 then
		-- Finding the map waypoint where the marker should be
		local mapWayPoint = AutoDrive.mapWayPoints[wayPointId]
		for markerId, marker in pairs(AutoDrive.mapMarker) do
			-- Checking if the waypoint id matches the marker id
			if marker.id == mapWayPoint.id then
				AutoDrive.removeMapMarker(markerId, sendEvent)
				break
			end
		end
	end
end

function AutoDrive.removeMapMarker(markerId, sendEvent)
	if markerId ~= nil and markerId >= 0 then
		if sendEvent == nil or sendEvent == true then
			-- Propagating marker deletion all over the network
			AutoDriveDeleteMapMarkerEvent.sendEvent(markerId)
		else
			if AutoDrive.mapMarker[markerId] ~= nil then
				table.remove(AutoDrive.mapMarker, markerId)
				AutoDrive.mapMarkerCounter = AutoDrive.mapMarkerCounter - 1

				-- Removing references to it on all vehicles
				for _, vehicle in pairs(g_currentMission.vehicles) do
					if vehicle.ad ~= nil then
						if vehicle.ad.parkDestination ~= nil and vehicle.ad.parkDestination >= markerId then
							-- TODO: Should we remove the parking reference if it was on the delete marker?
							vehicle.ad.parkDestination = math.max(vehicle.ad.parkDestination - 1, 1)
						end
						if vehicle.ad.mapMarkerSelected ~= nil and vehicle.ad.mapMarkerSelected >= markerId then
							vehicle.ad.mapMarkerSelected = math.max(vehicle.ad.mapMarkerSelected - 1, 1)
							vehicle.ad.targetSelected = AutoDrive.mapMarker[vehicle.ad.mapMarkerSelected].id
							vehicle.ad.nameOfSelectedTarget = AutoDrive.mapMarker[vehicle.ad.mapMarkerSelected].name
						end
						if vehicle.ad.mapMarkerSelected_Unload ~= nil and vehicle.ad.mapMarkerSelected_Unload >= markerId then
							vehicle.ad.mapMarkerSelected_Unload = math.max(vehicle.ad.mapMarkerSelected_Unload - 1, 1)
							vehicle.ad.targetSelected_Unload = AutoDrive.mapMarker[vehicle.ad.mapMarkerSelected_Unload].id
							vehicle.ad.nameOfSelectedTarget_Unload = AutoDrive.mapMarker[vehicle.ad.mapMarkerSelected_Unload].name
						end
					end
				end

				if g_server ~= nil then
					removeXMLProperty(AutoDrive.adXml, "AutoDrive." .. AutoDrive.loadedMap .. ".mapmarker.mm" .. markerId)
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

function AutoDrive.toggleConnectionBetween(startNode, endNode, sendEvent)
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

function AutoDrive:createWayPoint(vehicle, x, y, z, connectPrevious, dual)
	AutoDrive.MarkChanged()
	if vehicle.ad.createMapPoints == true then
		AutoDrive.mapWayPointsCounter = AutoDrive.mapWayPointsCounter + 1
		if AutoDrive.mapWayPointsCounter > 1 and connectPrevious then
			--edit previous point
			local out_index = 1
			if AutoDrive.mapWayPoints[AutoDrive.mapWayPointsCounter - 1].out[out_index] ~= nil then
				out_index = out_index + 1
			end
			AutoDrive.mapWayPoints[AutoDrive.mapWayPointsCounter - 1].out[out_index] = AutoDrive.mapWayPointsCounter
		end

		--edit current point
		--g_logManager:devInfo("Creating Waypoint #" .. AutoDrive.mapWayPointsCounter);
		AutoDrive.mapWayPoints[AutoDrive.mapWayPointsCounter] = AutoDrive:createNode(AutoDrive.mapWayPointsCounter, x, y, z, {}, {}, {})
		if connectPrevious then
			AutoDrive.mapWayPoints[AutoDrive.mapWayPointsCounter].incoming[1] = AutoDrive.mapWayPointsCounter - 1
		end
	end
	if vehicle.ad.creationModeDual == true and connectPrevious then
		local incomingNodes = 1
		for _, _ in pairs(AutoDrive.mapWayPoints[AutoDrive.mapWayPointsCounter - 1].incoming) do
			incomingNodes = incomingNodes + 1
		end
		AutoDrive.mapWayPoints[AutoDrive.mapWayPointsCounter - 1].incoming[incomingNodes] = AutoDrive.mapWayPointsCounter
		--edit current point
		AutoDrive.mapWayPoints[AutoDrive.mapWayPointsCounter].out[1] = AutoDrive.mapWayPointsCounter - 1
	end

	AutoDriveCourseEditEvent:sendEvent(AutoDrive.mapWayPoints[AutoDrive.mapWayPointsCounter])
	if (AutoDrive.mapWayPoints[AutoDrive.mapWayPointsCounter - 1] ~= nil) then
		AutoDriveCourseEditEvent:sendEvent(AutoDrive.mapWayPoints[AutoDrive.mapWayPointsCounter - 1])
	end

	return AutoDrive.mapWayPoints[AutoDrive.mapWayPointsCounter]
end

function AutoDrive:handleRecording(vehicle)
	if vehicle == nil or vehicle.ad.creationMode == false then
		return
	end

	if g_server == nil then
		return
	end

	local i = 1
	for _, _ in pairs(vehicle.ad.wayPoints) do
		i = i + 1
	end

	--first entry
	if i == 1 then
		local startPoint, _ = AutoDrive:findClosestWayPoint(vehicle)
		local x1, y1, z1 = getWorldTranslation(vehicle.components[1].node)
		if vehicle.ad.createMapPoints == true then
			vehicle.ad.wayPoints[i] = AutoDrive:createWayPoint(vehicle, x1, y1, z1, false, vehicle.ad.creationModeDual)
		end

		if AutoDrive.getSetting("autoConnectStart") then
			if startPoint ~= nil then
				local startNode = AutoDrive.mapWayPoints[startPoint]
				if startNode ~= nil then
					if AutoDrive.getDistanceBetweenNodes(startPoint, AutoDrive.mapWayPointsCounter) < 20 then
						table.insert(startNode.out, vehicle.ad.wayPoints[i].id)
						table.insert(vehicle.ad.wayPoints[i].incoming, startNode.id)

						if vehicle.ad.creationModeDual then
							table.insert(AutoDrive.mapWayPoints[startPoint].incoming, AutoDrive.mapWayPointsCounter)
							table.insert(vehicle.ad.wayPoints[i].out, startPoint)
						end

						AutoDriveCourseEditEvent:sendEvent(startNode)
					end
				end
			end
		end
	else
		if i == 2 then
			local x, y, z = getWorldTranslation(vehicle.components[1].node)
			local wp = vehicle.ad.wayPoints[i - 1]
			if AutoDrive.getDistance(x, z, wp.x, wp.z) > 3 then
				if vehicle.ad.createMapPoints == true then
					vehicle.ad.wayPoints[i] = AutoDrive:createWayPoint(vehicle, x, y, z, true, vehicle.ad.creationModeDual)
				end
			end
		else
			local x, y, z = getWorldTranslation(vehicle.components[1].node)
			local wp = vehicle.ad.wayPoints[i - 1]
			local wp_ref = vehicle.ad.wayPoints[i - 2]
			local angle = math.abs(AutoDrive.angleBetween({x = x - wp_ref.x, z = z - wp_ref.z}, {x = wp.x - wp_ref.x, z = wp.z - wp_ref.z}))
			local max_distance = 6
			if angle < 1 then
				max_distance = 6
			elseif angle < 3 then
				max_distance = 4
			elseif angle < 5 then
				max_distance = 3
			elseif angle < 8 then
				max_distance = 2
			elseif angle < 15 then
				max_distance = 1
			elseif angle < 50 then
				max_distance = 0.5
			end

			if AutoDrive.getDistance(x, z, wp.x, wp.z) > max_distance then
				if vehicle.ad.createMapPoints == true then
					vehicle.ad.wayPoints[i] = AutoDrive:createWayPoint(vehicle, x, y, z, true, vehicle.ad.creationModeDual)
				end
			end
		end
	end
end

function AutoDrive:isDualRoad(start, target)
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

function AutoDrive.getDistanceBetweenNodes(start, target)
	local euclidianDistance = AutoDrive.getDistance(AutoDrive.mapWayPoints[start].x, AutoDrive.mapWayPoints[start].z, AutoDrive.mapWayPoints[target].x, AutoDrive.mapWayPoints[target].z)

	local distance = euclidianDistance

	if AutoDrive.getSetting("avoidMarkers") then
		for _, mapMarker in pairs(AutoDrive.mapMarker) do
			if mapMarker.id == start then
				distance = distance + AutoDrive.getSetting("mapMarkerDetour")
				break
			end
		end
	end

	return distance
end

function AutoDrive:getDriveTimeBetweenNodes(start, target, past, maxDrivingSpeed, arrivalTime)
	--changed setToUse to defined 3 point for angle calculation
	local wp_ahead = AutoDrive.mapWayPoints[target]
	local wp_current = AutoDrive.mapWayPoints[start]

	if wp_ahead == nil or wp_current == nil then
		return 0
	end

	local angle = 0

	if past ~= nil then
		local wp_ref = AutoDrive.mapWayPoints[past]
		if wp_ref ~= nil then
			angle = math.abs(AutoDrive.angleBetween({x = wp_ahead.x - wp_current.x, z = wp_ahead.z - wp_current.z}, {x = wp_current.x - wp_ref.x, z = wp_current.z - wp_ref.z}))
		end
	end

	local driveTime = 0
	local drivingSpeed = 50
	if maxDrivingSpeed ~= nil then
		drivingSpeed = maxDrivingSpeed
	end

	if angle < 3 then
		drivingSpeed = math.min(drivingSpeed, 50)
	elseif angle < 5 then
		drivingSpeed = math.min(drivingSpeed, 38)
	elseif angle < 8 then
		drivingSpeed = math.min(drivingSpeed, 27)
	elseif angle < 12 then
		drivingSpeed = math.min(drivingSpeed, 20)
	elseif angle < 15 then
		drivingSpeed = math.min(drivingSpeed, 13)
	elseif angle < 20 then
		drivingSpeed = math.min(drivingSpeed, 10)
	elseif angle < 30 then
		drivingSpeed = math.min(drivingSpeed, 7)
	else
		drivingSpeed = math.min(drivingSpeed, 4)
	end

	local drivingDistance = AutoDrive.getDistance(wp_ahead.x, wp_ahead.z, wp_current.x, wp_current.z)

	driveTime = (drivingDistance) / (drivingSpeed * (1000 / 3600))

	--avoid map marker

	if not arrivalTime == true then --only for djikstra, for live travel timer we ignore it
		if AutoDrive.getSetting("avoidMarkers") then
			for _, mapMarker in pairs(AutoDrive.mapMarker) do
				if mapMarker.id == start then
					driveTime = driveTime + (AutoDrive.getSetting("mapMarkerDetour") / (20 / 3.6))
					break
				end
			end
		end
	end

	return driveTime, angle
end

function AutoDrive:getDriveTimeForWaypoints(wps, currentWaypoint, maxDrivingSpeed)
	local totalTime = 0

	if wps ~= nil and currentWaypoint ~= nil and wps[currentWaypoint + 1] ~= nil and wps[currentWaypoint] ~= nil and wps[currentWaypoint - 1] == nil then
		totalTime = totalTime + AutoDrive:getDriveTimeBetweenNodes(wps[currentWaypoint].id, wps[currentWaypoint + 1].id, nil, maxDrivingSpeed, true) --first segment, only 2 points, no angle
		currentWaypoint = currentWaypoint + 1
	end
	while wps ~= nil and wps[currentWaypoint - 1] ~= nil and currentWaypoint ~= nil and wps[currentWaypoint + 1] ~= nil do
		if wps[currentWaypoint] ~= nil then
			totalTime = totalTime + AutoDrive:getDriveTimeBetweenNodes(wps[currentWaypoint].id, wps[currentWaypoint + 1].id, wps[currentWaypoint - 1].id, maxDrivingSpeed, true) --continuous segments, 3 points for angle
		end
		currentWaypoint = currentWaypoint + 1
	end
	return totalTime * 1.15 --reduced the factor a little bit
end

function AutoDrive:getHighestConsecutiveIndex()
	local toCheckFor = 0
	local consecutive = true
	while consecutive == true do
		toCheckFor = toCheckFor + 1
		consecutive = false
		if AutoDrive.mapWayPoints[toCheckFor] ~= nil then
			if AutoDrive.mapWayPoints[toCheckFor].id == toCheckFor then
				consecutive = true
			end
		end
	end

	return (toCheckFor - 1)
end

function AutoDrive:findClosestWayPoint(veh)
	if veh.ad.closest ~= nil then
		return veh.ad.closest, veh.ad.closestDistance
	end

	local startNode = veh.ad.frontNode
	if AutoDrive.getSetting("autoConnectStart") or not AutoDrive.experimentalFeatures.redLinePosition then
		startNode = veh.components[1].node
	end

	--returns waypoint closest to vehicle position
	local x1, _, z1 = getWorldTranslation(startNode)
	local closest = -1
	local minDistance = math.huge --AutoDrive.getDistance(AutoDrive.mapWayPoints[1].x,AutoDrive.mapWayPoints[1].z,x1,z1);
	if AutoDrive.mapWayPoints[1] ~= nil then
		for _, wp in pairs(AutoDrive.mapWayPoints) do
			local distance = AutoDrive.getDistance(wp.x, wp.z, x1, z1)
			if distance < minDistance then
				closest = wp.id
				minDistance = distance
			end
		end
	end

	veh.ad.closest = closest
	veh.ad.closestDistance = minDistance

	return closest, minDistance
end

function AutoDrive:findMatchingWayPointForVehicle(veh)
	local startNode = veh.ad.frontNode
	if AutoDrive.getSetting("autoConnectStart") or not AutoDrive.experimentalFeatures.redLinePosition then
		startNode = veh.components[1].node
	end
	--returns waypoint closest to vehicle position and with the most suited heading
	local x1, _, z1 = getWorldTranslation(startNode)
	local rx, _, rz = localDirectionToWorld(startNode, 0, 0, 1)
	local vehicleVector = {x = rx, z = rz}
	local point = {x = x1, z = z1}

	local bestPoint, distance = AutoDrive:findMatchingWayPoint(point, vehicleVector, 1, 20)

	if bestPoint == -1 then
		return AutoDrive:findClosestWayPoint(veh)
	end

	return bestPoint, distance
end

function AutoDrive:findMatchingWayPoint(point, direction, rangeMin, rangeMax)
	local candidates = AutoDrive.getWayPointsInRange(point, rangeMin, rangeMax)

	local closest = -1
	local distance = -1
	local lastAngleToPoint = -1
	local lastAngleToVehicle = -1
	for _, id in pairs(candidates) do
		local toCheck = AutoDrive.mapWayPoints[id]
		local nextP = nil
		local outIndex = 1
		if toCheck.out ~= nil then
			if toCheck.out[outIndex] ~= nil then
				nextP = AutoDrive.mapWayPoints[toCheck.out[outIndex]]
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
					nextP = AutoDrive.mapWayPoints[toCheck.out[outIndex]]
				else
					nextP = nil
				end
			end
		end
	end

	return closest, distance
end

function AutoDrive.getWayPointsInRange(point, rangeMin, rangeMax)
	local inRange = {}

	for _, wp in pairs(AutoDrive.mapWayPoints) do
		local dis = AutoDrive.getDistance(wp.x, wp.z, point.x, point.z)
		if dis < rangeMax and dis > rangeMin then
			table.insert(inRange, wp.id)
		end
	end

	return inRange
end

function AutoDrive:findMatchingWayPointForReverseDirection(veh)
	local startNode = veh.ad.frontNode
	if AutoDrive.getSetting("autoConnectStart") or not AutoDrive.experimentalFeatures.redLinePosition then
		startNode = veh.components[1].node
	end
	--returns waypoint closest to vehicle position and with the most suited heading
	local x1, _, z1 = getWorldTranslation(startNode)
	local rx, _, rz = localDirectionToWorld(startNode, 0, 0, 1)
	local vehicleVector = {x = -rx, z = -rz}
	local point = {x = x1, z = z1}

	local bestPoint = AutoDrive:findMatchingWayPoint(point, vehicleVector, 0.1, 5)

	if bestPoint == -1 then
		return nil
	end

	return bestPoint
end

function AutoDrive:graphcopy(graph)
	local function copyArrayElements(srcArray)
		local newArray = {}
		for i in pairs(srcArray) do
			newArray[i] = srcArray[i]
		end
		return newArray
	end

	local newGraph = {}
	for i in pairs(graph) do
		local graphElem = graph[i]

		local out = copyArrayElements(graphElem.out)
		local incoming = copyArrayElements(graphElem.incoming)

		newGraph[i] = AutoDrive:createNode(graphElem.id, graphElem.x, graphElem.y, graphElem.z, out, incoming)
	end

	return newGraph
end

function AutoDrive:createNode(id, x, y, z, out, incoming)
	return {
		id = id,
		x = x,
		y = y,
		z = z,
		out = out,
		incoming = incoming
	}
end
