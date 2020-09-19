-- positive X -> left
-- negative X -> right
function AutoDrive.createWayPointRelativeToVehicle(vehicle, offsetX, offsetZ)
    local wayPoint = {}
    wayPoint.x, wayPoint.y, wayPoint.z = localToWorld(vehicle.components[1].node, offsetX, 0, offsetZ)
    return wayPoint
end

function AutoDrive.createWayPointRelativeToNode(node, offsetX, offsetZ)
    local wayPoint = {}
    wayPoint.x, wayPoint.y, wayPoint.z = localToWorld(node, offsetX, 0, offsetZ)
    return wayPoint
end

function AutoDrive.isTrailerInCrop(vehicle, enlargeDetectionArea)
    local widthFactor = 1
    if enlargeDetectionArea then
        widthFactor = 1.5
    end

    local trailers, trailerCount = AutoDrive.getTrailersOf(vehicle)
    local trailer = trailers[trailerCount]
    local inCrop = false
    if trailer ~= nil then
        if trailer.ad == nil then
            trailer.ad = {}
        end
        ADSensor:handleSensors(trailer, 0)
        inCrop = trailer.ad.sensors.centerSensorFruit:pollInfo(true, widthFactor)
    end
    return inCrop
end

function AutoDrive.isVehicleOrTrailerInCrop(vehicle, enlargeDetectionArea)
    local widthFactor = 1
    if enlargeDetectionArea then
        widthFactor = 1.5
    end

    return AutoDrive.isTrailerInCrop(vehicle, enlargeDetectionArea) or vehicle.ad.sensors.centerSensorFruit:pollInfo(true, widthFactor)
end

function AutoDrive:checkIsConnected(toCheck, other)
    local isAttachedToMe = false
    if toCheck == nil or other == nil then
        return false
    end
    if toCheck.getAttachedImplements == nil then
        return false
    end

    for _, impl in pairs(toCheck:getAttachedImplements()) do
        if impl.object ~= nil then
            if impl.object == other then
                return true
            end

            if impl.object.getAttachedImplements ~= nil then
                isAttachedToMe = isAttachedToMe or AutoDrive:checkIsConnected(impl.object, other)
            end
        end
    end

    return isAttachedToMe
end

function AutoDrive.defineMinDistanceByVehicleType(vehicle)
    local min_distance = 1.8
    if
        vehicle.typeDesc == "combine" or vehicle.typeDesc == "harvester" or vehicle.typeName == "combineDrivable" or vehicle.typeName == "selfPropelledMower" or vehicle.typeName == "woodHarvester" or vehicle.typeName == "combineCutterFruitPreparer" or vehicle.typeName == "drivableMixerWagon" or
            vehicle.typeName == "cottonHarvester" or
            vehicle.typeName == "pdlc_claasPack.combineDrivableCrawlers"
     then
        min_distance = 6
    elseif vehicle.typeDesc == "telehandler" or vehicle.spec_crabSteering ~= nil then --If vehicle has 4 steering wheels like xerion or hardi self Propelled sprayer then also min_distance = 3;
        min_distance = 3
    elseif vehicle.typeDesc == "truck" then
        min_distance = 3
    end
    -- If vehicle is quadtrack then also min_distance = 6;
    if vehicle.spec_articulatedAxis ~= nil and vehicle.spec_articulatedAxis.rotSpeed ~= nil then
        min_distance = 6
    end
    return min_distance
end

function AutoDrive.getVehicleMaxSpeed(vehicle)
    -- 255 is the max value to prevent errors with MP sync
    if vehicle ~= nil and vehicle.spec_motorized ~= nil and vehicle.spec_motorized.motor ~= nil then
        local motor = vehicle.spec_motorized.motor
        return math.min(motor:getMaximumForwardSpeed() * 3.6, 255)
    end
    return 255
end

function AutoDrive.renameDriver(vehicle, name, sendEvent)
    if name:len() > 1 and vehicle ~= nil and vehicle.ad ~= nil then
        if sendEvent == nil or sendEvent == true then
            -- Propagating driver rename all over the network
            AutoDriveRenameDriverEvent.sendEvent(vehicle, name)
        else
            vehicle.ad.stateModule:setName(name)
        end
    end
end

function AutoDrive.hasToRefuel(vehicle)
    local spec = vehicle.spec_motorized

    if spec.consumersByFillTypeName ~= nil and spec.consumersByFillTypeName.diesel ~= nil and spec.consumersByFillTypeName.diesel.fillUnitIndex ~= nil then
        return vehicle:getFillUnitFillLevelPercentage(spec.consumersByFillTypeName.diesel.fillUnitIndex) <= AutoDrive.REFUEL_LEVEL
    end

    return false
end

function AutoDrive.combineIsTurning(combine)
    local cpIsTurning = combine.cp ~= nil and (combine.cp.isTurning or (combine.cp.turnStage ~= nil and combine.cp.turnStage > 0))
    local cpIsTurningTwo = combine.cp ~= nil and combine.cp.driver and (combine.cp.driver.turnIsDriving or (combine.cp.driver.fieldworkState ~= nil and combine.cp.driver.fieldworkState == combine.cp.driver.states.TURNING))
    local aiIsTurning = (combine.getAIIsTurning ~= nil and combine:getAIIsTurning() == true)
    --local combineSteering = combine.rotatedTime ~= nil and (math.deg(combine.rotatedTime) > 30)
    local combineIsTurning = cpIsTurning or cpIsTurningTwo or aiIsTurning --or combineSteering

    --local b = AutoDrive.boolToString
    --print("cpIsTurning: " .. b(cpIsTurning) .. " cpIsTurningTwo: " .. b(cpIsTurningTwo) .. " aiIsTurning: " .. b(aiIsTurning) .. " combineIsTurning: " .. b(combineIsTurning) .. " driveForwardDone: " .. b(combine.ad.driveForwardTimer:done()))
    if not combineIsTurning then --(combine.ad.driveForwardTimer:done() and (not combine:getIsBufferCombine()))
        return false
    end
    if combine.ad.noMovementTimer.elapsedTime > 3000 then
        return false
    end
    return true
end

function AutoDrive.pointIsBetweenTwoPoints(x, z, startX, startZ, endX, endZ)
    local xInside = (startX >= x and endX <= x) or (startX <= x and endX >= x)
    local zInside = (startZ >= z and endZ <= z) or (startZ <= z and endZ >= z)
    return xInside and zInside
end

function AutoDrive.semanticVersionToValue(versionString)
    local codes = versionString:split(".")
    local value = 0
    if codes ~= nil then
        for i, code in ipairs(codes) do
            local subCodes = code:split("-")
            if subCodes ~= nil and subCodes[1] ~= nil then
                value = value * 10 + tonumber(subCodes[1])
                if subCodes[2] ~= nil then
                    value = value + (tonumber(subCodes[2]) / 1000)
                end
            end
        end
    end

    return value
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

function AutoDrive.isVehicleInBunkerSiloArea(vehicle)
    for _, trigger in pairs(ADTriggerManager.getUnloadTriggers()) do
        local x, y, z = getWorldTranslation(vehicle.components[1].node)
        local tx, _, tz = x, y, z + 1
        if trigger ~= nil and trigger.bunkerSiloArea ~= nil then
            local x1, z1 = trigger.bunkerSiloArea.sx, trigger.bunkerSiloArea.sz
            local x2, z2 = trigger.bunkerSiloArea.wx, trigger.bunkerSiloArea.wz
            local x3, z3 = trigger.bunkerSiloArea.hx, trigger.bunkerSiloArea.hz
            if MathUtil.hasRectangleLineIntersection2D(x1, z1, x2 - x1, z2 - z1, x3 - x1, z3 - z1, x, z, tx - x, tz - z) then
                return true
            end
        end

        local trailers, trailerCount = AutoDrive.getTrailersOf(vehicle)
        if trailerCount > 0 then
            for _, trailer in pairs(trailers) do
                if AutoDrive.isTrailerInBunkerSiloArea(trailer, trigger) then
                    return true
                end
            end
        end
    end

    return false
end
