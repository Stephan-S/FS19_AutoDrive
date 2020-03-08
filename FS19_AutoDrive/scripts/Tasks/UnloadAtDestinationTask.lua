UnloadAtDestinationTask = ADInheritsFrom(AbstractTask)

function UnloadAtDestinationTask:new(vehicle, destinationID)
    local o = UnloadAtDestinationTask:create()
    o.vehicle = vehicle
    o.destinationID = destinationID
    return o
end

function UnloadAtDestinationTask:setUp()
    print("Setting up UnloadAtDestinationTask")
    self.vehicle.ad.drivePathModule:setPathTo(self.destinationID)
end

function UnloadAtDestinationTask:update(dt)
    if self.vehicle.ad.drivePathModule:isTargetReached() then
        self:finished()
    else
        self.vehicle.ad.trailerModule:update(dt)
        self.vehicle.ad.specialDrivingModule:releaseVehicle()
        if self.vehicle.ad.trailerModule:isActiveAtTrigger() then
            --print("UnloadAtDestinationTask - trailerModule:isActiveAtTrigger()")
            if self.vehicle.ad.trailerModule:isUnloadingToBunkerSilo() then
                self.vehicle.ad.drivePathModule:update(dt)
            else
                --print("UnloadAtDestinationTask - trailerModule:isActiveAtTrigger() - stop Vehicle")
                self.vehicle.ad.specialDrivingModule:stopVehicle()
                self.vehicle.ad.specialDrivingModule:update(dt)
            end
        else
            self.vehicle.ad.drivePathModule:update(dt)
        end
    end
end

function UnloadAtDestinationTask:abort()
end

function UnloadAtDestinationTask:finished()
    self.vehicle.ad.taskModule:setCurrentTaskFinished()
end
