function AutoDrive.prerequisitesPresent(specializations)
    return SpecializationUtil.hasSpecialization(Motorized, specializations) and SpecializationUtil.hasSpecialization(Drivable, specializations) and SpecializationUtil.hasSpecialization(Enterable, specializations)
end

function AutoDrive.registerEventListeners(vehicleType)
    for _, n in pairs({"load", "onUpdate", "onRegisterActionEvents", "onDelete", "onDraw", "onPostLoad", "onLoad", "saveToXMLFile", "onReadStream", "onWriteStream", "onReadUpdateStream", "onWriteUpdateStream", "onUpdateTick"}) do
        SpecializationUtil.registerEventListener(vehicleType, n, AutoDrive)
    end
end

function AutoDrive.registerOverwrittenFunctions(vehicleType)
    SpecializationUtil.registerOverwrittenFunction(vehicleType, "updateAILights", AutoDrive.updateAILights)
    SpecializationUtil.registerOverwrittenFunction(vehicleType, "getCanMotorRun", AutoDrive.getCanMotorRun)
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

    self.ad.dirtyFlag = self:getNextDirtyFlag()
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
    if g_server ~= nil then
        if self.ad.stateModule:isDirty() then
            self:raiseDirtyFlags(self.ad.dirtyFlag)
        end
    end
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
end

function AutoDrive:onPreLeaveVehicle()
    if self.ad == nil then
        return
    end
    -- We have to do that only for the player who were in the vehicle ( this also fix mouse cursor hiding bug in MP )
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
        local wps, currentWp = self.ad.drivePathModule:getWayPoints()
        if wps ~= nil and currentWp ~= nil and currentWp > 0 and wps[currentWp] ~= nil and wps[currentWp + 1] ~= nil then
            --draw line with direction markers (arrow)
            local sWP = wps[currentWp]
            local eWP = wps[currentWp + 1]
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
        while pointsCheckedThisFrame < 1000 and pointsCheckedThisFrame < ADGraphManager:getWayPointCount() do
            pointsCheckedThisFrame = pointsCheckedThisFrame + 1
            vehicle.ad.lastPointCheckedForProximity = vehicle.ad.lastPointCheckedForProximity + 1
            if vehicle.ad.lastPointCheckedForProximity > ADGraphManager:getWayPointCount() then
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
        AutoDrive.disableAutoDriveFunctions(vehicle)
    else
        vehicle.ad.stateModule:disableCreationMode()

        if AutoDrive.getSetting("autoConnectEnd") then
            if vehicle.ad.lastCreatedWp ~= nil then
                local targetID = ADGraphManager:findMatchingWayPointForVehicle(vehicle)
                if targetID ~= nil then
                    local targetNode = ADGraphManager:getWayPointById(targetID)
                    if targetNode ~= nil then
                        targetNode.incoming[#targetNode.incoming + 1] = vehicle.ad.lastCreatedWp.id
                        vehicle.ad.lastCreatedWp.out[#vehicle.ad.lastCreatedWp.out + 1] = targetNode.id
                        if dual == true then
                            targetNode.out[#targetNode.out + 1] = vehicle.ad.lastCreatedWp.id
                            vehicle.ad.lastCreatedWp.incoming[#vehicle.ad.lastCreatedWp.incoming + 1] = targetNode.id
                        end

                        AutoDriveCourseEditEvent:sendEvent(targetNode)
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
        local startPoint, _ = ADGraphManager:findClosestWayPoint(vehicle)
        local x1, y1, z1 = getWorldTranslation(vehicle.components[1].node)
        vehicle.ad.lastCreatedWp = ADGraphManager:createWayPoint(vehicle, x1, y1, z1, false)

        if AutoDrive.getSetting("autoConnectStart") then
            if startPoint ~= nil then
                local startNode = ADGraphManager:getWayPointById(startPoint)
                if startNode ~= nil then
                    if ADGraphManager:getDistanceBetweenNodes(startPoint, vehicle.ad.lastCreatedWp.id) < 20 then
                        table.insert(startNode.out, vehicle.ad.lastCreatedWp.id)
                        table.insert(vehicle.ad.lastCreatedWp.incoming, startNode.id)

                        if vehicle.ad.stateModule:isInDualCreationMode() then
                            table.insert(ADGraphManager:getWayPointById(startPoint).incoming, vehicle.ad.lastCreatedWp.id)
                            table.insert(vehicle.ad.lastCreatedWp.out, startPoint)
                        end

                        AutoDriveCourseEditEvent:sendEvent(startNode)
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
                vehicle.ad.lastCreatedWp = ADGraphManager:createWayPoint(vehicle, x, y, z, true)
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
                vehicle.ad.lastCreatedWp = ADGraphManager:createWayPoint(vehicle, x, y, z, true)
            end
        end
    end
end

function AutoDrive:preRemoveVehicle(vehicle)
    if vehicle.ad ~= nil and vehicle.ad.stateModule ~= nil and vehicle.ad.stateModule:isActive() then
        AutoDrive.disableAutoDriveFunctions(vehicle)
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

AIVehicleUtil.driveInDirection = function(self, dt, steeringAngleLimit, acceleration, slowAcceleration, slowAngleLimit, allowedToDrive, moveForwards, lx, lz, maxSpeed, slowDownFactor)
    if self.getMotorStartTime ~= nil then
        allowedToDrive = allowedToDrive and (self:getMotorStartTime() <= g_currentMission.time)
    end

    if self.ad ~= nil and AutoDrive.experimentalFeatures.smootherDriving then
        if self.ad.stateModule:isActive() and allowedToDrive then
            --slowAngleLimit = 90 -- Set it to high value since we don't need the slow down

            local accFactor = 2 / 1000 -- km h / s converted to km h / ms
            accFactor = accFactor + math.abs((maxSpeed - self.lastSpeedReal * 3600) / 2000) -- Changing accFactor based on missing speed to reach target (useful for sudden braking)
            if self.ad.smootherDriving.lastMaxSpeed < maxSpeed then
                self.ad.smootherDriving.lastMaxSpeed = math.min(self.ad.smootherDriving.lastMaxSpeed + accFactor / 2 * dt, maxSpeed)
            else
                self.ad.smootherDriving.lastMaxSpeed = math.max(self.ad.smootherDriving.lastMaxSpeed - accFactor * dt, maxSpeed)
            end

            if maxSpeed < 1 then
                -- Hard braking, is needed to prevent combine's pipe overstep and crash
                self.ad.smootherDriving.lastMaxSpeed = maxSpeed
            end
            --AutoDrive.renderTable(0.1, 0.9, 0.012, {maxSpeed = maxSpeed, lastMaxSpeed = self.ad.smootherDriving.lastMaxSpeed})
            maxSpeed = self.ad.smootherDriving.lastMaxSpeed
        else
            self.ad.smootherDriving.lastMaxSpeed = 0
        end
    end

    local angle = 0
    if lx ~= nil and lz ~= nil then
        local dot = lz
        angle = math.deg(math.acos(dot))
        if angle < 0 then
            angle = angle + 180
        end
        local turnLeft = lx > 0.00001
        if not moveForwards then
            turnLeft = not turnLeft
        end
        local targetRotTime = 0
        if turnLeft then
            --rotate to the left
            targetRotTime = self.maxRotTime * math.min(angle / steeringAngleLimit, 1)
        else
            --rotate to the right
            targetRotTime = self.minRotTime * math.min(angle / steeringAngleLimit, 1)
        end
        if targetRotTime > self.rotatedTime then
            self.rotatedTime = math.min(self.rotatedTime + dt * self:getAISteeringSpeed(), targetRotTime)
        else
            self.rotatedTime = math.max(self.rotatedTime - dt * self:getAISteeringSpeed(), targetRotTime)
        end
    end
    if self.firstTimeRun then
        local acc = acceleration
        if maxSpeed ~= nil and maxSpeed ~= 0 then
            if math.abs(angle) >= slowAngleLimit then
                maxSpeed = maxSpeed * slowDownFactor
            end
            self.spec_motorized.motor:setSpeedLimit(maxSpeed)
            if self.spec_drivable.cruiseControl.state ~= Drivable.CRUISECONTROL_STATE_ACTIVE then
                self:setCruiseControlState(Drivable.CRUISECONTROL_STATE_ACTIVE)
            end
        else
            if math.abs(angle) >= slowAngleLimit then
                acc = slowAcceleration
            end
        end
        if not allowedToDrive then
            acc = 0
        end
        if not moveForwards then
            acc = -acc
        end
        --FS 17 Version WheelsUtil.updateWheelsPhysics(self, dt, self.lastSpeedReal, acc, not allowedToDrive, self.requiredDriveMode);
        WheelsUtil.updateWheelsPhysics(self, dt, self.lastSpeedReal * self.movingDirection, acc, not allowedToDrive, true)
    end
end

function AIVehicle:onUpdateTick(dt, isActiveForInput, isActiveForInputIgnoreSelection, isSelected)
    local spec = self.spec_aiVehicle

    if self.isClient then
        local actionEvent = spec.actionEvents[InputAction.TOGGLE_AI]
        if actionEvent ~= nil then
            local showAction = false

            if self:getIsActiveForInput(true, true) then
                -- If ai is active we always display the dismiss helper action
                -- But only if the AutoDrive is not active :)
                showAction = self:getCanStartAIVehicle() or (self:getIsAIActive() and (self.ad == nil or not self.ad.stateModule:isActive()))

                if showAction then
                    if self:getIsAIActive() then
                        g_inputBinding:setActionEventText(actionEvent.actionEventId, g_i18n:getText("action_dismissEmployee"))
                    else
                        g_inputBinding:setActionEventText(actionEvent.actionEventId, g_i18n:getText("action_hireEmployee"))
                    end
                end
            end

            g_inputBinding:setActionEventActive(actionEvent.actionEventId, showAction)
        end
    end
end
