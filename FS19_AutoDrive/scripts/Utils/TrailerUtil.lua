function AutoDrive.handleTrailers(vehicle, dt)
    if not AutoDrive.inModeToHandleTrailers(vehicle) then
        return
    end

    local isLoading = false
    if AutoDrive.shouldLoadOnTrigger(vehicle) then
        --g_logManager:devInfo(vehicle.ad.driverName .. " - shouldLoadOnTrigger");
        local loadPairs = AutoDrive.getTriggerAndTrailerPairs(vehicle)
        --g_logManager:devInfo(vehicle.ad.driverName .. " - #loadPairs: " .. #loadPairs);
        for _, pair in pairs(loadPairs) do
            local trailer = pair.trailer
            local trigger = pair.trigger

            local fillUnits = trailer:getFillUnits()
            for i = 1, #fillUnits do
                --g_logManager:devInfo("unit: " .. i .. " : " .. trailer:getFillUnitFillLevelPercentage(i)*100 .. " ad.isLoading: " .. AutoDrive.boolToString(vehicle.ad.isLoading) .. " trigger.isLoading: " .. AutoDrive.boolToString(trigger.isLoading))
                if trailer:getFillUnitFillLevelPercentage(i) <= AutoDrive.getSetting("unloadFillLevel", vehicle) * 0.999 and (not vehicle.ad.isLoading) and (not trigger.isLoading) then
                    if trigger:getIsActivatable(trailer) then
                        AutoDrive.startLoadingCorrectFillTypeAtTrigger(vehicle, trailer, trigger, i)
                        --g_logManager:devInfo(vehicle.ad.driverName .. " - started loading with fillUnit: " .. i);
                    else
                        --g_logManager:devInfo(vehicle.ad.driverName .. " - trigger:getIsActivatable(trailer): false ");
                    end
                end
            end
            isLoading = isLoading or trigger.isLoading
            --g_logManager:devInfo(vehicle.ad.driverName .. " - isLoading : " .. AutoDrive.boolToString(trigger.isLoading) .. " ad: " .. AutoDrive.boolToString(isLoading));
        end
    end

    local vehicleFull, _, fillUnitFull = AutoDrive.getIsFilled(vehicle, vehicle.ad.isLoadingToTrailer, vehicle.ad.isLoadingToFillUnitIndex)
    local vehicleIsPausedForLoading = vehicle.ad.isPaused and vehicle.ad.waitingToBeLoaded
    local vehicleIsPausedForTrigger = vehicle.ad.isLoading and (vehicle.ad.trigger == nil or (not vehicle.ad.trigger.isLoading))
    if vehicleIsPausedForLoading or vehicleIsPausedForTrigger then
        if ((fillUnitFull or AutoDrive.getSetting("continueOnEmptySilo")) and vehicleIsPausedForTrigger) or (vehicleIsPausedForLoading and vehicleFull) then
            --g_logManager:devInfo(vehicle.ad.driverName .. " - done loading");
            vehicle.ad.waitingToBeLoaded = false
            vehicle.ad.isLoading = false
            vehicle.ad.isLoadingToFillUnitIndex = nil
            vehicle.ad.isLoadingToTrailer = nil
            vehicle.ad.trigger = nil
            vehicle.ad.isPaused = false
        end
    end

    --legacy code from here on
    local trailers, trailerCount = AutoDrive.getTrailersOf(vehicle, true)
    local allFillables, fillableCount = AutoDrive.getTrailersOf(vehicle, false)

    if trailerCount == 0 and fillableCount == 0 then
        return
    end

    local fillLevel, leftCapacity = AutoDrive.getFillLevelAndCapacityOfAll(trailers, vehicle.ad.unloadFillTypeIndex)

    AutoDrive.checkTrailerStatesAndAttributes(vehicle, trailers)

    AutoDrive.handleTrailersUnload(vehicle, trailers, fillLevel, leftCapacity, dt)

    fillLevel, leftCapacity = AutoDrive.getFillLevelAndCapacityOfAll(allFillables, vehicle.ad.unloadFillTypeIndex)
    AutoDrive.checkTrailerStatesAndAttributes(vehicle, allFillables)
end

function AutoDrive.getIsFilled(vehicle, trailer, fillUnitIndex)
    local vehicleFull = false
    local trailerFull = false
    local fillUnitFull = false

    if vehicle ~= nil then
        local allFillables, _ = AutoDrive.getTrailersOf(vehicle, false)
        local fillLevel, leftCapacity = AutoDrive.getFillLevelAndCapacityOfAll(allFillables)
        local maxCapacity = fillLevel + leftCapacity
        vehicleFull = (leftCapacity <= (maxCapacity * (1 - AutoDrive.getSetting("unloadFillLevel", vehicle) + 0.001)))
    end

    if trailer ~= nil then
        local trailerFillLevel, trailerLeftCapacity = AutoDrive.getFilteredFillLevelAndCapacityOfAllUnits(trailer)
        local maxCapacity = trailerFillLevel + trailerLeftCapacity
        trailerFull = (trailerLeftCapacity <= (maxCapacity * (1 - AutoDrive.getSetting("unloadFillLevel", vehicle) + 0.001)))
    end

    if fillUnitIndex ~= nil then
        fillUnitFull = trailer:getFillUnitFillLevelPercentage(fillUnitIndex) >= AutoDrive.getSetting("unloadFillLevel", vehicle) * 0.999
    end

    return vehicleFull, trailerFull, fillUnitFull
end

function AutoDrive.getIsEmpty(vehicle, trailer, fillUnitIndex)
    local vehicleEmpty = false
    local trailerEmpty = false
    local fillUnitEmpty = false

    if vehicle ~= nil then
        local allFillables, _ = AutoDrive.getTrailersOf(vehicle, false)
        local fillLevel, _ = AutoDrive.getFillLevelAndCapacityOfAll(allFillables)
        --local maxCapacity = fillLevel + leftCapacity
        vehicleEmpty = fillLevel <= 0.001
    end

    if trailer ~= nil then
        local trailerFillLevel, _ = AutoDrive.getFilteredFillLevelAndCapacityOfAllUnits(trailer)
        --local maxCapacity = trailerFillLevel + trailerLeftCapacity
        trailerEmpty = trailerFillLevel <= 0.001
    end

    if fillUnitIndex ~= nil then
        fillUnitEmpty = trailer:getFillUnitFillLevelPercentage(fillUnitIndex) <= 0.001
    end

    return vehicleEmpty, trailerEmpty, fillUnitEmpty
end

function AutoDrive.fillTypesMatch(vehicle, fillTrigger, workTool, allowedFillTypes, fillTypeIndex)
    if fillTrigger ~= nil then
        local typesMatch = false
        local selectedFillType = vehicle.ad.unloadFillTypeIndex or FillType.UNKNOWN
        local fillUnits = workTool:getFillUnits()

        local fillTypesToCheck = {}
        if allowedFillTypes ~= nil then
            fillTypesToCheck = allowedFillTypes
        else
            if vehicle.ad.unloadFillTypeIndex == nil then
                table.insert(fillTypesToCheck, FillType.UNKNOWN)
            else
                table.insert(fillTypesToCheck, vehicle.ad.unloadFillTypeIndex)
            end
        end

        -- go through the single fillUnits and check:
        -- does the trigger support the tools filltype ?
        -- does the trigger support the single fillUnits filltype ?
        -- does the trigger and the fillUnit match the selectedFilltype or do they ignore it ?
        for i = 1, #fillUnits do
            if fillTypeIndex == nil or i == fillTypeIndex then
                local selectedFillTypeIsNotInMyFillUnit = true
                local matchInThisUnit = false
                for index, _ in pairs(workTool:getFillUnitSupportedFillTypes(i)) do
                    --loadTriggers
                    if fillTrigger.source ~= nil and fillTrigger.source.providedFillTypes ~= nil and fillTrigger.source.providedFillTypes[index] then
                        typesMatch = true
                        matchInThisUnit = true
                    end
                    if fillTrigger.source ~= nil and fillTrigger.source.gcId ~= nil and fillTrigger.source.fillLevels ~= nil and fillTrigger.source.fillLevels[index] then
                        typesMatch = true
                        matchInThisUnit = true
                    end
                    
                    --fillTriggers
                    if fillTrigger.source ~= nil and fillTrigger.source.productLines ~= nil then --is gc trigger
                        for _, subSource in pairs(fillTrigger.source.providedFillTypes) do
                            --if type(subSource) == "table" then
                                if subSource[index] ~= nil then
                                    typesMatch = true
                                    matchInThisUnit = true
                                end
                            --end
                        end
                    end

                    if fillTrigger.sourceObject ~= nil then
                        local fillTypes = fillTrigger.sourceObject:getFillUnitSupportedFillTypes(1)
                        if fillTypes[index] then
                            typesMatch = true
                            matchInThisUnit = true
                        end
                    end

                    for _, allowedFillType in pairs(fillTypesToCheck) do
                        if index == allowedFillType and allowedFillType ~= FillType.UNKNOWN then
                            selectedFillTypeIsNotInMyFillUnit = false
                        end
                    end
                end
                if matchInThisUnit and selectedFillTypeIsNotInMyFillUnit then
                    return false
                end
            end
        end

        if typesMatch then
            for _, allowedFillType in pairs(fillTypesToCheck) do
                if allowedFillType == FillType.UNKNOWN then
                    return true
                end
            end

            local isFillType = false
            for _, allowedFillType in pairs(fillTypesToCheck) do
                if fillTrigger.source then
                    if fillTrigger.source.productLines ~= nil then --is gc trigger
                        return true
                    else
                        if (fillTrigger.source.providedFillTypes ~= nil and fillTrigger.source.providedFillTypes[allowedFillType]) or 
                            (fillTrigger.source.fillLevels ~= nil and fillTrigger.source.fillLevels[allowedFillType]) then
                            return true
                        end
                    end
                elseif fillTrigger.sourceObject ~= nil then
                    local fillType = fillTrigger.sourceObject:getFillUnitFillType(1)
                    isFillType = (fillType == selectedFillType)
                end
            end
            return isFillType
        end
    end
    return false
end

function AutoDrive.getTrailersOf(vehicle, onlyDischargeable)
    AutoDrive.tempTrailers = {}
    AutoDrive.tempTrailerCount = 0

    if (vehicle.spec_dischargeable ~= nil or (not onlyDischargeable)) and vehicle.getFillUnits ~= nil then
        local vehicleFillLevel, vehicleLeftCapacity = AutoDrive.getFilteredFillLevelAndCapacityOfAllUnits(vehicle, nil)
        --g_logManager:devInfo("VehicleFillLevel: " .. vehicleFillLevel .. " vehicleLeftCapacity: " .. vehicleLeftCapacity);
        if not (vehicleFillLevel == 0 and vehicleLeftCapacity == 0) then
            AutoDrive.tempTrailerCount = AutoDrive.tempTrailerCount + 1
            AutoDrive.tempTrailers[AutoDrive.tempTrailerCount] = vehicle
        end
    end
    --g_logManager:devInfo("AutoDrive.tempTrailerCount after vehicle: "  .. AutoDrive.tempTrailerCount);

    if vehicle.getAttachedImplements ~= nil then
        for _, implement in pairs(vehicle:getAttachedImplements()) do
            AutoDrive.getTrailersOfImplement(implement.object, onlyDischargeable)
        end
    end

    return AutoDrive.tempTrailers, AutoDrive.tempTrailerCount
end

function AutoDrive.getTrailersOfImplement(attachedImplement, onlyDischargeable)
    if ((attachedImplement.typeDesc == g_i18n:getText("typeDesc_tipper") or attachedImplement.spec_dischargeable ~= nil) or (not onlyDischargeable)) and attachedImplement.getFillUnits ~= nil then
        if not (attachedImplement.vehicleType.specializationsByName["leveler"] ~= nil or attachedImplement.typeDesc == "frontloaderTool") then --avoid trying to fill shovels and levellers atached
            local trailer = attachedImplement
            AutoDrive.tempTrailerCount = AutoDrive.tempTrailerCount + 1
            AutoDrive.tempTrailers[AutoDrive.tempTrailerCount] = trailer
        end
    end
    if attachedImplement.getAttachedImplements ~= nil then
        for _, implement in pairs(attachedImplement:getAttachedImplements()) do
            AutoDrive.getTrailersOfImplement(implement.object)
        end
    end

    return
end

function AutoDrive.getDistanceToUnloadPosition(vehicle)
    if vehicle.ad.targetSelected_Unload == nil or vehicle.ad.targetSelected == nil then
        return math.huge
    end
    local x, _, z = getWorldTranslation(vehicle.components[1].node)
    local destination = AutoDrive.mapWayPoints[vehicle.ad.targetSelected_Unload]
    if destination == nil then
        return math.huge
    end
    return AutoDrive.getDistance(x, z, destination.x, destination.z)
end

function AutoDrive.getDistanceToTargetPosition(vehicle)
    if vehicle.ad.targetSelected == nil then
        return math.huge
    end
    local x, _, z = getWorldTranslation(vehicle.components[1].node)
    local destination = AutoDrive.mapWayPoints[vehicle.ad.targetSelected]
    if destination == nil then
        return math.huge
    end
    return AutoDrive.getDistance(x, z, destination.x, destination.z)
end

function AutoDrive.getFillLevelAndCapacityOfAll(trailers, selectedFillType)
    local leftCapacity = 0
    local fillLevel = 0

    if trailers ~= nil then
        for _, trailer in pairs(trailers) do
            local trailerFillLevel, trailerLeftCapacity = AutoDrive.getFilteredFillLevelAndCapacityOfAllUnits(trailer, selectedFillType)
            fillLevel = fillLevel + trailerFillLevel
            leftCapacity = leftCapacity + trailerLeftCapacity
        end
    end

    return fillLevel, leftCapacity
end

function AutoDrive.getFillLevelAndCapacityOf(trailer, selectedFillType)
    local leftCapacity = 0
    local fillLevel = 0
    local fullFillUnits = {}

    if trailer ~= nil then
        for fillUnitIndex, _ in pairs(trailer:getFillUnits()) do
            if selectedFillType == nil or trailer:getFillUnitSupportedFillTypes(fillUnitIndex)[selectedFillType] == true then
                local trailerFillLevel, trailerLeftCapacity = AutoDrive.getFilteredFillLevelAndCapacityOfOneUnit(trailer, fillUnitIndex, selectedFillType)
                fillLevel = fillLevel + trailerFillLevel
                leftCapacity = leftCapacity + trailerLeftCapacity
                if (trailerLeftCapacity <= 0.01) then
                    fullFillUnits[fillUnitIndex] = true
                end
            end
        end
    end
    -- g_logManager:devInfo("FillLevel: " .. fillLevel .. " leftCapacity: " .. leftCapacity .. " fullUnits: " .. #fullFillUnits);
    -- for index, value in pairs(fullFillUnits) do
    --     g_logManager:devInfo("Unit full: " .. index .. " " .. AutoDrive.boolToString(value));
    -- end;

    return fillLevel, leftCapacity, fullFillUnits
end

function AutoDrive.getFilteredFillLevelAndCapacityOfAllUnits(object, selectedFillType)
    if object == nil or object.getFillUnits == nil then
        return 0, 0
    end
    local leftCapacity = 0
    local fillLevel = 0
    --local hasOnlyDieselForFuel = AutoDrive.checkForDieselTankOnlyFuel(object)
    for fillUnitIndex, _ in pairs(object:getFillUnits()) do
        --g_logManager:devInfo("object fillUnit " .. fillUnitIndex ..  " has :");
        local unitFillLevel, unitLeftCapacity = AutoDrive.getFilteredFillLevelAndCapacityOfOneUnit(object, fillUnitIndex, selectedFillType)
        --g_logManager:devInfo("   fillLevel: " .. unitFillLevel ..  " leftCapacity: " .. unitLeftCapacity);
        fillLevel = fillLevel + unitFillLevel
        leftCapacity = leftCapacity + unitLeftCapacity
    end
    --g_logManager:devInfo("Total fillLevel: " .. fillLevel ..  " leftCapacity: " .. leftCapacity);
    return fillLevel, leftCapacity
end

function AutoDrive.getFilteredFillLevelAndCapacityOfOneUnit(object, fillUnitIndex, selectedFillType)
    local hasOnlyDieselForFuel = AutoDrive.checkForDieselTankOnlyFuel(object)
    local fillTypeIsProhibited = false
    local isSelectedFillType = false
    for fillType, _ in pairs(object:getFillUnitSupportedFillTypes(fillUnitIndex)) do
        if fillType == 1 or fillType == 34 or fillType == 33 or (fillType == 32 and hasOnlyDieselForFuel) then --1:UNKNOWN 34:AIR 33:AdBlue 32:Diesel
            --g_logManager:devInfo("Found prohibited filltype: " .. fillType);
            fillTypeIsProhibited = true
        end
        if selectedFillType ~= nil and fillType == selectedFillType then
            --g_logManager:devInfo("Found selected filltype: " .. fillType);
            isSelectedFillType = true
        end
        --g_logManager:devInfo("FillType: " .. fillType .. " : " .. g_fillTypeManager:getFillTypeByIndex(fillType).title .. "  free Capacity: " ..  object:getFillUnitFreeCapacity(fillUnitIndex));
    end
    if isSelectedFillType then
        fillTypeIsProhibited = false
    end
    --g_logManager:devInfo("DieselForFuel: " .. AutoDrive.boolToString(hasOnlyDieselForFuel));

    if object:getFillUnitCapacity(fillUnitIndex) > 300 and (not fillTypeIsProhibited) then
        return object:getFillUnitFillLevel(fillUnitIndex), object:getFillUnitFreeCapacity(fillUnitIndex)
    end
    return 0, 0
end

function AutoDrive.checkForDieselTankOnlyFuel(object)
    if object.getFillUnits == nil then
        return true
    end
    local dieselFuelUnitCount = 0
    local adBlueUnitCount = 0
    local otherFillUnitsCapacity = 0
    local dieselFillUnitCapacity = 0
    local numberOfFillUnits = 0
    for fillUnitIndex, _ in pairs(object:getFillUnits()) do
        numberOfFillUnits = numberOfFillUnits + 1
        local dieselFillUnit = false
        for fillType, _ in pairs(object:getFillUnitSupportedFillTypes(fillUnitIndex)) do
            if fillType == 33 then
                adBlueUnitCount = adBlueUnitCount + 1
            end
            if fillType == 32 then
                dieselFuelUnitCount = dieselFuelUnitCount + 1
                dieselFillUnit = true
            end
        end
        if dieselFillUnit then
            dieselFillUnitCapacity = dieselFillUnitCapacity + object:getFillUnitCapacity(fillUnitIndex)
        else
            otherFillUnitsCapacity = otherFillUnitsCapacity + object:getFillUnitCapacity(fillUnitIndex)
        end
    end

    return ((dieselFuelUnitCount == adBlueUnitCount) or (dieselFillUnitCapacity < otherFillUnitsCapacity)) and numberOfFillUnits > 1
end

function AutoDrive.checkTrailerStatesAndAttributes(vehicle, trailers)
    if vehicle == nil or trailers == nil then
        return
    end
    local fillLevel, leftCapacity = AutoDrive.getFillLevelAndCapacityOfAll(trailers)
    vehicle.ad.inTriggerProximity = AutoDrive.checkForTriggerProximity(vehicle)

    if vehicle.ad.mode == AutoDrive.MODE_PICKUPANDDELIVER or vehicle.ad.mode == AutoDrive.MODE_LOAD then
        if AutoDrive.getDistanceToTargetPosition(vehicle) > 25 and AutoDrive.getDistanceToUnloadPosition(vehicle) > 25 and (not vehicle.ad.inTriggerProximity) and (vehicle.ad.distanceToCombine > 40) then
            AutoDrive.setTrailerCoverOpen(vehicle, trailers, false)
        else
            if vehicle.ad.mode ~= AutoDrive.MODE_LOAD or AutoDrive.getDistanceToUnloadPosition(vehicle) <= 25 or vehicle.ad.inTriggerProximity or (vehicle.ad.distanceToCombine < 35) then
                AutoDrive.setTrailerCoverOpen(vehicle, trailers, true)
            end
        end
        fillLevel, leftCapacity = AutoDrive.getFillLevelAndCapacityOfAll(trailers, vehicle.ad.unloadFillTypeIndex)
    end

    if vehicle.ad.mode == AutoDrive.MODE_UNLOAD then
        AutoDrive.handleUnloaderSpecificStates(vehicle, trailers, fillLevel, leftCapacity)
    end
end

function AutoDrive.handleUnloaderSpecificStates(vehicle, trailers, fillLevel, leftCapacity)
    vehicle.ad.distanceToCombine = math.huge
    if vehicle.ad.currentCombine ~= nil then
        local combineWorldX, _, combineWorldZ = getWorldTranslation(vehicle.ad.currentCombine.components[1].node)
        local worldX, _, worldZ = getWorldTranslation(vehicle.components[1].node)
        vehicle.ad.distanceToCombine = MathUtil.vector2Length(combineWorldX - worldX, combineWorldZ - worldZ)
    end

    if vehicle.ad.combineState == AutoDrive.WAIT_FOR_COMBINE or vehicle.ad.combineState == AutoDrive.DRIVE_TO_COMBINE or vehicle.ad.combineState == AutoDrive.WAIT_TILL_UNLOADED or (vehicle.ad.distanceToCombine < 30) then
        AutoDrive.setTrailerCoverOpen(vehicle, trailers, true) --open
        AutoDrive.setAugerPipeOpen(trailers, false)
    end

    if fillLevel <= 0.0001 then
        AutoDrive.setAugerPipeOpen(trailers, false)
    end

    local totalCapacity = fillLevel + leftCapacity
    if vehicle.ad.combineState == AutoDrive.WAIT_FOR_COMBINE and (fillLevel / totalCapacity) >= (AutoDrive.getSetting("unloadFillLevel", vehicle) - 0.001) then --was filled up manually
        AutoDrive:sendCombineUnloaderToStartOrToUnload(vehicle, false)
    end

    if (vehicle.ad.combineState ~= AutoDrive.DRIVE_TO_COMBINE and vehicle.ad.combineState ~= AutoDrive.WAIT_TILL_UNLOADED) then
        if AutoDrive.getDistanceToUnloadPosition(vehicle) < 35 then
            if fillLevel >= 0.0001 then
                AutoDrive.setAugerPipeOpen(trailers, true)
            end
            AutoDrive.setTrailerCoverOpen(vehicle, trailers, true)
        end
    end

    if vehicle.ad.combineState ~= AutoDrive.DRIVE_TO_COMBINE and AutoDrive.getDistanceToUnloadPosition(vehicle) > 25 and (vehicle.ad.distanceToCombine > 40) then
        AutoDrive.setTrailerCoverOpen(vehicle, trailers, false)
    end
end

function AutoDrive.setTrailerCoverOpen(vehicle, trailers, open)
    if trailers == nil then
        return
    end

    local targetState = 0
    if open then
        targetState = 1
    end

    vehicle.ad.closeCoverTimer:timer(not open, 2000, 16)

    if (not open) and (not vehicle.ad.closeCoverTimer:done()) then
        return
    end

    for _, trailer in pairs(trailers) do
        if trailer.spec_cover ~= nil then
            targetState = targetState * #trailer.spec_cover.covers
            if trailer.spec_cover.state ~= targetState and trailer:getIsNextCoverStateAllowed(targetState) then
                trailer:setCoverState(targetState, true)
            end
        end
    end
end

function AutoDrive.setAugerPipeOpen(trailers, open)
    if trailers == nil then
        return
    end

    local targetState = 1
    if open then
        targetState = 2
    end
    for _, trailer in pairs(trailers) do
        if trailer.spec_pipe ~= nil then
            if trailer.spec_pipe.currentState ~= targetState and trailer:getIsPipeStateChangeAllowed(targetState) then
                trailer:setPipeState(targetState, true)
            end
        end
    end
end

function AutoDrive.continueIfAllTrailersClosed(vehicle, trailers, dt)
    local allClosed = true
    for _, trailer in pairs(trailers) do
        if trailer.getTipState ~= nil then
            local tipState = trailer:getTipState()
            if trailer.noDischargeTimer == nil then
                trailer.noDischargeTimer = AutoDriveTON:new()
            end
            if (not trailer.noDischargeTimer:timer((tipState == Trailer.TIPSTATE_CLOSED), 500, dt)) or vehicle.ad.isLoading then
                allClosed = false
            end
        end
    end
    if allClosed and (vehicle.ad.mode ~= AutoDrive.MODE_UNLOAD or vehicle.ad.combineState == AutoDrive.DRIVE_TO_UNLOAD_POS or vehicle.ad.combineState == AutoDrive.COMBINE_UNINITIALIZED) then
        if vehicle.ad.isPaused and vehicle.ad.isPausedForTrailersClosing then
            AutoDrive.debugPrint(vehicle, AutoDrive.DC_VEHICLEINFO, "All trailers closed - continue")
            vehicle.ad.isPaused = false
            vehicle.ad.isPausedForTrailersClosing = false
            vehicle.ad.isUnloading = false
        end
    end
end

function AutoDrive.findAndSetBestTipPoint(vehicle, trailer)
    local dischargeCondition = true
    if trailer.getCanDischargeToObject ~= nil and trailer.getCurrentDischargeNode ~= nil then
        dischargeCondition = (not trailer:getCanDischargeToObject(trailer:getCurrentDischargeNode()))
    end
    if dischargeCondition and (not vehicle.ad.isLoading) and (not vehicle.ad.isUnloading) and trailer.getCurrentDischargeNode ~= nil and trailer:getCurrentDischargeNode() ~= nil then
        local spec = trailer.spec_trailer
        if spec == nil then
            return
        end
        local currentDischargeNodeIndex = trailer:getCurrentDischargeNode().index
        for i = 1, spec.tipSideCount, 1 do
            local tipSide = spec.tipSides[i]
            trailer:setCurrentDischargeNodeIndex(tipSide.dischargeNodeIndex)
            trailer:updateRaycast(trailer:getCurrentDischargeNode())
            if trailer:getCanDischargeToObject(trailer:getCurrentDischargeNode()) then
                if trailer:getCanTogglePreferdTipSide() then
                    trailer:setPreferedTipSide(i)
                    trailer:updateRaycast(trailer:getCurrentDischargeNode())
                    AutoDrive.debugPrint(vehicle, AutoDrive.DC_VEHICLEINFO, "Changed tip side to %s", i)
                    return
                end
            end
        end
        trailer:setCurrentDischargeNodeIndex(currentDischargeNodeIndex)
    end
end

function AutoDrive.isTrailerInBunkerSiloArea(trailer, trigger)
    if trailer.getCurrentDischargeNode ~= nil then
        local dischargeNode = trailer:getCurrentDischargeNode()
        if dischargeNode ~= nil then
            local x, y, z = getWorldTranslation(dischargeNode.node)
            local tx, _, tz = x, y, z + 1
            if trigger ~= nil and trigger.bunkerSiloArea ~= nil then
                local x1, z1 = trigger.bunkerSiloArea.sx, trigger.bunkerSiloArea.sz
                local x2, z2 = trigger.bunkerSiloArea.wx, trigger.bunkerSiloArea.wz
                local x3, z3 = trigger.bunkerSiloArea.hx, trigger.bunkerSiloArea.hz
                return MathUtil.hasRectangleLineIntersection2D(x1, z1, x2 - x1, z2 - z1, x3 - x1, z3 - z1, x, z, tx - x, tz - z)
            end
        end
    end
    return false
end

function AutoDrive.trailerInTriggerRange(trailer, trigger)
    if trigger.fillableObjects ~= nil then
        for _, fillableObject in pairs(trigger.fillableObjects) do
            if fillableObject.object == trailer and trigger:getIsActivatable(trailer) then
                return true
            end
        end
    end
    return false
end



function AutoDrive.shouldLoadOnTrigger(vehicle)
    if vehicle.ad.mode == AutoDrive.MODE_PICKUPANDDELIVER then
        if (AutoDrive.getDistanceToTargetPosition(vehicle) <= AutoDrive.getSetting("maxTriggerDistance")) then --(not vehicle.ad.onRouteToSecondTarget) and
            return true
        end
    end

    if vehicle.ad.mode == AutoDrive.MODE_LOAD then
        if (AutoDrive.getDistanceToUnloadPosition(vehicle) <= AutoDrive.getSetting("maxTriggerDistance")) then --vehicle.ad.onRouteToSecondTarget and
            return true
        end
    end

    return false
end

function AutoDrive.shouldUnloadAtTrigger(vehicle)
    if (vehicle.ad.mode == AutoDrive.MODE_UNLOAD and vehicle.ad.combineState == AutoDrive.DRIVE_TO_UNLOAD_POS) then
        return true
    end

    if vehicle.ad.mode == AutoDrive.MODE_PICKUPANDDELIVER then
        if (AutoDrive.getDistanceToUnloadPosition(vehicle) <= AutoDrive.getSetting("maxTriggerDistance")) then -- (vehicle.ad.onRouteToSecondTarget) and
            return true
        end
    end

    if vehicle.ad.mode == AutoDrive.MODE_DELIVERTO then
        if (AutoDrive.getDistanceToTargetPosition(vehicle) <= AutoDrive.getSetting("maxTriggerDistance")) then -- (vehicle.ad.onRouteToSecondTarget) and
            return true
        end
    end

    return false
end



function AutoDrive.inModeToHandleTrailers(vehicle)
    if vehicle.ad.isActive == true then
        if (vehicle.ad.mode == AutoDrive.MODE_DELIVERTO or vehicle.ad.mode == AutoDrive.MODE_PICKUPANDDELIVER or vehicle.ad.mode == AutoDrive.MODE_UNLOAD or vehicle.ad.mode == AutoDrive.MODE_LOAD) then --and vehicle.isServer == true
            return true
        end
    end
    return false
end

function AutoDrive.getTriggerAndTrailerPairs(vehicle)
    local trailerTriggerPairs = {}
    local trailers, _ = AutoDrive.getTrailersOf(vehicle, false)

    for _, trailer in pairs(trailers) do
        local trailerX, _, trailerZ = getWorldTranslation(trailer.components[1].node)

        for _, trigger in pairs(AutoDrive.Triggers.siloTriggers) do
            local triggerX, _, triggerZ = ADTriggerManager.getTriggerPos(trigger)
            if triggerX ~= nil then
                local distance = MathUtil.vector2Length(triggerX - trailerX, triggerZ - trailerZ)
                if distance <= AutoDrive.getSetting("maxTriggerDistance") then
                    local allowedFillTypes = {vehicle.ad.unloadFillTypeIndex}
                    if vehicle.ad.unloadFillTypeIndex == 13 or vehicle.ad.unloadFillTypeIndex == 43 or vehicle.ad.unloadFillTypeIndex == 44 then
                        allowedFillTypes = {}
                        table.insert(allowedFillTypes, 13)
                        table.insert(allowedFillTypes, 43)
                        table.insert(allowedFillTypes, 44)
                    end

                    local fillLevels = {}
                    if trigger.source ~= nil and trigger.source.getAllFillLevels ~= nil then
                        fillLevels, _ = trigger.source:getAllFillLevels(g_currentMission:getFarmId())
                    end
                    local gcFillLevels = {}
                    if trigger.source ~= nil and trigger.source.getAllProvidedFillLevels ~= nil then
                        gcFillLevels, _ = trigger.source:getAllProvidedFillLevels(g_currentMission:getFarmId(), trigger.managerId)
                    end
                    if #fillLevels == 0 and #gcFillLevels == 0 and trigger.source ~= nil and trigger.source.gcId ~= nil and trigger.source.fillLevels ~= nil then
                        --g_logManager:devInfo("Adding gm fill levels now")
                        for index, fillLevel in pairs(trigger.source.fillLevels) do
                            if fillLevel ~= nil and fillLevel[1] ~= nil then
                                --g_logManager:devInfo("Adding gm fill levels now - adding " .. index .. " with value: " .. fillLevel[1])
                                fillLevels[index] = fillLevel[1]
                            end
                        end
                    end
                    local hasCapacity = trigger.hasInfiniteCapacity or (fillLevels[vehicle.ad.unloadFillTypeIndex] ~= nil and fillLevels[vehicle.ad.unloadFillTypeIndex] > 0) or (gcFillLevels[vehicle.ad.unloadFillTypeIndex] ~= nil and gcFillLevels[vehicle.ad.unloadFillTypeIndex] > 0)

                    local hasRequiredFillType = false
                    local fillUnits = trailer:getFillUnits()
                    for i = 1, #fillUnits do
                        hasRequiredFillType = AutoDrive.fillTypesMatch(vehicle, trigger, trailer, allowedFillTypes, i)
                        local isNotFilled = trailer:getFillUnitFillLevelPercentage(i) <= AutoDrive.getSetting("unloadFillLevel", vehicle) * 0.999

                        for _, allowedFillType in pairs(allowedFillTypes) do
                            if trailer:getFillUnitSupportsFillType(i, allowedFillType) then
                                hasCapacity = hasCapacity or (fillLevels[allowedFillType] ~= nil and fillLevels[allowedFillType] > 0) or (gcFillLevels[allowedFillType] ~= nil and gcFillLevels[allowedFillType] > 0)
                            end
                        end

                        local trailerIsInRange = AutoDrive.trailerIsInTriggerList(trailer, trigger, i)

                        --g_logManager:devInfo(vehicle.ad.driverName .. " i: " .. i .. " - checking trailer: hasRequiredFillType " .. AutoDrive.boolToString(hasRequiredFillType));
                        --g_logManager:devInfo(vehicle.ad.driverName .. " i: " .. i .. " - checking trailer: hasCapacity " .. AutoDrive.boolToString(hasCapacity));
                        --g_logManager:devInfo(vehicle.ad.driverName .. " i: " .. i .. " - checking trailer: trailerIsInRange " .. AutoDrive.boolToString(trailerIsInRange));
                        --g_logManager:devInfo(vehicle.ad.driverName .. " i: " .. i .. " - checking trailer: isNotFilled " .. AutoDrive.boolToString(isNotFilled) .. " level: " .. (trailer:getFillUnitFillLevelPercentage(i)*100) .. " setting: " .. (AutoDrive.getSetting("unloadFillLevel", vehicle) * 0.999) );

                        if trailerIsInRange and hasRequiredFillType and isNotFilled and hasCapacity then
                            local pair = {trailer = trailer, trigger = trigger}
                            table.insert(trailerTriggerPairs, pair)
                        end
                    end
                end
            end
        end
    end

    return trailerTriggerPairs
end

function AutoDrive.trailerIsInTriggerList(trailer, trigger, fillUnitIndex)
    if trigger ~= nil and trigger.fillableObjects ~= nil then
        for _, fillableObject in pairs(trigger.fillableObjects) do
            if fillableObject == trailer or (fillableObject.object ~= nil and fillableObject.object == trailer and fillableObject.fillUnitIndex == fillUnitIndex) then
                return true
            end
        end
    end

    return false
end


function AutoDrive.getFillUnitEmptyForSomeTime(trailer, fillUnitEmpty, dt)
    if trailer ~= nil then
        if trailer.emptyTimer == nil then
            trailer.emptyTimer = AutoDriveTON:new()
        end
        return trailer.emptyTimer:timer(fillUnitEmpty, 1000, dt)
    end
    return false
end
