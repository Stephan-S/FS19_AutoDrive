function AutoDrive:ContiniousRecalculation()
	--speed up access by creating local 'copy'
	local recalcTable = AutoDrive.Recalculation
	local mapPoints = AutoDrive.mapWayPoints
	local numberOfWayPoints = AutoDrive.mapWayPointsCounter
	if recalcTable.continue == true then
		if recalcTable.initializedWaypoints == false then
			g_logManager:info("[AutoDrive] %s Recalculating started", getDate("%H:%M:%S"))
			for _, point in pairs(mapPoints) do
				point.marker = {}
			end
			recalcTable.initializedWaypoints = true
			recalcTable.handledWayPoints = 1
			recalcTable.dijkstraStep = 0
			recalcTable.dijkstraCopy = nil
			return 10
		end

		local markerFinished = false
		for i, marker in pairs(AutoDrive.mapMarker) do
			local wayPointsToHandleThisFrame = 2000 * AutoDrive.getSetting("recalculationSpeed")
			if markerFinished == false or wayPointsToHandleThisFrame > 0 then
				if i == recalcTable.nextMarker then
					local tempAD = recalcTable.dijkstraCopy
					if recalcTable.dijkstraCopy == nil then
						local percentage = 0
						tempAD, percentage = AutoDrive:dijkstra(mapPoints, marker.id, "incoming")

						--Only continue if dijkstra calculation has finished
						if tempAD == -1 then
							local markerPercentage = (recalcTable.handledMarkers / AutoDrive.mapMarkerCounter)
							local percentagePerMarker = math.ceil(90 / AutoDrive.mapMarkerCounter)
							return 10 + math.ceil(markerPercentage * 90) + math.ceil(percentage * percentagePerMarker * 0.5)
						else
							recalcTable.dijkstraCopy = tempAD
						end
					end

					--now enter the calculated shortest paths into the AutoDrive.mapWayPoints table to store them permanently
					while wayPointsToHandleThisFrame > 0 and recalcTable.handledWayPoints <= numberOfWayPoints do
						wayPointsToHandleThisFrame = wayPointsToHandleThisFrame - 1
						local point = mapPoints[recalcTable.handledWayPoints]
						point.marker[marker.name] = tempAD.pre[point.id]
						recalcTable.handledWayPoints = recalcTable.handledWayPoints + 1
					end

					if recalcTable.handledWayPoints >= numberOfWayPoints then
						markerFinished = true
						recalcTable.nextMarker = i + 1
						recalcTable.handledMarkers = recalcTable.handledMarkers + 1
						recalcTable.dijkstraCopy = nil
						recalcTable.handledWayPoints = 1
					end

					if wayPointsToHandleThisFrame == 0 and recalcTable.handledWayPoints < numberOfWayPoints and markerFinished ~= true then
						local markerPercentage = (recalcTable.handledMarkers / AutoDrive.mapMarkerCounter)
						local wayPointPercentage = (recalcTable.handledWayPoints / numberOfWayPoints)
						local percentagePerMarker = math.ceil(90 / AutoDrive.mapMarkerCounter)
						return 10 + math.ceil(markerPercentage * 90) + (percentagePerMarker / 2) + math.ceil(wayPointPercentage * percentagePerMarker * 0.5)
					end
				end
			else
				if recalcTable.nextMarker < i then
					recalcTable.handledMarkers = recalcTable.handledMarkers + 1
					recalcTable.nextMarker = i
				end
				return 10 + math.ceil((recalcTable.handledMarkers / AutoDrive.mapMarkerCounter) * 90)
			end
		end

		if AutoDrive.adXml ~= nil then
			setXMLString(AutoDrive.adXml, "AutoDrive.Recalculation", "false")
			AutoDrive.MarkChanged()
			AutoDrive.handledRecalculation = true
		end

		recalcTable.continue = false
		g_logManager:info("[AutoDrive] %s Recalculating finished", getDate("%H:%M:%S"))

		AutoDrive:broadCastUpdateToClients()
		return 100
	else
		AutoDrive.Recalculation = {}
		AutoDrive.Recalculation.continue = true
		AutoDrive.Recalculation.initializedWaypoints = false
		AutoDrive.Recalculation.nextMarker = nil
		for i, _ in pairs(AutoDrive.mapMarker) do
			if AutoDrive.Recalculation.nextMarker == nil then
				AutoDrive.Recalculation.nextMarker = i
			end
		end
		AutoDrive.Recalculation.handledMarkers = 0
		AutoDrive.Recalculation.nextCalculationSkipFrames = 6

		return 5
	end
end

function AutoDrive:dijkstra(Graph, start, setToUse)
	--speed up access by creating local 'copy'
	local recalcTable = AutoDrive.Recalculation
	local mapPoints = AutoDrive.mapWayPoints
	local numberOfWayPoints = AutoDrive.mapWayPointsCounter

	if recalcTable.dijkstraStep < 3 then
		AutoDrive:dijkstraInit(Graph, start, setToUse)
	end

	local workGraph = AutoDrive.dijkstraCalc
	local workDistances = workGraph.distance
	local workPre = workGraph.pre
	local workQ = workGraph.Q

	if recalcTable.dijkstraStep == 3 then
		recalcTable.dijkstraAllowedIteratorQ = 200 / (math.max(0.001, (numberOfWayPoints / (2000 * AutoDrive.getSetting("recalculationSpeed")))))
		local useFastestRoute = AutoDrive.getSetting("useFastestRoute")

		while recalcTable.dijkstraAllowedIteratorQ > 0 and next(workQ, nil) ~= nil do
			recalcTable.dijkstraAllowedIteratorQ = recalcTable.dijkstraAllowedIteratorQ - 1
			recalcTable.dijkstraHandledIteratorsQ = recalcTable.dijkstraHandledIteratorsQ + 1

			local shortest = math.huge
			local shortest_id = -1
			--for i, element in pairs(workQ) do
			--	if workDistances[i] < shortest then
			--		shortest = workDistances[i];
			--		shortest_id = i;
			--	end;
			--end;

			--trying to speed things up. Changes only occur in workDistances
			--if i only have elements in workDistances with values ~= math.huge, I can speed up the process of finding the next shortest id
			if workGraph.workQEntries > (numberOfWayPoints / 2) then
				for i, _ in pairs(workDistances) do
					if workQ[i] ~= nil and workDistances[i] <= shortest then
						shortest = workDistances[i]
						shortest_id = i
					end
				end
			else
				for i, _ in pairs(workQ) do
					if workDistances[i] ~= nil and workDistances[i] <= shortest then
						shortest = workDistances[i]
						shortest_id = i
					end
				end
			end

			if shortest_id == -1 then
				for i, _ in pairs(workQ) do
					if workDistances[i] == nil then
						workDistances[i] = math.huge
						shortest = workDistances[i]
						shortest_id = i
						break
					end
				end
			end

			if shortest_id == -1 then
				workQ = {}
			else
				local longLine = true
				local lastShortest = -1
				local lastShortestID = shortest_id

				--update distances of long chained line without iterating over all nodes again
				while longLine == true do
					if #workQ[shortest_id] > 1 or #mapPoints[shortest_id].out > 1 then
						longLine = false
					end

					for _, linkedNodeId in pairs(workQ[shortest_id]) do
						local wp = workQ[linkedNodeId]

						if wp ~= nil then
							--distanceupdate
							if #wp > 1 or #mapPoints[linkedNodeId].out > 1 then
								longLine = false
							end

							local distanceToAdd = 0
							if useFastestRoute == true then
								distanceToAdd = AutoDrive:getDriveTimeBetweenNodes(shortest_id, linkedNodeId, workPre[shortest_id], nil, true) --3 points for angle
							else
								distanceToAdd = AutoDrive:getDistanceBetweenNodes(shortest_id, linkedNodeId)
							end

							local wp_ahead = mapPoints[linkedNodeId]
							local wp_current = mapPoints[shortest_id]

							--disregard connections with an angle over 90°
							if wp_ahead ~= nil and wp_current ~= nil then
								local angle = 0

								if workPre[shortest_id] ~= nil then
									local wp_ref = mapPoints[workPre[shortest_id]]
									if wp_ref ~= nil then
										angle = math.abs(AutoDrive.angleBetween({x = wp_ahead.x - wp_current.x, z = wp_ahead.z - wp_current.z}, {x = wp_current.x - wp_ref.x, z = wp_current.z - wp_ref.z}))
									end
								end

								if math.abs(angle) > 90 then
									distanceToAdd = math.huge
								end
							end

							local alternative = shortest + distanceToAdd
							if (workDistances[linkedNodeId] == nil or alternative < workDistances[linkedNodeId]) and (alternative < math.huge) then
								workDistances[linkedNodeId] = alternative
								workPre[linkedNodeId] = shortest_id
								lastShortest = alternative
								lastShortestID = linkedNodeId
							end
						end
					end

					workQ[shortest_id] = nil
					workGraph.workQEntries = workGraph.workQEntries - 1

					if (lastShortestID == shortest_id) then
						longLine = false
					else
						shortest_id = lastShortestID
						shortest = lastShortest
					end
					--longLine = false;
				end
			end
		end

		if next(workQ, nil) == nil then
			recalcTable.dijkstraStep = 0
			return AutoDrive.dijkstraCalc, 1.0
		else
			local percentage = recalcTable.dijkstraHandledIteratorsQ / numberOfWayPoints
			return -1, percentage
		end
	end

	if recalcTable.dijkstraStep < 3 then
		recalcTable.dijkstraStep = recalcTable.dijkstraStep + 1
	end

	return -1, 0.1
end

function AutoDrive:dijkstraInit(Graph, start, setToUse)
	--speed up access by creating local 'copy'
	local recalcTable = AutoDrive.Recalculation

	if recalcTable.dijkstraStep == 0 then
		if AutoDrive.dijkstraCalc == nil then
			AutoDrive.dijkstraCalc = {}
		end

		AutoDrive.dijkstraCalc.Q = {}
		for i, point in pairs(Graph) do
			AutoDrive.dijkstraCalc.Q[i] = point[setToUse]
		end
		--AutoDrive.dijkstraCalc.Q = AutoDrive:graphcopy(Graph);
		AutoDrive.dijkstraCalc.distance = {}
		AutoDrive.dijkstraCalc.pre = {}
		recalcTable.dijkstraHandledIteratorsQ = 0
	end

	local workGraph = AutoDrive.dijkstraCalc
	local workDistances = workGraph.distance
	local workPre = workGraph.pre
	local workQ = workGraph.Q
	workGraph.workQEntries = AutoDrive.mapWayPointsCounter

	local forcedInit = AutoDrive.getSetting("recalculationSpeed") > 10

	if recalcTable.dijkstraStep == 1 or forcedInit then
		for i in pairs(Graph) do
			--workDistances[i] = math.huge;
			workPre[i] = -1
		end
	end

	if recalcTable.dijkstraStep == 2 or forcedInit then
		local useFastestRoute = AutoDrive.getSetting("useFastestRoute")
		workDistances[start] = 0
		for _, id in pairs(workQ[start]) do
			local distanceToAdd = 0
			if useFastestRoute == true then
				distanceToAdd = AutoDrive:getDriveTimeBetweenNodes(start, id, nil, nil, nil) --first segments, only 2 points, no angle
			else
				distanceToAdd = AutoDrive:getDistanceBetweenNodes(start, id)
			end
			workDistances[id] = distanceToAdd
			workPre[id] = start
		end
	end

	if forcedInit then
		recalcTable.dijkstraStep = 3
	end
end
