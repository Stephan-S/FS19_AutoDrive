function AutoDrive:loadStoredXML()
	local adXml;
	local path = g_currentMission.missionInfo.savegameDirectory;
	local file = "";
	if path ~= nil then
		file = path .."/AutoDrive_config.xml";
	else
		file = getUserProfileAppPath() .. "savegame" .. g_currentMission.missionInfo.savegameIndex  .. "/AutoDrive_config.xml";
	end;
	local tempXml = nil;
	
	if fileExists(file) then
		print("AD: Loading xml file from " .. file);
		AutoDrive.xmlSaveFile = file;
		adXml = loadXMLFile("AutoDrive_XML", file);
		
		local VersionCheck = getXMLString(adXml, "AutoDrive.version");
		local MapCheck = hasXMLProperty(adXml, "AutoDrive." .. AutoDrive.loadedMap);
		if VersionCheck == nil or MapCheck == false then
			print("AD: Version Check or Map check failed - Loading init config");

			path = getUserProfileAppPath();
			file = path .. "/mods/FS19_AutoDrive/AutoDrive_init_config.xml";				

			tempXml = loadXMLFile("AutoDrive_XML_temp", file);--, "AutoDrive");
			local MapCheckInit= hasXMLProperty(tempXml, "AutoDrive." .. AutoDrive.loadedMap);
			if MapCheckInit == false then
				print("AD: Init config does not contain any information for this map. Existing Config will not be overwritten");
				tempXml = nil;
			end;

			print("AD: Finished loading xml from memory");				
		end;				
	else --create std file instead:
		path = getUserProfileAppPath();
		file = path .. "/mods/FS19_AutoDrive/AutoDrive_init_config.xml";
		
		print("AD: Loading xml file from init config");
		tempXml = loadXMLFile("AutoDrive_XML_temp", file);
		--local tempstring = saveXMLFileToMemory(tempXml);
		--adXml = loadXMLFileFromMemory("AutoDrive_XML", tempstring);
		print("AD: Finished loading xml from memory");
		
		AutoDrive:MarkChanged();
		
		path = g_currentMission.missionInfo.savegameDirectory;
		if path ~= nil then
			file = path .."/AutoDrive_config.xml";
		else
			file = getUserProfileAppPath() .. "savegame" .. g_currentMission.missionInfo.savegameIndex  .. "/AutoDrive_config.xml";
		end;
		print("AD: creating xml file at " .. file);
		adXml = createXMLFile("AutoDrive_XML", file, "AutoDrive");
					
		saveXMLFile(adXml);
		AutoDrive.xmlSaveFile = file;
	end;

	AutoDrive:readFromXML(adXml);
end;

function AutoDrive:readFromXML(xmlFile)
	if xmlFile == nil then
		return;
	end;

	AutoDrive.adXml = xmlFile;
	--print("retrieving waypoints");
	--print("map " .. g_currentMission.autoLoadedMap .. " waypoints are loaded");
	if AutoDrive.loadedMap == nil then
		print("AutoDrive could not load your map name");
		return;
	end;

	local recalculate = true;
	local recalculateString = getXMLString(xmlFile, "AutoDrive.Recalculation");
	if recalculateString == "true" then
		recalculate = true;
	end;
	if recalculateString == "false" then
		recalculate = false;
	end;
	if recalculateString == nil then
		print("AutoDrive is starting a new configuration file");
		return;
	end;
		
	local idString = getXMLString(xmlFile, "AutoDrive." .. AutoDrive.loadedMap .. ".waypoints.id");
	local idTable = idString:split(",");
	local xString = getXMLString(xmlFile, "AutoDrive." .. AutoDrive.loadedMap .. ".waypoints.x");
	local xTable = xString:split(",");
	local yString = getXMLString(xmlFile, "AutoDrive." .. AutoDrive.loadedMap .. ".waypoints.y");
	local yTable = yString:split(",");
	local zString = getXMLString(xmlFile, "AutoDrive." .. AutoDrive.loadedMap .. ".waypoints.z");
	local zTable = zString:split(",");
	
	local outString = getXMLString(xmlFile, "AutoDrive." .. AutoDrive.loadedMap .. ".waypoints.out");
	print("Outstring: " .. outString);
	local outTable = outString:split(";");
	for _,out in pairs(outTable) do
		print("Outtable[" .. _ .. "] = " .. out);
	end;
	local outSplitted = {};
	for i, outer in pairs(outTable) do
		local out = outer:split(",");
		outSplitted[i] = out;
		if out == nil then
			outSplitted[i] = {outer};
		end;
	end;
	
	local incomingString = getXMLString(xmlFile, "AutoDrive." .. AutoDrive.loadedMap .. ".waypoints.incoming");
	local incomingTable = incomingString:split(";");
	local incomingSplitted = {};
	for i, outer in pairs(incomingTable) do
		local incoming = outer:split(",");
		incomingSplitted[i] = incoming;	
		if incoming == nil then
			incomingSplitted[i] = {outer};
		end;
	end;
	
	local out_costString = getXMLString(xmlFile, "AutoDrive." .. AutoDrive.loadedMap .. ".waypoints.out_cost");
	local out_costTable = out_costString:split(";");
	local out_costSplitted = {};
	for i, outer in pairs(out_costTable) do
		local out_cost = outer:split(",");
		out_costSplitted[i] = out_cost;	
		if out_cost == nil then
			out_costSplitted[i] = {outer};
		end;				
	end;
	
	local markerIDString = getXMLString(xmlFile, "AutoDrive." .. AutoDrive.loadedMap .. ".waypoints.markerID");
	local markerIDTable = markerIDString:split(";");
	local markerIDSplitted = {};
	for i, outer in pairs(markerIDTable) do
		local markerID = outer:split(",");
		markerIDSplitted[i] = markerID;	
		if markerID == nil then
			markerIDSplitted[i] = {outer};
		end;
	end;
	
	local markerNamesString = getXMLString(xmlFile, "AutoDrive." .. AutoDrive.loadedMap .. ".waypoints.markerNames");
	local markerNamesTable = markerNamesString:split(";");
	local markerNamesSplitted = {};
	for i, outer in pairs(markerNamesTable) do
		local markerNames = outer:split(",");
		markerNamesSplitted[i] = markerNames;
		if markerNames == nil then
			markerNamesSplitted[i] = {outer};
		end;
	end;
	
	local wp_counter = 0;
	for i, id in pairs(idTable) do
		if id ~= "" then
			wp_counter = wp_counter +1;
			local wp = {};
			wp["id"] = tonumber(id);
			wp["out"] = {};
			if outSplitted[i] ~= nil then
				for i2,outString in pairs(outSplitted[i]) do
					local number = tonumber(outString);
					if number ~= -1 then
						wp["out"][i2] = tonumber(outString);
					end;
				end;
			end;			
			
			wp["incoming"] = {};
			local incoming_counter = 1;
			if incomingSplitted[i] ~= nil then
				for i2, incomingID in pairs(incomingSplitted[i]) do
					if incomingID ~= "" then
						local number = tonumber(incomingID);
						if number ~= -1 then
							wp["incoming"][incoming_counter] = tonumber(incomingID);
						end;
					end;
					incoming_counter = incoming_counter +1;
				end;
			end;
			
			wp["out_cost"] = {};
			if out_costSplitted[i] ~= nil then
				for i2,out_costString in pairs(out_costSplitted[i]) do
					local number = tonumber(out_costString);
					if number ~= -1 then
						wp["out_cost"][i2] = tonumber(out_costString);
					end;
				end;
			end;
			
			wp["marker"] = {};
			if markerNamesSplitted[i] ~= nil then
				for i2, markerName in pairs(markerNamesSplitted[i]) do
					if markerName ~= "" then
						wp.marker[markerName] = tonumber(markerIDSplitted[i][i2]);
					end;
				end;
			end;

			wp.x = tonumber(xTable[i]);
			wp.y = tonumber(yTable[i]);
			wp.z = tonumber(zTable[i]);
			
			AutoDrive.mapWayPoints[wp_counter] = wp;			
		end;
		
	end;
	
	if AutoDrive.mapWayPoints[wp_counter] ~= nil then
		print("AD: Loaded Waypoints: " .. wp_counter);
		AutoDrive.mapWayPointsCounter = wp_counter;
	else
		AutoDrive.mapWayPointsCounter = 0;
	end;
		
	local mapMarker = {};
	local mapMarkerCounter = 1;
	mapMarker.name = getXMLString(xmlFile,"AutoDrive." .. AutoDrive.loadedMap ..".mapmarker.mm"..mapMarkerCounter..".name");
	
	while mapMarker.name ~= nil do
		--print("Loading map marker: " .. mapMarker.name);
		mapMarker.id = getXMLFloat(xmlFile,"AutoDrive." .. AutoDrive.loadedMap ..".mapmarker.mm"..mapMarkerCounter..".id");

		local node = createTransformGroup(mapMarker.name);
		setTranslation(node, AutoDrive.mapWayPoints[mapMarker.id].x, AutoDrive.mapWayPoints[mapMarker.id].y + 4 , AutoDrive.mapWayPoints[mapMarker.id].z  );
		mapMarker.node = node;
		--TODO: do this on import as well

		AutoDrive.mapMarker[mapMarkerCounter] = mapMarker;

		mapMarker = nil;
		mapMarker = {};
		mapMarkerCounter = mapMarkerCounter + 1;	
		AutoDrive.mapMarkerCounter = AutoDrive.mapMarkerCounter + 1;
		mapMarker.name = getXMLString(xmlFile,"AutoDrive." .. AutoDrive.loadedMap ..".mapmarker.mm"..mapMarkerCounter..".name");
	end;
	
	local recalculate = true;
	local recalculateString = getXMLString(xmlFile, "AutoDrive.Recalculation");
	if recalculateString == "true" then
		recalculate = true;
	end;
	if recalculateString == "false" then
		recalculate = false;
	end;
				
	if recalculate == true then
		for i2,point in pairs(AutoDrive.mapWayPoints) do
			point.marker = {};
		end;

		print("AD: recalculating routes");
		for i, marker in pairs(AutoDrive.mapMarker) do
			
			local tempAD = AutoDrive:dijkstra(AutoDrive.mapWayPoints, marker.id,"incoming");
			
			for i2,point in pairs(AutoDrive.mapWayPoints) do
						
				point.marker[marker.name] = tempAD.pre[point.id];
							
			end;
			
			
		end;
		setXMLString(xmlFile, "AutoDrive.Recalculation","false");
		AutoDrive:MarkChanged();
		AutoDrive.handledRecalculation = true;
	else
		print("AD: Routes are already calculated");
	end;	
end;

function AutoDrive:saveToXML(xmlFile)
	if xmlFile == nil then
		print("AutoDrive - no valid xml file for saving the configuration");
		return;
	end;
		
	setXMLString(xmlFile, "AutoDrive.Version", AutoDrive.Version);
	if AutoDrive.handledRecalculation ~= true then
		setXMLString(xmlFile, "AutoDrive.Recalculation", "true");	
		print("AD: Set to recalculating routes");
	else
		setXMLString(xmlFile, "AutoDrive.Recalculation", "false");
		print("AD: Set to not recalculating routes");
	end;		
		
	local idFullTable = {};
	local idString = "";
	
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
	
	local out_costTable = {};
	local out_costString = "";
	
	local markerNamesTable = {};
	local markerNames = "";
	
	local markerIDsTable = {};
	local markerIDs = "";
		
	for i,p in pairs(AutoDrive.mapWayPoints) do
	
		idFullTable[i] = p.id;
		xTable[i] = p.x;
		yTable[i] = p.y;
		zTable[i] = p.z;
		
		outTable[i] = table.concat(p.out, ",");
		if outTable[i] == nil or outTable[i] == "" then
			outTable[i] = "-1";
		end;
			
		local innerIncomingTable = {};
		local innerIncomingCounter = 1;
		for i2, p2 in pairs(AutoDrive.mapWayPoints) do
			for i3, out2 in pairs(p2.out) do
				if out2 == p.id then
					innerIncomingTable[innerIncomingCounter] = p2.id;
					innerIncomingCounter = innerIncomingCounter + 1;
				end;
			end;
			if innerIncomingCounter == 1 then
				innerIncomingTable[1] = -1;
			end;
		end;
		incomingTable[i] = table.concat(innerIncomingTable, ",");
		
		out_costTable[i] = table.concat(p.out_cost, ",");
		if out_costTable[i] == nil or out_costTable[i] == "" then
			out_costTable[i] = "-1";
		end;
			
		local markerCounter = 1;
		local innerMarkerNamesTable = {};
		local innerMarkerIDsTable = {};
		for i2,marker in pairs(p.marker) do
			innerMarkerIDsTable[markerCounter] = marker;
			innerMarkerNamesTable[markerCounter] = i2;
			markerCounter = markerCounter + 1;
		end;
		markerNamesTable[i] = table.concat(innerMarkerNamesTable, ",");
		markerIDsTable[i] = table.concat(innerMarkerIDsTable, ",");
	end;
		
	if idFullTable[1] ~= nil then
					
		setXMLString(xmlFile, "AutoDrive." .. AutoDrive.loadedMap .. ".waypoints.id" , table.concat(idFullTable, ",") );
		setXMLString(xmlFile, "AutoDrive." .. AutoDrive.loadedMap .. ".waypoints.x" , table.concat(xTable, ","));
		setXMLString(xmlFile, "AutoDrive." .. AutoDrive.loadedMap .. ".waypoints.y" , table.concat(yTable, ","));
		setXMLString(xmlFile, "AutoDrive." .. AutoDrive.loadedMap .. ".waypoints.z" , table.concat(zTable, ","));
		setXMLString(xmlFile, "AutoDrive." .. AutoDrive.loadedMap .. ".waypoints.out" , table.concat(outTable, ";"));
		setXMLString(xmlFile, "AutoDrive." .. AutoDrive.loadedMap .. ".waypoints.incoming" , table.concat(incomingTable, ";") );
		setXMLString(xmlFile, "AutoDrive." .. AutoDrive.loadedMap .. ".waypoints.out_cost" , table.concat(out_costTable, ";"));
		if markerIDsTable[1] ~= nil then
			setXMLString(xmlFile, "AutoDrive." .. AutoDrive.loadedMap .. ".waypoints.markerID" , table.concat(markerIDsTable, ";"));
			setXMLString(xmlFile, "AutoDrive." .. AutoDrive.loadedMap .. ".waypoints.markerNames" , table.concat(markerNamesTable, ";"));
		end;
	end;
		
	for i in pairs(AutoDrive.mapMarker) do

		setXMLFloat(xmlFile, "AutoDrive." .. AutoDrive.loadedMap .. ".mapmarker.mm".. i ..".id", AutoDrive.mapMarker[i].id);
		setXMLString(xmlFile, "AutoDrive." .. AutoDrive.loadedMap .. ".mapmarker.mm".. i ..".name", AutoDrive.mapMarker[i].name);		
	end;
	
	saveXMLFile(xmlFile);
end;