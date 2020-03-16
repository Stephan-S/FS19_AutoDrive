FollowCombineTask = ADInheritsFrom(AbstractTask)

FollowCombineTask.STATE_CHASING = 1
FollowCombineTask.STATE_WAIT_FOR_TURN = 2
FollowCombineTask.STATE_REVERSING = 3
FollowCombineTask.STATE_WAIT_FOR_PASS_BY = 4

function FollowCombineTask:new(vehicle, combine)
    local o = FollowCombineTask:create()
    o.vehicle = vehicle
    o.combine = combine
    o.state = FollowCombineTask.STATE_CHASING
    o.reverseStartLocation = nil
    o.angleWrongTimer = AutoDriveTON:new()
    o.caughtCurrentChaseSide = false
    o.lastChaseSide = -1
    o.waitForPassByTimer = AutoDriveTON:new()
    return o
end

function FollowCombineTask:setUp()
    AutoDrive.debugPrint(self.vehicle, AutoDrive.DC_COMBINEINFO, "Setting up FollowCombineTask")
end

function FollowCombineTask:update(dt)
    self:updateStates()
    if self.filled or (self.combine.ad.noMovementTimer.elapsedTime > 5000 and not self.combine:getIsBufferCombine()) then
        if self.state ~= FollowCombineTask.STATE_REVERSING then
            local x, y, z = getWorldTranslation(self.vehicle.components[1].node)
            self.reverseStartLocation = {x = x, y = y, z = z}
            self.state = FollowCombineTask.STATE_REVERSING
        end
    end

    if self.state == FollowCombineTask.STATE_CHASING then
        if AutoDrive.combineIsTurning(self.combine) then
            self.state = FollowCombineTask.STATE_WAIT_FOR_TURN
        else
            self:followChasePoint(dt)
        end
    elseif self.state == FollowCombineTask.STATE_WAIT_FOR_TURN then
        if self.distanceToCombine < ((self.vehicle.sizeLength + self.combine.sizeLength) / 2 + 2) then
            self:reverse(dt)
        else
            self.vehicle.ad.specialDrivingModule:stopVehicle()
            self.vehicle.ad.specialDrivingModule:update(dt)
        end
        if not AutoDrive.combineIsTurning(self.combine) then
            self:finished()
        end
        if self.filledToUnload then
            self:finished()
            return
        end
    elseif self.state == FollowCombineTask.STATE_WAIT_FOR_PASS_BY then
        self.waitForPassByTimer:timer(true, 5000, dt)
        self.vehicle.ad.specialDrivingModule:stopVehicle()
        self.vehicle.ad.specialDrivingModule:update(dt)
        if self.waitForPassByTimer:done() then
            self.state = FollowCombineTask.STATE_CHASING
            self.waitForPassByTimer:timer(false)
        end
    elseif self.state == FollowCombineTask.STATE_REVERSING then
        local x, y, z = getWorldTranslation(self.vehicle.components[1].node)
        local distanceToReversStart = MathUtil.vector2Length(x - self.reverseStartLocation.x, z - self.reverseStartLocation.z)
        if distanceToReversStart > 25 then
            self:finished()
        else
            self.vehicle.ad.specialDrivingModule:driveReverse(dt, 15, 1)
        end
    end
end

function FollowCombineTask:updateStates()
    local x, y, z = getWorldTranslation(self.vehicle.components[1].node)
    local cx, cy, cz = getWorldTranslation(self.combine.components[1].node)
    self.angleToCombine = self.vehicle.ad.modes[AutoDrive.MODE_UNLOAD]:getAngleToCombineHeading()
    --local isChopper = combine:getIsBufferCombine()
    self.leftBlocked = self.combine.ad.sensors.leftSensorFruit:pollInfo() or self.combine.ad.sensors.leftSensor:pollInfo() or (not self.combine.ad.sensors.leftSensorField:pollInfo())
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
    if self.chaseSide ~= self.lastChaseSide then
        if self.lastChaseSide ~= -1 then
            self.state = FollowCombineTask.STATE_WAIT_FOR_PASS_BY
        end
        self.caughtCurrentChaseSide = false
        self.lastChaseSide = self.chaseSide
    end
    -- If we haven't caught up with the current chaseSide, we put the target ahead of it, so the unloader will get muche closer to the combine for these changes and won't cause the combine to stop due to the pipe distance
    if self.chaseSide == CombineUnloaderMode.CHASEPOS_REAR and not self.caughtCurrentChaseSide then
        self.chasePos = AutoDrive.createWayPointRelativeToVehicle(self.combine, 0, 3)
    end
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
    local combineSteering = self.combine.rotatedTime ~= nil and (math.deg(self.combine.rotatedTime) > 30)
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
    if self:shouldWaitForChasePos(dt) then
        self.vehicle.ad.specialDrivingModule:stopVehicle()
        self.vehicle.ad.specialDrivingModule:update(dt)
    else
        local combineSpeed = self.combine.lastSpeedReal * 3600
        local dynamicCollisionWindow = not self.caughtCurrentChaseSide
        self.vehicle.ad.specialDrivingModule:driveToPoint(dt, self.chasePos, combineSpeed, dynamicCollisionWindow)
    end
end

function FollowCombineTask:shouldWaitForChasePos(dt)
    self:getAngleToChasePos(dt)
    return self.angleWrongTimer:done() or (not self.combine.ad.sensors.frontSensorFruit:pollInfo())
end

function FollowCombineTask:getAngleToChasePos(dt)
    local worldX, _, worldZ = getWorldTranslation(self.vehicle.components[1].node)
    local rx, _, rz = localDirectionToWorld(self.vehicle.components[1].node, 0, 0, 1)
    local angle = math.abs(AutoDrive.angleBetween({x = rx, z = rz}, {x = self.chasePos.x - worldX, z = self.chasePos.z - worldZ}))
    self.angleWrongTimer:timer(angle > 50, 3000, dt)

    if angle < 15 then
        self.caughtCurrentChaseSide = true
    end

    return angle
end

function FollowCombineTask:abort()
end

function FollowCombineTask:finished()
    AutoDrive.debugPrint(self.vehicle, AutoDrive.DC_COMBINEINFO, "FollowCombineTask:finished()")
    self.vehicle.ad.taskModule:setCurrentTaskFinished()
end

function FollowCombineTask:getExcludedVehiclesForCollisionCheck()
    local excludedVehicles = {}
    if self.state == FollowCombineTask.STATE_CHASING then --and self.chaseSide == CombineUnloaderMode.CHASEPOS_REAR and self:getAngleToChasePos(0) < 15 then
        table.insert(excludedVehicles, self.combine)
    end
    return excludedVehicles
end

function FollowCombineTask:getInfoText()
    local text = ""
    if self.state == FollowCombineTask.STATE_CHASING then
        text = g_i18n:getText("AD_task_chasing_combine") .. "-"
        if not self.caughtCurrentChaseSide then
            text = text .. g_i18n:getText("AD_task_catching_chase_side") .. ": "
        else
            text = text .. g_i18n:getText("AD_task_chase_side") .. ": "
        end
        if self.chaseSide == CombineUnloaderMode.CHASEPOS_LEFT then
            text = text .. g_i18n:getText("AD_task_chase_side_left")
        elseif self.chaseSide == CombineUnloaderMode.CHASEPOS_REAR then
            text = text .. g_i18n:getText("AD_task_chase_side_rear")
        elseif self.chaseSide == CombineUnloaderMode.CHASEPOS_RIGHT then
            text = text .. g_i18n:getText("AD_task_chase_side_right")
        end
    elseif self.state == FollowCombineTask.STATE_WAIT_FOR_TURN then
        text = g_i18n:getText("AD_task_wait_for_combine_turn")
    elseif self.state == FollowCombineTask.STATE_REVERSING then
        text = g_i18n:getText("AD_task_reversing_from_combine")
    elseif self.state == FollowCombineTask.STATE_WAIT_FOR_PASS_BY then
        text = g_i18n:getText("AD_task_wait_for_combine_pass_by")
    end

    return text
end
