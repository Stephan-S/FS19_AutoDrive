EmptyHarvesterTask = ADInheritsFrom(AbstractTask)

EmptyHarvesterTask.STATE_PATHPLANNING = 1
EmptyHarvesterTask.STATE_DRIVING = 2
EmptyHarvesterTask.STATE_UNLOADING = 3
EmptyHarvesterTask.STATE_REVERSING = 4
EmptyHarvesterTask.STATE_WAITING = 5

EmptyHarvesterTask.REVERSE_TIME = 7000

function EmptyHarvesterTask:new(vehicle, combine)
    local o = EmptyHarvesterTask:create()
    o.vehicle = vehicle
    o.combine = combine
    o.state = EmptyHarvesterTask.STATE_PATHPLANNING
    o.wayPoints = nil
    o.reverseStartLocation = nil
    o.waitTimer = AutoDriveTON:new()
    return o
end

function EmptyHarvesterTask:setUp()
    AutoDrive.debugPrint(self.vehicle, AutoDrive.DC_COMBINEINFO, "Setting up EmptyHarvesterTask")
    self.vehicle.ad.pathFinderModule:startPathPlanningToPipe(self.combine, false)
    self.vehicle.ad.trailerModule:reset()
end

function EmptyHarvesterTask:update(dt)
    if self.combine ~= nil and g_currentMission.nodeToObject[self.combine.components[1].node] == nil then
        self:finished()
        return
    end

    if self.state == EmptyHarvesterTask.STATE_PATHPLANNING then
        if self.vehicle.ad.pathFinderModule:hasFinished() then
            self.wayPoints = self.vehicle.ad.pathFinderModule:getPath()
            self.vehicle.ad.drivePathModule:setWayPoints(self.wayPoints)
            if self.wayPoints == nil or #self.wayPoints == 0 then
                -- If the target/pipe location is blocked, we can issue a notification and stop the task - Otherwise we pause a moment and retry
                if self.vehicle.ad.pathFinderModule:isTargetBlocked() then
                    self:finished(ADTaskModule.DONT_PROPAGATE)
                    self.vehicle:stopAutoDrive()
                    AutoDriveMessageEvent.sendMessageOrNotification(self.vehicle, ADMessagesManager.messageTypes.WARN, "$l10n_AD_Driver_of; %s $l10n_AD_cannot_find_path; %s", 5000, self.vehicle.ad.stateModule:getName(), self.combine.ad.stateModule:getName())
                else
                    self.vehicle.ad.modes[AutoDrive.MODE_UNLOAD]:notifyAboutFailedPathfinder()
                    self.vehicle.ad.pathFinderModule:startPathPlanningToPipe(self.combine, false)
                    self.vehicle.ad.pathFinderModule:addDelayTimer(10000)
                end
            else
                --AutoDrive.debugPrint(self.vehicle, AutoDrive.DC_COMBINEINFO, "EmptyHarvesterTask:update - next: EmptyHarvesterTask.STATE_DRIVING")
                self.state = EmptyHarvesterTask.STATE_DRIVING
            end
        else
            self.vehicle.ad.pathFinderModule:update(dt)
            self.vehicle.ad.specialDrivingModule:stopVehicle()
            self.vehicle.ad.specialDrivingModule:update(dt)
        end
    elseif self.state == EmptyHarvesterTask.STATE_DRIVING then
        if self.vehicle.ad.drivePathModule:isTargetReached() then
            --AutoDrive.debugPrint(self.vehicle, AutoDrive.DC_COMBINEINFO, "EmptyHarvesterTask:update - next: EmptyHarvesterTask.STATE_UNLOADING 1")
            self.state = EmptyHarvesterTask.STATE_UNLOADING
        elseif (AutoDrive.getSetting("preCallLevel", self.combine) > 50 and self.combine.getDischargeState ~= nil and self.combine:getDischargeState() ~= Dischargeable.DISCHARGE_STATE_OFF) then
            --AutoDrive.debugPrint(self.vehicle, AutoDrive.DC_COMBINEINFO, "EmptyHarvesterTask:update - next: EmptyHarvesterTask.STATE_UNLOADING 2")
            self.state = EmptyHarvesterTask.STATE_UNLOADING
        else
            self.vehicle.ad.drivePathModule:update(dt)
        end
        local trailers, _ = AutoDrive.getTrailersOf(self.vehicle, false)
        AutoDrive.setTrailerCoverOpen(self.vehicle, trailers, true)
    elseif self.state == EmptyHarvesterTask.STATE_UNLOADING then
        self.vehicle.ad.specialDrivingModule.motorShouldNotBeStopped = true
        -- Stopping CP drivers for now

        if self.combine.trailingVehicle ~= nil then
            -- harvester is trailed - CP use the trailing vehicle
            if self.combine.trailingVehicle.cp and self.combine.trailingVehicle.cp.driver and self.combine.trailingVehicle.cp.driver.holdForUnloadOrRefill then
                self.combine.trailingVehicle.cp.driver:holdForUnloadOrRefill()
            end
        else
            if self.combine.cp and self.combine.cp.driver and self.combine.cp.driver.holdForUnloadOrRefill then
                self.combine.cp.driver:holdForUnloadOrRefill()
            end
        end

        --Check if the combine is moving / has already moved away and we are supposed to actively unload
        if self.combine.ad.driveForwardTimer.elapsedTime > 100 then
            if AutoDrive.isVehicleOrTrailerInCrop(self.vehicle, true) then
                self:finished()
            elseif self.combine.ad.driveForwardTimer.elapsedTime > 4000 then
                self.vehicle.ad.modes[AutoDrive.MODE_UNLOAD].state = CombineUnloaderMode.STATE_ACTIVE_UNLOAD_COMBINE
                self.vehicle.ad.modes[AutoDrive.MODE_UNLOAD].breadCrumbs = Queue:new()
                self.vehicle.ad.modes[AutoDrive.MODE_UNLOAD].lastBreadCrumb = nil
                self.vehicle.ad.taskModule:addTask(FollowCombineTask:new(self.vehicle, self.combine))
                self.vehicle.ad.taskModule:setCurrentTaskFinished(ADTaskModule.DONT_PROPAGATE)
            end
        end

        local combineFillLevel, _ = AutoDrive.getFilteredFillLevelAndCapacityOfAllUnits(self.combine)
        if combineFillLevel > 1 and self.combine.getDischargeState ~= nil and self.combine:getDischargeState() ~= Dischargeable.DISCHARGE_STATE_OFF then
            self.vehicle.ad.specialDrivingModule:stopVehicle()
            self.vehicle.ad.specialDrivingModule:update(dt)
        else
            --Is the current trailer filled or is the combine empty?
            local trailers, _ = AutoDrive.getTrailersOf(self.vehicle, false)
            local _, leftCapacity = AutoDrive.getFillLevelAndCapacityOfAll(trailers)
            local distanceToCombine = AutoDrive.getDistanceBetween(self.vehicle, self.combine)

            if combineFillLevel <= 0.1 or leftCapacity <= 0.1 then
                local x, y, z = getWorldTranslation(self.vehicle.components[1].node)
                self.reverseStartLocation = {x = x, y = y, z = z}
                AutoDrive.debugPrint(self.vehicle, AutoDrive.DC_COMBINEINFO, "EmptyHarvesterTask:update - next: EmptyHarvesterTask.STATE_REVERSING")
                self.state = EmptyHarvesterTask.STATE_REVERSING
            else
                -- Drive forward with collision checks active and only for a limited distance
                if distanceToCombine > 30 then
                    self:finished()
                else
                    self.vehicle.ad.specialDrivingModule:driveForward(dt)
                end
            end
        end
    elseif self.state == EmptyHarvesterTask.STATE_REVERSING then
        self.vehicle.ad.specialDrivingModule.motorShouldNotBeStopped = false
        local x, y, z = getWorldTranslation(self.vehicle.components[1].node)
        local distanceToReversStart = MathUtil.vector2Length(x - self.reverseStartLocation.x, z - self.reverseStartLocation.z)
        local  _,trailercount = AutoDrive.getTrailersOf(self.vehicle, false)
        local overallLength
        if trailercount <= 1 then
            overallLength = self.vehicle.sizeLength * 2 -- 2x tractor length
        else
            overallLength = AutoDrive.getTractorTrainLength(self.vehicle, true, true) -- complete train length
        end
        if self.combine.trailingVehicle ~= nil then
            -- if the harvester is trailed reverse 5m more
            -- overallLength = overallLength + 5
        end
        if distanceToReversStart > overallLength then
            AutoDrive.debugPrint(self.vehicle, AutoDrive.DC_COMBINEINFO, "EmptyHarvesterTask:update - next: EmptyHarvesterTask.STATE_WAITING")
            self.state = EmptyHarvesterTask.STATE_WAITING
        else
            self.vehicle.ad.specialDrivingModule:driveReverse(dt, 5, 1)
        end
    elseif self.state == EmptyHarvesterTask.STATE_WAITING then
        self.waitTimer:timer(true, EmptyHarvesterTask.REVERSE_TIME, dt)
        if self.waitTimer:done() then
            self:finished()
        else
            self.vehicle.ad.specialDrivingModule:stopVehicle()
            self.vehicle.ad.specialDrivingModule:update(dt)
        end
    end
end

function EmptyHarvesterTask:abort()
end

function EmptyHarvesterTask:finished(propagate)
    AutoDrive.debugPrint(self.vehicle, AutoDrive.DC_COMBINEINFO, "EmptyHarvesterTask:finished()")
    self.vehicle.ad.specialDrivingModule.motorShouldNotBeStopped = false
    self.vehicle.ad.taskModule:setCurrentTaskFinished(propagate)
end

function EmptyHarvesterTask:getExcludedVehiclesForCollisionCheck()
    local excludedVehicles = {}
    if self.state == EmptyHarvesterTask.STATE_DRIVING then
        table.insert(excludedVehicles, self.combine)
    end
    return excludedVehicles
end

function EmptyHarvesterTask:getInfoText()
    if self.state == EmptyHarvesterTask.STATE_PATHPLANNING then
        local actualState, maxStates = self.vehicle.ad.pathFinderModule:getCurrentState()
        return g_i18n:getText("AD_task_pathfinding") .. string.format(" %d / %d ", actualState, maxStates)
    elseif self.state == EmptyHarvesterTask.STATE_DRIVING then
        return g_i18n:getText("AD_task_drive_to_combine_pipe")
    elseif self.state == EmptyHarvesterTask.STATE_UNLOADING then
        return g_i18n:getText("AD_task_unloading_combine")
    elseif self.state == EmptyHarvesterTask.STATE_REVERSING then
        return g_i18n:getText("AD_task_reversing_from_combine")
    elseif self.state == EmptyHarvesterTask.STATE_WAITING then
        return g_i18n:getText("AD_task_waiting_for_room")
    else
        return g_i18n:getText("AD_task_unloading_combine")
    end
end

function EmptyHarvesterTask:getI18nInfo()
    if self.state == EmptyHarvesterTask.STATE_PATHPLANNING then
        local actualState, maxStates = self.vehicle.ad.pathFinderModule:getCurrentState()
        return "$l10n_AD_task_pathfinding;" .. string.format(" %d / %d ", actualState, maxStates)
    elseif self.state == EmptyHarvesterTask.STATE_DRIVING then
        return "$l10n_AD_task_drive_to_combine_pipe;"
    elseif self.state == EmptyHarvesterTask.STATE_UNLOADING then
        return "$l10n_AD_task_unloading_combine;"
    elseif self.state == EmptyHarvesterTask.STATE_REVERSING then
        return "$l10n_AD_task_reversing_from_combine;"
    elseif self.state == EmptyHarvesterTask.STATE_WAITING then
        return "$l10n_AD_task_waiting_for_room;"
    else
        return "$l10n_AD_task_unloading_combine;"
    end
end
