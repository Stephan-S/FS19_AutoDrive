function AutoDrive.loadStoredXML()
	if g_server == nil then
		return
	end

	local xmlFile = AutoDrive.getXMLFile()

	--AutoDrive.currentVersion = AutoDrive.semanticVersionToValue(AutoDrive.version)
	--AutoDrive.versionUpdate = false
	AutoDrive.versionUpdateCancelsSettingsLoad = false

	if fileExists(xmlFile) then
		g_logManager:devInfo("[AutoDrive] Loading xml file from " .. xmlFile)
		AutoDrive.adXml = loadXMLFile("AutoDrive_XML", xmlFile)
		--[[
		local versionString = getXMLString(AutoDrive.adXml, "AutoDrive.version")
		if versionString ~= nil then
			AutoDrive.savedVersion = AutoDrive.semanticVersionToValue(versionString)

			if AutoDrive.savedVersion < AutoDrive.currentVersion then
				AutoDrive.versionUpdate = true
			end

			if AutoDrive.versionUpdate and AutoDrive.currentVersion ~= nil and AutoDrive.currentVersion == 1100 then
				--Dont read settings from config file - we will create a small pop up menu instead to inform users that the default values have changed and were thus reloaded
				AutoDrive.versionUpdateCancelsSettingsLoad = true
			end
		end
		--]]
		local MapCheck = hasXMLProperty(AutoDrive.adXml, "AutoDrive." .. AutoDrive.loadedMap)
		if MapCheck == false then --versionString == nil or
			g_logManager:devWarning("[AutoDrive] Map Check (%s) failed", MapCheck == false)
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
		local xmlId = loadXMLFile("AutoDrive_XML_temp", initConfFile)
		AutoDrive.readFromXML(xmlId)
		delete(xmlId)
	else
		g_logManager:devWarning("[AutoDrive] Can't load init config from " .. initConfFile)
		-- Loading custom init config from mod map
		initConfFile = g_currentMission.missionInfo.map.baseDirectory .. "AutoDrive_" .. AutoDrive.loadedMap .. "_init_config.xml"
		if fileExists(initConfFile) then
			g_logManager:devInfo("[AutoDrive] Loading init config from " .. initConfFile)
			local xmlId = loadXMLFile("AutoDrive_XML_temp", initConfFile)
			AutoDrive.readFromXML(xmlId)
			delete(xmlId)
		else
			g_logManager:devWarning("[AutoDrive] Can't load init config from " .. initConfFile)
		end
	end

	ADGraphManager:markChanges()
	g_logManager:devInfo("[AutoDrive] Saving xml file to " .. xmlFile)
	if createNewXML then
		AutoDrive.adXml = createXMLFile("AutoDrive_XML", xmlFile, "AutoDrive")
		saveXMLFile(AutoDrive.adXml)
	end
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

	AutoDrive.HudX = getXMLFloat(xmlFile, "AutoDrive.HudX")
	AutoDrive.HudY = getXMLFloat(xmlFile, "AutoDrive.HudY")
	AutoDrive.showingHud = getXMLBool(xmlFile, "AutoDrive.HudShow")

	AutoDrive.currentDebugChannelMask = getXMLInt(xmlFile, "AutoDrive.currentDebugChannelMask") or 0

	if not AutoDrive.versionUpdateCancelsSettingsLoad then
		for settingName, _ in pairs(AutoDrive.settings) do
			local value = getXMLFloat(xmlFile, "AutoDrive." .. settingName)
			if value ~= nil then
				AutoDrive.settings[settingName].current = value
			end
		end

		for feature, _ in pairs(AutoDrive.experimentalFeatures) do
			AutoDrive.experimentalFeatures[feature] = Utils.getNoNil(getXMLBool(xmlFile, "AutoDrive.experimentalFeatures." .. feature .. "#enabled"), AutoDrive.experimentalFeatures[feature])
		end
	end

	local mapMarker = {}
	local mapMarkerCounter = 1
	mapMarker.name = getXMLString(xmlFile, "AutoDrive." .. AutoDrive.loadedMap .. ".mapmarker.mm" .. mapMarkerCounter .. ".name")
	mapMarker.group = getXMLString(xmlFile, "AutoDrive." .. AutoDrive.loadedMap .. ".mapmarker.mm" .. mapMarkerCounter .. ".group")
	mapMarker.markerIndex = mapMarkerCounter
	if mapMarker.group == nil then
		mapMarker.group = "All"
	end
	if ADGraphManager:getGroupByName(mapMarker.group) == nil then
		ADGraphManager:addGroup(mapMarker.group)
	end

	ADGraphManager:resetMapMarkers()

	while mapMarker.name ~= nil do
		mapMarker.id = getXMLFloat(xmlFile, "AutoDrive." .. AutoDrive.loadedMap .. ".mapmarker.mm" .. mapMarkerCounter .. ".id")
		mapMarker.markerIndex = mapMarkerCounter

		ADGraphManager:setMapMarker(mapMarker)

		mapMarker = nil
		mapMarker = {}
		mapMarkerCounter = mapMarkerCounter + 1
		mapMarker.name = getXMLString(xmlFile, "AutoDrive." .. AutoDrive.loadedMap .. ".mapmarker.mm" .. mapMarkerCounter .. ".name")
		mapMarker.group = getXMLString(xmlFile, "AutoDrive." .. AutoDrive.loadedMap .. ".mapmarker.mm" .. mapMarkerCounter .. ".group")
		if mapMarker.group == nil then
			mapMarker.group = "All"
		end
		if ADGraphManager:getGroupByName(mapMarker.group) == nil then
			ADGraphManager:addGroup(mapMarker.group)
		end
	end

	local idString = getXMLString(xmlFile, "AutoDrive." .. AutoDrive.loadedMap .. ".waypoints.id")

	--maybe map was opened and saved, but no waypoints recorded with AutoDrive!
	if idString == nil then
		return
	end

	ADGraphManager:resetWayPoints()

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

			wp.x = tonumber(xTable[i])
			wp.y = tonumber(yTable[i])
			wp.z = tonumber(zTable[i])

			ADGraphManager:setWayPoint(wp)
		end
	end

	if ADGraphManager:getWayPointById(wp_counter) ~= nil then
		g_logManager:devInfo("[AutoDrive] Loaded %s waypoints", wp_counter)
	end

	for markerIndex, marker in pairs(ADGraphManager:getMapMarkers()) do
		if ADGraphManager:getWayPointById(marker.id) == nil then
			g_logManager:devInfo("[AutoDrive] mapMarker[" .. markerIndex .. "] : " .. marker.name .. " points to a non existing waypoint! Please repair your config file!")
		end
	end
end

function AutoDrive.saveToXML(xmlFile)
	if xmlFile == nil then
		g_logManager:devInfo("[AutoDrive] No valid xml file for saving the configuration")
		return
	end

	setXMLString(xmlFile, "AutoDrive.version", AutoDrive.version)

	setXMLFloat(xmlFile, "AutoDrive.HudX", AutoDrive.HudX)
	setXMLFloat(xmlFile, "AutoDrive.HudY", AutoDrive.HudY)
	setXMLBool(xmlFile, "AutoDrive.HudShow", AutoDrive.Hud.showHud)
	--setXMLFloat(xmlFile, "AutoDrive.lastSetSpeed", AutoDrive.lastSetSpeed)

	setXMLInt(xmlFile, "AutoDrive.currentDebugChannelMask", AutoDrive.currentDebugChannelMask)

	for settingName, _ in pairs(AutoDrive.settings) do
		setXMLFloat(xmlFile, "AutoDrive." .. settingName, AutoDrive.settings[settingName].current)
	end

	for feature, enabled in pairs(AutoDrive.experimentalFeatures) do
		setXMLBool(xmlFile, "AutoDrive.experimentalFeatures." .. feature .. "#enabled", enabled)
	end

	removeXMLProperty(AutoDrive.adXml, "AutoDrive." .. AutoDrive.loadedMap .. ".waypoints.markerID")

	local idFullTable = {}

	local xTable = {}

	local yTable = {}

	local zTable = {}

	local outTable = {}

	local incomingTable = {}

	for i, p in pairs(ADGraphManager:getWayPoints()) do
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
	end

	if idFullTable[1] ~= nil then
		setXMLString(xmlFile, "AutoDrive." .. AutoDrive.loadedMap .. ".waypoints.id", table.concat(idFullTable, ","))
		setXMLString(xmlFile, "AutoDrive." .. AutoDrive.loadedMap .. ".waypoints.x", table.concat(xTable, ","))
		setXMLString(xmlFile, "AutoDrive." .. AutoDrive.loadedMap .. ".waypoints.y", table.concat(yTable, ","))
		setXMLString(xmlFile, "AutoDrive." .. AutoDrive.loadedMap .. ".waypoints.z", table.concat(zTable, ","))
		setXMLString(xmlFile, "AutoDrive." .. AutoDrive.loadedMap .. ".waypoints.out", table.concat(outTable, ";"))
		setXMLString(xmlFile, "AutoDrive." .. AutoDrive.loadedMap .. ".waypoints.incoming", table.concat(incomingTable, ";"))
	end

	for i in pairs(ADGraphManager:getMapMarkers()) do
		setXMLFloat(xmlFile, "AutoDrive." .. AutoDrive.loadedMap .. ".mapmarker.mm" .. i .. ".id", ADGraphManager:getMapMarkerById(i).id)
		setXMLString(xmlFile, "AutoDrive." .. AutoDrive.loadedMap .. ".mapmarker.mm" .. i .. ".name", ADGraphManager:getMapMarkerById(i).name)
		setXMLString(xmlFile, "AutoDrive." .. AutoDrive.loadedMap .. ".mapmarker.mm" .. i .. ".group", ADGraphManager:getMapMarkerById(i).group)
	end

	saveXMLFile(xmlFile)
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
					AutoDrive.usersData[uniqueId].wideHUD = Utils.getNoNil(getXMLInt(xmlFile, uKey .. "#wideHUD"), AutoDrive.settings.wideHUD.default)
					AutoDrive.usersData[uniqueId].notifications = Utils.getNoNil(getXMLInt(xmlFile, uKey .. "#notifications"), AutoDrive.settings.notifications.default)
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
		setXMLInt(xmlFile, uKey .. "#wideHUD", userData.wideHUD)
		setXMLInt(xmlFile, uKey .. "#notifications", userData.notifications)
		uIndex = uIndex + 1
	end
	saveXMLFile(xmlFile)
	delete(xmlFile)
end

function AutoDrive.writeGraphToXml(xmlId, rootNode, waypoints, markers, groups)
	-- writing waypoints
	removeXMLProperty(xmlId, rootNode .. ".waypoints")
	do
		local key = string.format("%s.waypoints", rootNode)
		setXMLInt(xmlId, key .. "#c", #waypoints)

		local xt = {}
		local yt = {}
		local zt = {}
		local ot = {}
		local it = {}

		-- localization for better performances
		local frmt = string.format
		local cnl = table.concatNil

		for i, w in pairs(waypoints) do
			xt[i] = frmt("%.2f", w.x)
			yt[i] = frmt("%.2f", w.y)
			zt[i] = frmt("%.2f", w.z)
			ot[i] = cnl(w.out, ",") or "-1"
			it[i] = cnl(w.incoming, ",") or "-1"
		end

		setXMLString(xmlId, key .. ".x", table.concat(xt, ";"))
		setXMLString(xmlId, key .. ".y", table.concat(yt, ";"))
		setXMLString(xmlId, key .. ".z", table.concat(zt, ";"))
		setXMLString(xmlId, key .. ".out", table.concat(ot, ";"))
		setXMLString(xmlId, key .. ".in", table.concat(it, ";"))
	end

	-- writing markers
	removeXMLProperty(xmlId, rootNode .. ".markers")
	for i, m in pairs(markers) do
		local key = string.format("%s.markers.m(%d)", rootNode, i - 1)
		setXMLInt(xmlId, key .. "#i", m.id)
		setXMLString(xmlId, key .. "#n", m.name)
		setXMLString(xmlId, key .. "#g", m.group)
	end

	-- writing groups
	removeXMLProperty(xmlId, rootNode .. ".groups")
	do
		local i = 0
		for name, _ in pairs(groups) do
			local key = string.format("%s.groups.g(%d)", rootNode, i)
			setXMLString(xmlId, key .. "#n", name)
			i = i + 1
		end
	end
end

function AutoDrive.readGraphFromXml(xmlId, rootNode, waypoints, markers, groups)
	-- reading waypoints
	do
		local key = string.format("%s.waypoints", rootNode)
		local waypointsCount = getXMLInt(xmlId, key .. "#c")
		local xt = getXMLString(xmlId, key .. ".x"):split(";")
		local yt = getXMLString(xmlId, key .. ".y"):split(";")
		local zt = getXMLString(xmlId, key .. ".z"):split(";")
		local ot = getXMLString(xmlId, key .. ".out"):split(";")
		local it = getXMLString(xmlId, key .. ".in"):split(";")

		-- localization for better performances
		local tnum = tonumber
		local tbin = table.insert
		local stsp = string.split

		for i = 1, waypointsCount do
			local wp = {id = i, x = tnum(xt[i]), y = tnum(yt[i]), z = tnum(zt[i]), out = {}, incoming = {}}
			if ot[i] ~= "-1" then
				for _, out in pairs(stsp(ot[i], ",")) do
					tbin(wp.out, tnum(out))
				end
			end
			if it[i] ~= "-1" then
				for _, incoming in pairs(stsp(it[i], ",")) do
					tbin(wp.incoming, tnum(incoming))
				end
			end
			waypoints[i] = wp
			i = i + 1
		end
	end

	-- reading markers
	do
		local i = 0
		while true do
			local key = string.format("%s.markers.m(%d)", rootNode, i)
			if not hasXMLProperty(xmlId, key) then
				break
			end
			local id = getXMLInt(xmlId, key .. "#i")
			local name = getXMLString(xmlId, key .. "#n")
			local group = getXMLString(xmlId, key .. "#g")

			i = i + 1
			markers[i] = {id = id, name = name, group = group, markerIndex = i}
		end
	end

	-- reading groups
	do
		local i = 0
		while true do
			local key = string.format("%s.groups.g(%d)", rootNode, i)
			if not hasXMLProperty(xmlId, key) then
				break
			end
			local groupName = getXMLString(xmlId, key .. "#n")
			i = i + 1
			groups[groupName] = i
		end
	end
end
