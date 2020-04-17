ADHarvestManager = {}

ADHarvestManager.MAX_PREDRIVE_LEVEL = 0.85
ADHarvestManager.MAX_SEARCH_RANGE = 300

function ADHarvestManager:load()
    self.harvesters = {}
    self.idleHarvesters = {}
    self.activeUnloaders = {}
    self.idleUnloaders = {}
    self.assignmentDelayTimer = AutoDriveTON:new()
end

function ADHarvestManager:registerHarvester(harvester)
    AutoDrive.debugPrint(harvester, AutoDrive.DC_COMBINEINFO, "ADHarvestManager:registerHarvester")
    if not table.contains(self.idleHarvesters, harvester) and not table.contains(self.harvesters, harvester) then
        AutoDrive.debugPrint(harvester, AutoDrive.DC_COMBINEINFO, "ADHarvestManager:registerHarvester - inserted")
        if harvester ~= nil and harvester.ad ~= nil then
            harvester.ad.isCombine = true
        end
        if g_server ~= nil then
            table.insert(self.idleHarvesters, harvester)
        end
    end
end

function ADHarvestManager:unregisterHarvester(harvester)
    AutoDrive.debugPrint(harvester, AutoDrive.DC_COMBINEINFO, "ADHarvestManager:unregisterHarvester")
    if harvester ~= nil and harvester.ad ~= nil then
        harvester.ad.isCombine = false
    end
    if g_server ~= nil then
        if table.contains(self.idleHarvesters, harvester) then
            local index = table.indexOf(self.idleHarvesters, harvester)
            local harvester = table.remove(self.idleHarvesters, index)
            AutoDrive.debugPrint(harvester, AutoDrive.DC_COMBINEINFO, "ADHarvestManager:unregisterHarvester - removed - idleHarvesters")
        end
        if table.contains(self.harvesters, harvester) then
            local index = table.indexOf(self.harvesters, harvester)
            local harvester = table.remove(self.harvesters, index)
            AutoDrive.debugPrint(harvester, AutoDrive.DC_COMBINEINFO, "ADHarvestManager:unregisterHarvester - removed - harvesters")
        end
    end
end

function ADHarvestManager:registerAsUnloader(vehicle)
    AutoDrive.debugPrint(vehicle, AutoDrive.DC_COMBINEINFO, "ADHarvestManager:registerAsUnloader")
    --remove from active and idle list
    self:unregisterAsUnloader(vehicle)
    if not table.contains(self.idleUnloaders, vehicle) then
        AutoDrive.debugPrint(vehicle, AutoDrive.DC_COMBINEINFO, "ADHarvestManager:registerAsUnloader - inserted")
        table.insert(self.idleUnloaders, vehicle)
    end
end

function ADHarvestManager:unregisterAsUnloader(vehicle)
    if vehicle.ad.modes ~= nil and vehicle.ad.modes[AutoDrive.MODE_UNLOAD] ~= nil then
        local followingUnloder = vehicle.ad.modes[AutoDrive.MODE_UNLOAD]:getFollowingUnloader()
        if followingUnloder ~= nil then
            --promote following unloader to current unloader
            followingUnloder.ad.modes[AutoDrive.MODE_UNLOAD]:promoteFollowingUnloader(vehicle.ad.modes[AutoDrive.MODE_UNLOAD].combine)
        end
    end
    if table.contains(self.idleUnloaders, vehicle) then
        table.removeValue(self.idleUnloaders, vehicle)
    end
    if table.contains(self.activeUnloaders, vehicle) then
        table.removeValue(self.activeUnloaders, vehicle)
        if g_currentMission.controlledVehicle ~= nil and vehicle == g_currentMission.controlledVehicle then
            --Give the player some time to reset/reposition the fired unloader
            self.assignmentDelayTimer:timer(false)
        else
            --Only short delay for AI controlled unloader being removed
            self.assignmentDelayTimer:timer(false)
            self.assignmentDelayTimer.elapsedTime = 10000
        end
    end
end

function ADHarvestManager:fireUnloader(unloader)
    if unloader.ad.stateModule:isActive() then
        local follower = unloader.ad.modes[AutoDrive.MODE_UNLOAD]:getFollowingUnloader()
        if follower ~= nil then
            follower.ad.taskModule:abortAllTasks()
            follower.ad.taskModule:addTask(StopAndDisableADTask:new(follower, ADTaskModule.DONT_PROPAGATE, true))
        end
        unloader.ad.taskModule:abortAllTasks()
        unloader.ad.taskModule:addTask(StopAndDisableADTask:new(unloader, ADTaskModule.DONT_PROPAGATE, true))
    end
    self:unregisterAsUnloader(unloader)
end

function ADHarvestManager:update(dt)
    self.assignmentDelayTimer:timer(true, 10000, dt)
    for _, idleHarvester in pairs(self.idleHarvesters) do
        local vehicle = idleHarvester
        if vehicle.isTrailedHarvester then
            vehicle = vehicle.trailingVehicle
        end
        if (vehicle.spec_aiVehicle ~= nil and vehicle.spec_aiVehicle.isActive) or (vehicle.getIsEntered ~= nil and vehicle:getIsEntered()) then
            table.insert(self.harvesters, idleHarvester)
            table.removeValue(self.idleHarvesters, idleHarvester)
        end
    end
    for _, harvester in pairs(self.harvesters) do
        local vehicle = harvester
        if vehicle.isTrailedHarvester then
            vehicle = vehicle.trailingVehicle
        end
        if not ((vehicle.spec_aiVehicle ~= nil and vehicle.spec_aiVehicle.isActive) or (vehicle.getIsEntered ~= nil and vehicle:getIsEntered())) then
            table.insert(self.idleHarvesters, harvester)
            table.removeValue(self.harvesters, harvester)

            local unloader = self:getAssignedUnloader(harvester)
            if unloader ~= nil then
                self:fireUnloader(unloader)
            end
        end
    end

    for _, harvester in pairs(self.harvesters) do
        if harvester ~= nil and g_currentMission.nodeToObject[harvester.components[1].node] ~= nil and entityExists(harvester.components[1].node) then
            if self.assignmentDelayTimer:done() then
                if not self:alreadyAssignedUnloader(harvester) then
                    if ADHarvestManager.doesHarvesterNeedUnloading(harvester) or ((not AutoDrive.combineIsTurning(harvester)) and ADHarvestManager.isHarvesterActive(harvester)) then
                        self:assignUnloaderToHarvester(harvester)
                    end
                else
                    if AutoDrive.getSetting("callSecondUnloader", harvester) then
                        local unloader = self:getAssignedUnloader(harvester)
                        if unloader.ad.modes[AutoDrive.MODE_UNLOAD]:getFollowingUnloader() == nil then
                            local trailers, _ = AutoDrive.getTrailersOf(unloader, false)
                            local fillLevel, leftCapacity = AutoDrive.getFillLevelAndCapacityOfAll(trailers)
                            local maxCapacity = fillLevel + leftCapacity
                            if fillLevel >= (maxCapacity * AutoDrive.getSetting("preCallLevel", harvester)) then
                                local closestUnloader = self:getClosestIdleUnloader(harvester)
                                if closestUnloader ~= nil then
                                    closestUnloader.ad.modes[AutoDrive.MODE_UNLOAD]:driveToUnloader(unloader)
                                end
                            end
                        end
                    end
                end
            end

            if (harvester.ad ~= nil and harvester.ad.noMovementTimer ~= nil and harvester.lastSpeedReal ~= nil) then
                harvester.ad.noMovementTimer:timer((harvester.lastSpeedReal <= 0.0004), 3000, dt)

                local vehicleSteering = false --harvester.rotatedTime ~= nil and (math.deg(harvester.rotatedTime) > 10)
                if (not vehicleSteering) and ((harvester.lastSpeedReal * harvester.movingDirection) >= 0.0004) then
                    harvester.ad.driveForwardTimer:timer(true, 4000, dt)
                else
                    harvester.ad.driveForwardTimer:timer(false)
                end
            end

            if (harvester.ad ~= nil and harvester.ad.noTurningTimer ~= nil) then
                local cpIsTurning = harvester.cp ~= nil and (harvester.cp.isTurning or (harvester.cp.turnStage ~= nil and harvester.cp.turnStage > 0))
                local cpIsTurningTwo = harvester.cp ~= nil and harvester.cp.driver and (harvester.cp.driver.turnIsDriving or (harvester.cp.driver.fieldworkState ~= nil and harvester.cp.driver.fieldworkState == harvester.cp.driver.states.TURNING))
                local aiIsTurning = (harvester.getAIIsTurning ~= nil and harvester:getAIIsTurning() == true)
                local combineSteering = harvester.rotatedTime ~= nil and (math.deg(harvester.rotatedTime) > 20)
                local combineIsTurning = cpIsTurning or cpIsTurningTwo or aiIsTurning or combineSteering
                harvester.ad.noTurningTimer:timer((not combineIsTurning), 4000, dt)
                harvester.ad.turningTimer:timer(combineIsTurning, 4000, dt)
            end
        else
            table.removeValue(self.harvesters, harvester)
        end
    end

    if AutoDrive.getDebugChannelIsSet(AutoDrive.DC_COMBINEINFO) then
        local debug = {}
        debug.harvesters = {}
        for _, harvester in pairs(self.harvesters) do
            local infoTable = {}
            infoTable.name = harvester:getName()
            if self:getAssignedUnloader(harvester) ~= nil then
                infoTable.unloader = self:getAssignedUnloader(harvester):getName()
            end
            if self:getAssignedUnloader(harvester) ~= nil and self:getAssignedUnloader(harvester).ad.modes[AutoDrive.MODE_UNLOAD]:getFollowingUnloader() ~= nil then
                infoTable.follower = self:getAssignedUnloader(harvester).ad.modes[AutoDrive.MODE_UNLOAD]:getFollowingUnloader():getName()
            end
            table.insert(debug.harvesters, infoTable)
        end
        debug.idleUnloaders = {}
        for _, idleUnloader in pairs(self.idleUnloaders) do
            local infoTable = {}
            infoTable.name = idleUnloader:getName()
            if idleUnloader.ad.modes[AutoDrive.MODE_UNLOAD].combine ~= nil then
                infoTable.unloader = idleUnloader.ad.modes[AutoDrive.MODE_UNLOAD].combine:getName()
            end
            if idleUnloader.ad.modes[AutoDrive.MODE_UNLOAD]:getFollowingUnloader() ~= nil then
                infoTable.follower = idleUnloader.ad.modes[AutoDrive.MODE_UNLOAD]:getFollowingUnloader():getName()
            end
            table.insert(debug.idleUnloaders, infoTable)
        end
        debug.activeUnloaders = {}
        for _, activeUnloader in pairs(self.activeUnloaders) do
            local infoTable = {}
            infoTable.name = activeUnloader:getName()
            if activeUnloader.ad.modes[AutoDrive.MODE_UNLOAD].combine ~= nil then
                infoTable.unloader = activeUnloader.ad.modes[AutoDrive.MODE_UNLOAD].combine:getName()
            end
            if activeUnloader.ad.modes[AutoDrive.MODE_UNLOAD]:getFollowingUnloader() ~= nil then
                infoTable.follower = activeUnloader.ad.modes[AutoDrive.MODE_UNLOAD]:getFollowingUnloader():getName()
            end
            table.insert(debug.activeUnloaders, infoTable)
        end
        debug.delayTimer = self.assignmentDelayTimer.elapsedTime
        AutoDrive.renderTable(0.65, 0.6, 0.014, debug, 3)
    end
end

function ADHarvestManager.doesHarvesterNeedUnloading(harvester, ignorePipe)
    local fillLevel, leftCapacity = AutoDrive.getFilteredFillLevelAndCapacityOfAllUnits(harvester)
    local maxCapacity = fillLevel + leftCapacity

    local cpIsCalling = false
    if harvester.cp and harvester.cp.driver and harvester.cp.driver.isWaitingForUnload then
        cpIsCalling = harvester.cp.driver:isWaitingForUnload()
    end

    local pipeOut = AutoDrive.isPipeOut(harvester)
    return (((maxCapacity > 0 and leftCapacity < 1.0) or cpIsCalling) and (pipeOut or ignorePipe) and harvester.ad.noMovementTimer.elapsedTime > 5000)
end

function ADHarvestManager.isHarvesterActive(harvester)
    if harvester:getIsBufferCombine() then
        return true
    else
        local fillLevel, leftCapacity = AutoDrive.getFilteredFillLevelAndCapacityOfAllUnits(harvester)
        local maxCapacity = fillLevel + leftCapacity
        local fillPercent = (fillLevel / maxCapacity)
        local reachedPreCallLevel = fillPercent >= AutoDrive.getSetting("preCallLevel", harvester)
        local isAlmostFull = fillPercent >= ADHarvestManager.MAX_PREDRIVE_LEVEL
               
        -- Only chase the rear on low fill levels of the combine. This should prevent getting into unneccessarily tight spots for the final approach to the pipe.
        -- Also for small fields, there is often no purpose in chasing so far behind the combine as it will already start a turn soon
        local allowedToChase = true
        if not AutoDrive.isSugarcaneHarvester(harvester) then
            local chasingRear = false
            local pipeSide = AutoDrive.getPipeSide(harvester)
            if pipeSide == AutoDrive.CHASEPOS_LEFT then
                local leftBlocked = harvester.ad.sensors.leftSensorFruit:pollInfo() or harvester.ad.sensors.leftSensor:pollInfo() or (AutoDrive.getSetting("followOnlyOnField") and (not harvester.ad.sensors.leftSensorField:pollInfo()))
                local leftFrontBlocked = harvester.ad.sensors.leftFrontSensorFruit:pollInfo() or harvester.ad.sensors.leftFrontSensor:pollInfo()
                chasingRear = leftBlocked or leftFrontBlocked
            else
                local rightBlocked = harvester.ad.sensors.rightSensorFruit:pollInfo() or harvester.ad.sensors.rightSensor:pollInfo() or (AutoDrive.getSetting("followOnlyOnField") and (not harvester.ad.sensors.rightSensorField:pollInfo()))
                local rightBlockedBlocked = harvester.ad.sensors.rightFrontSensorFruit:pollInfo() or harvester.ad.sensors.rightFrontSensor:pollInfo()
                chasingRear = rightBlocked or rightBlockedBlocked
            end

            if fillPercent > 0.9 or (fillPercent > 0.7 and chasingRear) then
                allowedToChase = false
            end
        end

        return reachedPreCallLevel and (not isAlmostFull) and allowedToChase
    end

    return false
end

function ADHarvestManager:assignUnloaderToHarvester(harvester)
    local closestUnloader = self:getClosestIdleUnloader(harvester)
    if closestUnloader ~= nil then
        closestUnloader.ad.modes[AutoDrive.MODE_UNLOAD]:assignToHarvester(harvester)
        table.insert(self.activeUnloaders, closestUnloader)
        table.removeValue(self.idleUnloaders, closestUnloader)
    end
end

function ADHarvestManager:alreadyAssignedUnloader(harvester)
    for _, unloader in pairs(self.activeUnloaders) do
        if unloader.ad.modes[AutoDrive.MODE_UNLOAD].combine == harvester then
            return true
        end
    end
    return false
end

function ADHarvestManager:getAssignedUnloader(harvester)
    for _, unloader in pairs(self.activeUnloaders) do
        if unloader.ad.modes[AutoDrive.MODE_UNLOAD].combine == harvester then
            return unloader
        end
    end
    return nil
end

function ADHarvestManager:getClosestIdleUnloader(harvester)
    local closestUnloader = nil
    local closestDistance = math.huge
    for _, unloader in pairs(self.idleUnloaders) do
        -- sort by distance to combine first
        local distance = AutoDrive.getDistanceBetween(unloader, harvester)
        local distanceMatch = distance <= ADHarvestManager.MAX_SEARCH_RANGE and AutoDrive.getSetting("findDriver")
        local targetsMatch = unloader.ad.stateModule:getFirstMarker() == harvester.ad.stateModule:getFirstMarker()
        if distanceMatch or targetsMatch then
            if closestUnloader == nil or distance < closestDistance then
                closestUnloader = unloader
                closestDistance = distance
            end
        end
    end
    return closestUnloader
end
