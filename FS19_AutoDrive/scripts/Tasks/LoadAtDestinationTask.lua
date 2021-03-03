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
    self.vehicle.ad.trailerModule:reset()
    AutoDrive.debugPrint(self.vehicle, AutoDrive.DC_VEHICLEINFO, "[AD] LoadAtDestinationTask:setUp end self.state %s", tostring(self.state))
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
        -- STATE_DRIVING
        AutoDrive.debugPrint(self.vehicle, AutoDrive.DC_VEHICLEINFO, "[AD] LoadAtDestinationTask:update self.state %s", tostring(self.state))
        if self.vehicle.ad.drivePathModule:isTargetReached() then
            --Check if we have actually loaded / tried to load
            AutoDrive.debugPrint(self.vehicle, AutoDrive.DC_VEHICLEINFO, "[AD] LoadAtDestinationTask:update isTargetReached")
            local trailers, _ = AutoDrive.getTrailersOf(self.vehicle, false)
            AutoDrive.setTrailerCoverOpen(self.vehicle, trailers, true)
            if (self.vehicle.ad.callBackFunction ~= nil or (g_courseplay ~= nil and self.vehicle.ad.stateModule:getStartCP_AIVE())) and self.vehicle.ad.stateModule:getMode() == AutoDrive.MODE_PICKUPANDDELIVER then
                AutoDrive.debugPrint(self.vehicle, AutoDrive.DC_VEHICLEINFO, "[AD] LoadAtDestinationTask:update ERROR stopAutoDrive")
                self.vehicle:stopAutoDrive()
            else
                if not self.vehicle.ad.trailerModule:isActiveAtTrigger() then
                    AutoDrive.debugPrint(self.vehicle, AutoDrive.DC_VEHICLEINFO, "[AD] LoadAtDestinationTask:update not isActiveAtTrigger")
                    if self.vehicle.ad.trailerModule:wasAtSuitableTrigger() then
                        AutoDrive.debugPrint(self.vehicle, AutoDrive.DC_VEHICLEINFO, "[AD] LoadAtDestinationTask:update wasAtSuitableTrigger -> self:finished")
                        self:finished()
                    else
                        -- Wait to be loaded manally - check filllevel
                        AutoDrive.startFillFillableTrailer(self.vehicle)        -- try to load fillable trailer
                        AutoDrive.debugPrint(self.vehicle, AutoDrive.DC_VEHICLEINFO, "[AD] LoadAtDestinationTask:update Wait to be loaded manally")
                        self.vehicle.ad.specialDrivingModule:stopVehicle()
                        self.vehicle.ad.specialDrivingModule:update(dt)

                        local trailers, _ = AutoDrive.getTrailersOf(self.vehicle, false)
                        local fillLevel, leftCapacity = AutoDrive.getFillLevelAndCapacityOfAll(trailers)
                        local maxCapacity = fillLevel + leftCapacity
                        AutoDrive.debugPrint(self.vehicle, AutoDrive.DC_VEHICLEINFO, "[AD] LoadAtDestinationTask:update leftCapacity %s maxCapacity %s", tostring(leftCapacity), tostring(maxCapacity))

                        if (leftCapacity <= (maxCapacity * (1 - AutoDrive.getSetting("unloadFillLevel", self.vehicle) + 0.001))) or ((AutoDrive.getSetting("rotateTargets", self.vehicle) == AutoDrive.RT_ONLYPICKUP or AutoDrive.getSetting("rotateTargets", self.vehicle) == AutoDrive.RT_PICKUPANDDELIVER) and AutoDrive.getSetting("useFolders")) then
                            AutoDrive.debugPrint(self.vehicle, AutoDrive.DC_VEHICLEINFO, "[AD] LoadAtDestinationTask:update leftCapacity <= -> self:finished")
                            self:finished()
                        end
                    end
                else
                    AutoDrive.debugPrint(self.vehicle, AutoDrive.DC_VEHICLEINFO, "[AD] LoadAtDestinationTask:update 1 isActiveAtTrigger -> specialDrivingModule:stopVehicle")
                    self.vehicle.ad.specialDrivingModule:stopVehicle()
                    self.vehicle.ad.specialDrivingModule:update(dt)
                end
            end
        else
            AutoDrive.debugPrint(self.vehicle, AutoDrive.DC_VEHICLEINFO, "[AD] LoadAtDestinationTask:update NOT isTargetReached")
            self.vehicle.ad.trailerModule:update(dt)
            --self.vehicle.ad.specialDrivingModule:releaseVehicle()
            if self.vehicle.ad.trailerModule:isActiveAtTrigger() then
                AutoDrive.debugPrint(self.vehicle, AutoDrive.DC_VEHICLEINFO, "[AD] LoadAtDestinationTask:update 2 isActiveAtTrigger -> specialDrivingModule:stopVehicle")
                self.vehicle.ad.specialDrivingModule:stopVehicle()
                self.vehicle.ad.specialDrivingModule:update(dt)
            else
                AutoDrive.debugPrint(self.vehicle, AutoDrive.DC_VEHICLEINFO, "[AD] LoadAtDestinationTask:update not isActiveAtTrigger -> drivePathModule:update")
                self.vehicle.ad.drivePathModule:update(dt)
            end
        end
    end
end

function LoadAtDestinationTask:continue()
    AutoDrive.debugPrint(self.vehicle, AutoDrive.DC_VEHICLEINFO, "[AD] LoadAtDestinationTask:continue -> trailerModule:stopLoading")
    self.vehicle.ad.trailerModule:stopLoading()
end

function LoadAtDestinationTask:abort()
end

function LoadAtDestinationTask:finished()
    AutoDrive.debugPrint(self.vehicle, AutoDrive.DC_VEHICLEINFO, "[AD] LoadAtDestinationTask:finished -> specialDrivingModule:releaseVehicle / setCurrentTaskFinished")
    self.vehicle.ad.specialDrivingModule:releaseVehicle()
    self.vehicle.ad.taskModule:setCurrentTaskFinished()
end

function LoadAtDestinationTask:getInfoText()
    if self.state == LoadAtDestinationTask.STATE_PATHPLANNING then
        local actualState, maxStates = self.vehicle.ad.pathFinderModule:getCurrentState()
        return g_i18n:getText("AD_task_pathfinding") .. string.format(" %d / %d ", actualState, maxStates)
    else
        return g_i18n:getText("AD_task_drive_to_load_point")
    end
end

function LoadAtDestinationTask:getI18nInfo()
    if self.state == LoadAtDestinationTask.STATE_PATHPLANNING then
        local actualState, maxStates = self.vehicle.ad.pathFinderModule:getCurrentState()
        return "$l10n_AD_task_pathfinding;" .. string.format(" %d / %d ", actualState, maxStates)
    else
        return "$l10n_AD_task_drive_to_load_point;"
    end
end
