DriveToDestinationTask = ADInheritsFrom(AbstractTask)

function DriveToDestinationTask:new(vehicle, destinationID)
    local o = DriveToDestinationTask:create()
    o.vehicle = vehicle
    o.destinationID = destinationID
    return o
end

function DriveToDestinationTask:setUp()
    print("Setting up DriveToDestinationTask")
    self.vehicle.ad.drivePathModule:setPathTo(self.destinationID)
end

function DriveToDestinationTask:update(dt)
    if self.vehicle.ad.drivePathModule:isTargetReached() then
        self:finished()
    else
        self.vehicle.ad.drivePathModule:update(dt)
    end
end

function DriveToDestinationTask:abort()
end

function DriveToDestinationTask:finished()
    self.vehicle.ad.taskModule:setCurrentTaskFinished()
end
