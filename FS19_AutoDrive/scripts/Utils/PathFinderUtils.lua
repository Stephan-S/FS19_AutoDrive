function AutoDrive.getDriverRadius(vehicle)
    local minTurnRadius = AIVehicleUtil.getAttachedImplementsMaxTurnRadius(vehicle)
    if AIVehicleUtil.getAttachedImplementsMaxTurnRadius(vehicle) <= 5 then
        minTurnRadius = PathFinderModule.PP_CELL_X
    end

    local maxToolRadius = 0
    for _, implement in pairs(vehicle:getAttachedAIImplements()) do
        maxToolRadius = math.max(maxToolRadius, AIVehicleUtil.getMaxToolRadius(implement))
    end

    minTurnRadius = math.max(minTurnRadius, maxToolRadius)

    return minTurnRadius
end

function AutoDrive.boundingBoxFromCorners(cornerX, cornerZ, corner2X, corner2Z, corner3X, corner3Z, corner4X, corner4Z)
    local boundingBox = {}
    boundingBox[1] = {
        x = cornerX,
        y = 0,
        z = cornerZ
    }
    boundingBox[2] = {
        x = corner2X,
        y = 0,
        z = corner2Z
    }
    boundingBox[3] = {
        x = corner3X,
        y = 0,
        z = corner3Z
    }
    boundingBox[4] = {
        x = corner4X,
        y = 0,
        z = corner4Z
    }

    return boundingBox
end

function AutoDrive.getTractorAndTrailersLength(vehicle, onlyfirst)
    local totalLength = vehicle.sizeLength
    g_logManager:info("Vechicle length: " .. vehicle.sizeLength)
    local trailers, _ = AutoDrive.getTrailersOf(vehicle, false)

    for _, trailer in ipairs(trailers) do
        g_logManager:info("Trailer length: " .. trailer.sizeLength)
        totalLength = totalLength + trailer.sizeLength
        if onlyFirst then
            break
        end
    end
    g_logManager:info("Total length: " .. totalLength)
    return totalLength
end

function AutoDrive.sign(x)
    if x<0 then
        return -1
    elseif x>0 then
        return 1
    else
        return 0
    end
end
