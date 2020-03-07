LoadAtDestinationTask = ADInheritsFrom(AbstractTask)

function LoadAtDestinationTask:new(vehicle, destinationID)
    local o = LoadAtDestinationTask:create()
    o.vehicle = vehicle
    o.destinationID = destinationID
    return o
end

function LoadAtDestinationTask:setUp()
    self.vehicle.ad.drivePathModule:setPathTo(self.destinationID)
end

function LoadAtDestinationTask:update(dt)
    if self.vehicle.ad.drivePathModule:isTargetReached() then
        --Check if we have actually loaded / tried to load something
        if self.vehicle.ad.trailerModule:wasAtSuitableTrigger() then
            self:finished()
        else
            -- Wait to be loaded manally - check filllevel
            self.vehicle.ad.specialDrivingModule:stopVehicle()
            self.vehicle.ad.specialDrivingModule:update(dt)
            
            local trailers, _ = AutoDrive.getTrailersOf(self.vehicle, false)
            local fillLevel, leftCapacity = AutoDrive.getFillLevelAndCapacityOfAll(trailers)
            local maxCapacity = fillLevel + leftCapacity

            if (leftCapacity <= (maxCapacity * (1 - AutoDrive.getSetting("unloadFillLevel", self.vehicle) + 0.001))) then
                self:finished()
            end
        end
    else
        self.vehicle.ad.trailerModule:update(dt)
        self.vehicle.ad.specialDrivingModule:releaseVehicle()
        if self.vehicle.ad.trailerModule:isActiveAtTrigger() then
            self.vehicle.ad.specialDrivingModule:stopVehicle()
            self.vehicle.ad.specialDrivingModule:update(dt)
        else
            self.vehicle.ad.drivePathModule:update(dt)
        end
    end
end

function LoadAtDestinationTask:abort()
end

function LoadAtDestinationTask:finished()
    self.vehicle.ad.specialDrivingModule:releaseVehicle()
    self.vehicle.ad.taskModule:setCurrentTaskFinished()
end
