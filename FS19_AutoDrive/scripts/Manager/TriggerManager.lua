ADTriggerManager = {}

ADTriggerManager.tipTriggers = {}
ADTriggerManager.siloTriggers = {}

function ADTriggerManager.load()
    ADTriggerManager.loadAllTriggers()
end

function ADTriggerManager.checkForTriggerProximity(vehicle)
    local shouldLoad = vehicle.ad.modes[vehicle.ad.mode]:shouldLoadOnTrigger(vehicle)
    local shouldUnload = vehicle.ad.modes[vehicle.ad.mode]:shouldUnloadAtTrigger(vehicle)
    if (not shouldUnload) and (not shouldLoad) then
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
    local distanceToSlowDownAt = 15 * speedFactor * massFactor;

    if shouldLoad then
        for _, trigger in pairs(ADTriggerManager.siloTriggers) do
            local triggerX, _, triggerZ = AutoDrive.getTriggerPos(trigger)
            if triggerX ~= nil then
                local distance = MathUtil.vector2Length(triggerX - x, triggerZ - z)

                if distance < distanceToSlowDownAt then
                    local hasRequiredFillType = false
                    local allowedFillTypes = {vehicle.ad.unloadFillTypeIndex}
                    if vehicle.ad.unloadFillTypeIndex == 13 or vehicle.ad.unloadFillTypeIndex == 43 or vehicle.ad.unloadFillTypeIndex == 44 then
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
            local triggerX, _, triggerZ = AutoDrive.getTriggerPos(trigger)
            if triggerX ~= nil then
                local distance = MathUtil.vector2Length(triggerX - x, triggerZ - z)
                if distance < distanceToSlowDownAt then
                    return true
                end
            end
        end
    end

    return false
end

function ADTriggerManager.loadAllTriggers()
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
                        table.insert(ADTriggerManager.tipTriggers, myModule.loadPlace)
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
        for i=1,#g_company.triggerManagerList do
            local triggerManager = g_company.triggerManagerList[i];			
            for _, trigger in pairs (triggerManager.registeredTriggers) do
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
    if #ADTriggerManager.tipTriggers == 0 then        
	    ADTriggerManager.loadAllTriggers()
    end
    return ADTriggerManager.tipTriggers
end

function ADTriggerManager.getLoadTriggers()
    if #ADTriggerManager.siloTriggers == 0 then        
	    ADTriggerManager.loadAllTriggers()
    end
    return ADTriggerManager.siloTriggers
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