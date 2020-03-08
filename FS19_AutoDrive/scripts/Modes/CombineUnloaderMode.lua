CombineUnloaderMode = ADInheritsFrom(AbstractMode)

CombineUnloaderMode.STATE_INIT = 1
CombineUnloaderMode.STATE_WAIT_TO_BE_CALLED = 2
CombineUnloaderMode.STATE_DRIVE_TO_COMBINE = 3
CombineUnloaderMode.STATE_DRIVE_TO_PIPE = 4
CombineUnloaderMode.STATE_REVERSE_FROM_PIPE = 5
CombineUnloaderMode.STATE_LEAVE_CROP = 6
CombineUnloaderMode.STATE_DRIVE_TO_START = 7
CombineUnloaderMode.STATE_DRIVE_TO_UNLOAD = 8
CombineUnloaderMode.STATE_FOLLOW_COMBINE = 9
CombineUnloaderMode.STATE_ACTIVE_UNLOAD_COMBINE = 10

function CombineUnloaderMode:new(vehicle)
    local o = CombineUnloaderMode:create()
    o.vehicle = vehicle
    CombineUnloaderMode.reset(o)
    return o
end

function CombineUnloaderMode:reset()
    self.state = CombineUnloaderMode.STATE_INIT
    self.activeTask = nil
end

function CombineUnloaderMode:start()
    print("CombineUnloaderMode:start")
    if not self.vehicle.ad.isActive then
        AutoDrive:startAD(self.vehicle)
    end

    if AutoDrive.mapMarker[self.vehicle.ad.mapMarkerSelected] == nil or AutoDrive.mapMarker[self.vehicle.ad.mapMarkerSelected_Unload] == nil then
        return
    end

    self.activeTask = self:getNextTask()
    if self.activeTask ~= nil then
        self.vehicle.ad.taskModule:addTask(self.activeTask)
    end
end

function CombineUnloaderMode:monitorTasks(dt)
end

function CombineUnloaderMode:handleFinishedTask()
    print("CombineUnloaderMode:handleFinishedTask")
    self.vehicle.ad.trailerModule:reset()
    self.activeTask = self:getNextTask()
    if self.activeTask ~= nil then
        self.vehicle.ad.taskModule:addTask(self.activeTask)
    end
end

function CombineUnloaderMode:stop()
end

function CombineUnloaderMode:continue()
    if self.state == CombineUnloaderMode.STATE_PICKUP then
        self.activeTask:continue()
    end
end

function CombineUnloaderMode:getNextTask()
    print("CombineUnloaderMode:getNextTask()")
    --quick test
    local otherVehicle
    for _, vehicle in pairs(g_currentMission.vehicles) do
        if vehicle.ad ~= nil and vehicle.ad.mode == AutoDrive.MODE_DRIVETO and vehicle.ad.targetSelected == self.vehicle.ad.targetSelected then
            otherVehicle = vehicle
        end
    end
    if otherVehicle ~= nil then
        print("Found other vehicle")
        return DriveToVehicleTask:new(self.vehicle, otherVehicle)
    end

    local nextTask
    
    local trailers, _ = AutoDrive.getTrailersOf(self.vehicle, false)
    local fillLevel, leftCapacity = AutoDrive.getFillLevelAndCapacityOfAll(trailers)
    local maxCapacity = fillLevel + leftCapacity
    local filledToUnload = (leftCapacity <= (maxCapacity * (1 - AutoDrive.getSetting("unloadFillLevel", self.vehicle) + 0.001)))

    if self.state == CombineUnloaderMode.STATE_INIT then
        if filledToUnload then
            nextTask = UnloadAtDestinationTask:new(self.vehicle, self.vehicle.ad.targetSelected_Unload)
            self.state = CombineUnloaderMode.STATE_DRIVE_TO_UNLOAD
        else
            self:setToWaitForCall()
        end
    elseif self.state == CombineUnloaderMode.STATE_DRIVE_TO_COMBINE then
        -- we finished the precall to combine route
        -- check if we should wait / pull up to combines pipe
        if AutoDrive.getSetting("chaseCombine", self.vehicle) or (self.currentCombine ~= nil and self.currentCombine:getIsBufferCombine()) then            
            nextTask = FollowCombineTask:new(self.vehicle, self.currentCombine)
            self.state = CombineUnloaderMode.STATE_ACTIVE_UNLOAD_COMBINE
        else
            self:setToWaitForCall()
        end
    elseif self.state == CombineUnloaderMode.STATE_DRIVE_TO_PIPE then
        -- this task is finished when the combine is emptied / trailer is filled 
        -- we should create the reversing maneuver anyhow, just to avoid collisions with a CP driven combine
        nextTask = ReverseFromCombineTask:new(self.vehicle)
        self.state = CombineUnloaderMode.STATE_REVERSE_FROM_PIPE
    elseif self.state == CombineUnloaderMode.STATE_REVERSE_FROM_PIPE then
        nextTask = self:getTaskAfterUnload(filledToUnload)
    elseif self.state == CombineUnloaderMode.STATE_LEAVE_CROP then
        self:setToWaitForCall()
    elseif self.state == CombineUnloaderMode.STATE_DRIVE_TO_UNLOAD then
        nextTask = DriveToDestinationTask:new(self.vehicle, self.vehicle.ad.targetSelected)
        self.state = CombineUnloaderMode.STATE_DRIVE_TO_START
    elseif self.state == CombineUnloaderMode.STATE_DRIVE_TO_START then
        self:setToWaitForCall()
    elseif self.state == CombineUnloaderMode.STATE_ACTIVE_UNLOAD_COMBINE then
        nextTask = self:getTaskAfterUnload(filledToUnload)
    end

    return nextTask
end

function CombineUnloaderMode:setToWaitForCall()
    -- We just have to wait to be wait to be called (again)
    self.state = CombineUnloaderMode.STATE_WAIT_TO_BE_CALLED
    --register as available unloader - finish harvesterManager first
end

function CombineUnloaderMode:getTaskAfterUnload(filledToUnload)
    local nextTask
    if filledToUnload then
        nextTask = UnloadAtDestinationTask:new(self.vehicle, self.vehicle.ad.targetSelected_Unload)
        self.state = CombineUnloaderMode.STATE_DRIVE_TO_UNLOAD
    else
        -- Should we not park in the field?
        if AutoDrive.getSetting("parkInField", self.vehicle) then           
            -- If we are in fruit, we should clear it
            if self:isParkedInFruit() then
                nextTask = ClearCropTask:new(self.vehicle)
                self.state = CombineUnloaderMode.STATE_LEAVE_CROP
            else
                -- We just have to wait to be wait to be called (again)
                self.state = CombineUnloaderMode.STATE_WAIT_TO_BE_CALLED
                --register as available unloader - finish harvesterManager first
            end
        else
            nextTask = DriveToDestinationTask:new(self.vehicle, self.vehicle.ad.targetSelected)
            self.state = CombineUnloaderMode.STATE_DRIVE_TO_START
        end
    end
    return nextTask
end

function CombineUnloaderMode:shouldUnloadAtTrigger()
    return self.state == CombineUnloaderMode.STATE_DELIVER and (AutoDrive.getDistanceToUnloadPosition(self.vehicle) <= AutoDrive.getSetting("maxTriggerDistance"))
end

function CombineUnloaderMode:shouldLoadOnTrigger()
    return self.state == CombineUnloaderMode.STATE_PICKUP and (AutoDrive.getDistanceToTargetPosition(self.vehicle) <= AutoDrive.getSetting("maxTriggerDistance"))
end

function CombineUnloaderMode:getExcludedVehiclesForCollisionCheck()
    local excludedVehicles = {}
    if self.assignedCombine ~= nil and self:ignoreCombineCollision() then
        table.insert(excludedVehicles, self.assignedCombine)
    end
    
    return excludedVehicles
end

function CombineUnloaderMode:ignoreCombineCollision()
    if (self.combineState == AutoDrive.DRIVE_TO_COMBINE or self.combineState == AutoDrive.PREDRIVE_COMBINE or self.combineState == AutoDrive.CHASE_COMBINE) then
		return true
	end
    
    return false
end

function CombineUnloaderMode:isParkedInFruit()
    local trailers, _ = AutoDrive.getTrailersOf(self.vehicle)
    local trailer = trailers[self.vehicle.ad.currentTrailer]
    local trailerClear = true
    if trailer ~= nil then
        if trailer.ad == nil then
            trailer.ad = {}
        end
        ADSensor:handleSensors(trailer, dt)
        trailer.ad.sensors.centerSensorFruit.frontFactor = -1
        trailerClear = not trailer.ad.sensors.centerSensorFruit:pollInfo()
    end

    if trailerClear and not vehicle.ad.sensors.centerSensorFruit:pollInfo() and not vehicle.ad.sensors.rearSensorFruit:pollInfo() then
        return false
    end
    
    return true
end
