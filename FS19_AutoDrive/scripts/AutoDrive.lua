AutoDrive = {}
AutoDrive.version = "1.1.0.9-RC1"

AutoDrive.directory = g_currentModDirectory

g_autoDriveUIFilename = AutoDrive.directory .. "textures/GUI_Icons.dds"
g_autoDriveDebugUIFilename = AutoDrive.directory .. "textures/gui_debug_Icons.dds"

AutoDrive.experimentalFeatures = {}
AutoDrive.experimentalFeatures.redLinePosition = false
AutoDrive.experimentalFeatures.dynamicChaseDistance = false
AutoDrive.experimentalFeatures.enableRoutesManagerOnDediServer = false

AutoDrive.smootherDriving = true
AutoDrive.developmentControls = false

AutoDrive.mapHotspotsBuffer = {}

AutoDrive.drawHeight = 0.3
AutoDrive.drawDistance = getViewDistanceCoeff() * 50

AutoDrive.STAT_NAMES = {"driversTraveledDistance", "driversHired"}
for _, statName in pairs(AutoDrive.STAT_NAMES) do
	table.insert(FarmStats.STAT_NAMES, statName)
end

AutoDrive.MODE_DRIVETO = 1
AutoDrive.MODE_PICKUPANDDELIVER = 2
AutoDrive.MODE_DELIVERTO = 3
AutoDrive.MODE_LOAD = 4
AutoDrive.MODE_UNLOAD = 5
AutoDrive.MODE_BGA = 6

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
AutoDrive.DC_ROADNETWORKINFO = 512
AutoDrive.DC_ALL = 65535

AutoDrive.currentDebugChannelMask = AutoDrive.DC_NONE

-- rotate target modes
AutoDrive.RT_NONE = 1
AutoDrive.RT_ONLYPICKUP = 2
AutoDrive.RT_ONLYDELIVER = 3
AutoDrive.RT_PICKUPANDDELIVER = 4

AutoDrive.EDITOR_OFF = 1
AutoDrive.EDITOR_ON = 2
AutoDrive.EDITOR_EXTENDED = 3
AutoDrive.EDITOR_SHOW = 4

AutoDrive.MAX_BUNKERSILO_LENGTH = 100 -- length of bunker silo where speed should be lowered

AutoDrive.toggleSphrere = true
AutoDrive.enableSphrere = true

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
	{"ADSwapTargets", false, 0},
	{"AD_open_notification_history", false, 0},
	{"AD_continue", false, 3},
	{"ADParkVehicle", false, 0},
	{"AD_devAction", false, 0}
}

function AutoDrive:onAllModsLoaded()
	ADThirdPartyModsManager:load()
end

function AutoDrive:loadMap(name)
g_logManager:info("[AD] Start register later loaded mods...")
-- second iteration to register AD to vehicle types which where loaded after AD
    AutoDriveRegister.register()
    AutoDriveRegister.registerVehicleData()
g_logManager:info("[AD] Start register later loaded mods end")

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
	AutoDrive.loadedMap = string.gsub(AutoDrive.loadedMap, "'", "_")

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

	ADGraphManager:load()

	AutoDrive.loadStoredXML()

	ADUserDataManager:load()
	if g_server ~= nil then
		ADUserDataManager:loadFromXml()
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
	Placeable.onBuy = Utils.appendedFunction(Placeable.onBuy, ADTriggerManager.onPlaceableBuy)

	MapHotspot.getHasDetails = Utils.overwrittenFunction(MapHotspot.getHasDetails, AutoDrive.mapHotSpotClicked)
	MapHotspot.getIsVisible = Utils.overwrittenFunction(MapHotspot.getIsVisible, AutoDrive.MapHotspot_getIsVisible)
	IngameMapElement.mouseEvent = Utils.overwrittenFunction(IngameMapElement.mouseEvent, AutoDrive.ingameMapElementMouseEvent)

	FarmStats.saveToXMLFile = Utils.appendedFunction(FarmStats.saveToXMLFile, AutoDrive.FarmStats_saveToXMLFile)
	FarmStats.loadFromXMLFile = Utils.appendedFunction(FarmStats.loadFromXMLFile, AutoDrive.FarmStats_loadFromXMLFile)
	FarmStats.getStatisticData = Utils.overwrittenFunction(FarmStats.getStatisticData, AutoDrive.FarmStats_getStatisticData)

	FSBaseMission.removeVehicle = Utils.prependedFunction(FSBaseMission.removeVehicle, AutoDrive.preRemoveVehicle)

	ADRoutesManager:load()
	ADDrawingManager:load()
	ADMessagesManager:load()
	ADHarvestManager:load()
        ADScheduler:load()
	ADInputManager:load()
	ADMultipleTargetsManager:load()
end

function AutoDrive:init()
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
--    g_logManager:info("[AD] AutoDrive:saveSavegame start")
	if g_server ~= nil then
--        g_logManager:info("[AD] AutoDrive:saveSavegame g_server ~= nil start")
--[[
		if ADGraphManager:hasChanges() or AutoDrive.HudChanged then
            g_logManager:info("[AD] AutoDrive:saveSavegame hasChanges or HudChanged")
			AutoDrive.saveToXML(AutoDrive.adXml)
			ADGraphManager:resetChanges()
			AutoDrive.HudChanged = false
		else
            g_logManager:info("[AD] AutoDrive:saveSavegame else hasChanges or HudChanged")
			if AutoDrive.adXml ~= nil then
                g_logManager:info("[AD] AutoDrive:saveSavegame AutoDrive.adXml ~= nil -> saveXMLFile")
				saveXMLFile(AutoDrive.adXml)
			end
		end
]]
        AutoDrive.saveToXML()
		ADUserDataManager:saveToXml()
--        g_logManager:info("[AD] AutoDrive:saveSavegame g_server ~= nil end")
	end
--    g_logManager:info("[AD] AutoDrive:saveSavegame end")
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
	ADRoutesManager:delete()
end

function AutoDrive:keyEvent(unicode, sym, modifier, isDown)
	AutoDrive.leftCTRLmodifierKeyPressed = bitAND(modifier, Input.MOD_LCTRL) > 0
	AutoDrive.leftALTmodifierKeyPressed = bitAND(modifier, Input.MOD_LALT) > 0
	AutoDrive.leftLSHIFTmodifierKeyPressed = bitAND(modifier, Input.MOD_LSHIFT) > 0
	AutoDrive.isCAPSKeyActive = bitAND(modifier, Input.MOD_CAPS) > 0
	AutoDrive.rightCTRLmodifierKeyPressed = bitAND(modifier, Input.MOD_RCTRL) > 0

    if AutoDrive.isInExtendedEditorMode() then
        if (AutoDrive.rightCTRLmodifierKeyPressed and AutoDrive.toggleSphrere == true) then
            AutoDrive.toggleSphrere = false
        elseif (AutoDrive.rightCTRLmodifierKeyPressed and AutoDrive.toggleSphrere == false) then
            AutoDrive.toggleSphrere = true
        end

        if (AutoDrive.leftCTRLmodifierKeyPressed or AutoDrive.leftALTmodifierKeyPressed) then
            AutoDrive.enableSphrere = true
        else
            AutoDrive.enableSphrere = AutoDrive.toggleSphrere
        end
    end
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

	if vehicle ~= nil and vehicle.ad ~= nil and vehicle.ad.stateModule ~= nil and AutoDrive.Hud.showHud == true then
		AutoDrive.Hud:mouseEvent(vehicle, posX, posY, isDown, isUp, button)
	end

	ADMessagesManager:mouseEvent(posX, posY, isDown, isUp, button)
end

function AutoDrive:update(dt)
	if AutoDrive.isFirstRun == nil then
		AutoDrive.isFirstRun = false
		self:init()
                if AutoDrive.devAutoDriveInit ~= nil then
                    AutoDrive.devAutoDriveInit()
                end
	end

	if AutoDrive.getDebugChannelIsSet(AutoDrive.DC_NETWORKINFO) then
		if AutoDrive.debug.lastSentEvent ~= nil then
			AutoDrive.renderTable(0.3, 0.9, 0.009, AutoDrive.debug.lastSentEvent)
		end
	end
	if AutoDrive.getDebugChannelIsSet(AutoDrive.DC_SENSORINFO) and AutoDrive.getDebugChannelIsSet(AutoDrive.DC_VEHICLEINFO) then
		AutoDrive.debugDrawBoundingBoxForVehicles()
	end

	if AutoDrive.Hud ~= nil then
		if AutoDrive.Hud.showHud == true then
			AutoDrive.Hud:update(dt)
		end
	end

	if g_server ~= nil then
		ADHarvestManager:update(dt)
		ADScheduler:update(dt)
	end

	ADMessagesManager:update(dt)
	ADTriggerManager:update(dt)
	ADRoutesManager:update(dt)
end

function AutoDrive:draw()
	ADDrawingManager:draw()
	ADMessagesManager:draw()
end

function AutoDrive:preRemoveVehicle(vehicle)
	if vehicle.ad ~= nil and vehicle.ad.stateModule ~= nil then
        if vehicle.ad.stateModule:isActive() then
            vehicle:stopAutoDrive()
        end
        vehicle.ad.stateModule:disableCreationMode()
	end
end

function AutoDrive:FarmStats_saveToXMLFile(xmlFile, key)
	key = key .. ".statistics"
	if self.statistics.driversTraveledDistance ~= nil then
		setXMLFloat(xmlFile, key .. ".driversTraveledDistance", self.statistics.driversTraveledDistance.total)
	end
end

function AutoDrive:FarmStats_loadFromXMLFile(xmlFile, key)
	key = key .. ".statistics"
	self.statistics["driversTraveledDistance"].total = Utils.getNoNil(getXMLFloat(xmlFile, key .. ".driversTraveledDistance"), 0)
end

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

addModEventListener(AutoDrive)
