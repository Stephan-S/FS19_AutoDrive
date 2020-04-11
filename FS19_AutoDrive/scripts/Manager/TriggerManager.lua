ADTriggerManager = {}

ADTriggerManager.tipTriggers = {}
ADTriggerManager.siloTriggers = {}

ADTriggerManager.searchedForTriggers = false

AutoDrive.MAX_REFUEL_TRIGGER_DISTANCE = 15
AutoDrive.REFUEL_LEVEL = 0.15

function ADTriggerManager.load()
end

function ADTriggerManager:update(dt)
    for _, trigger in pairs(self:getLoadTriggers()) do
        if trigger.stoppedTimer == nil then
            trigger.stoppedTimer = AutoDriveTON:new()
        end
        trigger.stoppedTimer:timer(not trigger.isLoading, 300, dt)
    end
end

function ADTriggerManager.checkForTriggerProximity(vehicle, distanceToTarget)
    local shouldLoad = vehicle.ad.stateModule:getCurrentMode():shouldLoadOnTrigger()
    local shouldUnload = vehicle.ad.stateModule:getCurrentMode():shouldUnloadAtTrigger()
    if (not shouldUnload) and (not shouldLoad) or distanceToTarget == nil then
        return false
    end

    local x, y, z = getWorldTranslation(vehicle.components[1].node)
    local allFillables, _ = AutoDrive.getTrailersOf(vehicle, false)

    local totalMass = vehicle:getTotalMass(false)
    local massFactor = math.max(1, math.min(3, (totalMass + 20) / 30))
    if vehicle.lastSpeedReal * 3600 < 15 then
        massFactor = 1
    end
    local speedFactor = math.max(0.5, math.min(4, (((vehicle.lastSpeedReal * 3600) + 10) / 20.0)))
    local distanceToSlowDownAt = 15 * speedFactor * massFactor

    if vehicle.ad.trailerModule:isActiveAtTrigger() then
        return true
    end

    if shouldLoad then
        for _, trigger in pairs(ADTriggerManager.siloTriggers) do
            local triggerX, _, triggerZ = ADTriggerManager.getTriggerPos(trigger)
            if triggerX ~= nil then
                local distance = MathUtil.vector2Length(triggerX - x, triggerZ - z)

                if distance < distanceToSlowDownAt and distanceToTarget < AutoDrive.getSetting("maxTriggerDistance") then
                    local hasRequiredFillType = false
                    local allowedFillTypes = {vehicle.ad.stateModule:getFillType()}
                    if vehicle.ad.stateModule:getFillType() == 13 or vehicle.ad.stateModule:getFillType() == 43 or vehicle.ad.stateModule:getFillType() == 44 then
                        allowedFillTypes = {}
                        table.insert(allowedFillTypes, 13)
                        table.insert(allowedFillTypes, 43)
                        table.insert(allowedFillTypes, 44)
                    end

                    for _, trailer in pairs(allFillables) do
                        hasRequiredFillType = hasRequiredFillType or AutoDrive.fillTypesMatch(vehicle, trigger, trailer, allowedFillTypes)
                    end

                    if hasRequiredFillType then
                        return true
                    end
                end
            end
        end
    end

    if shouldUnload then
        for _, trigger in pairs(ADTriggerManager.tipTriggers) do
            local triggerX, _, triggerZ = ADTriggerManager.getTriggerPos(trigger)
            if triggerX ~= nil then
                local distance = MathUtil.vector2Length(triggerX - x, triggerZ - z)
                if distance < distanceToSlowDownAt and (distanceToTarget < AutoDrive.getSetting("maxTriggerDistance") or (trigger.bunkerSiloArea ~= nil and distanceToTarget < 300)) then
                    return true
                end
            end
        end
    end

    return false
end

function ADTriggerManager.loadAllTriggers()
    ADTriggerManager.searchedForTriggers = true
    ADTriggerManager.tipTriggers = {}
    ADTriggerManager.siloTriggers = {}
    for _, ownedItem in pairs(g_currentMission.ownedItems) do
        if ownedItem.storeItem ~= nil then
            if ownedItem.storeItem.categoryName == "SILOS" then
                for _, item in pairs(ownedItem.items) do
                    if item.unloadingStation ~= nil then
                        for _, unloadTrigger in pairs(item.unloadingStation.unloadTriggers) do
                            table.insert(ADTriggerManager.tipTriggers, unloadTrigger)
                        end
                    end

                    if item.loadingStation ~= nil then
                        for _, loadTrigger in pairs(item.loadingStation.loadTriggers) do
                            table.insert(ADTriggerManager.siloTriggers, loadTrigger)
                        end
                    end
                end
            end
        end
    end

    if g_currentMission.placeables ~= nil then
        for _, placeable in pairs(g_currentMission.placeables) do
            if placeable.sellingStation ~= nil then
                for _, unloadTrigger in pairs(placeable.sellingStation.unloadTriggers) do
                    table.insert(ADTriggerManager.tipTriggers, unloadTrigger)
                end
            end

            if placeable.unloadingStation ~= nil then
                for _, unloadTrigger in pairs(placeable.unloadingStation.unloadTriggers) do
                    table.insert(ADTriggerManager.tipTriggers, unloadTrigger)
                end
            end

            if placeable.modulesById ~= nil then
                for i = 1, #placeable.modulesById do
                    local myModule = placeable.modulesById[i]
                    if myModule.unloadPlace ~= nil then
                        table.insert(ADTriggerManager.tipTriggers, myModule.unloadPlace)
                    end

                    if myModule.feedingTrough ~= nil then
                        table.insert(ADTriggerManager.tipTriggers, myModule.feedingTrough)
                    end

                    if myModule.loadPlace ~= nil then
                        table.insert(ADTriggerManager.siloTriggers, myModule.loadPlace)
                    end
                end
            end

            if placeable.buyingStation ~= nil then
                for _, loadTrigger in pairs(placeable.buyingStation.loadTriggers) do
                    table.insert(ADTriggerManager.siloTriggers, loadTrigger)
                end
            end

            if placeable.loadingStation ~= nil then
                for _, loadTrigger in pairs(placeable.loadingStation.loadTriggers) do
                    table.insert(ADTriggerManager.siloTriggers, loadTrigger)
                end
            end

            if placeable.bunkerSilos ~= nil then
                for _, bunker in pairs(placeable.bunkerSilos) do
                    table.insert(ADTriggerManager.tipTriggers, bunker)
                end
            end
        end
    end

    if g_currentMission.nodeToObject ~= nil then
        for _, object in pairs(g_currentMission.nodeToObject) do
            if object.triggerNode ~= nil then
                table.insert(ADTriggerManager.siloTriggers, object)
            end
        end
    end

    if g_currentMission.bunkerSilos ~= nil then
        for _, trigger in pairs(g_currentMission.bunkerSilos) do
            if trigger.bunkerSilo then
                table.insert(ADTriggerManager.tipTriggers, trigger)
            end
        end
    end

    if g_company ~= nil and g_company.triggerManagerList ~= nil then
        for i = 1, #g_company.triggerManagerList do
            local triggerManager = g_company.triggerManagerList[i]
            for _, trigger in pairs(triggerManager.registeredTriggers) do
                if trigger.exactFillRootNode then
                    table.insert(ADTriggerManager.tipTriggers, trigger)
                end
                if trigger.triggerNode then
                    table.insert(ADTriggerManager.siloTriggers, trigger)
                end
            end
        end
    end
end

function ADTriggerManager.getUnloadTriggers()
    if not ADTriggerManager.searchedForTriggers then
        ADTriggerManager.loadAllTriggers()
    end
    return ADTriggerManager.tipTriggers
end

function ADTriggerManager.getLoadTriggers()
    if not ADTriggerManager.searchedForTriggers then
        ADTriggerManager.loadAllTriggers()
    end
    return ADTriggerManager.siloTriggers
end

function ADTriggerManager.getRefuelTriggers(vehicle)
    local refuelTriggers = {}

    for _, trigger in pairs(ADTriggerManager.getLoadTriggers()) do
        --loadTriggers
        if trigger.source ~= nil and trigger.source.providedFillTypes ~= nil and trigger.source.providedFillTypes[32] then
            local fillLevels = {}
            if trigger.source ~= nil and trigger.source.getAllFillLevels ~= nil then
                fillLevels, _ = trigger.source:getAllFillLevels(vehicle:getOwnerFarmId())
            end
            local gcFillLevels = {}
            if trigger.source ~= nil and trigger.source.getAllProvidedFillLevels ~= nil then
                gcFillLevels, _ = trigger.source:getAllProvidedFillLevels(vehicle:getOwnerFarmId(), trigger.managerId)
            end
            if #fillLevels == 0 and #gcFillLevels == 0 and trigger.source ~= nil and trigger.source.gcId ~= nil and trigger.source.fillLevels ~= nil then
                for index, fillLevel in pairs(trigger.source.fillLevels) do
                    if fillLevel ~= nil and fillLevel[1] ~= nil then
                        fillLevels[index] = fillLevel[1]
                    end
                end
            end
            local hasCapacity = trigger.hasInfiniteCapacity or (fillLevels[32] ~= nil and fillLevels[32] > 0) or (gcFillLevels[32] ~= nil and gcFillLevels[32] > 0)

            if hasCapacity then
                table.insert(refuelTriggers, trigger)
            end
        end
    end

    return refuelTriggers
end

function ADTriggerManager.getClosestRefuelTrigger(vehicle)
    local refuelTriggers = ADTriggerManager.getRefuelTriggers(vehicle)
    local x, _, z = getWorldTranslation(vehicle.components[1].node)

    local closestRefuelTrigger = nil
    local closestDistance = math.huge

    for _, refuelTrigger in pairs(refuelTriggers) do
        local triggerX, _, triggerZ = ADTriggerManager.getTriggerPos(refuelTrigger)
        local distance = MathUtil.vector2Length(triggerX - x, triggerZ - z)

        if distance < closestDistance then
            closestDistance = distance
            closestRefuelTrigger = refuelTrigger
        end
    end

    return closestRefuelTrigger
end

function ADTriggerManager.getRefuelDestinations(vehicle)
    local refuelDestinations = {}

    local refuelTriggers = ADTriggerManager.getRefuelTriggers(vehicle)

    for mapMarkerID, mapMarker in pairs(ADGraphManager:getMapMarkers()) do
        for _, refuelTrigger in pairs(refuelTriggers) do
            local triggerX, _, triggerZ = ADTriggerManager.getTriggerPos(refuelTrigger)
            local distance = MathUtil.vector2Length(triggerX - ADGraphManager:getWayPointById(mapMarker.id).x, triggerZ - ADGraphManager:getWayPointById(mapMarker.id).z)
            if distance < AutoDrive.MAX_REFUEL_TRIGGER_DISTANCE then
                --g_logManager:devInfo("Found possible refuel destination: " .. mapMarker.name .. " at distance: " .. distance);
                table.insert(refuelDestinations, mapMarkerID)
            end
        end
    end

    return refuelDestinations
end

function ADTriggerManager.getClosestRefuelDestination(vehicle)
    local refuelDestinations = ADTriggerManager.getRefuelDestinations(vehicle)

    local x, _, z = getWorldTranslation(vehicle.components[1].node)
    local closestRefuelDestination = nil
    local closestDistance = math.huge

    for _, refuelDestination in pairs(refuelDestinations) do
        local refuelX, refuelZ = ADGraphManager:getWayPointById(ADGraphManager:getMapMarkerById(refuelDestination).id).x, ADGraphManager:getWayPointById(ADGraphManager:getMapMarkerById(refuelDestination).id).z
        local distance = MathUtil.vector2Length(refuelX - x, refuelZ - z)
        if distance < closestDistance then
            closestDistance = distance
            closestRefuelDestination = refuelDestination
        end
    end

    return closestRefuelDestination
end

function ADTriggerManager.getTriggerPos(trigger)
    local x, y, z = 0, 0, 0
    if trigger.triggerNode ~= nil and g_currentMission.nodeToObject[trigger.triggerNode] ~= nil and entityExists(trigger.triggerNode) then
        x, y, z = getWorldTranslation(trigger.triggerNode)
    --g_logManager:devInfo("Got triggerpos: " .. x .. "/" .. y .. "/" .. z);
    end
    if trigger.exactFillRootNode ~= nil and g_currentMission.nodeToObject[trigger.exactFillRootNode] ~= nil and entityExists(trigger.exactFillRootNode)  then
        x, y, z = getWorldTranslation(trigger.exactFillRootNode)
    --g_logManager:devInfo("Got triggerpos: " .. x .. "/" .. y .. "/" .. z);
    end
    return x, y, z
end

function ADTriggerManager:loadTriggerLoad(superFunc, rootNode, xmlFile, xmlNode)
    local result = superFunc(self, rootNode, xmlFile, xmlNode)

    if result and ADTriggerManager ~= nil and ADTriggerManager.siloTriggers ~= nil then
        if not table.contains(ADTriggerManager.siloTriggers, self) then
            table.insert(ADTriggerManager.siloTriggers, self)
        end
    end

    return result
end

function ADTriggerManager:loadTriggerDelete(superFunc)
    if ADTriggerManager ~= nil and ADTriggerManager.siloTriggers ~= nil then
        table.removeValue(ADTriggerManager.siloTriggers, self)
    end
    superFunc(self)
end

function ADTriggerManager:onPlaceableBuy()
    ADTriggerManager.searchedForTriggers = false
end

