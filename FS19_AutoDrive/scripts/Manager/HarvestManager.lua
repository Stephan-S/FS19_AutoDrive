ADHarvestManager = {}

ADHarvestManager.MAX_PREDRIVE_LEVEL = 0.96
ADHarvestManager.MAX_SEARCH_RANGE = 300

function ADHarvestManager:load()
    self.harvesters = {}
    self.activeUnloaders = {}
    self.idleUnloaders = {}
end

function ADHarvestManager:registerHarvester(harvester)
    if not table.contains(self.harvesters, harvester) then
        table.insert(self.harvesters, harvester)
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
            followingUnloder.ad.modes[AutoDrive.MODE_UNLOAD].combine = vehicle.ad.modes[AutoDrive.MODE_UNLOAD].combine
        end
    end
    if table.contains(self.idleUnloaders, vehicle) then
        table.removeValue(self.idleUnloaders, vehicle)
    end
    if table.contains(self.activeUnloaders, vehicle) then
        table.removeValue(self.activeUnloaders, vehicle)
    end
end

function ADHarvestManager:update()
    for _, harvester in pairs(self.harvesters) do
        if harvester ~= nil then
            if not self:alreadyAssignedUnloader(harvester) then
                if  ADHarvestManager.doesHarvesterNeedUnloading(harvester) or (not AutoDrive.combineIsTurning(harvester) and ADHarvestManager.isHarvesterActive(harvester)) then
                    self:assignUnloaderToHarvester(harvester)
                end
            --[[
            else
                local unloader = self:getAssignedUnloader(harvester)
                if unloader.ad.modes[AutoDrive.MODE_UNLOAD]:getFollowingUnloader() == nil then                
                    local trailers, _ = AutoDrive.getTrailersOf(unloader, false)
                    local fillLevel, leftCapacity = AutoDrive.getFillLevelAndCapacityOfAll(trailers)
                    local maxCapacity = fillLevel + leftCapacity
                    if leftCapacity < (maxCapacity * AutoDrive.getSetting("preCallLevel", harvester)) then
                        local closestUnloader = self:getClosestIdleUnloader(harvester)
                        if closestUnloader ~= nil then
                            closestUnloader.ad.modes[AutoDrive.MODE_UNLOAD]:driveToUnloader(unloader)
                        end
                    end
                end
                --]]
            end
        end
    end
end

function ADHarvestManager.doesHarvesterNeedUnloading(harvester)
    local fillLevel, leftCapacity = AutoDrive.getFilteredFillLevelAndCapacityOfAllUnits(harvester)
    local maxCapacity = fillLevel + leftCapacity

    local cpIsCalling = false
    if harvester.cp and harvester.cp.driver and harvester.cp.driver.isWaitingForUnload then
        cpIsCalling = harvester.cp.driver:isWaitingForUnload()
    end
    return (((maxCapacity > 0 and leftCapacity < 1.0) or cpIsCalling) and harvester.ad.noMovementTimer.elapsedTime > 5000)
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

        return reachedPreCallLevel and (not isAlmostFull)
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