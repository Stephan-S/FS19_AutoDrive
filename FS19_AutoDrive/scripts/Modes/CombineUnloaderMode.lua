CombineUnloaderMode = ADInheritsFrom(AbstractMode)

CombineUnloaderMode.STATE_INIT = 1
CombineUnloaderMode.STATE_WAIT_TO_BE_CALLED = 2
CombineUnloaderMode.STATE_DRIVE_TO_COMBINE = 3
CombineUnloaderMode.STATE_DRIVE_TO_PIPE = 4
CombineUnloaderMode.STATE_LEAVE_CROP = 5
CombineUnloaderMode.STATE_DRIVE_TO_START = 6
CombineUnloaderMode.STATE_DRIVE_TO_UNLOAD = 7
CombineUnloaderMode.STATE_FOLLOW_COMBINE = 8
CombineUnloaderMode.STATE_ACTIVE_UNLOAD_COMBINE = 9

CombineUnloaderMode.CHASEPOS_LEFT = 1
CombineUnloaderMode.CHASEPOS_RIGHT = 2
CombineUnloaderMode.CHASEPOS_REAR = 3

function CombineUnloaderMode:new(vehicle)
    local o = CombineUnloaderMode:create()
    o.vehicle = vehicle
    CombineUnloaderMode.reset(o)
    return o
end

function CombineUnloaderMode:reset()
    self.state = CombineUnloaderMode.STATE_INIT
    self.activeTask = nil
    self.combine = nil
	ADHarvestManager:unregisterAsUnloader(self.vehicle)
end

function CombineUnloaderMode:start()
    AutoDrive.debugPrint(vehicle, AutoDrive.DC_COMBINEINFO, "CombineUnloaderMode:start")
    if not self.vehicle.ad.stateModule:isActive() then
        AutoDrive.startAD(self.vehicle)
    end

    if vehicle.ad.stateModule:getFirstMarker() == nil or vehicle.ad.stateModule:getSecondMarker() == nil then
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
    AutoDrive.debugPrint(vehicle, AutoDrive.DC_COMBINEINFO, "CombineUnloaderMode:handleFinishedTask")
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
    AutoDrive.debugPrint(vehicle, AutoDrive.DC_COMBINEINFO, "CombineUnloaderMode:getNextTask()")
    local nextTask
    
    local trailers, _ = AutoDrive.getTrailersOf(self.vehicle, false)
    local fillLevel, leftCapacity = AutoDrive.getFillLevelAndCapacityOfAll(trailers)
    local maxCapacity = fillLevel + leftCapacity
    local filledToUnload = (leftCapacity <= (maxCapacity * (1 - AutoDrive.getSetting("unloadFillLevel", self.vehicle) + 0.001)))

    if self.state == CombineUnloaderMode.STATE_INIT then        
        AutoDrive.debugPrint(vehicle, AutoDrive.DC_COMBINEINFO, "CombineUnloaderMode:getNextTask() - STATE_INIT")
        if filledToUnload then
            nextTask = UnloadAtDestinationTask:new(self.vehicle, self.vehicle.ad.stateModule:getSecondMarker(),id)
            self.state = CombineUnloaderMode.STATE_DRIVE_TO_UNLOAD
        else
            if ADGraphManager:getDistanceFromNetwork(self.vehicle) < 15 then
                self.state = CombineUnloaderMode.STATE_DRIVE_TO_START
                nextTask = DriveToDestinationTask:new(self.vehicle, self.vehicle.ad.stateModule:getFirstMarker().id)
            else
                self:setToWaitForCall()
            end
        end
    elseif self.state == CombineUnloaderMode.STATE_DRIVE_TO_COMBINE then
        AutoDrive.debugPrint(vehicle, AutoDrive.DC_COMBINEINFO, "CombineUnloaderMode:getNextTask() - STATE_DRIVE_TO_COMBINE")
        -- we finished the precall to combine route
        -- check if we should wait / pull up to combines pipe
        if AutoDrive.getSetting("chaseCombine", self.vehicle) or (self.combine ~= nil and self.combine:getIsBufferCombine()) then            
            nextTask = FollowCombineTask:new(self.vehicle, self.combine)
            self.state = CombineUnloaderMode.STATE_ACTIVE_UNLOAD_COMBINE
        else
            self:setToWaitForCall()
        end
    elseif self.state == CombineUnloaderMode.STATE_DRIVE_TO_PIPE then
        AutoDrive.debugPrint(vehicle, AutoDrive.DC_COMBINEINFO, "CombineUnloaderMode:getNextTask() - STATE_DRIVE_TO_PIPE")
        --Drive to pipe can be finished when combine is emptied or when vehicle has reached 'old' pipe position and should switch to active mode
        nextTask = self:getTaskAfterUnload(filledToUnload)
    elseif self.state == CombineUnloaderMode.STATE_LEAVE_CROP then
        AutoDrive.debugPrint(vehicle, AutoDrive.DC_COMBINEINFO, "CombineUnloaderMode:getNextTask() - STATE_LEAVE_CROP")
        self:setToWaitForCall()
    elseif self.state == CombineUnloaderMode.STATE_DRIVE_TO_UNLOAD then
        AutoDrive.debugPrint(vehicle, AutoDrive.DC_COMBINEINFO, "CombineUnloaderMode:getNextTask() - STATE_DRIVE_TO_UNLOAD")
        nextTask = DriveToDestinationTask:new(self.vehicle, self.vehicle.ad.stateModule:getFirstMarker().id)
        self.state = CombineUnloaderMode.STATE_DRIVE_TO_START
    elseif self.state == CombineUnloaderMode.STATE_DRIVE_TO_START then
        self:setToWaitForCall()
    elseif self.state == CombineUnloaderMode.STATE_ACTIVE_UNLOAD_COMBINE then
        AutoDrive.debugPrint(vehicle, AutoDrive.DC_COMBINEINFO, "CombineUnloaderMode:getNextTask() - STATE_ACTIVE_UNLOAD_COMBINE")
        nextTask = self:getTaskAfterUnload(filledToUnload)
    end

    return nextTask
end

function CombineUnloaderMode:setToWaitForCall()
    AutoDrive.debugPrint(vehicle, AutoDrive.DC_COMBINEINFO, "CombineUnloaderMode:getNextTask() - CombineUnloaderMode:setToWaitForCall()")
    -- We just have to wait to be wait to be called (again)
    self.state = CombineUnloaderMode.STATE_WAIT_TO_BE_CALLED
    self.vehicle.ad.taskModule:addTask(WaitForCallTask:new(self.vehicle))
    if self.combine ~= nil and self.combine.ad ~= nil then
        self.combine.ad.currentDriver = nil
    end
    ADHarvestManager:registerAsUnloader(self.vehicle)
end

function CombineUnloaderMode:assignToHarvester(harvester)
    if self.state == CombineUnloaderMode.STATE_WAIT_TO_BE_CALLED then
        self.vehicle.ad.taskModule:abortCurrentTask()
        self.combine = harvester
        self.combine.ad.currentDriver = self.vehicle
        -- if combine has extended pipe, aim for that. Otherwise DriveToVehicle and choose from there
        local spec = self.combine.spec_pipe
        if spec.currentState == spec.targetState and (spec.currentState == 2 or self.combine.typeName == "combineCutterFruitPreparer") then
            local cfillLevel, cleftCapacity = AutoDrive.getFilteredFillLevelAndCapacityOfAllUnits(self.combine)
                
            if (self.combine.getIsBufferCombine == nil or not self.combine:getIsBufferCombine()) and (self.combine.ad.noMovementTimer.elapsedTime > 2000 or cleftCapacity < 1.0) then
                -- default unloading - no movement
                self.state = CombineUnloaderMode.STATE_DRIVE_TO_PIPE
                self.vehicle.ad.taskModule:addTask(EmptyHarvesterTask:new(self.vehicle, self.combine))
            else
                -- Probably active unloading for choppers and moving combines
                self.state = CombineUnloaderMode.STATE_DRIVE_TO_COMBINE
                self.vehicle.ad.taskModule:addTask(CatchCombinePipeTask:new(self.vehicle, self.combine))                
            end
        else
            self.state = CombineUnloaderMode.STATE_DRIVE_TO_COMBINE
            self.vehicle.ad.taskModule:addTask(CatchCombinePipeTask:new(self.vehicle, self.combine))
        end
    end
end

function CombineUnloaderMode:getTaskAfterUnload(filledToUnload)
    local nextTask
    if filledToUnload then
        nextTask = UnloadAtDestinationTask:new(self.vehicle, self.vehicle.ad.stateModule:getSecondMarker().id)
        self.state = CombineUnloaderMode.STATE_DRIVE_TO_UNLOAD
    else
        -- Should we park in the field?
        if AutoDrive.getSetting("parkInField", self.vehicle) then
            -- If we are in fruit, we should clear it
            if AutoDrive.isVehicleOrTrailerInCrop(self.vehicle) then
                nextTask = ClearCropTask:new(self.vehicle)
                self.state = CombineUnloaderMode.STATE_LEAVE_CROP
            else
                self:setToWaitForCall()
            end
        else
            nextTask = DriveToDestinationTask:new(self.vehicle, self.vehicle.ad.stateModule:getFirstMarker().id)
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

function CombineUnloaderMode:shouldUnloadAtTrigger()
    return self.state == CombineUnloaderMode.STATE_DRIVE_TO_UNLOAD and (AutoDrive.getDistanceToUnloadPosition(self.vehicle) <= AutoDrive.getSetting("maxTriggerDistance"))
end

function CombineUnloaderMode:getPipeChasePosition()
    local worldX, worldY, worldZ = getWorldTranslation(self.combine.components[1].node)
    local vehicleX, vehicleY, vehicleZ = getWorldTranslation(self.vehicle.components[1].node)
    local rx, _, rz = localDirectionToWorld(self.combine.components[1].node, 0, 0, 1)
    local combineVector = {x = rx, z = rz}
    local combineNormalVector = {x = -combineVector.z, z = combineVector.x}

    local chaseNode = { x=worldX, y=worldY, z=worldZ }
    local sideIndex = CombineUnloaderMode.CHASEPOS_REAR

    local leftBlocked = self.combine.ad.sensors.leftSensorFruit:pollInfo() or self.combine.ad.sensors.leftSensor:pollInfo() or (not self.combine.ad.sensors.leftSensorField:pollInfo())
    local rightBlocked = self.combine.ad.sensors.rightSensorFruit:pollInfo() or self.combine.ad.sensors.rightSensor:pollInfo() or (not self.combine.ad.sensors.rightSensorField:pollInfo())

    local leftFrontBlocked = self.combine.ad.sensors.leftFrontSensorFruit:pollInfo()
    local rightFrontBlocked = self.combine.ad.sensors.rightFrontSensorFruit:pollInfo()
    
    -- prefer side where front is also free
    if (not leftBlocked) and (not rightBlocked) then
        if (not leftFrontBlocked) and rightFrontBlocked then
            rightBlocked = true
        elseif leftFrontBlocked and (not rightFrontBlocked) then
            leftBlocked = true
        end
    end

    if self.combine.getIsBufferCombine ~= nil and self.combine:getIsBufferCombine() then
        if (not leftBlocked) then
            chaseNode = AutoDrive.createWayPointRelativeToVehicle(self.combine, 7, 3)
            sideIndex = CombineUnloaderMode.CHASEPOS_LEFT
        elseif (not rightBlocked) then
            chaseNode = AutoDrive.createWayPointRelativeToVehicle(self.combine, -7, 3)
            sideIndex = CombineUnloaderMode.CHASEPOS_RIGHT
        else
            chaseNode = AutoDrive.createWayPointRelativeToVehicle(self.combine, 0, -AutoDrive.getSetting("followDistance", self.vehicle))
            sideIndex = CombineUnloaderMode.CHASEPOS_REAR
        end
    else
        local combineFillLevel, combineLeftCapacity = AutoDrive.getFilteredFillLevelAndCapacityOfAllUnits(self.combine)
        local combineMaxCapacity = combineFillLevel + combineLeftCapacity
        local combineFillPercent = (combineFillLevel / combineMaxCapacity) * 100

        if ((not leftBlocked) and combineFillPercent < 90) or self.combine.ad.noMovementTimer.elapsedTime > 1000 then
            chaseNode = AutoDrive.createWayPointRelativeToVehicle(self.combine, 9.5, 6)
            sideIndex = CombineUnloaderMode.CHASEPOS_LEFT

            local spec = self.combine.spec_pipe
            if spec.currentState == spec.targetState and (spec.currentState == 2 or self.combine.typeName == "combineCutterFruitPreparer") then
                local dischargeNode = nil
                for _, dischargeNodeIter in pairs(self.combine.spec_dischargeable.dischargeNodes) do
                    dischargeNode = dischargeNodeIter
                end

                local pipeOffset = AutoDrive.getSetting("pipeOffset", self.vehicle)
                local trailerOffset = AutoDrive.getSetting("trailerOffset", self.vehicle)

                local trailers, trailerCount = AutoDrive.getTrailersOf(self.vehicle, true)
                local currentTrailer = 1
                local targetTrailer = trailers[1]

                -- Get the next trailer that hasn't reached fill level yet
                for trailerIndex, trailer in ipairs(trailers) do
                    local trailerFillLevel, trailerLeftCapacity = AutoDrive.getFillLevelAndCapacityOf(trailer)
                    if (trailerLeftCapacity < 0.01) and currentTrailer < trailerCount then
                        currentTrailer = trailerIndex;
                        targetTrailer = AutoDrive.getTrailersOf(self.vehicle, true)[self.vehicle.ad.currentTrailer];
                    end
                end

                local trailerX, trailerY, trailerZ = getWorldTranslation(targetTrailer.components[1].node)
                local _, _, diffZ = worldToLocal(self.vehicle.components[1].node, trailerX, trailerY, trailerZ)

                local totalDiff = -diffZ + trailerOffset + 2;

                local nodeX, nodeY, nodeZ = getWorldTranslation(dischargeNode.node)
                chaseNode.x, chaseNode.y, chaseNode.z = nodeX + totalDiff * rx - pipeOffset * combineNormalVector.x, nodeY, nodeZ + totalDiff * rz - pipeOffset * combineNormalVector.z
            end
        else
            sideIndex = CombineUnloaderMode.CHASEPOS_REAR
            chaseNode = AutoDrive.createWayPointRelativeToVehicle(self.combine, 0, -PathFinderModule.PATHFINDER_FOLLOW_DISTANCE)
        end
    end

    return chaseNode, sideIndex
end

function CombineUnloaderMode:getAngleToCombineHeading()
    if self.vehicle == nil or self.combine == nil then
        return math.huge
    end

    --local combineWorldX, combineWorldY, combineWorldZ = getWorldTranslation(combine.components[1].node)
    local combineRx, _, combineRz = localDirectionToWorld(self.combine.components[1].node, 0, 0, 1)

    --local worldX, worldY, worldZ = getWorldTranslation(vehicle.components[1].node)
    local rx, _, rz = localDirectionToWorld(self.vehicle.components[1].node, 0, 0, 1)

    return math.abs(AutoDrive.angleBetween({x = rx, z = rz}, {x = combineRx, z = combineRz}))
end