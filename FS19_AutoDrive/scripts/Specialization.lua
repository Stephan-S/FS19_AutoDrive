function AutoDrive.prerequisitesPresent(specializations)
    return SpecializationUtil.hasSpecialization(Motorized, specializations) and SpecializationUtil.hasSpecialization(Drivable, specializations) and SpecializationUtil.hasSpecialization(Enterable, specializations)
end

function AutoDrive.registerEventListeners(vehicleType)
    for _, n in pairs({"load", "onUpdate", "onRegisterActionEvents", "onDelete", "onDraw", "onPostLoad", "onLoad", "saveToXMLFile", "onReadStream", "onWriteStream", "onReadUpdateStream", "onWriteUpdateStream", "onUpdateTick", "onStartAutoDrive", "onStopAutoDrive"}) do
        SpecializationUtil.registerEventListener(vehicleType, n, AutoDrive)
    end
end

function AutoDrive.registerOverwrittenFunctions(vehicleType)
    SpecializationUtil.registerOverwrittenFunction(vehicleType, "updateAILights", AutoDrive.updateAILights)
    SpecializationUtil.registerOverwrittenFunction(vehicleType, "getCanMotorRun", AutoDrive.getCanMotorRun)
end

function AutoDrive.registerFunctions(vehicleType)
    SpecializationUtil.registerFunction(vehicleType, "startAutoDrive", AutoDrive.startAutoDrive)
    SpecializationUtil.registerFunction(vehicleType, "stopAutoDrive", AutoDrive.stopAutoDrive)
end

function AutoDrive.registerEvents(vehicleType)
    SpecializationUtil.registerEvent(vehicleType, "onStartAutoDrive")
    SpecializationUtil.registerEvent(vehicleType, "onStopAutoDrive")
end

function AutoDrive:onRegisterActionEvents(_, isOnActiveVehicle)
    local registerEvents = isOnActiveVehicle
    if self.ad ~= nil then
        registerEvents = registerEvents or self == g_currentMission.controlledVehicle
    end

    -- only in active vehicle
    if registerEvents then
        -- attach our actions
        local _, eventName
        local toggleButton = false
        local showF1Help = AutoDrive.getSetting("showHelp")
        for _, action in pairs(AutoDrive.actions) do
            _, eventName = InputBinding.registerActionEvent(g_inputBinding, action[1], self, ADInputManager.onActionCall, toggleButton, true, false, true)
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
    self.ad.dirtyFlag = self:getNextDirtyFlag()
    self.ad.smootherDriving = {}
    self.ad.smootherDriving.lastMaxSpeed = 0
    self.ad.groups = {}

    self.ad.stateModule = ADStateModule:new(self)
    self.ad.taskModule = ADTaskModule:new(self)
    self.ad.trailerModule = ADTrailerModule:new(self)
    self.ad.drivePathModule = ADDrivePathModule:new(self)
    self.ad.specialDrivingModule = ADSpecialDrivingModule:new(self)
    self.ad.collisionDetectionModule = ADCollisionDetectionModule:new(self)
    self.ad.pathFinderModule = PathFinderModule:new(self)

    self.ad.modes = {}
    self.ad.modes[AutoDrive.MODE_DRIVETO] = DriveToMode:new(self)
    self.ad.modes[AutoDrive.MODE_DELIVERTO] = UnloadAtMode:new(self)
    self.ad.modes[AutoDrive.MODE_PICKUPANDDELIVER] = PickupAndDeliverMode:new(self)
    self.ad.modes[AutoDrive.MODE_LOAD] = LoadMode:new(self)
    self.ad.modes[AutoDrive.MODE_BGA] = BGAMode:new(self)
    self.ad.modes[AutoDrive.MODE_UNLOAD] = CombineUnloaderMode:new(self)
end

function AutoDrive:onPostLoad(savegame)
    -- This will run before initial MP sync

    for groupName, _ in pairs(AutoDrive.groups) do
        self.ad.groups[groupName] = false
    end

    if self.isServer then
        if savegame ~= nil then
            local xmlFile = savegame.xmlFile
            local key = savegame.key .. ".FS19_AutoDrive.AutoDrive"

            self.ad.stateModule:readFromXMLFile(xmlFile, key)
            AutoDrive.readVehicleSettingsFromXML(self, xmlFile, key)

            local groupString = getXMLString(xmlFile, key .. "#groups")
            if groupString ~= nil then
                local groupTable = groupString:split(";")
                for _, groupCombined in pairs(groupTable) do
                    local groupNameAndBool = groupCombined:split(",")
                    if tonumber(groupNameAndBool[2]) >= 1 then
                        self.ad.groups[groupNameAndBool[1]] = true
                    else
                        self.ad.groups[groupNameAndBool[1]] = false
                    end
                end
            end
        end

        self.ad.noMovementTimer = AutoDriveTON:new()
        self.ad.noTurningTimer = AutoDriveTON:new()
        self.ad.turningTimer = AutoDriveTON:new()
        self.ad.driveForwardTimer = AutoDriveTON:new()

        if self.spec_pipe ~= nil and self.spec_enterable ~= nil and self.getIsBufferCombine ~= nil then
            ADHarvestManager:registerHarvester(self)
        end
    end

    if self.ad.settings == nil then
        AutoDrive.copySettingsToVehicle(self)
    end

    -- Pure client side state
    self.ad.nToolTipWait = 300
    self.ad.sToolTip = ""
    self.ad.destinationFilterText = ""

    if AutoDrive.showingHud ~= nil then
        self.ad.showingHud = AutoDrive.showingHud
    else
        self.ad.showingHud = true
    end
    self.ad.showingMouse = false

    -- Points used for drawing nearby points without iterating over complete network each time
    self.ad.pointsInProximity = {}
    self.ad.lastPointCheckedForProximity = 1

    self.ad.lastMouseState = false

    -- Creating a new transform on front of the vehicle
    self.ad.frontNode = createTransformGroup(self:getName() .. "_frontNode")
    link(self.components[1].node, self.ad.frontNode)
    setTranslation(self.ad.frontNode, 0, 0, self.sizeLength / 2 + self.lengthOffset + 0.75)
    self.ad.frontNodeGizmo = DebugGizmo:new()

    if self.spec_autodrive == nil then
        self.spec_autodrive = AutoDrive
    end
end

function AutoDrive:onWriteStream(streamId, connection)
    for settingName, setting in pairs(AutoDrive.settings) do
        if setting ~= nil and setting.isVehicleSpecific then
            streamWriteInt16(streamId, AutoDrive.getSettingState(settingName, self))
        end
    end
    self.ad.stateModule:writeStream(streamId)
end

function AutoDrive:onReadStream(streamId, connection)
    for settingName, setting in pairs(AutoDrive.settings) do
        if setting ~= nil and setting.isVehicleSpecific then
            self.ad.settings[settingName].current = streamReadInt16(streamId)
        end
    end
    self.ad.stateModule:readStream(streamId)
end

function AutoDrive:onUpdateTick(dt, isActiveForInput, isActiveForInputIgnoreSelection, isSelected)
end

function AutoDrive:onReadUpdateStream(streamId, timestamp, connection)
    if connection:getIsServer() then
        if streamReadBool(streamId) then
            self.ad.stateModule:readUpdateStream(streamId)
        end
    end
end

function AutoDrive:onWriteUpdateStream(streamId, connection, dirtyMask)
    if not connection:getIsServer() then
        if streamWriteBool(streamId, bitAND(dirtyMask, self.ad.dirtyFlag) ~= 0) then
            self.ad.stateModule:writeUpdateStream(streamId)
        end
    end
end

function AutoDrive:onUpdate(dt)
    -- Cloest point is stored per frame
    self.ad.closest = nil

    self.ad.taskModule:update(dt)
    if self.getIsEntered ~= nil and self:getIsEntered() then
        self.ad.stateModule:update(dt)
    end

    AutoDrive:handleRecording(self)
    ADSensor:handleSensors(self, dt)
    AutoDrive:handleDriverWages(self, dt)

    --For 'legacy' purposes, this value should be kept since other mods already test for this:
    self.ad.isActive = self.ad.stateModule:isActive()
end

function AutoDrive:startAutoDrive()
    if self.isServer then
        self.ad.stateModule:setActive(true)

        self.ad.isStoppingWithError = false
        self.ad.onRouteToPark = false

        if self.getAINeedsTrafficCollisionBox ~= nil then
            if self:getAINeedsTrafficCollisionBox() then
                local collisionRoot = g_i3DManager:loadSharedI3DFile(AIVehicle.TRAFFIC_COLLISION_BOX_FILENAME, self.baseDirectory, false, true, false)
                if collisionRoot ~= nil and collisionRoot ~= 0 then
                    local collision = getChildAt(collisionRoot, 0)
                    link(getRootNode(), collision)
                    self.spec_aiVehicle.aiTrafficCollision = collision
                    delete(collisionRoot)
                end
            end
        end

        g_currentMission:farmStats(self:getOwnerFarmId()):updateStats("driversHired", 1)

        AutoDriveStartStopEvent:sendStartEvent(self)
    else
        g_logManager:devError("AutoDrive:startAutoDrive() must be called only on the server.")
    end
end

function AutoDrive:stopAutoDrive()
    if self.isServer then
        g_currentMission:farmStats(self:getOwnerFarmId()):updateStats("driversHired", -1)
        self.ad.drivePathModule:reset()
        self.ad.specialDrivingModule:reset()
        self.ad.trailerModule:reset()

        for _, mode in pairs(self.ad.modes) do
            mode:reset()
        end

        local hasCallbacks = self.ad.callBackFunction ~= nil and (self.ad.isStoppingWithError == nil or self.ad.isStoppingWithError == false)

        if hasCallbacks then
            --work with copys, so we can remove the callBackObjects before calling the function
            local callBackFunction = self.ad.callBackFunction
            local callBackObject = self.ad.callBackObject
            local callBackArg = self.ad.callBackArg
            self.ad.callBackFunction = nil
            self.ad.callBackObject = nil
            self.ad.callBackArg = nil

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
            AIVehicleUtil.driveInDirection(self, 16, 30, 0, 0.2, 20, false, self.ad.drivingForward, 0, 0, 0, 1)
            self:setCruiseControlState(Drivable.CRUISECONTROL_STATE_OFF)

            if self.ad.onRouteToPark == true then
                self.ad.onRouteToPark = false
                if self.spec_lights ~= nil then
                    self:deactivateLights()
                end
            end

            if self.ad.sensors ~= nil then
                for _, sensor in pairs(self.ad.sensors) do
                    sensor:setEnabled(false)
                end
            end
        end

        if self.setBeaconLightsVisibility ~= nil then
            self:setBeaconLightsVisibility(false)
        end

        self.ad.stateModule:setActive(false)

        self.ad.taskModule:reset()

        AutoDriveStartStopEvent:sendStopEvent(self, hasCallbacks)
    else
        g_logManager:devError("AutoDrive:stopAutoDrive() must be called only on the server.")
    end
end

function AutoDrive:onStartAutoDrive()
    self.forceIsActive = true
    self.spec_motorized.stopMotorOnLeave = false
    self.spec_enterable.disableCharacterOnLeave = false
    self.spec_aiVehicle.isActive = true
    self.steeringEnabled = false

    if self.currentHelper == nil then
        self.currentHelper = g_helperManager:getRandomHelper()
        if self.setRandomVehicleCharacter ~= nil then
            self:setRandomVehicleCharacter()
            self.ad.vehicleCharacter = self.spec_enterable.vehicleCharacter
        end
        if self.spec_enterable.controllerFarmId ~= 0 then
            self.spec_aiVehicle.startedFarmId = self.spec_enterable.controllerFarmId
        end
    end

    AutoDriveHud:createMapHotspot(self)
end

function AutoDrive:onStopAutoDrive(hasCallbacks)
    if not hasCallbacks then
        if self.raiseAIEvent ~= nil then
            self:raiseAIEvent("onAIEnd", "onAIImplementEnd")
        end

        self.spec_aiVehicle.isActive = false
        self.forceIsActive = false
        self.spec_motorized.stopMotorOnLeave = true
        self.spec_enterable.disableCharacterOnLeave = true
        self.currentHelper = nil

        if self.restoreVehicleCharacter ~= nil then
            self:restoreVehicleCharacter()
        end

        if self.steeringEnabled == false then
            self.steeringEnabled = true
        end
    end

    self:requestActionEventUpdate()

    AutoDriveHud:deleteMapHotspot(self)
end

function AutoDrive:onPreLeaveVehicle()
    if self.ad == nil then
        return
    end
    -- We have to do that only for the player who were in the vehicle ( this also fixes mouse cursor hiding bug in MP )
    if self.getIsEntered ~= nil and self:getIsEntered() then
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
end
Enterable.leaveVehicle = Utils.prependedFunction(Enterable.leaveVehicle, AutoDrive.onPreLeaveVehicle)

function AutoDrive:onToggleMouse(vehicle)
    if g_inputBinding:getShowMouseCursor() == true then
        if vehicle.spec_enterable ~= nil then
            if vehicle.spec_enterable.cameras ~= nil then
                for _, camera in pairs(vehicle.spec_enterable.cameras) do
                    camera.allowTranslation = false
                    camera.isRotatable = false
                end
            end
        end
    else
        if vehicle.spec_enterable ~= nil then
            if vehicle.spec_enterable.cameras ~= nil then
                for _, camera in pairs(vehicle.spec_enterable.cameras) do
                    camera.allowTranslation = true
                    camera.isRotatable = true
                end
            end
        end
    end

    vehicle.ad.lastMouseState = g_inputBinding:getShowMouseCursor()
end

function AutoDrive:handleDriverWages(vehicle, dt)
    local spec = vehicle.spec_aiVehicle
    if vehicle.isServer and spec ~= nil then
        if vehicle:getIsAIActive() and spec.startedFarmId ~= nil and spec.startedFarmId > 0 and vehicle.ad.stateModule:isActive() then
            local driverWages = AutoDrive.getSetting("driverWages")
            local difficultyMultiplier = g_currentMission.missionInfo.buyPriceMultiplier
            local price = -dt * difficultyMultiplier * (driverWages - 1) * spec.pricePerMS
            g_currentMission:addMoney(price, spec.startedFarmId, MoneyType.AI, true)
        end
    end
end

function AutoDrive:saveToXMLFile(xmlFile, key)
    self.ad.stateModule:saveToXMLFile(xmlFile, key)

    for settingName, setting in pairs(AutoDrive.settings) do
        if setting.isVehicleSpecific and self.ad.settings ~= nil and self.ad.settings[settingName] ~= nil then
            setXMLInt(xmlFile, key .. "#" .. settingName, self.ad.settings[settingName].current)
        end
    end

    if self.ad.groups ~= nil then
        local combinedString = ""
        for groupName, _ in pairs(AutoDrive.groups) do
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
    if self.ad ~= nil then
        if self.ad.showingHud ~= AutoDrive.Hud.showHud then
            AutoDrive.Hud:toggleHud(self)
        end
    end

    if AutoDrive.getSetting("showNextPath") == true then
        local sWP = self.ad.stateModule:getCurrentWayPoint()
        local eWP = self.ad.stateModule:getNextWayPoint()
        if sWP ~= nil and eWP ~= nil then
            --draw line with direction markers (arrow)
            ADDrawingManager:addLineTask(sWP.x, sWP.y, sWP.z, eWP.x, eWP.y, eWP.z, 1, 1, 1)
            ADDrawingManager:addArrowTask(sWP.x, sWP.y, sWP.z, eWP.x, eWP.y, eWP.z, ADDrawingManager.arrows.position.start, 1, 1, 1)
        end
    end

    if self == g_currentMission.controlledVehicle and (g_dedicatedServerInfo == nil) then
        AutoDrive:onDrawControlledVehicle(self)
    end

    if (self.ad.stateModule:isEditorModeEnabled() or self.ad.stateModule:isEditorShowEnabled()) and self == g_currentMission.controlledVehicle then
        AutoDrive:onDrawCreationMode(self)
    end

    if AutoDrive.experimentalFeatures.redLinePosition and AutoDrive.getDebugChannelIsSet(AutoDrive.DC_VEHICLEINFO) and self.ad.frontNodeGizmo ~= nil then
        self.ad.frontNodeGizmo:createWithNode(self.ad.frontNode, getName(self.ad.frontNode), false)
        self.ad.frontNodeGizmo:draw()
    end
end

function AutoDrive:onDrawControlledVehicle(vehicle)
    if AutoDrive.Hud ~= nil then
        if AutoDrive.Hud.showHud == true then
            AutoDrive.Hud:drawHud(vehicle)
        end
    end
end

function AutoDrive:onDrawCreationMode(vehicle)
    local AutoDriveDM = ADDrawingManager

    local startNode = vehicle.ad.frontNode
    if AutoDrive.getSetting("autoConnectStart") or not AutoDrive.experimentalFeatures.redLinePosition then
        startNode = vehicle.components[1].node
    end

    local x1, y1, z1 = getWorldTranslation(startNode)
    local dy = y1 + 3.5 - AutoDrive.getSetting("lineHeight")

    AutoDrive.drawPointsInProximity(vehicle)

    --Draw close destination (names)
    local maxDistance = AutoDrive.drawDistance
    for _, marker in pairs(ADGraphManager:getMapMarkers()) do
        local wp = ADGraphManager:getWayPointById(marker.id)
        if AutoDrive.getDistance(wp.x, wp.z, x1, z1) < maxDistance then
            Utils.renderTextAtWorldPosition(wp.x, wp.y + 4, wp.z, marker.name, getCorrectTextSize(0.013), 0)
            if not (vehicle.ad.stateModule:getEditorMode() == ADStateModule.EDITOR_EXTENDED) then
                AutoDriveDM:addMarkerTask(wp.x, wp.y + 0.45, wp.z)
            end
        end
    end

    if ADGraphManager:getWayPointById(1) ~= nil and not vehicle.ad.stateModule:isEditorShowEnabled() then
        local g = 0

        --Draw line to selected neighbor point
        local neighbour = vehicle.ad.stateModule:getSelectedNeighbourPoint()
        if neighbour ~= nil then
            AutoDriveDM:addLineTask(x1, dy, z1, neighbour.x, neighbour.y, neighbour.z, 1, 1, 0)
            g = 0.4
        end

        --Draw line to closest point
        local closest, _ = ADGraphManager:findClosestWayPoint(vehicle)
        local wp = ADGraphManager:getWayPointById(closest)
        AutoDriveDM:addLineTask(x1, dy, z1, wp.x, wp.y, wp.z, 1, 0, 0)
        AutoDriveDM:addSmallSphereTask(x1, dy, z1, 1, g, 0)
    end
end

function AutoDrive.getNewPointsInProximity(vehicle)
    local x1, _, z1 = getWorldTranslation(vehicle.components[1].node)
    local maxDistance = AutoDrive.drawDistance

    if ADGraphManager:getWayPointById(1) ~= nil then
        local newPointsToDraw = {}
        local pointsCheckedThisFrame = 0
        --only handly a limited amount of points per frame
        while pointsCheckedThisFrame < 1000 and pointsCheckedThisFrame < ADGraphManager:getWayPointsCount() do
            pointsCheckedThisFrame = pointsCheckedThisFrame + 1
            vehicle.ad.lastPointCheckedForProximity = vehicle.ad.lastPointCheckedForProximity + 1
            if vehicle.ad.lastPointCheckedForProximity > ADGraphManager:getWayPointsCount() then
                vehicle.ad.lastPointCheckedForProximity = 1
            end
            local pointToCheck = ADGraphManager:getWayPointById(vehicle.ad.lastPointCheckedForProximity)
            if pointToCheck ~= nil then
                if AutoDrive.getDistance(pointToCheck.x, pointToCheck.z, x1, z1) < maxDistance then
                    table.insert(newPointsToDraw, pointToCheck.id, pointToCheck)
                end
            end
        end
        --go through all stored points to check if they are still in proximity
        for id, point in pairs(vehicle.ad.pointsInProximity) do
            if AutoDrive.getDistance(point.x, point.z, x1, z1) < maxDistance and newPointsToDraw[id] == nil and ADGraphManager:getWayPointById(id) ~= nil then
                table.insert(newPointsToDraw, id, point)
            end
        end
        --replace stored list with update
        vehicle.ad.pointsInProximity = newPointsToDraw
    end
end

function AutoDrive.mouseIsAtPos(position, radius)
    local x, y, _ = project(position.x, position.y + AutoDrive.drawHeight + AutoDrive.getSetting("lineHeight"), position.z)

    if g_lastMousePosX < (x + radius) and g_lastMousePosX > (x - radius) then
        if g_lastMousePosY < (y + radius) and g_lastMousePosY > (y - radius) then
            return true
        end
    end

    return false
end

function AutoDrive.drawPointsInProximity(vehicle)
    local AutoDriveDM = ADDrawingManager
    local arrowPosition = AutoDriveDM.arrows.position.start
    AutoDrive.getNewPointsInProximity(vehicle)

    for _, point in pairs(vehicle.ad.pointsInProximity) do
        local x = point.x
        local y = point.y
        local z = point.z
        if vehicle.ad.stateModule:isInExtendedEditorMode() then
            arrowPosition = AutoDriveDM.arrows.position.middle
            if AutoDrive.mouseIsAtPos(point, 0.01) then
                AutoDriveDM:addSphereTask(x, y, z, 3, 0, 0, 1, 0.3)
            else
                if point.id == vehicle.ad.selectedNodeId then
                    AutoDriveDM:addSphereTask(x, y, z, 3, 0, 1, 0, 0.3)
                else
                    AutoDriveDM:addSphereTask(x, y, z, 3, 1, 0, 0, 0.3)
                end
            end

            -- If the lines are drawn above the vehicle, we have to draw a line to the reference point on the ground and a second cube there for moving the node position
            if AutoDrive.getSettingState("lineHeight") > 1 then
                local gy = y - AutoDrive.drawHeight - AutoDrive.getSetting("lineHeight")
                AutoDriveDM:addLineTask(x, y, z, x, gy, z, 1, 1, 1)

                if AutoDrive.mouseIsAtPos(point, 0.01) or AutoDrive.mouseIsAtPos({x = x, y = gy, z = z}, 0.01) then
                    AutoDriveDM:addSphereTask(x, gy, z, 3, 0, 0, 1, 0.15)
                else
                    if point.id == vehicle.ad.selectedNodeId then
                        AutoDriveDM:addSphereTask(x, gy, z, 3, 0, 1, 0, 0.15)
                    else
                        AutoDriveDM:addSphereTask(x, gy, z, 3, 1, 0, 0, 0.15)
                    end
                end
            end
        end

        if point.out ~= nil then
            for _, neighbor in pairs(point.out) do
                local target = ADGraphManager:getWayPointById(neighbor)
                if target ~= nil then
                    --check if outgoing connection is a dual way connection
                    local nWp = ADGraphManager:getWayPointById(neighbor)
                    if table.contains(point.incoming, neighbor) then
                        --draw simple line
                        AutoDriveDM:addLineTask(x, y, z, nWp.x, nWp.y, nWp.z, 0, 0, 1)
                    else
                        --draw line with direction markers (arrow)
                        AutoDriveDM:addLineTask(x, y, z, nWp.x, nWp.y, nWp.z, 0, 1, 0)
                        AutoDriveDM:addArrowTask(x, y, z, nWp.x, nWp.y, nWp.z, arrowPosition, 0, 1, 0)
                    end
                end
            end
        end

        if not vehicle.ad.stateModule:isInExtendedEditorMode() then
            --just a quick way to highlight single (forgotten) points with no connections
            if (#point.out == 0) and (#point.incoming == 0) then
                AutoDriveDM:addSphereTask(x, y, z, 1.5, 1, 0, 0, 0.1)
            end
        end
    end
end

function AutoDrive:toggleRecording(vehicle, dual)
    if not vehicle.ad.stateModule:isInCreationMode() then
        if dual then
            vehicle.ad.stateModule:startDualCreationMode()
        else
            vehicle.ad.stateModule:startNormalCreationMode()
        end
        vehicle:stopAutoDrive()
    else
        vehicle.ad.stateModule:disableCreationMode()

        if AutoDrive.getSetting("autoConnectEnd") then
            if vehicle.ad.lastCreatedWp ~= nil then
                local targetID = ADGraphManager:findMatchingWayPointForVehicle(vehicle)
                if targetID ~= nil then
                    local targetNode = ADGraphManager:getWayPointById(targetID)
                    if targetNode ~= nil then
                        ADGraphManager:toggleConnectionBetween(vehicle.ad.lastCreatedWp, targetNode)
                        if dual == true then
                            ADGraphManager:toggleConnectionBetween(targetNode, vehicle.ad.lastCreatedWp)
                        end
                    end
                end
            end
        end

        vehicle.ad.lastCreatedWp = nil
        vehicle.ad.secondLastCreatedWp = nil
    end
end

function AutoDrive:handleRecording(vehicle)
    if vehicle == nil or vehicle.ad.stateModule:isInCreationMode() == false then
        return
    end

    if g_server == nil then
        return
    end

    --first entry
    if vehicle.ad.lastCreatedWp == nil and vehicle.ad.secondLastCreatedWp == nil then
        local startNodeId, _ = ADGraphManager:findClosestWayPoint(vehicle)
        local x1, y1, z1 = getWorldTranslation(vehicle.components[1].node)
        vehicle.ad.lastCreatedWp = ADGraphManager:recordWayPoint(x1, y1, z1, false, vehicle.ad.stateModule:isInDualCreationMode())

        if AutoDrive.getSetting("autoConnectStart") then
            if startNodeId ~= nil then
                local startNode = ADGraphManager:getWayPointById(startNodeId)
                if startNode ~= nil then
                    if ADGraphManager:getDistanceBetweenNodes(startNodeId, vehicle.ad.lastCreatedWp.id) < 20 then
                        ADGraphManager:toggleConnectionBetween(startNode, vehicle.ad.lastCreatedWp)
                        if vehicle.ad.stateModule:isInDualCreationMode() then
                            ADGraphManager:toggleConnectionBetween(vehicle.ad.lastCreatedWp, startNode)
                        end
                    end
                end
            end
        end
    else
        if vehicle.ad.secondLastCreatedWp == nil then
            local x, y, z = getWorldTranslation(vehicle.components[1].node)
            local wp = vehicle.ad.lastCreatedWp
            if AutoDrive.getDistance(x, z, wp.x, wp.z) > 3 then
                vehicle.ad.secondLastCreatedWp = vehicle.ad.lastCreatedWp
                vehicle.ad.lastCreatedWp = ADGraphManager:recordWayPoint(x, y, z, true, vehicle.ad.stateModule:isInDualCreationMode())
            end
        else
            local x, y, z = getWorldTranslation(vehicle.components[1].node)
            local angle = math.abs(AutoDrive.angleBetween({x = x - vehicle.ad.secondLastCreatedWp.x, z = z - vehicle.ad.secondLastCreatedWp.z}, {x = vehicle.ad.lastCreatedWp.x - vehicle.ad.secondLastCreatedWp.x, z = vehicle.ad.lastCreatedWp.z - vehicle.ad.secondLastCreatedWp.z}))
            local max_distance = 6
            if angle < 1 then
                max_distance = 6
            elseif angle < 3 then
                max_distance = 4
            elseif angle < 5 then
                max_distance = 3
            elseif angle < 8 then
                max_distance = 2
            elseif angle < 15 then
                max_distance = 1
            elseif angle < 50 then
                max_distance = 0.5
            end

            if AutoDrive.getDistance(x, z, vehicle.ad.lastCreatedWp.x, vehicle.ad.lastCreatedWp.z) > max_distance then
                vehicle.ad.secondLastCreatedWp = vehicle.ad.lastCreatedWp
                vehicle.ad.lastCreatedWp = ADGraphManager:recordWayPoint(x, y, z, true, vehicle.ad.stateModule:isInDualCreationMode())
            end
        end
    end
end

function AutoDrive:preRemoveVehicle(vehicle)
    if vehicle.ad ~= nil and vehicle.ad.stateModule ~= nil and vehicle.ad.stateModule:isActive() then
        vehicle:stopAutoDrive()
    end
end
FSBaseMission.removeVehicle = Utils.prependedFunction(FSBaseMission.removeVehicle, AutoDrive.preRemoveVehicle)

function AutoDrive:onDelete()
    AutoDriveHud:deleteMapHotspot(self)
end

function AutoDrive:updateAILights(superFunc)
    if self.ad ~= nil and self.ad.stateModule:isActive() then
        -- If AutoDrive is active, then we take care of lights our self
        local spec = self.spec_lights
        local dayMinutes = g_currentMission.environment.dayTime / (1000 * 60)
        local needLights = (dayMinutes > g_currentMission.environment.nightStartMinutes or dayMinutes < g_currentMission.environment.nightEndMinutes)
        if needLights then
            local x, y, z = getWorldTranslation(self.components[1].node)
            if spec.lightsTypesMask ~= spec.aiLightsTypesMask and AutoDrive.checkIsOnField(x, y, z) then
                self:setLightsTypesMask(spec.aiLightsTypesMask)
            end
            if spec.lightsTypesMask ~= 1 and not AutoDrive.checkIsOnField(x, y, z) then
                self:setLightsTypesMask(1)
            end
        else
            if spec.lightsTypesMask ~= 0 then
                self:setLightsTypesMask(0)
            end
        end
        return
    else
        superFunc(self)
    end
end

function AutoDrive:getCanMotorRun(superFunc)
    if self.ad ~= nil and self.ad.stateModule:isActive() and self.ad.specialDrivingModule:shouldStopMotor() then
        return false
    else
        return superFunc(self)
    end
end
