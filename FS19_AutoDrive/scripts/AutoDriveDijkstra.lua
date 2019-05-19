function AutoDrive:ContiniousRecalculation()	
	--speed up access by creating local 'copy'
	local recalcTable = AutoDrive.Recalculation;
	local mapPoints = AutoDrive.mapWayPoints;
	local numberOfWayPoints = AutoDrive.mapWayPointsCounter
	if  recalcTable.continue == true then
		if recalcTable.initializedWaypoints == false then
			print(("%s - Recalculating started"):format(getDate("%H:%M:%S")))
			for i2,point in pairs(mapPoints) do
				point.marker = {};
			end;
			recalcTable.initializedWaypoints = true;
			recalcTable.handledWayPoints = 1;
			recalcTable.dijkstraStep = 0
			recalcTable.dijkstraCopy = nil;
			return 10;
		end;

		local markerFinished = false;
		--print("AutoDrive - Recalculating");	
		for i, marker in pairs(AutoDrive.mapMarker) do
			if markerFinished == false then
				
				if i == recalcTable.nextMarker then
					
					--DebugUtil.printTableRecursively(AutoDrive.mapWayPoints, "--", 0,3);
					local tempAD = recalcTable.dijkstraCopy;
					if recalcTable.dijkstraCopy == nil then
						local percentage = 0;
						tempAD, percentage = AutoDrive:dijkstra(mapPoints, marker.id,"incoming");
						
						--Only continue if dijkstra calculation has finished
						if tempAD == -1 then
							local markerPercentage = (recalcTable.handledMarkers/AutoDrive.mapMarkerCounter);
							local percentagePerMarker = math.ceil(90/AutoDrive.mapMarkerCounter);
							return 10 + math.ceil(markerPercentage * 90) + math.ceil(percentage * percentagePerMarker * 0.5);
						else
							recalcTable.dijkstraCopy = tempAD;
						end;
					end;

					local wayPointsToHandleThisFrame = 2000;
					while wayPointsToHandleThisFrame > 0  and recalcTable.handledWayPoints <= numberOfWayPoints do
						wayPointsToHandleThisFrame = wayPointsToHandleThisFrame - 1;
						local point = mapPoints[recalcTable.handledWayPoints];						
						point.marker[marker.name] = tempAD.pre[point.id];
						recalcTable.handledWayPoints = recalcTable.handledWayPoints + 1;
					end;

					if recalcTable.handledWayPoints >= numberOfWayPoints then
						markerFinished = true;
						recalcTable.dijkstraCopy = nil;
						recalcTable.handledWayPoints = 1;
					end;

					if wayPointsToHandleThisFrame == 0 and recalcTable.handledWayPoints < numberOfWayPoints and markerFinished ~= true then
						local markerPercentage = (recalcTable.handledMarkers/AutoDrive.mapMarkerCounter);
						local wayPointPercentage = (recalcTable.handledWayPoints/numberOfWayPoints)
						local percentagePerMarker = math.ceil(90/AutoDrive.mapMarkerCounter);
						return 10 + math.ceil(markerPercentage * 90) + (percentagePerMarker/2) + math.ceil(wayPointPercentage * percentagePerMarker * 0.5);
					end;

				end;
			else				
				recalcTable.nextMarker = i;
				recalcTable.handledMarkers = recalcTable.handledMarkers + 1;
				return 10 + math.ceil((recalcTable.handledMarkers/AutoDrive.mapMarkerCounter) * 90)
			end;
		end;

		if AutoDrive.adXml ~= nil then
			setXMLString(AutoDrive.adXml, "AutoDrive.Recalculation","false");
			AutoDrive:MarkChanged();
			AutoDrive.handledRecalculation = true;
		end;

		recalcTable.continue = false;
		print(("%s - Recalculating finished"):format(getDate("%H:%M:%S")))
		
		AutoDrive:broadCastUpdateToClients();		
		return 100;

	else
		AutoDrive.Recalculation = {};
		AutoDrive.Recalculation.continue = true;
		AutoDrive.Recalculation.initializedWaypoints = false;
		AutoDrive.Recalculation.nextMarker = ""
		for i, marker in pairs(AutoDrive.mapMarker) do
			if AutoDrive.Recalculation.nextMarker == "" then
				AutoDrive.Recalculation.nextMarker = i;
			end;
		end;
		AutoDrive.Recalculation.handledMarkers = 0;
		AutoDrive.Recalculation.nextCalculationSkipFrames = 6;

		return 5;
	end;
end

function AutoDrive:dijkstra(Graph,start,setToUse)
	--speed up access by creating local 'copy'
	local recalcTable = AutoDrive.Recalculation;
	local mapPoints = AutoDrive.mapWayPoints;
	local numberOfWayPoints = AutoDrive.mapWayPointsCounter
	
	if recalcTable.dijkstraStep < 3 then
        AutoDrive:dijkstraInit(Graph, start, setToUse);
    end;

    local workGraph = AutoDrive.dijkstraCalc;
	local workDistances = workGraph.distance;
	local workPre = workGraph.pre;
	local workQ = workGraph.Q;

	if recalcTable.dijkstraStep == 3 then
		recalcTable.dijkstraAllowedIteratorQ = 200 / (math.max(1, (numberOfWayPoints/2000)));		

		while recalcTable.dijkstraAllowedIteratorQ > 0 and next(workQ,nil) ~= nil do
			recalcTable.dijkstraAllowedIteratorQ = recalcTable.dijkstraAllowedIteratorQ - 1;
			recalcTable.dijkstraHandledIteratorsQ = recalcTable.dijkstraHandledIteratorsQ + 1;

			local shortest = 10000000;
			local shortest_id = -1;
			for i, element in pairs(workQ) do			
				if workDistances[i] < shortest then
					shortest = workDistances[i];
					shortest_id = i;
				end;
			end;
			
			if shortest_id == -1 then
				workQ = {};
			else
				local longLine = true;
				local lastShortest = -1;
				local lastShortestID = shortest_id;

				--update distances of long chained line without iterating over all nodes again
                while longLine == true do
					if ADTableLength(workQ[shortest_id]) > 1 or ADTableLength(mapPoints[shortest_id].out) > 1 then
						longLine = false;
					end;

					for i, linkedNodeId in pairs(workQ[shortest_id]) do						
						local wp = workQ[linkedNodeId]
						
						if wp ~= nil then					
							--distanceupdate
							if ADTableLength(wp) > 1 or ADTableLength(mapPoints[linkedNodeId].out) > 1 then
								longLine = false;
							end;

							local distanceToAdd = 0;
							if AutoDrive:getSetting("useFastestRoute") == true then
								distanceToAdd = AutoDrive:getDriveTimeBetweenNodes(shortest_id, linkedNodeId);
							else
								distanceToAdd = AutoDrive:getDistanceBetweenNodes(shortest_id, linkedNodeId);
							end;

							local alternative = shortest + distanceToAdd;
							if alternative < workDistances[linkedNodeId] then
								workDistances[linkedNodeId] = alternative;
								workPre[linkedNodeId] = shortest_id;
								lastShortest = alternative;
								lastShortestID = linkedNodeId;
							end;
						end;			
					end;
					
					workQ[shortest_id] = nil;

					if (lastShortestID == shortest_id) then
						longLine = false;
					else						
						shortest_id = lastShortestID;
						shortest = lastShortest;
					end;
					--longLine = false;
				end;
			end;	
		end;

		if next(workQ,nil) == nil then
			recalcTable.dijkstraStep = 0;
			return AutoDrive.dijkstraCalc, 1.0;
		else
			local percentage = recalcTable.dijkstraHandledIteratorsQ/numberOfWayPoints;
			return -1, percentage;
		end;
	end;	
	
	if recalcTable.dijkstraStep < 3 then
		recalcTable.dijkstraStep = recalcTable.dijkstraStep + 1;		
	end;

	return -1, 0.1;
end;

function AutoDrive:dijkstraInit(Graph, start, setToUse)
	--speed up access by creating local 'copy'
	local recalcTable = AutoDrive.Recalculation;

    if recalcTable.dijkstraStep == 0 then
		if AutoDrive.dijkstraCalc == nil then
			AutoDrive.dijkstraCalc = {};
		end;

		AutoDrive.dijkstraCalc.Q = {};
		for i, point in pairs(Graph) do
			AutoDrive.dijkstraCalc.Q[i] = point[setToUse];
		end;
		--AutoDrive.dijkstraCalc.Q = AutoDrive:graphcopy(Graph);
		AutoDrive.dijkstraCalc.distance = {};
		AutoDrive.dijkstraCalc.pre = {};
		recalcTable.dijkstraHandledIteratorsQ = 0;
	end;

	local workGraph = AutoDrive.dijkstraCalc;
	local workDistances = workGraph.distance;
	local workPre = workGraph.pre;
	local workQ = workGraph.Q;

	if recalcTable.dijkstraStep == 1 then
		for i in pairs(Graph) do
			workDistances[i] = math.huge;
			workPre[i] = -1;
		end;
	end;

	if recalcTable.dijkstraStep == 2 then
		workDistances[start] = 0;
		for i, id in pairs(workQ[start]) do
			local distanceToAdd = 0;
			if AutoDrive:getSetting("useFastestRoute") == true then
				distanceToAdd = AutoDrive:getDriveTimeBetweenNodes(start, id);
			else
				distanceToAdd = AutoDrive:getDistanceBetweenNodes(start, id);
			end;
			workDistances[id] = distanceToAdd;
			workPre[id] = start;
		end;
	end;	
end;