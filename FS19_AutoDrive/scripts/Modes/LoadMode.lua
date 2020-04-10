LoadMode = ADInheritsFrom(AbstractMode)

LoadMode.STATE_LOAD = 1
LoadMode.STATE_TO_TARGET = 2
LoadMode.STATE_EXIT_FIELD = 3

function LoadMode:new(vehicle)
    local o = LoadMode:create()
    o.vehicle = vehicle
    LoadMode.reset(o)
    return o
end

function LoadMode:reset()
    self.state = LoadMode.STATE_LOAD
end

function LoadMode:start()
    if not self.vehicle.ad.stateModule:isActive() then
        self.vehicle:startAutoDrive()
    end

    local trailers, _ = AutoDrive.getTrailersOf(self.vehicle, false)
    local fillLevel, leftCapacity = AutoDrive.getFillLevelAndCapacityOfAll(trailers)
    local maxCapacity = fillLevel + leftCapacity

    if self.vehicle.ad.stateModule:getFirstMarker() == nil or self.vehicle.ad.stateModule:getSecondMarker() == nil then
        return
    end

    if self.vehicle.ad.callBackFunction ~= nil and ADGraphManager:getDistanceFromNetwork(self.vehicle) > 30 then
        self.vehicle.ad.taskModule:addTask(ExitFieldTask:new(self.vehicle))
        self.state = self.STATE_EXIT_FIELD
    else
        if (leftCapacity <= (maxCapacity * (1 - AutoDrive.getSetting("unloadFillLevel", self.vehicle) + 0.001))) then
            self.state = LoadMode.STATE_TO_TARGET
            self.vehicle.ad.taskModule:addTask(DriveToDestinationTask:new(self.vehicle, self.vehicle.ad.stateModule:getFirstMarker().id))
        else
            self.vehicle.ad.taskModule:addTask(LoadAtDestinationTask:new(self.vehicle, self.vehicle.ad.stateModule:getSecondMarker().id))
        end
    end
end

function LoadMode:monitorTasks(dt)
end

function LoadMode:handleFinishedTask()
    self.vehicle.ad.trailerModule:reset()
    self.vehicle.ad.taskModule:addTask(self:getNextTask())
end

function LoadMode:stop()
end

function LoadMode:getNextTask()
    local nextTask
    if self.state == LoadMode.STATE_TO_TARGET then
        nextTask = StopAndDisableADTask:new(self.vehicle, ADTaskModule.DONT_PROPAGATE)
    elseif self.state == LoadMode.STATE_EXIT_FIELD then
        self.vehicle.ad.taskModule:addTask(LoadAtDestinationTask:new(self.vehicle, self.vehicle.ad.stateModule:getSecondMarker().id))
        self.state = LoadMode.STATE_LOAD
    else
        nextTask = DriveToDestinationTask:new(self.vehicle, self.vehicle.ad.stateModule:getFirstMarker().id)
        self.state = LoadMode.STATE_TO_TARGET
    end
    return nextTask
end

function LoadMode:shouldLoadOnTrigger()
    return self.state == LoadMode.STATE_LOAD and (AutoDrive.getDistanceToUnloadPosition(self.vehicle) <= AutoDrive.getSetting("maxTriggerDistance"))
end
