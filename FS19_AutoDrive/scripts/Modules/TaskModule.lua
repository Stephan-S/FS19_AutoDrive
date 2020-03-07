ADTaskModule = {}

function ADTaskModule:new(vehicle)
    local o = {}
    setmetatable(o, self)
    self.__index = self
    o.vehicle = vehicle
    ADTaskModule.reset(o)
    return o
end

function ADTaskModule:reset()
    self.currentTask = nil
end

function ADTaskModule:addTask(newTask)
    self.currentTask = newTask
    self.currentTask:setUp()
end

function ADTaskModule:setCurrentTaskFinished()
    print("ADTaskModule:setCurrentTaskFinished - mode: " .. self.vehicle.ad.mode)
    self.currentTask = nil
    self.vehicle.ad.modes[self.vehicle.ad.mode]:handleFinishedTask()
end

function ADTaskModule:abortCurrentTask(abortMessage)
    if abortMessage ~= nil then
        AutoDrive.printMessage(self.vehicle, abortMessage)
    end
    self.vehicle.ad.specialDrivingModule:stopVehicle()
end

function ADTaskModule:update(dt)
    if self.currentTask ~= nil and self.currentTask.update ~= nil then
        self.currentTask:update(dt)
    end
end

