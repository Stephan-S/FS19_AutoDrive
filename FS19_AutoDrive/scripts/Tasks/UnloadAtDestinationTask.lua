UnloadAtDestinationTask = ADInheritsFrom(AbstractTask)

UnloadAtDestinationTask.STATE_PATHPLANNING = 1
UnloadAtDestinationTask.STATE_DRIVING = 2

function UnloadAtDestinationTask:new(vehicle, destinationID)
    local o = UnloadAtDestinationTask:create()
    o.vehicle = vehicle
    o.destinationID = destinationID
    o.isContinued = false
    return o
end

function UnloadAtDestinationTask:setUp()
    if ADGraphManager:getDistanceFromNetwork(self.vehicle) > 30 then
        self.state = UnloadAtDestinationTask.STATE_PATHPLANNING
        if self.vehicle.ad.callBackFunction ~= nil then
            if self.vehicle.ad.stateModule:getMode() == AutoDrive.MODE_PICKUPANDDELIVER then
                self.vehicle.ad.pathFinderModule:startPathPlanningToWayPoint(self.vehicle.ad.stateModule:getFirstWayPoint(), self.destinationID)
            else
                self.vehicle.ad.pathFinderModule:startPathPlanningToWayPoint(self.vehicle.ad.stateModule:getSecondWayPoint(), self.destinationID)
            end
        else
            self.vehicle.ad.pathFinderModule:startPathPlanningToNetwork(self.destinationID)
        end
    else
        self.state = UnloadAtDestinationTask.STATE_DRIVING
        self.vehicle.ad.drivePathModule:setPathTo(self.destinationID)
    end
    self.vehicle.ad.trailerModule:reset()
end

function UnloadAtDestinationTask:update(dt)
    if self.state == UnloadAtDestinationTask.STATE_PATHPLANNING then
        if self.vehicle.ad.pathFinderModule:hasFinished() then
            self.wayPoints = self.vehicle.ad.pathFinderModule:getPath()
            if self.wayPoints == nil or #self.wayPoints == 0 then
                if self.vehicle.ad.pathFinderModule:isTargetBlocked() then
                    -- If the selected field exit isn't reachable, try the closest one                    
                    self.vehicle.ad.pathFinderModule:startPathPlanningToNetwork(self.vehicle.ad.stateModule:getSecondWayPoint())
                elseif self.vehicle.ad.pathFinderModule:timedOut() or self.vehicle.ad.pathFinderModule:isBlocked() then
                    -- Add some delay to give the situation some room to clear itself
                    self.vehicle.ad.modes[AutoDrive.MODE_UNLOAD]:notifyAboutFailedPathfinder()
                    self.vehicle.ad.pathFinderModule:startPathPlanningToNetwork(self.vehicle.ad.stateModule:getSecondWayPoint())
                    self.vehicle.ad.pathFinderModule:addDelayTimer(10000)
                else
                    self.vehicle.ad.pathFinderModule:startPathPlanningToNetwork(self.vehicle.ad.stateModule:getSecondWayPoint())
                end

                g_logManager:error("[AutoDrive] Could not calculate path - shutting down")
                self.vehicle.ad.taskModule:abortAllTasks()
                self.vehicle:stopAutoDrive()
                AutoDriveMessageEvent.sendMessageOrNotification(self.vehicle, ADMessagesManager.messageTypes.ERROR, "$l10n_AD_Driver_of; %s $l10n_AD_cannot_find_path;", 5000, self.vehicle.ad.stateModule:getName())
            else
                self.vehicle.ad.drivePathModule:setWayPoints(self.wayPoints)
                --self.vehicle.ad.drivePathModule:appendPathTo(self.wayPoints[#self.wayPoints], self.destinationID)
                self.state = UnloadAtDestinationTask.STATE_DRIVING
            end
        else
            self.vehicle.ad.pathFinderModule:update(dt)
            self.vehicle.ad.specialDrivingModule:stopVehicle()
            self.vehicle.ad.specialDrivingModule:update(dt)
        end
    else
        if not self.isContinued then
            self.vehicle.ad.trailerModule:update(dt)
        end
        if self.vehicle.ad.drivePathModule:isTargetReached() then
            AutoDrive.debugPrint(self.vehicle, AutoDrive.DC_PATHINFO, "[AD] UnloadAtDestinationTask:update isTargetReached")
            if not self.vehicle.ad.trailerModule:isActiveAtTrigger() then
                AutoDrive.debugPrint(self.vehicle, AutoDrive.DC_PATHINFO, "[AD] UnloadAtDestinationTask:update isTargetReached isActiveAtTrigger")
                local trailers, _ = AutoDrive.getTrailersOf(self.vehicle, false)
                AutoDrive.setTrailerCoverOpen(self.vehicle, trailers, true)
                local fillLevel, _ = AutoDrive.getFillLevelAndCapacityOfAll(trailers)
                if fillLevel <= 1 or self.isContinued or (((AutoDrive.getSetting("rotateTargets", self.vehicle) == AutoDrive.RT_ONLYDELIVER or AutoDrive.getSetting("rotateTargets", self.vehicle) == AutoDrive.RT_PICKUPANDDELIVER) and AutoDrive.getSetting("useFolders")) and (not ((self.vehicle.ad.drivePathModule:getIsReversing() and self.vehicle.ad.trailerModule:getBunkerTrigger() ~= nil)))) then
                    AutoDrive.debugPrint(self.vehicle, AutoDrive.DC_VEHICLEINFO, "[AD] UnloadAtDestinationTask:update fillLevel <= 1")
                    AutoDrive.setAugerPipeOpen(trailers, false)
                    self:finished()
                else
                    AutoDrive.debugPrint(self.vehicle, AutoDrive.DC_PATHINFO, "[AD] UnloadAtDestinationTask:update Wait at unload point until unloaded somehow")
                    -- Wait at unload point until unloaded somehow
                    self.vehicle.ad.specialDrivingModule:stopVehicle()
                    self.vehicle.ad.specialDrivingModule:update(dt)
                end
            else
                AutoDrive.debugPrint(self.vehicle, AutoDrive.DC_PATHINFO, "[AD] UnloadAtDestinationTask:update isTargetReached NOT isActiveAtTrigger")
                if self.vehicle.ad.trailerModule:isUnloadingToBunkerSilo() then
                    AutoDrive.debugPrint(self.vehicle, AutoDrive.DC_PATHINFO, "[AD] UnloadAtDestinationTask:update isTargetReached NOT isActiveAtTrigger isUnloadingToBunkerSilo")
                    self.vehicle.ad.drivePathModule:update(dt)
                else
                    AutoDrive.debugPrint(self.vehicle, AutoDrive.DC_PATHINFO, "[AD] UnloadAtDestinationTask:update isTargetReached NOT isActiveAtTrigger stopVehicle")
                    self.vehicle.ad.specialDrivingModule:stopVehicle()
                    self.vehicle.ad.specialDrivingModule:update(dt)
                end
            end
        else
            if self.vehicle.ad.trailerModule:isActiveAtTrigger() then
                AutoDrive.debugPrint(self.vehicle, AutoDrive.DC_PATHINFO, "[AD] UnloadAtDestinationTask:update isActiveAtTrigger")
                if self.vehicle.ad.trailerModule:isUnloadingToBunkerSilo() then
                    AutoDrive.debugPrint(self.vehicle, AutoDrive.DC_PATHINFO, "[AD] UnloadAtDestinationTask:update isActiveAtTrigger isUnloadingToBunkerSilo")
                    self.vehicle.ad.drivePathModule:update(dt)
                else
                    AutoDrive.debugPrint(self.vehicle, AutoDrive.DC_PATHINFO, "[AD] UnloadAtDestinationTask:update isActiveAtTrigger stopVehicle")
                    self.vehicle.ad.specialDrivingModule:stopVehicle()
                    self.vehicle.ad.specialDrivingModule:update(dt)
                end
            else
                AutoDrive.debugPrint(self.vehicle, AutoDrive.DC_PATHINFO, "[AD] UnloadAtDestinationTask:update isActiveAtTrigger drivePathModule:update")
                self.vehicle.ad.drivePathModule:update(dt)
            end
        end
    end
end

function UnloadAtDestinationTask:abort()
end

function UnloadAtDestinationTask:continue()
    if self.vehicle.ad.trailerModule:isActiveAtTrigger() then
        self.vehicle.ad.trailerModule:stopUnloading()
    end
    self.isContinued = true
end

function UnloadAtDestinationTask:finished()
    self.vehicle.ad.taskModule:setCurrentTaskFinished()
end

function UnloadAtDestinationTask:getInfoText()
    if self.state == UnloadAtDestinationTask.STATE_PATHPLANNING then
        local actualState, maxStates = self.vehicle.ad.pathFinderModule:getCurrentState()
        return g_i18n:getText("AD_task_pathfinding") .. string.format(" %d / %d ", actualState, maxStates)
    else
        return g_i18n:getText("AD_task_drive_to_unload_point")
    end
end

function UnloadAtDestinationTask:getI18nInfo()
    if self.state == UnloadAtDestinationTask.STATE_PATHPLANNING then
        local actualState, maxStates = self.vehicle.ad.pathFinderModule:getCurrentState()
        return "$l10n_AD_task_pathfinding;" .. string.format(" %d / %d ", actualState, maxStates)
    else
        return "$l10n_AD_task_drive_to_unload_point;"
    end
end
