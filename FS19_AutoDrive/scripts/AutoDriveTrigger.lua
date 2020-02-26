AutoDrive.MAX_REFUEL_TRIGGER_DISTANCE = 25
AutoDrive.REFUEL_LEVEL = 0.15

function AutoDrive.getAllTriggers()
    AutoDrive.Triggers = {}
    AutoDrive.Triggers.tipTriggers = {}
    AutoDrive.Triggers.siloTriggers = {}
    AutoDrive.Triggers.tipTriggerCount = 0
    AutoDrive.Triggers.loadTriggerCount = 0

    --g_logManager:devInfo("AutoDrive looking for triggers");

    for _, ownedItem in pairs(g_currentMission.ownedItems) do
        if ownedItem.storeItem ~= nil then
            if ownedItem.storeItem.categoryName == "SILOS" then
                --DebugUtil.printTableRecursively(ownedItem, ":", 0, 3);
                --local trigger = {}
                for _, item in pairs(ownedItem.items) do
                    if item.unloadingStation ~= nil then
                        for _, unloadTrigger in pairs(item.unloadingStation.unloadTriggers) do
                            --DebugUtil.printTableRecursively(unloadTrigger, ":", 0, 3);
                            --local triggerId = unloadTrigger.exactFillRootNode
                            --trigger = {
                            --    triggerId = triggerId,
                            --    acceptedFillTypes = item.storages[1].fillTypes,
                            --    capacity = item.storages[1].capacityPerFillType,
                            --    fillLevels = item.storages[1].fillLevels
                            --}
                            --g_logManager:devInfo("AutoDrive - found silo unloading trigger: " .. ownedItem.storeItem.categoryName .. " with capacity: " .. trigger.capacity);

                            AutoDrive.Triggers.tipTriggerCount = AutoDrive.Triggers.tipTriggerCount + 1
                            AutoDrive.Triggers.tipTriggers[AutoDrive.Triggers.tipTriggerCount] = unloadTrigger
                        end
                    end

                    if item.loadingStation ~= nil then
                        for _, loadTrigger in pairs(item.loadingStation.loadTriggers) do
                            --local triggerId = loadTrigger.triggerNode
                            --g_logManager:devInfo("AutoDrive - found silo loading trigger: " .. ownedItem.storeItem.categoryName);

                            AutoDrive.Triggers.loadTriggerCount = AutoDrive.Triggers.loadTriggerCount + 1
                            AutoDrive.Triggers.siloTriggers[AutoDrive.Triggers.loadTriggerCount] = loadTrigger
                        end
                    end
                end
            end
        --g_logManager:devInfo("Category: " .. trigger.storeItem.categoryName);
        end
        --DebugUtil.printTableRecursively(trigger, ":", 0, 2);
    end

    if g_currentMission.placeables ~= nil then
        --local counter = 0
        for _, placeable in pairs(g_currentMission.placeables) do
            if placeable.sellingStation ~= nil then
                --local trigger = {}
                for _, unloadTrigger in pairs(placeable.sellingStation.unloadTriggers) do
                    --local triggerId = unloadTrigger.exactFillRootNode
                    --trigger = {
                    --    triggerId = triggerId,
                    --    acceptedFillTypes = placeable.sellingStation.acceptedFillTypes
                    --}

                    --g_logManager:devInfo("AutoDrive - found selling unloading trigger: " .. placeable.sellingStation.stationName);

                    AutoDrive.Triggers.tipTriggerCount = AutoDrive.Triggers.tipTriggerCount + 1
                    AutoDrive.Triggers.tipTriggers[AutoDrive.Triggers.tipTriggerCount] = unloadTrigger
                end
            end

            if placeable.unloadingStation ~= nil then
                --local trigger = {}
                for _, unloadTrigger in pairs(placeable.unloadingStation.unloadTriggers) do
                    --local triggerId = unloadTrigger.exactFillRootNode
                    --trigger = {
                    --    triggerId = triggerId,
                    --    acceptedFillTypes = placeable.storages[1].fillTypes,
                    --    capacity = placeable.storages[1].capacityPerFillType,
                    --    fillLevels = placeable.storages[1].fillLevels
                    --}
                    AutoDrive.Triggers.tipTriggerCount = AutoDrive.Triggers.tipTriggerCount + 1
                    AutoDrive.Triggers.tipTriggers[AutoDrive.Triggers.tipTriggerCount] = unloadTrigger
                end
            end

            if placeable.modulesById ~= nil then
                for i = 1, #placeable.modulesById do
                    local myModule = placeable.modulesById[i]
                    --DebugUtil.printTableRecursively(myModule,":",0,1);
                    if myModule.unloadPlace ~= nil then
                        --local triggerId = myModule.unloadPlace.target.unloadPlace.exactFillRootNode
                        --local trigger = {
                        --    triggerId = triggerId,
                        --    acceptedFillTypes = myModule.unloadPlace.fillTypes
                        --}
                        AutoDrive.Triggers.tipTriggerCount = AutoDrive.Triggers.tipTriggerCount + 1
                        AutoDrive.Triggers.tipTriggers[AutoDrive.Triggers.tipTriggerCount] = myModule.unloadPlace
                    end

                    if myModule.feedingTrough ~= nil then
                        --local triggerId = myModule.feedingTrough.target.feedingTrough.exactFillRootNode
                        --local trigger = {
                        --    triggerId = triggerId,
                        --    acceptedFillTypes = myModule.feedingTrough.fillTypes
                        --}
                        AutoDrive.Triggers.tipTriggerCount = AutoDrive.Triggers.tipTriggerCount + 1
                        AutoDrive.Triggers.tipTriggers[AutoDrive.Triggers.tipTriggerCount] = myModule.feedingTrough
                    end

                    if myModule.loadPlace ~= nil then
                        AutoDrive.Triggers.loadTriggerCount = AutoDrive.Triggers.loadTriggerCount + 1
                        AutoDrive.Triggers.siloTriggers[AutoDrive.Triggers.loadTriggerCount] = myModule.loadPlace
                    end
                end
            end

            if placeable.buyingStation ~= nil then
                for _, loadTrigger in pairs(placeable.buyingStation.loadTriggers) do
                    --local triggerId = loadTrigger.triggerNode
                    AutoDrive.Triggers.loadTriggerCount = AutoDrive.Triggers.loadTriggerCount + 1
                    AutoDrive.Triggers.siloTriggers[AutoDrive.Triggers.loadTriggerCount] = loadTrigger
                end
            end

            if placeable.loadingStation ~= nil then
                for _, loadTrigger in pairs(placeable.loadingStation.loadTriggers) do
                    --local triggerId = loadTrigger.triggerNode

                    AutoDrive.Triggers.loadTriggerCount = AutoDrive.Triggers.loadTriggerCount + 1
                    AutoDrive.Triggers.siloTriggers[AutoDrive.Triggers.loadTriggerCount] = loadTrigger
                end
            end

            if placeable.bunkerSilos ~= nil then
                for _, bunker in pairs(placeable.bunkerSilos) do
                    AutoDrive.Triggers.tipTriggerCount = AutoDrive.Triggers.tipTriggerCount + 1
                    AutoDrive.Triggers.tipTriggers[AutoDrive.Triggers.tipTriggerCount] = bunker
                end
            end
        end
    end

    if g_currentMission.nodeToObject ~= nil then
        for _, object in pairs(g_currentMission.nodeToObject) do
            if object.triggerNode ~= nil then
                AutoDrive.Triggers.loadTriggerCount = AutoDrive.Triggers.loadTriggerCount + 1
                AutoDrive.Triggers.siloTriggers[AutoDrive.Triggers.loadTriggerCount] = object
            end
        end
    end

    if g_currentMission.bunkerSilos ~= nil then
        for _, trigger in pairs(g_currentMission.bunkerSilos) do
            if trigger.bunkerSilo then
                AutoDrive.Triggers.tipTriggerCount = AutoDrive.Triggers.tipTriggerCount + 1
                AutoDrive.Triggers.tipTriggers[AutoDrive.Triggers.tipTriggerCount] = trigger
            end
        end
    end

    if g_company and g_company.loadedFactories then
        for i = 1, #g_company.loadedFactories do
            local factory = g_company.loadedFactories[i]
            if factory.registeredUnloadingTriggers then
                for _, unloadingTrigger in pairs(factory.registeredUnloadingTriggers) do
                    if unloadingTrigger.trigger then
                        AutoDrive.Triggers.tipTriggerCount = AutoDrive.Triggers.tipTriggerCount + 1
                        AutoDrive.Triggers.tipTriggers[AutoDrive.Triggers.tipTriggerCount] = unloadingTrigger.trigger
                    end
                end
                for _, loadingTrigger in pairs(factory.registeredLoadingTriggers) do
                    if loadingTrigger.trigger then
                        AutoDrive.Triggers.loadTriggerCount = AutoDrive.Triggers.loadTriggerCount + 1
                        AutoDrive.Triggers.siloTriggers[AutoDrive.Triggers.loadTriggerCount] = loadingTrigger.trigger
                    end
                end
            end
        end
    end
end

function AutoDrive.getRefuelTriggers()
    local refuelTriggers = {}

    for _, trigger in pairs(AutoDrive.Triggers.siloTriggers) do
        --loadTriggers
        if trigger.source ~= nil and trigger.source.providedFillTypes ~= nil and trigger.source.providedFillTypes[32] then
            table.insert(refuelTriggers, trigger)
        end
    end

    return refuelTriggers
end

function AutoDrive.getClosestRefuelTrigger(vehicle)
    local refuelTriggers = AutoDrive.getRefuelTriggers()
    local x, _, z = getWorldTranslation(vehicle.components[1].node)

    local closestRefuelTrigger = nil
    local closestDistance = math.huge

    for _, refuelTrigger in pairs(refuelTriggers) do
        local triggerX, _, triggerZ = AutoDrive.getTriggerPos(refuelTrigger)
        local distance = MathUtil.vector2Length(triggerX - x, triggerZ - z)

        if distance < closestDistance then
            closestDistance = distance
            closestRefuelTrigger = refuelTrigger
        end
    end

    return closestRefuelTrigger
end

function AutoDrive.getRefuelDestinations()
    local refuelDestinations = {}

    local refuelTriggers = AutoDrive.getRefuelTriggers()

    for mapMarkerID, mapMarker in pairs(AutoDrive.mapMarker) do
        local x, z = AutoDrive.mapWayPoints[mapMarker.id].x, AutoDrive.mapWayPoints[mapMarker.id].z
        for _, refuelTrigger in pairs(refuelTriggers) do
            local triggerX, _, triggerZ = AutoDrive.getTriggerPos(refuelTrigger)
            local distance = MathUtil.vector2Length(triggerX - x, triggerZ - z)
            if distance < AutoDrive.MAX_REFUEL_TRIGGER_DISTANCE then
                --g_logManager:devInfo("Found possible refuel destination: " .. mapMarker.name .. " at distance: " .. distance);
                table.insert(refuelDestinations, mapMarkerID)
            end
        end
    end

    return refuelDestinations
end

function AutoDrive.getClosestRefuelDestination(vehicle)
    local refuelDestinations = AutoDrive.getRefuelDestinations()

    local x, _, z = getWorldTranslation(vehicle.components[1].node)
    local closestRefuelDestination = nil
    local closestDistance = math.huge

    for _, refuelDestination in pairs(refuelDestinations) do
        local refuelX, refuelZ = AutoDrive.mapWayPoints[AutoDrive.mapMarker[refuelDestination].id].x, AutoDrive.mapWayPoints[AutoDrive.mapMarker[refuelDestination].id].z
        local distance = MathUtil.vector2Length(refuelX - x, refuelZ - z)
        if distance < closestDistance then
            closestDistance = distance
            closestRefuelDestination = refuelDestination
        end
    end

    return closestRefuelDestination
end

function AutoDrive.hasToRefuel(vehicle)
    local spec = vehicle.spec_motorized

    if spec.consumersByFillTypeName ~= nil and spec.consumersByFillTypeName.diesel ~= nil and spec.consumersByFillTypeName.diesel.fillUnitIndex ~= nil then
        return vehicle:getFillUnitFillLevelPercentage(spec.consumersByFillTypeName.diesel.fillUnitIndex) <= AutoDrive.REFUEL_LEVEL
    end
    
    return false;
end

function AutoDrive.startRefuelingWhenInRange(vehicle, dt)
    local refuelTrigger = AutoDrive.getClosestRefuelTrigger(vehicle)

    local spec = vehicle.spec_motorized
    local fillUnitIndex = spec.consumersByFillTypeName.diesel.fillUnitIndex
    local isInRange = false
    if refuelTrigger ~= nil and refuelTrigger.fillableObjects ~= nil then
        for _, fillableObject in pairs(refuelTrigger.fillableObjects) do
            if fillableObject == vehicle or (fillableObject.object ~= nil and fillableObject.object == vehicle and fillableObject.fillUnitIndex == fillUnitIndex) then
                isInRange = true
            end
        end
    end

    local isFull = vehicle:getFillUnitFillLevelPercentage(spec.consumersByFillTypeName.diesel.fillUnitIndex) >= 0.99

    if isInRange and (not refuelTrigger.isLoading) and (not isFull) then
        AutoDrive.debugPrint(vehicle, AutoDrive.DC_VEHICLEINFO, "Start refueling")
        refuelTrigger.autoStart = true
        refuelTrigger.selectedFillType = 32
        refuelTrigger:onFillTypeSelection(32)
        refuelTrigger.selectedFillType = 32
        g_effectManager:setFillType(refuelTrigger.effects, refuelTrigger.selectedFillType)
        vehicle.ad.startedRefueling = true
        vehicle.ad.isPaused = true
    else
        if vehicle.ad.startedRefueling and (not refuelTrigger.isLoading) then
            AutoDrive.debugPrint(vehicle, AutoDrive.DC_VEHICLEINFO, "Done refueling")
            vehicle.ad.startedRefueling = false
            AutoDrive.continueAfterRefueling(vehicle)
        end
    end

    if vehicle.ad.startedRefueling then
        AutoDrive:getVehicleToStop(vehicle, false, dt)
    end
end

function AutoDrive.goToRefuelStation(vehicle)
    AutoDrive.debugPrint(vehicle, AutoDrive.DC_VEHICLEINFO, "goToRefuelStation")
    vehicle.ad.storedMapMarkerSelected = vehicle.ad.mapMarkerSelected
    vehicle.ad.storedMode = vehicle.ad.mode

    local refuelDestination = AutoDrive.getClosestRefuelDestination(vehicle)

    if refuelDestination ~= nil then
        vehicle.ad.mapMarkerSelected = refuelDestination
        vehicle.ad.targetSelected = AutoDrive.mapMarker[vehicle.ad.mapMarkerSelected].id
        vehicle.ad.nameOfSelectedTarget = AutoDrive.mapMarker[vehicle.ad.mapMarkerSelected].name
        if AutoDrive:isActive(vehicle) then
            AutoDrive:InputHandling(vehicle, "input_start_stop") --disable if already active
        end
        vehicle.ad.mode = 1
        AutoDrive:InputHandling(vehicle, "input_start_stop")
        vehicle.ad.onRouteToRefuel = true
    end
end

function AutoDrive.continueAfterRefueling(vehicle)
    vehicle.ad.mapMarkerSelected = vehicle.ad.storedMapMarkerSelected
    vehicle.ad.targetSelected = AutoDrive.mapMarker[vehicle.ad.mapMarkerSelected].id
    vehicle.ad.nameOfSelectedTarget = AutoDrive.mapMarker[vehicle.ad.mapMarkerSelected].name
    if AutoDrive:isActive(vehicle) then
        AutoDrive:InputHandling(vehicle, "input_start_stop") --disable if already active
    end
    vehicle.ad.mode = vehicle.ad.storedMode
    AutoDrive:InputHandling(vehicle, "input_start_stop")
    vehicle.ad.onRouteToRefuel = false
end
