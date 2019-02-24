AutoDriveCourseDownloadEvent = {};
AutoDriveCourseDownloadEvent_mt = Class(AutoDriveCourseDownloadEvent, Event);

InitEventClass(AutoDriveCourseDownloadEvent, "AutoDriveCourseDownloadEvent");

function AutoDriveCourseDownloadEvent:emptyNew()
	local self = Event:new(AutoDriveCourseDownloadEvent_mt);
	self.className="AutoDriveCourseDownloadEvent";
	return self;
end;

function AutoDriveCourseDownloadEvent:new(vehicle)
	local self = AutoDriveCourseDownloadEvent:emptyNew()
	self.vehicle = vehicle;
	--print("event new")
	return self;
end;

function AutoDriveCourseDownloadEvent:writeStream(streamId, connection)
	if AutoDrive == nil then
		return;
	end;
	if g_server ~= nil or AutoDrive.playerSendsMapToServer == true then
		--print("Broadcasting waypoints");

		local idFullTable = {};
		local idString = "";
		local idCounter = 0;

		local xTable = {};
		local xString = "";

		local yTable = {};
		local yString = "";

		local zTable = {};
		local zString = "";

		local outTable = {};
		local outString = "";

		local incomingTable = {};
		local incomingString = "";

		local markerNamesTable = {};
		local markerNames = "";

		local markerIDsTable = {};
		local markerIDs = "";


		local wayPointsInCurrentMessage = 0;
		
		for i=AutoDrive.requestedWaypointCount, math.min(AutoDrive.requestedWaypointCount + 24, AutoDrive.mapWayPointsCounter), 1 do --for i,p in pairs(AutoDrive.mapWayPoints) do
			local p = AutoDrive.mapWayPoints[i];		

			idCounter = idCounter + 1;
			idFullTable[idCounter] = p.id;
			xTable[idCounter] = p.x;
			yTable[idCounter] = p.y;
			zTable[idCounter] = p.z;

			outTable[idCounter] = table.concat(p.out, ",");

			local innerIncomingTable = {};
			for incomingIndex,incomingID in pairs(p.incoming) do
				innerIncomingTable[incomingIndex] = incomingID;
			end;			
			incomingTable[idCounter] = table.concat(innerIncomingTable, ",");

			local markerCounter = 1;
			local innerMarkerNamesTable = {};
			local innerMarkerIDsTable = {};
			for i2,marker in pairs(p.marker) do
				innerMarkerIDsTable[markerCounter] = marker;
				innerMarkerNamesTable[markerCounter] = i2;
				markerCounter = markerCounter + 1;
			end;

			markerNamesTable[idCounter] = table.concat(innerMarkerNamesTable, ",");
			markerIDsTable[idCounter] = table.concat(innerMarkerIDsTable, ",");
		end;

		if idFullTable[1] ~= nil then
			streamWriteFloat32(streamId, idCounter);
			local i = 1;
			while i <= idCounter do
				streamWriteFloat32(streamId,idFullTable[i]);
				streamWriteFloat32(streamId,xTable[i]);
				streamWriteFloat32(streamId,yTable[i]);
				streamWriteFloat32(streamId,zTable[i]);
				streamWriteStringOrEmpty(streamId,outTable[i]);
				streamWriteStringOrEmpty(streamId,incomingTable[i]);
				if markerIDsTable[1] ~= nil then
					streamWriteStringOrEmpty(streamId, markerIDsTable[i]);
					streamWriteStringOrEmpty(streamId, markerNamesTable[i]);
				else
					streamWriteStringOrEmpty(streamId, "");
					streamWriteStringOrEmpty(streamId, "");
				end;
				i = i + 1;
			end;
		end;

		--print("Broadcasting waypoints from " .. AutoDrive.requestedWaypointCount .. " to " ..  math.min(AutoDrive.requestedWaypointCount + 24, AutoDrive.mapWayPointsCounter));
		AutoDrive.requestedWaypointCount = math.min(AutoDrive.requestedWaypointCount + 25, AutoDrive.mapWayPointsCounter);

		if AutoDrive.requestedWaypointCount >= AutoDrive.mapWayPointsCounter then
			local markerIDs = "";
			local markerNames = "";
			local markerCounter = 0;
			for i in pairs(AutoDrive.mapMarker) do
				markerCounter = markerCounter + 1;
			end;
			streamWriteFloat32(streamId, markerCounter);
			local i = 1;
			while i <= markerCounter do
				streamWriteFloat32(streamId, AutoDrive.mapMarker[i].id);
				streamWriteStringOrEmpty(streamId, AutoDrive.mapMarker[i].name);
				i = i + 1;
			end;

			
			AutoDrive.requestedWaypoints = false;			
			AutoDrive.playerSendsMapToServer = false;
			if g_server == nil then
				--make sure everybode gets a course update after upload to the server
				--AutoDriveRequestWayPointEvent:sendEvent(self.vehicle); --scratch that. due to AutoDrive.requestedWaypoints = false, the client will trigger an update
			end;
			--print("Broadcasted waypoints");
		else
			streamWriteFloat32(streamId, 0);
		end;		
	else
		--print("Requesting waypoints");
		streamWriteInt32(streamId, NetworkUtil.getObjectId(self.vehicle));
	end;
	--print("event writeStream")
end;

function AutoDriveCourseDownloadEvent:readStream(streamId, connection)
	--print("Received Event");
	if AutoDrive == nil then
		return;
	end;

	--if g_server ~= nil then
		--print("Receiving request for broadcasting waypoints");
		--local id = streamReadInt32(streamId);
		--local vehicle = NetworkUtil.getObject(id);
		--AutoDrive.requestedWaypoints = true;
		--AutoDrive.requestedWaypointCount = 1;

		--AutoDriveCourseDownloadEvent:sendEvent(vehicle)
	--else	
		local pointCounter = streamReadFloat32(streamId);
		--print("Receiving waypoints - " .. pointCounter);	
		
		if AutoDrive.receivedWaypoints ~= true then
			AutoDrive.receivedWaypoints = true;
			if pointCounter > 0 then
				AutoDrive.mapWayPoints = {};
			end;
		end;

		local wp_counter = 0;
		while wp_counter < pointCounter do
			wp_counter = wp_counter +1;
			local wp = {};
			wp["id"] =  streamReadFloat32(streamId);
			wp.x = streamReadFloat32(streamId);
			wp.y =	streamReadFloat32(streamId);
			wp.z = streamReadFloat32(streamId);

			local outString = streamReadStringOrEmpty(streamId);
			local outTable = StringUtil.splitString("," , outString);
			wp["out"] = {};
			for i2,outString in pairs(outTable) do
				wp["out"][i2] = tonumber(outString);
			end;

			local incomingString = streamReadStringOrEmpty(streamId);
			local incomingTable = StringUtil.splitString("," , incomingString);
			wp["incoming"] = {};
			local incoming_counter = 1;
			for i2, incomingID in pairs(incomingTable) do
				if incomingID ~= "" then
					wp["incoming"][incoming_counter] = tonumber(incomingID);
				end;
				incoming_counter = incoming_counter +1;
			end;

			local markerIDsString = streamReadStringOrEmpty(streamId);
			local markerIDsTable = StringUtil.splitString("," , markerIDsString);
			local markerNamesString = streamReadStringOrEmpty(streamId);
			local markerNamesTable = StringUtil.splitString("," , markerNamesString);
			wp["marker"] = {};
			for i2, markerName in pairs(markerNamesTable) do
				if markerName ~= "" then
					wp.marker[markerName] = tonumber(markerIDsTable[i2]);
				end;
			end;

			AutoDrive.mapWayPoints[wp.id] = wp;
		end;

		if AutoDrive.mapWayPoints[AutoDrive.mapWayPointsCounter + wp_counter] ~= nil then
			--print("AD: Loaded Waypoints: " .. (AutoDrive.mapWayPointsCounter+1) .. " to " .. AutoDrive.mapWayPointsCounter + wp_counter);
			AutoDrive.mapWayPointsCounter =  AutoDrive.mapWayPointsCounter + wp_counter;
		else
			AutoDrive.mapWayPointsCounter = 0;
		end;

		local mapMarkerCounter = streamReadFloat32(streamId);
		local mapMarkerCount = 1;

		if mapMarkerCounter ~= 0 then
			AutoDrive.mapMarker = {}
			if mapMarkerCounter ~= nil then
				--print("AD: Loaded Destinations: " .. mapMarkerCounter);
			end
			if AutoDrive.Recalculation ~= nil then
				AutoDrive.Recalculation.continue = false;
			end;
		end;

		while mapMarkerCount <= mapMarkerCounter do
			local markerId = streamReadFloat32(streamId);
			local markerName = streamReadStringOrEmpty(streamId);
			local marker = {};

			local node = createTransformGroup(markerName);
			setTranslation(node, AutoDrive.mapWayPoints[markerId].x, AutoDrive.mapWayPoints[markerId].y + 4 , AutoDrive.mapWayPoints[markerId].z  );

			marker.node=node;

			marker.id = markerId;
			marker.name = markerName;

			AutoDrive.mapMarker[mapMarkerCount] = marker;
			mapMarkerCount = mapMarkerCount + 1;
		end;
		AutoDrive.mapMarkerCounter = mapMarkerCounter;
	--end;
end;

function AutoDriveCourseDownloadEvent:sendEvent(vehicle)
	if g_server ~= nil then
		g_server:broadcastEvent(AutoDriveCourseDownloadEvent:new(vehicle), nil, nil, nil);
		--print("broadcasting")
	else
		g_client:getServerConnection():sendEvent(AutoDriveCourseDownloadEvent:new(vehicle));
		--print("sending event to server...")
	end;
end;
