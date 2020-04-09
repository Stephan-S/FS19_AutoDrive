ADSpecialDrivingModule = {}

ADSpecialDrivingModule.MAX_SPEED_DEVIATION = 6

function ADSpecialDrivingModule:new(vehicle)
    local o = {}
    setmetatable(o, self)
    self.__index = self
    o.vehicle = vehicle
    ADSpecialDrivingModule.reset(o)
    return o
end

function ADSpecialDrivingModule:reset()
    self.shouldStopOrHoldVehicle = false
    self.unloadingIntoBunkerSilo = false
end

function ADSpecialDrivingModule:stopVehicle(lx, lz)
    self.shouldStopOrHoldVehicle = true
    self.targetLX = lx
    self.targetLZ = lz
end

function ADSpecialDrivingModule:releaseVehicle()
    self.shouldStopOrHoldVehicle = false
    self.motorShouldBeStopped = false
end

function ADSpecialDrivingModule:update(dt)
    if self.shouldStopOrHoldVehicle then
        self:stopAndHoldVehicle(dt)
    end
end

function ADSpecialDrivingModule:isStoppingVehicle()
    return self.shouldStopOrHoldVehicle
end

function ADSpecialDrivingModule:stopAndHoldVehicle(dt)
    local finalSpeed = 0
    local acc = -0.6
    local allowedToDrive = false

    if math.abs(self.vehicle.lastSpeedReal) > 0.002 then
        finalSpeed = 0.01
        allowedToDrive = true
    end

    local x, y, z = getWorldTranslation(self.vehicle.components[1].node)

    local lx, lz = self.targetLX, self.targetLZ

    if lx == nil or lz == nil then
        --If no target was provided, aim in front of te vehicle to prevent steering maneuvers
        local rx, _, rz = localDirectionToWorld(self.vehicle.components[1].node, 0, 0, 1)
        x = x + rx
        z = z + rz

        lx, lz = AIVehicleUtil.getDriveDirection(self.vehicle.components[1].node, x, y, z)
    end

    if self.stoppedTimer == nil then
        self.stoppedTimer = AutoDriveTON:new()
    end
    self.stoppedTimer:timer(self.vehicle.lastSpeedReal < 0.0013 and (not self.vehicle.ad.trailerModule:isActiveAtTrigger()), 5000, dt)

    if self.stoppedTimer:done() then
        self.motorShouldBeStopped = true
        if self.vehicle.spec_motorized.isMotorStarted and (not g_currentMission.missionInfo.automaticMotorStartEnabled) then
            if self.vehicle.getIsControlled == nil or self.vehicle:getIsControlled() then
                self.vehicle:stopMotor()
            end
        end
    end

    AIVehicleUtil.driveInDirection(self.vehicle, dt, 30, acc, 0.2, 20, allowedToDrive, true, lx, lz, finalSpeed, 1)
end

function ADSpecialDrivingModule:shouldStopMotor()
    return self.motorShouldBeStopped
end

function ADSpecialDrivingModule:driveForward(dt)
    local speed = 8
    local acc = 0.6

    local targetX, targetY, targetZ = localToWorld(self.vehicle.components[1].node, 0, 0, 20)
    local lx, lz = AIVehicleUtil.getDriveDirection(self.vehicle.components[1].node, targetX, targetY, targetZ)

    AIVehicleUtil.driveInDirection(self.vehicle, dt, 30, acc, 0.2, 20, true, true, lx, lz, speed, 1)
end

function ADSpecialDrivingModule:driveReverse(dt, maxSpeed, maxAcceleration)
    local speed = maxSpeed
    local acc = maxAcceleration

    local targetX, targetY, targetZ = localToWorld(self.vehicle.components[1].node, 0, 0, -20)
    local lx, lz = AIVehicleUtil.getDriveDirection(self.vehicle.components[1].node, targetX, targetY, targetZ)

    if self.vehicle.ad.collisionDetectionModule:checkReverseCollision() then
        self:stopAndHoldVehicle(dt)
    else
        local storedSmootherDriving = AutoDrive.experimentalFeatures.smootherDriving
        AutoDrive.experimentalFeatures.smootherDriving = false
        AIVehicleUtil.driveInDirection(self.vehicle, dt, 30, acc, 0.2, 20, true, false, -lx, -lz, speed, 1)
        AutoDrive.experimentalFeatures.smootherDriving = storedSmootherDriving
    end
end

function ADSpecialDrivingModule:driveToPoint(dt, point, maxFollowSpeed, checkDynamicCollision, maxAcc, maxSpeed)
    local speed = math.min(self.vehicle.ad.stateModule:getFieldSpeedLimit(), maxSpeed)
    local acc = math.min(0.75, maxAcc)

    local x, y, z = getWorldTranslation(self.vehicle.components[1].node)
    self.distanceToChasePos = MathUtil.vector2Length(x - point.x, z - point.z)

    if self.distanceToChasePos < 1.75 then
        speed = maxFollowSpeed * 1
    elseif self.distanceToChasePos < 7 then
        speed = maxFollowSpeed + self.distanceToChasePos * 1.4
    elseif self.distanceToChasePos < 20 then
        speed = maxFollowSpeed + self.distanceToChasePos * 2
    end

    --print("Targetspeed: " .. speed .. " distance: " .. self.distanceToChasePos .. " maxFollowSpeed: " .. maxFollowSpeed)

    local lx, lz = AIVehicleUtil.getDriveDirection(self.vehicle.components[1].node, point.x, point.y, point.z)

    if (checkDynamicCollision and self.vehicle.ad.collisionDetectionModule:hasDetectedObstable()) or self.vehicle.ad.sensors.frontSensor:pollInfo() then
        self:stopVehicle(lx, lz)
        self:update(dt)
    else
        -- Allow active braking if vehicle is not 'following' targetSpeed precise enough
        if (self.vehicle.lastSpeedReal * 3600) > (speed + ADSpecialDrivingModule.MAX_SPEED_DEVIATION) then
            self.acceleration = -0.6
        end
        --ADDrawingManager:addLineTask(x, y, z, point.x, point.y, point.z, 1, 0, 0)
        local storedSmootherDriving = AutoDrive.experimentalFeatures.smootherDriving
        AutoDrive.experimentalFeatures.smootherDriving = false
        AIVehicleUtil.driveInDirection(self.vehicle, dt, 30, acc, 0.2, 20, true, true, lx, lz, speed, 0.3)
        AutoDrive.experimentalFeatures.smootherDriving = storedSmootherDriving
    end
end

function ADSpecialDrivingModule:handleReverseDriving(dt)
    self.wayPoints = self.vehicle.ad.drivePathModule:getWayPoints()
    self.currentWayPointIndex = self.vehicle.ad.drivePathModule:getCurrentWayPointIndex()

    if self.vehicle.ad.trailerModule:isUnloadingToBunkerSilo() then
        if self.vehicle.ad.trailerModule:getIsBlocked(dt) then
            self:driveForward(dt)
        else
            self:stopAndHoldVehicle(dt)
        end
        self.unloadingIntoBunkerSilo = true
    else
        if self.unloadingIntoBunkerSilo then
            self.vehicle.ad.drivePathModule:reachedTarget()
        else
            if self.wayPoints == nil or self.wayPoints[self.currentWayPointIndex] == nil then
                return
            end

            self.reverseNode = self:getReverseNode()
            if self.reverseNode == nil then
                return
            end

            self.reverseTarget = self.wayPoints[self.currentWayPointIndex]

            self:getBasicStates()

            if self:checkWayPointReached() then
                return
            end

            local inBunkerSilo = AutoDrive.isVehicleInBunkerSiloArea(self.vehicle)

            if not inBunkerSilo and self.vehicle.ad.collisionDetectionModule:checkReverseCollision() then
                self:stopAndHoldVehicle(dt)
            else
                self:reverseToPoint(dt)
            end
        end
        self.unloadingIntoBunkerSilo = false
    end
end

function ADSpecialDrivingModule:getBasicStates()
    self.x, self.y, self.z = getWorldTranslation(self.vehicle:getAIVehicleDirectionNode())
    self.vehicleVecX, _, self.vehicleVecZ = localDirectionToWorld(self.vehicle:getAIVehicleDirectionNode(), 0, 0, 1)
    self.rNx, self.rNy, self.rNz = getWorldTranslation(self.reverseNode)
    self.targetX, self.targetY, self.targetZ = localToWorld(self.vehicle:getAIVehicleDirectionNode(), 0, 0, 5)
    self.trailerVecX, _, self.trailerVecZ = localDirectionToWorld(self.reverseNode, 0, 0, 1)
    self.trailerRearVecX, _, self.trailerRearVecZ = localDirectionToWorld(self.reverseNode, 0, 0, -1)
    --self.rNx, self.rNy, self.rNz = localToWorld(self.reverseNode, self.trailerRearToNode, 0, self.trailerRearToNode)
    self.vecToPoint = {x = self.reverseTarget.x - self.rNx, z = self.reverseTarget.z - self.rNz}
    self.angleToTrailer = AutoDrive.angleBetween({x = self.vehicleVecX, z = self.vehicleVecZ}, {x = self.trailerVecX, z = self.trailerVecZ})
    self.angleToPoint = AutoDrive.angleBetween({x = self.trailerRearVecX, z = self.trailerRearVecZ}, {x = self.vecToPoint.x, z = self.vecToPoint.z})
    self.steeringAngle = math.deg(math.abs(self.vehicle.rotatedTime))

    if self.reverseSolo then
        self.angleToTrailer = -math.deg(self.vehicle.rotatedTime)
    end

    self.trailerX, self.trailerY, self.trailerZ = localToWorld(self.reverseNode, 0, 0, 5)
    --ADDrawingManager:addLineTask(self.x, self.y+3, self.z, self.targetX, self.targetY+3, self.targetZ, 1, 1, 1)
    --ADDrawingManager:addLineTask(self.rNx, self.rNy + 3, self.rNz, self.trailerX, self.trailerY + 3, self.trailerZ, 1, 1, 1)
    --ADDrawingManager:addLineTask(self.reverseTarget.x, self.reverseTarget.y + 1, self.reverseTarget.z, self.trailerX, self.trailerY + 3, self.trailerZ, 1, 1, 1)
    --ADDrawingManager:addLineTask(self.rNx, self.rNy + 3, self.rNz, self.rNx, self.rNy + 5, self.rNz, 1, 1, 1)

    --print("AngleToTrailer: " .. self.angleToTrailer .. " angleToPoint: " .. self.angleToPoint)
end

function ADSpecialDrivingModule:checkWayPointReached()
    local distanceToTarget = MathUtil.vector2Length(self.reverseTarget.x - self.rNx, self.reverseTarget.z - self.rNz)
    local minDistance = 9
    local storedIndex = self.vehicle.ad.drivePathModule.currentWayPoint
    self.vehicle.ad.drivePathModule.currentWayPoint = self.vehicle.ad.drivePathModule.currentWayPoint + 1
    local reverseStart, reverseEnd = self.vehicle.ad.drivePathModule:checkForReverseSection()
    self.vehicle.ad.drivePathModule.currentWayPoint = storedIndex
    if self.reverseSolo then
        minDistance = AutoDrive.defineMinDistanceByVehicleType(self.vehicle)
    elseif self.currentWayPointIndex == #self.wayPoints then
        minDistance = 4.5
    elseif reverseEnd then
        minDistance = 3
    end
    if distanceToTarget < minDistance or math.abs(self.angleToPoint) > 80 then
        self.vehicle.ad.drivePathModule:handleReachedWayPoint()
    end
end

function ADSpecialDrivingModule:getReverseNode()
    local reverseNode
    for _, implement in pairs(self.vehicle:getAttachedImplements()) do
        if implement ~= nil and implement.object ~= nil then
            if (implement.object ~= self.vehicle or reverseNode == nil) and implement.object.spec_wheels ~= nil then
                local implementX, implementY, implementZ = getWorldTranslation(implement.object.components[1].node)
                local _, _, diffZ = worldToLocal(self.vehicle.components[1].node, implementX, implementY, implementZ)
                if diffZ < 0 then
                    reverseNode = implement.object.spec_wheels.steeringCenterNode
                    self.reverseSolo = false
                    self.trailer = implement.object
                    local trailerRearX, trailerRearY, trailerRearZ = localToWorld(self.trailer.components[1].node, 0, 0, -self.trailer.sizeLength / 2)
                    local _, _, trailerRearToNode = worldToLocal(reverseNode, trailerRearX, trailerRearY, trailerRearZ)
                    self.trailerRearToNode = trailerRearToNode
                --print("trailerRearToNode: " .. self.trailerRearToNode)
                end
            end
        end
    end
    if reverseNode == nil then
        reverseNode = self.vehicle.spec_wheels.steeringCenterNode
        self.reverseSolo = true
    end
    return reverseNode
end

function ADSpecialDrivingModule:reverseToPoint(dt)
    if self.lastAngleToPoint == nil then
        self.lastAngleToPoint = self.angleToPoint
    end
    if self.i == nil then
        self.i = 0
    end

    local delta = self.angleToPoint -- - angleToTrailer
    local p = delta
    self.i = self.i + (delta) * 0.05
    local d = delta - self.lastAngleToPoint

    self.pFactor = 6 --self.vehicle.ad.stateModule:getSpeedLimit()
    self.iFactor = 0.01
    self.dFactor = 1400 --self.vehicle.ad.stateModule:getFieldSpeedLimit() * 100

    if self.vehicle.typeDesc == "truck" then
        self.pFactor = 1 --self.vehicle.ad.stateModule:getSpeedLimit() * 0.05 --0.1 -- --0.1
        self.iFactor = 0.00001
        self.dFactor = 6.7 --self.vehicle.ad.stateModule:getFieldSpeedLimit() * 0.1 --10
    end

    local targetAngleToTrailer = math.clamp(-40, (p * self.pFactor) + (self.i * self.iFactor) + (d * self.dFactor), 40)
    local targetDiff = self.angleToTrailer - targetAngleToTrailer
    local offsetX = -targetDiff * 5
    local offsetZ = -20

    if self.vehicle.typeDesc == "truck" then
        offsetX = -targetDiff * 0.1
        offsetZ = -100
    end

    --print("p: " .. p .. " i: " .. self.i .. " d: " .. d)
    --print("p: " .. p * self.pFactor .. " i: " .. (self.i * self.iFactor) .. " d: " .. (d * self.dFactor))
    --print("targetAngleToTrailer: " .. targetAngleToTrailer .. " targetDiff: " .. targetDiff .. "  offsetX" .. offsetX)

    local speed = 5 + (6 * math.clamp(0, (5 / math.max(self.steeringAngle, math.abs(self.angleToTrailer))), 1))
    local acc = 0.4

    if self.vehicle.typeDesc == "truck" then
        speed = 4
    end

    local node = self.vehicle:getAIVehicleDirectionNode()

    local rx, _, rz = localDirectionToWorld(node, offsetX, 0, offsetZ)
    local targetX = self.x + rx
    local targetZ = self.z + rz

    if self.reverseSolo then
        targetX = self.reverseTarget.x
        targetZ = self.reverseTarget.z
    end
    local lx, lz = AIVehicleUtil.getDriveDirection(node, targetX, self.y, targetZ)
    if self.reverseSolo then
        lx = -lx
        lz = -lz
    end

    local maxAngle = 60
    if self.vehicle.maxRotation then
        if self.vehicle.maxRotation > (2 * math.pi) then
            maxAngle = self.vehicle.maxRotation
        else
            maxAngle = math.deg(self.vehicle.maxRotation)
        end
    end

    local storedSmootherDriving = AutoDrive.experimentalFeatures.smootherDriving
    AutoDrive.experimentalFeatures.smootherDriving = false
    AIVehicleUtil.driveInDirection(self.vehicle, dt, maxAngle, acc, 0.2, 20, true, false, lx, lz, speed, 1)
    AutoDrive.experimentalFeatures.smootherDriving = storedSmootherDriving

    self.lastAngleToPoint = self.angleToPoint
end
