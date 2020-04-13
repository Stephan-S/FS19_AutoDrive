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
            if not self.vehicle.ad.trailerModule:isActiveAtTrigger() then
                local trailers, _ = AutoDrive.getTrailersOf(self.vehicle, false)
                local fillLevel, _ = AutoDrive.getFillLevelAndCapacityOfAll(trailers)
                if fillLevel <= 1 or self.isContinued or (AutoDrive.getSetting("distributeToFolder", self.vehicle) and not self.vehicle.ad.drivePathModule:getIsReversing()) then
                    AutoDrive.setAugerPipeOpen(trailers, false)
                    self:finished()
                else
                    -- Wait at unload point until unloaded somehow
                    self.vehicle.ad.specialDrivingModule:stopVehicle()
                    self.vehicle.ad.specialDrivingModule:update(dt)
                end
            else
                if self.vehicle.ad.trailerModule:isUnloadingToBunkerSilo() then
                    self.vehicle.ad.drivePathModule:update(dt)
                else
                    self.vehicle.ad.specialDrivingModule:stopVehicle()
                    self.vehicle.ad.specialDrivingModule:update(dt)
                end
            end
        else
            --self.vehicle.ad.specialDrivingModule:releaseVehicle()
            if self.vehicle.ad.trailerModule:isActiveAtTrigger() then
                if self.vehicle.ad.trailerModule:isUnloadingToBunkerSilo() then
                    self.vehicle.ad.drivePathModule:update(dt)
                else
                    self.vehicle.ad.specialDrivingModule:stopVehicle()
                    self.vehicle.ad.specialDrivingModule:update(dt)
                end
            else
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
        return g_i18n:getText("AD_task_pathfinding")
    else
        return g_i18n:getText("AD_task_drive_to_unload_point")
    end
end

function UnloadAtDestinationTask:getI18nInfo()
    if self.state == UnloadAtDestinationTask.STATE_PATHPLANNING then
        return "$l10n_AD_task_pathfinding;"
    else
        return "$l10n_AD_task_drive_to_unload_point;"
    end
end
