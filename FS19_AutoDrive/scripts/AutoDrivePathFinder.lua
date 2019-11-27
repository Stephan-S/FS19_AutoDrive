AutoDrive.MAX_PATHFINDER_STEPS_PER_FRAME = 20
AutoDrive.MAX_PATHFINDER_STEPS_TOTAL = 400
AutoDrive.PATHFINDER_FOLLOW_DISTANCE = 44
AutoDrive.PATHFINDER_TARGET_DISTANCE = 14
AutoDrive.PATHFINDER_TARGET_DISTANCE_PIPE = 20
AutoDrive.PATHFINDER_TARGET_DISTANCE_PIPE_CLOSE = 9
AutoDrive.PATHFINDER_START_DISTANCE = 7 --15;
AutoDrive.PP_UP = 0
AutoDrive.PP_UP_RIGHT = 1
AutoDrive.PP_RIGHT = 2
AutoDrive.PP_DOWN_RIGHT = 3
AutoDrive.PP_DOWN = 4
AutoDrive.PP_DOWN_LEFT = 5
AutoDrive.PP_LEFT = 6
AutoDrive.PP_UP_LEFT = 7

AutoDrive.PP_MIN_DISTANCE = 20
AutoDrive.PP_CELL_X = 9
AutoDrive.PP_CELL_Z = 9
AutoDrivePathFinder = {}

function AutoDrivePathFinder:startPathPlanningToCombine(driver, combine, dischargeNode, alreadyOnField)
    --g_logManager:devInfo("startPathPlanningToCombine " .. driver.ad.driverName );
    local _, worldY, _ = getWorldTranslation(combine.components[1].node)
    local rx, _, rz = localDirectionToWorld(combine.components[1].node, 0, 0, 1)
    local combineVector = {x = rx, z = rz}
    local combineNormalVector = {x = -combineVector.z, z = combineVector.x}

    local wpAhead
    local wpCurrent
    local wpBehind_close
    local wpBehind

    local firstBinIsOnDriver = false
    local trailers, trailerCount = AutoDrive.getTrailersOf(driver)
    if trailers[1] ~= nil and driver == trailers[1] then
        firstBinIsOnDriver = true
    end

    if dischargeNode == nil then
        local followDistance = AutoDrive.PATHFINDER_FOLLOW_DISTANCE
        local fillLevel, leftCapacity = AutoDrive.getFilteredFillLevelAndCapacityOfAllUnits(combine)
        local maxCapacity = fillLevel + leftCapacity
        local combineFillLevel = (fillLevel / maxCapacity)

        if combineFillLevel <= 0.80 or combine:getIsBufferCombine() then
            followDistance = 0
        end

        local leftBlocked = combine.ad.sensors.leftSensorFruit:pollInfo() or combine.ad.sensors.leftSensor:pollInfo() or (not combine.ad.sensors.leftSensorField:pollInfo())
        local rightBlocked = combine.ad.sensors.rightSensorFruit:pollInfo() or combine.ad.sensors.rightSensor:pollInfo() or (not combine.ad.sensors.rightSensorField:pollInfo())

        local leftFrontBlocked = combine.ad.sensors.leftFrontSensorFruit:pollInfo()
        local rightFrontBlocked = combine.ad.sensors.rightFrontSensorFruit:pollInfo()

        if (not leftBlocked) and (not rightBlocked) then
            if (not leftFrontBlocked) and rightFrontBlocked then
                rightBlocked = true
            elseif leftFrontBlocked and (not rightFrontBlocked) then
                leftBlocked = true
            end
        end

        local pipeChasePos, _ = AutoDrive:getPipeChasePosition(driver, combine, combine:getIsBufferCombine(), leftBlocked, rightBlocked)
        wpAhead = {x = pipeChasePos.x, y = pipeChasePos.y, z = pipeChasePos.z}

        wpBehind = {x = pipeChasePos.x - AutoDrive.PATHFINDER_TARGET_DISTANCE * rx, y = pipeChasePos.y, z = pipeChasePos.z - AutoDrive.PATHFINDER_TARGET_DISTANCE * rz}
        driver.ad.waitForPreDriveTimer = 10000
    else
        local nodeX, nodeY, nodeZ = getWorldTranslation(dischargeNode)
        local pipeOffset = AutoDrive.getSetting("pipeOffset", driver)
        local trailerOffset = AutoDrive.getSetting("trailerOffset", driver)
        local lengthOffset = 5 + driver.sizeLength / 2
        if firstBinIsOnDriver then
            lengthOffset = 0
        end

        if lengthOffset ~= 0 or trailerOffset ~= 0 then
            wpAhead = {x = (nodeX + (lengthOffset + trailerOffset) * rx) - pipeOffset * combineNormalVector.x, y = worldY, z = nodeZ + (lengthOffset + trailerOffset) * rz - pipeOffset * combineNormalVector.z}
        end
        wpCurrent = {x = (nodeX - pipeOffset * combineNormalVector.x), y = worldY, z = nodeZ - pipeOffset * combineNormalVector.z}
        wpBehind_close = {x = (nodeX - AutoDrive.PATHFINDER_TARGET_DISTANCE_PIPE_CLOSE * rx - pipeOffset * combineNormalVector.x), y = worldY, z = nodeZ - AutoDrive.PATHFINDER_TARGET_DISTANCE_PIPE_CLOSE * rz - pipeOffset * combineNormalVector.z}

        wpBehind = {x = (nodeX - AutoDrive.PATHFINDER_TARGET_DISTANCE_PIPE * rx - pipeOffset * combineNormalVector.x), y = worldY, z = nodeZ - AutoDrive.PATHFINDER_TARGET_DISTANCE_PIPE * rz - pipeOffset * combineNormalVector.z} --make this target
    end

    local driverWorldX, driverWorldY, driverWorldZ = getWorldTranslation(driver.components[1].node)
    local driverRx, driverRy, driverRz = localDirectionToWorld(driver.components[1].node, 0, 0, 1)
    local driverVector = {x = driverRx, z = driverRz}

    local startDistance = AutoDrive.PATHFINDER_START_DISTANCE
    if dischargeNode == nil then
        startDistance = 4
    end

    local startX = driverWorldX + startDistance * driverRx
    local startZ = driverWorldZ + startDistance * driverRz

    --local atan = AutoDrive.normalizeAngle(math.atan2(driverVector.z, driverVector.x))
    local atan = AutoDrive.normalizeAngle(math.atan2(combineVector.z, combineVector.x))

    local sin = math.sin(atan)
    local cos = math.cos(atan)

    local minTurnRadius = AutoDrivePathFinder:getDriverRadius(driver)

    local vectorX = {}
    vectorX.x = cos * minTurnRadius
    vectorX.z = sin * minTurnRadius

    local vectorZ = {}
    vectorZ.x = -sin * minTurnRadius
    vectorZ.z = cos * minTurnRadius

    AutoDrivePathFinder:init(driver, startX, startZ, wpBehind.x, wpBehind.z, combineVector, vectorX, vectorZ, combine, driverVector)

    driver.ad.pf.minTurnRadius = minTurnRadius

    driver.ad.pf.appendWayPoints = {}
    local appendCount = 1
    if wpBehind_close ~= nil then
        driver.ad.pf.appendWayPoints[appendCount] = wpBehind_close
        appendCount = appendCount + 1
    end
    if wpCurrent ~= nil then
        driver.ad.pf.appendWayPoints[appendCount] = wpCurrent
        appendCount = appendCount + 1
    end
    if wpAhead ~= nil then
        driver.ad.pf.appendWayPoints[appendCount] = wpAhead
    end
    driver.ad.pf.appendWayPointCount = appendCount

    driver.ad.pf.goingToCombine = true

    if dischargeNode == nil then
        driver.ad.pf.preDriveCombine = true
    else
        driver.ad.pf.preDriveCombine = false
    end

    if alreadyOnField or (AutoDrive.getDistanceToTargetPosition(driver) > 10) then
        driver.ad.pf.alreadyOnField = true
    else
        driver.ad.pf.alreadyOnField = false
    end

    if combine.spec_combine ~= nil then
        if combine.spec_combine.fillUnitIndex ~= nil and combine.spec_combine.fillUnitIndex ~= 0 then
            local fillType = g_fruitTypeManager:getFruitTypeIndexByFillTypeIndex(combine:getFillUnitFillType(combine.spec_combine.fillUnitIndex))
            if fillType ~= nil and (not combine:getIsBufferCombine()) then
                driver.ad.pf.fruitToCheck = fillType
                driver.ad.combineFruitToCheck = driver.ad.pf.fruitToCheck
            end
        end
    end

    local startIsOnField = AutoDrivePathFinder:checkIsOnField(driverWorldX, driverWorldY, driverWorldZ)
    local endIsOnField = AutoDrivePathFinder:checkIsOnField(wpBehind.x, worldY, wpBehind.z)

    driver.ad.pf.restrictToField = startIsOnField and endIsOnField
end

function AutoDrivePathFinder:startPathPlanningToStartPosition(driver, combine, ignoreFruit)
    --g_logManager:devInfo("startPathPlanningToStartPosition " .. driver.ad.driverName );
    local driverWorldX, driverWorldY, driverWorldZ = getWorldTranslation(driver.components[1].node)
    local driverRx, _, driverRz = localDirectionToWorld(driver.components[1].node, 0, 0, 1)
    local driverVector = {x = driverRx, z = driverRz}
    local startX = driverWorldX + AutoDrive.PATHFINDER_START_DISTANCE * driverRx
    local startZ = driverWorldZ + AutoDrive.PATHFINDER_START_DISTANCE * driverRz

    local targetPoint = AutoDrive.mapWayPoints[AutoDrive.mapMarker[driver.ad.mapMarkerSelected].id]
    local preTargetPoint = AutoDrive.mapWayPoints[targetPoint.incoming[1]]
    local targetVector = {}
    local waypointsToUnload = AutoDrive:FastShortestPath(AutoDrive.mapWayPoints, AutoDrive.mapMarker[driver.ad.mapMarkerSelected].id, AutoDrive.mapMarker[driver.ad.mapMarkerSelected_Unload].name, AutoDrive.mapMarker[driver.ad.mapMarkerSelected_Unload].id)
    if waypointsToUnload ~= nil and waypointsToUnload[6] ~= nil then
        preTargetPoint = AutoDrive.mapWayPoints[waypointsToUnload[1].id]
        targetPoint = AutoDrive.mapWayPoints[waypointsToUnload[2].id]
    end

    local exitStrategy = AutoDrive.getSetting("exitField", driver)
    if exitStrategy == 1 and driver.ad.combineState ~= AutoDrive.DRIVE_TO_PARK_POS then
        if waypointsToUnload ~= nil and waypointsToUnload[6] ~= nil then
            preTargetPoint = AutoDrive.mapWayPoints[waypointsToUnload[5].id]
            targetPoint = AutoDrive.mapWayPoints[waypointsToUnload[6].id]
        end
    elseif exitStrategy == 2 and driver.ad.combineState ~= AutoDrive.DRIVE_TO_PARK_POS then
        --local closest, _ = AutoDrive:findClosestWayPoint(driver)
        local closest = AutoDrive:findMatchingWayPointForVehicle(driver)
        waypointsToUnload = AutoDrive:FastShortestPath(AutoDrive.mapWayPoints, closest, AutoDrive.mapMarker[driver.ad.mapMarkerSelected_Unload].name, AutoDrive.mapMarker[driver.ad.mapMarkerSelected_Unload].id)
        if waypointsToUnload ~= nil and waypointsToUnload[2] ~= nil then
            preTargetPoint = AutoDrive.mapWayPoints[waypointsToUnload[1].id]
            targetPoint = AutoDrive.mapWayPoints[waypointsToUnload[2].id]
        end
    end

    targetVector.x = targetPoint.x - preTargetPoint.x
    targetVector.z = targetPoint.z - preTargetPoint.z

    local atan = AutoDrive.normalizeAngle(math.atan2(targetVector.z, targetVector.x))
    local sin = math.sin(atan)
    local cos = math.cos(atan)

    local minTurnRadius = AutoDrivePathFinder:getDriverRadius(driver)

    local vectorX = {}
    vectorX.x = cos * minTurnRadius
    vectorX.z = sin * minTurnRadius

    local vectorZ = {}
    vectorZ.x = -sin * minTurnRadius
    vectorZ.z = cos * minTurnRadius

    local angleRad = math.atan2(targetVector.z, targetVector.x)

    angleRad = AutoDrive.normalizeAngle(angleRad)

    local targetX = preTargetPoint.x - math.cos(angleRad) * AutoDrive.PATHFINDER_TARGET_DISTANCE --Make the target a few meters ahead of the road to the start point
    local targetZ = preTargetPoint.z - math.sin(angleRad) * AutoDrive.PATHFINDER_TARGET_DISTANCE

    AutoDrivePathFinder:init(driver, startX, startZ, targetX, targetZ, targetVector, vectorX, vectorZ, combine, driverVector)

    driver.ad.pf.minTurnRadius = minTurnRadius
    driver.ad.pf.appendWayPoints = {}
    driver.ad.pf.appendWayPoints[1] = preTargetPoint
    driver.ad.pf.appendWayPoints[2] = targetPoint
    driver.ad.pf.appendWayPointCount = 2

    if driver.ad.mode ~= AutoDrive.MODE_UNLOAD then --add waypoints to actual target
        local nextPoints = {}
        if driver.ad.skipStart == true then
            driver.ad.skipStart = false
            if AutoDrive.mapMarker[driver.ad.mapMarkerSelected_Unload] == nil then
                return
            end
            nextPoints = AutoDrive:FastShortestPath(AutoDrive.mapWayPoints, targetPoint.id, AutoDrive.mapMarker[driver.ad.mapMarkerSelected_Unload].name, AutoDrive.mapMarker[driver.ad.mapMarkerSelected_Unload].id)
        else
            if AutoDrive.mapMarker[driver.ad.mapMarkerSelected] == nil then
                return
            end
            nextPoints = AutoDrive:FastShortestPath(AutoDrive.mapWayPoints, targetPoint.id, AutoDrive.mapMarker[driver.ad.mapMarkerSelected].name, driver.ad.targetSelected)
        end

        local i = 2
        for _, point in pairs(nextPoints) do
            driver.ad.pf.appendWayPoints[i] = point
            driver.ad.pf.appendWayPointCount = i
            i = i + 1
        end
    end

    driver.ad.pf.goingToCombine = false
    driver.ad.pf.ignoreFruit = ignoreFruit

    local startIsOnField = AutoDrivePathFinder:checkIsOnField(driverWorldX, driverWorldY, driverWorldZ)
    local endIsOnField = AutoDrivePathFinder:checkIsOnField(targetX, driverWorldY, targetZ)

    driver.ad.pf.restrictToField = startIsOnField and endIsOnField
end

function AutoDrivePathFinder:getDriverRadius(driver)
    local minTurnRadius = (AIVehicleUtil.getAttachedImplementsMaxTurnRadius(driver) + 5) / 2
    if AIVehicleUtil.getAttachedImplementsMaxTurnRadius(driver) <= 5 then
        minTurnRadius = AutoDrive.PP_CELL_X
    end
    --minTurnRadius = math.max(minTurnRadius, AutoDrive.PP_CELL_X);

    local maxToolRadius = 0
    for _, implement in pairs(driver:getAttachedAIImplements()) do
        maxToolRadius = math.max(maxToolRadius, (AIVehicleUtil.getMaxToolRadius(implement) + 5) / 2)
    end

    minTurnRadius = math.max(minTurnRadius, maxToolRadius)

    AutoDrive.debugPrint(driver, AutoDrive.DC_PATHINFO, " startPathPlanningToCombine - minTurnRadius: " .. minTurnRadius .. " AI: " .. AIVehicleUtil.getAttachedImplementsMaxTurnRadius(driver) .. " tools: " .. maxToolRadius)

    return minTurnRadius
end

function AutoDrivePathFinder:init(driver, startX, startZ, targetX, targetZ, targetVector, vectorX, vectorZ, combine, startVector)
    driver.ad.pf = {}
    driver.ad.pf.driver = driver
    --driver.ad.combineUnloadInFruit = false;
    driver.ad.combineUnloadInFruitWaitTimer = AutoDrive.UNLOAD_WAIT_TIMER
    driver.ad.pf.grid = {}
    driver.ad.pf.startX = startX
    driver.ad.pf.startZ = startZ
    driver.ad.pf.vectorX = vectorX
    driver.ad.pf.vectorZ = vectorZ
    driver.ad.pf.targetVector = targetVector
    driver.ad.pf.steps = 0
    driver.ad.pf.isFinished = false
    driver.ad.pf.fallBackMode = false
    driver.ad.pf.combine = combine
    driver.ad.pf.fruitToCheck = driver.ad.combineFruitToCheck
    if (driver.ad.combineFruitToCheck == nil) and (driver.ad.pf.combine ~= nil) then
        driver.ad.pf.fruitToCheck = nil
    end

    driver.ad.currentTrailer = 1
    driver.ad.designatedTrailerFillLevel = math.huge

    local startCell = {x = 0, z = 0}
    --startCell.direction = AutoDrive.PP_UP
    startCell.direction = AutoDrivePathFinder:worldDirectionToGridDirection(driver.ad.pf, startVector)
    startCell.visited = false
    startCell.isRestricted = false
    startCell.hasCollision = false
    startCell.hasInfo = true
    startCell.hasFruit = false
    startCell.steps = 0
    driver.ad.pf.startCell = startCell

    driver.ad.pf.targetCell = AutoDrivePathFinder:worldLocationToGridLocation(driver.ad.pf, targetX, targetZ)
    --local targetDirection = AutoDrivePathFinder:worldDirectionToGridDirection(driver.ad.pf, targetVector)
    --AutoDrivePathFinder:determineBlockedCells(driver.ad.pf, targetDirection, driver.ad.pf.targetCell)
    AutoDrivePathFinder:determineBlockedCells(driver.ad.pf, AutoDrive.PP_UP, driver.ad.pf.targetCell)

    table.insert(driver.ad.pf.grid, startCell)
    driver.ad.pf.smoothStep = 0
    driver.ad.pf.smoothDone = false
    driver.ad.pf.target = {x = targetX, z = targetZ}
end

function AutoDrivePathFinder:updatePathPlanning(driver)
    local pf = driver.ad.pf
    if driver.ad.createMapPoints and AutoDrive.getDebugChannelIsSet(AutoDrive.DC_PATHINFO) then
        AutoDrivePathFinder:drawDebugForPF(pf)
    end
    pf.steps = pf.steps + 1

    if pf.isFinished and pf.smoothDone == true then
        return
    end

    if pf.isFinished and pf.smoothDone == false then
        AutoDrivePathFinder:createWayPoints(pf)
        return
    end

    if pf.steps > (AutoDrive.MAX_PATHFINDER_STEPS_TOTAL * AutoDrive.getSetting("pathFinderTime")) then
        if not pf.fallBackMode then --look for path through fruit
            --g_logManager:devInfo("Going into fallback mode - no fruit free path found in reasonable time");
            pf.fallBackMode = true
            pf.steps = 0
            pf.grid = {}
            pf.startCell.visited = false
            pf.currentCell = nil
            table.insert(pf.grid, pf.startCell)
            local targetDirection = AutoDrivePathFinder:worldDirectionToGridDirection(pf, pf.targetVector)
            AutoDrivePathFinder:determineBlockedCells(pf, targetDirection, pf.targetCell)
            pf.smoothStep = 0
            pf.smoothDone = false
        else
            --stop searching
            pf.isFinished = true
            pf.smoothDone = true
            pf.wayPoints = {}
            if driver.ad.combineState ~= AutoDrive.PREDRIVE_COMBINE then
                AutoDrive.printMessage(driver, g_i18n:getText("AD_Driver_of") .. " " .. driver.ad.driverName .. " " .. g_i18n:getText("AD_cannot_find_path"))
            --g_logManager:devInfo("Stop searching - no path found in reasonable time");
            end
        end
    end

    for i = 1, AutoDrive.MAX_PATHFINDER_STEPS_PER_FRAME, 1 do
        if pf.currentCell == nil then
            local minDistance = math.huge
            local bestCell = nil
            local bestSteps = math.huge

            local bestCellRatio = nil
            local minRatio = 0

            local grid = pf.grid
            for _, cell in pairs(grid) do
                --also checking for preDriveCombine here -> don't ever drive through fruit in preDrive mode -> this will often result in driver cutting through fruit in front of combine!
                if not cell.visited and ((not cell.isRestricted) or (pf.fallBackMode and (not pf.preDriveCombine))) and (not cell.hasCollision) and cell.hasInfo == true then
                    local distance = AutoDrivePathFinder.cellDistance(pf, cell)
                    local originalDistance = AutoDrivePathFinder.cellDistance(pf, pf.startCell)
                    local ratio = (originalDistance - distance) / cell.steps

                    if distance < minDistance then
                        minDistance = distance
                        bestCell = cell
                        bestSteps = cell.steps
                    elseif distance == minDistance and cell.steps < bestSteps then
                        minDistance = distance
                        bestCell = cell
                        bestSteps = cell.steps
                    end

                    if ratio > minRatio then
                        minRatio = ratio
                        bestCellRatio = cell
                    end
                end
            end

            if bestCellRatio ~= nil and math.random() > 1 then --0.4 then
                pf.currentCell = bestCellRatio
            else
                pf.currentCell = bestCell
            end

            if pf.currentCell ~= nil and AutoDrivePathFinder.cellDistance(pf, pf.currentCell) == 0 then
                pf.isFinished = true
                pf.targetCell.incoming = pf.currentCell.incoming
                if pf.currentCell.hasFruit ~= nil then
                    pf.driver.ad.combineUnloadInFruit = pf.currentCell.hasFruit
                end
                AutoDrivePathFinder:createWayPoints(pf)
            end

            if pf.currentCell == nil then
                pf.grid = {}
                pf.startCell.visited = false
                table.insert(pf.grid, pf.startCell)
                local targetDirection = AutoDrivePathFinder:worldDirectionToGridDirection(pf, pf.targetVector)
                AutoDrivePathFinder:determineBlockedCells(pf, targetDirection, pf.targetCell)
            end
        else
            if pf.currentCell.out == nil then
                AutoDrivePathFinder:determineNextGridCells(pf, pf.currentCell)
            end
            AutoDrivePathFinder:testNextCells(pf, pf.currentCell)
        end
    end
    driver.ad.pf = pf
end

function AutoDrivePathFinder:isPathPlanningFinished(driver)
    if driver.ad.pf ~= nil then
        if driver.ad.pf.isFinished == true and driver.ad.pf.smoothDone == true then
            if driver.ad.createMapPoints and AutoDrive.getDebugChannelIsSet(AutoDrive.DC_PATHINFO) then
                AutoDrivePathFinder.drawDebugForCreatedRoute(driver.ad.pf)
            else
                return true
            end
        end
    end
    return false
end

function AutoDrivePathFinder:determineNextGridCells(pf, cell)
    cell.out = {}
    if cell.direction == AutoDrive.PP_UP then
        cell.out[1] = {x = cell.x + 1, z = cell.z - 1}
        cell.out[1].direction = AutoDrive.PP_UP_LEFT
        cell.out[2] = {x = cell.x + 1, z = cell.z + 0}
        cell.out[2].direction = AutoDrive.PP_UP
        cell.out[3] = {x = cell.x + 1, z = cell.z + 1}
        cell.out[3].direction = AutoDrive.PP_UP_RIGHT
    elseif cell.direction == AutoDrive.PP_UP_RIGHT then
        cell.out[1] = {x = cell.x + 1, z = cell.z + 0}
        cell.out[1].direction = AutoDrive.PP_UP
        cell.out[2] = {x = cell.x + 1, z = cell.z + 1}
        cell.out[2].direction = AutoDrive.PP_UP_RIGHT
        cell.out[3] = {x = cell.x + 0, z = cell.z + 1}
        cell.out[3].direction = AutoDrive.PP_RIGHT
    elseif cell.direction == AutoDrive.PP_RIGHT then
        cell.out[1] = {x = cell.x + 1, z = cell.z + 1}
        cell.out[1].direction = AutoDrive.PP_UP_RIGHT
        cell.out[2] = {x = cell.x + 0, z = cell.z + 1}
        cell.out[2].direction = AutoDrive.PP_RIGHT
        cell.out[3] = {x = cell.x - 1, z = cell.z + 1}
        cell.out[3].direction = AutoDrive.PP_DOWN_RIGHT
    elseif cell.direction == AutoDrive.PP_DOWN_RIGHT then
        cell.out[1] = {x = cell.x + 0, z = cell.z + 1}
        cell.out[1].direction = AutoDrive.PP_RIGHT
        cell.out[2] = {x = cell.x - 1, z = cell.z + 1}
        cell.out[2].direction = AutoDrive.PP_DOWN_RIGHT
        cell.out[3] = {x = cell.x - 1, z = cell.z + 0}
        cell.out[3].direction = AutoDrive.PP_DOWN
    elseif cell.direction == AutoDrive.PP_DOWN then
        cell.out[1] = {x = cell.x - 1, z = cell.z + 1}
        cell.out[1].direction = AutoDrive.PP_DOWN_RIGHT
        cell.out[2] = {x = cell.x - 1, z = cell.z + 0}
        cell.out[2].direction = AutoDrive.PP_DOWN
        cell.out[3] = {x = cell.x - 1, z = cell.z - 1}
        cell.out[3].direction = AutoDrive.PP_DOWN_LEFT
    elseif cell.direction == AutoDrive.PP_DOWN_LEFT then
        cell.out[1] = {x = cell.x - 1, z = cell.z - 0}
        cell.out[1].direction = AutoDrive.PP_DOWN
        cell.out[2] = {x = cell.x - 1, z = cell.z - 1}
        cell.out[2].direction = AutoDrive.PP_DOWN_LEFT
        cell.out[3] = {x = cell.x - 0, z = cell.z - 1}
        cell.out[3].direction = AutoDrive.PP_LEFT
    elseif cell.direction == AutoDrive.PP_LEFT then
        cell.out[1] = {x = cell.x - 1, z = cell.z - 1}
        cell.out[1].direction = AutoDrive.PP_DOWN_LEFT
        cell.out[2] = {x = cell.x - 0, z = cell.z - 1}
        cell.out[2].direction = AutoDrive.PP_LEFT
        cell.out[3] = {x = cell.x + 1, z = cell.z - 1}
        cell.out[3].direction = AutoDrive.PP_UP_LEFT
    elseif cell.direction == AutoDrive.PP_UP_LEFT then
        cell.out[1] = {x = cell.x - 0, z = cell.z - 1}
        cell.out[1].direction = AutoDrive.PP_LEFT
        cell.out[2] = {x = cell.x + 1, z = cell.z - 1}
        cell.out[2].direction = AutoDrive.PP_UP_LEFT
        cell.out[3] = {x = cell.x + 1, z = cell.z + 0}
        cell.out[3].direction = AutoDrive.PP_UP
    end

    for _, outGoing in pairs(cell.out) do
        outGoing.incoming = cell
        outGoing.steps = cell.steps + 1
    end
end

function AutoDrivePathFinder:testNextCells(pf, cell)
    local allResultsIn = true
    for _, location in pairs(cell.out) do
        local createPoint = true
        local grid = pf.grid
        for _, c in pairs(grid) do
            if c.x == location.x and c.z == location.z and c.direction == location.direction then
                createPoint = false
                if c.steps > (cell.steps + 1) then --found shortcut
                    c.incoming = cell
                    c.steps = cell.steps + 1
                end
                location.hasInfo = c.hasInfo
                location.isRestricted = c.isRestricted
                location.hasFruit = c.hasFruit
                location.hasCollision = c.hasCollision
            end

            if c.x == location.x and c.z == location.z and c.direction == -1 then
                location.isRestricted = true
                location.hasInfo = true
                location.hasFruit = true
                location.hasCollision = true
                createPoint = false
            end
        end

        if createPoint then
            AutoDrivePathFinder:createGridCells(pf, location)
        end

        if not location.hasInfo then
            AutoDrivePathFinder:checkGridCell(pf, location)
        end

        allResultsIn = allResultsIn and location.hasInfo
    end

    if allResultsIn then
        --g_logManager:devInfo("All result are in for: " .. cell.x .. "/" .. cell.z);
        cell.visited = true
        pf.currentCell = nil
    end
end

function AutoDrivePathFinder:createGridCells(pf, location)
    location.visited = false
    location.isRestricted = false
    location.hasInfo = false
    location.hasCollision = false
    location.hasFruit = true
    table.insert(pf.grid, location)
end

function AutoDrivePathFinder:checkGridCell(pf, cell)
    if cell.hasInfo == false then
        if cell.x == pf.targetCell.x and cell.z == pf.targetCell.z then
            cell.isRestricted = false
            cell.hasCollision = false
            cell.hasFruit = false
            cell.hasInfo = true
            return
        end

        local worldPos = AutoDrivePathFinder:gridLocationToWorldLocation(pf, cell)

        local cornerX = worldPos.x + (-pf.vectorX.x - pf.vectorZ.x) / 2
        local cornerZ = worldPos.z + (-pf.vectorX.z - pf.vectorZ.z) / 2

        local corner2X = worldPos.x + (pf.vectorX.x - pf.vectorZ.x) / 2
        local corner2Z = worldPos.z + (pf.vectorX.z - pf.vectorZ.z) / 2

        local corner3X = worldPos.x + (-pf.vectorX.x + pf.vectorZ.x) / 2
        local corner3Z = worldPos.z + (-pf.vectorX.z + pf.vectorZ.z) / 2

        local corner4X = worldPos.x + (pf.vectorX.x + pf.vectorZ.x) / 2
        local corner4Z = worldPos.z + (pf.vectorX.z + pf.vectorZ.z) / 2

        local shapeDefinition = AutoDrivePathFinder.getShapeDefByDirectionType(pf, cell)

        local angleRad = math.atan2(pf.targetVector.z, pf.targetVector.x)
        angleRad = AutoDrive.normalizeAngle(angleRad)
        local y = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, worldPos.x, 1, worldPos.z)
        local shapes = overlapBox(shapeDefinition.x, shapeDefinition.y + 3, shapeDefinition.z, 0, shapeDefinition.angleRad, 0, shapeDefinition.widthX, shapeDefinition.height, shapeDefinition.widthZ, "collisionTestCallbackIgnore", nil, AIVehicleUtil.COLLISION_MASK, true, true, true)

        cell.hasCollision = (shapes > 0)

        local worldPosPrevious = AutoDrivePathFinder:gridLocationToWorldLocation(pf, cell.incoming)
        cell.hasCollision = cell.hasCollision or AutoDrivePathFinder:checkSlopeAngle(worldPos.x, worldPos.z, worldPosPrevious.x, worldPosPrevious.z)

        if (pf.ignoreFruit == nil or pf.ignoreFruit == false) and AutoDrive.getSetting("avoidFruit", pf.driver) then
            AutoDrivePathFinder.checkForFruitInArea(pf, cell, cornerX, cornerZ, corner2X, corner2Z, corner3X, corner3Z)
        else
            cell.isRestricted = false
            cell.hasFruit = not AutoDrive.getSetting("avoidFruit", pf.driver) --make sure that on fallback mode or when fruit avoidance is off, we don't park in the fruit next to the combine!
        end

        cell.hasInfo = true

        cell.isRestricted = cell.isRestricted or (pf.restrictToField and (not pf.fallBackMode) and (not AutoDrivePathFinder:checkIsOnField(worldPos.x, y, worldPos.z)))

        local boundingBox = AutoDrive:boundingBoxFromCorners(cornerX, cornerZ, corner2X, corner2Z, corner3X, corner3Z, corner4X, corner4Z)
        if AutoDrive:checkForVehiclesInBox(boundingBox) then
            cell.isRestricted = true
            cell.hasCollision = true
        end
    end
end

function AutoDrivePathFinder:checkIsOnField(worldX, worldY, worldZ)
    local densityBits = 0

    local bits = getDensityAtWorldPos(g_currentMission.terrainDetailId, worldX, worldY, worldZ)
    densityBits = bitOR(densityBits, bits)
    if densityBits ~= 0 or (AutoDrive.getSetting("restrictToField") == false) then
        return true
    end

    return false
end

function AutoDrivePathFinder:checkSlopeAngle(x1, z1, x2, z2)
    local vectorFromPrevious = {x = x1 - x2, z = z1 - z2}
    local worldPosMiddle = {x = x2 + vectorFromPrevious.x / 2, z = z2 + vectorFromPrevious.z / 2}

    local terrain1 = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, x1, 0, z1)
    local terrain2 = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, x2, 0, z2)
    local terrain3 = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, worldPosMiddle.x, 0, worldPosMiddle.z)
    local length = MathUtil.vector3Length(x1 - x2, terrain1 - terrain2, z1 - z2)
    local lengthMiddle = MathUtil.vector3Length(worldPosMiddle.x - x2, terrain3 - terrain2, worldPosMiddle.z - z2)
    local angleBetween = math.atan(math.abs(terrain1 - terrain2) / length)
    local angleBetweenCenter = math.atan(math.abs(terrain3 - terrain2) / lengthMiddle)

    if (angleBetween * 3) > AITurnStrategy.SLOPE_DETECTION_THRESHOLD or (angleBetweenCenter * 3) > AITurnStrategy.SLOPE_DETECTION_THRESHOLD then
        return true
    end
    return false
end

function AutoDrivePathFinder.getShapeDefByDirectionType(pf, cell)
    local shapeDefinition = {}
    shapeDefinition.angleRad = math.atan2(-pf.targetVector.z, pf.targetVector.x)
    shapeDefinition.angleRad = AutoDrive.normalizeAngle(shapeDefinition.angleRad)
    local worldPos = AutoDrivePathFinder:gridLocationToWorldLocation(pf, cell)
    shapeDefinition.y = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, worldPos.x, 1, worldPos.z)
    shapeDefinition.height = 2.85

    if cell.direction == AutoDrive.PP_UP or cell.direction == AutoDrive.PP_DOWN or cell.direction == AutoDrive.PP_RIGHT or cell.direction == AutoDrive.PP_LEFT then
        --default size:
        shapeDefinition.x = worldPos.x
        shapeDefinition.z = worldPos.z
        shapeDefinition.widthX = pf.minTurnRadius / 2
        shapeDefinition.widthZ = pf.minTurnRadius / 2
    elseif cell.direction == AutoDrive.PP_UP_RIGHT then
        local offsetX = (-pf.vectorX.x) / 2 + (-pf.vectorZ.x) / 4
        local offsetZ = (-pf.vectorX.z) / 2 + (-pf.vectorZ.z) / 4
        shapeDefinition.x = worldPos.x + offsetX
        shapeDefinition.z = worldPos.z + offsetZ
        shapeDefinition.widthX = (pf.minTurnRadius / 2) + math.abs(offsetX)
        shapeDefinition.widthZ = pf.minTurnRadius / 2 + math.abs(offsetZ)
    elseif cell.direction == AutoDrive.PP_UP_LEFT then
        local offsetX = (-pf.vectorX.x) / 2 + (pf.vectorZ.x) / 4
        local offsetZ = (-pf.vectorX.z) / 2 + (pf.vectorZ.z) / 4
        shapeDefinition.x = worldPos.x + offsetX
        shapeDefinition.z = worldPos.z + offsetZ
        shapeDefinition.widthX = pf.minTurnRadius / 2 + math.abs(offsetX)
        shapeDefinition.widthZ = pf.minTurnRadius / 2 + math.abs(offsetZ)
    elseif cell.direction == AutoDrive.PP_DOWN_RIGHT then
        local offsetX = (pf.vectorX.x) / 2 + (-pf.vectorZ.x) / 4
        local offsetZ = (pf.vectorX.z) / 2 + (-pf.vectorZ.z) / 4
        shapeDefinition.x = worldPos.x + offsetX
        shapeDefinition.z = worldPos.z + offsetZ
        shapeDefinition.widthX = pf.minTurnRadius / 2 + math.abs(offsetX)
        shapeDefinition.widthZ = pf.minTurnRadius / 2 + math.abs(offsetZ)
    elseif cell.direction == AutoDrive.PP_DOWN_LEFT then
        local offsetX = (pf.vectorX.x) / 2 + (pf.vectorZ.x) / 4
        local offsetZ = (pf.vectorX.z) / 2 + (pf.vectorZ.z) / 4
        shapeDefinition.x = worldPos.x + offsetX
        shapeDefinition.z = worldPos.z + offsetZ
        shapeDefinition.widthX = pf.minTurnRadius / 2 + math.abs(offsetX)
        shapeDefinition.widthZ = pf.minTurnRadius / 2 + math.abs(offsetZ)
    end

    return shapeDefinition
end

function AutoDrivePathFinder:createWayPoints(pf)
    if pf.smoothStep == 0 then
        local currentCell = pf.targetCell
        pf.chainTargetToStart = {}
        local index = 1
        pf.chainTargetToStart[index] = currentCell
        index = index + 1
        while currentCell.x ~= 0 or currentCell.z ~= 0 do
            pf.chainTargetToStart[index] = currentCell.incoming
            currentCell = currentCell.incoming
            if currentCell == nil then
                break
            end
            index = index + 1
        end
        index = index - 1

        pf.chainStartToTarget = {}
        for reversedIndex = 0, index, 1 do
            pf.chainStartToTarget[reversedIndex + 1] = pf.chainTargetToStart[index - reversedIndex]
        end

        --Now build actual world coordinates as waypoints and include pre and append points
        pf.wayPoints = {}
        for chainIndex, cell in pairs(pf.chainStartToTarget) do
            pf.wayPoints[chainIndex] = AutoDrivePathFinder:gridLocationToWorldLocation(pf, cell)
            pf.wayPoints[chainIndex].y = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, pf.wayPoints[chainIndex].x, 1, pf.wayPoints[chainIndex].z)
            pf.wayPoints[chainIndex].lastDirection = cell.direction
        end

        AutoDrivePathFinder:smoothResultingPPPath(pf)
    end

    if AutoDrive.getSetting("smoothField") == true then
        AutoDrivePathFinder:smoothResultingPPPath_Refined(pf)
    else
        pf.smoothStep = 2
        pf.smoothDone = true
    end

    if pf.smoothStep == 2 then
        if pf.appendWayPointCount ~= nil then
            for i = 1, pf.appendWayPointCount, 1 do
                pf.wayPoints[AutoDrive.tableLength(pf.wayPoints) + 1] = pf.appendWayPoints[i]
            end
            pf.smoothStep = 3
        end
    end
end

function AutoDrivePathFinder:smoothResultingPPPath(pf)
    local index = 1
    local filteredIndex = 1
    local filteredWPs = {}

    while index < AutoDrive.tableLength(pf.wayPoints) - 1 do
        local node = pf.wayPoints[index]
        local nodeAhead = pf.wayPoints[index + 1]
        local nodeTwoAhead = pf.wayPoints[index + 2]

        filteredWPs[filteredIndex] = node
        filteredIndex = filteredIndex + 1

        if node.lastDirection ~= nil and nodeAhead.lastDirection ~= nil and nodeTwoAhead.lastDirection ~= nil then
            if node.lastDirection == nodeTwoAhead.lastDirection and node.lastDirection ~= nodeAhead.lastDirection then
                index = index + 1 --skip next point because it is a zig zag line. Cut right through instead
            end
        end

        index = index + 1
    end

    while index <= AutoDrive.tableLength(pf.wayPoints) do
        local node = pf.wayPoints[index]
        filteredWPs[filteredIndex] = node
        filteredIndex = filteredIndex + 1
        index = index + 1
    end

    pf.wayPoints = filteredWPs
end

function AutoDrivePathFinder:smoothResultingPPPath_Refined(pf)
    if pf.smoothStep == 0 then
        pf.smoothIndex = 1
        pf.filteredIndex = 1
        pf.filteredWPs = {}

        --add first few without filtering
        while pf.smoothIndex < AutoDrive.tableLength(pf.wayPoints) and pf.smoothIndex < 3 do
            pf.filteredWPs[pf.filteredIndex] = pf.wayPoints[pf.smoothIndex]
            pf.filteredIndex = pf.filteredIndex + 1
            pf.smoothIndex = pf.smoothIndex + 1
        end

        pf.smoothStep = 1
    end

    local unfilteredEndPointCount = 5
    if pf.smoothStep == 1 then
        local stepsThisFrame = 0
        while pf.smoothIndex < AutoDrive.tableLength(pf.wayPoints) - unfilteredEndPointCount and stepsThisFrame < 1 do
            stepsThisFrame = stepsThisFrame + 1

            local node = pf.wayPoints[pf.smoothIndex]
            local previousNode = nil
            local worldPos = pf.wayPoints[pf.smoothIndex]

            if pf.totalEagerSteps == nil or pf.totalEagerSteps == 0 then
                pf.filteredWPs[pf.filteredIndex] = node
                if pf.filteredIndex > 1 then
                    previousNode = pf.filteredWPs[pf.filteredIndex - 1]
                end
                pf.filteredIndex = pf.filteredIndex + 1

                pf.lookAheadIndex = 1
                pf.eagerLookAhead = 0
                pf.totalEagerSteps = 0
            end

            local widthOfColBox = math.sqrt(math.pow(pf.minTurnRadius, 2) + math.pow(pf.minTurnRadius, 2))
            local sideLength = widthOfColBox / 2
            local y = worldPos.y
            local foundCollision = false

            local stepsOfLookAheadThisFrame = 0
            while (foundCollision == false or pf.totalEagerSteps < 30) and ((pf.smoothIndex + pf.totalEagerSteps) < (AutoDrive.tableLength(pf.wayPoints) - unfilteredEndPointCount)) and stepsOfLookAheadThisFrame < unfilteredEndPointCount do
                stepsOfLookAheadThisFrame = stepsOfLookAheadThisFrame + 1
                local nodeAhead = pf.wayPoints[pf.smoothIndex + pf.totalEagerSteps + 1]
                local nodeTwoAhead = pf.wayPoints[pf.smoothIndex + pf.totalEagerSteps + 2]

                local angle = AutoDrive.angleBetween({x = nodeAhead.x - node.x, z = nodeAhead.z - node.z}, {x = nodeTwoAhead.x - nodeAhead.x, z = nodeTwoAhead.z - nodeAhead.z})
                angle = math.abs(angle)

                local hasCollision = false
                if angle > 60 then
                    hasCollision = true
                end
                if previousNode ~= nil then
                    angle = AutoDrive.angleBetween({x = node.x - previousNode.x, z = node.z - previousNode.z}, {x = nodeTwoAhead.x - node.x, z = nodeTwoAhead.z - node.z})
                    angle = math.abs(angle)
                    if angle > 60 then
                        hasCollision = true
                    end
                    angle = AutoDrive.angleBetween({x = node.x - previousNode.x, z = node.z - previousNode.z}, {x = nodeAhead.x - node.x, z = nodeAhead.z - node.z})
                    angle = math.abs(angle)
                    if angle > 60 then
                        hasCollision = true
                    end
                end

                hasCollision = hasCollision or AutoDrivePathFinder:checkSlopeAngle(worldPos.x, worldPos.z, nodeAhead.x, nodeAhead.z)

                local vectorX = nodeAhead.x - node.x
                local vectorZ = nodeAhead.z - node.z
                local angleRad = math.atan2(-vectorZ, vectorX)
                angleRad = AutoDrive.normalizeAngle(angleRad)
                local length = math.sqrt(math.pow(vectorX, 2) + math.pow(vectorZ, 2)) + widthOfColBox

                local leftAngle = AutoDrive.normalizeAngle(angleRad + math.rad(-90))
                local rightAngle = AutoDrive.normalizeAngle(angleRad + math.rad(90))

                local cornerX = node.x - math.cos(leftAngle) * sideLength
                local cornerZ = node.z + math.sin(leftAngle) * sideLength

                local corner2X = nodeAhead.x - math.cos(leftAngle) * sideLength
                local corner2Z = nodeAhead.z + math.sin(leftAngle) * sideLength

                local corner3X = nodeAhead.x - math.cos(rightAngle) * sideLength
                local corner3Z = nodeAhead.z + math.sin(rightAngle) * sideLength

                local corner4X = node.x - math.cos(rightAngle) * sideLength
                local corner4Z = node.z + math.sin(rightAngle) * sideLength

                local shapes = overlapBox(worldPos.x + vectorX / 2, y + 3, worldPos.z + vectorZ / 2, 0, angleRad, 0, length / 2 + 2.5, 2.85, widthOfColBox / 2 + 1.5, "collisionTestCallbackIgnore", nil, AIVehicleUtil.COLLISION_MASK, true, true, true)
                hasCollision = hasCollision or (shapes > 0)

                if (pf.smoothIndex > 1) then
                    local worldPosPrevious = pf.wayPoints[pf.smoothIndex - 1]
                    local length = MathUtil.vector3Length(worldPos.x - worldPosPrevious.x, worldPos.y - worldPosPrevious.y, worldPos.z - worldPosPrevious.z)
                    local angleBetween = math.atan(math.abs(worldPos.y - worldPosPrevious.y) / length)

                    if angleBetween > AITurnStrategy.SLOPE_DETECTION_THRESHOLD then
                        hasCollision = true
                    end
                end

                if pf.fruitToCheck ~= nil then
                    local fruitValue, _, _, _ = FSDensityMapUtil.getFruitArea(pf.fruitToCheck, cornerX, cornerZ, corner2X, corner2Z, corner4X, corner4Z, nil, false)
                    if pf.fruitToCheck == 9 or pf.fruitToCheck == 22 then
                        fruitValue, _, _, _ = FSDensityMapUtil.getFruitArea(pf.fruitToCheck, cornerX, cornerZ, corner2X, corner2Z, corner4X, corner4Z, true, true)
                    end

                    hasCollision = hasCollision or (fruitValue > 50)
                end

                local cellBox = AutoDrive:boundingBoxFromCorners(cornerX, cornerZ, corner2X, corner2Z, corner3X, corner3Z, corner4X, corner4Z)
                hasCollision = hasCollision or AutoDrive:checkForVehiclesInBox(cellBox)

                foundCollision = hasCollision

                if foundCollision then
                    pf.eagerLookAhead = pf.eagerLookAhead + 1
                else
                    pf.lookAheadIndex = pf.totalEagerSteps + 1 --lookAheadIndex + 1 + eagerLookAhead;
                    pf.eagerLookAhead = 0
                end

                pf.totalEagerSteps = pf.totalEagerSteps + 1
            end

            if pf.totalEagerSteps >= 30 or ((pf.smoothIndex + pf.totalEagerSteps) >= (AutoDrive.tableLength(pf.wayPoints) - unfilteredEndPointCount)) then
                pf.smoothIndex = pf.smoothIndex + math.max(1, (pf.lookAheadIndex)) --(pf.lookAheadIndex-2)
                pf.totalEagerSteps = 0
            end
        end

        if pf.smoothIndex >= AutoDrive.tableLength(pf.wayPoints) - unfilteredEndPointCount then
            pf.smoothStep = 2
        end
    end

    if pf.smoothStep == 2 then
        --add remaining points without filtering
        while pf.smoothIndex <= AutoDrive.tableLength(pf.wayPoints) do
            local node = pf.wayPoints[pf.smoothIndex]
            pf.filteredWPs[pf.filteredIndex] = node
            pf.filteredIndex = pf.filteredIndex + 1
            pf.smoothIndex = pf.smoothIndex + 1
        end

        pf.wayPoints = pf.filteredWPs

        pf.smoothDone = true
    end
end

function AutoDrivePathFinder:gridLocationToWorldLocation(pf, cell)
    local result = {x = 0, z = 0}

    result.x = pf.startX + cell.x * pf.vectorX.x + cell.z * pf.vectorZ.x
    result.z = pf.startZ + cell.x * pf.vectorX.z + cell.z * pf.vectorZ.z

    return result
end

function AutoDrivePathFinder:worldLocationToGridLocation(pf, worldX, worldZ)
    local result = {x = 0, z = 0}

    result.z = (((worldX - pf.startX) / pf.vectorX.x) * pf.vectorX.z - worldZ + pf.startZ) / (((pf.vectorZ.x / pf.vectorX.x) * pf.vectorX.z) - pf.vectorZ.z)
    result.x = (worldZ - pf.startZ - result.z * pf.vectorZ.z) / pf.vectorX.z

    result.x = AutoDrive.round(result.x)
    result.z = AutoDrive.round(result.z)

    return result
end

function AutoDrivePathFinder:worldDirectionToGridDirection(pf, vector)
    local angleWorldDirection = math.atan2(vector.z, vector.x)
    angleWorldDirection = AutoDrive.normalizeAngle2(angleWorldDirection)

    local angleRad = math.atan2(pf.vectorX.z, pf.vectorX.x)
    angleRad = AutoDrive.normalizeAngle2(angleRad)

    local upRightAngle = AutoDrive.normalizeAngle2(angleRad + math.rad(45))
    local rightAngle = AutoDrive.normalizeAngle2(angleRad + math.rad(90))
    local downRightAngle = AutoDrive.normalizeAngle2(angleRad + math.rad(135))
    local downAngle = AutoDrive.normalizeAngle2(angleRad + math.rad(180))
    local downLeftAngle = AutoDrive.normalizeAngle2(angleRad + math.rad(225))
    local leftAngle = AutoDrive.normalizeAngle2(angleRad + math.rad(270))
    local upLeftAngle = AutoDrive.normalizeAngle2(angleRad + math.rad(315))

    local direction = AutoDrive.PP_UP

    if math.abs(math.deg(AutoDrive.normalizeAngle2(angleWorldDirection - upRightAngle))) <= 22.5 or math.abs(math.deg(AutoDrive.normalizeAngle2(angleWorldDirection - upRightAngle))) >= 337.5 then
        direction = AutoDrive.PP_UP_RIGHT
    elseif math.abs(math.deg(AutoDrive.normalizeAngle2(angleWorldDirection - rightAngle))) <= 22.5 or math.abs(math.deg(AutoDrive.normalizeAngle2(angleWorldDirection - rightAngle))) >= 337.5 then
        direction = AutoDrive.PP_RIGHT
    elseif math.abs(math.deg(AutoDrive.normalizeAngle2(angleWorldDirection - downRightAngle))) <= 22.5 or math.abs(math.deg(AutoDrive.normalizeAngle2(angleWorldDirection - downRightAngle))) >= 337.5 then
        direction = AutoDrive.PP_DOWN_RIGHT
    elseif math.abs(math.deg(AutoDrive.normalizeAngle2(angleWorldDirection - downAngle))) <= 22.5 or math.abs(math.deg(AutoDrive.normalizeAngle2(angleWorldDirection - downAngle))) >= 337.5 then
        direction = AutoDrive.PP_DOWN
    elseif math.abs(math.deg(AutoDrive.normalizeAngle2(angleWorldDirection - downLeftAngle))) <= 22.5 or math.abs(math.deg(AutoDrive.normalizeAngle2(angleWorldDirection - downLeftAngle))) >= 337.5 then
        direction = AutoDrive.PP_DOWN_LEFT
    elseif math.abs(math.deg(AutoDrive.normalizeAngle2(angleWorldDirection - leftAngle))) <= 22.5 or math.abs(math.deg(AutoDrive.normalizeAngle2(angleWorldDirection - leftAngle))) >= 337.5 then
        direction = AutoDrive.PP_LEFT
    elseif math.abs(math.deg(AutoDrive.normalizeAngle2(angleWorldDirection - upLeftAngle))) <= 22.5 or math.abs(math.deg(AutoDrive.normalizeAngle2(angleWorldDirection - upLeftAngle))) >= 337.5 then
        direction = AutoDrive.PP_UP_LEFT
    end

    return direction
end

function AutoDrivePathFinder:determineBlockedCells(pf, endDirection, cell)
    local x = cell.x
    local z = cell.z

    if (math.abs(cell.x) < 2 and math.abs(cell.z) < 2) then
        return
    end

    --block cells which would result in bad angles to the end/start point
    -- \|/  x|/  xx/  xxx  xxx  xxx  \xx  \|x
    -- x|x  x/-  x>-  x\-  x|x  -/x  -<x  -\x
    -- xxx  xxx  xx\  x|\  /|\  /|x  /xx  xxx
    if endDirection == AutoDrive.PP_DOWN then
        table.insert(pf.grid, {x = x - 1, z = z, direction = -1, hasInfo = true, isRestricted = true, hasCollision = true, steps = 1000})
        table.insert(pf.grid, {x = x - 1, z = z - 1, direction = -1, hasInfo = true, isRestricted = true, hasCollision = true, steps = 1000})
        table.insert(pf.grid, {x = x - 1, z = z + 1, direction = -1, hasInfo = true, isRestricted = true, hasCollision = true, steps = 1000})
        table.insert(pf.grid, {x = x + 0, z = z - 1, direction = -1, hasInfo = true, isRestricted = true, hasCollision = true, steps = 1000})
        table.insert(pf.grid, {x = x + 0, z = z + 1, direction = -1, hasInfo = true, isRestricted = true, hasCollision = true, steps = 1000})
    elseif endDirection == AutoDrive.PP_DOWN_LEFT then
        table.insert(pf.grid, {x = x - 1, z = z, direction = -1, hasInfo = true, isRestricted = true, hasCollision = true, steps = 1000})
        table.insert(pf.grid, {x = x - 1, z = z - 1, direction = -1, hasInfo = true, isRestricted = true, hasCollision = true, steps = 1000})
        table.insert(pf.grid, {x = x, z = z - 1, direction = -1, hasInfo = true, isRestricted = true, hasCollision = true, steps = 1000})
        table.insert(pf.grid, {x = x - 1, z = z + 1, direction = -1, hasInfo = true, isRestricted = true, hasCollision = true, steps = 1000})
        table.insert(pf.grid, {x = x + 1, z = z - 1, direction = -1, hasInfo = true, isRestricted = true, hasCollision = true, steps = 1000})
    elseif endDirection == AutoDrive.PP_LEFT then
        table.insert(pf.grid, {x = x - 1, z = z - 1, direction = -1, hasInfo = true, isRestricted = true, hasCollision = true, steps = 1000})
        table.insert(pf.grid, {x = x - 1, z = z + 0, direction = -1, hasInfo = true, isRestricted = true, hasCollision = true, steps = 1000})
        table.insert(pf.grid, {x = x + 0, z = z - 1, direction = -1, hasInfo = true, isRestricted = true, hasCollision = true, steps = 1000})
        table.insert(pf.grid, {x = x + 1, z = z + 0, direction = -1, hasInfo = true, isRestricted = true, hasCollision = true, steps = 1000})
        table.insert(pf.grid, {x = x + 1, z = z - 1, direction = -1, hasInfo = true, isRestricted = true, hasCollision = true, steps = 1000})
    elseif endDirection == AutoDrive.PP_UP_LEFT then
        table.insert(pf.grid, {x = x + 1, z = z + 0, direction = -1, hasInfo = true, isRestricted = true, hasCollision = true, steps = 1000})
        table.insert(pf.grid, {x = x + 1, z = z - 1, direction = -1, hasInfo = true, isRestricted = true, hasCollision = true, steps = 1000})
        table.insert(pf.grid, {x = x + 0, z = z - 1, direction = -1, hasInfo = true, isRestricted = true, hasCollision = true, steps = 1000})
        table.insert(pf.grid, {x = x + 1, z = z + 1, direction = -1, hasInfo = true, isRestricted = true, hasCollision = true, steps = 1000})
        table.insert(pf.grid, {x = x - 1, z = z - 1, direction = -1, hasInfo = true, isRestricted = true, hasCollision = true, steps = 1000})
    elseif endDirection == AutoDrive.PP_UP then
        table.insert(pf.grid, {x = x + 1, z = z + 0, direction = -1, hasInfo = true, isRestricted = true, hasCollision = true, steps = 1000})
        table.insert(pf.grid, {x = x + 1, z = z - 1, direction = -1, hasInfo = true, isRestricted = true, hasCollision = true, steps = 1000})
        table.insert(pf.grid, {x = x + 0, z = z + 1, direction = -1, hasInfo = true, isRestricted = true, hasCollision = true, steps = 1000})
        table.insert(pf.grid, {x = x + 1, z = z + 1, direction = -1, hasInfo = true, isRestricted = true, hasCollision = true, steps = 1000})
        table.insert(pf.grid, {x = x + 0, z = z - 1, direction = -1, hasInfo = true, isRestricted = true, hasCollision = true, steps = 1000})
    elseif endDirection == AutoDrive.PP_UP_RIGHT then
        table.insert(pf.grid, {x = x + 1, z = z + 0, direction = -1, hasInfo = true, isRestricted = true, hasCollision = true, steps = 1000})
        table.insert(pf.grid, {x = x + 1, z = z + 1, direction = -1, hasInfo = true, isRestricted = true, hasCollision = true, steps = 1000})
        table.insert(pf.grid, {x = x + 0, z = z + 1, direction = -1, hasInfo = true, isRestricted = true, hasCollision = true, steps = 1000})
        table.insert(pf.grid, {x = x + 1, z = z - 1, direction = -1, hasInfo = true, isRestricted = true, hasCollision = true, steps = 1000})
        table.insert(pf.grid, {x = x - 1, z = z + 1, direction = -1, hasInfo = true, isRestricted = true, hasCollision = true, steps = 1000})
    elseif endDirection == AutoDrive.PP_RIGHT then
        table.insert(pf.grid, {x = x - 1, z = z + 1, direction = -1, hasInfo = true, isRestricted = true, hasCollision = true, steps = 1000})
        table.insert(pf.grid, {x = x + 1, z = z + 1, direction = -1, hasInfo = true, isRestricted = true, hasCollision = true, steps = 1000})
        table.insert(pf.grid, {x = x + 0, z = z + 1, direction = -1, hasInfo = true, isRestricted = true, hasCollision = true, steps = 1000})
        table.insert(pf.grid, {x = x + 1, z = z + 0, direction = -1, hasInfo = true, isRestricted = true, hasCollision = true, steps = 1000})
        table.insert(pf.grid, {x = x - 1, z = z + 0, direction = -1, hasInfo = true, isRestricted = true, hasCollision = true, steps = 1000})
    elseif endDirection == AutoDrive.PP_DOWN_RIGHT then
        table.insert(pf.grid, {x = x - 1, z = z + 1, direction = -1, hasInfo = true, isRestricted = true, hasCollision = true, steps = 1000})
        table.insert(pf.grid, {x = x + 1, z = z + 1, direction = -1, hasInfo = true, isRestricted = true, hasCollision = true, steps = 1000})
        table.insert(pf.grid, {x = x + 0, z = z + 1, direction = -1, hasInfo = true, isRestricted = true, hasCollision = true, steps = 1000})
        table.insert(pf.grid, {x = x - 1, z = z + 0, direction = -1, hasInfo = true, isRestricted = true, hasCollision = true, steps = 1000})
        table.insert(pf.grid, {x = x - 0, z = z - 1, direction = -1, hasInfo = true, isRestricted = true, hasCollision = true, steps = 1000})
    end
end

function AutoDrivePathFinder.cellDistance(pf, cell)
    return math.sqrt(math.pow(pf.targetCell.x - cell.x, 2) + math.pow(pf.targetCell.z - cell.z, 2))
end

function AutoDrivePathFinder.checkForFruitInArea(pf, cell, cornerX, cornerZ, corner2X, corner2Z, corner3X, corner3Z)
    if pf.fruitToCheck == nil then
        for i = 1, #g_fruitTypeManager.fruitTypes do
            if i ~= g_fruitTypeManager.nameToIndex["GRASS"] and i ~= g_fruitTypeManager.nameToIndex["DRYGRASS"] then
                local fruitType = g_fruitTypeManager.fruitTypes[i].index
                if cell.isRestricted == false and pf.fruitToCheck == nil then --stop if cell is already restricted and/or fruit type is now known
                    AutoDrivePathFinder.checkForFruitTypeInArea(pf, cell, fruitType, cornerX, cornerZ, corner2X, corner2Z, corner3X, corner3Z)
                end
            end
        end
    else
        AutoDrivePathFinder.checkForFruitTypeInArea(pf, cell, pf.fruitToCheck, cornerX, cornerZ, corner2X, corner2Z, corner3X, corner3Z)
    end
end

function AutoDrivePathFinder.checkForFruitTypeInArea(pf, cell, fruitType, cornerX, cornerZ, corner2X, corner2Z, corner3X, corner3Z)
    local fruitValue = 0
    if fruitType == 9 or fruitType == 22 then
        fruitValue, _, _, _ = FSDensityMapUtil.getFruitArea(fruitType, cornerX, cornerZ, corner2X, corner2Z, corner3X, corner3Z, true, true)
    else
        fruitValue, _, _, _ = FSDensityMapUtil.getFruitArea(fruitType, cornerX, cornerZ, corner2X, corner2Z, corner3X, corner3Z, nil, false)
    end

    if (pf.fruitToCheck == nil or pf.fruitToCheck < 1) and (fruitValue > 150) then
        pf.fruitToCheck = fruitType
        pf.driver.ad.combineFruitToCheck = fruitType
    end
    local wasRestricted = cell.isRestricted
    cell.isRestricted = cell.isRestricted or (fruitValue > 150)

    cell.hasFruit = (fruitValue > 150)

    --Allow fruit in the first few grid cells
    if ((((math.abs(cell.x) <= 3) and (math.abs(cell.z) <= 3)) and pf.driver.ad.combineUnloadInFruit) or AutoDrivePathFinder.cellDistance(pf, cell) <= 3) and (not pf.preDriveCombine) then
        cell.isRestricted = false or wasRestricted
    end
end

function AutoDrive:boundingBoxFromCorners(cornerX, cornerZ, corner2X, corner2Z, corner3X, corner3Z, corner4X, corner4Z)
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

function AutoDrive:checkForVehicleCollision(vehicle, excludedVehicles, dynamicSize)
    if excludedVehicles == nil then
        excludedVehicles = {}
    end
    table.insert(excludedVehicles, vehicle)
    return AutoDrive:checkForVehiclesInBox(AutoDrive:getBoundingBoxForVehicle(vehicle, dynamicSize), excludedVehicles)
end

function AutoDrive:checkForVehiclesInBox(boundingBox, excludedVehicles)
    for _, otherVehicle in pairs(g_currentMission.vehicles) do
        local isExcluded = false
        if excludedVehicles ~= nil and otherVehicle ~= nil then
            for _, excludedVehicle in pairs(excludedVehicles) do
                if excludedVehicle == otherVehicle or AutoDrive:checkIsConnected(excludedVehicle, otherVehicle) then
                    isExcluded = true
                end
            end
        end

        if (not isExcluded) and otherVehicle ~= nil and otherVehicle.components ~= nil and otherVehicle.sizeWidth ~= nil and otherVehicle.sizeLength ~= nil and otherVehicle.rootNode ~= nil then
            local x, y, z = getWorldTranslation(otherVehicle.components[1].node)
            local distance = MathUtil.vector2Length(boundingBox[1].x - x, boundingBox[1].z - z)
            if distance < 50 then
                if AutoDrive.boxesIntersect(boundingBox, AutoDrive:getBoundingBoxForVehicle(otherVehicle, false)) == true then
                    return true
                end
            end
        end
    end

    return false
end

function AutoDrive:getBoundingBoxForVehicle(vehicle, dynamicSize)
    local x, y, z = getWorldTranslation(vehicle.components[1].node)
    --create bounding box to check for vehicle
    local rx, ry, rz = 0, 0, 0
    local lookAheadDistance = 0
    local width = vehicle.sizeWidth
    local length = vehicle.sizeLength
    if dynamicSize then
        --Box should be a lookahead box which adjusts to vehicle steering rotation
        rx, ry, rz = localDirectionToWorld(vehicle.components[1].node, math.sin(vehicle.rotatedTime), 0, math.cos(vehicle.rotatedTime))
        lookAheadDistance = math.min(vehicle.lastSpeedReal * 3600 / 40, 1) * 10 + 2
        if vehicle.ad ~= nil and vehicle.ad.wayPoints ~= nil and vehicle.ad.wayPoints[vehicle.ad.currentWayPoint] ~= nil and vehicle.ad.wayPoints[vehicle.ad.currentWayPoint + 2] == nil then
            width = width * 2 / 3
        end
    else
        rx, ry, rz = localDirectionToWorld(vehicle.components[1].node, 0, 0, 1)
    end
    local vehicleVector = {x = rx, z = rz}
    local ortho = {x = -vehicleVector.z, z = vehicleVector.x}

    local boundingBox = {}
    boundingBox[1] = {
        x = x + (width / 2) * ortho.x + (length / 2) * vehicleVector.x,
        y = y + 2,
        z = z + (width / 2) * ortho.z + (length / 2) * vehicleVector.z
    }
    boundingBox[2] = {
        x = x - (width / 2) * ortho.x + (length / 2) * vehicleVector.x,
        y = y + 2,
        z = z - (width / 2) * ortho.z + (length / 2) * vehicleVector.z
    }
    boundingBox[3] = {
        x = x - (width / 2) * ortho.x + (length / 2 + lookAheadDistance) * vehicleVector.x,
        y = y + 2,
        z = z - (width / 2) * ortho.z + (length / 2 + lookAheadDistance) * vehicleVector.z
    }
    boundingBox[4] = {
        x = x + (width / 2) * ortho.x + (length / 2 + lookAheadDistance) * vehicleVector.x,
        y = y + 2,
        z = z + (width / 2) * ortho.z + (length / 2 + lookAheadDistance) * vehicleVector.z
    }

    --Box should just be vehicle dimensions;
    if not dynamicSize then
        boundingBox[1] = {
            x = x + (width / 2) * ortho.x - (length / 2) * vehicleVector.x,
            y = y + 2,
            z = z + (width / 2) * ortho.z - (length / 2) * vehicleVector.z
        }
        boundingBox[2] = {
            x = x - (width / 2) * ortho.x - (length / 2) * vehicleVector.x,
            y = y + 2,
            z = z - (width / 2) * ortho.z - (length / 2) * vehicleVector.z
        }
    end

    --AutoDrive:drawLine(boundingBox[1], boundingBox[2], 1, 0, 0, 1);
    --AutoDrive:drawLine(boundingBox[2], boundingBox[3], 1, 0, 0, 1);
    --AutoDrive:drawLine(boundingBox[3], boundingBox[4], 1, 0, 0, 1);
    --AutoDrive:drawLine(boundingBox[4], boundingBox[1], 1, 0, 0, 1);

    return boundingBox
end

function AutoDrivePathFinder:drawDebugForPF(pf)
    local pointTarget = AutoDrivePathFinder:gridLocationToWorldLocation(pf, pf.targetCell)
    local pointTargetUp = AutoDrivePathFinder:gridLocationToWorldLocation(pf, pf.targetCell)
    pointTarget.y = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, pointTarget.x, 1, pointTarget.z) + 3
    pointTargetUp.y = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, pointTargetUp.x, 1, pointTargetUp.z) + 6
    AutoDrive:drawLine(pointTarget, pointTargetUp, 0, 0, 1, 1)
    local pointStart = AutoDrivePathFinder:gridLocationToWorldLocation(pf, pf.startCell)
    local pointStartUp = AutoDrivePathFinder:gridLocationToWorldLocation(pf, pf.startCell)
    pointStart.y = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, pointStart.x, 1, pointStart.z) + 3
    pointStartUp.y = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, pointStartUp.x, 1, pointStartUp.z) + 6
    AutoDrive:drawLine(pointStart, pointStartUp, 0, 0, 1, 1)

    for _, cell in pairs(pf.grid) do
        local size = 0.3
        local pointA = AutoDrivePathFinder:gridLocationToWorldLocation(pf, cell)
        pointA.x = pointA.x + pf.vectorX.x * size + pf.vectorZ.x * size
        pointA.z = pointA.z + pf.vectorX.z * size + pf.vectorZ.z * size
        pointA.y = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, pointA.x, 1, pointA.z) + 3
        local pointB = AutoDrivePathFinder:gridLocationToWorldLocation(pf, cell)
        pointB.x = pointB.x - pf.vectorX.x * size - pf.vectorZ.x * size
        pointB.z = pointB.z - pf.vectorX.z * size - pf.vectorZ.z * size
        pointB.y = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, pointB.x, 1, pointB.z) + 3
        local pointC = AutoDrivePathFinder:gridLocationToWorldLocation(pf, cell)
        pointC.x = pointC.x + pf.vectorX.x * size - pf.vectorZ.x * size
        pointC.z = pointC.z + pf.vectorX.z * size - pf.vectorZ.z * size
        pointC.y = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, pointC.x, 1, pointC.z) + 3
        local pointD = AutoDrivePathFinder:gridLocationToWorldLocation(pf, cell)
        pointD.x = pointD.x - pf.vectorX.x * size + pf.vectorZ.x * size
        pointD.z = pointD.z - pf.vectorX.z * size + pf.vectorZ.z * size
        pointD.y = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, pointD.x, 1, pointD.z) + 3

        if cell.hasInfo == true then
            if cell.isRestricted == true then
                AutoDrive:drawLine(pointA, pointB, 1, 0, 0, 1)
                if cell.hasCollision == true then
                    AutoDrive:drawLine(pointC, pointD, 1, 1, 0, 1)
                else
                    AutoDrive:drawLine(pointC, pointD, 1, 0, 1, 1)
                end
            else
                AutoDrive:drawLine(pointA, pointB, 0, 1, 0, 1)
                if cell.hasCollision == true then
                    AutoDrive:drawLine(pointC, pointD, 1, 1, 0, 1)
                else
                    AutoDrive:drawLine(pointC, pointD, 1, 0, 1, 1)
                end
            end
        else
            AutoDrive:drawLine(pointA, pointB, 0, 0, 1, 1)
            AutoDrive:drawLine(pointC, pointD, 0, 0, 1, 1)
        end
    end

    local size = 0.3
    local pointA = AutoDrivePathFinder:gridLocationToWorldLocation(pf, pf.targetCell)
    pointA.x = pointA.x + pf.vectorX.x * size + pf.vectorZ.x * size
    pointA.z = pointA.z + pf.vectorX.z * size + pf.vectorZ.z * size
    pointA.y = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, pointA.x, 1, pointA.z) + 3
    local pointB = AutoDrivePathFinder:gridLocationToWorldLocation(pf, pf.targetCell)
    pointB.x = pointB.x - pf.vectorX.x * size - pf.vectorZ.x * size
    pointB.z = pointB.z - pf.vectorX.z * size - pf.vectorZ.z * size
    pointB.y = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, pointB.x, 1, pointB.z) + 3
    local pointC = AutoDrivePathFinder:gridLocationToWorldLocation(pf, pf.targetCell)
    pointC.x = pointC.x + pf.vectorX.x * size - pf.vectorZ.x * size
    pointC.z = pointC.z + pf.vectorX.z * size - pf.vectorZ.z * size
    pointC.y = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, pointC.x, 1, pointC.z) + 3
    local pointD = AutoDrivePathFinder:gridLocationToWorldLocation(pf, pf.targetCell)
    pointD.x = pointD.x - pf.vectorX.x * size + pf.vectorZ.x * size
    pointD.z = pointD.z - pf.vectorX.z * size + pf.vectorZ.z * size
    pointD.y = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, pointD.x, 1, pointD.z) + 3

    AutoDrive:drawLine(pointA, pointB, 1, 1, 1, 1)
    AutoDrive:drawLine(pointC, pointD, 1, 1, 1, 1)

    local pointAB = AutoDrivePathFinder:gridLocationToWorldLocation(pf, pf.targetCell)
    pointAB.y = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, pointAB.x, 1, pointAB.z) + 3

    local pointTargetVector = AutoDrivePathFinder:gridLocationToWorldLocation(pf, pf.targetCell)
    pointTargetVector.x = pointTargetVector.x + pf.targetVector.x * 10
    pointTargetVector.z = pointTargetVector.z + pf.targetVector.z * 10
    pointTargetVector.y = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, pointTargetVector.x, 1, pointTargetVector.z) + 3
    AutoDrive:drawLine(pointAB, pointTargetVector, 1, 1, 1, 1)
end

function AutoDrivePathFinder.drawDebugForCreatedRoute(pf)
    if pf.chainStartToTarget ~= nil then
        for chainIndex, cell in pairs(pf.chainStartToTarget) do
            local shape = AutoDrivePathFinder.getShapeDefByDirectionType(pf, cell)
            if shape.x ~= nil then
                local pointA = {
                    x = shape.x + shape.widthX * math.cos(shape.angleRad) + shape.widthZ * math.sin(shape.angleRad),
                    y = shape.y,
                    z = shape.z + shape.widthZ * math.cos(shape.angleRad) + shape.widthX * math.sin(shape.angleRad)
                }
                local pointB = {
                    x = shape.x - shape.widthX * math.cos(shape.angleRad) - shape.widthZ * math.sin(shape.angleRad),
                    y = shape.y,
                    z = shape.z + shape.widthZ * math.cos(shape.angleRad) + shape.widthX * math.sin(shape.angleRad)
                }
                local pointC = {
                    x = shape.x - shape.widthX * math.cos(shape.angleRad) - shape.widthZ * math.sin(shape.angleRad),
                    y = shape.y,
                    z = shape.z - shape.widthZ * math.cos(shape.angleRad) - shape.widthX * math.sin(shape.angleRad)
                }
                local pointD = {
                    x = shape.x + shape.widthX * math.cos(shape.angleRad) + shape.widthZ * math.sin(shape.angleRad),
                    y = shape.y,
                    z = shape.z - shape.widthZ * math.cos(shape.angleRad) - shape.widthX * math.sin(shape.angleRad)
                }

                AutoDrive:drawLine(pointA, pointC, 1, 1, 1, 1)
                AutoDrive:drawLine(pointB, pointD, 1, 1, 1, 1)

                if cell.incoming ~= nil then
                    local worldPos_cell = AutoDrivePathFinder:gridLocationToWorldLocation(pf, cell)
                    local worldPos_incoming = AutoDrivePathFinder:gridLocationToWorldLocation(pf, cell.incoming)

                    local vectorX = worldPos_cell.x - worldPos_incoming.x
                    local vectorZ = worldPos_cell.z - worldPos_incoming.z
                    local angleRad = math.atan2(-vectorZ, vectorX)
                    angleRad = AutoDrive.normalizeAngle(angleRad)
                    local widthOfColBox = math.sqrt(math.pow(pf.minTurnRadius, 2) + math.pow(pf.minTurnRadius, 2))
                    local sideLength = widthOfColBox / 2
                    local length = math.sqrt(math.pow(vectorX, 2) + math.pow(vectorZ, 2)) + widthOfColBox

                    local leftAngle = AutoDrive.normalizeAngle(angleRad + math.rad(-90))
                    local rightAngle = AutoDrive.normalizeAngle(angleRad + math.rad(90))

                    local cornerX = worldPos_incoming.x - math.cos(leftAngle) * sideLength
                    local cornerZ = worldPos_incoming.z + math.sin(leftAngle) * sideLength

                    local corner2X = worldPos_cell.x - math.cos(leftAngle) * sideLength
                    local corner2Z = worldPos_cell.z + math.sin(leftAngle) * sideLength

                    local corner3X = worldPos_cell.x - math.cos(rightAngle) * sideLength
                    local corner3Z = worldPos_cell.z + math.sin(rightAngle) * sideLength

                    local corner4X = worldPos_incoming.x - math.cos(rightAngle) * sideLength
                    local corner4Z = worldPos_incoming.z + math.sin(rightAngle) * sideLength

                    local inY = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, worldPos_incoming.x, 1, worldPos_incoming.z) + 1
                    local currentY = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, worldPos_cell.x, 1, worldPos_cell.z) + 1

                    AutoDrive:drawLine({x = cornerX, y = inY, z = cornerZ}, {x = corner2X, y = currentY, z = corner2Z}, 1, 0, 0, 1)
                    AutoDrive:drawLine({x = corner2X, y = currentY, z = corner2Z}, {x = corner3X, y = currentY, z = corner3Z}, 1, 0, 0, 1)
                    AutoDrive:drawLine({x = corner3X, y = currentY, z = corner3Z}, {x = corner4X, y = inY, z = corner4Z}, 1, 0, 0, 1)
                    AutoDrive:drawLine({x = corner4X, y = inY, z = corner4Z}, {x = cornerX, y = inY, z = cornerZ}, 1, 0, 0, 1)
                end
            end
        end
    end

    for i, waypoint in pairs(pf.wayPoints) do
        local node = createTransformGroup("Node " .. i)
        setTranslation(node, waypoint.x, waypoint.y + 4, waypoint.z)
        DebugUtil.drawDebugNode(node, "Node " .. i)

        if i > 1 then
            AutoDrive:drawLine(waypoint, pf.wayPoints[i - 1], 0, 1, 1, 1)
        end
    end
end
