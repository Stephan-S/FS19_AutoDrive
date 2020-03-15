PathFinderModule = {}

PathFinderModule.PATHFINDER_MAX_RETRIES = 3
PathFinderModule.MAX_PATHFINDER_STEPS_PER_FRAME = 20
PathFinderModule.MAX_PATHFINDER_STEPS_TOTAL = 400
PathFinderModule.PATHFINDER_FOLLOW_DISTANCE = 20
PathFinderModule.PATHFINDER_TARGET_DISTANCE = 7
PathFinderModule.PATHFINDER_TARGET_DISTANCE_PIPE = 12
PathFinderModule.PATHFINDER_TARGET_DISTANCE_PIPE_CLOSE = 6
PathFinderModule.PATHFINDER_START_DISTANCE = 7

PathFinderModule.PP_UP = 0
PathFinderModule.PP_UP_RIGHT = 1
PathFinderModule.PP_RIGHT = 2
PathFinderModule.PP_DOWN_RIGHT = 3
PathFinderModule.PP_DOWN = 4
PathFinderModule.PP_DOWN_LEFT = 5
PathFinderModule.PP_LEFT = 6
PathFinderModule.PP_UP_LEFT = 7

PathFinderModule.PP_MIN_DISTANCE = 20
PathFinderModule.PP_CELL_X = 9
PathFinderModule.PP_CELL_Z = 9

function PathFinderModule:new(vehicle)
    local o = {}
    setmetatable(o, self)
    self.__index = self
    o.vehicle = vehicle
    PathFinderModule.reset(o)
    return o
end

function PathFinderModule:reset()
    self.steps = 0
    self.grid = {}
    self.retryCounter = 0
end

function PathFinderModule:update()
    if self.vehicle.ad.stateModule:isEditorModeEnabled() and AutoDrive.getDebugChannelIsSet(AutoDrive.DC_PATHINFO) then
        self:drawDebugForPF()
    end

    if self.isFinished and self.smoothDone == true then
        return
    end

    if self.isFinished and self.smoothDone == false then
        self:createWayPoints()
        return
    end

    self.steps = self.steps + 1

    if self.steps > (self.MAX_PATHFINDER_STEPS_TOTAL * AutoDrive.getSetting("pathFinderTime")) then
        if (not self.fallBackMode) or (self.possiblyBlockedByOtherVehicle and self.retryCounter < self.PATHFINDER_MAX_RETRIES) then
            --g_logManager:devInfo("Going into fallback mode - no fruit free path found in reasonable time");
            if not self.possiblyBlockedByOtherVehicle then
                self.fallBackMode = true
            else
                self.retryCounter = self.retryCounter + 1
                self.possiblyBlockedByOtherVehicle = false
            end
            self.steps = 0
            self.grid = {}
            self.startCell.visited = false
            self.currentCell = nil
            table.insert(self.grid, self.startCell)
            self:determineBlockedCells(self.targetCell)
            self.smoothStep = 0
            self.smoothDone = false
        else
            --stop searching
            self.isFinished = true
            self.smoothDone = true
            self.wayPoints = {}
            
            g_logManager:error("[AutoDrive] Could not calculate path - shutting down")
            self.vehicle.ad.taskModule:abortAllTasks()
            AutoDrive.disableAutoDriveFunctions(self.vehicle)
            AutoDriveMessageEvent.sendMessageOrNotification(self.vehicle, MessagesManager.messageTypes.ERROR, "$l10n_AD_Driver_of; %s $l10n_AD_cannot_find_path;", 5000, self.vehicle.ad.driverName)
        end
    end

    for i = 1, self.MAX_PATHFINDER_STEPS_PER_FRAME, 1 do
        if self.currentCell == nil then
            local minDistance = math.huge
            local bestCell = nil
            local bestSteps = math.huge

            local grid = self.grid
            for _, cell in pairs(grid) do
                --also checking for preDriveCombine here -> don't ever drive through fruit in preDrive mode -> this will often result in driver cutting through fruit in front of combine!
                if not cell.visited and ((not cell.isRestricted) or (self.fallBackMode and (not self.chasingVehicle))) and (not cell.hasCollision) and cell.hasInfo == true then
                    local distance = self:cellDistance(cell)

                    if distance < minDistance then
                        minDistance = distance
                        bestCell = cell
                        bestSteps = cell.steps
                    elseif distance == minDistance and cell.steps < bestSteps then
                        minDistance = distance
                        bestCell = cell
                        bestSteps = cell.steps
                    end
                end
            end

            self.currentCell = bestCell

            if self.currentCell ~= nil and self:cellDistance(self.currentCell) == 0 then
                self.isFinished = true
                self.targetCell.incoming = self.currentCell.incoming
                self:createWayPoints()
            end

            if self.currentCell == nil then
                self.grid = {}
                self.startCell.visited = false
                table.insert(self.grid, self.startCell)
                self:determineBlockedCells(self.targetCell)
            end
        else
            if self.currentCell.out == nil then
                self:determineNextGridCells(self.currentCell)
            end
            self:testNextCells(self.currentCell)
        end
    end
end

function PathFinderModule:hasFinished()
    if self.vehicle.ad.stateModule:isEditorModeEnabled() and AutoDrive.getDebugChannelIsSet(AutoDrive.DC_PATHINFO) then
        return false
    end
    if self.isFinished and self.smoothDone == true then
        return true
    end
    return false
end

function PathFinderModule:getPath()
    return self.wayPoints
end

function PathFinderModule:startPathPlanningToNetwork(destinationID)
    local closest = ADGraphManager:findClosestWayPoint(self.vehicle)
    local targetNode = ADGraphManager:getWayPointById(closest)
    local wayPoints = ADGraphManager:pathFromTo(closest, destinationID)
    if wayPoints ~= nil and #wayPoints > 1 then
        local vecToNextPoint = {x = wayPoints[2].x - targetNode.x, z = wayPoints[2].z - targetNode.z}
        self:startPathPlanningTo(targetNode, vecToNextPoint)
    end
    return
end

function PathFinderModule:startPathPlanningToPipe(combine, chasing)
    AutoDrive.debugPrint(vehicle, AutoDrive.DC_PATHINFO, "PathFinderModule:startPathPlanningToPipe")
    local _, worldY, _ = getWorldTranslation(combine.components[1].node)
    local rx, _, rz = localDirectionToWorld(combine.components[1].node, 0, 0, 1)
    local combineVector = {x = rx, z = rz}
    
    local pipeChasePos, pipeChaseSide = self.vehicle.ad.modes[AutoDrive.MODE_UNLOAD]:getPipeChasePosition()

    if combine.getIsBufferCombine ~= nil and combine:getIsBufferCombine() then
        local pathFinderTarget =    {x = pipeChasePos.x - self.PATHFINDER_TARGET_DISTANCE * 2   * rx, y = worldY, z = pipeChasePos.z - self.PATHFINDER_TARGET_DISTANCE * 2  * rz}
        local appendTarget =        {x = pipeChasePos.x - self.PATHFINDER_TARGET_DISTANCE       * rx, y = worldY, z = pipeChasePos.z - self.PATHFINDER_TARGET_DISTANCE      * rz}

        self:startPathPlanningTo(pathFinderTarget, combineVector)

        table.insert(self.appendWayPoints, appendTarget)
    else  
        local pathFinderTarget =    {x = pipeChasePos.x, y = worldY, z = pipeChasePos.z}
        -- only append target points / try to straighten the driver/trailer combination if we are driving up to the pipe not the rear end
        local appendedNode =        {x = pipeChasePos.x - self.PATHFINDER_TARGET_DISTANCE_PIPE_CLOSE    * rx, y = worldY, z = pipeChasePos.z - self.PATHFINDER_TARGET_DISTANCE_PIPE_CLOSE * rz}
        if pipeChaseSide ~= CombineUnloaderMode.CHASEPOS_REAR then      
            pathFinderTarget =      {x = pipeChasePos.x - self.PATHFINDER_TARGET_DISTANCE_PIPE          * rx, y = worldY, z = pipeChasePos.z - self.PATHFINDER_TARGET_DISTANCE_PIPE * rz}
        end

        AutoDrive.debugPrint(vehicle, AutoDrive.DC_PATHINFO, "PathFinderModule:startPathPlanningToPipe - normal combine")
        self:startPathPlanningTo(pathFinderTarget, combineVector)

        if pipeChaseSide ~= CombineUnloaderMode.CHASEPOS_REAR then            
            table.insert(self.appendWayPoints, appendedNode)
            table.insert(self.appendWayPoints, pipeChasePos)
        end        
    end
    
    if combine.spec_combine ~= nil then
        if combine.spec_combine.fillUnitIndex ~= nil and combine.spec_combine.fillUnitIndex ~= 0 then
            local fillType = g_fruitTypeManager:getFruitTypeIndexByFillTypeIndex(combine:getFillUnitFillType(combine.spec_combine.fillUnitIndex))
            if fillType ~= nil and (not combine:getIsBufferCombine()) then
                self.fruitToCheck = fillType
            end
        end
    end

    self.goingToPipe = true
    self.chasingVehicle = chasing
end

function PathFinderModule:startPathPlanningToVehicle(targetVehicle, targetDistance)
    local worldX, worldY, worldZ = getWorldTranslation(targetVehicle.components[1].node)
    local rx, _, rz = localDirectionToWorld(targetVehicle.components[1].node, 0, 0, 1)
    local targetVector = {x = rx, z = rz}

    local wpBehind = {x = worldX - targetDistance * rx, y = worldY, z = worldZ - targetDistance * rz}
    self:startPathPlanningTo(wpBehind, targetVector)

    self.goingToPipe = false
    self.chasingVehicle = true
end

function PathFinderModule:startPathPlanningTo(targetPoint, targetVector)
    self.targetVector = targetVector
    local vehicleWorldX, vehicleWorldY, vehicleWorldZ = getWorldTranslation(self.vehicle.components[1].node)
    local vehicleRx, _, vehicleRz = localDirectionToWorld(self.vehicle.components[1].node, 0, 0, 1)
    local vehicleVector = {x = vehicleRx, z = vehicleRz}
    self.startX = vehicleWorldX + self.PATHFINDER_START_DISTANCE * vehicleRx
    self.startZ = vehicleWorldZ + self.PATHFINDER_START_DISTANCE * vehicleRz

    local atan = AutoDrive.normalizeAngle(math.atan2(targetVector.z, targetVector.x))
    local sin = math.sin(atan)
    local cos = math.cos(atan)

    self.minTurnRadius = AutoDrive.getDriverRadius(self.vehicle) * 2/3

    self.vectorX = {x = cos * self.minTurnRadius, z = sin * self.minTurnRadius}
    self.vectorZ = {x = -sin * self.minTurnRadius, z = cos * self.minTurnRadius}

    local angleRad = math.atan2(targetVector.z, targetVector.x)
    angleRad = AutoDrive.normalizeAngle(angleRad)

    --Make the target a few meters ahead of the road to the start point
    local targetX = targetPoint.x - math.cos(angleRad) * self.PATHFINDER_TARGET_DISTANCE
    local targetZ = targetPoint.z - math.sin(angleRad) * self.PATHFINDER_TARGET_DISTANCE
    
    self.grid = {}
    self.steps = 0
    self.retryCounter = 0
    self.isFinished = false
    self.fallBackMode = false
    self.fruitToCheck = nil

    self.startCell = {x = 0, z = 0}
    self.startCell.direction = self:worldDirectionToGridDirection(vehicleVector)
    self.startCell.visited = false
    self.startCell.isRestricted = false
    self.startCell.hasCollision = false
    self.startCell.hasInfo = true
    self.startCell.hasFruit = false
    self.startCell.steps = 0

    self.targetCell = self:worldLocationToGridLocation(targetX, targetZ)
    self:determineBlockedCells(self.targetCell)

    table.insert(self.grid, self.startCell)
    self.smoothStep = 0
    self.smoothDone = false
    self.target = {x = targetX, z = targetZ}


    self.appendWayPoints = {}
    self.appendWayPoints[1] = targetPoint

    self.goingToCombine = false

    local startIsOnField = AutoDrive.checkIsOnField(vehicleWorldX, vehicleWorldY, vehicleWorldZ)
    local endIsOnField = AutoDrive.checkIsOnField(targetX, vehicleWorldY, targetZ)

    self.restrictToField = startIsOnField and endIsOnField and AutoDrive.getSetting("restrictToField")

    self.goingToPipe = false
    self.chasingVehicle = false
end

function PathFinderModule:testNextCells(cell)
    local allResultsIn = true
    for _, location in pairs(cell.out) do
        local createPoint = true
        for _, c in pairs(self.grid) do
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
            self:createGridCells(location)
        end

        if not location.hasInfo then
            self:checkGridCell(location)
        end

        allResultsIn = allResultsIn and location.hasInfo
    end

    if allResultsIn then
        cell.visited = true
        self.currentCell = nil
    end
end

function PathFinderModule:createGridCells(location)
    location.visited = false
    location.isRestricted = false
    location.hasInfo = false
    location.hasCollision = false
    location.hasFruit = true
    table.insert(self.grid, location)
end

function PathFinderModule:checkGridCell(cell)
    if cell.hasInfo == false then
        if cell.x == self.targetCell.x and cell.z == self.targetCell.z then
            cell.isRestricted = false
            cell.hasCollision = false
            cell.hasFruit = false
            cell.hasInfo = true
            return
        end

        local worldPos = self:gridLocationToWorldLocation(cell)

        local cornerX = worldPos.x + (-self.vectorX.x - self.vectorZ.x) / 2
        local cornerZ = worldPos.z + (-self.vectorX.z - self.vectorZ.z) / 2

        local corner2X = worldPos.x + (self.vectorX.x - self.vectorZ.x) / 2
        local corner2Z = worldPos.z + (self.vectorX.z - self.vectorZ.z) / 2

        local corner3X = worldPos.x + (-self.vectorX.x + self.vectorZ.x) / 2
        local corner3Z = worldPos.z + (-self.vectorX.z + self.vectorZ.z) / 2

        local corner4X = worldPos.x + (self.vectorX.x + self.vectorZ.x) / 2
        local corner4Z = worldPos.z + (self.vectorX.z + self.vectorZ.z) / 2

        local shapeDefinition = self:getShapeDefByDirectionType(cell)

        local angleRad = math.atan2(self.targetVector.z, self.targetVector.x)
        angleRad = AutoDrive.normalizeAngle(angleRad)
        local y = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, worldPos.x, 1, worldPos.z)
        local shapes = overlapBox(shapeDefinition.x, shapeDefinition.y + 3, shapeDefinition.z, 0, shapeDefinition.angleRad, 0, shapeDefinition.widthX, shapeDefinition.height, shapeDefinition.widthZ, "collisionTestCallbackIgnore", nil, AIVehicleUtil.COLLISION_MASK, true, true, true)

        cell.hasCollision = (shapes > 0)

        local worldPosPrevious = self:gridLocationToWorldLocation(cell.incoming)
        cell.hasCollision = cell.hasCollision or AutoDrive.checkSlopeAngle(worldPos.x, worldPos.z, worldPosPrevious.x, worldPosPrevious.z)

        if (self.ignoreFruit == nil or self.ignoreFruit == false) and AutoDrive.getSetting("avoidFruit", self.vehicle) then
            self:checkForFruitInArea(cell, cornerX, cornerZ, corner2X, corner2Z, corner3X, corner3Z)
        else
            cell.isRestricted = false
            cell.hasFruit = not AutoDrive.getSetting("avoidFruit", self.vehicle) --make sure that on fallback mode or when fruit avoidance is off, we don't park in the fruit next to the combine!
        end

        cell.hasInfo = true

        cell.isRestricted = cell.isRestricted or (self.restrictToField and (not self.fallBackMode) and (not AutoDrive.checkIsOnField(worldPos.x, y, worldPos.z)))

        local boundingBox = AutoDrive.boundingBoxFromCorners(cornerX, cornerZ, corner2X, corner2Z, corner3X, corner3Z, corner4X, corner4Z)
        local vehicleCollides, vehiclePathCollides = AutoDrive.checkForVehiclesInBox(boundingBox, {self.vehicle}, self.minTurnRadius)
        if vehicleCollides then
            cell.isRestricted = true
            cell.hasCollision = true
            cell.hasVehicleCollision = true
        end
        self.possiblyBlockedByOtherVehicle = self.possiblyBlockedByOtherVehicle or vehiclePathCollides
    end
end

function PathFinderModule:gridLocationToWorldLocation(cell)
    local result = {x = 0, z = 0}

    result.x = self.startX + cell.x * self.vectorX.x + cell.z * self.vectorZ.x
    result.z = self.startZ + cell.x * self.vectorX.z + cell.z * self.vectorZ.z

    return result
end

function PathFinderModule:worldDirectionToGridDirection(vector)
    local angle = AutoDrive.angleBetween(self.vectorX, vector)

    local direction = math.floor(angle / 45)
    local remainder = angle % 45
    if remainder >= 22.5 then
        direction = (direction + 1)
    elseif remainder <= -22.5 then
        direction = (direction - 1)
    end

    if direction < 0 then
        direction = 8 + direction
    end
    
    print("Angle to target: " .. angle .. " -> direction: " .. direction)

    return direction
end

function PathFinderModule:worldLocationToGridLocation(worldX, worldZ)
    local result = {x = 0, z = 0}

    result.z = (((worldX - self.startX) / self.vectorX.x) * self.vectorX.z - worldZ + self.startZ) / (((self.vectorZ.x / self.vectorX.x) * self.vectorX.z) - self.vectorZ.z)
    result.x = (worldZ - self.startZ - result.z * self.vectorZ.z) / self.vectorX.z

    result.x = AutoDrive.round(result.x)
    result.z = AutoDrive.round(result.z)

    return result
end

function PathFinderModule:determineBlockedCells(cell)
    if (math.abs(cell.x) < 2 and math.abs(cell.z) < 2) then
        return
    end

    table.insert(self.grid, {x = cell.x + 1, z = cell.z + 0, direction = -1, hasInfo = true, isRestricted = true, hasCollision = true, steps = 1000})
    table.insert(self.grid, {x = cell.x + 1, z = cell.z - 1, direction = -1, hasInfo = true, isRestricted = true, hasCollision = true, steps = 1000})
    table.insert(self.grid, {x = cell.x + 0, z = cell.z + 1, direction = -1, hasInfo = true, isRestricted = true, hasCollision = true, steps = 1000})
    table.insert(self.grid, {x = cell.x + 1, z = cell.z + 1, direction = -1, hasInfo = true, isRestricted = true, hasCollision = true, steps = 1000})
    table.insert(self.grid, {x = cell.x + 0, z = cell.z - 1, direction = -1, hasInfo = true, isRestricted = true, hasCollision = true, steps = 1000})
end

function PathFinderModule:determineNextGridCells(cell)
    cell.out = {}
    if cell.direction == self.PP_UP then
        cell.out[1] = {x = cell.x + 1, z = cell.z - 1}
        cell.out[1].direction = self.PP_UP_LEFT
        cell.out[2] = {x = cell.x + 1, z = cell.z + 0}
        cell.out[2].direction = self.PP_UP
        cell.out[3] = {x = cell.x + 1, z = cell.z + 1}
        cell.out[3].direction = self.PP_UP_RIGHT
    elseif cell.direction == self.PP_UP_RIGHT then
        cell.out[1] = {x = cell.x + 1, z = cell.z + 0}
        cell.out[1].direction = self.PP_UP
        cell.out[2] = {x = cell.x + 1, z = cell.z + 1}
        cell.out[2].direction = self.PP_UP_RIGHT
        cell.out[3] = {x = cell.x + 0, z = cell.z + 1}
        cell.out[3].direction = self.PP_RIGHT
    elseif cell.direction == self.PP_RIGHT then
        cell.out[1] = {x = cell.x + 1, z = cell.z + 1}
        cell.out[1].direction = self.PP_UP_RIGHT
        cell.out[2] = {x = cell.x + 0, z = cell.z + 1}
        cell.out[2].direction = self.PP_RIGHT
        cell.out[3] = {x = cell.x - 1, z = cell.z + 1}
        cell.out[3].direction = self.PP_DOWN_RIGHT
    elseif cell.direction == self.PP_DOWN_RIGHT then
        cell.out[1] = {x = cell.x + 0, z = cell.z + 1}
        cell.out[1].direction = self.PP_RIGHT
        cell.out[2] = {x = cell.x - 1, z = cell.z + 1}
        cell.out[2].direction = self.PP_DOWN_RIGHT
        cell.out[3] = {x = cell.x - 1, z = cell.z + 0}
        cell.out[3].direction = self.PP_DOWN
    elseif cell.direction == self.PP_DOWN then
        cell.out[1] = {x = cell.x - 1, z = cell.z + 1}
        cell.out[1].direction = self.PP_DOWN_RIGHT
        cell.out[2] = {x = cell.x - 1, z = cell.z + 0}
        cell.out[2].direction = self.PP_DOWN
        cell.out[3] = {x = cell.x - 1, z = cell.z - 1}
        cell.out[3].direction = self.PP_DOWN_LEFT
    elseif cell.direction == self.PP_DOWN_LEFT then
        cell.out[1] = {x = cell.x - 1, z = cell.z - 0}
        cell.out[1].direction = self.PP_DOWN
        cell.out[2] = {x = cell.x - 1, z = cell.z - 1}
        cell.out[2].direction = self.PP_DOWN_LEFT
        cell.out[3] = {x = cell.x - 0, z = cell.z - 1}
        cell.out[3].direction = self.PP_LEFT
    elseif cell.direction == self.PP_LEFT then
        cell.out[1] = {x = cell.x - 1, z = cell.z - 1}
        cell.out[1].direction = self.PP_DOWN_LEFT
        cell.out[2] = {x = cell.x - 0, z = cell.z - 1}
        cell.out[2].direction = self.PP_LEFT
        cell.out[3] = {x = cell.x + 1, z = cell.z - 1}
        cell.out[3].direction = self.PP_UP_LEFT
    elseif cell.direction == self.PP_UP_LEFT then
        cell.out[1] = {x = cell.x - 0, z = cell.z - 1}
        cell.out[1].direction = self.PP_LEFT
        cell.out[2] = {x = cell.x + 1, z = cell.z - 1}
        cell.out[2].direction = self.PP_UP_LEFT
        cell.out[3] = {x = cell.x + 1, z = cell.z + 0}
        cell.out[3].direction = self.PP_UP
    end

    for _, outGoing in pairs(cell.out) do
        outGoing.incoming = cell
        outGoing.steps = cell.steps + 1
    end
end

function PathFinderModule:cellDistance(cell)
    return math.sqrt(math.pow(self.targetCell.x - cell.x, 2) + math.pow(self.targetCell.z - cell.z, 2))
end

function PathFinderModule:checkForFruitInArea(cell, cornerX, cornerZ, corner2X, corner2Z, corner3X, corner3Z)
    if self.fruitToCheck == nil then
        for i = 1, #g_fruitTypeManager.fruitTypes do
            if i ~= g_fruitTypeManager.nameToIndex["GRASS"] and i ~= g_fruitTypeManager.nameToIndex["DRYGRASS"] then
                local fruitType = g_fruitTypeManager.fruitTypes[i].index
                if cell.isRestricted == false and self.fruitToCheck == nil then --stop if cell is already restricted and/or fruit type is now known
                    self:checkForFruitTypeInArea(cell, fruitType, cornerX, cornerZ, corner2X, corner2Z, corner3X, corner3Z)
                end
            end
        end
    else
        self:checkForFruitTypeInArea(cell, self.fruitToCheck, cornerX, cornerZ, corner2X, corner2Z, corner3X, corner3Z)
    end
end

function PathFinderModule:checkForFruitTypeInArea(cell, fruitType, cornerX, cornerZ, corner2X, corner2Z, corner3X, corner3Z)
    local fruitValue = 0
    if fruitType == 9 or fruitType == 22 then
        fruitValue, _, _, _ = FSDensityMapUtil.getFruitArea(fruitType, cornerX, cornerZ, corner2X, corner2Z, corner3X, corner3Z, true, true)
    else
        fruitValue, _, _, _ = FSDensityMapUtil.getFruitArea(fruitType, cornerX, cornerZ, corner2X, corner2Z, corner3X, corner3Z, nil, false)
    end

    if (self.fruitToCheck == nil or self.fruitToCheck < 1) and (fruitValue > 150) then
        self.fruitToCheck = fruitType
    end
    local wasRestricted = cell.isRestricted
    cell.isRestricted = cell.isRestricted or (fruitValue > 150)

    cell.hasFruit = (fruitValue > 150)

    --Allow fruit in the first few grid cells
    if self:cellDistance(cell) <= 3 and self.goingToPipe then
        cell.isRestricted = false or wasRestricted
    end
end

function PathFinderModule:drawDebugForPF()
    local AutoDriveDM = DrawingManager
    local pointTarget = self:gridLocationToWorldLocation(self.targetCell)
    local pointTargetUp = self:gridLocationToWorldLocation(self.targetCell)
    pointTarget.y = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, pointTarget.x, 1, pointTarget.z) + 3
    pointTargetUp.y = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, pointTargetUp.x, 1, pointTargetUp.z) + 6
    AutoDriveDM:addLineTask(pointTarget.x, pointTarget.y, pointTarget.z, pointTargetUp.x, pointTargetUp.y, pointTargetUp.z, 0, 0, 1)
    local pointStart = self:gridLocationToWorldLocation(self.startCell)
    local pointStartUp = self:gridLocationToWorldLocation(self.startCell)
    pointStart.y = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, pointStart.x, 1, pointStart.z) + 3
    pointStartUp.y = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, pointStartUp.x, 1, pointStartUp.z) + 6
    AutoDriveDM:addLineTask(pointTarget.x, pointTarget.y, pointTarget.z, pointTargetUp.x, pointTargetUp.y, pointTargetUp.z, 0, 0, 1)

    for _, cell in pairs(self.grid) do
        local size = 0.3
        local pointA = self:gridLocationToWorldLocation(cell)
        pointA.x = pointA.x + self.vectorX.x * size + self.vectorZ.x * size
        pointA.z = pointA.z + self.vectorX.z * size + self.vectorZ.z * size
        pointA.y = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, pointA.x, 1, pointA.z) + 3
        local pointB = self:gridLocationToWorldLocation(cell)
        pointB.x = pointB.x - self.vectorX.x * size - self.vectorZ.x * size
        pointB.z = pointB.z - self.vectorX.z * size - self.vectorZ.z * size
        pointB.y = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, pointB.x, 1, pointB.z) + 3
        local pointC = self:gridLocationToWorldLocation(cell)
        pointC.x = pointC.x + self.vectorX.x * size - self.vectorZ.x * size
        pointC.z = pointC.z + self.vectorX.z * size - self.vectorZ.z * size
        pointC.y = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, pointC.x, 1, pointC.z) + 3
        local pointD = self:gridLocationToWorldLocation(cell)
        pointD.x = pointD.x - self.vectorX.x * size + self.vectorZ.x * size
        pointD.z = pointD.z - self.vectorX.z * size + self.vectorZ.z * size
        pointD.y = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, pointD.x, 1, pointD.z) + 3

        if cell.hasInfo == true then
            if cell.isRestricted == true then
                AutoDriveDM:addLineTask(pointA.x, pointA.y, pointA.z, pointB.x, pointB.y, pointB.z, 1, 0, 0)
                if cell.hasCollision == true then
                    if cell.hasVehicleCollision then
                        AutoDriveDM:addLineTask(pointC.x, pointC.y, pointC.z, pointD.x, pointD.y, pointD.z, 0, 0, 1)
                    else
                        AutoDriveDM:addLineTask(pointC.x, pointC.y, pointC.z, pointD.x, pointD.y, pointD.z, 1, 1, 0)
                    end
                else
                    AutoDriveDM:addLineTask(pointC.x, pointC.y, pointC.z, pointD.x, pointD.y, pointD.z, 1, 0, 1)
                end
            else
                AutoDriveDM:addLineTask(pointA.x, pointA.y, pointA.z, pointB.x, pointB.y, pointB.z, 0, 1, 0)
                if cell.hasCollision == true then
                    AutoDriveDM:addLineTask(pointC.x, pointC.y, pointC.z, pointD.x, pointD.y, pointD.z, 1, 1, 0)
                else
                    AutoDriveDM:addLineTask(pointC.x, pointC.y, pointC.z, pointD.x, pointD.y, pointD.z, 1, 0, 1)
                end
            end
        else
            AutoDriveDM:addLineTask(pointA.x, pointA.y, pointA.z, pointB.x, pointB.y, pointB.z, 0, 0, 1)
            AutoDriveDM:addLineTask(pointC.x, pointC.y, pointC.z, pointD.x, pointD.y, pointD.z, 0, 0, 1)
        end
    end

    local size = 0.3
    local pointA = self:gridLocationToWorldLocation(self.targetCell)
    pointA.x = pointA.x + self.vectorX.x * size + self.vectorZ.x * size
    pointA.z = pointA.z + self.vectorX.z * size + self.vectorZ.z * size
    pointA.y = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, pointA.x, 1, pointA.z) + 3
    local pointB = self:gridLocationToWorldLocation(self.targetCell)
    pointB.x = pointB.x - self.vectorX.x * size - self.vectorZ.x * size
    pointB.z = pointB.z - self.vectorX.z * size - self.vectorZ.z * size
    pointB.y = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, pointB.x, 1, pointB.z) + 3
    local pointC = self:gridLocationToWorldLocation(self.targetCell)
    pointC.x = pointC.x + self.vectorX.x * size - self.vectorZ.x * size
    pointC.z = pointC.z + self.vectorX.z * size - self.vectorZ.z * size
    pointC.y = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, pointC.x, 1, pointC.z) + 3
    local pointD = self:gridLocationToWorldLocation(self.targetCell)
    pointD.x = pointD.x - self.vectorX.x * size + self.vectorZ.x * size
    pointD.z = pointD.z - self.vectorX.z * size + self.vectorZ.z * size
    pointD.y = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, pointD.x, 1, pointD.z) + 3

    AutoDriveDM:addLineTask(pointA.x, pointA.y, pointA.z, pointB.x, pointB.y, pointB.z, 1, 1, 1)
    AutoDriveDM:addLineTask(pointC.x, pointC.y, pointC.z, pointD.x, pointD.y, pointD.z, 1, 1, 1)

    local pointAB = self:gridLocationToWorldLocation(self.targetCell)
    pointAB.y = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, pointAB.x, 1, pointAB.z) + 3

    local pointTargetVector = self:gridLocationToWorldLocation(self.targetCell)
    pointTargetVector.x = pointTargetVector.x + self.targetVector.x * 10
    pointTargetVector.z = pointTargetVector.z + self.targetVector.z * 10
    pointTargetVector.y = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, pointTargetVector.x, 1, pointTargetVector.z) + 3
    AutoDriveDM:addLineTask(pointAB.x, pointAB.y, pointAB.z, pointTargetVector.x, pointTargetVector.y, pointTargetVector.z, 1, 1, 1)
end

function PathFinderModule:drawDebugForCreatedRoute()
    local AutoDriveDM = DrawingManager
    if self.chainStartToTarget ~= nil then
        for _, cell in pairs(self.chainStartToTarget) do
            local shape = self:getShapeDefByDirectionType(cell)
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

                AutoDriveDM:addLineTask(pointA.x, pointA.y, pointA.z, pointC.x, pointC.y, pointC.z, 1, 1, 1)
                AutoDriveDM:addLineTask(pointB.x, pointB.y, pointB.z, pointD.x, pointD.y, pointD.z, 1, 1, 1)

                if cell.incoming ~= nil then
                    local worldPos_cell = self:gridLocationToWorldLocation(cell)
                    local worldPos_incoming = self:gridLocationToWorldLocation(cell.incoming)

                    local vectorX = worldPos_cell.x - worldPos_incoming.x
                    local vectorZ = worldPos_cell.z - worldPos_incoming.z
                    local angleRad = math.atan2(-vectorZ, vectorX)
                    angleRad = AutoDrive.normalizeAngle(angleRad)
                    local widthOfColBox = math.sqrt(math.pow(self.minTurnRadius, 2) + math.pow(self.minTurnRadius, 2))
                    local sideLength = widthOfColBox / 2

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

                    AutoDriveDM:addLineTask(cornerX, inY, cornerZ, corner2X, currentY, corner2Z, 1, 0, 0)
                    AutoDriveDM:addLineTask(corner2X, currentY, corner2Z, corner3X, currentY, corner3Z, 1, 0, 0)
                    AutoDriveDM:addLineTask(corner3X, currentY, corner3Z, corner4X, inY, corner4Z, 1, 0, 0)
                    AutoDriveDM:addLineTask(corner4X, inY, corner4Z, cornerX, inY, cornerZ, 1, 0, 0)
                end
            end
        end
    end

    for i, waypoint in pairs(self.wayPoints) do
        Utils.renderTextAtWorldPosition(waypoint.x, waypoint.y + 4, waypoint.z, "Node " .. i, getCorrectTextSize(0.013), 0)
        if i > 1 then
            local wp = waypoint
            local pfWp = self.wayPoints[i - 1]
            AutoDriveDM:addLineTask(wp.x, wp.y, wp.z, pfWp.x, pfWp.y, pfWp.z, 0, 1, 1)
        end
    end
end

function PathFinderModule:getShapeDefByDirectionType(cell)
    local shapeDefinition = {}
    shapeDefinition.angleRad = math.atan2(-self.targetVector.z, self.targetVector.x)
    shapeDefinition.angleRad = AutoDrive.normalizeAngle(shapeDefinition.angleRad)
    local worldPos = self:gridLocationToWorldLocation(cell)
    shapeDefinition.y = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, worldPos.x, 1, worldPos.z)
    shapeDefinition.height = 2.85

    if cell.direction == self.PP_UP or cell.direction == self.PP_DOWN or cell.direction == self.PP_RIGHT or cell.direction == self.PP_LEFT then
        --default size:
        shapeDefinition.x = worldPos.x
        shapeDefinition.z = worldPos.z
        shapeDefinition.widthX = self.minTurnRadius / 2
        shapeDefinition.widthZ = self.minTurnRadius / 2
    elseif cell.direction == self.PP_UP_RIGHT then
        local offsetX = (-self.vectorX.x) / 2 + (-self.vectorZ.x) / 4
        local offsetZ = (-self.vectorX.z) / 2 + (-self.vectorZ.z) / 4
        shapeDefinition.x = worldPos.x + offsetX
        shapeDefinition.z = worldPos.z + offsetZ
        shapeDefinition.widthX = (self.minTurnRadius / 2) + math.abs(offsetX)
        shapeDefinition.widthZ = self.minTurnRadius / 2 + math.abs(offsetZ)
    elseif cell.direction == self.PP_UP_LEFT then
        local offsetX = (-self.vectorX.x) / 2 + (self.vectorZ.x) / 4
        local offsetZ = (-self.vectorX.z) / 2 + (self.vectorZ.z) / 4
        shapeDefinition.x = worldPos.x + offsetX
        shapeDefinition.z = worldPos.z + offsetZ
        shapeDefinition.widthX = self.minTurnRadius / 2 + math.abs(offsetX)
        shapeDefinition.widthZ = self.minTurnRadius / 2 + math.abs(offsetZ)
    elseif cell.direction == self.PP_DOWN_RIGHT then
        local offsetX = (self.vectorX.x) / 2 + (-self.vectorZ.x) / 4
        local offsetZ = (self.vectorX.z) / 2 + (-self.vectorZ.z) / 4
        shapeDefinition.x = worldPos.x + offsetX
        shapeDefinition.z = worldPos.z + offsetZ
        shapeDefinition.widthX = self.minTurnRadius / 2 + math.abs(offsetX)
        shapeDefinition.widthZ = self.minTurnRadius / 2 + math.abs(offsetZ)
    elseif cell.direction == self.PP_DOWN_LEFT then
        local offsetX = (self.vectorX.x) / 2 + (self.vectorZ.x) / 4
        local offsetZ = (self.vectorX.z) / 2 + (self.vectorZ.z) / 4
        shapeDefinition.x = worldPos.x + offsetX
        shapeDefinition.z = worldPos.z + offsetZ
        shapeDefinition.widthX = self.minTurnRadius / 2 + math.abs(offsetX)
        shapeDefinition.widthZ = self.minTurnRadius / 2 + math.abs(offsetZ)
    end

    return shapeDefinition
end

function PathFinderModule:createWayPoints()
    if self.smoothStep == 0 then
        local currentCell = self.targetCell
        self.chainTargetToStart = {}
        local index = 1
        self.chainTargetToStart[index] = currentCell
        index = index + 1
        while currentCell.x ~= 0 or currentCell.z ~= 0 do
            self.chainTargetToStart[index] = currentCell.incoming
            currentCell = currentCell.incoming
            if currentCell == nil then
                break
            end
            index = index + 1
        end
        index = index - 1

        self.chainStartToTarget = {}
        for reversedIndex = 0, index, 1 do
            self.chainStartToTarget[reversedIndex + 1] = self.chainTargetToStart[index - reversedIndex]
        end

        --Now build actual world coordinates as waypoints and include pre and append points
        self.wayPoints = {}
        for chainIndex, cell in pairs(self.chainStartToTarget) do
            self.wayPoints[chainIndex] = self:gridLocationToWorldLocation(cell)
            self.wayPoints[chainIndex].y = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, self.wayPoints[chainIndex].x, 1, self.wayPoints[chainIndex].z)
            self.wayPoints[chainIndex].lastDirection = cell.direction
        end

        self:smoothResultingPPPath()
    end

    if AutoDrive.getSetting("smoothField") == true then
        self:smoothResultingPPPath_Refined()
    else
        self.smoothStep = 2
        self.smoothDone = true
    end

    if self.smoothStep == 2 then
        if self.appendWayPoints ~= nil then
            for i = 1, #self.appendWayPoints, 1 do
                self.wayPoints[#self.wayPoints + 1] = self.appendWayPoints[i]
            end
            self.smoothStep = 3
        end
    end
end

function PathFinderModule:smoothResultingPPPath()
    local index = 1
    local filteredIndex = 1
    local filteredWPs = {}

    while index < #self.wayPoints - 1 do
        local node = self.wayPoints[index]
        local nodeAhead = self.wayPoints[index + 1]
        local nodeTwoAhead = self.wayPoints[index + 2]

        filteredWPs[filteredIndex] = node
        filteredIndex = filteredIndex + 1

        if node.lastDirection ~= nil and nodeAhead.lastDirection ~= nil and nodeTwoAhead.lastDirection ~= nil then
            if node.lastDirection == nodeTwoAhead.lastDirection and node.lastDirection ~= nodeAhead.lastDirection then
                index = index + 1 --skip next point because it is a zig zag line. Cut right through instead
            end
        end

        index = index + 1
    end

    while index <= #self.wayPoints do
        local node = self.wayPoints[index]
        filteredWPs[filteredIndex] = node
        filteredIndex = filteredIndex + 1
        index = index + 1
    end

    self.wayPoints = filteredWPs
end

function PathFinderModule:smoothResultingPPPath_Refined()
    if self.smoothStep == 0 then
        self.smoothIndex = 1
        self.filteredIndex = 1
        self.filteredWPs = {}

        --add first few without filtering
        while self.smoothIndex < #self.wayPoints and self.smoothIndex < 3 do
            self.filteredWPs[self.filteredIndex] = self.wayPoints[self.smoothIndex]
            self.filteredIndex = self.filteredIndex + 1
            self.smoothIndex = self.smoothIndex + 1
        end

        self.smoothStep = 1
    end

    local unfilteredEndPointCount = 5
    if self.smoothStep == 1 then
        local stepsThisFrame = 0
        while self.smoothIndex < #self.wayPoints - unfilteredEndPointCount and stepsThisFrame < 10 * AutoDrive.getSetting("pathFinderTime") do
            stepsThisFrame = stepsThisFrame + 1

            local node = self.wayPoints[self.smoothIndex]
            local previousNode = nil
            local worldPos = self.wayPoints[self.smoothIndex]

            if self.totalEagerSteps == nil or self.totalEagerSteps == 0 then
                self.filteredWPs[self.filteredIndex] = node
                if self.filteredIndex > 1 then
                    previousNode = self.filteredWPs[self.filteredIndex - 1]
                end
                self.filteredIndex = self.filteredIndex + 1

                self.lookAheadIndex = 1
                self.eagerLookAhead = 0
                self.totalEagerSteps = 0
            end

            local widthOfColBox = self.minTurnRadius
            local sideLength = widthOfColBox / 2
            local y = worldPos.y
            local foundCollision = false

            local stepsOfLookAheadThisFrame = 0
            while (foundCollision == false or self.totalEagerSteps < 30) and ((self.smoothIndex + self.totalEagerSteps) < (#self.wayPoints - unfilteredEndPointCount)) and stepsOfLookAheadThisFrame < unfilteredEndPointCount do
                stepsOfLookAheadThisFrame = stepsOfLookAheadThisFrame + 1
                local nodeAhead = self.wayPoints[self.smoothIndex + self.totalEagerSteps + 1]
                local nodeTwoAhead = self.wayPoints[self.smoothIndex + self.totalEagerSteps + 2]

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

                hasCollision = hasCollision or AutoDrive.checkSlopeAngle(worldPos.x, worldPos.z, nodeAhead.x, nodeAhead.z)

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

                if (self.smoothIndex > 1) then
                    local worldPosPrevious = self.wayPoints[self.smoothIndex - 1]
                    length = MathUtil.vector3Length(worldPos.x - worldPosPrevious.x, worldPos.y - worldPosPrevious.y, worldPos.z - worldPosPrevious.z)
                    local angleBetween = math.atan(math.abs(worldPos.y - worldPosPrevious.y) / length)

                    if angleBetween > AITurnStrategy.SLOPE_DETECTION_THRESHOLD then
                        hasCollision = true
                    end
                end

                if self.fruitToCheck ~= nil then
                    local fruitValue, _, _, _ = FSDensityMapUtil.getFruitArea(self.fruitToCheck, cornerX, cornerZ, corner2X, corner2Z, corner4X, corner4Z, nil, false)
                    if self.fruitToCheck == 9 or self.fruitToCheck == 22 then
                        fruitValue, _, _, _ = FSDensityMapUtil.getFruitArea(self.fruitToCheck, cornerX, cornerZ, corner2X, corner2Z, corner4X, corner4Z, true, true)
                    end

                    hasCollision = hasCollision or (fruitValue > 50)
                end

                local cellBox = AutoDrive.boundingBoxFromCorners(cornerX, cornerZ, corner2X, corner2Z, corner3X, corner3Z, corner4X, corner4Z)
                hasCollision = hasCollision or AutoDrive.checkForVehiclesInBox(cellBox, {}, self.minTurnRadius)

                foundCollision = hasCollision

                if foundCollision then
                    self.eagerLookAhead = self.eagerLookAhead + 1
                else
                    self.lookAheadIndex = self.totalEagerSteps + 1
                    self.eagerLookAhead = 0
                end

                self.totalEagerSteps = self.totalEagerSteps + 1
            end

            if self.totalEagerSteps >= 30 or ((self.smoothIndex + self.totalEagerSteps) >= (#self.wayPoints - unfilteredEndPointCount)) then
                self.smoothIndex = self.smoothIndex + math.max(1, (self.lookAheadIndex))
                self.totalEagerSteps = 0
            end
        end

        if self.smoothIndex >= #self.wayPoints - unfilteredEndPointCount then
            self.smoothStep = 2
        end
    end

    if self.smoothStep == 2 then
        --add remaining points without filtering
        while self.smoothIndex <= #self.wayPoints do
            local node = self.wayPoints[self.smoothIndex]
            self.filteredWPs[self.filteredIndex] = node
            self.filteredIndex = self.filteredIndex + 1
            self.smoothIndex = self.smoothIndex + 1
        end

        self.wayPoints = self.filteredWPs

        self.smoothDone = true
    end
end
