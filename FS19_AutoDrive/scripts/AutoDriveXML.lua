function AutoDrive.loadStoredXML()
	if g_server == nil then
		return
	end

	local xmlFile = AutoDrive.getXMLFile()

	if fileExists(xmlFile) then
		g_logManager:devInfo("[AutoDrive] Loading xml file from " .. xmlFile)
		AutoDrive.adXml = loadXMLFile("AutoDrive_XML", xmlFile)

		local VersionCheck = getXMLString(AutoDrive.adXml, "AutoDrive.version")
		if VersionCheck ~= AutoDrive.version then
			AutoDrive.versionUpdate = true
		end
		local MapCheck = hasXMLProperty(AutoDrive.adXml, "AutoDrive." .. AutoDrive.loadedMap)
		if VersionCheck == nil or MapCheck == false then
			g_logManager:devWarning("[AutoDrive] Version Check (%s) or Map Check (%s) failed", VersionCheck == nil, MapCheck == false)
			AutoDrive.loadInitConfig(xmlFile, false)
		else
			AutoDrive.readFromXML(AutoDrive.adXml)
		end
	else
		AutoDrive.loadInitConfig(xmlFile)
	end
end

function AutoDrive.loadInitConfig(xmlFile, createNewXML)
	createNewXML = createNewXML or true

	local initConfFile = AutoDrive.directory .. "AutoDrive_" .. AutoDrive.loadedMap .. "_init_config.xml"

	if fileExists(initConfFile) then
		g_logManager:devInfo("[AutoDrive] Loading init config from " .. initConfFile)
		AutoDrive.readFromXML(loadXMLFile("AutoDrive_XML_temp", initConfFile))
	else
		g_logManager:devWarning("[AutoDrive] Can't load init config from " .. initConfFile)
		-- Loading custom init config from mod map
		initConfFile = g_currentMission.missionInfo.map.baseDirectory .. "AutoDrive_" .. AutoDrive.loadedMap .. "_init_config.xml"
		if fileExists(initConfFile) then
			g_logManager:devInfo("[AutoDrive] Loading init config from " .. initConfFile)
			AutoDrive.readFromXML(loadXMLFile("AutoDrive_XML_temp", initConfFile))
		else
			g_logManager:devWarning("[AutoDrive] Can't load init config from " .. initConfFile)
		end
	end

	AutoDrive.MarkChanged()
	g_logManager:devInfo("[AutoDrive] Saving xml file to " .. xmlFile)
	if createNewXML then
		AutoDrive.adXml = createXMLFile("AutoDrive_XML", xmlFile, "AutoDrive")
		saveXMLFile(AutoDrive.adXml)
	end
	--AutoDrive.saveToXML(AutoDrive.adXml)
end

function AutoDrive.getXMLFile()
	local path = g_currentMission.missionInfo.savegameDirectory
	if path ~= nil then
		return path .. "/AutoDrive_" .. AutoDrive.loadedMap .. "_config.xml"
	else
		return getUserProfileAppPath() .. "savegame" .. g_currentMission.missionInfo.savegameIndex .. "/AutoDrive_" .. AutoDrive.loadedMap .. "_config.xml"
	end
end

function AutoDrive.readFromXML(xmlFile)
	if xmlFile == nil then
		return
	end

	if AutoDrive.loadedMap == nil then
		g_logManager:error("[AutoDrive] Could not load your map name")
		return
	end

	local recalculate = true
	local recalculateString = getXMLString(xmlFile, "AutoDrive.Recalculation")
	if recalculateString == "true" then
		recalculate = true
		AutoDrive.MarkChanged()
	end
	if recalculateString == "false" then
		recalculate = false
	end
	if recalculateString == nil then
		g_logManager:devInfo("[AutoDrive] Starting a new configuration file")
		return
	end

	AutoDrive.HudX = getXMLFloat(xmlFile, "AutoDrive.HudX")
	AutoDrive.HudY = getXMLFloat(xmlFile, "AutoDrive.HudY")
	AutoDrive.showingHud = getXMLBool(xmlFile, "AutoDrive.HudShow")
	--local lastSetSpeed = getXMLFloat(xmlFile, "AutoDrive.lastSetSpeed")
	--if lastSetSpeed ~= nil then
	--	AutoDrive.lastSetSpeed = lastSetSpeed
	--end

	for settingName, _ in pairs(AutoDrive.settings) do
		local value = getXMLFloat(xmlFile, "AutoDrive." .. settingName)
		if value ~= nil then
			AutoDrive.settings[settingName].current = value
		end
	end

	for feature, _ in pairs(AutoDrive.experimentalFeatures) do
		AutoDrive.experimentalFeatures[feature] = Utils.getNoNil(getXMLBool(xmlFile, "AutoDrive.experimentalFeatures." .. feature .. "#enabled"), AutoDrive.experimentalFeatures[feature])
	end

	local mapMarker = {}
	local mapMarkerCounter = 1
	mapMarker.name = getXMLString(xmlFile, "AutoDrive." .. AutoDrive.loadedMap .. ".mapmarker.mm" .. mapMarkerCounter .. ".name")
	mapMarker.group = getXMLString(xmlFile, "AutoDrive." .. AutoDrive.loadedMap .. ".mapmarker.mm" .. mapMarkerCounter .. ".group")
	if mapMarker.group == nil then
		mapMarker.group = "All"
	end
	if AutoDrive.groups[mapMarker.group] == nil then
		AutoDrive.groupCounter = AutoDrive.groupCounter + 1
		AutoDrive.groups[mapMarker.group] = AutoDrive.groupCounter
	end

	AutoDrive.mapMarker = {}

	while mapMarker.name ~= nil do
		--g_logManager:devInfo("[AutoDrive] Loading map marker: " .. mapMarker.name);
		mapMarker.id = getXMLFloat(xmlFile, "AutoDrive." .. AutoDrive.loadedMap .. ".mapmarker.mm" .. mapMarkerCounter .. ".id")

		AutoDrive.mapMarker[mapMarkerCounter] = mapMarker

		mapMarker = nil
		mapMarker = {}
		mapMarkerCounter = mapMarkerCounter + 1
		AutoDrive.mapMarkerCounter = AutoDrive.mapMarkerCounter + 1
		mapMarker.name = getXMLString(xmlFile, "AutoDrive." .. AutoDrive.loadedMap .. ".mapmarker.mm" .. mapMarkerCounter .. ".name")
		mapMarker.group = getXMLString(xmlFile, "AutoDrive." .. AutoDrive.loadedMap .. ".mapmarker.mm" .. mapMarkerCounter .. ".group")
		if mapMarker.group == nil then
			mapMarker.group = "All"
		end
		if AutoDrive.groups[mapMarker.group] == nil then
			AutoDrive.groupCounter = AutoDrive.groupCounter + 1
			AutoDrive.groups[mapMarker.group] = AutoDrive.groupCounter
		end
	end

	local idString = getXMLString(xmlFile, "AutoDrive." .. AutoDrive.loadedMap .. ".waypoints.id")

	--maybe map was opened and saved, but no waypoints recorded with AutoDrive!
	if idString == nil then
		return
	end

	AutoDrive.mapWayPoints = {}

	local idTable = idString:split(",")
	local xString = getXMLString(xmlFile, "AutoDrive." .. AutoDrive.loadedMap .. ".waypoints.x")
	local xTable = xString:split(",")
	local yString = getXMLString(xmlFile, "AutoDrive." .. AutoDrive.loadedMap .. ".waypoints.y")
	local yTable = yString:split(",")
	local zString = getXMLString(xmlFile, "AutoDrive." .. AutoDrive.loadedMap .. ".waypoints.z")
	local zTable = zString:split(",")

	local outString = getXMLString(xmlFile, "AutoDrive." .. AutoDrive.loadedMap .. ".waypoints.out")
	local outTable = outString:split(";")
	local outSplitted = {}
	for i, outer in pairs(outTable) do
		local out = outer:split(",")
		outSplitted[i] = out
		if out == nil then
			outSplitted[i] = {outer}
		end
	end

	local incomingString = getXMLString(xmlFile, "AutoDrive." .. AutoDrive.loadedMap .. ".waypoints.incoming")
	local incomingTable = incomingString:split(";")
	local incomingSplitted = {}
	for i, outer in pairs(incomingTable) do
		local incoming = outer:split(",")
		incomingSplitted[i] = incoming
		if incoming == nil then
			incomingSplitted[i] = {outer}
		end
	end

	local markerIDString = getXMLString(xmlFile, "AutoDrive." .. AutoDrive.loadedMap .. ".waypoints.markerID")
	local markerIDSplitted = {}
	if markerIDString ~= nil then
		local markerIDTable = markerIDString:split(";")
		for i, outer in pairs(markerIDTable) do
			local markerID = outer:split(",")
			markerIDSplitted[i] = markerID
			if markerID == nil then
				markerIDSplitted[i] = {outer}
			end
		end
	end

	local markerNamesString = getXMLString(xmlFile, "AutoDrive." .. AutoDrive.loadedMap .. ".waypoints.markerNames")
	local markerNamesSplitted = nil
	if markerNamesString ~= nil then
		markerNamesSplitted = {}
		local markerNamesTable = markerNamesString:split(";")
		for i, outer in pairs(markerNamesTable) do
			local markerNames = outer:split(",")
			markerNamesSplitted[i] = markerNames
			if markerNames == nil then
				markerNamesSplitted[i] = {outer}
			end
		end
	end

	local wp_counter = 0
	for i, id in pairs(idTable) do
		if id ~= "" then
			wp_counter = wp_counter + 1
			local wp = {}
			wp["id"] = tonumber(id)
			wp["out"] = {}
			if outSplitted[i] ~= nil then
				for i2, outStr in pairs(outSplitted[i]) do
					local number = tonumber(outStr)
					if number ~= -1 then
						wp["out"][i2] = tonumber(outStr)
					end
				end
			end

			wp["incoming"] = {}
			local incoming_counter = 1
			if incomingSplitted[i] ~= nil then
				for _, incomingID in pairs(incomingSplitted[i]) do
					if incomingID ~= "" then
						local number = tonumber(incomingID)
						if number ~= -1 then
							wp["incoming"][incoming_counter] = tonumber(incomingID)
						end
					end
					incoming_counter = incoming_counter + 1
				end
			end

			wp["marker"] = {}
			if markerNamesSplitted ~= nil then
				if markerNamesSplitted[i] ~= nil then
					for i2, markerName in pairs(markerNamesSplitted[i]) do
						if markerName ~= "" then
							wp.marker[markerName] = tonumber(markerIDSplitted[i][i2])
						end
					end
				end
			else
				if markerIDSplitted[i] ~= nil then
					if markerIDSplitted[i][1] == "=" then
						for _, marker in pairs(AutoDrive.mapMarker) do
							wp.marker[marker.name] = tonumber(markerIDSplitted[i][2])
						end
					else
						for markerIndex, marker in pairs(AutoDrive.mapMarker) do
							wp.marker[marker.name] = tonumber(markerIDSplitted[i][markerIndex])
						end
					end
				else
					for _, marker in pairs(AutoDrive.mapMarker) do
						wp.marker[marker.name] = -1
					end
				end
			end

			wp.x = tonumber(xTable[i])
			wp.y = tonumber(yTable[i])
			wp.z = tonumber(zTable[i])

			AutoDrive.mapWayPoints[wp_counter] = wp
		end
	end

	if AutoDrive.mapWayPoints[wp_counter] ~= nil then
		g_logManager:devInfo("[AutoDrive] Loaded %s waypoints", wp_counter)
		AutoDrive.mapWayPointsCounter = wp_counter
	else
		AutoDrive.mapWayPointsCounter = 0
	end

	for markerIndex, marker in pairs(AutoDrive.mapMarker) do
		if AutoDrive.mapWayPoints[marker.id] ~= nil then
			local node = createTransformGroup(marker.name)
			setTranslation(node, AutoDrive.mapWayPoints[marker.id].x, AutoDrive.mapWayPoints[marker.id].y + 4, AutoDrive.mapWayPoints[marker.id].z)
			marker.node = node
		else
			g_logManager:devInfo("[AutoDrive] mapMarker[" .. markerIndex .. "] : " .. marker.name .. " points to a non existing waypoint! Please repair your config file!")
		end
	end

	recalculate = true
	recalculateString = getXMLString(xmlFile, "AutoDrive.Recalculation")
	if recalculateString == "true" then
		recalculate = true
	end
	if recalculateString == "false" then
		recalculate = false
	end
	AutoDrive.handledRecalculation = not recalculate
end

function AutoDrive.saveToXML(xmlFile)
	if xmlFile == nil then
		g_logManager:devInfo("[AutoDrive] No valid xml file for saving the configuration")
		return
	end

	setXMLString(xmlFile, "AutoDrive.version", AutoDrive.version)
	if AutoDrive.handledRecalculation ~= true then
		setXMLString(xmlFile, "AutoDrive.Recalculation", "true")
		g_logManager:devInfo("[AutoDrive] Set to recalculating routes")
	else
		setXMLString(xmlFile, "AutoDrive.Recalculation", "false")
		g_logManager:devInfo("[AutoDrive] Set to not recalculating routes")
	end

	setXMLFloat(xmlFile, "AutoDrive.HudX", AutoDrive.HudX)
	setXMLFloat(xmlFile, "AutoDrive.HudY", AutoDrive.HudY)
	setXMLBool(xmlFile, "AutoDrive.HudShow", AutoDrive.Hud.showHud)
	--setXMLFloat(xmlFile, "AutoDrive.lastSetSpeed", AutoDrive.lastSetSpeed)

	for settingName, _ in pairs(AutoDrive.settings) do
		setXMLFloat(xmlFile, "AutoDrive." .. settingName, AutoDrive.settings[settingName].current)
	end

	for feature, enabled in pairs(AutoDrive.experimentalFeatures) do
		setXMLBool(xmlFile, "AutoDrive.experimentalFeatures." .. feature .. "#enabled", enabled)
	end

	local idFullTable = {}
	--local idString = ""

	local xTable = {}
	--local xString = ""

	local yTable = {}
	--local yString = ""

	local zTable = {}
	--local zString = ""

	local outTable = {}
	--local outString = ""

	local incomingTable = {}
	--local incomingString = ""

	--local markerNamesTable = {}
	--local markerNames = ""

	local markerIDsTable = {}
	--local markerIDs = ""

	for i, p in pairs(AutoDrive.mapWayPoints) do
		idFullTable[i] = p.id
		xTable[i] = string.format("%.3f", p.x)
		yTable[i] = string.format("%.3f", p.y)
		zTable[i] = string.format("%.3f", p.z)

		outTable[i] = table.concat(p.out, ",")
		if outTable[i] == nil or outTable[i] == "" then
			outTable[i] = "-1"
		end

		incomingTable[i] = table.concat(p.incoming, ",")
		if incomingTable[i] == nil or incomingTable[i] == "" then
			incomingTable[i] = "-1"
		end

		local allMarkerIdsMatch = true
		local lastMarker = nil
		local firstMarker = nil
		for i2, marker in pairs(p.marker) do
			if lastMarker == nil then
				lastMarker = marker
				firstMarker = i2
			else
				if lastMarker ~= marker then
					allMarkerIdsMatch = false
				end
			end
		end

		if allMarkerIdsMatch == true then
			if p.marker[firstMarker] ~= nil then
				markerIDsTable[i] = "=," .. p.marker[firstMarker]
			end
		else
			local markerCounter = 1
			--local innerMarkerNamesTable = {}
			local innerMarkerIDsTable = {}
			for _, marker in pairs(AutoDrive.mapMarker) do
				innerMarkerIDsTable[markerCounter] = p.marker[marker.name]
				markerCounter = markerCounter + 1
			end
			markerIDsTable[i] = table.concat(innerMarkerIDsTable, ",")
		end
	end

	if idFullTable[1] ~= nil then
		setXMLString(xmlFile, "AutoDrive." .. AutoDrive.loadedMap .. ".waypoints.id", table.concat(idFullTable, ","))
		setXMLString(xmlFile, "AutoDrive." .. AutoDrive.loadedMap .. ".waypoints.x", table.concat(xTable, ","))
		setXMLString(xmlFile, "AutoDrive." .. AutoDrive.loadedMap .. ".waypoints.y", table.concat(yTable, ","))
		setXMLString(xmlFile, "AutoDrive." .. AutoDrive.loadedMap .. ".waypoints.z", table.concat(zTable, ","))
		setXMLString(xmlFile, "AutoDrive." .. AutoDrive.loadedMap .. ".waypoints.out", table.concat(outTable, ";"))
		setXMLString(xmlFile, "AutoDrive." .. AutoDrive.loadedMap .. ".waypoints.incoming", table.concat(incomingTable, ";"))
		if markerIDsTable[1] ~= nil then
			setXMLString(xmlFile, "AutoDrive." .. AutoDrive.loadedMap .. ".waypoints.markerID", table.concat(markerIDsTable, ";"))
		end
	end

	for i in pairs(AutoDrive.mapMarker) do
		setXMLFloat(xmlFile, "AutoDrive." .. AutoDrive.loadedMap .. ".mapmarker.mm" .. i .. ".id", AutoDrive.mapMarker[i].id)
		setXMLString(xmlFile, "AutoDrive." .. AutoDrive.loadedMap .. ".mapmarker.mm" .. i .. ".name", AutoDrive.mapMarker[i].name)
		setXMLString(xmlFile, "AutoDrive." .. AutoDrive.loadedMap .. ".mapmarker.mm" .. i .. ".group", AutoDrive.mapMarker[i].group)
	end

	saveXMLFile(xmlFile)
end

function AutoDrive.exportRoutes()
	local path = getUserProfileAppPath()
	local file = path .. "FS19_AutoDrive_Export/AutoDrive_" .. AutoDrive.loadedMap .. "_config.xml"

	createFolder(path .. "FS19_AutoDrive_Export")
	createFolder(path .. "FS19_AutoDrive_Import")

	g_logManager:devInfo("[AutoDrive] Creating xml file at " .. file)
	local adXml = createXMLFile("AutoDrive_export_XML", file, "AutoDrive")
	saveXMLFile(adXml)
	AutoDrive.saveToXML(adXml)
	g_logManager:devInfo("[AutoDrive] Finished exporting routes")
end

function AutoDrive.importRoutes()
	local path = getUserProfileAppPath()
	local file = path .. "FS19_AutoDrive_Import/AutoDrive_" .. AutoDrive.loadedMap .. "_config.xml"

	createFolder(path .. "FS19_AutoDrive_Import")

	g_logManager:devInfo("[AutoDrive] Trying to load xml file from " .. file)
	if fileExists(file) then
		g_logManager:devInfo("[AutoDrive] Loading xml file from " .. file)
		local adXml = loadXMLFile("AutoDrive_XML", file)

		local VersionCheck = getXMLString(adXml, "AutoDrive.version")
		local MapCheck = hasXMLProperty(adXml, "AutoDrive." .. AutoDrive.loadedMap)
		if VersionCheck == nil or MapCheck == false then
			g_logManager:devInfo("[AutoDrive] Version Check or Map check failed - cannot import")
		else
			AutoDrive.readFromXML(adXml)
			AutoDrive.requestedWaypoints = true
			AutoDrive.requestedWaypointCount = 1
			AutoDrive.MarkChanged()
		end
	end
end

function AutoDrive.tableEntriesAreEqual(list)
	local match = true
	local toCompare = nil

	for _, element in pairs(list) do
		if toCompare == nil then
			toCompare = element
		else
			if toCompare ~= element then
				match = false
			end
		end
	end

	return match
end

function AutoDrive.loadUsersData()
	local file = tostring(g_currentMission.missionInfo.savegameDirectory) .. "/AutoDriveUsersData.xml"
	if fileExists(file) then
		local xmlFile = loadXMLFile("AutoDriveUsersData_XML_temp", file)
		if xmlFile ~= nil then
			local uIndex = 0
			while true do
				local uKey = string.format("AutoDriveUsersData.users.user(%d)", uIndex)
				if not hasXMLProperty(xmlFile, uKey) then
					break
				end
				local uniqueId = getXMLString(xmlFile, uKey .. "#uniqueId")
				if uniqueId ~= nil and uniqueId ~= "" then
					AutoDrive.usersData[uniqueId] = {}
					AutoDrive.usersData[uniqueId].hudX = Utils.getNoNil(getXMLFloat(xmlFile, uKey .. "#hudX"), 0.5)
					AutoDrive.usersData[uniqueId].hudY = Utils.getNoNil(getXMLFloat(xmlFile, uKey .. "#hudY"), 0.5)
					AutoDrive.usersData[uniqueId].guiScale = Utils.getNoNil(getXMLInt(xmlFile, uKey .. "#guiScale"), AutoDrive.settings.guiScale.default)
				end
				uIndex = uIndex + 1
			end
		end
		delete(xmlFile)
	end
end

function AutoDrive.saveUsersData()
	local file = g_currentMission.missionInfo.savegameDirectory .. "/AutoDriveUsersData.xml"
	local xmlFile = createXMLFile("AutoDriveUsersData_XML_temp", file, "AutoDriveUsersData")
	local uIndex = 0
	for uniqueId, userData in pairs(AutoDrive.usersData) do
		local uKey = string.format("AutoDriveUsersData.users.user(%d)", uIndex)
		setXMLString(xmlFile, uKey .. "#uniqueId", uniqueId)
		setXMLFloat(xmlFile, uKey .. "#hudX", userData.hudX)
		setXMLFloat(xmlFile, uKey .. "#hudY", userData.hudY)
		setXMLInt(xmlFile, uKey .. "#guiScale", userData.guiScale)
		uIndex = uIndex + 1
	end
	saveXMLFile(xmlFile)
	delete(xmlFile)
end
