AutoDrive = {}
AutoDrive.version = "1.1.0.0"

AutoDrive.directory = g_currentModDirectory

g_autoDriveUIFilename = AutoDrive.directory .. "textures/GUI_Icons.dds"
g_autoDriveDebugUIFilename = AutoDrive.directory .. "textures/gui_debug_Icons.dds"

AutoDrive.experimentalFeatures = {}
AutoDrive.experimentalFeatures.smootherDriving = true
AutoDrive.experimentalFeatures.redLinePosition = false

AutoDrive.developmentControls = false

--AutoDrive.renderTime = 0

AutoDrive.configChanged = false

AutoDrive.actions = {
	{"ADToggleMouse", true, 1},
	{"ADToggleHud", true, 1},
	{"ADEnDisable", true, 1},
	{"ADSelectTarget", false, 0},
	{"ADSelectPreviousTarget", false, 0},
	{"ADSelectTargetUnload", false, 0},
	{"ADSelectPreviousTargetUnload", false, 0},
	{"ADActivateDebug", false, 0},
	{"ADDebugSelectNeighbor", false, 0},
	{"ADDebugChangeNeighbor", false, 0},
	{"ADDebugCreateConnection", false, 0},
	{"ADDebugCreateMapMarker", false, 0},
	{"ADDebugDeleteWayPoint", false, 0},
	{"ADDebugDeleteDestination", false, 3},
	{"ADSilomode", false, 0},
	{"ADOpenGUI", true, 2},
	{"ADCallDriver", false, 3},
	{"ADSelectNextFillType", false, 0},
	{"ADSelectPreviousFillType", false, 0},
	{"ADRecord", false, 0},
	{"AD_routes_manager", false, 0},
	{"ADGoToVehicle", false, 3},
	{"ADNameDriver", false, 0},
	{"ADRenameMapMarker", false, 0},
	{"ADSwapTargets", false, 0}
}

AutoDrive.drawHeight = 0.3
AutoDrive.drawDistance = getViewDistanceCoeff() * 50

AutoDrive.MODE_DRIVETO = 1
AutoDrive.MODE_PICKUPANDDELIVER = 2
AutoDrive.MODE_DELIVERTO = 3
AutoDrive.MODE_LOAD = 4
AutoDrive.MODE_UNLOAD = 5
AutoDrive.MODE_BGA = 6

AutoDrive.WAYPOINTS_PER_PACKET = 100
AutoDrive.SPEED_ON_FIELD = 100

AutoDrive.DC_NONE = 0
AutoDrive.DC_VEHICLEINFO = 1
AutoDrive.DC_COMBINEINFO = 2
AutoDrive.DC_TRAILERINFO = 4
AutoDrive.DC_DEVINFO = 8
AutoDrive.DC_PATHINFO = 16
AutoDrive.DC_SENSORINFO = 32
AutoDrive.DC_NETWORKINFO = 64
AutoDrive.DC_EXTERNALINTERFACEINFO = 128
AutoDrive.DC_RENDERINFO = 256
AutoDrive.DC_ALL = 65535

AutoDrive.currentDebugChannelMask = AutoDrive.DC_NONE

function AutoDrive:loadMap(name)
	source(Utils.getFilename("scripts/AutoDriveXML.lua", AutoDrive.directory))
	source(Utils.getFilename("scripts/AutoDriveSettings.lua", AutoDrive.directory))
	source(Utils.getFilename("scripts/AutoDriveExternalInterface.lua", AutoDrive.directory))
	source(Utils.getFilename("scripts/Sensors/AutoDriveVirtualSensors.lua", AutoDrive.directory))
	source(Utils.getFilename("scripts/Sensors/ADCollSensor.lua", AutoDrive.directory))
	source(Utils.getFilename("scripts/Sensors/ADFruitSensor.lua", AutoDrive.directory))
	source(Utils.getFilename("scripts/Sensors/ADFieldSensor.lua", AutoDrive.directory))
	source(Utils.getFilename("scripts/AutoDriveDijkstraLive.lua", AutoDrive.directory))
	source(Utils.getFilename("gui/AutoDriveGUI.lua", AutoDrive.directory))

	if g_server ~= nil then
		AutoDrive.AutoDriveSync = AutoDriveSync:new(g_server ~= nil, g_client ~= nil)
		AutoDrive.AutoDriveSync:register(false)
	end

	AutoDrive:loadGUI()

	g_logManager:devInfo("[AutoDrive] Map title: %s", g_currentMission.missionInfo.map.title)

	AutoDrive.loadedMap = g_currentMission.missionInfo.map.title
	AutoDrive.loadedMap = string.gsub(AutoDrive.loadedMap, " ", "_")
	AutoDrive.loadedMap = string.gsub(AutoDrive.loadedMap, "%.", "_")
	AutoDrive.loadedMap = string.gsub(AutoDrive.loadedMap, ",", "_")
	AutoDrive.loadedMap = string.gsub(AutoDrive.loadedMap, ":", "_")
	AutoDrive.loadedMap = string.gsub(AutoDrive.loadedMap, ";", "_")

	g_logManager:devInfo("[AutoDrive] Parsed map title: %s", AutoDrive.loadedMap)

	-- That's probably bad, but for the moment I can't find another way to know if development controls are enabled
	local gameXmlFilePath = getUserProfileAppPath() .. "game.xml"
	if fileExists(gameXmlFilePath) then
		local gameXmlFile = loadXMLFile("game_XML", gameXmlFilePath)
		if gameXmlFile ~= nil then
			if hasXMLProperty(gameXmlFile, "game.development.controls") then
				AutoDrive.developmentControls = Utils.getNoNil(getXMLBool(gameXmlFile, "game.development.controls"), AutoDrive.developmentControls)
			end
		end
	end

	AutoDrive.groups = {}
	AutoDrive.groups["All"] = 1
	AutoDrive.groupCounter = 1

	AutoDrive.pullDownListExpanded = 0
	AutoDrive.pullDownListDirection = 0

	AutoDrive.requestedWaypoints = false
	AutoDrive.requestedWaypointCount = 1
	AutoDrive.playerSendsMapToServer = false

	AutoDrive.showMouse = false
	AutoDrive.mouseWheelActive = false

	AutoDrive.waitingUnloadDrivers = {}
	AutoDrive.destinationListeners = {}

	AutoDrive.mapHotspotsBuffer = {}

	AutoDrive.requestWayPointTimer = 10000

	AutoDrive.loadStoredXML()

	if g_server ~= nil then
		AutoDrive.usersData = {}
		AutoDrive.loadUsersData()
		AutoDrive.Server = {}
		AutoDrive.Server.Users = {}
	else
		AutoDrive.highestIndex = 1
	end

	AutoDrive.Hud = AutoDriveHud:new()
	AutoDrive.Hud:loadHud()

	-- Save Configuration when saving savegame
	FSBaseMission.saveSavegame = Utils.appendedFunction(FSBaseMission.saveSavegame, AutoDrive.saveSavegame)

	LoadTrigger.onActivateObject = Utils.overwrittenFunction(LoadTrigger.onActivateObject, AutoDrive.onActivateObject)
	LoadTrigger.getIsActivatable = Utils.overwrittenFunction(LoadTrigger.getIsActivatable, AutoDrive.getIsActivatable)
	LoadTrigger.onFillTypeSelection = Utils.overwrittenFunction(LoadTrigger.onFillTypeSelection, AutoDrive.onFillTypeSelection)

	VehicleCamera.zoomSmoothly = Utils.overwrittenFunction(VehicleCamera.zoomSmoothly, AutoDrive.zoomSmoothly)

	LoadTrigger.load = Utils.overwrittenFunction(LoadTrigger.load, ADTriggerManager.loadTriggerLoad)
	LoadTrigger.delete = Utils.overwrittenFunction(LoadTrigger.delete, ADTriggerManager.loadTriggerDelete)

	MapHotspot.getHasDetails = Utils.overwrittenFunction(MapHotspot.getHasDetails, AutoDrive.mapHotSpotClicked)
	MapHotspot.getIsVisible = Utils.overwrittenFunction(MapHotspot.getIsVisible, AutoDrive.MapHotspot_getIsVisible)
	IngameMapElement.mouseEvent = Utils.overwrittenFunction(IngameMapElement.mouseEvent, AutoDrive.ingameMapElementMouseEvent)

	ADRoutesManager.load()
	ADDrawingManager:load()
	ADMessagesManager:load()
	ADHarvestManager:load()
	ADInputManager:load()
end

function AutoDrive:firstRun()
	if g_server == nil then
		-- Here we could ask to server the initial sync
		AutoDriveUserConnectedEvent.sendEvent()
	else
		ADGraphManager:checkYPositionIntegrity()
	end

	AutoDrive.updateDestinationsMapHotspots()
	AutoDrive:registerDestinationListener(AutoDrive, AutoDrive.updateDestinationsMapHotspots)
end

function AutoDrive:saveSavegame()
	if AutoDrive.GetChanged() == true or AutoDrive.HudChanged then
		AutoDrive.saveToXML(AutoDrive.adXml)
		AutoDrive.configChanged = false
		AutoDrive.HudChanged = false
	else
		if AutoDrive.adXml ~= nil then
			saveXMLFile(AutoDrive.adXml)
		end
	end
	if g_server ~= nil then
		AutoDrive.saveUsersData()
	end
end

function AutoDrive:deleteMap()
	-- this function is called even befor the game is compeltely started in case you insert a wrong password for mp game, so we need to check that "mapHotspotsBuffer" and "unRegisterDestinationListener" are not nil
	if g_dedicatedServerInfo == nil and AutoDrive.mapHotspotsBuffer ~= nil then
		-- Removing and deleting all map hotspots
		for _, mh in pairs(AutoDrive.mapHotspotsBuffer) do
			g_currentMission:removeMapHotspot(mh)
			mh:delete()
		end
	end
	AutoDrive.mapHotspotsBuffer = {}

	if (AutoDrive.unRegisterDestinationListener ~= nil) then
		AutoDrive:unRegisterDestinationListener(AutoDrive)
	end
	ADRoutesManager.delete()
	if g_server ~= nil then
		delete(AutoDrive.adXml)
	end
end

function AutoDrive:keyEvent(unicode, sym, modifier, isDown)
	--print("Key event called with modifier: " .. modifier .. " and key: " .. unicode .. " and isDown: " .. AutoDrive.boolToString(isDown))
	AutoDrive.leftCTRLmodifierKeyPressed = bitAND(modifier, Input.MOD_LCTRL) > 0
	AutoDrive.leftALTmodifierKeyPressed = bitAND(modifier, Input.MOD_LALT) > 0
end

function AutoDrive:mouseEvent(posX, posY, isDown, isUp, button)
	local vehicle = g_currentMission.controlledVehicle

	if vehicle ~= nil and vehicle.ad ~= nil and vehicle.ad.nToolTipWait ~= nil then
		if vehicle.ad.sToolTip ~= "" then
			if vehicle.ad.nToolTipWait <= 0 then
				vehicle.ad.sToolTip = ""
			else
				vehicle.ad.nToolTipWait = vehicle.ad.nToolTipWait - 1
			end
		end
	end

	if vehicle ~= nil and vehicle.ad ~= nil and vehicle.ad.lastMouseState ~= g_inputBinding:getShowMouseCursor() then
		AutoDrive:onToggleMouse(vehicle)
	end

	if vehicle ~= nil and AutoDrive.Hud.showHud == true then
		AutoDrive.Hud:mouseEvent(vehicle, posX, posY, isDown, isUp, button)
	end
end

function AutoDrive:update(dt)
	if AutoDrive.isFirstRun == nil then
		AutoDrive.isFirstRun = false
		self:firstRun()
	end

	if AutoDrive.getDebugChannelIsSet(AutoDrive.DC_NETWORKINFO) then
		if AutoDrive.debug.lastSentEvent ~= nil then
			AutoDrive.renderTable(0.3, 0.9, 0.009, AutoDrive.debug.lastSentEvent)
		end
	end

	AutoDrive.handlePerFrameOperations(dt)

	ADHarvestManager:update()
	ADMessagesManager:update(dt)
end

function AutoDrive.handlePerFrameOperations(dt)
	for _, vehicle in pairs(g_currentMission.vehicles) do
		if (vehicle.ad ~= nil and vehicle.ad.noMovementTimer ~= nil and vehicle.lastSpeedReal ~= nil) then
			vehicle.ad.noMovementTimer:timer((vehicle.lastSpeedReal <= 0.0010), 3000, dt)

			local vehicleSteering = vehicle.rotatedTime ~= nil and (math.deg(vehicle.rotatedTime) > 10)
			if (not vehicleSteering) and ((vehicle.lastSpeedReal * vehicle.movingDirection) >= 0.0008) then
				vehicle.ad.driveForwardTimer:timer(true, 20000, dt)
			else
				vehicle.ad.driveForwardTimer:timer(false)
			end
		end

		if (vehicle.ad ~= nil and vehicle.ad.noTurningTimer ~= nil) then
			local cpIsTurning = vehicle.cp ~= nil and (vehicle.cp.isTurning or (vehicle.cp.turnStage ~= nil and vehicle.cp.turnStage > 0))
			local cpIsTurningTwo = vehicle.cp ~= nil and vehicle.cp.driver and (vehicle.cp.driver.turnIsDriving or (vehicle.cp.driver.fieldworkState ~= nil and vehicle.cp.driver.fieldworkState == vehicle.cp.driver.states.TURNING))
			local aiIsTurning = (vehicle.getAIIsTurning ~= nil and vehicle:getAIIsTurning() == true)
			local combineSteering = vehicle.rotatedTime ~= nil and (math.deg(vehicle.rotatedTime) > 20)
			local combineIsTurning = cpIsTurning or cpIsTurningTwo or aiIsTurning or combineSteering
			vehicle.ad.noTurningTimer:timer((not combineIsTurning), 4000, dt)
			vehicle.ad.turningTimer:timer(combineIsTurning, 4000, dt)
		end
	end

	for _, trigger in pairs(ADTriggerManager:getLoadTriggers()) do
		if trigger.stoppedTimer == nil then
			trigger.stoppedTimer = AutoDriveTON:new()
		end
		trigger.stoppedTimer:timer(not trigger.isLoading, 300, dt)
	end
end

function AutoDrive:draw()
	ADDrawingManager:draw()
	ADMessagesManager:draw()
end

function AutoDrive.startAD(vehicle)
	vehicle.ad.stateModule:setActive(true)

	vehicle.ad.onRouteToPark = false
	vehicle.ad.isStoppingWithError = false

	vehicle.forceIsActive = true
	vehicle.spec_motorized.stopMotorOnLeave = false
	vehicle.spec_enterable.disableCharacterOnLeave = false
	if vehicle.currentHelper == nil then
		vehicle.currentHelper = g_helperManager:getRandomHelper()
		if vehicle.setRandomVehicleCharacter ~= nil then
			vehicle:setRandomVehicleCharacter()
			vehicle.ad.vehicleCharacter = vehicle.spec_enterable.vehicleCharacter
		end
		if vehicle.spec_enterable.controllerFarmId ~= 0 then
			vehicle.spec_aiVehicle.startedFarmId = vehicle.spec_enterable.controllerFarmId
		end
	end
	vehicle.spec_aiVehicle.isActive = true

	if vehicle.steeringEnabled == true then
		vehicle.steeringEnabled = false
	end

	--vehicle.spec_aiVehicle.aiTrafficCollision = nil;
	--Code snippet from function AIVehicle:startAIVehicle(helperIndex, noEventSend, startedFarmId):
	if vehicle.getAINeedsTrafficCollisionBox ~= nil then
		if vehicle:getAINeedsTrafficCollisionBox() then
			local collisionRoot = g_i3DManager:loadSharedI3DFile(AIVehicle.TRAFFIC_COLLISION_BOX_FILENAME, vehicle.baseDirectory, false, true, false)
			if collisionRoot ~= nil and collisionRoot ~= 0 then
				local collision = getChildAt(collisionRoot, 0)
				link(getRootNode(), collision)

				vehicle.spec_aiVehicle.aiTrafficCollision = collision

				delete(collisionRoot)
			end
		end
	end

	AutoDriveHud:createMapHotspot(vehicle)
	if vehicle.isServer then
		--g_currentMission:farmStats(vehicle:getOwnerFarmId()):updateStats("workersHired", 1)
		g_currentMission:farmStats(vehicle:getOwnerFarmId()):updateStats("driversHired", 1)
	end
end

function AutoDrive.disableAutoDriveFunctions(vehicle)
	if vehicle.isServer and vehicle.ad.stateModule:isActive() then
		g_currentMission:farmStats(vehicle:getOwnerFarmId()):updateStats("driversHired", -1)
	end

	vehicle.ad.drivePathModule:reset()
	vehicle.ad.specialDrivingModule:reset()
	vehicle.ad.trailerModule:reset()

	for _, mode in pairs(vehicle.ad.modes) do
		mode:reset()
	end

	vehicle.ad.stateModule:setActive(false)

	if vehicle.ad.callBackFunction ~= nil and (vehicle.ad.isStoppingWithError == nil or vehicle.ad.isStoppingWithError == false) then
		--work with copys, so we can remove the callBackObjects before calling the function
		local callBackFunction = vehicle.ad.callBackFunction
		local callBackObject = vehicle.ad.callBackObject
		local callBackArg = vehicle.ad.callBackArg
		vehicle.ad.callBackFunction = nil
		vehicle.ad.callBackObject = nil
		vehicle.ad.callBackArg = nil

		if callBackObject ~= nil then
			if callBackArg ~= nil then
				callBackFunction(callBackObject, callBackArg)
			else
				callBackFunction(callBackObject)
			end
		else
			if callBackArg ~= nil then
				callBackFunction(callBackArg)
			else
				callBackFunction()
			end
		end
	else
		vehicle.spec_aiVehicle.isActive = false
		vehicle.forceIsActive = false
		vehicle.spec_motorized.stopMotorOnLeave = true
		vehicle.spec_enterable.disableCharacterOnLeave = true
		vehicle.currentHelper = nil

		if vehicle.restoreVehicleCharacter ~= nil then
			vehicle:restoreVehicleCharacter()
		end

		if vehicle.steeringEnabled == false then
			vehicle.steeringEnabled = true
		end

		vehicle:setCruiseControlState(Drivable.CRUISECONTROL_STATE_OFF)
		AIVehicleUtil.driveInDirection(vehicle, 16, 30, 0, 0.2, 20, false, vehicle.ad.drivingForward, 0, 0, 0, 1)

		if vehicle.ad.onRouteToPark == true then
			vehicle.ad.onRouteToPark = false
			-- We don't need that, since the motor is turned off automatically when the helper is kicked out
			--vehicle:stopMotor()
			if vehicle.spec_lights ~= nil then
				vehicle:deactivateLights()
			end
		end

		vehicle:requestActionEventUpdate()
		if vehicle.raiseAIEvent ~= nil then
			vehicle:raiseAIEvent("onAIEnd", "onAIImplementEnd")
		end
	end

	if vehicle.ad.sensors ~= nil then
		for _, sensor in pairs(vehicle.ad.sensors) do
			sensor:setEnabled(false)
		end
	end

	AutoDriveHud:deleteMapHotspot(vehicle)

	if vehicle.setBeaconLightsVisibility ~= nil then
		vehicle:setBeaconLightsVisibility(false)
	end

	vehicle.ad.taskModule:reset()
end

function AutoDrive.MarkChanged()
	AutoDrive.configChanged = true
end

function AutoDrive.GetChanged()
	return AutoDrive.configChanged
end

function AutoDrive.addGroup(groupName, sendEvent)
	if groupName:len() > 1 and AutoDrive.groups[groupName] == nil then
		if sendEvent == nil or sendEvent == true then
			-- Propagating group creation all over the network
			AutoDriveGroupsEvent.sendEvent(groupName, AutoDriveGroupsEvent.TYPE_ADD)
		else
			AutoDrive.groupCounter = table.count(AutoDrive.groups) + 1
			AutoDrive.groups[groupName] = AutoDrive.groupCounter
			for _, vehicle in pairs(g_currentMission.vehicles) do
				if (vehicle.ad ~= nil) then
					if vehicle.ad.groups[groupName] == nil then
						vehicle.ad.groups[groupName] = false
					end
				end
			end
			-- Resetting HUD
			AutoDrive.Hud.lastUIScale = 0
		end
	end
end

function AutoDrive.removeGroup(groupName, sendEvent)
	if AutoDrive.groups[groupName] ~= nil then
		if sendEvent == nil or sendEvent == true then
			-- Propagating group creation all over the network
			AutoDriveGroupsEvent.sendEvent(groupName, AutoDriveGroupsEvent.TYPE_REMOVE)
		else
			local groupId = AutoDrive.groups[groupName]
			-- Removing group from the groups list
			AutoDrive.groups[groupName] = nil
			-- Removing group from the vehicles groups list
			for _, vehicle in pairs(g_currentMission.vehicles) do
				if (vehicle.ad ~= nil) then
					if vehicle.ad.groups[groupName] ~= nil then
						vehicle.ad.groups[groupName] = nil
					end
				end
			end
			-- Moving all markers in the deleted group to default group
			for markerID, mapMarker in pairs(ADGraphManager:getMapMarkers()) do
				if mapMarker.group == groupName then
					mapMarker.group = "All"
				end
			end
			-- Resetting other goups id
			for gName, gId in pairs(AutoDrive.groups) do
				if groupId <= gId then
					AutoDrive.groups[gName] = gId - 1
				end
			end
			-- Resetting HUD
			AutoDrive.Hud.lastUIScale = 0
			AutoDrive.groupCounter = table.count(AutoDrive.groups)
		end
	end
end

AutoDrive.STAT_NAMES = {"driversTraveledDistance", "driversHired"}
for _, statName in pairs(AutoDrive.STAT_NAMES) do
	table.insert(FarmStats.STAT_NAMES, statName)
end

function AutoDrive:FarmStats_saveToXMLFile(xmlFile, key)
	key = key .. ".statistics"
	if self.statistics.driversTraveledDistance ~= nil then
		setXMLFloat(xmlFile, key .. ".driversTraveledDistance", self.statistics.driversTraveledDistance.total)
	end
end
FarmStats.saveToXMLFile = Utils.appendedFunction(FarmStats.saveToXMLFile, AutoDrive.FarmStats_saveToXMLFile)

function AutoDrive:FarmStats_loadFromXMLFile(xmlFile, key)
	key = key .. ".statistics"
	self.statistics["driversTraveledDistance"].total = Utils.getNoNil(getXMLFloat(xmlFile, key .. ".driversTraveledDistance"), 0)
end
FarmStats.loadFromXMLFile = Utils.appendedFunction(FarmStats.loadFromXMLFile, AutoDrive.FarmStats_loadFromXMLFile)

function AutoDrive:FarmStats_getStatisticData(superFunc)
	if superFunc ~= nil then
		superFunc(self)
	end
	if not g_currentMission.missionDynamicInfo.isMultiplayer or not g_currentMission.missionDynamicInfo.isClient then
		local firstCall = self.statisticDataRev["driversHired"] == nil or self.statisticDataRev["driversTraveledDistance"] == nil
		self:addStatistic("driversHired", nil, self:getSessionValue("driversHired"), nil, "%s")
		self:addStatistic("driversTraveledDistance", g_i18n:getMeasuringUnit(), g_i18n:getDistance(self:getSessionValue("driversTraveledDistance")), g_i18n:getDistance(self:getTotalValue("driversTraveledDistance")), "%.2f")
		if firstCall then
			-- Moving position of our stats
			local statsLength = #self.statisticData
			local dTdPosition = 14
			-- Backup of our new stats
			local driversHired = self.statisticData[statsLength - 1]
			local driversTraveledDistance = self.statisticData[statsLength]
			-- Moving 'driversHired' one position up
			self.statisticData[statsLength - 1] = self.statisticData[statsLength - 2]
			self.statisticData[statsLength - 2] = driversHired
			-- Moving 'driversTraveledDistance' to 14th position
			for i = statsLength - 1, dTdPosition, -1 do
				self.statisticData[i + 1] = self.statisticData[i]
			end
			self.statisticData[dTdPosition] = driversTraveledDistance
		end
	end
	return Utils.getNoNil(self.statisticData, {})
end
FarmStats.getStatisticData = Utils.overwrittenFunction(FarmStats.getStatisticData, AutoDrive.FarmStats_getStatisticData)

addModEventListener(AutoDrive)
