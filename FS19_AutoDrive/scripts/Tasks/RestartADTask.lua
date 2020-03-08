RestartADTask = ADInheritsFrom(AbstractTask)

function RestartADTask:new(vehicle)
    local o = RestartADTask:create()
    o.vehicle = vehicle
    return o
end

function RestartADTask:setUp()
    print("RestartADTask:setUp()") 
    if self.vehicle.ad.isActive then
        AutoDrive.disableAutoDriveFunctions(self.vehicle)
    end
    self.vehicle.ad.modes[self.vehicle.ad.mode]:start()
end

function RestartADTask:update(dt)
    self:finished()
end

function RestartADTask:abort()
end

function RestartADTask:finished()
    self.vehicle.ad.taskModule:setCurrentTaskFinished(ADTaskModule.DONT_PROPAGATE)
end
