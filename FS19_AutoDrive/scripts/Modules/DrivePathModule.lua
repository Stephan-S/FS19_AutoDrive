ADDrivePathModule = {}

ADDrivePathModule.LOOKAHEADDISTANCE = 20
ADDrivePathModule.MAXLOOKAHEADPOINTS = 20

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
end

function ADDrivePathModule:setPathTo(waypointID)
    self.wayPoints = ADGraphManager:getPathTo(self.vehicle, waypointID)
    self:setDirtyFlag()
    self.minDistanceToNextWp = math.huge
    
    if self.wayPoints == nil or (self.wayPoints[2] == nil and (self.wayPoints[1] == nil or (self.wayPoints[1] ~= nil and self.wayPoints[1].id ~= waypointID))) then
        print("self.wayPoints[1]: " .. self.wayPoints[1].id)
        g_logManager:error("[AutoDrive] Encountered a problem during initialization - shutting down")
        AutoDriveMessageEvent.sendMessageOrNotification(self.vehicle, MessagesManager.messageTypes.ERROR, "$l10n_AD_Driver_of; %s $l10n_AD_cannot_reach; %s", 5000, self.vehicle.ad.driverName, self.vehicle.ad.nameOfSelectedTarget)
        self.vehicle.ad.taskModule:addTask(StopAndDisableADTask:new(self.vehicle))
    else
        print("Got path to destination of length: " .. #self.wayPoints)
        --skip first wp for a smoother start
        if self.wayPoints[2] ~= nil then
            self.currentWayPoint = 2
        else
            self.currentWayPoint = 1
        end

        if not self.vehicle.ad.trailerModule:isActiveAtTrigger() then
            self:setUnPaused()
        end

        self.atTarget = false
    end
end

function ADDrivePathModule:setWayPoints(wayPoints)
    self.wayPoints = wayPoints
    self.minDistanceToNextWp = math.huge
    self.atTarget = false
    if self.wayPoints[2] ~= nil then
        self.currentWayPoint = 2
    else
        self.currentWayPoint = 1
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
    -- Todo:
    --AutoDrive:checkForDeadLock(vehicle, dt)
    --AutoDrive:handleDeadlock(vehicle, dt)

    if self.wayPoints ~= nil and self.currentWayPoint <= #self.wayPoints then
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
    if self.wayPoints[self.currentWayPoint] ~= nil then
        if AutoDrive.getDistance(x, z, self.wayPoints[self.currentWayPoint].x, self.wayPoints[self.currentWayPoint].z) < self.min_distance then
            return true
        end
    end
    return false
end

function ADDrivePathModule:followWaypoints(dt)
    local x, y, z = getWorldTranslation(self.vehicle.components[1].node)

    self.targetSpeed = self.vehicle.ad.targetSpeed
    self.acceleration = 1
    if self.wayPoints[self.currentWayPoint - 1] ~= nil and self.wayPoints[self.currentWayPoint + 1] ~= nil then
        local highestAngle = self:getHighestApproachingAngle()
        self.targetSpeed = self:getMaxSpeedForAngle(highestAngle)
    end

    local distanceToTarget = self:getDistanceToLastWaypoint(10)
    if distanceToTarget < 20 then
        self.targetSpeed =  math.clamp(8, self.targetSpeed, distanceToTarget)
    end

    if ADTriggerManager.checkForTriggerProximity(self.vehicle) then
        self.targetSpeed = math.min(5, self.targetSpeed)
    end

    if self.vehicle.ad.inDeadLock then
        self.targetSpeed = math.min(AutoDrive.DEADLOCKSPEED, self.targetSpeed)
    end

    if AutoDrive.checkIsOnField(x, y, z) then
        self.targetSpeed = math.min(AutoDrive.SPEED_ON_FIELD, self.targetSpeed)
    end

    if self.vehicle.ad.trailerModule:isUnloadingToBunkerSilo() then
        self.targetSpeed = math.min(self.vehicle.ad.trailerModule:getBunkerSiloSpeed(), self.targetSpeed)
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
        AIVehicleUtil.driveInDirection(self.vehicle, dt, maxAngle, self.acceleration, 0.8, maxAngle / 1.5, true, true, lx, lz, self.targetSpeed, 0.65)
    end
end

function ADDrivePathModule:handleReachedWayPoint()
    if self:getNextWaypoint() ~= nil then
        self:switchToNextWayPoint()
    else
        print("Reached target wp")
        self:reachedTarget()
    end
end

function ADDrivePathModule:reachedTarget()
    self.atTarget = true;
end

function ADDrivePathModule:isTargetReached()
    return self.atTarget
end

-- To differentiate between waypoints on the road and ones created from pathfinder
function ADDrivePathModule:isOnRoadNetwork()
    return self.onRoadNetwork
end

function ADDrivePathModule:getWayPoints()
    return self.wayPoints, self.currentWayPoint
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
    local distanceToLookAhead = self:getCurrentLookAheadDistance()
    local pointsToLookAhead = ADDrivePathModule.MAXLOOKAHEADPOINTS
    
    local highestAngle = 0
    local doneCheckingRoute = false
    local currentLookAheadPoint = 1
    while not doneCheckingRoute and currentLookAheadPoint <= pointsToLookAhead do
        if self.wayPoints[self.currentWayPoint + currentLookAheadPoint] ~= nil then
            local wp_ahead = self.wayPoints[self.currentWayPoint + currentLookAheadPoint]
            local wp_current = self.wayPoints[self.currentWayPoint + currentLookAheadPoint - 1]
            local wp_ref = self.wayPoints[self.currentWayPoint + currentLookAheadPoint - 2]

            local angle = AutoDrive.angleBetween({x = wp_ahead.x - wp_ref.x, z = wp_ahead.z - wp_ref.z}, {x = wp_current.x - wp_ref.x, z = wp_current.z - wp_ref.z})
            angle = math.abs(angle)
            
            if AutoDrive.getDistance(self.wayPoints[self.currentWayPoint].x, self.wayPoints[self.currentWayPoint].z, wp_ahead.x, wp_ahead.z) <= distanceToLookAhead then
                highestAngle = math.max(highestAngle, angle)
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
    local maxSpeed = self.vehicle.ad.targetSpeed;
    
    if angle < 3 then
        maxSpeed = self.vehicle.ad.targetSpeed
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

    return maxSpeed * 1.8
end

function ADDrivePathModule:getDistanceToLastWaypoint(maxLookAheadPar)
    local distance = 0
    local maxLookAhead = maxLookAheadPar
    if maxLookAhead == nil then
        maxLookAhead = 10
    end
    if self.wayPoints ~= nil and self.currentWayPoint ~= nil and self.wayPoints[self.currentWayPoint] ~= nil then
        local lookAhead = 1
        while self.wayPoints[self.currentWayPoint + lookAhead] ~= nil and lookAhead < maxLookAhead do
            local p1 = self.wayPoints[self.currentWayPoint + lookAhead]
            local p2 = self.wayPoints[self.currentWayPoint + lookAhead - 1]
            distance = distance + MathUtil.vector2Length(p2.x - p1.x, p2.z - p1.z)

            lookAhead = lookAhead + 1
        end
    end

    return distance
end

function ADDrivePathModule:getNextWaypoint()
    return self.wayPoints[self.currentWayPoint + 1]
end

function ADDrivePathModule:switchToNextWayPoint()
    self.currentWayPoint = self.currentWayPoint + 1
    self.minDistanceToNextWp = math.huge
end

function ADDrivePathModule:getLookAheadTarget()
    --start driving to the nextWayPoint when closing in on current waypoint in order to avoid harsh steering angles and oversteering

    local x, _, z = getWorldTranslation(self.vehicle.components[1].node)
    local targetX = x
    local targetZ = z

    if self.wayPoints[self.currentWayPoint] ~= nil then
        targetX = self.wayPoints[self.currentWayPoint].x
        targetZ = self.wayPoints[self.currentWayPoint].z
    end

    if self.wayPoints[self.currentWayPoint + 1] ~= nil then
        local wp_current = self.wayPoints[self.currentWayPoint]

        local lookAheadID = 1
        local lookAheadDistance = AutoDrive.getSetting("lookAheadTurning")
        local distanceToCurrentTarget = AutoDrive.getDistance(x, z, wp_current.x, wp_current.z)
                
        local wp_ahead = self.wayPoints[self.currentWayPoint + lookAheadID]
        local distanceToNextTarget = AutoDrive.getDistance(x, z, wp_ahead.x, wp_ahead.z)
        
        if distanceToCurrentTarget < distanceToNextTarget then
            lookAheadDistance = lookAheadDistance - distanceToCurrentTarget
        end

        while lookAheadDistance > distanceToNextTarget do
            lookAheadDistance = lookAheadDistance - distanceToNextTarget
            lookAheadID = lookAheadID + 1
            if self.wayPoints[self.currentWayPoint + lookAheadID] == nil then
                break
            end
            wp_current = wp_ahead
            wp_ahead = self.wayPoints[self.currentWayPoint + lookAheadID]
            distanceToNextTarget = AutoDrive.getDistance(wp_current.x, wp_current.z, wp_ahead.x, wp_ahead.z)
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
            if not AutoDrive:checkIsOnField(self.vehicle) and self.vehicle.spec_motorized.isMotorStarted then
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
        if not self.vehicle.ad.specialDrivingModule:isStoppingVehicle() then
            --print("ADDrivePathModule:checkIfStuck(dt) - " .. self.minDistanceTimer.elapsedTime)
            local x, _, z = getWorldTranslation(self.vehicle.components[1].node)
            local distanceToNextWayPoint = AutoDrive.getDistance(x, z, self.wayPoints[self.currentWayPoint].x, self.wayPoints[self.currentWayPoint].z)
            self.minDistanceTimer:timer(distanceToNextWayPoint >= self.minDistanceToNextWp, 5000, dt)
            self.minDistanceToNextWp = math.min(self.minDistanceToNextWp, distanceToNextWayPoint)
            if self.minDistanceTimer:done() then
                self:handleBeingStuck()
            end
        end
    end
end

function ADDrivePathModule:handleBeingStuck()
    print("ADDrivePathModule:handleBeingStuck()")
    if self.vehicle.isServer then
        --deadlock handling
        self.vehicle.ad.taskModule:stopAndRestartAD()
    end
end