function AutoDrive:writeWaypointsToStream(streamId, startId, endId)
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
    
    for i=startId, endId, 1 do
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
end;

function AutoDrive:writeMapMarkersToStream(streamId)
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
        streamWriteStringOrEmpty(streamId, AutoDrive.mapMarker[i].group);
        i = i + 1;
    end;

    if g_server == nil then
        AutoDrive.requestedWaypoints = false;			
        AutoDrive.playerSendsMapToServer = false;
    end;
end;

function AutoDrive:writeGroupsToStream(streamId)
    streamWriteFloat32(streamId, #AutoDrive.groups);
    for groupName, groupID in pairs(AutoDrive.groups) do
        streamWriteStringOrEmpty(streamId, groupName);
        streamWriteFloat32(streamId, groupID);
    end;
end;

function AutoDrive:readWayPointsFromStream(streamId, numberOfWayPoints)
    local wp_counter = 0;
	local highestId = 0;
	local lowestId = math.huge;
	while wp_counter < numberOfWayPoints do
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

		highestId = math.max(highestId, wp.id);
		lowestId = math.min(lowestId, wp.id);
	end;
end;

function AutoDrive:readMapMarkerFromStream(streamId, numberOfMapMarkers)
    local mapMarkerCount = 1;
    while mapMarkerCount <= numberOfMapMarkers do
		local markerId = streamReadFloat32(streamId);
		local markerName = streamReadStringOrEmpty(streamId);
		local markerGroup = streamReadStringOrEmpty(streamId);
		local marker = {};

        if AutoDrive.mapWayPoints[markerId] ~= nil then
		    local node = createTransformGroup(markerName);
            setTranslation(node, AutoDrive.mapWayPoints[markerId].x, AutoDrive.mapWayPoints[markerId].y + 4 , AutoDrive.mapWayPoints[markerId].z  );
            marker.node=node;

		    marker.id = markerId;
		    marker.name = markerName;
		    marker.group = markerGroup;

		    AutoDrive.mapMarker[mapMarkerCount] = marker;
            mapMarkerCount = mapMarkerCount + 1;
        else
            print("Error receiving marker " .. markerName);           
        end;		        
	end;
	AutoDrive.mapMarkerCounter = numberOfMapMarkers;
end;

function AutoDrive:readGroupsFromStream(streamId)
    AutoDrive.groups = {};
    local numberOfGroups = streamReadFloat32(streamId);
    local loopCounter = 1;
    while loopCounter <= numberOfGroups do
		local groupName = streamReadStringOrEmpty(streamId);
        local groupID = streamReadFloat32(streamId);
        if groupName ~= nil and groupName ~= "" then
            AutoDrive.groups[groupName] = groupID;
        end;
        loopCounter = loopCounter + 1;
    end;
    AutoDrive.groups["All"] = 1;
end;

function streamReadStringOrEmpty(streamId) 
	local string = streamReadString(streamId);
	if string == nil or string == "nil" then
		string = "";
	end;
	return string;
end;

function streamWriteStringOrEmpty(streamId, string) 	
	if string == nil or string == "" then
		string = "nil";
	end;
	streamWriteString(streamId, string);
end;

function streamWriteInt32OrEmpty(streamId, value) 	
	if value == nil then
		value = 0;
	end;
	streamWriteInt32(streamId, value);
end;

function streamWriteInt16Or1337(streamId, value) 	
	if value == nil then
		value = 1337;
	end;
	streamWriteInt16(streamId, value);
end;

function streamReadInt16Or1337(streamId) 
    local val = streamReadInt16(streamId);
	if val == nil then
		val = 1337;
	end;
	return val;
end;
