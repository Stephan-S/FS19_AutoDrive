DriveToVehicleTask = ADInheritsFrom(AbstractTask)

DriveToVehicleTask.TARGET_DISTANCE = 35

DriveToVehicleTask.STATE_PATHPLANNING = 1
DriveToVehicleTask.STATE_DRIVING = 2

function DriveToVehicleTask:new(vehicle, targetVehicle)
    local o = DriveToVehicleTask:create()
    o.vehicle = vehicle
    o.targetVehicle = targetVehicle
    o.state = DriveToVehicleTask.STATE_PATHPLANNING
    o.wayPoints = nil
    return o
end

function DriveToVehicleTask:setUp()
    self.vehicle.ad.pathFinderModule:startPathPlanningToVehicle(self.targetVehicle, DriveToVehicleTask.TARGET_DISTANCE)
end

function DriveToVehicleTask:update(dt)
    if self.state == DriveToVehicleTask.STATE_PATHPLANNING then
        if self.vehicle.ad.pathFinderModule:hasFinished() then
            self.wayPoints = self.vehicle.ad.pathFinderModule:getPath()
            if self.wayPoints == nil or #self.wayPoints == 0 then
                g_logManager:error("[AutoDrive] Could not calculate path - shutting down")
                self.vehicle.ad.taskModule:abortAllTasks()
                AutoDrive.disableAutoDriveFunctions(self.vehicle)
                AutoDriveMessageEvent.sendMessageOrNotification(self.vehicle, MessagesManager.messageTypes.ERROR, "$l10n_AD_Driver_of; %s $l10n_AD_cannot_find_path;", 5000, self.vehicle.ad.driverName)
            else
                self.vehicle.ad.drivePathModule:setWayPoints(self.wayPoints)
                self.state = DriveToVehicleTask.STATE_DRIVING
            end
        else
            self.vehicle.ad.pathFinderModule:update()
            self.vehicle.ad.specialDrivingModule:stopVehicle()
            self.vehicle.ad.specialDrivingModule:update(dt)
        end
    elseif self.state == DriveToVehicleTask.STATE_DRIVING then
        if self.vehicle.ad.drivePathModule:isTargetReached() then
            self:finished()
        else
            self.vehicle.ad.drivePathModule:update(dt)
        end
    end
end

function DriveToVehicleTask:abort()
    self.targetVehicle.ad.modes[AutoDrive.MODE_UNLOAD]:unregisterFollowingUnloader()
end

function DriveToVehicleTask:finished()
    self.targetVehicle.ad.modes[AutoDrive.MODE_UNLOAD]:unregisterFollowingUnloader()
    self.vehicle.ad.taskModule:setCurrentTaskFinished()
end

function DriveToVehicleTask:getInfoText()
    if self.state == DriveToVehicleTask.STATE_PATHPLANNING then
        return g_i18n:getText("AD_task_pathfinding")
    else
        return g_i18n:getText("AD_task_drive_to_vehicle")
    end
end
