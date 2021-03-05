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
    self:onTaskChange()
    self.lastTaskInfo = ""
end

function ADTaskModule:addTask(newTask)
    self.tasks:Enqueue(newTask)
end

function ADTaskModule:getActiveTask()
    return self.activeTask
end

function ADTaskModule:setCurrentTaskFinished(stoppedFlag)
    if stoppedFlag == nil or stoppedFlag ~= ADTaskModule.DONT_PROPAGATE then
        self.vehicle.ad.stateModule:getCurrentMode():handleFinishedTask()
    end

    self.activeTask = nil

    self:RefuelIfNeeded()

    -- No refuel needed or no refuel trigger available
    if self.activeTask == nil then
        self.activeTask = self.tasks:Dequeue()
    end

    if self.activeTask ~= nil then
        self:onTaskChange()
        self.activeTask:setUp()
    end
end

function ADTaskModule:abortCurrentTask(abortMessage)
    if abortMessage ~= nil then
        AutoDrive.printMessage(self.vehicle, abortMessage)
    end
    self.activeTask = nil
    self:onTaskChange()
end

function ADTaskModule:abortAllTasks()
    if self.activeTask ~= nil then
        self.activeTask:abort()
    end
    self.tasks:Clear()
    self.activeTask = nil
    self:onTaskChange()
end

function ADTaskModule:stopAndRestartAD()
    self:abortAllTasks()
    self:addTask(StopAndDisableADTask:new(self.vehicle, ADTaskModule.DONT_PROPAGATE, true))
end

function ADTaskModule:update(dt)
    if self.activeTask ~= nil and self.activeTask.update ~= nil then
        local taskInfo = self.activeTask:getI18nInfo()
        self.activeTask:update(dt)
        self.vehicle.ad.stateModule:getCurrentMode():monitorTasks(dt)
        if self.lastTaskInfo ~= taskInfo then
            self:onTaskInfoChange(taskInfo)
        end
    else
        self:RefuelIfNeeded()
    
        -- No refuel needed or no refuel trigger available
        if self.activeTask == nil then
            self.activeTask = self.tasks:Dequeue()
        end
        
        if self.activeTask ~= nil then
            self.activeTask:setUp()
        end
        self:onTaskChange()
    end
end

function ADTaskModule:hasToRefuel()
    if not AutoDrive.getSetting("autoRefuel", self.vehicle) then
        return false
    end
    local refuelFillType = AutoDrive.getRequiredRefuel(self.vehicle)
    if refuelFillType > 0 then
        -- refuel required
        if self.vehicle.ad.stateModule:getRefuelFillType() ~= refuelFillType then
            self.vehicle.ad.stateModule:setRefuelFillType(refuelFillType)
        end
        return true
    else
        return false
    end
end

function ADTaskModule:RefuelIfNeeded()
    if self:hasToRefuel() then
        local refuelDestinationMarkerID = ADTriggerManager.getClosestRefuelDestination(self.vehicle)
        if refuelDestinationMarkerID ~= nil then
            self.activeTask = RefuelTask:new(self.vehicle, ADGraphManager:getMapMarkerById(refuelDestinationMarkerID).id)
        else
            self.vehicle.ad.isStoppingWithError = true
            self.vehicle:stopAutoDrive()
            local refuelFillTypeTitle = g_fillTypeManager:getFillTypeByIndex(self.vehicle.ad.stateModule:getRefuelFillType()).title
            AutoDriveMessageEvent.sendMessageOrNotification(self.vehicle, ADMessagesManager.messageTypes.ERROR, "$l10n_AD_Driver_of; %s $l10n_AD_No_Refuel_Station; %s", 5000, self.vehicle.ad.stateModule:getName(), refuelFillTypeTitle)
        end
    end
end
    

function ADTaskModule:onTaskChange()
    local taskInfo = ""
    if self.activeTask ~= nil then
        taskInfo = self.activeTask:getI18nInfo()
    end
    if self.lastTaskInfo ~= taskInfo then
        self:onTaskInfoChange(taskInfo)
    end
    self.vehicle.ad.trailerModule:reset()
end

function ADTaskModule:onTaskInfoChange(taskInfo)
    self.vehicle.ad.stateModule:setCurrentTaskInfo(taskInfo)
    self.lastTaskInfo = taskInfo
end

function ADTaskModule:getNumberOfTasks()
    return self.tasks:Count()
end
