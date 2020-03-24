ADDrivePathModule = {}

ADDrivePathModule.LOOKAHEADDISTANCE = 20
ADDrivePathModule.MAXLOOKAHEADPOINTS = 20
ADDrivePathModule.MAX_SPEED_DEVIATION = 6
ADDrivePathModule.MAX_STEERING_ANGLE = 30
ADDrivePathModule.SPEED_ON_FIELD = 100

function ADDrivePathModule:new(vehicle)
    local o = {}
    setmetatable(o, self)
    self.__index = self
    o.vehicle = vehicle
    o.min_distance = AutoDrive.defineMinDistanceByVehicleType(vehicle)
    o.minDistanceTimer = AutoDriveTON:new()
    ADDrivePathModule.reset(o)
    return o
end

function ADDrivePathModule:reset()
    self.isPaused = false
    self.atTarget = false
    self.wayPoints = nil
    self.currentWayPoint = 0
    self.onRoadNetwork = true
    self.minDistanceToNextWp = math.huge
    self.minDistanceTimer:timer(false, 5000, 0)
    self.vehicle.ad.stateModule:setCurrentWayPointId(-1)
    self.vehicle.ad.stateModule:setNextWayPointId(-1)
end

function ADDrivePathModule:setPathTo(waypointId)
    self.wayPoints = ADGraphManager:getPathTo(self.vehicle, waypointId)
    local destination = ADGraphManager:getMapMarkerByWayPointId(self:getLastWayPointId())
    self.vehicle.ad.stateModule:setCurrentDestination(destination)
    self:setDirtyFlag()
    self.minDistanceToNextWp = math.huge

    if self.wayPoints == nil or (self.wayPoints[2] == nil and (self.wayPoints[1] == nil or (self.wayPoints[1] ~= nil and self.wayPoints[1].id ~= waypointId))) then
        g_logManager:error("[AutoDrive] Encountered a problem during initialization - shutting down")
        AutoDriveMessageEvent.sendMessageOrNotification(self.vehicle, ADMessagesManager.messageTypes.ERROR, "$l10n_AD_Driver_of; %s $l10n_AD_cannot_reach; %s", 5000, self.vehicle.ad.stateModule:getName(), self.vehicle.ad.stateModule:getFirstMarker().name)
        self.vehicle.ad.taskModule:abortAllTasks()
        self.vehicle.ad.taskModule:addTask(StopAndDisableADTask:new(self.vehicle))
    else
        --skip first wp for a smoother start
        if self.wayPoints[2] ~= nil then
            self:setCurrentWayPointIndex(2)
        else
            self:setCurrentWayPointIndex(1)
        end

        if not self.vehicle.ad.trailerModule:isActiveAtTrigger() then
            self:setUnPaused()
        end

        self.atTarget = false
    end
end

function ADDrivePathModule:appendPathTo(startWayPointId, wayPointId)
    local appendWayPoints = ADGraphManager:getPathTo(self.vehicle, wayPointId)

    if appendWayPoints == nil or (appendWayPoints[2] == nil and (appendWayPoints[1] == nil or (appendWayPoints[1] ~= nil and appendWayPoints[1].id ~= wayPointId))) then
        g_logManager:error("[AutoDrive] Encountered a problem during initialization - shutting down")
        AutoDriveMessageEvent.sendMessageOrNotification(self.vehicle, ADMessagesManager.messageTypes.ERROR, "$l10n_AD_Driver_of; %s $l10n_AD_cannot_reach; %s", 5000, self.vehicle.ad.stateModule:getName(), self.vehicle.ad.stateModule:getFirstMarker().name)
        self.vehicle.ad.taskModule:abortAllTasks()
        self.vehicle.ad.taskModule:addTask(StopAndDisableADTask:new(self.vehicle))
    else
        --skip first wp for a smoother start
        for _, wp in ipairs(appendWayPoints) do
            table.insert(self.wayPoints, wp)
        end
    end
end

function ADDrivePathModule:setWayPoints(wayPoints)
    self.wayPoints = wayPoints
    local destination = ADGraphManager:getMapMarkerByWayPointId(self:getLastWayPointId())
    self.vehicle.ad.stateModule:setCurrentDestination(destination)
    self.minDistanceToNextWp = math.huge
    self.atTarget = false
    if self.wayPoints[2] ~= nil then
        self:setCurrentWayPointIndex(2)
    else
        self:setCurrentWayPointIndex(1)
    end
end

function ADDrivePathModule:setPaused()
    self.isPaused = true
end

function ADDrivePathModule:setUnPaused()
    self.isPaused = false
end

function ADDrivePathModule:setDirtyFlag()
    self.wayPointsDirtyFlag = true
end

function ADDrivePathModule:resetDirtyFlag()
    self.wayPointsDirtyFlag = false
end

function ADDrivePathModule:update(dt)
    if self.wayPoints ~= nil and self:getCurrentWayPointIndex() <= #self.wayPoints then
        local x, _, z = getWorldTranslation(self.vehicle.components[1].node)
        if self:isCloseToWaypoint() then
            self:handleReachedWayPoint()
        end

        self:followWaypoints(dt)
        self:checkActiveAttributesSet()
        self:checkIfStuck(dt)
    end
end

function ADDrivePathModule:isCloseToWaypoint()
    local x, _, z = getWorldTranslation(self.vehicle.components[1].node)
    local maxSkipWayPoints = 2
    for i = 0, maxSkipWayPoints do
        if self.wayPoints[self:getCurrentWayPointIndex() + i] ~= nil then
            local distanceToCurrentWp = MathUtil.vector2Length(x - self.wayPoints[self:getCurrentWayPointIndex() + i].x, z - self.wayPoints[self:getCurrentWayPointIndex() + i].z)
            if distanceToCurrentWp < self.min_distance then
                return true
            end
            -- Check if vehicle is cutting corners due to the lookahead target and skip current waypoint accordingly
            if i > 0 then
                local distanceToLastWp =  MathUtil.vector2Length(x - self.wayPoints[self:getCurrentWayPointIndex() + i - 1].x, z - self.wayPoints[self:getCurrentWayPointIndex() + i - 1].z)
                if distanceToCurrentWp < distanceToLastWp and distanceToCurrentWp < 8 then
                    return true
                end
            end
            -- Check if the angle between vehicle and current wp and current wp to next wp is over 90° - then we should already make the switch
            if i == 1 then
                local wp_ahead = self:getNextWayPoint()
                local wp_current = self:getCurrentWayPoint()

                local angle = AutoDrive.angleBetween({x = wp_ahead.x - wp_current.x, z = wp_ahead.z - wp_current.z}, {x = wp_current.x - x, z = wp_current.z - z})
                angle = math.abs(angle)

                if angle >= 90 then
                    return true
                end
            end
        end
    end
    return false
end

function ADDrivePathModule:followWaypoints(dt)
    local x, y, z = getWorldTranslation(self.vehicle.components[1].node)

    self.speedLimit = self.vehicle.ad.stateModule:getSpeedLimit()
    self.acceleration = 1
    self.distanceToLookAhead = 8
    if self.wayPoints[self:getCurrentWayPointIndex() - 1] ~= nil and self:getNextWayPoint() ~= nil then
        local highestAngle = self:getHighestApproachingAngle()
        self.speedLimit = math.min(self.speedLimit, self:getMaxSpeedForAngle(highestAngle))
    end

    self.distanceToTarget = self:getDistanceToLastWaypoint(10)
    if self.distanceToTarget < self.distanceToLookAhead then
        self.speedLimit = math.clamp(8, self.speedLimit, 2 + self.distanceToTarget)
    end

    self.speedLimit = math.min(self.speedLimit, self:getSpeedLimitBySteeringAngle())

    if ADTriggerManager.checkForTriggerProximity(self.vehicle, self.distanceToTarget) then
        self.speedLimit = math.min(5, self.speedLimit)
    end

    if AutoDrive.checkIsOnField(x, y, z) then
        self.speedLimit = math.min(ADDrivePathModule.SPEED_ON_FIELD, self.speedLimit)
    end

    local maxSpeedDiff = ADDrivePathModule.MAX_SPEED_DEVIATION
    if self.vehicle.ad.trailerModule:isUnloadingToBunkerSilo() then
        self.speedLimit = math.min(self.vehicle.ad.trailerModule:getBunkerSiloSpeed(), self.speedLimit)
        maxSpeedDiff = 1
    else
        if self.vehicle.ad.stateModule:getCurrentMode():shouldUnloadAtTrigger() and AutoDrive.isVehicleInBunkerSiloArea(self.vehicle) then
            self.speedLimit = math.min(5, self.speedLimit)
            maxSpeedDiff = 3
        end
    end

    local maxAngle = 60
    if self.vehicle.maxRotation then
        if self.vehicle.maxRotation > (2 * math.pi) then
            maxAngle = self.vehicle.maxRotation
        else
            maxAngle = math.deg(self.vehicle.maxRotation)
        end
    end

    self.targetX, self.targetZ = self:getLookAheadTarget()
    local lx, lz = AIVehicleUtil.getDriveDirection(self.vehicle.components[1].node, self.targetX, y, self.targetZ)

    if self.vehicle.ad.collisionDetectionModule:hasDetectedObstable() then
        self.vehicle.ad.specialDrivingModule:stopVehicle(lx, lz)
        self.vehicle.ad.specialDrivingModule:update(dt)
    else
        self.vehicle.ad.specialDrivingModule:releaseVehicle()
        -- Allow active braking if vehicle is not 'following' targetSpeed precise enough
        if (self.vehicle.lastSpeedReal * 3600) > (self.speedLimit + maxSpeedDiff) then
            self.acceleration = -0.6
        end
        --ADDrawingManager:addLineTask(x, y, z, self.targetX, y, self.targetZ, 1, 0, 0)
        AIVehicleUtil.driveInDirection(self.vehicle, dt, maxAngle, self.acceleration, 0.8, maxAngle, true, true, lx, lz, self.speedLimit, 1)
    end
end

function ADDrivePathModule:handleReachedWayPoint()
    if self:getNextWayPoint() ~= nil then
        self:switchToNextWayPoint()
    else
        self:reachedTarget()
    end
end

function ADDrivePathModule:reachedTarget()
    self.atTarget = true
end

function ADDrivePathModule:isTargetReached()
    return self.atTarget
end

-- To differentiate between waypoints on the road and ones created from pathfinder
function ADDrivePathModule:isOnRoadNetwork()
    return self.onRoadNetwork
end

function ADDrivePathModule:getWayPoints()
    return self.wayPoints, self:getCurrentWayPointIndex()
end

function ADDrivePathModule:getLastWayPoint()
    if self.wayPoints ~= nil then
        return self.wayPoints[#self.wayPoints]
    end
    return nil
end

function ADDrivePathModule:getLastWayPointId()
    local lastWp = self:getLastWayPoint()
    if lastWp ~= nil then
        return lastWp.id
    end
    return -1
end

function ADDrivePathModule:getCurrentLookAheadDistance()
    local totalMass = self.vehicle:getTotalMass(false)
    local massFactor = math.max(1, math.min(3, (totalMass + 20) / 30))
    local speedFactor = math.max(0.5, math.min(4, (((self.vehicle.lastSpeedReal * 3600) + 10) / 20.0)))
    if speedFactor <= 1 then
        massFactor = 1
    end
    return math.min(ADDrivePathModule.LOOKAHEADDISTANCE * massFactor * speedFactor, 100)
end

function ADDrivePathModule:getHighestApproachingAngle()
    self.distanceToLookAhead = self:getCurrentLookAheadDistance()
    local pointsToLookAhead = ADDrivePathModule.MAXLOOKAHEADPOINTS
    local x, y, z = getWorldTranslation(self.vehicle.components[1].node)
    local baseDistance = MathUtil.vector2Length(self:getCurrentWayPoint().x - x, self:getCurrentWayPoint().z - z)

    local highestAngle = 0
    local doneCheckingRoute = false
    local currentLookAheadPoint = 1
    while not doneCheckingRoute and currentLookAheadPoint <= pointsToLookAhead do
        if self.wayPoints[self:getCurrentWayPointIndex() + currentLookAheadPoint] ~= nil then
            local wp_ahead = self.wayPoints[self:getCurrentWayPointIndex() + currentLookAheadPoint]
            local wp_current = self.wayPoints[self:getCurrentWayPointIndex() + currentLookAheadPoint - 1]
            local wp_ref = self.wayPoints[self:getCurrentWayPointIndex() + currentLookAheadPoint - 2]

            local angle = AutoDrive.angleBetween({x = wp_ahead.x - wp_ref.x, z = wp_ahead.z - wp_ref.z}, {x = wp_current.x - wp_ref.x, z = wp_current.z - wp_ref.z})
            angle = math.abs(angle)

            if MathUtil.vector2Length(self:getCurrentWayPoint().x - wp_ahead.x, self:getCurrentWayPoint().z - wp_ahead.z) <= (self.distanceToLookAhead - baseDistance) then
                if angle < 100 then
                    highestAngle = math.max(highestAngle, angle)
                end
            else
                doneCheckingRoute = true
            end
        else
            doneCheckingRoute = true
        end
        currentLookAheadPoint = currentLookAheadPoint + 1
    end

    return highestAngle
end

function ADDrivePathModule:getMaxSpeedForAngle(angle)
    local maxSpeed = math.huge

    if angle < 3 then
        maxSpeed = self.vehicle.ad.stateModule:getSpeedLimit()
    elseif angle < 5 then
        maxSpeed = 38
    elseif angle < 8 then
        maxSpeed = 27
    elseif angle < 12 then
        maxSpeed = 20
    elseif angle < 15 then
        maxSpeed = 17
    elseif angle < 20 then
        maxSpeed = 16
    else
        maxSpeed = 13
    end

    return maxSpeed * 1.25 * AutoDrive.getSetting("cornerSpeed", self.vehicle)
end

function ADDrivePathModule:getSpeedLimitBySteeringAngle()
    local steeringAngle = math.deg(math.abs(self.vehicle.rotatedTime))

    local maxSpeed = math.huge

    local maxAngle = 60
    if self.vehicle.maxRotation then
        if self.vehicle.maxRotation > (2 * math.pi) then
            maxAngle = self.vehicle.maxRotation
        else
            maxAngle = math.deg(self.vehicle.maxRotation)
        end
    end

    if steeringAngle > maxAngle * 0.85 then
        maxSpeed = 10
    end
    return maxSpeed
end

function ADDrivePathModule:getDistanceToLastWaypoint(maxLookAheadPar)
    local distance = math.huge
    local maxLookAhead = maxLookAheadPar
    if maxLookAhead == nil then
        maxLookAhead = 10
    end
    
    if self.wayPoints ~= nil and self:getCurrentWayPointIndex() ~= nil and self:getCurrentWayPoint() ~= nil and (self:getCurrentWayPointIndex() + maxLookAheadPar) >= #self.wayPoints then
        distance = 0
        local lookAhead = 1
        while self.wayPoints[self:getCurrentWayPointIndex() + lookAhead] ~= nil and lookAhead < maxLookAhead do
            local p1 = self.wayPoints[self:getCurrentWayPointIndex() + lookAhead]
            local p2 = self.wayPoints[self:getCurrentWayPointIndex() + lookAhead - 1]
            local pointDistance = MathUtil.vector2Length(p2.x - p1.x, p2.z - p1.z)
            if pointDistance ~= nil then
                distance = distance + pointDistance
            end
            lookAhead = lookAhead + 1
        end
    end

    return distance
end

function ADDrivePathModule:getNextWayPoint()
    return self.wayPoints[self:getNextWayPointIndex()]
end

function ADDrivePathModule:getNextWayPointId()
    local nWp = self:getNextWayPoint()
    if nWp ~= nil and nWp.id ~= nil then
        return nWp.id
    end
    return -1
end

function ADDrivePathModule:getNextWayPoints()
    local cId = self:getCurrentWayPointIndex()
    return self.wayPoints[cId + 1], self.wayPoints[cId + 2], self.wayPoints[cId + 3], self.wayPoints[cId + 4], self.wayPoints[cId + 5]
end

function ADDrivePathModule:setCurrentWayPointIndex(waypointId)
    self.currentWayPoint = waypointId
    self.vehicle.ad.stateModule:setCurrentWayPointId(self:getCurrentWayPointId())
    self.vehicle.ad.stateModule:setNextWayPointId(self:getNextWayPointId())
end

function ADDrivePathModule:getCurrentWayPointIndex()
    return self.currentWayPoint
end

function ADDrivePathModule:getCurrentWayPoint()
    return self.wayPoints[self:getCurrentWayPointIndex()]
end

function ADDrivePathModule:getCurrentWayPointId()
    local nWp = self:getCurrentWayPoint()
    if nWp ~= nil and nWp.id ~= nil then
        return nWp.id
    end
    return -1
end

function ADDrivePathModule:getNextWayPointIndex()
    return self:getCurrentWayPointIndex() + 1
end

function ADDrivePathModule:switchToNextWayPoint()
    self:setCurrentWayPointIndex(self:getNextWayPointIndex())
    self.minDistanceToNextWp = math.huge
end

function ADDrivePathModule:getLookAheadTarget()
    --start driving to the nextWayPoint when closing in on current waypoint in order to avoid harsh steering angles and oversteering

    local x, _, z = getWorldTranslation(self.vehicle.components[1].node)
    local targetX = x
    local targetZ = z

    local wp_current = self:getCurrentWayPoint()

    if wp_current ~= nil then
        targetX = wp_current.x
        targetZ = wp_current.z
    end

    if self:getNextWayPoint() ~= nil then
        local lookAheadID = 1
        local lookAheadDistance = AutoDrive.getSetting("lookAheadTurning")
        local distanceToCurrentTarget = MathUtil.vector2Length(x - wp_current.x, z - wp_current.z)

        local wp_ahead = self.wayPoints[self:getCurrentWayPointIndex() + lookAheadID]
        local distanceToNextTarget = MathUtil.vector2Length(x - wp_ahead.x, z - wp_ahead.z)

        if distanceToCurrentTarget < distanceToNextTarget then
            lookAheadDistance = lookAheadDistance - distanceToCurrentTarget
        end

        while lookAheadDistance > distanceToNextTarget do
            lookAheadDistance = lookAheadDistance - distanceToNextTarget
            lookAheadID = lookAheadID + 1
            if self.wayPoints[self:getCurrentWayPointIndex() + lookAheadID] == nil then
                break
            end
            wp_current = wp_ahead
            wp_ahead = self.wayPoints[self:getCurrentWayPointIndex() + lookAheadID]
            distanceToNextTarget = MathUtil.vector2Length(wp_current.x - wp_ahead.x, wp_current.z - wp_ahead.z)
        end

        local distX = wp_ahead.x - wp_current.x
        local distZ = wp_ahead.z - wp_current.z
        if lookAheadDistance > 0 then
            local addX = lookAheadDistance * (math.abs(distX) / (math.abs(distX) + math.abs(distZ)))
            local addZ = lookAheadDistance * (math.abs(distZ) / (math.abs(distX) + math.abs(distZ)))
            if distX < 0 then
                addX = -addX
            end

            if distZ < 0 then
                addZ = -addZ
            end

            if (math.abs(distX) + math.abs(distZ)) > 0 then
                targetX = wp_current.x + addX
                targetZ = wp_current.z + addZ
            end
        end
    end

    return targetX, targetZ
end

function ADDrivePathModule:checkActiveAttributesSet()
    if self.vehicle.isServer then
        self.vehicle.forceIsActive = true
        self.vehicle.spec_motorized.stopMotorOnLeave = false
        self.vehicle.spec_enterable.disableCharacterOnLeave = false

        if self.vehicle.steeringEnabled == true then
            self.vehicle.steeringEnabled = false
        end
        self.vehicle.spec_aiVehicle.aiTrafficCollisionTranslation[2] = -1000

        if self.vehicle.setBeaconLightsVisibility ~= nil and AutoDrive.getSetting("useBeaconLights") then
            local x, y, z = getWorldTranslation(self.vehicle.components[1].node)
            if not AutoDrive.checkIsOnField(x, y, z) and self.vehicle.spec_motorized.isMotorStarted then
                self.vehicle:setBeaconLightsVisibility(true)
            else
                self.vehicle:setBeaconLightsVisibility(false)
            end
        end

        -- Only the server has to start/stop motor
        if self.vehicle.startMotor and self.vehicle.stopMotor then
            if not self.vehicle.spec_motorized.isMotorStarted and self.vehicle:getCanMotorRun() then
                self.vehicle:startMotor()
            end
        end
    end
end

function ADDrivePathModule:checkIfStuck(dt)
    if self.vehicle.isServer then
        local wp = self:getCurrentWayPoint()
        if not self.vehicle.ad.specialDrivingModule:isStoppingVehicle() and wp ~= nil then
            local x, _, z = getWorldTranslation(self.vehicle.components[1].node)
            local distanceToNextWayPoint = MathUtil.vector2Length(x - wp.x, z - wp.z)
            self.minDistanceTimer:timer(distanceToNextWayPoint >= self.minDistanceToNextWp, 8000, dt)
            self.minDistanceToNextWp = math.min(self.minDistanceToNextWp, distanceToNextWayPoint)
            if self.minDistanceTimer:done() then
                self:handleBeingStuck()
            end
        else
            self.minDistanceTimer:timer(false)
        end
    end
end

function ADDrivePathModule:handleBeingStuck()
    AutoDrive.debugPrint(self.vehicle, AutoDrive.DC_VEHICLEINFO, "handleBeingStuck")
    if self.vehicle.isServer then
        self.vehicle.ad.taskModule:stopAndRestartAD()
    end
end
