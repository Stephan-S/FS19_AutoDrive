ADHarvestManager = {}

ADHarvestManager.MAX_PREDRIVE_LEVEL = 0.96

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
                if ADHarvestManager.doesHarvesterNeedUnloading(harvester) or ADHarvestManager.isHarvesterActive(harvester) then
                    for _, unloader in pairs(self.idleUnloaders) do
                        -- sort by distance to combine first
                        if unloader.ad.stateModule:getFirstMarker() == harvester.ad.stateModule:getFirstMarker() then
                            unloader.ad.modes[AutoDrive.MODE_UNLOAD]:assignToHarvester(harvester)
                            table.insert(self.activeUnloaders, unloader)
                            table.removeValue(self.idleUnloaders, unloader)
                            break
                        end
                    end
                end
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
    return (((maxCapacity > 0 and leftCapacity < maxCapacity) or cpIsCalling) and harvester.ad.noMovementTimer.elapsedTime > 5000)
end

function ADHarvestManager.isHarvesterActive(harvester)
    if harvester:getIsBufferCombine() then
        return true
    else
        if AutoDrive.getSetting("preCallDriver", harvester) then
            local fillLevel, leftCapacity = AutoDrive.getFilteredFillLevelAndCapacityOfAllUnits(harvester)
            local maxCapacity = fillLevel + leftCapacity
            local fillPercent = (fillLevel / maxCapacity)
            local reachedPreCallLevel = fillPercent >= AutoDrive.getSetting("preCallLevel", harvester)
            local isAlmostFull = fillPercent >= ADHarvestManager.MAX_PREDRIVE_LEVEL

            return reachedPreCallLevel and (not isAlmostFull)
        end
    end
    
    return false
end

function ADHarvestManager:alreadyAssignedUnloader(harvester)
    for _, unloader in pairs(self.activeUnloaders) do
       if unloader.ad.modes[AutoDrive.MODE_UNLOAD].combine == harvester then
            return true
       end
    end
    return false
end