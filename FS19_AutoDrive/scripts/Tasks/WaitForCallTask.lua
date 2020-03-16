WaitForCallTask = ADInheritsFrom(AbstractTask)

function WaitForCallTask:new(vehicle)
    local o = WaitForCallTask:create()
    o.vehicle = vehicle
    o.propagate = propagate -- TODO: Missing "propagate"
    return o
end

function WaitForCallTask:setUp()
    self.vehicle.ad.specialDrivingModule:stopVehicle()
end

function WaitForCallTask:update(dt)
    self.vehicle.ad.specialDrivingModule:update(dt)
end

function WaitForCallTask:abort()
end

function WaitForCallTask:finished()
    self.vehicle.ad.taskModule:setCurrentTaskFinished(self.propagate)
end

function WaitForCallTask:getInfoText()
    return g_i18n:getText("AD_task_wait_for_call")
end
