function AutoDrive:loadStoredXML()
	local adXml;
	local path = g_currentMission.missionInfo.savegameDirectory;
	local file = "";
	if path ~= nil then
		file = path .. "/AutoDrive_" .. AutoDrive.loadedMap .. "_config.xml";
	else
		file = getUserProfileAppPath() .. "savegame" .. g_currentMission.missionInfo.savegameIndex  .. "/AutoDrive_" .. AutoDrive.loadedMap .. "_config.xml";
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
			file = path .. "/mods/FS19_AutoDrive/AutoDrive_" .. AutoDrive.loadedMap .. "_init_config.xml";				

			tempXml = loadXMLFile("AutoDrive_XML_temp", file);--, "AutoDrive");
			local MapCheckInit= hasXMLProperty(tempXml, "AutoDrive." .. AutoDrive.loadedMap);
			if MapCheckInit == false then
				print("AD: Init config does not contain any information for this map. Existing Config will not be overwritten");
				tempXml = nil;
			end;

			print("AD: Finished loading xml from memory");				
		end;				
	else --create std file instead:
		path = AutoDrive.directory; --getUserProfileAppPath();
		file = path .. "AutoDrive_" .. AutoDrive.loadedMap .. "_init_config.xml";
		
		print("AD: Loading xml file from init config");
		tempXml = loadXMLFile("AutoDrive_XML_temp", file);
		--local tempstring = saveXMLFileToMemory(tempXml);
		--adXml = loadXMLFileFromMemory("AutoDrive_XML", tempstring);
		
		AutoDrive:readFromXML(tempXml);
		print("AD: Finished loading xml from memory");
		
		AutoDrive:MarkChanged();
		
		path = g_currentMission.missionInfo.savegameDirectory;
		if path ~= nil then
			file = path .. "/AutoDrive_" .. AutoDrive.loadedMap .. "_config.xml";
		else
			file = getUserProfileAppPath() .. "savegame" .. g_currentMission.missionInfo.savegameIndex  .. "/AutoDrive_" .. AutoDrive.loadedMap .. "_config.xml";
		end;
		print("AD: creating xml file at " .. file);
		adXml = createXMLFile("AutoDrive_XML", file, "AutoDrive");
					
		saveXMLFile(adXml);
		AutoDrive.xmlSaveFile = file;
		--AutoDrive:saveToXML(adXml);
	end;

	AutoDrive.adXml = adXml;
	AutoDrive:readFromXML(adXml);
end;

function AutoDrive:readFromXML(xmlFile)
	if xmlFile == nil then
		return;
	end;
	
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
		AutoDrive:MarkChanged();
	end;
	if recalculateString == nil then
		print("AutoDrive is starting a new configuration file");
		return;
	end;

	AutoDrive.HudX = getXMLFloat(xmlFile,"AutoDrive.HudX");
	AutoDrive.HudY = getXMLFloat(xmlFile,"AutoDrive.HudY");
	AutoDrive.showingHud = getXMLBool(xmlFile,"AutoDrive.HudShow");
	local lastSetSpeed = getXMLFloat(xmlFile,"AutoDrive.lastSetSpeed");
	if lastSetSpeed ~= nil then
		AutoDrive.lastSetSpeed = lastSetSpeed;
	end;

	for settingName, setting in pairs(AutoDrive.settings) do
		local value = getXMLFloat(xmlFile,"AutoDrive." .. settingName);
		if value ~= nil then
			AutoDrive.settings[settingName].current = value;
		end;
	end;

	local mapMarker = {};
	local mapMarkerCounter = 1;
	mapMarker.name = getXMLString(xmlFile,"AutoDrive." .. AutoDrive.loadedMap ..".mapmarker.mm"..mapMarkerCounter..".name");
	
	AutoDrive.mapMarker = {};

	while mapMarker.name ~= nil do
		--print("Loading map marker: " .. mapMarker.name);
		mapMarker.id = getXMLFloat(xmlFile,"AutoDrive." .. AutoDrive.loadedMap ..".mapmarker.mm"..mapMarkerCounter..".id");

		AutoDrive.mapMarker[mapMarkerCounter] = mapMarker;

		mapMarker = nil;
		mapMarker = {};
		mapMarkerCounter = mapMarkerCounter + 1;	
		AutoDrive.mapMarkerCounter = AutoDrive.mapMarkerCounter + 1;
		mapMarker.name = getXMLString(xmlFile,"AutoDrive." .. AutoDrive.loadedMap ..".mapmarker.mm"..mapMarkerCounter..".name");
	end;
		
	local idString = getXMLString(xmlFile, "AutoDrive." .. AutoDrive.loadedMap .. ".waypoints.id");
	
	--maybe map was opened and saved, but no waypoints recorded with AutoDrive!
	if idString == nil then
		return;
	end;

	AutoDrive.mapWayPoints = {};
	
	local idTable = idString:split(",");
	local xString = getXMLString(xmlFile, "AutoDrive." .. AutoDrive.loadedMap .. ".waypoints.x");
	local xTable = xString:split(",");
	local yString = getXMLString(xmlFile, "AutoDrive." .. AutoDrive.loadedMap .. ".waypoints.y");
	local yTable = yString:split(",");
	local zString = getXMLString(xmlFile, "AutoDrive." .. AutoDrive.loadedMap .. ".waypoints.z");
	local zTable = zString:split(",");
	
	local outString = getXMLString(xmlFile, "AutoDrive." .. AutoDrive.loadedMap .. ".waypoints.out");
	local outTable = outString:split(";");	
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
	
	local markerIDString = getXMLString(xmlFile, "AutoDrive." .. AutoDrive.loadedMap .. ".waypoints.markerID");
	local markerIDSplitted = {};
	if markerIDString ~= nil then
		local markerIDTable = markerIDString:split(";");		
		for i, outer in pairs(markerIDTable) do
			local markerID = outer:split(",");
			markerIDSplitted[i] = markerID;	
			if markerID == nil then
				markerIDSplitted[i] = {outer};
			end;
		end;
	end;
	
	local markerNamesString = getXMLString(xmlFile, "AutoDrive." .. AutoDrive.loadedMap .. ".waypoints.markerNames");
	if markerNamesString ~= nil then
		local markerNamesTable = markerNamesString:split(";");
		local markerNamesSplitted = {};
		for i, outer in pairs(markerNamesTable) do
			local markerNames = outer:split(",");
			markerNamesSplitted[i] = markerNames;
			if markerNames == nil then
				markerNamesSplitted[i] = {outer};
			end;
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
						
			wp["marker"] = {};
			if markerNamesSplitted ~= nil then
				if markerNamesSplitted[i] ~= nil then
					for i2, markerName in pairs(markerNamesSplitted[i]) do
						if markerName ~= "" then						
							wp.marker[markerName] = tonumber(markerIDSplitted[i][i2]);
						end;
					end;
				end;
			else
				if markerIDSplitted[i] ~= nil then
					if markerIDSplitted[i][1] == "=" then
						for markerIndex, marker in pairs(AutoDrive.mapMarker) do
							wp.marker[marker.name] = tonumber(markerIDSplitted[i][2]);
						end;
					else
						for markerIndex, marker in pairs(AutoDrive.mapMarker) do
							wp.marker[marker.name] = tonumber(markerIDSplitted[i][markerIndex]);
						end;
					end;
				else
					for markerIndex, marker in pairs(AutoDrive.mapMarker) do
						wp.marker[marker.name] = -1;
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

	for markerIndex, marker in pairs(AutoDrive.mapMarker) do
		local node = createTransformGroup(marker.name);
		setTranslation(node, AutoDrive.mapWayPoints[marker.id].x, AutoDrive.mapWayPoints[marker.id].y + 4 , AutoDrive.mapWayPoints[marker.id].z  );
		marker.node = node;
	end;

	
	local recalculate = true;
	local recalculateString = getXMLString(xmlFile, "AutoDrive.Recalculation");
	if recalculateString == "true" then
		recalculate = true;
	end;
	if recalculateString == "false" then
		recalculate = false;
	end;
end;

function AutoDrive:ExportRoutes()
	path = getUserProfileAppPath();
	file = path .. "FS19_AutoDrive_Export/AutoDrive_" .. AutoDrive.loadedMap .. "_config.xml";

	createFolder(path .. "FS19_AutoDrive_Export");
	createFolder(path .. "FS19_AutoDrive_Import");
	
	print("AD: creating xml file at " .. file);
	local adXml = createXMLFile("AutoDrive_export_XML", file, "AutoDrive");			
	saveXMLFile(adXml);
	AutoDrive:saveToXML(adXml);
	print("AD: Finished exporting routes");
end;

function AutoDrive:ImportRoutes()
	path = getUserProfileAppPath();
	file = path .. "FS19_AutoDrive_Import/AutoDrive_" .. AutoDrive.loadedMap .. "_config.xml";

	createFolder(path .. "FS19_AutoDrive_Import");

	print("AD: Trying to load xml file from " .. file);
	if fileExists(file) then
		print("AD: Loading xml file from " .. file);
		local adXml = loadXMLFile("AutoDrive_XML", file);
		
		local VersionCheck = getXMLString(adXml, "AutoDrive.version");
		local MapCheck = hasXMLProperty(adXml, "AutoDrive." .. AutoDrive.loadedMap);
		if VersionCheck == nil or MapCheck == false then
			print("AD: Version Check or Map check failed - cannot import");
		else
			AutoDrive:readFromXML(adXml);
			AutoDrive.requestedWaypoints = true;
			AutoDrive.requestedWaypointCount = 1;
			AutoDrive:MarkChanged();
		end;
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
	
	setXMLFloat(xmlFile, "AutoDrive.HudX", AutoDrive.HudX);
	setXMLFloat(xmlFile, "AutoDrive.HudY", AutoDrive.HudY);
	setXMLBool(xmlFile, "AutoDrive.HudShow", AutoDrive.Hud.showHud);	
	setXMLFloat(xmlFile, "AutoDrive.lastSetSpeed", AutoDrive.lastSetSpeed);

	for settingName, setting in pairs(AutoDrive.settings) do
		setXMLFloat(xmlFile, "AutoDrive." .. settingName, AutoDrive.settings[settingName].current);
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
		
	local markerNamesTable = {};
	local markerNames = "";
	
	local markerIDsTable = {};
	local markerIDs = "";
		
	for i,p in pairs(AutoDrive.mapWayPoints) do
	
		idFullTable[i] = p.id;
		xTable[i] = string.format("%.3f", p.x);
		yTable[i] = string.format("%.3f", p.y);
		zTable[i] = string.format("%.3f", p.z);
		
		
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
		
		
		local allMarkerIdsMatch = true;
		local lastMarker = nil;
		local firstMarker = nil;
		for i2,marker in pairs(p.marker) do
			if lastMarker == nil then
				lastMarker = marker;
				firstMarker = i2;
			else
				if lastMarker ~= marker then
					allMarkerIdsMatch = false;
				end;
			end;
		end;

		if allMarkerIdsMatch == true then
			if p.marker[firstMarker] ~= nil then
				markerIDsTable[i] = "=," .. p.marker[firstMarker];
			end;
		else
			local markerCounter = 1;
			local innerMarkerNamesTable = {};
			local innerMarkerIDsTable = {};
			for markerIndex, marker in pairs(AutoDrive.mapMarker) do
				innerMarkerIDsTable[markerCounter] = p.marker[marker.name];
				markerCounter = markerCounter + 1;
			end;
			markerIDsTable[i] = table.concat(innerMarkerIDsTable, ",");		
		end;		
	end;
		
	if idFullTable[1] ~= nil then					
		setXMLString(xmlFile, "AutoDrive." .. AutoDrive.loadedMap .. ".waypoints.id" , table.concat(idFullTable, ",") );
		setXMLString(xmlFile, "AutoDrive." .. AutoDrive.loadedMap .. ".waypoints.x" , table.concat(xTable, ","));
		setXMLString(xmlFile, "AutoDrive." .. AutoDrive.loadedMap .. ".waypoints.y" , table.concat(yTable, ","));
		setXMLString(xmlFile, "AutoDrive." .. AutoDrive.loadedMap .. ".waypoints.z" , table.concat(zTable, ","));
		setXMLString(xmlFile, "AutoDrive." .. AutoDrive.loadedMap .. ".waypoints.out" , table.concat(outTable, ";"));
		setXMLString(xmlFile, "AutoDrive." .. AutoDrive.loadedMap .. ".waypoints.incoming" , table.concat(incomingTable, ";") );
		if markerIDsTable[1] ~= nil then
			setXMLString(xmlFile, "AutoDrive." .. AutoDrive.loadedMap .. ".waypoints.markerID" , table.concat(markerIDsTable, ";"));
		end;
	end;
		
	for i in pairs(AutoDrive.mapMarker) do
		setXMLFloat(xmlFile, "AutoDrive." .. AutoDrive.loadedMap .. ".mapmarker.mm".. i ..".id", AutoDrive.mapMarker[i].id);
		setXMLString(xmlFile, "AutoDrive." .. AutoDrive.loadedMap .. ".mapmarker.mm".. i ..".name", AutoDrive.mapMarker[i].name);		
	end;
	
	saveXMLFile(xmlFile);
end;

function AutoDrive:tableEntriesAreEqual(list)
	local match = true;
	local toCompare = nil;

	for _,element in pairs(list) do
		if toCompare == nil then
			toCompare = element;
		else
			if toCompare ~= element then
				match = false;
			end;
		end;	
	end;

	return match;
end;
