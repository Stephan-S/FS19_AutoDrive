ExitFieldTask = ADInheritsFrom(AbstractTask)

ExitFieldTask.STATE_PATHPLANNING = 1
ExitFieldTask.STATE_DRIVING = 2

ExitFieldTask.STRATEGY_START = 0
ExitFieldTask.STRATEGY_BEHIND_START = 1
ExitFieldTask.STRATEGY_CLOSEST = 2

function ExitFieldTask:new(vehicle)
    local o = ExitFieldTask:create()
    o.vehicle = vehicle
    return o
end

function ExitFieldTask:setUp()
    self.state = ExitFieldTask.STATE_PATHPLANNING
    self.nextExitStrategy = AutoDrive.getSetting("exitField", self.vehicle)
    self:startPathPlanning()
end

function ExitFieldTask:update(dt)
    if self.state == ExitFieldTask.STATE_PATHPLANNING then
        if self.vehicle.ad.pathFinderModule:hasFinished() then
            self.wayPoints = self.vehicle.ad.pathFinderModule:getPath()
            if self.wayPoints == nil or #self.wayPoints == 0 then
                self.vehicle.ad.modes[AutoDrive.MODE_UNLOAD]:notifyAboutFailedPathfinder()
                self:selectNextStrategy()
                if self.vehicle.ad.pathFinderModule:isTargetBlocked() then
                    -- If the selected field exit isn't reachable, try the next strategy and restart without delay
                    self:startPathPlanning()
                elseif self.vehicle.ad.pathFinderModule:timedOut() or self.vehicle.ad.pathFinderModule:isBlocked() then
                    -- Add some delay to give the situation some room to clear itself
                    self:startPathPlanning()
                    self.vehicle.ad.pathFinderModule:addDelayTimer(10000)
                else
                    self:startPathPlanning()
                    self.vehicle.ad.pathFinderModule:addDelayTimer(10000)
                end
            else
                self.vehicle.ad.drivePathModule:setWayPoints(self.wayPoints)
                self.state = ExitFieldTask.STATE_DRIVING
            end
        else
            self.vehicle.ad.pathFinderModule:update(dt)
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
    if self.nextExitStrategy == ExitFieldTask.STRATEGY_CLOSEST then
        local closest = self.vehicle:getClosestWayPoint()
        local closestNode = ADGraphManager:getWayPointById(closest)
        local wayPoints = ADGraphManager:pathFromTo(closest, self.vehicle.ad.stateModule:getSecondWayPoint())
        if wayPoints ~= nil and #wayPoints > 1 then
            local vecToNextPoint = {x = wayPoints[2].x - closestNode.x, z = wayPoints[2].z - closestNode.z}
            self.vehicle.ad.pathFinderModule:startPathPlanningTo(closestNode, vecToNextPoint)
        else
            AutoDriveMessageEvent.sendMessageOrNotification(self.vehicle, ADMessagesManager.messageTypes.WARN, "$l10n_AD_Driver_of; %s $l10n_AD_cannot_find_path;", 5000, self.vehicle.ad.stateModule:getName())
            self.vehicle.ad.taskModule:abortAllTasks()
            self.vehicle.ad.taskModule:addTask(StopAndDisableADTask:new(self.vehicle))
        end
    else
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
            AutoDriveMessageEvent.sendMessageOrNotification(self.vehicle, ADMessagesManager.messageTypes.WARN, "$l10n_AD_Driver_of; %s $l10n_AD_cannot_find_path;", 5000, self.vehicle.ad.stateModule:getName())
            self.vehicle.ad.taskModule:abortAllTasks()
            self.vehicle.ad.taskModule:addTask(StopAndDisableADTask:new(self.vehicle))
        end
    end
end

function ExitFieldTask:selectNextStrategy()
    self.nextExitStrategy = (self.nextExitStrategy + 1) % (ExitFieldTask.STRATEGY_CLOSEST + 1)
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
