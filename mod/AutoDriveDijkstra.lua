
function AutoDrive:ContiniousRecalculation()
	if  AutoDrive.Recalculation.continue == true then
		if AutoDrive.Recalculation.initializedWaypoints == false then
			print(("%s - Recalculating started"):format(getDate("%H:%M:%S")))
			for i2,point in pairs(AutoDrive.mapWayPoints) do
				point.marker = {};
			end;
			AutoDrive.Recalculation.initializedWaypoints = true;
			AutoDrive.Recalculation.handledWayPoints = 1;
			AutoDrive.Recalculation.dijkstraStep = 0
			AutoDrive.Recalculation.dijkstraCopy = nil;
			return 10;
		end;

		local markerFinished = false;
		--print("AutoDrive - Recalculating");	
		for i, marker in pairs(AutoDrive.mapMarker) do
			if markerFinished == false then
				
				if i == AutoDrive.Recalculation.nextMarker then
					
					--DebugUtil.printTableRecursively(AutoDrive.mapWayPoints, "--", 0,3);
					local tempAD = AutoDrive.Recalculation.dijkstraCopy;
					if AutoDrive.Recalculation.dijkstraCopy == nil then
						local percentage = 0;
						tempAD, percentage = AutoDrive:dijkstra(AutoDrive.mapWayPoints, marker.id,"incoming");
						
						--Only continue if dijkstra calculation has finished
						if tempAD == -1 then
							local markerPercentage = (AutoDrive.Recalculation.handledMarkers/AutoDrive.mapMarkerCounter);
							local percentagePerMarker = math.ceil(90/AutoDrive.mapMarkerCounter);
							return 10 + math.ceil(markerPercentage * 90) + math.ceil(percentage * percentagePerMarker * 0.5);
						else
							AutoDrive.Recalculation.dijkstraCopy = tempAD;
						end;
					end;

					local wayPointsToHandleThisFrame = 2000;
					while wayPointsToHandleThisFrame > 0  and AutoDrive.Recalculation.handledWayPoints < AutoDrive.mapWayPointsCounter do
						wayPointsToHandleThisFrame = wayPointsToHandleThisFrame - 1;
						local point = AutoDrive.mapWayPoints[AutoDrive.Recalculation.handledWayPoints];						
						point.marker[marker.name] = tempAD.pre[point.id];
						AutoDrive.Recalculation.handledWayPoints = AutoDrive.Recalculation.handledWayPoints + 1;
					end;

					if AutoDrive.Recalculation.handledWayPoints >= AutoDrive.mapWayPointsCounter then
						markerFinished = true;
						AutoDrive.Recalculation.dijkstraCopy = nil;
						AutoDrive.Recalculation.handledWayPoints = 1;
					end;

					if wayPointsToHandleThisFrame == 0 and AutoDrive.Recalculation.handledWayPoints < AutoDrive.mapWayPointsCounter and markerFinished ~= true then
						local markerPercentage = (AutoDrive.Recalculation.handledMarkers/AutoDrive.mapMarkerCounter);
						local wayPointPercentage = (AutoDrive.Recalculation.handledWayPoints/AutoDrive.mapWayPointsCounter)
						local percentagePerMarker = math.ceil(90/AutoDrive.mapMarkerCounter);
						return 10 + math.ceil(markerPercentage * 90) + (percentagePerMarker/2) + math.ceil(wayPointPercentage * percentagePerMarker * 0.5);
					end;

				end;
			else				
				AutoDrive.Recalculation.nextMarker = i;
				AutoDrive.Recalculation.handledMarkers = AutoDrive.Recalculation.handledMarkers + 1;
				return 10 + math.ceil((AutoDrive.Recalculation.handledMarkers/AutoDrive.mapMarkerCounter) * 90)
			end;
		end;

		if AutoDrive.adXml ~= nil then
			setXMLString(AutoDrive.adXml, "AutoDrive.Recalculation","false");
			AutoDrive:MarkChanged();
			AutoDrive.handledRecalculation = true;
		end;

		AutoDrive.Recalculation.continue = false;
		print(("%s - Recalculating finished"):format(getDate("%H:%M:%S")))
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
    if AutoDrive.Recalculation.dijkstraStep < 3 then
        AutoDrive:dijkstraInit(Graph, start, setToUse);
    end;

    local workGraph = AutoDrive.dijkstraCalc;
	local workDistances = workGraph.distance;
	local workPre = workGraph.pre;
	local workQ = workGraph.Q;

	if AutoDrive.Recalculation.dijkstraStep == 3 then
		AutoDrive.Recalculation.dijkstraAllowedIteratorQ = 200 / (math.max(1, (AutoDrive.mapWayPointsCounter/2000)));		

		while AutoDrive.Recalculation.dijkstraAllowedIteratorQ > 0 and next(workQ,nil) ~= nil do
			AutoDrive.Recalculation.dijkstraAllowedIteratorQ = AutoDrive.Recalculation.dijkstraAllowedIteratorQ - 1;
			AutoDrive.Recalculation.dijkstraHandledIteratorsQ = AutoDrive.Recalculation.dijkstraHandledIteratorsQ + 1;

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
				local numOfOutgoingLines = 0;
				local lastShortest = -1;
				local lastShortestID = shortest_id;

				--update distances of long chained line without iterating over all nodes again
                while longLine == true do
					for _,outgoing in pairs(AutoDrive.mapWayPoints[shortest_id].out) do
						numOfOutgoingLines = numOfOutgoingLines + 1;
					end;

					for i, linkedNodeId in pairs(workQ[shortest_id]) do
						
						local wp = workQ[linkedNodeId]
						if wp ~= nil then					
							--distanceupdate
							local alternative = shortest + 1;
							if alternative < workDistances[linkedNodeId] then
								workDistances[linkedNodeId] = alternative;
								workPre[linkedNodeId] = shortest_id;
								lastShortest = alternative;
								lastShortestID = linkedNodeId;
							end;
						end;			
					end;
					
					workQ[shortest_id] = nil;

					if numOfOutgoingLines > 1 or (lastShortestID == shortest_id) then
						longLine = false;
					else						
						shortest_id = lastShortestID;
						shortest = lastShortest;
					end;
				end;
			end;	
		end;

		if next(workQ,nil) == nil then
			AutoDrive.Recalculation.dijkstraStep = 0;
			return AutoDrive.dijkstraCalc, 1.0;
		else
			local percentage = AutoDrive.Recalculation.dijkstraHandledIteratorsQ/AutoDrive.mapWayPointsCounter;
			return -1, percentage;
		end;
	end;	
	
	if AutoDrive.Recalculation.dijkstraStep < 3 then
		AutoDrive.Recalculation.dijkstraStep = AutoDrive.Recalculation.dijkstraStep + 1;		
	end;

	return -1, 0.1;
end;

function AutoDrive:dijkstraInit(Graph, start, setToUse)
    if AutoDrive.Recalculation.dijkstraStep == 0 then
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
		AutoDrive.Recalculation.dijkstraHandledIteratorsQ = 0;
	end;

	local workGraph = AutoDrive.dijkstraCalc;
	local workDistances = workGraph.distance;
	local workPre = workGraph.pre;
	local workQ = workGraph.Q;

	if AutoDrive.Recalculation.dijkstraStep == 1 then
		for i in pairs(Graph) do
			workDistances[i] = math.huge;
			workPre[i] = -1;
		end;
	end;

	if AutoDrive.Recalculation.dijkstraStep == 2 then
		workDistances[start] = 0;
		for i, id in pairs(workQ[start]) do
			workDistances[id] = 1;
			workPre[id] = start;
		end;
	end;	
end;