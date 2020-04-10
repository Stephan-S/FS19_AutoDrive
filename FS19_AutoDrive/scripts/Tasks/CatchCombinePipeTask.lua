CatchCombinePipeTask = ADInheritsFrom(AbstractTask)

CatchCombinePipeTask.TARGET_DISTANCE = 15

CatchCombinePipeTask.STATE_PATHPLANNING = 1
CatchCombinePipeTask.STATE_DRIVING = 2
CatchCombinePipeTask.STATE_REVERSING = 3

CatchCombinePipeTask.MAX_REVERSE_DISTANCE = 18
CatchCombinePipeTask.MIN_COMBINE_DISTANCE = 25
CatchCombinePipeTask.MAX_REVERSE_TIME = 5000

function CatchCombinePipeTask:new(vehicle, combine)
    local o = CatchCombinePipeTask:create()
    o.vehicle = vehicle
    o.combine = combine
    o.state = CatchCombinePipeTask.STATE_PATHPLANNING
    o.wayPoints = nil
    o.stuckTimer = AutoDriveTON:new()
    o.reverseTimer = AutoDriveTON:new()
    return o
end

function CatchCombinePipeTask:setUp()
    AutoDrive.debugPrint(self.vehicle, AutoDrive.DC_COMBINEINFO, "CatchCombinePipeTask:setUp()")
    local angleToCombineHeading = self.vehicle.ad.modes[AutoDrive.MODE_UNLOAD]:getAngleToCombineHeading()
    local angleToCombine = self.vehicle.ad.modes[AutoDrive.MODE_UNLOAD]:getAngleToCombine()

    if angleToCombineHeading < 35 and angleToCombine < 90 and AutoDrive.getDistanceBetween(self.vehicle, self.combine) < 60 then
        self:finished()
    else
        self:startNewPathFinding()
    end
end

function CatchCombinePipeTask:update(dt)
    --abort if the combine is nearing it's fill level and we should take care of 'real' approaches when it's in stand still
    local cfillLevel, cleftCapacity = AutoDrive.getFilteredFillLevelAndCapacityOfAllUnits(self.combine)
    if (self.combine.getIsBufferCombine == nil or not self.combine:getIsBufferCombine()) and (self.combine.ad.noMovementTimer.elapsedTime > 2000 or cleftCapacity < 1.0) then
        self:finished()
    end

    if self.combine ~= nil and g_currentMission.nodeToObject[self.combine.components[1].node] == nil then
        self:finished()
        return
    end

    if self.state == CatchCombinePipeTask.STATE_PATHPLANNING then
        if self.vehicle.ad.pathFinderModule:hasFinished() then
            AutoDrive.debugPrint(self.vehicle, AutoDrive.DC_COMBINEINFO, "CatchCombinePipeTask:update - STATE_PATHPLANNING finished")
            self.wayPoints = self.vehicle.ad.pathFinderModule:getPath()
            if self.wayPoints == nil or #self.wayPoints < 1 then
                --restart
                AutoDriveMessageEvent.sendMessageOrNotification(self.vehicle, ADMessagesManager.messageTypes.WARN, "$l10n_AD_Driver_of; %s $l10n_AD_cannot_find_path; %s", 5000, self.vehicle.ad.stateModule:getName(), self.combine.ad.stateModule:getName())
                AutoDrive.debugPrint(self.vehicle, AutoDrive.DC_COMBINEINFO, "CatchCombinePipeTask:update - STATE_PATHPLANNING restarting path finder - with delay 10000")
                self:startNewPathFinding()
                self.vehicle.ad.pathFinderModule:addDelayTimer(10000)
            else
                self.vehicle.ad.drivePathModule:setWayPoints(self.wayPoints)
                self.state = CatchCombinePipeTask.STATE_DRIVING
            end
        else
            self.vehicle.ad.pathFinderModule:update(dt)
            self.vehicle.ad.specialDrivingModule:stopVehicle()
            self.vehicle.ad.specialDrivingModule:update(dt)
        end
    elseif self.state == CatchCombinePipeTask.STATE_DRIVING then
        -- check if this is still a clever path to follow
        -- do this by distance of the combine to the last location pathfinder started at
        local x, y, z = getWorldTranslation(self.combine.components[1].node)
        local combineTravelDistance = MathUtil.vector2Length(x - self.combinesStartLocation.x, z - self.combinesStartLocation.z)
        self.stuckTimer:timer(true, 60000, dt)
        if self.vehicle.ad.drivePathModule:isTargetReached() or AutoDrive.getDistanceBetween(self.vehicle, self.combine) > self.MIN_COMBINE_DISTANCE then
            self.stuckTimer:timer(false)
        elseif self.stuckTimer:done() then
            self.stuckTimer:timer(false)
            local x, y, z = getWorldTranslation(self.vehicle.components[1].node)
            self.reverseStartLocation = {x = x, y = y, z = z}
            self.state = CatchCombinePipeTask.STATE_REVERSING
        end
        if combineTravelDistance > 65 then
            AutoDrive.debugPrint(self.vehicle, AutoDrive.DC_COMBINEINFO, "CatchCombinePipeTask:update - combine travelled - recalculate path")
            self:startNewPathFinding()
            self.state = CatchCombinePipeTask.STATE_PATHPLANNING
        else
            if self.vehicle.ad.drivePathModule:isTargetReached() then
                -- check if we have actually reached the target or not
                -- accept current location if we are in a good position to start chasing: distance and angle are important here
                local angleToCombine = self.vehicle.ad.modes[AutoDrive.MODE_UNLOAD]:getAngleToCombineHeading()
                local isCorrectSide = self.vehicle.ad.modes[AutoDrive.MODE_UNLOAD]:isUnloaderOnCorrectSide()

                if angleToCombine < 35 and AutoDrive.getDistanceBetween(self.vehicle, self.combine) < 60
                   and isCorrectSide then
                    self:finished()
                else
                    AutoDrive.debugPrint(self.vehicle, AutoDrive.DC_COMBINEINFO, "CatchCombinePipeTask:update - angle or distance to combine too high - recalculate path now")
                    self:startNewPathFinding()
                    self.state = CatchCombinePipeTask.STATE_PATHPLANNING
                end
            else
                self.vehicle.ad.drivePathModule:update(dt)
            end
        end
    elseif self.state == FollowCombineTask.STATE_REVERSING then
        local x, y, z = getWorldTranslation(self.vehicle.components[1].node)
        local distanceToReverseStart = MathUtil.vector2Length(x - self.reverseStartLocation.x, z - self.reverseStartLocation.z)
        self.reverseTimer:timer(true, self.MAX_REVERSE_TIME, dt)
        if distanceToReverseStart > self.MAX_REVERSE_DISTANCE or self.reverseTimer:done() then
            self.reverseTimer:timer(false)
            self:startNewPathFinding()
            self.state = CatchCombinePipeTask.STATE_PATHPLANNING
        else
            self.vehicle.ad.specialDrivingModule:driveReverse(dt, 15, 1)
        end
    end
end

function CatchCombinePipeTask:abort()
end

function CatchCombinePipeTask:finished()
    AutoDrive.debugPrint(self.vehicle, AutoDrive.DC_COMBINEINFO, "CatchCombinePipeTask:update - finished")
    self.vehicle.ad.taskModule:setCurrentTaskFinished()
end

function CatchCombinePipeTask:startNewPathFinding()
    self.vehicle.ad.pathFinderModule:startPathPlanningToPipe(self.combine, (not self.combine:getIsBufferCombine() and self.combine.lastSpeedReal > 0.002))
    self.combinesStartLocation = {}
    self.combinesStartLocation.x, self.combinesStartLocation.y, self.combinesStartLocation.z = getWorldTranslation(self.combine.components[1].node)
end

function CatchCombinePipeTask:getInfoText()
    if self.state == CatchCombinePipeTask.STATE_PATHPLANNING then
        return g_i18n:getText("AD_task_pathfinding")
    else
        return g_i18n:getText("AD_task_catch_up_with_combine")
    end
end

function CatchCombinePipeTask:getI18nInfo()
    if self.state == CatchCombinePipeTask.STATE_PATHPLANNING then
        return "$l10n_AD_task_pathfinding;"
    else
        return "$l10n_AD_task_catch_up_with_combine;"
    end
end
