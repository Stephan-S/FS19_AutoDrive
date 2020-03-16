UnloadAtMode = ADInheritsFrom(AbstractMode)

function UnloadAtMode:new(vehicle)
    local o = UnloadAtMode:create()
    o.vehicle = vehicle
    UnloadAtMode.reset(o)
    return o
end

function UnloadAtMode:reset()
    self.unloadAtDestinationTask = nil
    self.destinationID = nil
end

function UnloadAtMode:start()
    if not self.vehicle.ad.stateModule:isActive() then
        AutoDrive.startAD(self.vehicle)
    end

    if self.vehicle.ad.stateModule:getFirstMarker() == nil then
        return
    end
    self.destinationID = self.vehicle.ad.stateModule:getFirstMarker().id

    self.unloadAtDestinationTask = UnloadAtDestinationTask:new(self.vehicle, self.destinationID)
    self.vehicle.ad.taskModule:addTask(self.unloadAtDestinationTask)
end

function UnloadAtMode:monitorTasks(dt)
end

function UnloadAtMode:handleFinishedTask()
    --print("UnloadAtMode:handleFinishedTask")
    if self.unloadAtDestinationTask ~= nil then
        self.unloadAtDestinationTask = nil
        --print("UnloadAtMode:handleFinishedTask - starting stopAndDisableTask now")
        self.vehicle.ad.taskModule:addTask(StopAndDisableADTask:new(self.vehicle))
    else
        local target = self.vehicle.ad.stateModule:getFirstMarker().name
        for _, mapMarker in pairs(ADGraphManager:getMapMarker()) do
            if self.destinationID == mapMarker.id then
                target = mapMarker.name
            end
        end

        --print("UnloadAtMode:handleFinishedTask - done")
        AutoDriveMessageEvent.sendNotification(self.vehicle, MessagesManager.messageTypes.INFO, "$l10n_AD_Driver_of; %s $l10n_AD_has_reached; %s", 5000, self.vehicle.ad.driverName, target)
    end
end

function UnloadAtMode:stop()
end

function UnloadAtMode:shouldUnloadAtTrigger()
    return (AutoDrive.getDistanceToTargetPosition(self.vehicle) <= AutoDrive.getSetting("maxTriggerDistance"))
end
