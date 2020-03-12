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
    print("ADTaskModule:reset")
    while self.tasks:Count() > 0 do        
        print("ADTaskModule:reset - self.tasks:Count(): " .. self.tasks:Count())
        local task = self.tasks:Dequeue()
        if task.doRestart ~= nil then
            print("ADTaskModule:reset - task:doRestart()")
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
    if stoppedFlag == nil or stoppedFlag ~= ADTaskModule.DONT_PROPAGATE then
        self.vehicle.ad.stateModule:getCurrentMode():handleFinishedTask()
    end

    if self:hasToRefuel() then
        local refuelDestination = ADTriggerManager.getClosestRefuelDestination(vehicle)
        if refuelDestination ~= nil then
            self.activeTask = RefuelTask:new(self.vehicle, refuelDestination)
        end       
    end

    -- No refuel needed or no refuel trigger available
    if self.activeTask == nil then
        self.activeTask = self.tasks:Dequeue()
    end

    if self.activeTask ~= nil then
        print("ADTaskModule:update(dt) - starting new task")
        self.activeTask:setUp()
    end
end

function ADTaskModule:abortCurrentTask(abortMessage)
    if abortMessage ~= nil then
        AutoDrive.printMessage(self.vehicle, abortMessage)
    end
    self.activeTask = nil
end

function ADTaskModule:abortAllTasks()
    self.tasks:Clear()
    self.activeTask = nil
end

function ADTaskModule:stopAndRestartAD()
    self:abortAllTasks()
    self:addTask(StopAndDisableADTask:new(self.vehicle, ADTaskModule.DONT_PROPAGATE, true))
    --self:addTask(RestartADTask:new(self.vehicle))
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

function ADTaskModule:hasToRefuel()
    return AutoDrive.getSetting("autoRefuel", self.vehicle) and AutoDrive.hasToRefuel(self.vehicle)
end
