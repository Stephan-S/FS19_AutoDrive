DriveToMode = ADInheritsFrom(AbstractMode)

function DriveToMode:new(vehicle)
    local o = DriveToMode:create()
    o.vehicle = vehicle
    DriveToMode.reset(o)
    return o
end

function DriveToMode:reset()
    self.driveToDestinationTask = nil
    self.destinationID = nil
end

function DriveToMode:start()
    if not self.vehicle.ad.stateModule:isActive() then
        AutoDrive.startAD(self.vehicle)
    end

    if self.vehicle.ad.stateModule:getFirstMarker() == nil then
        return
    end
    self.destinationID = self.vehicle.ad.stateModule:getFirstMarker().id

    self.driveToDestinationTask = DriveToDestinationTask:new(self.vehicle, self.destinationID)
    self.vehicle.ad.taskModule:addTask(self.driveToDestinationTask)
end

function DriveToMode:monitorTasks(dt)
end

function DriveToMode:handleFinishedTask()
    if self.driveToDestinationTask ~= nil then
        self.driveToDestinationTask = nil
        self.vehicle.ad.taskModule:addTask(StopAndDisableADTask:new(self.vehicle))
    else
        local target = self.vehicle.ad.stateModule:getFirstMarker().name
        for _, mapMarker in pairs(ADGraphManager:getMapMarkers()) do
            if self.destinationID == mapMarker.id then
                target = mapMarker.name
            end
        end

        AutoDriveMessageEvent.sendNotification(self.vehicle, ADMessagesManager.messageTypes.INFO, "$l10n_AD_Driver_of; %s $l10n_AD_has_reached; %s", 5000, self.vehicle.ad.driverName, target)
    end
end

function DriveToMode:stop()
end
