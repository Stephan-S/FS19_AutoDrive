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

function AutoDrive.sign(x)
    if x<0 then
        return -1
    elseif x>0 then
        return 1
    else
        return 0
    end
end

function AutoDrive.getPipeSlopeCorrection(combineNode, dischargeNode)
    local combineX, combineY, combineZ = getWorldTranslation(combineNode)    
    local nodeX, nodeY, nodeZ = getWorldTranslation(dischargeNode)
    -- +1 means left, -1 means right. 0 means we don't know
    pipeSide = AutoDrive.sign(AutoDrive.getSetting("pipeOffset", self.vehicle))
    local heightUnderCombine = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, combineX, combineY, combineZ)
    g_logManager:info("heightUnderCombine: " .. heightUnderCombine);
    local heightUnderPipe = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, nodeX, nodeY, nodeZ)
    g_logManager:info("heightUnderPipe: " .. heightUnderPipe);

    -- want this to be negative if the ground is lower under the pipe
    local dh = heightUnderPipe - heightUnderCombine
    g_logManager:info("dh: " .. dh);
    local _, _, _, hyp = AutoDrive.getWorldDirection(combineX, heightUnderCombine, combineZ, nodeX, heightUnderPipe, nodeZ)
    g_logManager:info("hyp: " .. hyp);
    local run = math.sqrt(hyp * hyp - dh * dh)
    g_logManager:info("run: " .. run);
    local theta = math.asin(dh/hyp)
    g_logManager:info("theta: " .. theta)
    g_logManager:info("nodeY: " .. nodeY)
    local elevationCorrection = (run * math.cos(theta) + (nodeY - heightUnderPipe) * math.sin(theta)) - run
    g_logManager:info("elevationCorrection: " .. elevationCorrection)
    return elevationCorrection * pipeSide
end