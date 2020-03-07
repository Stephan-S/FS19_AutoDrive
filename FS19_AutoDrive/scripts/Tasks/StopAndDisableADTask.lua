StopAndDisableADTask = ADInheritsFrom(AbstractTask)

function StopAndDisableADTask:new(vehicle)
    local o = StopAndDisableADTask:create()
    o.vehicle = vehicle
    return o
end

function StopAndDisableADTask:setUp()
    print("StopAndDisableADTask:setUp()")
    self.vehicle.ad.specialDrivingModule:stopVehicle()
end

function StopAndDisableADTask:update(dt)
    if math.abs(self.vehicle.lastSpeedReal) < 0.0015 then
        print("StopAndDisableADTask:update() - done - shutting down")
        AutoDrive:disableAutoDriveFunctions(self.vehicle)
        self:finished()
    else
        self.vehicle.ad.specialDrivingModule:update(dt)
    end
end

function StopAndDisableADTask:abort()
end

function StopAndDisableADTask:finished()
    self.vehicle.ad.taskModule:setCurrentTaskFinished()
end
