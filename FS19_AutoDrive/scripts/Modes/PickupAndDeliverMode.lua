PickupAndDeliverMode = ADInheritsFrom(AbstractMode)

PickupAndDeliverMode.STATE_DELIVER = 1
PickupAndDeliverMode.STATE_PICKUP = 2
PickupAndDeliverMode.STATE_RETURN_TO_START = 3
PickupAndDeliverMode.STATE_FINISHED = 4
PickupAndDeliverMode.STATE_EXIT_FIELD = 5

function PickupAndDeliverMode:new(vehicle)
    local o = PickupAndDeliverMode:create()
    o.vehicle = vehicle
    PickupAndDeliverMode.reset(o)
    return o
end

function PickupAndDeliverMode:reset()
    self.state = PickupAndDeliverMode.STATE_DELIVER
    self.loopsDone = 0
    self.activeTask = nil
end

function PickupAndDeliverMode:start()
    if not self.vehicle.ad.stateModule:isActive() then
        self.vehicle:startAutoDrive()
    end

    local trailers, _ = AutoDrive.getTrailersOf(self.vehicle, false)
    local fillLevel, leftCapacity = AutoDrive.getFillLevelAndCapacityOfAll(trailers)
    local maxCapacity = fillLevel + leftCapacity

    if (leftCapacity <= (maxCapacity * (1 - AutoDrive.getSetting("unloadFillLevel", self.vehicle) + 0.001))) then
        self.state = PickupAndDeliverMode.STATE_PICKUP
        if AutoDrive.getSetting("distributeToFolder", self.vehicle) and AutoDrive.getSetting("useFolders") then
            if AutoDrive.getSetting("syncMultiTargets") then
                local nextTarget = ADMultipleTargetsManager:getNextTarget(self.vehicle, false)
                if nextTarget ~= nil then
                    self.vehicle.ad.stateModule:setSecondMarker(nextTarget)
                end
            end
        end
    end

    if self.vehicle.ad.stateModule:getFirstMarker() == nil or self.vehicle.ad.stateModule:getSecondMarker() == nil then
        return
    end

    if self.vehicle.ad.callBackFunction ~= nil and ADGraphManager:getDistanceFromNetwork(self.vehicle) > 30 then
        self.activeTask = ExitFieldTask:new(self.vehicle)
        self.vehicle.ad.taskModule:addTask(self.activeTask)
        self.state = self.STATE_EXIT_FIELD
    else
        self.activeTask = self:getNextTask(false)
        if self.activeTask ~= nil then
            self.vehicle.ad.taskModule:addTask(self.activeTask)
        end
    end
end

function PickupAndDeliverMode:monitorTasks(dt)
end

function PickupAndDeliverMode:handleFinishedTask()
    self.vehicle.ad.trailerModule:reset()
    self.activeTask = self:getNextTask(true)
    if self.activeTask ~= nil then
        self.vehicle.ad.taskModule:addTask(self.activeTask)
    end
end

function PickupAndDeliverMode:stop()
end

function PickupAndDeliverMode:continue()
    if self.activeTask ~= nil and self.state == PickupAndDeliverMode.STATE_PICKUP or self.state == PickupAndDeliverMode.STATE_DELIVER then
        self.activeTask:continue()
    end
end

function PickupAndDeliverMode:getNextTask(forced)
    local nextTask
    if self.state == PickupAndDeliverMode.STATE_DELIVER then
        if self.vehicle.ad.stateModule:getLoopCounter() == 0 or self.loopsDone < self.vehicle.ad.stateModule:getLoopCounter() then
            nextTask = LoadAtDestinationTask:new(self.vehicle, self.vehicle.ad.stateModule:getFirstMarker().id)
            self.state = PickupAndDeliverMode.STATE_PICKUP

            if AutoDrive.getSetting("distributeToFolder", self.vehicle) and AutoDrive.getSetting("useFolders") then
                if AutoDrive.getSetting("distributeToFolder", self.vehicle) and AutoDrive.getSetting("useFolders") then
                    if AutoDrive.getSetting("syncMultiTargets") then
                        local nextTarget = ADMultipleTargetsManager:getNextTarget(self.vehicle, forced)
                        if nextTarget ~= nil then
                            self.vehicle.ad.stateModule:setSecondMarker(nextTarget)
                        end
                    end
                elseif forced then
                    self.vehicle.ad.stateModule:setNextTargetInFolder()
                end

                local trailers, _ = AutoDrive.getTrailersOf(self.vehicle, false)
                local fillLevel, _ = AutoDrive.getFillLevelAndCapacityOfAll(trailers)
                if fillLevel > 1 then
                    nextTask = UnloadAtDestinationTask:new(self.vehicle, self.vehicle.ad.stateModule:getSecondMarker().id)
                    self.state = PickupAndDeliverMode.STATE_DELIVER
                end
            end
        else
            nextTask = DriveToDestinationTask:new(self.vehicle, self.vehicle.ad.stateModule:getFirstMarker().id)
            self.state = PickupAndDeliverMode.STATE_RETURN_TO_START
        end
    elseif self.state == PickupAndDeliverMode.STATE_PICKUP or self.state == PickupAndDeliverMode.STATE_EXIT_FIELD then
        nextTask = UnloadAtDestinationTask:new(self.vehicle, self.vehicle.ad.stateModule:getSecondMarker().id)
        self.loopsDone = self.loopsDone + 1
        self.state = PickupAndDeliverMode.STATE_DELIVER
    elseif self.state == PickupAndDeliverMode.STATE_RETURN_TO_START then
        nextTask = StopAndDisableADTask:new(self.vehicle, ADTaskModule.DONT_PROPAGATE)
        self.state = PickupAndDeliverMode.STATE_FINISHED
    end

    return nextTask
end

function PickupAndDeliverMode:shouldUnloadAtTrigger()
    return self.state == PickupAndDeliverMode.STATE_DELIVER
end

function PickupAndDeliverMode:shouldLoadOnTrigger()
    return self.state == PickupAndDeliverMode.STATE_PICKUP and (AutoDrive.getDistanceToTargetPosition(self.vehicle) <= AutoDrive.getSetting("maxTriggerDistance"))
end
