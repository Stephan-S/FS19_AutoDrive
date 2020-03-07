PickupAndDeliverMode = ADInheritsFrom(AbstractMode)

PickupAndDeliverMode.STATE_PICKUP_NEXT = 1
PickupAndDeliverMode.STATE_DELIVER_NEXT = 2

function PickupAndDeliverMode:new(vehicle)
    local o = PickupAndDeliverMode:create()
    o.vehicle = vehicle
    PickupAndDeliverMode.reset(o)
    return o
end

function PickupAndDeliverMode:reset()
    self.state = PickupAndDeliverMode.STATE_PICKUP_NEXT
    self.loopsDone = 0
end

function PickupAndDeliverMode:start()
    print("PickupAndDeliverMode:start")
    if not self.vehicle.ad.isActive then
        AutoDrive:startAD(self.vehicle)
    end

    local trailers, _ = AutoDrive.getTrailersOf(self.vehicle, false)
    local fillLevel, leftCapacity = AutoDrive.getFillLevelAndCapacityOfAll(trailers)
    local maxCapacity = fillLevel + leftCapacity

    if (leftCapacity <= (maxCapacity * (1 - AutoDrive.getSetting("unloadFillLevel", self.vehicle) + 0.001))) then
        self.state = PickupAndDeliverMode.STATE_DELIVER_NEXT
    end

    if AutoDrive.mapMarker[self.vehicle.ad.mapMarkerSelected] == nil or AutoDrive.mapMarker[self.vehicle.ad.mapMarkerSelected_Unload] == nil then
        return
    end

    self.vehicle.ad.taskModule:addTask(self:getNextTask())
end

function PickupAndDeliverMode:monitorTasks(dt)
end

function PickupAndDeliverMode:handleFinishedTask()
    self.vehicle.ad.trailerModule:reset()
    self.vehicle.ad.taskModule:addTask(self:getNextTask())
end

function PickupAndDeliverMode:stop()
end 

function PickupAndDeliverMode:getNextTask()
    local nextTask
    if self.state == PickupAndDeliverMode.STATE_PICKUP_NEXT then
        if self.vehicle.ad.loopCounterSelected == 0 or self.loopsDone < self.vehicle.ad.loopCounterSelected then
            nextTask = LoadAtDestinationTask:new(self.vehicle, self.vehicle.ad.targetSelected)
            self.state = PickupAndDeliverMode.STATE_DELIVER_NEXT
        else
            nextTask = StopAndDisableADTask:new(self.vehicle)
        end
    else
        nextTask = UnloadAtDestinationTask:new(self.vehicle, self.vehicle.ad.targetSelected_Unload)
        self.state = PickupAndDeliverMode.STATE_PICKUP_NEXT
    end
    return nextTask
end

function PickupAndDeliverMode:shouldUnloadAtTrigger()
    return self.state == PickupAndDeliverMode.STATE_PICKUP_NEXT and (AutoDrive.getDistanceToUnloadPosition(self.vehicle) <= AutoDrive.getSetting("maxTriggerDistance"))
end

function PickupAndDeliverMode:shouldLoadOnTrigger()
    return self.state == PickupAndDeliverMode.STATE_DELIVER_NEXT and (AutoDrive.getDistanceToTargetPosition(self.vehicle) <= AutoDrive.getSetting("maxTriggerDistance"))
end