AutoDrive = {}
AutoDrive.Version = "1.0.6.7"
AutoDrive.config_changed = false

AutoDrive.directory = g_currentModDirectory
AutoDrive.actions = {
	{"ADToggleMouse", true, 1},
	{"ADToggleHud", true, 1},
	{"ADEnDisable", true, 1},
	{"ADSelectTarget", false, 0},
	{"ADSelectPreviousTarget", false, 0},
	{"ADSelectTargetUnload", false, 0},
	{"ADSelectPreviousTargetUnload", false, 0},
	{"ADActivateDebug", false, 0},
	{"ADDebugShowClosest", false, 0},
	{"ADDebugSelectNeighbor", false, 0},
	{"ADDebugChangeNeighbor", false, 0},
	{"ADDebugCreateConnection", false, 0},
	{"ADDebugCreateMapMarker", false, 0},
	{"ADDebugDeleteWayPoint", false, 0},
	{"ADDebugForceUpdate", false, 0},
	{"ADDebugDeleteDestination", false, 3},
	{"ADSilomode", false, 0},
	{"ADOpenGUI", true, 2},
	{"ADCallDriver", false, 3},
	{"ADSelectNextFillType", false, 0},
	{"ADSelectPreviousFillType", false, 0},
	{"ADRecord", false, 0},
	{"AD_export_routes", false, 0},
	{"AD_import_routes", false, 0},
	{"AD_upload_routes", false, 0},
	{"ADGoToVehicle", false, 3},
	{"ADNameDriver", false, 0},
	{"ADRenameMapMarker", false, 0}
}

AutoDrive.drawHeight = 0.3

AutoDrive.MODE_DRIVETO = 1
AutoDrive.MODE_PICKUPANDDELIVER = 2
AutoDrive.MODE_DELIVERTO = 3
AutoDrive.MODE_LOAD = 4
AutoDrive.MODE_UNLOAD = 5
AutoDrive.MODE_BGA = 6

AutoDrive.WAYPOINTS_PER_PACKET = 25
AutoDrive.SPEED_ON_FIELD = 38

ADDEBUGLEVEL_NONE = 0
ADDEBUGLEVEL_ALL = math.huge
ADDEBUGLEVEL_1 = 1
ADDEBUGLEVEL_2 = 2
ADDEBUGLEVEL_3 = 3

AutoDrive.currentDebugLevel = ADDEBUGLEVEL_NONE --ADDEBUGLEVEL_ALL;

function AutoDrive:loadMap(name)
	source(Utils.getFilename("scripts/AutoDriveFunc.lua", AutoDrive.directory))
	source(Utils.getFilename("scripts/AutoDriveTrailerUtil.lua", AutoDrive.directory))
	source(Utils.getFilename("scripts/AutoDriveXML.lua", AutoDrive.directory))
	source(Utils.getFilename("scripts/AutoDriveInputFunctions.lua", AutoDrive.directory))
	source(Utils.getFilename("scripts/AutoDriveGraphHandling.lua", AutoDrive.directory))
	source(Utils.getFilename("scripts/AutoDriveLineDraw.lua", AutoDrive.directory))
	source(Utils.getFilename("scripts/AutoDriveDriveFuncs.lua", AutoDrive.directory))
	source(Utils.getFilename("scripts/AutoDriveTrigger.lua", AutoDrive.directory))
	source(Utils.getFilename("scripts/AutoDriveDijkstra.lua", AutoDrive.directory))
	source(Utils.getFilename("scripts/AutoDriveUtilFuncs.lua", AutoDrive.directory))
	source(Utils.getFilename("scripts/AutoDriveMultiplayer.lua", AutoDrive.directory))
	source(Utils.getFilename("scripts/AutoDriveCombineMode.lua", AutoDrive.directory))
	source(Utils.getFilename("scripts/AutoDrivePathFinder.lua", AutoDrive.directory))
	source(Utils.getFilename("scripts/AutoDriveSettings.lua", AutoDrive.directory))
	source(Utils.getFilename("gui/enterDriverNameGUI.lua", AutoDrive.directory))
	source(Utils.getFilename("gui/enterGroupNameGUI.lua", AutoDrive.directory))
	source(Utils.getFilename("gui/enterTargetNameGUI.lua", AutoDrive.directory))
	source(Utils.getFilename("gui/AutoDriveGUI.lua", AutoDrive.directory))
	source(Utils.getFilename("gui/settingsPage.lua", AutoDrive.directory))
	source(Utils.getFilename("scripts/AutoDriveExternalInterface.lua", AutoDrive.directory))
	source(Utils.getFilename("gui/vehicleSettingsPage.lua", AutoDrive.directory))
	source(Utils.getFilename("gui/combineUnloadSettingsPage.lua", AutoDrive.directory))
	source(Utils.getFilename("gui/settings.lua", AutoDrive.directory))
	source(Utils.getFilename("scripts/AutoDriveBGAUnloader.lua", AutoDrive.directory))
	source(Utils.getFilename("scripts/Sensors/AutoDriveVirtualSensors.lua", AutoDrive.directory))
	source(Utils.getFilename("scripts/Sensors/ADCollSensor.lua", AutoDrive.directory))
	source(Utils.getFilename("scripts/Sensors/ADFruitSensor.lua", AutoDrive.directory))
	AutoDrive:loadGUI()

	g_logManager:devInfo(string.format("Map title: %s", g_currentMission.missionInfo.map.title))

	AutoDrive.loadedMap = g_currentMission.missionInfo.map.title
	AutoDrive.loadedMap = string.gsub(AutoDrive.loadedMap, " ", "_")
	AutoDrive.loadedMap = string.gsub(AutoDrive.loadedMap, "%.", "_")
	AutoDrive.loadedMap = string.gsub(AutoDrive.loadedMap, ",", "_")
	AutoDrive.loadedMap = string.gsub(AutoDrive.loadedMap, ":", "_")
	AutoDrive.loadedMap = string.gsub(AutoDrive.loadedMap, ";", "_")

	g_logManager:devInfo(string.format("Parsed map title: %s", AutoDrive.loadedMap))

	AutoDrive.mapWayPoints = {}
	AutoDrive.mapWayPointsCounter = 0
	AutoDrive.mapMarker = {}
	AutoDrive.mapMarkerCounter = 0
	AutoDrive.showMouse = false

	AutoDrive.pullDownListExpanded = 0

	AutoDrive.lastSetSpeed = 50

	AutoDrive.print = {}
	AutoDrive.print.currentMessage = nil
	AutoDrive.print.referencedVehicle = nil
	AutoDrive.print.nextMessage = nil
	AutoDrive.print.showMessageFor = 12000
	AutoDrive.print.currentMessageActiveSince = 0
	AutoDrive.requestedWaypoints = false
	AutoDrive.requestedWaypointCount = 1
	AutoDrive.playerSendsMapToServer = false

	AutoDrive.mouseWheelActive = false

	AutoDrive:loadStoredXML()

	AutoDrive:initLineDrawing()

	AutoDrive.Hud = AutoDriveHud:new()
	AutoDrive.Hud:loadHud()

	-- Save Configuration when saving savegame
	FSBaseMission.saveSavegame = Utils.appendedFunction(FSBaseMission.saveSavegame, AutoDrive.saveSavegame)

	LoadTrigger.onActivateObject = Utils.overwrittenFunction(LoadTrigger.onActivateObject, AutoDrive.onActivateObject)
	LoadTrigger.getIsActivatable = Utils.overwrittenFunction(LoadTrigger.getIsActivatable, AutoDrive.getIsActivatable)
	LoadTrigger.onFillTypeSelection = Utils.overwrittenFunction(LoadTrigger.onFillTypeSelection, AutoDrive.onFillTypeSelection)

	VehicleCamera.zoomSmoothly = Utils.overwrittenFunction(VehicleCamera.zoomSmoothly, AutoDrive.zoomSmoothly)

	LoadTrigger.load = Utils.overwrittenFunction(LoadTrigger.load, AutoDrive.loadTriggerLoad)
	LoadTrigger.delete = Utils.overwrittenFunction(LoadTrigger.delete, AutoDrive.loadTriggerDelete)
	FillTrigger.onCreate = Utils.overwrittenFunction(FillTrigger.onCreate, AutoDrive.fillTriggerOnCreate)

	if g_server ~= nil then
		AutoDrive.Server = {}
		AutoDrive.Server.Users = {}
	else
		AutoDrive.highestIndex = 1
	end

	AutoDrive.waitingUnloadDrivers = {}
	AutoDrive.destinationListeners = {}

	AutoDrive.delayedCallBacks = {}
	--AutoDrive.delayedCallBacks.openEnterDriverNameGUI =
	--    DelayedCallBack:new(
	--    function()
	--        g_gui:showGui("adEnterDriverNameGui")
	--    end
	--)
	--AutoDrive.delayedCallBacks.openEnterTargetNameGUI =
	--    DelayedCallBack:new(
	--    function()
	--        g_gui:showGui("adEnterTargetNameGui")
	--    end
	--)
	--AutoDrive.delayedCallBacks.openEnterGroupNameGUI =
	--    DelayedCallBack:new(
	--    function()
	--        g_gui:showGui("adEnterGroupNameGui")
	--    end
	--)
end

function AutoDrive:saveSavegame()
	if AutoDrive:GetChanged() == true or AutoDrive.HudChanged then
		AutoDrive:saveToXML(AutoDrive.adXml)
		AutoDrive.config_changed = false
		AutoDrive.HudChanged = false
	else
		if AutoDrive.adXml ~= nil then
			saveXMLFile(AutoDrive.adXml)
		end
	end
end

function AutoDrive:deleteMap()
end

function AutoDrive:keyEvent(unicode, sym, modifier, isDown)
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
	if AutoDrive ~= nil then
		AutoDrive.runThisFrame = false
	end

	--if (g_currentMission.controlledVehicle ~= nil) then
	--	--AutoDrive.renderTable(0.1, 0.9, 0.015, AutoDrive.mapWayPoints[AutoDrive:findClosestWayPoint(g_currentMission.controlledVehicle)])
	--	--AutoDrive.renderTable(0.3, 0.9, 0.008, AutoDrive.mapMarker)
	--	local printTable = {}
	--	printTable.g_logManager = g_logManager
	--	printTable.LogManager = LogManager
	--	AutoDrive.renderTable(0.1, 0.9, 0.015, printTable)
	--end

	if AutoDrive.debug.lastSentEvent ~= nil then
		AutoDrive.renderTable(0.1, 0.9, 0.009, AutoDrive.debug.lastSentEvent)
	end

	-- Iterate over all delayed call back instances and call update (that's needed to make the script working)
	for _, delayedCallBack in pairs(AutoDrive.delayedCallBacks) do
		delayedCallBack:update(dt)
	end

	-- Run things that should run at least once per frame, independent of the vehicle
	-- TODO: we don't need thus anymore since the current update is running only once per frame, but make sure AutoDrive.runThisFrame is not reference elsewhere
	if AutoDrive.runThisFrame == false then
		AutoDrive.runThisFrame = true
	end

	AutoDrive.handlePerFrameOperations(dt)
end

function AutoDrive:draw()
end

function AutoDrive.handlePerFrameOperations(dt)
	for _, vehicle in pairs(g_currentMission.vehicles) do
		if (vehicle.ad ~= nil and vehicle.ad.noMovementTimer ~= nil and vehicle.lastSpeedReal ~= nil) then
			vehicle.ad.noMovementTimer:timer((vehicle.lastSpeedReal <= 0.0010), 3000, dt)
		end

		if (vehicle.ad ~= nil and vehicle.ad.noTurningTimer ~= nil) then
			local cpIsTurning = vehicle.cp ~= nil and (vehicle.cp.isTurning or (vehicle.cp.turnStage ~= nil and vehicle.cp.turnStage > 0))
			local aiIsTurning = (vehicle.getAIIsTurning ~= nil and vehicle:getAIIsTurning() == true)
			local combineSteering = false --combine.rotatedTime ~= nil and (math.deg(combine.rotatedTime) > 10);
			local combineIsTurning = cpIsTurning or aiIsTurning or combineSteering
			vehicle.ad.noTurningTimer:timer((not combineIsTurning), 4000, dt)
		end
	end

	for _, trigger in pairs(AutoDrive.Triggers.siloTriggers) do
		if trigger.stoppedTimer == nil then
			trigger.stoppedTimer = AutoDriveTON:new()
		end
		trigger.stoppedTimer:timer(not trigger.isLoading, 300, dt)
	end
end

function AutoDrive:MarkChanged()
	AutoDrive.config_changed = true
	AutoDrive.handledRecalculation = false
end

function AutoDrive:GetChanged()
	return AutoDrive.config_changed
end

function AutoDrive.addGroup(groupName, sendEvent)
	if groupName:len() > 1 and AutoDrive.groups[groupName] == nil then
		if sendEvent == nil or sendEvent == true then
			-- Propagating group creation all over the network
			AutoDriveGroupsEvent.sendEvent(groupName, AutoDriveGroupsEvent.TYPE_ADD)
		else
			AutoDrive.groupCounter = AutoDrive.groupCounter + 1
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
			-- TODO: Rework this
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
			-- Moving all markers in the delete group to default group
			for markerID, _ in pairs(AutoDrive.mapMarker) do
				if AutoDrive.mapMarker[markerID].group == groupName then
					AutoDrive.mapMarker[markerID].group = "All"
				end
			end
			-- Resetting other goups id
			for gName, groupID in pairs(AutoDrive.groups) do
				if groupId <= groupID then
					AutoDrive.groups[gName] = groupID - 1
				end
			end
			-- Resetting HUD
			AutoDrive.Hud.lastUIScale = 0
			AutoDrive.groupCounter = AutoDrive.groupCounter - 1
		end
	end
end

function AutoDrive.renameDriver(vehicle, name, sendEvent)
	if name:len() > 1 and vehicle ~= nil and vehicle.ad ~= nil then
		if sendEvent == nil or sendEvent == true then
			-- Propagating driver rename all over the network
			AutoDriveRenameDriverEvent.sendEvent(vehicle, name)
		else
			vehicle.ad.driverName = name
		end
	end
end

function AutoDrive:zoomSmoothly(superFunc, offset)
	if not AutoDrive.mouseWheelActive then -- don't zoom camera when mouse wheel is used to scroll targets (thanks to sperrgebiet)
		superFunc(self, offset)
	end
end

addModEventListener(AutoDrive)
