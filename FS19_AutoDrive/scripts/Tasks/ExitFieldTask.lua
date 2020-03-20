ExitFieldTask = ADInheritsFrom(AbstractTask)

ExitFieldTask.STATE_PATHPLANNING = 1
ExitFieldTask.STATE_DRIVING = 2

function ExitFieldTask:new(vehicle)
    local o = ExitFieldTask:create()
    o.vehicle = vehicle
    return o
end

function ExitFieldTask:setUp()
    self.state = ExitFieldTask.STATE_PATHPLANNING
    self:startPathPlanning()
end

function ExitFieldTask:update(dt)
    if self.state == ExitFieldTask.STATE_PATHPLANNING then
        if self.vehicle.ad.pathFinderModule:hasFinished() then
            self.wayPoints = self.vehicle.ad.pathFinderModule:getPath()
            if self.wayPoints == nil or #self.wayPoints == 0 then
                --restart
                --AutoDriveMessageEvent.sendNotification(self.vehicle, ADMessagesManager.messageTypes.WARN, "$l10n_AD_Driver_of; %s $l10n_AD_cannot_find_path;", 5000, self.vehicle.ad.stateModule:getName())
                self:startPathPlanning()
            else
                self.vehicle.ad.drivePathModule:setWayPoints(self.wayPoints)
                self.state = ExitFieldTask.STATE_DRIVING
            end
        else
            self.vehicle.ad.pathFinderModule:update()
            self.vehicle.ad.specialDrivingModule:stopVehicle()
            self.vehicle.ad.specialDrivingModule:update(dt)
        end
    else
        if self.vehicle.ad.drivePathModule:isTargetReached() then
            self:finished()
        else
            self.vehicle.ad.drivePathModule:update(dt)
        end
    end
end

function ExitFieldTask:abort()
end

function ExitFieldTask:finished()
    self.vehicle.ad.taskModule:setCurrentTaskFinished()
end

function ExitFieldTask:startPathPlanning()
    local targetNode = ADGraphManager:getWayPointById(self.vehicle.ad.stateModule:getFirstWayPoint())
    local wayPoints = ADGraphManager:pathFromTo(self.vehicle.ad.stateModule:getFirstWayPoint(), self.vehicle.ad.stateModule:getSecondWayPoint())
    if wayPoints ~= nil and #wayPoints > 1 then
        local vecToNextPoint = {x = wayPoints[2].x - targetNode.x, z = wayPoints[2].z - targetNode.z}
        if AutoDrive.getSetting("exitField", self.vehicle) == 1 and #wayPoints > 6 then
            targetNode = wayPoints[5]
            vecToNextPoint = {x = wayPoints[6].x - targetNode.x, z = wayPoints[6].z - targetNode.z}
        end
        self.vehicle.ad.pathFinderModule:startPathPlanningTo(targetNode, vecToNextPoint)
    else
        AutoDriveMessageEvent.sendNotification(self.vehicle, ADMessagesManager.messageTypes.WARN, "$l10n_AD_Driver_of; %s $l10n_AD_cannot_find_path;", 5000, self.vehicle.ad.stateModule:getName())
        self.vehicle.ad.taskModule:abortAllTasks()
        self.vehicle.ad.taskModule:addTask(StopAndDisableADTask:new(self.vehicle))
    end
end

function ExitFieldTask:getInfoText()
    if self.state == ExitFieldTask.STATE_PATHPLANNING then
        return g_i18n:getText("AD_task_pathfinding")
    else
        return g_i18n:getText("AD_task_exiting_field")
    end
end

function ExitFieldTask:getI18nInfo()
    if self.state == ExitFieldTask.STATE_PATHPLANNING then
        return "$l10n_AD_task_pathfinding;"
    else
        return "$l10n_AD_task_exiting_field;"
    end
end
