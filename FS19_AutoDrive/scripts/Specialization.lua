function AutoDrive.prerequisitesPresent(specializations)
    return SpecializationUtil.hasSpecialization(Motorized, specializations) and SpecializationUtil.hasSpecialization(Drivable, specializations) and SpecializationUtil.hasSpecialization(Enterable, specializations)
end

function AutoDrive.registerEventListeners(vehicleType)
    for _, n in pairs(
        {
            "onUpdate",
            "onRegisterActionEvents",
            "onDelete",
            "onDraw",
            "onPreLoad",
            "onPostLoad",
            "onLoad",
            "saveToXMLFile",
            "onReadStream",
            "onWriteStream",
            "onReadUpdateStream",
            "onWriteUpdateStream",
            "onUpdateTick",
            "onStartAutoDrive",
            "onStopAutoDrive",
            "onPostAttachImplement",
            "onPreDetachImplement",
            "onEnterVehicle"
        }
    ) do
        SpecializationUtil.registerEventListener(vehicleType, n, AutoDrive)
    end
end

function AutoDrive.registerOverwrittenFunctions(vehicleType)
    SpecializationUtil.registerOverwrittenFunction(vehicleType, "updateAILights", AutoDrive.updateAILights)
    SpecializationUtil.registerOverwrittenFunction(vehicleType, "getCanMotorRun", AutoDrive.getCanMotorRun)
    SpecializationUtil.registerOverwrittenFunction(vehicleType, "leaveVehicle", AutoDrive.leaveVehicle)
end

function AutoDrive.registerFunctions(vehicleType)
    SpecializationUtil.registerFunction(vehicleType, "startAutoDrive", AutoDrive.startAutoDrive)
    SpecializationUtil.registerFunction(vehicleType, "stopAutoDrive", AutoDrive.stopAutoDrive)
    SpecializationUtil.registerFunction(vehicleType, "toggleMouse", AutoDrive.toggleMouse)
    SpecializationUtil.registerFunction(vehicleType, "updateWayPointsDistance", AutoDrive.updateWayPointsDistance)
    SpecializationUtil.registerFunction(vehicleType, "resetClosestWayPoint", AutoDrive.resetClosestWayPoint)
    SpecializationUtil.registerFunction(vehicleType, "resetWayPointsDistance", AutoDrive.resetWayPointsDistance)
    SpecializationUtil.registerFunction(vehicleType, "getWayPointsDistance", AutoDrive.getWayPointsDistance)
    SpecializationUtil.registerFunction(vehicleType, "getClosestWayPoint", AutoDrive.getClosestWayPoint)
    SpecializationUtil.registerFunction(vehicleType, "getClosestNotReversedWayPoint", AutoDrive.getClosestNotReversedWayPoint)
    SpecializationUtil.registerFunction(vehicleType, "getWayPointsInRange", AutoDrive.getWayPointsInRange)
    SpecializationUtil.registerFunction(vehicleType, "getWayPointIdsInRange", AutoDrive.getWayPointIdsInRange)
    SpecializationUtil.registerFunction(vehicleType, "onDrawEditorMode", AutoDrive.onDrawEditorMode)
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

function AutoDrive:onPreLoad(savegame)
    if self.spec_autodrive == nil then
        self.spec_autodrive = AutoDrive
    end
end

function AutoDrive:onLoad(savegame)
    -- This will run before initial MP sync
    self.ad = {}
    self.ad.dirtyFlag = self:getNextDirtyFlag()
    self.ad.smootherDriving = {}
    self.ad.smootherDriving.lastMaxSpeed = 0
    self.ad.groups = {}

    self.ad.distances = {}
    self.ad.distances.wayPoints = nil
    self.ad.distances.closest = {}
    self.ad.distances.closest.wayPoint = -1
    self.ad.distances.closest.distance = 0
    self.ad.distances.closestNotReverse = {}
    self.ad.distances.closestNotReverse.wayPoint = -1
    self.ad.distances.closestNotReverse.distance = 0

    self.ad.stateModule = ADStateModule:new(self)
    self.ad.recordingModule = ADRecordingModule:new(self)
    self.ad.trailerModule = ADTrailerModule:new(self)
    self.ad.taskModule = ADTaskModule:new(self)
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

    self.ad.onRouteToPark = false
    self.ad.isStoppingWithError = false
end

function AutoDrive:onPostLoad(savegame)
    -- This will run before initial MP sync
    --print("Running post load for vehicle: " .. self:getName())

    for groupName, _ in pairs(ADGraphManager:getGroups()) do
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
    end

    if self.spec_pipe ~= nil and self.spec_enterable ~= nil and self.getIsBufferCombine ~= nil then
        ADHarvestManager:registerHarvester(self)
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

    self.ad.lastMouseState = false

    -- Creating a new transform on front of the vehicle
    self.ad.frontNode = createTransformGroup(self:getName() .. "_frontNode")
    link(self.components[1].node, self.ad.frontNode)
    setTranslation(self.ad.frontNode, 0, 0, self.sizeLength / 2 + self.lengthOffset + 0.75)
    self.ad.frontNodeGizmo = DebugGizmo:new()
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
    -- waypoints distances are updated once every ~2 frames
    self:resetClosestWayPoint()
    -- if we want to update distances every frame, when lines drawing is enabled, we can move this at the end of onDraw function
    self:resetWayPointsDistance()

    if self.isServer then
        self.ad.recordingModule:updateTick(dt, isActiveForInput, isActiveForInputIgnoreSelection, isSelected)

        local spec = self.spec_aiVehicle
        if self:getIsAIActive() and spec.startedFarmId ~= nil and spec.startedFarmId > 0 and self.ad.stateModule:isActive() then
            local driverWages = AutoDrive.getSetting("driverWages")
            local difficultyMultiplier = g_currentMission.missionInfo.buyPriceMultiplier
            local price = -dt * difficultyMultiplier * (driverWages - 1) * spec.pricePerMS
            g_currentMission:addMoney(price, spec.startedFarmId, MoneyType.AI, true)
        end
    end

    if self.ad.lastMouseState ~= g_inputBinding:getShowMouseCursor() then
        self:toggleMouse()
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
    if self.isServer and self.ad.stateModule:isActive() then
        self.ad.recordingModule:update(dt)
        self.ad.taskModule:update(dt)
        if self.lastMovedDistance > 0 then
            g_currentMission:farmStats(self:getOwnerFarmId()):updateStats("driversTraveledDistance", self.lastMovedDistance * 0.001)
        end
    end

    if self.getIsEntered ~= nil and self:getIsEntered() then
        self.ad.stateModule:update(dt)
    end

    ADSensor:handleSensors(self, dt)

    if not self.ad.stateModule:isActive() then
        self.ad.taskModule:abortAllTasks()
    end

    --For 'legacy' purposes, this value should be kept since other mods already test for this:
    self.ad.isActive = self.ad.stateModule:isActive()
    self.ad.mapMarkerSelected = self.ad.stateModule:getFirstMarkerId()
    self.ad.mapMarkerSelected_Unload = self.ad.stateModule:getSecondMarkerId()
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
        for groupName, _ in pairs(ADGraphManager:getGroups()) do
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
    if self.ad.showingHud ~= AutoDrive.Hud.showHud then
        AutoDrive.Hud:toggleHud(self)
    end

    if AutoDrive.Hud ~= nil then
        if AutoDrive.Hud.showHud == true then
            AutoDrive.Hud:drawHud(self)
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

    if (self.ad.stateModule:isEditorModeEnabled() or self.ad.stateModule:isEditorShowEnabled()) then
        self:onDrawEditorMode()
    end

    if AutoDrive.experimentalFeatures.redLinePosition and AutoDrive.getDebugChannelIsSet(AutoDrive.DC_VEHICLEINFO) and self.ad.frontNodeGizmo ~= nil then
        self.ad.frontNodeGizmo:createWithNode(self.ad.frontNode, getName(self.ad.frontNode), false)
        self.ad.frontNodeGizmo:draw()
    end

    local x, y, z = getWorldTranslation(self.components[1].node)
    if AutoDrive.getDebugChannelIsSet(AutoDrive.DC_PATHINFO) then
        for _, otherVehicle in pairs(g_currentMission.vehicles) do
            if otherVehicle ~= nil and otherVehicle.ad ~= nil and otherVehicle.ad.drivePathModule ~= nil and otherVehicle.ad.drivePathModule:getWayPoints() ~= nil and not otherVehicle.ad.drivePathModule:isTargetReached() then
                local currentIndex = otherVehicle.ad.drivePathModule:getCurrentWayPointIndex()

                local lastPoint = nil
                for index, point in ipairs(otherVehicle.ad.drivePathModule:getWayPoints()) do
                    if point.isPathFinderPoint and index >= currentIndex and lastPoint ~= nil and MathUtil.vector2Length(x - point.x, z - point.z) < 160 then
                        ADDrawingManager:addLineTask(lastPoint.x, lastPoint.y, lastPoint.z, point.x, point.y, point.z, 1, 0.09, 0.09)
                        ADDrawingManager:addArrowTask(lastPoint.x, lastPoint.y, lastPoint.z, point.x, point.y, point.z, ADDrawingManager.arrows.position.start, 1, 0.09, 0.09)

                        if AutoDrive.getSettingState("lineHeight") == 1 then
                            local gy = point.y - AutoDrive.drawHeight + 4
                            local ty = lastPoint.y - AutoDrive.drawHeight + 4
                            ADDrawingManager:addLineTask(point.x, gy, point.z, point.x, point.y, point.z, 1, 0.09, 0.09)
                            ADDrawingManager:addSphereTask(point.x, gy, point.z, 3, 1, 0.09, 0.09, 0.15)
                            ADDrawingManager:addLineTask(lastPoint.x, ty, lastPoint.z, point.x, gy, point.z, 1, 0.09, 0.09)
                            ADDrawingManager:addArrowTask(lastPoint.x, ty, lastPoint.z, point.x, gy, point.z, ADDrawingManager.arrows.position.start, 1, 0.09, 0.09)
                        else
                            local gy = point.y - AutoDrive.drawHeight - 4
                            local ty = lastPoint.y - AutoDrive.drawHeight - 4
                            ADDrawingManager:addLineTask(point.x, gy, point.z, point.x, point.y, point.z, 1, 0.09, 0.09)
                            ADDrawingManager:addSphereTask(point.x, gy, point.z, 3, 1, 0.09, 0.09, 0.15)
                            ADDrawingManager:addLineTask(lastPoint.x, ty, lastPoint.z, point.x, gy, point.z, 1, 0.09, 0.09)
                            ADDrawingManager:addArrowTask(lastPoint.x, ty, lastPoint.z, point.x, gy, point.z, ADDrawingManager.arrows.position.start, 1, 0.09, 0.09)
                        end
                    end
                    lastPoint = point
                end
            end
        end

        for _, otherVehicle in pairs(g_currentMission.vehicles) do
            if otherVehicle ~= nil and otherVehicle.ad ~= nil and otherVehicle.ad.drivePathModule ~= nil and otherVehicle.ad.modes[AutoDrive.MODE_UNLOAD]:getBreadCrumbs() ~= nil then
                local lastPoint = nil
                for index, point in ipairs(otherVehicle.ad.modes[AutoDrive.MODE_UNLOAD]:getBreadCrumbs().items) do
                    if lastPoint ~= nil and MathUtil.vector2Length(x - point.x, z - point.z) < 80 then
                        ADDrawingManager:addLineTask(lastPoint.x, lastPoint.y, lastPoint.z, point.x, point.y, point.z, 1.0, 0.769, 0.051)
                        ADDrawingManager:addArrowTask(lastPoint.x, lastPoint.y, lastPoint.z, point.x, point.y, point.z, ADDrawingManager.arrows.position.start, 1.0, 0.769, 0.051)

                        if AutoDrive.getSettingState("lineHeight") == 1 then
                            local gy = point.y - AutoDrive.drawHeight + 4
                            local ty = lastPoint.y - AutoDrive.drawHeight + 4
                            ADDrawingManager:addLineTask(point.x, gy, point.z, point.x, point.y, point.z, 1.0, 0.769, 0.051)
                            ADDrawingManager:addSphereTask(point.x, gy, point.z, 3, 1.0, 0.769, 0.051, 0.15)
                            ADDrawingManager:addLineTask(lastPoint.x, ty, lastPoint.z, point.x, gy, point.z, 1.0, 0.769, 0.051)
                            ADDrawingManager:addArrowTask(lastPoint.x, ty, lastPoint.z, point.x, gy, point.z, ADDrawingManager.arrows.position.start, 1.0, 0.769, 0.051)
                        else
                            local gy = point.y - AutoDrive.drawHeight - 4
                            local ty = lastPoint.y - AutoDrive.drawHeight - 4
                            ADDrawingManager:addLineTask(point.x, gy, point.z, point.x, point.y, point.z, 1.0, 0.769, 0.051)
                            ADDrawingManager:addSphereTask(point.x, gy, point.z, 3, 1.0, 0.769, 0.051, 0.15)
                            ADDrawingManager:addLineTask(lastPoint.x, ty, lastPoint.z, point.x, gy, point.z, 1.0, 0.769, 0.051)
                            ADDrawingManager:addArrowTask(lastPoint.x, ty, lastPoint.z, point.x, gy, point.z, ADDrawingManager.arrows.position.start, 1.0, 0.769, 0.051)
                        end
                    end
                    lastPoint = point
                end
            end
        end
    end
end

function AutoDrive:onPostAttachImplement(attachable, inputJointDescIndex, jointDescIndex)
    if attachable["spec_FS19_addon_strawHarvest.strawHarvestPelletizer"] ~= nil then
        attachable.isPremos = true
        attachable.getIsBufferCombine = function()
            return false
        end
    end
    if (attachable.spec_pipe ~= nil and attachable.getIsBufferCombine ~= nil) or attachable.isPremos then
        attachable.isTrailedHarvester = true
        attachable.trailingVehicle = self
        ADHarvestManager:registerHarvester(attachable)
        self.ad.isCombine = true
        attachable.ad = self.ad
    end

    local supportedFillTypes = {}
    for _, trailer in pairs(AutoDrive.getTrailersOf(self, false)) do
        if trailer.getFillUnits ~= nil then
            for fillUnitIndex, _ in pairs(trailer:getFillUnits()) do
                if trailer.getFillUnitSupportedFillTypes ~= nil then
                    for fillType, supported in pairs(trailer:getFillUnitSupportedFillTypes(fillUnitIndex)) do
                        if supported then
                            table.insert(supportedFillTypes, fillType)
                        end
                    end
                end
            end
        end
    end

    local storedSelectedFillType = self.ad.stateModule:getFillType()
    if #supportedFillTypes > 0 and not table.contains(supportedFillTypes, storedSelectedFillType) then
        self.ad.stateModule:setFillType(supportedFillTypes[1])
        AutoDrive.Hud.lastUIScale = 0
    end
end

function AutoDrive:onPreDetachImplement(implement)
    local attachable = implement.object
    if attachable.isTrailedHarvester and attachable.trailingVehicle == self then
        attachable.ad = nil
        self.ad.isCombine = false
        ADHarvestManager:unregisterHarvester(attachable)
        attachable.isTrailedHarvester = false
        attachable.trailingVehicle = nil
        if attachable.isPremos then
            attachable.getIsBufferCombine = nil
        end
    end
    if self.ad ~= nil then
        self.ad.frontToolWidth = nil
        self.ad.frontToolLength = nil
    end
end

function AutoDrive:onEnterVehicle()
    AutoDrive.Hud.lastUIScale = 0
end

function AutoDrive:onDelete()
    AutoDriveHud:deleteMapHotspot(self)
end

function AutoDrive:onDrawEditorMode()
    local DrawingManager = ADDrawingManager

    local startNode = self.ad.frontNode
    if not AutoDrive.experimentalFeatures.redLinePosition then
        startNode = self.components[1].node
    end
    local x1, y1, z1 = getWorldTranslation(startNode)

    local dy = y1 + 3.5 - AutoDrive.getSetting("lineHeight")
    local maxDistance = AutoDrive.drawDistance
    local arrowPosition = DrawingManager.arrows.position.start

    --Draw close destinations
    for _, marker in pairs(ADGraphManager:getMapMarkers()) do
        local wp = ADGraphManager:getWayPointById(marker.id)
        if MathUtil.vector2Length(wp.x - x1, wp.z - z1) < maxDistance then
            Utils.renderTextAtWorldPosition(wp.x, wp.y + 4, wp.z, marker.name, getCorrectTextSize(0.013), 0)
            DrawingManager:addMarkerTask(wp.x, wp.y + 0.45, wp.z)
        end
    end

    if ADGraphManager:getWayPointById(1) ~= nil and not self.ad.stateModule:isEditorShowEnabled() then
        local g = 0
        --Draw line to selected neighbor point
        local neighbour = self.ad.stateModule:getSelectedNeighbourPoint()
        if neighbour ~= nil then
            DrawingManager:addLineTask(x1, dy, z1, neighbour.x, neighbour.y, neighbour.z, 1, 1, 0)
            g = 0.4
        end

        --Draw line to closest point
        local closest, _ = self:getClosestWayPoint()
        local wp = ADGraphManager:getWayPointById(closest)
        if wp ~= nil then
            DrawingManager:addLineTask(x1, dy, z1, wp.x, wp.y, wp.z, 1, 0, 0)
            DrawingManager:addSmallSphereTask(x1, dy, z1, 1, g, 0)
        end
    end

    local outPointsSeen = {}
    for _, point in pairs(self:getWayPointsInRange(0, maxDistance)) do
        local x = point.x
        local y = point.y
        local z = point.z
        if self.ad.stateModule:isInExtendedEditorMode() then
            arrowPosition = DrawingManager.arrows.position.middle
            if AutoDrive.mouseIsAtPos(point, 0.01) then
                DrawingManager:addSphereTask(x, y, z, 3, 0, 0, 1, 0.3)
            else
                if point.id == self.ad.selectedNodeId then
                    DrawingManager:addSphereTask(x, y, z, 3, 0, 1, 0, 0.3)
                else
                    DrawingManager:addSphereTask(x, y, z, 3, 1, 0, 0, 0.3)
                end
            end

            -- If the lines are drawn above the vehicle, we have to draw a line to the reference point on the ground and a second cube there for moving the node position
            if AutoDrive.getSettingState("lineHeight") > 1 then
                local gy = y - AutoDrive.drawHeight - AutoDrive.getSetting("lineHeight")
                DrawingManager:addLineTask(x, y, z, x, gy, z, 1, 1, 1)

                if AutoDrive.mouseIsAtPos(point, 0.01) or AutoDrive.mouseIsAtPos({x = x, y = gy, z = z}, 0.01) then
                    DrawingManager:addSphereTask(x, gy, z, 3, 0, 0, 1, 0.15)
                else
                    if point.id == self.ad.selectedNodeId then
                        DrawingManager:addSphereTask(x, gy, z, 3, 0, 1, 0, 0.15)
                    else
                        DrawingManager:addSphereTask(x, gy, z, 3, 1, 0, 0, 0.15)
                    end
                end
            end
        end

        if point.out ~= nil then
            for _, neighbor in pairs(point.out) do
                table.insert(outPointsSeen, neighbor)
                local target = ADGraphManager:getWayPointById(neighbor)
                if target ~= nil then
                    --check if outgoing connection is a dual way connection
                    local nWp = ADGraphManager:getWayPointById(neighbor)
                    if point.incoming == nil or table.contains(point.incoming, neighbor) then
                        --draw simple line
                        DrawingManager:addLineTask(x, y, z, nWp.x, nWp.y, nWp.z, 0, 0, 1)
                    else
                        --draw line with direction markers (arrow)
                        if (nWp.incoming == nil or table.contains(nWp.incoming, point.id)) or not AutoDrive.experimentalFeatures.reverseDrivingAllowed then
                            DrawingManager:addLineTask(x, y, z, nWp.x, nWp.y, nWp.z, 0, 1, 0)
                            DrawingManager:addArrowTask(x, y, z, nWp.x, nWp.y, nWp.z, arrowPosition, 0, 1, 0)
                        else
                            DrawingManager:addLineTask(x, y, z, nWp.x, nWp.y, nWp.z, 0.0, 0.569, 0.835)
                            DrawingManager:addArrowTask(x, y, z, nWp.x, nWp.y, nWp.z, arrowPosition, 0.0, 0.569, 0.835)
                        end
                    end
                end
            end
        end

        --just a quick way to highlight single (forgotten) points with no connections
        if (#point.out == 0) and (#point.incoming == 0) and not table.contains(outPointsSeen, point.id) then
            y = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, x, 1, z) + 0.5
            DrawingManager:addCrossTask(x, y, z)
        end
    end
end

function AutoDrive:startAutoDrive()
    if self.isServer then
        if not self.ad.stateModule:isActive() then
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
        end
    else
        g_logManager:devError("AutoDrive:startAutoDrive() must be called only on the server.")
    end
    --[[
    for i = 1, #g_fruitTypeManager.fruitTypes do
        local fruitType = g_fruitTypeManager.fruitTypes[i].index
        print("FruitType: "  .. fruitType .. ": " .. g_fillTypeManager:getFillTypeByIndex(g_fruitTypeManager:getFillTypeIndexByFruitTypeIndex(fruitType)).title)
    end
    --]]
end

function AutoDrive:stopAutoDrive()
    if self.isServer then
        if self.ad.stateModule:isActive() then
            g_currentMission:farmStats(self:getOwnerFarmId()):updateStats("driversHired", -1)
            self.ad.drivePathModule:reset()
            self.ad.specialDrivingModule:reset()
            self.ad.trailerModule:reset()

            for _, mode in pairs(self.ad.modes) do
                mode:reset()
            end

            local hasCallbacks = self.ad.callBackFunction ~= nil and self.ad.isStoppingWithError == false

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

                self.ad.callBackFunction = nil
                self.ad.callBackObject = nil
                self.ad.callBackArg = nil
            else
                AIVehicleUtil.driveInDirection(self, 16, 30, 0, 0.2, 20, false, self.ad.drivingForward, 0, 0, 0, 1)
                self:setCruiseControlState(Drivable.CRUISECONTROL_STATE_OFF)

                if self.ad.onRouteToPark and not self.ad.isStoppingWithError then
                    self.ad.onRouteToPark = false
                    if self.deactivateLights ~= nil then
                        self:deactivateLights()
                    end
                    if self.stopMotor ~= nil then
                        self:stopMotor()
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

            self.ad.taskModule:abortAllTasks()
            self.ad.taskModule:reset()

            local isStartingAIVE = (not self.ad.isStoppingWithError and self.ad.stateModule:getStartAI() and not self.ad.stateModule:getUseCP())
            local isPassingToCP = hasCallbacks or (not self.ad.isStoppingWithError and self.ad.stateModule:getStartAI() and self.ad.stateModule:getUseCP())
            AutoDriveStartStopEvent:sendStopEvent(self, isPassingToCP, isStartingAIVE)

            if not hasCallbacks and not self.ad.isStoppingWithError then
                if self.ad.stateModule:getStartAI() then
                    self.ad.stateModule:setStartAI(false)
                    if  g_courseplay ~= nil and self.ad.stateModule:getUseCP() then
                        g_courseplay.courseplay:start(self)
                    else
                        if self.acParameters ~= nil then
                            self.acParameters.enabled = true
                            self:startAIVehicle(nil, false, self.spec_aiVehicle.startedFarmId)
                        end
                    end
                end
            end
        end
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

function AutoDrive:onStopAutoDrive(hasCallbacks, isStartingAIVE)
    if not hasCallbacks then
        if self.raiseAIEvent ~= nil and not isStartingAIVE then
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

function AutoDrive:updateWayPointsDistance()
    self.ad.distances.wayPoints = {}
    self.ad.distances.closest.wayPoint = nil
    self.ad.distances.closest.distance = math.huge
    self.ad.distances.closestNotReverse.wayPoint = nil
    self.ad.distances.closestNotReverse.distance = math.huge

    local x, _, z = getWorldTranslation(self.components[1].node)

    --We should see some perfomance increase by localizing the sqrt/pow functions right here
    local sqrt = math.sqrt
    local distanceFunc = function(a, b)
        return sqrt(a * a + b * b)
    end
    for _, wp in pairs(ADGraphManager:getWayPoints()) do
        local distance = distanceFunc(wp.x - x, wp.z - z)
        if distance < self.ad.distances.closest.distance then
            self.ad.distances.closest.distance = distance
            self.ad.distances.closest.wayPoint = wp
        end
        if distance <= AutoDrive.drawDistance then
            table.insert(self.ad.distances.wayPoints, {distance = distance, wayPoint = wp})
        end
        if distance < self.ad.distances.closestNotReverse.distance and (wp.incoming == nil or #wp.incoming > 0) then
            self.ad.distances.closestNotReverse.distance = distance
            self.ad.distances.closestNotReverse.wayPoint = wp
        end
    end
end

function AutoDrive:resetClosestWayPoint()
    self.ad.distances.closest.wayPoint = -1
end

function AutoDrive:resetWayPointsDistance()
    self.ad.distances.wayPoints = nil
end

function AutoDrive:getWayPointsDistance()
    return self.ad.distances.wayPoints
end

function AutoDrive:getClosestWayPoint()
    if self.ad.distances.closest.wayPoint == -1 then
        self:updateWayPointsDistance()
    end
    if self.ad.distances.closest.wayPoint ~= nil then
        return self.ad.distances.closest.wayPoint.id, self.ad.distances.closest.distance
    end
    return -1, math.huge
end

function AutoDrive:getClosestNotReversedWayPoint()
    if self.ad.distances.closestNotReverse.wayPoint == -1 then
        self:updateWayPointsDistance()
    end
    if self.ad.distances.closestNotReverse.wayPoint ~= nil then
        return self.ad.distances.closestNotReverse.wayPoint.id, self.ad.distances.closestNotReverse.distance
    end
    return -1, math.huge
end

function AutoDrive:getWayPointsInRange(minDistance, maxDistance)
    if self.ad.distances.wayPoints == nil then
        self:updateWayPointsDistance()
    end
    local inRange = {}
    for _, elem in pairs(self.ad.distances.wayPoints) do
        if elem.distance >= minDistance and elem.distance <= maxDistance and elem.wayPoint.id > 0 then
            table.insert(inRange, elem.wayPoint)
        end
    end
    return inRange
end

function AutoDrive:getWayPointIdsInRange(minDistance, maxDistance)
    if self.ad.distances.wayPoints == nil then
        self:updateWayPointsDistance()
    end
    local inRange = {}
    for _, elem in pairs(self.ad.distances.wayPoints) do
        if elem.distance >= minDistance and elem.distance <= maxDistance and elem.wayPoint.id > 0 then
            table.insert(inRange, elem.wayPoint.id)
        end
    end
    return inRange
end

function AutoDrive:toggleMouse()
    if g_inputBinding:getShowMouseCursor() then
        if self.spec_enterable ~= nil and self.spec_enterable.cameras ~= nil then
            for _, camera in pairs(self.spec_enterable.cameras) do
                camera.allowTranslation = false
                camera.isRotatable = false
            end
        end
    else
        if self.spec_enterable ~= nil and self.spec_enterable.cameras ~= nil then
            for _, camera in pairs(self.spec_enterable.cameras) do
                camera.allowTranslation = true
                camera.isRotatable = true
            end
        end
    end
    self.ad.lastMouseState = g_inputBinding:getShowMouseCursor()
end

function AutoDrive:leaveVehicle(superFunc)
    if self.ad ~= nil then
        if self.getIsEntered ~= nil and self:getIsEntered() then
            if g_inputBinding:getShowMouseCursor() then
                g_inputBinding:setShowMouseCursor(false)
            end
            AutoDrive.Hud:closeAllPullDownLists(self)
        end
    end
    superFunc(self)
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
