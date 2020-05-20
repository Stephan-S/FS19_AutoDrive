LoadAtDestinationTask = ADInheritsFrom(AbstractTask)

LoadAtDestinationTask.STATE_PATHPLANNING = 1
LoadAtDestinationTask.STATE_DRIVING = 2

function LoadAtDestinationTask:new(vehicle, destinationID)
    local o = LoadAtDestinationTask:create()
    o.vehicle = vehicle
    o.destinationID = destinationID
    return o
end

function LoadAtDestinationTask:setUp()
    if ADGraphManager:getDistanceFromNetwork(self.vehicle) > 30 then
        self.state = LoadAtDestinationTask.STATE_PATHPLANNING
        --if self.vehicle.ad.callBackFunction ~= nil then
            --if self.vehicle.ad.stateModule:getMode() == AutoDrive.MODE_LOAD then
                --self.vehicle.ad.pathFinderModule:startPathPlanningToWayPoint(self.vehicle.ad.stateModule:getFirstWayPoint(), self.destinationID)
            --else
                --self.vehicle.ad.pathFinderModule:startPathPlanningToWayPoint(self.vehicle.ad.stateModule:getSecondWayPoint(), self.destinationID)
            --end
        --else
            self.vehicle.ad.pathFinderModule:startPathPlanningToNetwork(self.destinationID)
        --end
    else
        self.state = LoadAtDestinationTask.STATE_DRIVING
        self.vehicle.ad.drivePathModule:setPathTo(self.destinationID)
    end
end

function LoadAtDestinationTask:update(dt)
    if self.state == LoadAtDestinationTask.STATE_PATHPLANNING then
        if self.vehicle.ad.pathFinderModule:hasFinished() then
            self.wayPoints = self.vehicle.ad.pathFinderModule:getPath()
            if self.wayPoints == nil or #self.wayPoints == 0 then
                g_logManager:error("[AutoDrive] Could not calculate path - shutting down")
                self.vehicle.ad.taskModule:abortAllTasks()
                self.vehicle:stopAutoDrive()
                AutoDriveMessageEvent.sendMessageOrNotification(self.vehicle, ADMessagesManager.messageTypes.ERROR, "$l10n_AD_Driver_of; %s $l10n_AD_cannot_find_path;", 5000, self.vehicle.ad.stateModule:getName())
            else
                self.vehicle.ad.drivePathModule:setWayPoints(self.wayPoints)
                --self.vehicle.ad.drivePathModule:appendPathTo(self.wayPoints[#self.wayPoints], self.destinationID)
                self.state = LoadAtDestinationTask.STATE_DRIVING
            end
        else
            self.vehicle.ad.pathFinderModule:update(dt)
            self.vehicle.ad.specialDrivingModule:stopVehicle()
            self.vehicle.ad.specialDrivingModule:update(dt)
        end
    else
        if self.vehicle.ad.drivePathModule:isTargetReached() then
            --Check if we have actually loaded / tried to load
            local trailers, _ = AutoDrive.getTrailersOf(self.vehicle, false)
            AutoDrive.setTrailerCoverOpen(self.vehicle, trailers, true)
            if (self.vehicle.ad.callBackFunction ~= nil or (g_courseplay ~= nil and self.vehicle.ad.stateModule:getStartAI())) and self.vehicle.ad.stateModule:getMode() == AutoDrive.MODE_PICKUPANDDELIVER then
                self.vehicle:stopAutoDrive()
            else
                if not self.vehicle.ad.trailerModule:isActiveAtTrigger() then
                    if self.vehicle.ad.trailerModule:wasAtSuitableTrigger() then
                        self:finished()
                    else
                        -- Wait to be loaded manally - check filllevel
                        self.vehicle.ad.specialDrivingModule:stopVehicle()
                        self.vehicle.ad.specialDrivingModule:update(dt)

                        local trailers, _ = AutoDrive.getTrailersOf(self.vehicle, false)
                        local fillLevel, leftCapacity = AutoDrive.getFillLevelAndCapacityOfAll(trailers)
                        local maxCapacity = fillLevel + leftCapacity

                        if (leftCapacity <= (maxCapacity * (1 - AutoDrive.getSetting("unloadFillLevel", self.vehicle) + 0.001))) then
                            self:finished()
                        end
                    end
                else
                    self.vehicle.ad.specialDrivingModule:stopVehicle()
                    self.vehicle.ad.specialDrivingModule:update(dt)
                end
            end
        else
            self.vehicle.ad.trailerModule:update(dt)
            --self.vehicle.ad.specialDrivingModule:releaseVehicle()
            if self.vehicle.ad.trailerModule:isActiveAtTrigger() then
                self.vehicle.ad.specialDrivingModule:stopVehicle()
                self.vehicle.ad.specialDrivingModule:update(dt)
            else
                self.vehicle.ad.drivePathModule:update(dt)
            end
        end
    end
end

function LoadAtDestinationTask:continue()
    self.vehicle.ad.trailerModule:stopLoading()
end

function LoadAtDestinationTask:abort()
end

function LoadAtDestinationTask:finished()
    self.vehicle.ad.specialDrivingModule:releaseVehicle()
    self.vehicle.ad.taskModule:setCurrentTaskFinished()
end

function LoadAtDestinationTask:getInfoText()
    if self.state == LoadAtDestinationTask.STATE_PATHPLANNING then
        return g_i18n:getText("AD_task_pathfinding")
    else
        return g_i18n:getText("AD_task_drive_to_load_point")
    end
end

function LoadAtDestinationTask:getI18nInfo()
    if self.state == LoadAtDestinationTask.STATE_PATHPLANNING then
        return "$l10n_AD_task_pathfinding;"
    else
        return "$l10n_AD_task_drive_to_load_point;"
    end
end
