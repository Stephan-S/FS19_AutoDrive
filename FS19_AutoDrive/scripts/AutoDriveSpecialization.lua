function AutoDrive.prerequisitesPresent(specializations)
    return SpecializationUtil.hasSpecialization(Motorized, specializations) and SpecializationUtil.hasSpecialization(Drivable, specializations) and SpecializationUtil.hasSpecialization(Enterable, specializations)
end

function AutoDrive.registerEventListeners(vehicleType)
    -- "onReadUpdateStream", "onWriteUpdateStream"
    for _, n in pairs({"load", "onUpdate", "onRegisterActionEvents", "onDelete", "onDraw", "onLeaveVehicle", "onPostLoad", "onLoad", "saveToXMLFile", "onReadStream", "onWriteStream"}) do
        SpecializationUtil.registerEventListener(vehicleType, n, AutoDrive)
    end
end

function AutoDrive:onRegisterActionEvents(isSelected, isOnActiveVehicle)
    -- continue on client side only
    -- TODO: I think we should remove that since everyone isClient even the dedicated server
    if not self.isClient then
        return
    end

    local registerEvents = isOnActiveVehicle
    if self.ad ~= nil then
        registerEvents = registerEvents or self == g_currentMission.controlledVehicle -- or self.ad.isActive;
    end

    -- only in active vehicle
    if registerEvents then
        -- we could have more than one event, so prepare a table to store them
        if self.ActionEvents == nil then
            self.ActionEvents = {}
        else
            --self:clearActionEventsTable( self.ActionEvents )
        end

        -- attach our actions
        local __, eventName
        local toggleButton = false
        local showF1Help = AutoDrive.getSetting("showHelp")
        for _, action in pairs(AutoDrive.actions) do
            __, eventName = InputBinding.registerActionEvent(g_inputBinding, action[1], self, AutoDrive.onActionCall, toggleButton, true, false, true)
            g_inputBinding:setActionEventTextVisibility(eventName, action[2] and showF1Help)
            if showF1Help then
                g_inputBinding:setActionEventTextPriority(eventName, action[3])
            end
        end
    end
end

function AutoDrive:onLoad(savegame)
    -- This will run before initial MP sync
    self.ad = {}
    self.ad.targetSelected = -1
    self.ad.mapMarkerSelected = -1
    self.ad.nameOfSelectedTarget = ""
    self.ad.targetSelected_Unload = -1
    self.ad.mapMarkerSelected_Unload = -1
    self.ad.nameOfSelectedTarget_Unload = ""
    self.ad.groups = {}
end

function AutoDrive:onPostLoad(savegame)
    -- This will run before initial MP sync
    if self.isServer then
        if savegame ~= nil then
            local xmlFile = savegame.xmlFile
            local key = savegame.key .. ".FS19_AutoDrive.AutoDrive"

            local mode = getXMLInt(xmlFile, key .. "#mode")
            if mode ~= nil then
                self.ad.mode = mode
            end
            local targetSpeed = getXMLInt(xmlFile, key .. "#targetSpeed")
            if targetSpeed ~= nil then
                self.ad.targetSpeed = targetSpeed
            end

            local mapMarkerSelected = getXMLInt(xmlFile, key .. "#mapMarkerSelected")
            if mapMarkerSelected ~= nil then
                self.ad.mapMarkerSelected = mapMarkerSelected
            end

            local mapMarkerSelected_Unload = getXMLInt(xmlFile, key .. "#mapMarkerSelected_Unload")
            if mapMarkerSelected_Unload ~= nil then
                self.ad.mapMarkerSelected_Unload = mapMarkerSelected_Unload
            end
            local unloadFillTypeIndex = getXMLInt(xmlFile, key .. "#unloadFillTypeIndex")
            if unloadFillTypeIndex ~= nil then
                self.ad.unloadFillTypeIndex = unloadFillTypeIndex
            end
            local driverName = getXMLString(xmlFile, key .. "#driverName")
            if driverName ~= nil then
                self.ad.driverName = driverName
            end
            local selectedLoopCounter = getXMLInt(xmlFile, key .. "#loopCounterSelected")
            if selectedLoopCounter ~= nil then
                self.ad.loopCounterSelected = selectedLoopCounter
            end
            local parkDestination = getXMLInt(xmlFile, key .. "#parkDestination")
            if parkDestination ~= nil then
                self.ad.parkDestination = parkDestination
            end

            local groupString = getXMLString(xmlFile, key .. "#groups")
            if groupString ~= nil then
                local groupTable = groupString:split(";")
                local temp = {}
                for i, groupCombined in pairs(groupTable) do
                    local groupNameAndBool = groupCombined:split(",")
                    if tonumber(groupNameAndBool[2]) >= 1 then
                        self.ad.groups[groupNameAndBool[1]] = true
                    else
                        self.ad.groups[groupNameAndBool[1]] = false
                    end
                end
            end

            AutoDrive.readVehicleSettingsFromXML(self, xmlFile, key)
        end
    end
    
    AutoDrive.init(self);
end

function AutoDrive:init()
    self.ad.isActive = false
    self.ad.isStopping = false
    self.ad.isStoppingWithError = false
    self.ad.drivingForward = true
    self.ad.targetX = 0
    self.ad.targetZ = 0
    self.ad.initialized = false
    self.ad.wayPoints = {}
    self.ad.wayPointsChanged = true
    self.ad.creationMode = false
    self.ad.creationModeDual = false
    self.ad.currentWayPoint = 0

    if self.ad.settings == nil then
        AutoDrive.copySettingsToVehicle(self)
    end

    if AutoDrive ~= nil then
        local set = false
        if self.ad.mapMarkerSelected ~= nil then
            if AutoDrive.mapMarker[self.ad.mapMarkerSelected] ~= nil then
                self.ad.targetSelected = AutoDrive.mapMarker[self.ad.mapMarkerSelected].id
                self.ad.nameOfSelectedTarget = AutoDrive.mapMarker[self.ad.mapMarkerSelected].name
                set = true
            end
        end
        if not set then
            self.ad.mapMarkerSelected = 1
            if AutoDrive.mapMarker[1] ~= nil then
                self.ad.targetSelected = AutoDrive.mapMarker[1].id
                self.ad.nameOfSelectedTarget = AutoDrive.mapMarker[1].name
            end
        end
    end
    if self.ad.mode == nil then
        self.ad.mode = AutoDrive.MODE_DRIVETO
    end
    if self.ad.targetSpeed == nil then
        self.ad.targetSpeed = AutoDrive.lastSetSpeed
    end
    self.ad.createMapPoints = false
    self.ad.displayMapPoints = false
    self.ad.showClosestPoint = true
    self.ad.selectedDebugPoint = -1
    self.ad.showSelectedDebugPoint = false
    self.ad.changeSelectedDebugPoint = false
    self.ad.iteratedDebugPoints = {}
    self.ad.inDeadLock = false
    self.ad.timeTillDeadLock = 15000
    self.ad.inDeadLockRepairCounter = 4

    self.ad.creatingMapMarker = false

    self.name = g_i18n:getText("UNKNOWN")
    if self.getName ~= nil then
        self.name = self:getName()
    end
    if self.ad.driverName == nil then
        self.ad.driverName = self.name
    end

    self.ad.moduleInitialized = true
    self.ad.currentInput = ""
    self.ad.lastSpeed = self.ad.targetSpeed
    self.ad.speedOverride = -1

    self.ad.isUnloading = false
    self.ad.isPaused = false
    self.ad.onRouteToSecondTarget = false
    self.ad.isLoading = false
    self.ad.isUnloadingToBunkerSilo = false
    if self.ad.unloadFillTypeIndex == nil then
        self.ad.unloadFillTypeIndex = 2
    end
    self.ad.isPausedCauseTraffic = false
    self.ad.startedLoadingAtTrigger = false
    self.ad.combineUnloadInFruit = false
    self.ad.combineUnloadInFruitWaitTimer = AutoDrive.UNLOAD_WAIT_TIMER
    self.ad.combineFruitToCheck = nil
    self.ad.driverOnTheWay = false
    self.ad.tryingToCallDriver = false
    self.ad.stoppedTimer = 5000
    self.ad.driveForwardTimer = AutoDriveTON:new()
    self.ad.closeCoverTimer = AutoDriveTON:new()
    self.ad.currentTrailer = 1
    self.ad.usePathFinder = false
    self.ad.onRouteToPark = false

    if AutoDrive ~= nil then
        local set = false
        if self.ad.mapMarkerSelected_Unload ~= nil then
            if AutoDrive.mapMarker[self.ad.mapMarkerSelected_Unload] ~= nil then
                self.ad.targetSelected_Unload = AutoDrive.mapMarker[self.ad.mapMarkerSelected_Unload].id
                self.ad.nameOfSelectedTarget_Unload = AutoDrive.mapMarker[self.ad.mapMarkerSelected_Unload].name
                set = true
            end
        end
        if not set then
            self.ad.mapMarkerSelected_Unload = 1
            if AutoDrive.mapMarker[1] ~= nil then
                self.ad.targetSelected_Unload = AutoDrive.mapMarker[1].id
                self.ad.nameOfSelectedTarget_Unload = AutoDrive.mapMarker[1].name
            end
        end
    end

    self.ad.nToolTipWait = 300
    self.ad.sToolTip = ""

    if AutoDrive.showingHud ~= nil then
        self.ad.showingHud = AutoDrive.showingHud
    else
        self.ad.showingHud = true
    end
    self.ad.showingMouse = false

    -- Variables the server sets so that the clients can act upon it:
    self.ad.disableAI = 0
    self.ad.enableAI = 0

    self.ad.combineState = AutoDrive.COMBINE_UNINITIALIZED
    self.ad.currentCombine = nil
    self.ad.currentDriver = nil

    if self.spec_autodrive == nil then
        self.spec_autodrive = AutoDrive
    end

    self.ad.pullDownList = {}
    self.ad.pullDownList.active = false
    self.ad.pullDownList.start = false
    self.ad.pullDownList.destination = false
    self.ad.pullDownList.fillType = false
    self.ad.pullDownList.itemList = {}
    self.ad.pullDownList.selectedItem = nil
    self.ad.pullDownList.posX = 0
    self.ad.pullDownList.posY = 0
    self.ad.pullDownList.width = 0
    self.ad.pullDownList.height = 0
    self.ad.lastMouseState = false
    if self.ad.loopCounterSelected == nil then
        self.ad.loopCounterSelected = 0
    end
    self.ad.loopCounterCurrent = 0
    if self.ad.parkDestination == nil then
        self.ad.parkDestination = -1
    end

    if self.bga == nil then
        self.bga = {}
        self.bga.state = AutoDriveBGA.STATE_IDLE
        self.bga.isActive = false
    end
    self.ad.noMovementTimer = AutoDriveTON:new()
    self.ad.noTurningTimer = AutoDriveTON:new()

    if self.ad.groups == nil then
        self.ad.groups = {}
    end
    for groupName, groupIds in pairs(AutoDrive.groups) do
        if self.ad.groups[groupName] == nil then
            self.ad.groups[groupName] = false
        end
    end
    self.ad.reverseTimer = 3000
    self.ad.ccMode = AutoDrive.CC_MODE_IDLE
    self.ccInfos = {}
    self.ad.distanceToCombine = math.huge
    self.ad.destinationFilterText = "";
end

function AutoDrive:onLeaveVehicle()
    local storedshowingHud = self.ad.showingHud
    if g_inputBinding:getShowMouseCursor() == true and (g_currentMission.controlledVehicle == nil or (g_currentMission.controlledVehicle.ad.showingHud == false) or self == g_currentMission.controlledVehicle) then
        g_inputBinding:setShowMouseCursor(false)
        AutoDrive:onToggleMouse(self)
    end
    self.ad.showingHud = storedshowingHud
    if (g_currentMission.controlledVehicle == nil or (g_currentMission.controlledVehicle.ad.showingHud == false) or self == g_currentMission.controlledVehicle) then
        AutoDrive.Hud:closeAllPullDownLists(self)
    end
end

function AutoDrive:onToggleMouse(vehicle)
    if g_inputBinding:getShowMouseCursor() == true then
        if vehicle.spec_enterable ~= nil then
            if vehicle.spec_enterable.cameras ~= nil then
                for camIndex, camera in pairs(vehicle.spec_enterable.cameras) do
                    camera.allowTranslation = false
                    camera.isRotatable = false
                end
            end
        end
    else
        if vehicle.spec_enterable ~= nil then
            if vehicle.spec_enterable.cameras ~= nil then
                for camIndex, camera in pairs(vehicle.spec_enterable.cameras) do
                    camera.allowTranslation = true
                    camera.isRotatable = true
                end
            end
        end
    end

    vehicle.ad.lastMouseState = g_inputBinding:getShowMouseCursor()
end

function AutoDrive:onWriteStream(streamId, connection)
    for settingName, setting in pairs(AutoDrive.settings) do
        if setting ~= nil and setting.isVehicleSpecific then
            streamWriteInt16(streamId, AutoDrive.getSettingState(settingName, self))
        end
    end
end

function AutoDrive:onReadStream(streamId, connection)
    for settingName, setting in pairs(AutoDrive.settings) do
        if setting ~= nil and setting.isVehicleSpecific then
            self.ad.settings[settingName].current = streamReadInt16(streamId)
        end
    end
end

function AutoDrive:onUpdate(dt)
    --if self.ad == nil or self.ad.moduleInitialized ~= true then
    --    init(self)
    --end

    if self.ad.currentInput ~= "" and self.isServer then
        AutoDrive:InputHandling(self, self.ad.currentInput)
    end

    self.ad.closest = nil

    AutoDrive:handleRecalculation(self)
    AutoDrive:handleRecording(self)
    ADSensor:handleSensors(self, dt)
    AutoDrive:handleDriving(self, dt)
    AutoDrive:handleYPositionIntegrityCheck(self)
    AutoDrive:handleVehicleIntegrity(self)
    AutoDrive.handleVehicleMultiplayer(self, dt)
    AutoDrive:handleDriverWages(self, dt)
    AutoDriveBGA:handleBGA(self, dt)

    if self.spec_pipe ~= nil and self.spec_enterable ~= nil and self.getIsBufferCombine ~= nil then
        AutoDrive:handleCombineHarvester(self, dt)
    end

    if g_currentMission.controlledVehicle == self and AutoDrive.getDebugChannelIsSet(AutoDrive.DC_VEHICLEINFO) then
        AutoDrive.renderTable(0.1, 0.9, 0.015, AutoDrive:createVehicleInfoTable(self));
	end;
end

function AutoDrive:createVehicleInfoTable(vehicle)
    local infoTable = {};

    infoTable["isPaused"] = vehicle.ad.isPaused;
    infoTable["isLoading"] = vehicle.ad.isLoading;
    infoTable["isUnloading"] = vehicle.ad.isUnloading;
    infoTable["isActive"] = vehicle.ad.isActive;
    infoTable["isStopping"] = vehicle.ad.isStopping;
    infoTable["mode"] = AutoDriveHud:getModeName(vehicle);
    infoTable["inDeadLock"] = vehicle.ad.inDeadLock;
    infoTable["speedOverride"] = vehicle.ad.speedOverride;
    infoTable["onRouteToSecondTarget"] = vehicle.ad.onRouteToSecondTarget;
    infoTable["onRouteToRefuel"] = vehicle.ad.onRouteToRefuel;
    infoTable["unloadFillTypeIndex"] = vehicle.ad.unloadFillTypeIndex;
    infoTable["startedLoadingAtTrigger"] = vehicle.ad.startedLoadingAtTrigger;
    infoTable["combineUnloadInFruit"] = vehicle.ad.combineUnloadInFruit;
    infoTable["combineFruitToCheck"] = vehicle.ad.combineFruitToCheck;
    infoTable["currentTrailer"] = vehicle.ad.currentTrailer;
    infoTable["combineState"] = AutoDrive.combineStateToName(vehicle)
    infoTable["ccMode"] = AutoDrive.combineCCStateToName(vehicle);

    return infoTable;
end;

function AutoDrive:handleDriverWages(vehicle, dt)
    local spec = vehicle.spec_aiVehicle
    if vehicle.isServer and spec ~= nil then
        if vehicle:getIsAIActive() and spec.startedFarmId ~= nil and spec.startedFarmId > 0 and vehicle.ad.isActive then
            local driverWages = AutoDrive.getSetting("driverWages")
            local difficultyMultiplier = g_currentMission.missionInfo.buyPriceMultiplier
            local price = -dt * difficultyMultiplier * (driverWages - 1) * spec.pricePerMS
            g_currentMission:addMoney(price, spec.startedFarmId, MoneyType.AI, true)
        end
    end
end

function AutoDrive:saveToXMLFile(xmlFile, key)
    setXMLInt(xmlFile, key .. "#mode", self.ad.mode)
    setXMLInt(xmlFile, key .. "#targetSpeed", self.ad.targetSpeed)
    setXMLInt(xmlFile, key .. "#mapMarkerSelected", self.ad.mapMarkerSelected)
    setXMLInt(xmlFile, key .. "#mapMarkerSelected_Unload", self.ad.mapMarkerSelected_Unload)
    setXMLInt(xmlFile, key .. "#unloadFillTypeIndex", self.ad.unloadFillTypeIndex)
    setXMLString(xmlFile, key .. "#driverName", self.ad.driverName)
    setXMLInt(xmlFile, key .. "#loopCounterSelected", self.ad.loopCounterSelected)
    setXMLInt(xmlFile, key .. "#parkDestination", self.ad.parkDestination)

    for settingName, setting in pairs(AutoDrive.settings) do
        if setting.isVehicleSpecific and self.ad.settings ~= nil and self.ad.settings[settingName] ~= nil then
            setXMLInt(xmlFile, key .. "#" .. settingName, self.ad.settings[settingName].current)
        end
    end

    if self.ad.groups ~= nil then
        local combinedString = ""
        for groupName, groupEntries in pairs(AutoDrive.groups) do
            for myGroupName, value in pairs(self.ad.groups) do
                if groupName == myGroupName then
                    if string.len(combinedString) > 0 then
                        combinedString = combinedString .. ";"
                    end
                    if value == true then
                        combinedString = combinedString .. myGroupName .. ",1"
                    else
                        combinedString = combinedString .. myGroupName .. ",0"
                    end
                end
            end
        end
        setXMLString(xmlFile, key .. "#groups", combinedString)
    end
end

function AutoDrive:onDraw()
    if self.ad.moduleInitialized == false then
        return
    end

    if self.ad ~= nil then
        if self.ad.showingHud ~= AutoDrive.Hud.showHud then
            AutoDrive.Hud:toggleHud(self)
        end
    end

    if AutoDrive.getSetting("showNextPath") == true and (self.bga.isActive == false) then
        if self.ad.currentWayPoint > 0 and self.ad.wayPoints ~= nil then
            if self.ad.wayPoints[self.ad.currentWayPoint + 1] ~= nil then
                AutoDrive:drawLine(self.ad.wayPoints[self.ad.currentWayPoint], self.ad.wayPoints[self.ad.currentWayPoint + 1], 1, 1, 1, 1)
            end
        end
    end

    if self == g_currentMission.controlledVehicle and (g_dedicatedServerInfo == nil) then
        AutoDrive:onDrawControlledVehicle(self)
    end

    if (self.ad.createMapPoints or self.ad.displayMapPoints) and self == g_currentMission.controlledVehicle then
        AutoDrive:onDrawCreationMode(self)
    end
end

function AutoDrive:onDrawControlledVehicle(vehicle)
    AutoDrive:drawJobs()

    if AutoDrive.print.currentMessage ~= nil then
        local adFontSize = 0.016
        local adPosX = 0.5
        local adPosY = 0.14
        setTextColor(1, 1, 0, 1)
        setTextAlignment(RenderText.ALIGN_CENTER)
        renderText(adPosX, adPosY, adFontSize, AutoDrive.print.currentMessage)
    end

    if AutoDrive.Hud ~= nil then
        if AutoDrive.Hud.showHud == true then
            AutoDrive.Hud:drawHud(vehicle)
        end
    end
end

function AutoDrive:onDrawCreationMode(vehicle)
    local x1, y1, z1 = getWorldTranslation(vehicle.components[1].node)
    for i, point in pairs(AutoDrive.mapWayPoints) do
        local distance = AutoDrive:getDistance(point.x, point.z, x1, z1)
        if distance < 50 then
            if point.out ~= nil then
                for i2, neighbor in pairs(point.out) do
                    local testDual = false
                    for _, incoming in pairs(point.incoming) do
                        if incoming == neighbor then
                            testDual = true
                        end
                    end

                    target = AutoDrive.mapWayPoints[neighbor]
                    if target ~= nil then
                        if testDual == true then
                            AutoDrive:drawLine(point, AutoDrive.mapWayPoints[neighbor], 0, 0, 1, 1)
                        else
                            local deltaX = AutoDrive.mapWayPoints[neighbor].x - point.x
                            local deltaY = AutoDrive.mapWayPoints[neighbor].y - point.y
                            local deltaZ = AutoDrive.mapWayPoints[neighbor].z - point.z
                            AutoDrive:drawLine(point, AutoDrive.mapWayPoints[neighbor], 0, 1, 0, 1)

                            local vecX = point.x - AutoDrive.mapWayPoints[neighbor].x
                            local vecZ = point.z - AutoDrive.mapWayPoints[neighbor].z

                            local angleRad = math.atan2(vecZ, vecX)

                            angleRad = AutoDrive.normalizeAngle(angleRad)

                            local arrowLength = 0.3

                            local arrowLeft = AutoDrive.normalizeAngle(angleRad + math.rad(-20))
                            local arrowRight = AutoDrive.normalizeAngle(angleRad + math.rad(20))

                            local arrowLeftX = AutoDrive.mapWayPoints[neighbor].x + math.cos(arrowLeft) * arrowLength
                            local arrowLeftZ = AutoDrive.mapWayPoints[neighbor].z + math.sin(arrowLeft) * arrowLength

                            local arrowRightX = AutoDrive.mapWayPoints[neighbor].x + math.cos(arrowRight) * arrowLength
                            local arrowRightZ = AutoDrive.mapWayPoints[neighbor].z + math.sin(arrowRight) * arrowLength

                            local arrowPointLeft = {}
                            arrowPointLeft.x = arrowLeftX
                            arrowPointLeft.y = AutoDrive.mapWayPoints[neighbor].y
                            arrowPointLeft.z = arrowLeftZ

                            local arrowPointRight = {}
                            arrowPointRight.x = arrowRightX
                            arrowPointRight.y = AutoDrive.mapWayPoints[neighbor].y
                            arrowPointRight.z = arrowRightZ

                            AutoDrive:drawLine(arrowPointLeft, AutoDrive.mapWayPoints[neighbor], 0, 1, 0, 1)
                            AutoDrive:drawLine(arrowPointRight, AutoDrive.mapWayPoints[neighbor], 0, 1, 0, 1)
                        end
                    end
                end
            end
        end

        if (AutoDrive.tableLength(point.out) == 0) and (AutoDrive.tableLength(point.incoming) == 0) then
            local node = createTransformGroup("X")
            setTranslation(node, point.x, point.y + 4, point.z)
            DebugUtil.drawDebugNode(node, "X")
        end
    end

    for markerID, marker in pairs(AutoDrive.mapMarker) do
        local x1, y1, z1 = getWorldTranslation(vehicle.components[1].node)
        local x2, y2, z2 = getWorldTranslation(marker.node)
        local distance = AutoDrive:getDistance(x2, z2, x1, z1)
        if distance < 50 then
            DebugUtil.drawDebugNode(marker.node, marker.name)
        end
    end

    if vehicle.ad.createMapPoints and vehicle.ad.showClosestPoint == true and AutoDrive.mapWayPoints[1] ~= nil then
        local closest = AutoDrive:findClosestWayPoint(vehicle)
        local x1, y1, z1 = getWorldTranslation(vehicle.components[1].node)

        if vehicle.ad.showClosestPoint == true then
            AutoDrive:drawLine(AutoDrive.createVector(x1, y1 + 3.5 - AutoDrive.getSetting("lineHeight"), z1), AutoDrive.mapWayPoints[closest], 1, 0, 0, 1)
        end
    end

    if vehicle.ad.createMapPoints and vehicle.ad.showSelectedDebugPoint == true and AutoDrive.mapWayPoints[1] ~= nil then
        local closest = AutoDrive:findClosestWayPoint(vehicle)
        local x1, y1, z1 = getWorldTranslation(vehicle.components[1].node)
        if vehicle.ad.showSelectedDebugPoint == true then
            if vehicle.ad.iteratedDebugPoints[vehicle.ad.selectedDebugPoint] ~= nil then
                AutoDrive:drawLine(AutoDrive.createVector(x1, y1 + 3.5 - AutoDrive.getSetting("lineHeight"), z1), vehicle.ad.iteratedDebugPoints[vehicle.ad.selectedDebugPoint], 1, 1, 0, 1)
            end
        end
    end
end

function AutoDrive:preRemoveVehicle(vehicle)
    if vehicle.ad ~= nil and vehicle.ad.isActive then
        AutoDrive:disableAutoDriveFunctions(vehicle)
    end
end
FSBaseMission.removeVehicle = Utils.prependedFunction(FSBaseMission.removeVehicle, AutoDrive.preRemoveVehicle)

function AutoDrive:onDelete()
    AutoDriveHud:deleteMapHotspot(self)
end
