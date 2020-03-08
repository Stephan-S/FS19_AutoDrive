ADTaskModule = {}

ADTaskModule.DONT_PROPAGATE = 1

function ADTaskModule:new(vehicle)
    local o = {}
    setmetatable(o, self)
    self.__index = self
    o.vehicle = vehicle
    o.tasks = Queue:new()
    ADTaskModule.reset(o)
    return o
end

function ADTaskModule:reset()
    while self.tasks:Count() > 0 do
        local task = self.tasks:Dequeue()
        if task.doRestart ~= nil then
            task:doRestart()
            break
        end
    end

    self.tasks:Clear()
    self.activeTask = nil
end

function ADTaskModule:addTask(newTask)
    print("ADTaskModule:addTask")
    self.tasks:Enqueue(newTask)
end

function ADTaskModule:setCurrentTaskFinished(stoppedFlag)
    print("ADTaskModule:setCurrentTaskFinished - mode: " .. self.vehicle.ad.mode)
    if stoppedFlag == nil or stoppedFlag ~= ADTaskModule.DONT_PROPAGATE then
        self.vehicle.ad.modes[self.vehicle.ad.mode]:handleFinishedTask()
    end

    self.activeTask = self.tasks:Dequeue()
    if self.activeTask ~= nil then
        print("ADTaskModule:update(dt) - starting new task")
        self.activeTask:setUp()
    end
end

function ADTaskModule:abortCurrentTask(abortMessage)
    if abortMessage ~= nil then
        AutoDrive.printMessage(self.vehicle, abortMessage)
    end
    self.vehicle.ad.specialDrivingModule:stopVehicle()
end

function ADTaskModule:abortAllTasks()
    self.tasks:Clear()
    self.activeTask = nil
end

function ADTaskModule:stopAndRestartAD()
    self:abortAllTasks()
    self:addTask(StopAndDisableADTask:new(self.vehicle, ADTaskModule.DONT_PROPAGATE))
    self:addTask(RestartADTask:new(self.vehicle))
end

function ADTaskModule:update(dt)    
    if self.activeTask ~= nil and self.activeTask.update ~= nil then
        self.activeTask:update(dt)
    else
        self.activeTask = self.tasks:Dequeue()
        if self.activeTask ~= nil then
            print("ADTaskModule:update(dt) - starting new task")
            self.activeTask:setUp()
        end
    end
end

