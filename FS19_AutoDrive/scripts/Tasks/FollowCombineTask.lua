FollowCombineTask = ADInheritsFrom(AbstractTask)

FollowCombineTask.STATE_CHASING = 1
FollowCombineTask.STATE_REVERSING = 2

function FollowCombineTask:new(vehicle, combine)
    local o = FollowCombineTask:create()
    o.vehicle = vehicle
    o.combine = combine
    o.state = FollowCombineTask.STATE_CHASING
    o.reverseStartLocation = nil
    return o
end

function FollowCombineTask:setUp()
    AutoDrive.debugPrint(vehicle, AutoDrive.DC_COMBINEINFO, "Setting up FollowCombineTask")
end

function FollowCombineTask:update(dt)
    self:updateStates()
    if self.filled or self.combine.ad.noMovementTimer.elapsedTime > 5000 then
        self:finished()
        return
    end
    
    if self.state == FollowCombineTask.STATE_CHASING then
        if self:combineIsTurning() then
            print("combineIsTurning - reversing now")
            self.state = FollowCombineTask.STATE_REVERSING
        else
            self:followChasePoint(dt)
        end
    elseif self.state == FollowCombineTask.STATE_REVERSING then
        if self.distanceToCombine < ((self.vehicle.sizeLength + self.combine.sizeLength)/2 + 4) then
            self:reverse(dt)
        else
            self.vehicle.ad.specialDrivingModule:stopVehicle()
            self.vehicle.ad.specialDrivingModule:update(dt)
        end
        if not self:combineIsTurning() then
            self:finished()
        end
        if self.filledToUnload then
            self:finished()
            return
        end
    end
end

function FollowCombineTask:updateStates()
    local x, y, z = getWorldTranslation(self.vehicle.components[1].node)
    local cx, cy, cz = getWorldTranslation(self.combine.components[1].node)
    self.angleToCombine = self.vehicle.ad.modes[AutoDrive.MODE_UNLOAD]:getAngleToCombineHeading()
    --local isChopper = combine:getIsBufferCombine()
    self.leftBlocked = self.combine.ad.sensors.leftSensorFruit:pollInfo()   or self.combine.ad.sensors.leftSensor:pollInfo()  or (not self.combine.ad.sensors.leftSensorField:pollInfo())
    self.rightBlocked = self.combine.ad.sensors.rightSensorFruit:pollInfo() or self.combine.ad.sensors.rightSensor:pollInfo() or (not self.combine.ad.sensors.rightSensorField:pollInfo())

    --start looking ahead a little if both sides are free currently
    self.frontLeftBlocked = self.combine.ad.sensors.leftFrontSensorFruit:pollInfo()
    self.frontRightBlocked = self.combine.ad.sensors.rightFrontSensorFruit:pollInfo()
    if (not self.leftBlocked) and (not self.rightBlocked) then
        if self.frontLeftBlocked then
            self.leftBlocked = true
        elseif self.frontRightBlocked then
            self.rightBlocked = true
        end
    end

    self.chasePos, self.chaseSide = self.vehicle.ad.modes[AutoDrive.MODE_UNLOAD]:getPipeChasePosition()
    self.distanceToCombine = MathUtil.vector2Length(x - cx, z - cz)
    self.distanceToChasePos = MathUtil.vector2Length(x - self.chasePos.x, z - self.chasePos.z)

    self.cfillLevel, self.cleftCapacity = AutoDrive.getFilteredFillLevelAndCapacityOfAllUnits(self.combine)
    self.cmaxCapacity = self.cfillLevel + self.cleftCapacity
    self.combineFillLevel = (self.cfillLevel / self.cmaxCapacity)
    
    local trailers, _ = AutoDrive.getTrailersOf(self.vehicle, false)
    local fillLevel, leftCapacity = AutoDrive.getFillLevelAndCapacityOfAll(trailers)
    local maxCapacity = fillLevel + leftCapacity
    self.filledToUnload = (leftCapacity <= (maxCapacity * (1 - AutoDrive.getSetting("unloadFillLevel", self.vehicle) + 0.001)))
    self.filled = leftCapacity <= 1
end

function FollowCombineTask:combineIsTurning()
    local cpIsTurning = self.combine.cp ~= nil and (self.combine.cp.isTurning or (self.combine.cp.turnStage ~= nil and self.combine.cp.turnStage > 0))
    local cpIsTurningTwo = self.combine.cp ~= nil and self.combine.cp.driver and (self.combine.cp.driver.turnIsDriving or (self.combine.cp.driver.fieldworkState ~= nil and self.combine.cp.driver.fieldworkState == self.combine.cp.driver.states.TURNING))
    local aiIsTurning = (self.combine.getAIIsTurning ~= nil and self.combine:getAIIsTurning() == true)
    local combineSteering = self.combine.rotatedTime ~= nil and (math.deg(self.combine.rotatedTime) > 20);
    local combineIsTurning = cpIsTurning or cpIsTurningTwo or aiIsTurning or combineSteering
    --print("cpIsTurning: " .. AutoDrive.boolToString(cpIsTurning) .. " cpIsTurning2: " .. AutoDrive.boolToString(cpIsTurningTwo) .. " aiIsTurning: " .. AutoDrive.boolToString(aiIsTurning) .. " combineSteering: " .. AutoDrive.boolToString(combineSteering) .. " combine.ad.driveForwardTimer:done(): " .. AutoDrive.boolToString(self.combine.ad.driveForwardTimer:done()) .. " noTurningTimer: " .. AutoDrive.boolToString(self.combine.ad.noTurningTimer:done()) .. " vehicle no movement: " .. self.vehicle.ad.noMovementTimer.elapsedTime);
    if ((self.combine:getIsBufferCombine() and self.combine.ad.noTurningTimer:done()) or (self.combine.ad.driveForwardTimer:done() and (not self.combine:getIsBufferCombine()))) and (not combineIsTurning) then
        return false
    end
    return true
end

function FollowCombineTask:reverse(dt)
    self.vehicle.ad.specialDrivingModule:driveReverse(dt, 15, 1)
end

function FollowCombineTask:followChasePoint(dt)
    if self:shouldWaitForChasePos() then
        print("Should wait for chase pos")
        self.vehicle.ad.specialDrivingModule:stopVehicle()
        self.vehicle.ad.specialDrivingModule:update(dt)
    else
        local combineSpeed = self.combine.lastSpeedReal * 3600
        self.vehicle.ad.specialDrivingModule:driveToPoint(dt, self.chasePos, combineSpeed)
    end
end

function FollowCombineTask:shouldWaitForChasePos()
    return self:getAngleToChasePos() > 50 or (not self.combine.ad.sensors.frontSensorFruit:pollInfo())
end

function FollowCombineTask:getAngleToChasePos()
    local worldX, _, worldZ = getWorldTranslation(self.vehicle.components[1].node)
    local rx, _, rz = localDirectionToWorld(self.vehicle.components[1].node, 0, 0, 1)

    return math.abs(AutoDrive.angleBetween({x = rx, z = rz}, {x = self.chasePos.x - worldX, z = self.chasePos.z - worldZ}))
end

function FollowCombineTask:abort()
end

function FollowCombineTask:finished()
    AutoDrive.debugPrint(vehicle, AutoDrive.DC_COMBINEINFO, "FollowCombineTask:finished()")
    self.vehicle.ad.taskModule:setCurrentTaskFinished()
end
