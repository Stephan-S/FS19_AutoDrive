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
CombineUnloaderMode.STATE_FOLLOW_CURRENT_UNLOADER = 10
CombineUnloaderMode.STATE_EXIT_FIELD = 11

CombineUnloaderMode.MAX_COMBINE_FILLLEVEL_CHASING = 90
CombineUnloaderMode.STATIC_X_OFFSET_FROM_HEADER = 2.7

function CombineUnloaderMode:new(vehicle)
    local o = CombineUnloaderMode:create()
    o.vehicle = vehicle
    CombineUnloaderMode.reset(o)
    return o
end

function CombineUnloaderMode:reset()
    self.state = self.STATE_INIT
    self.activeTask = nil
    ADHarvestManager:unregisterAsUnloader(self.vehicle)
    self.combine = nil
    self.followingUnloader = nil
    self.breadCrumbs = Queue:new()
    self.lastBreadCrumb = nil
end

function CombineUnloaderMode:start()
    AutoDrive.debugPrint(self.vehicle, AutoDrive.DC_COMBINEINFO, "CombineUnloaderMode:start")
    if not self.vehicle.ad.stateModule:isActive() then
        self.vehicle:startAutoDrive()
    end

    if self.vehicle.ad.stateModule:getFirstMarker() == nil or self.vehicle.ad.stateModule:getSecondMarker() == nil then
        return
    end

    self.activeTask = self:getNextTask()
    if self.activeTask ~= nil then
        self.vehicle.ad.taskModule:addTask(self.activeTask)
    end
end

function CombineUnloaderMode:monitorTasks(dt)
    if self.combine ~= nil and (self.state == self.STATE_LEAVE_CROP or self.state == self.STATE_DRIVE_TO_START or self.state == self.STATE_DRIVE_TO_UNLOAD or self.state == self.STATE_EXIT_FIELD) then
        if AutoDrive.getDistanceBetween(self.vehicle, self.combine) > 25 then
            ADHarvestManager:unregisterAsUnloader(self.vehicle)
            self.followingUnloader = nil
            self.combine = nil
        end
    end
    if self.combine ~= nil and self.state == self.STATE_ACTIVE_UNLOAD_COMBINE then
        self:leaveBreadCrumbs()
    end
end

function CombineUnloaderMode:leaveBreadCrumbs()
    local x, y, z = getWorldTranslation(self.vehicle.components[1].node)
    local rx, _, rz = localDirectionToWorld(self.vehicle.components[1].node, 0, 0, 1)

    if self.lastBreadCrumb == nil then
        self.lastBreadCrumb = {x=x, y=y, z=z, dirX=rx, dirZ=rz}
        self.breadCrumbs:Enqueue(self.lastBreadCrumb)
    else
        if (self.vehicle.lastSpeedReal * self.vehicle.movingDirection) > 0 then
            local _, _, diffZ = worldToLocal(self.vehicle.components[1].node, self.lastBreadCrumb.x, self.lastBreadCrumb.y, self.lastBreadCrumb.z)
            local vec1 = {x = x - self.lastBreadCrumb.x, z=z - self.lastBreadCrumb.z}
            local angleToNewPoint = AutoDrive.angleBetween({x=self.lastBreadCrumb.dirX, z=self.lastBreadCrumb.dirZ}, vec1)
            if diffZ < -1 and MathUtil.vector2Length(x - self.lastBreadCrumb.x, z - self.lastBreadCrumb.z) > 2.5 and math.abs(angleToNewPoint) < 90 then
                self.lastBreadCrumb = {x=x, y=y, z=z, dirX=vec1.x, dirZ=vec1.z}
                self.breadCrumbs:Enqueue(self.lastBreadCrumb)
            end
        end
    end
end

function CombineUnloaderMode:getBreadCrumbs()
    return self.breadCrumbs
end

function CombineUnloaderMode:promoteFollowingUnloader(combine)
    self.combine = combine
    if self.vehicle.ad.taskModule.activeTask ~= nil and self.vehicle.ad.taskModule.activeTask.signalPromotion ~= nil then
        self.vehicle.ad.taskModule.activeTask:signalPromotion()
    end
end


function CombineUnloaderMode:handleFinishedTask()
    AutoDrive.debugPrint(self.vehicle, AutoDrive.DC_COMBINEINFO, "CombineUnloaderMode:handleFinishedTask")
    self.vehicle.ad.trailerModule:reset()
    self.lastTask = self.activeTask
    self.activeTask = self:getNextTask()
    if self.activeTask ~= nil then
        self.vehicle.ad.taskModule:addTask(self.activeTask)
    end
end

function CombineUnloaderMode:stop()
end

function CombineUnloaderMode:continue()
    if self.state == self.STATE_DRIVE_TO_UNLOAD then
        self.activeTask:continue()
    else
        self.vehicle.ad.taskModule:abortCurrentTask()
        self.activeTask = UnloadAtDestinationTask:new(self.vehicle, self.vehicle.ad.stateModule:getSecondMarker().id)
        self.state = self.STATE_DRIVE_TO_UNLOAD
        ADHarvestManager:unregisterAsUnloader(self.vehicle)
        self.followingUnloader = nil
        self.combine = nil
        self.vehicle.ad.taskModule:addTask(self.activeTask)
    end
end

function CombineUnloaderMode:getNextTask()
    AutoDrive.debugPrint(self.vehicle, AutoDrive.DC_COMBINEINFO, "CombineUnloaderMode:getNextTask()")
    local nextTask

    local trailers, _ = AutoDrive.getTrailersOf(self.vehicle, false)
    local fillLevel, leftCapacity = AutoDrive.getFillLevelAndCapacityOfAll(trailers)
    local maxCapacity = fillLevel + leftCapacity
    local filledToUnload = (leftCapacity <= (maxCapacity * (1 - AutoDrive.getSetting("unloadFillLevel", self.vehicle) + 0.001)))

    if self.state == self.STATE_INIT then
        AutoDrive.debugPrint(self.vehicle, AutoDrive.DC_COMBINEINFO, "CombineUnloaderMode:getNextTask() - STATE_INIT")
        if filledToUnload then
            nextTask = UnloadAtDestinationTask:new(self.vehicle, self.vehicle.ad.stateModule:getSecondMarker().id)
            self.state = self.STATE_DRIVE_TO_UNLOAD
            ADHarvestManager:unregisterAsUnloader(self.vehicle)
            self.followingUnloader = nil
            self.combine = nil
        else            
            local x, y, z = getWorldTranslation(self.vehicle.components[1].node)
            if ADGraphManager:getDistanceFromNetwork(self.vehicle) < 15 and not AutoDrive.checkIsOnField(x, y, z) then
                self.state = self.STATE_DRIVE_TO_START
                nextTask = DriveToDestinationTask:new(self.vehicle, self.vehicle.ad.stateModule:getFirstMarker().id)
            else
                self:setToWaitForCall()
            end
        end
    elseif self.state == self.STATE_DRIVE_TO_COMBINE then
        AutoDrive.debugPrint(self.vehicle, AutoDrive.DC_COMBINEINFO, "CombineUnloaderMode:getNextTask() - STATE_DRIVE_TO_COMBINE")
        -- we finished the precall to combine route
        -- check if we should wait / pull up to combines pipe
        nextTask = FollowCombineTask:new(self.vehicle, self.combine)
        self.state = self.STATE_ACTIVE_UNLOAD_COMBINE
        self.breadCrumbs = Queue:new()
        self.lastBreadCrumb = nil
    elseif self.state == self.STATE_DRIVE_TO_PIPE then
        AutoDrive.debugPrint(self.vehicle, AutoDrive.DC_COMBINEINFO, "CombineUnloaderMode:getNextTask() - STATE_DRIVE_TO_PIPE")
        --Drive to pipe can be finished when combine is emptied or when vehicle has reached 'old' pipe position and should switch to active mode
        nextTask = self:getTaskAfterUnload(filledToUnload)
    elseif self.state == self.STATE_LEAVE_CROP then
        AutoDrive.debugPrint(self.vehicle, AutoDrive.DC_COMBINEINFO, "CombineUnloaderMode:getNextTask() - STATE_LEAVE_CROP")
        self:setToWaitForCall()
    elseif self.state == self.STATE_DRIVE_TO_UNLOAD then
        AutoDrive.debugPrint(self.vehicle, AutoDrive.DC_COMBINEINFO, "CombineUnloaderMode:getNextTask() - STATE_DRIVE_TO_UNLOAD")
        nextTask = DriveToDestinationTask:new(self.vehicle, self.vehicle.ad.stateModule:getFirstMarker().id)
        if AutoDrive.getSetting("distributeToFolder", self.vehicle) and AutoDrive.getSetting("useFolders") then
            self.vehicle.ad.stateModule:setNextTargetInFolder()
        end
        self.state = self.STATE_DRIVE_TO_START
    elseif self.state == self.STATE_DRIVE_TO_START then
        self:setToWaitForCall()
    elseif self.state == self.STATE_ACTIVE_UNLOAD_COMBINE then
        AutoDrive.debugPrint(self.vehicle, AutoDrive.DC_COMBINEINFO, "CombineUnloaderMode:getNextTask() - STATE_ACTIVE_UNLOAD_COMBINE")
        nextTask = self:getTaskAfterUnload(filledToUnload)
    elseif self.state == self.STATE_FOLLOW_CURRENT_UNLOADER then
        AutoDrive.debugPrint(self.vehicle, AutoDrive.DC_COMBINEINFO, "CombineUnloaderMode:getNextTask() - STATE_FOLLOW_CURRENT_UNLOADER")
        if self.targetUnloader ~= nil then
            self.targetUnloader.ad.modes[AutoDrive.MODE_UNLOAD]:unregisterFollowingUnloader()
        end
        self:setToWaitForCall()
    elseif self.state == self.STATE_EXIT_FIELD then
        AutoDrive.debugPrint(self.vehicle, AutoDrive.DC_COMBINEINFO, "CombineUnloaderMode:getNextTask() - STATE_EXIT_FIELD")
        nextTask = UnloadAtDestinationTask:new(self.vehicle, self.vehicle.ad.stateModule:getSecondMarker().id)
        self.state = self.STATE_DRIVE_TO_UNLOAD
    end

    return nextTask
end

function CombineUnloaderMode:setToWaitForCall()
    AutoDrive.debugPrint(self.vehicle, AutoDrive.DC_COMBINEINFO, "CombineUnloaderMode:getNextTask() - CombineUnloaderMode:setToWaitForCall()")
    -- We just have to wait to be wait to be called (again)
    self.state = self.STATE_WAIT_TO_BE_CALLED
    self.vehicle.ad.taskModule:addTask(WaitForCallTask:new(self.vehicle))
    if self.combine ~= nil and self.combine.ad ~= nil then
        self.combine = nil
    end
end

function CombineUnloaderMode:assignToHarvester(harvester)
    if self.state == self.STATE_WAIT_TO_BE_CALLED then
        local trailers, _ = AutoDrive.getTrailersOf(self.vehicle, false)
        AutoDrive.setAugerPipeOpen(trailers, false)

        self.vehicle.ad.taskModule:abortCurrentTask()
        self.combine = harvester
        -- if combine has extended pipe, aim for that. Otherwise DriveToVehicle and choose from there
        local spec = self.combine.spec_pipe
        if spec.currentState == spec.targetState and (spec.currentState == 2 or self.combine.typeName == "combineCutterFruitPreparer") then
            local cfillLevel, cleftCapacity = AutoDrive.getFilteredFillLevelAndCapacityOfAllUnits(self.combine)

            if (self.combine.getIsBufferCombine == nil or not self.combine:getIsBufferCombine()) and (self.combine.ad.noMovementTimer.elapsedTime > 2000 or cleftCapacity < 1.0) then
                -- default unloading - no movement
                self.state = self.STATE_DRIVE_TO_PIPE
                self.vehicle.ad.taskModule:addTask(EmptyHarvesterTask:new(self.vehicle, self.combine))
            else
                -- Probably active unloading for choppers and moving combines
                self.state = self.STATE_DRIVE_TO_COMBINE
                self.vehicle.ad.taskModule:addTask(CatchCombinePipeTask:new(self.vehicle, self.combine))
            end
        else
            self.state = self.STATE_DRIVE_TO_COMBINE
            self.vehicle.ad.taskModule:addTask(CatchCombinePipeTask:new(self.vehicle, self.combine))
        end
    end
end

function CombineUnloaderMode:driveToUnloader(unloader)
    if self.state == self.STATE_WAIT_TO_BE_CALLED then
        local trailers, _ = AutoDrive.getTrailersOf(self.vehicle, false)
        AutoDrive.setAugerPipeOpen(trailers, false)
        
        self.vehicle.ad.taskModule:abortCurrentTask()
        self.vehicle.ad.taskModule:addTask(DriveToVehicleTask:new(self.vehicle, unloader))
        unloader.ad.modes[AutoDrive.MODE_UNLOAD]:registerFollowingUnloader(self.vehicle)
        self.targetUnloader = unloader
        self.state = self.STATE_FOLLOW_CURRENT_UNLOADER
    end
end

function CombineUnloaderMode:getTaskAfterUnload(filledToUnload)
    local nextTask
    if filledToUnload then
        if ADGraphManager:getDistanceFromNetwork(self.vehicle) > 30 then
            nextTask = ExitFieldTask:new(self.vehicle)
            self.state = self.STATE_EXIT_FIELD
        else
            nextTask = UnloadAtDestinationTask:new(self.vehicle, self.vehicle.ad.stateModule:getSecondMarker().id)
            self.state = self.STATE_DRIVE_TO_UNLOAD
        end
        
        --ADHarvestManager:unregisterAsUnloader(self.vehicle)
        --self.followingUnloader = nil
        --self.combine = nil
    else
        -- Should we park in the field?
        if AutoDrive.getSetting("parkInField", self.vehicle) or (self.lastTask ~= nil and self.lastTask.stayOnField) then
            -- If we are in fruit, we should clear it
            if AutoDrive.isVehicleOrTrailerInCrop(self.vehicle) then
                nextTask = ClearCropTask:new(self.vehicle, self.combine)
                self.state = self.STATE_LEAVE_CROP
            else
                self:setToWaitForCall()
            end
        else
            ADHarvestManager:unregisterAsUnloader(self.vehicle)
            nextTask = DriveToDestinationTask:new(self.vehicle, self.vehicle.ad.stateModule:getFirstMarker().id)
            self.state = self.STATE_DRIVE_TO_START
        end
    end
    return nextTask
end

function CombineUnloaderMode:shouldLoadOnTrigger()
    return self.state == self.STATE_PICKUP and (AutoDrive.getDistanceToTargetPosition(self.vehicle) <= AutoDrive.getSetting("maxTriggerDistance"))
end

function CombineUnloaderMode:shouldUnloadAtTrigger()
    return self.state == self.STATE_DRIVE_TO_UNLOAD
end

function CombineUnloaderMode:getNodeName(node)
    if node == 0 then
        return "nil"
    end

    local name = getName(node)
    if name == nil then
        name = "nil"
    end
    return name
end

function CombineUnloaderMode:getPipeSlopeCorrection()
    local combineNode = self.combine.components[1].node
    local combineX, combineY, combineZ = getWorldTranslation(combineNode)
    local nodeX, nodeY, nodeZ = getWorldTranslation(AutoDrive.getDischargeNode(self.combine))
    local heightUnderCombine = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, combineX, combineY, combineZ)
    local heightUnderPipe = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, nodeX, nodeY, nodeZ)
    -- want this to be negative if the ground is lower under the pipe
    local dh = heightUnderPipe - heightUnderCombine
    local hyp = MathUtil.vector3Length(combineX - nodeX, heightUnderCombine - heightUnderPipe, combineZ - nodeZ)
    local run = math.sqrt(hyp * hyp - dh * dh)
    local elevationCorrection = (hyp + (nodeY - heightUnderPipe) * (dh/hyp)) - run
    return elevationCorrection * AutoDrive.getPipeSide(self.combine)
end

function CombineUnloaderMode:getUnloaderOnSide()
    local sameSide = false
    local vehicleX, vehicleY, vehicleZ = getWorldTranslation(self.vehicle.components[1].node)
    local combineX, combineY, combineZ = getWorldTranslation(self.combine.components[1].node)

    --local diffX, _, _ = worldToLocal(self.vehicle.components[1].node, combineX, combineY, combineZ)
    local diffX, _, _ = worldToLocal(self.combine.components[1].node, vehicleX, vehicleY, vehicleZ)
    return AutoDrive.sign(diffX)
end

function CombineUnloaderMode:getTargetTrailer()
    local trailers, trailerCount = AutoDrive.getTrailersOf(self.vehicle, true)
    local currentTrailer = 1
    local targetTrailer = trailers[1]
    local fillRatio = 0
    local trailerFillLevel = 0
    local trailerLeftCapacity = 0
    -- Get the next trailer that hasn't reached fill level yet
    for trailerIndex, trailer in ipairs(trailers) do
        trailerFillLevel, trailerLeftCapacity = AutoDrive.getFillLevelAndCapacityOf(targetTrailer)
        fillRatio = trailerFillLevel / (trailerFillLevel + trailerLeftCapacity)
        if (trailerLeftCapacity < 1) and currentTrailer < trailerCount then
            currentTrailer = trailerIndex
            targetTrailer = trailer
        end
    end
    --AutoDrive.debugPrint(self.vehicle, AutoDrive.DC_COMBINEINFO, "CombineUnloaderMode:getTargetTrailer - " ..
    --currentTrailer .. "/" .. trailerCount .. ":" .. trailerFillLevel .. "/" .. trailerLeftCapacity)
    return targetTrailer, fillRatio
end

function CombineUnloaderMode:getSideChaseOffsetX()
    -- NB: We cannot apply slope correction until after we have chosen which side
    -- we are chasing on! This function only finds the base X offset "to the left".
    -- Slope and side correction MUST be applied in CombineUnloaderMode:getPipeChasePosition
    -- AFTER determining the chase side. Or this function needs to be rewritten.
    local targetTrailer, targetTrailerFillRatio = self:getTargetTrailer()
    local pipeOffset = AutoDrive.getSetting("pipeOffset", self.vehicle)
    local pipeRootOffsetX, _, _= AutoDrive.getPipeRootOffset(self.combine)
    local unloaderWidest = math.max(self.vehicle.sizeWidth, targetTrailer.sizeWidth)
    local headerExtra = math.max((AutoDrive.getFrontToolWidth(self.combine) - self.combine.sizeWidth)/2,
                                0)

    local sideChaseTermPipeIn = self.combine.sizeWidth/2 +
                                unloaderWidest +
                                headerExtra +
                                CombineUnloaderMode.STATIC_X_OFFSET_FROM_HEADER
    local sideChaseTermPipeOut = self.combine.sizeWidth/2 +
                                    (AutoDrive.getPipeLength(self.combine) + pipeOffset)
    -- Some combines fold up their pipe so tight that targeting it could cause a collision.
    -- So, choose the max between the two to avoid a collison
    local sideChaseTermX = math.max(sideChaseTermPipeIn, sideChaseTermPipeOut)

    local spec = self.combine.spec_pipe
    if self.combine:getIsBufferCombine() and not AutoDrive.isSugarcaneHarvester(self.combine) then
        -- If it is a buffer combine, use the pipe in offset regardless
        sideChaseTermX = sideChaseTermPipeIn
    elseif spec.currentState == spec.targetState and (spec.currentState == 2 or self.combine.typeName == "combineCutterFruitPreparer") then
        -- If the pipe is extended, though, target it regardless
        sideChaseTermX = sideChaseTermPipeOut
    end

    return sideChaseTermX
end

function CombineUnloaderMode:getDynamicSideChaseOffsetZ()
    -- The default maximum will place the front of the unloader at the back of the header
    --local maxOffset = self.combine.sizeLength/2 - self.vehicle.sizeLength / 2
    local maxOffset = 10000--AutoDrive.getTractorTrainLength(self.vehicle, true, false)
    local spec = self.combine.spec_pipe
    --if spec.currentState == spec.targetState and (spec.currentState == 2 or self.combine.typeName == "combineCutterFruitPreparer") then
        -- If the pipe is extended, go as far forward as we like. This is a first approximation
        -- assuming the user isn't using a header which is wider than the pipe extends
        -- If the X direction collision avoidance is working, we might not need this guard?
        --maxOffset = AutoDrive.getTractorTrainLength(self.vehicle, true, false)
    --end

    local targetTrailer, targetTrailerFillRatio = self:getTargetTrailer()
    local _, _, pipeRootOffsetZ= AutoDrive.getPipeRootOffset(self.combine)
    vehicleX, vehicleY, vehicleZ = getWorldTranslation(self.vehicle.components[1].node)
    local _, _, diffZ = worldToLocal(targetTrailer.components[1].node, vehicleX, vehicleY, vehicleZ)
    
    -- We gradually move the chase node forward as a function of fill level because it's pretty and
    -- helps the sugarcane harvester. We start at at the front of the trailer. We use an exponential
    -- to increase dwell time towards the front of the trailer, since loads migrate towards the back.
    
    -- The constant additions should put at precisely at the joint of the vehicle and trailer, then correct for
    -- only moving the midpoint of the tractor
    local constantAdditionsZ = 1 + self.vehicle.sizeLength/2 - targetTrailer.sizeLength/2
    -- We then gradually move back, but don't use the last part of trailer for cosmetic reasons
    local dynamicAdditionsZ = diffZ + pipeRootOffsetZ + math.max((targetTrailer.sizeLength - self.vehicle.sizeLength/2 - 2) ^ targetTrailerFillRatio, 0)
    local sideChaseTermZ = constantAdditionsZ + dynamicAdditionsZ
    return math.min(maxOffset, sideChaseTermZ)
end

function CombineUnloaderMode:getSideChaseOffsetZ(dynamic)
    if dynamic then
        return self:getDynamicSideChaseOffsetZ()
    else
        return (self.combine.sizeLength - self.vehicle.sizeLength + AutoDrive.getFrontToolLength(self.combine) )/2
    end
end

function CombineUnloaderMode:getRearChaseOffsetX()
    local targetTrailer, targetTrailerFillRatio = self:getTargetTrailer()
    local rearChaseOffset = 0
    if self.combine.getIsBufferCombine == nil or not self.combine:getIsBufferCombine() or AutoDrive.isSugarcaneHarvester(self.combine) then
        local pipeSide = AutoDrive.getPipeSide(self.combine)
        rearChaseOffset = -pipeSide*(self.combine.sizeWidth/2 + math.max(self.vehicle.sizeWidth, targetTrailer.sizeWidth)/2)+1
    end

    return rearChaseOffset
end

function CombineUnloaderMode:getRearChaseOffsetZ()
    local followDistance = AutoDrive.getSetting("followDistance", self.vehicle)
    local rearChaseOffset = -followDistance - (self.combine.sizeLength / 2)
    if self.combine.getIsBufferCombine ~= nil and self.combine:getIsBufferCombine() and not AutoDrive.isSugarcaneHarvester(self.combine) then
        rearChaseOffset = -followDistance - (self.combine.sizeLength / 2)
    else
        -- math.sqrt(2) ensures the trailer could straighten if it was turned 90 degrees, and it makes this point further
        -- back than the pathfinder (straightening) target in PathFinderModule:startPathPlanningToPipe
        -- math.sqrt(2) gives the hypotenuse of an isosceles right trangle with side length equal to the length
        -- of the trailer 
        rearChaseOffset = -self.combine.sizeLength/2 - AutoDrive.getTractorTrainLength(self.vehicle, true, false) * math.sqrt(2)
    end

    return rearChaseOffset
end

function CombineUnloaderMode:getPipeChasePosition()
    local worldX, worldY, worldZ = getWorldTranslation(self.combine.components[1].node)
    local vehicleX, _, vehicleZ = getWorldTranslation(self.vehicle.components[1].node)
    local rx, _, rz = localDirectionToWorld(self.combine.components[1].node, 0, 0, 1)
    local combineVector = {x = rx, z = rz}
    local combineNormalVector = {x = -combineVector.z, z = combineVector.x}

    local chaseNode = {x = worldX, y = worldY, z = worldZ}
    local sideIndex = AutoDrive.CHASEPOS_REAR

    local leftBlocked = self.combine.ad.sensors.leftSensorFruit:pollInfo() or self.combine.ad.sensors.leftSensor:pollInfo() or (AutoDrive.getSetting("followOnlyOnField", self.vehicle) and (not self.combine.ad.sensors.leftSensorField:pollInfo()))
    local rightBlocked = self.combine.ad.sensors.rightSensorFruit:pollInfo() or self.combine.ad.sensors.rightSensor:pollInfo() or (AutoDrive.getSetting("followOnlyOnField", self.vehicle) and (not self.combine.ad.sensors.rightSensorField:pollInfo()))

    local leftFrontBlocked = self.combine.ad.sensors.leftFrontSensorFruit:pollInfo() or self.combine.ad.sensors.leftFrontSensor:pollInfo()
    local rightFrontBlocked = self.combine.ad.sensors.rightFrontSensorFruit:pollInfo() or self.combine.ad.sensors.rightFrontSensor:pollInfo()

    leftBlocked = leftBlocked or leftFrontBlocked
    rightBlocked = rightBlocked or rightFrontBlocked

    -- prefer side where front is also free
    if (not leftBlocked) and (not rightBlocked) then
        if (not leftFrontBlocked) and rightFrontBlocked then
            rightBlocked = true
        elseif leftFrontBlocked and (not rightFrontBlocked) then
            leftBlocked = true
        end
    end

    local dischargeNode = AutoDrive.getDischargeNode(self.combine)
    local pipeSide = AutoDrive.getPipeSide(self.combine)
    -- Slope correction is a very fickle thing for buffer harvesters since you can't know
    -- whether the pipe will be on the same side as the chase.
    local slopeCorrection = self:getPipeSlopeCorrection()

    local sideChaseTermX = self:getSideChaseOffsetX()
    local sideChaseTermZ = self:getSideChaseOffsetZ(AutoDrive.experimentalFeatures.dynamicChaseDistance)
    local rearChaseTermX = self:getRearChaseOffsetX()
    local rearChaseTermZ = self:getRearChaseOffsetZ()
    
    if self.combine.getIsBufferCombine ~= nil and self.combine:getIsBufferCombine() then
        --AutoDrive.debugPrint(self.vehicle, AutoDrive.DC_COMBINEINFO, "CombineUnloaderMode:getPipeChasePosition=IsBufferCombine")
        local leftChasePos = AutoDrive.createWayPointRelativeToVehicle(self.combine, sideChaseTermX  + slopeCorrection, sideChaseTermZ)
        local rightChasePos = AutoDrive.createWayPointRelativeToVehicle(self.combine, -sideChaseTermX  + slopeCorrection, sideChaseTermZ)
        local rearChasePos = AutoDrive.createWayPointRelativeToVehicle(self.combine, 0, rearChaseTermZ)
        local angleToLeftChaseSide = self:getAngleToChasePos(leftChasePos)
        local angleToRearChaseSide = self:getAngleToChasePos(rearChasePos)
        
        chaseNode = leftChasePos
        sideIndex = AutoDrive.CHASEPOS_LEFT
        if self:getUnloaderOnSide() == AutoDrive.CHASEPOS_RIGHT then
            chaseNode = rightChasePos
            sideIndex = AutoDrive.CHASEPOS_RIGHT
        end

        if (not leftBlocked) and angleToLeftChaseSide < angleToRearChaseSide then
            chaseNode = leftChasePos
            sideIndex = AutoDrive.CHASEPOS_LEFT
        elseif (not rightBlocked) then
            chaseNode = rightChasePos
            sideIndex = AutoDrive.CHASEPOS_RIGHT
        elseif not AutoDrive.isSugarcaneHarvester(self.combine) then
            chaseNode = rearChasePos
            sideIndex = AutoDrive.CHASEPOS_REAR
        end
    else
        --AutoDrive.debugPrint(self.vehicle, AutoDrive.DC_COMBINEINFO, "CombineUnloaderMode:getPipeChasePosition:IsNormalCombine")
        local combineFillLevel, combineLeftCapacity = AutoDrive.getFilteredFillLevelAndCapacityOfAllUnits(self.combine)
        local combineMaxCapacity = combineFillLevel + combineLeftCapacity
        local combineFillPercent = (combineFillLevel / combineMaxCapacity) * 100

        if (((pipeSide == AutoDrive.CHASEPOS_LEFT and not leftBlocked) or
             (pipeSide == AutoDrive.CHASEPOS_RIGHT and not rightBlocked)) and
             combineFillPercent < self.MAX_COMBINE_FILLLEVEL_CHASING) or self.combine.ad.noMovementTimer.elapsedTime > 1000 then
            chaseNode = AutoDrive.createWayPointRelativeToVehicle(self.combine, (sideChaseTermX * pipeSide) + slopeCorrection, sideChaseTermZ)
            -- Take into account a right sided harvester, e.g. potato harvester.
            sideIndex = pipeSide

            --local spec = self.combine.spec_pipe
            --if spec.currentState == spec.targetState and (spec.currentState == 2 or self.combine.typeName == "combineCutterFruitPreparer") then
             --   AutoDrive.debugPrint(self.vehicle, AutoDrive.DC_COMBINEINFO, "CombineUnloaderMode:getPipeChasePosition:PipeOut")
                --local dischargeNode = self:getDischargeNode()
             --   local nodeX, nodeY, nodeZ = getWorldTranslation(dischargeNode)
             --   chaseNode.x, chaseNode.y, chaseNode.z = chaseNode.x + sideChaseTermZ * rx, nodeY, chaseNode.z + sideChaseTermZ * rz
            --end
        else
            sideIndex = AutoDrive.CHASEPOS_REAR
            -- We chase off to the side to avoid collisions
            -- We chase a little further back to avoid eating dust
            --chaseNode = AutoDrive.createWayPointRelativeToVehicle(self.combine, 
            --                                                        -pipeSide*(self.combine.sizeWidth/2 + math.max(self.vehicle.sizeWidth, targetTrailer.sizeWidth)/2)+1,
            --                                                        -self.combine.sizeLength/2 - AutoDrive.getTractorTrainLength(self.vehicle, false, true) * math.sqrt(2))
            chaseNode = AutoDrive.createWayPointRelativeToVehicle(self.combine, rearChaseTermX, rearChaseTermZ)
        end
    end

    return chaseNode, sideIndex
end

function CombineUnloaderMode:getAngleToCombineHeading()
    if self.vehicle == nil or self.combine == nil then
        return math.huge
    end

    local combineRx, _, combineRz = localDirectionToWorld(self.combine.components[1].node, 0, 0, 1)
    local rx, _, rz = localDirectionToWorld(self.vehicle.components[1].node, 0, 0, 1)

    return math.abs(AutoDrive.angleBetween({x = rx, z = rz}, {x = combineRx, z = combineRz}))
end

function CombineUnloaderMode:getAngleToCombine()
    if self.vehicle == nil or self.combine == nil then
        return math.huge
    end
    
    local vehicleX, vehicleY, vehicleZ = getWorldTranslation(self.vehicle.components[1].node)
    local combineX, combineY, combineZ = getWorldTranslation(self.combine.components[1].node)
    local rx, _, rz = localDirectionToWorld(self.vehicle.components[1].node, 0, 0, 1)

    return math.abs(AutoDrive.angleBetween({x = rx, z = rz}, {x = combineX - vehicleX, z = combineZ - vehicleZ}))
end

function CombineUnloaderMode:getAngleToChasePos(chasePos)
    local worldX, _, worldZ = getWorldTranslation(self.vehicle.components[1].node)
    local rx, _, rz = localDirectionToWorld(self.vehicle.components[1].node, 0, 0, 1)
    local angle = AutoDrive.angleBetween({x = rx, z = rz}, {x = chasePos.x - worldX, z = chasePos.z - worldZ})

    return angle
end

function CombineUnloaderMode:getFollowingUnloader()
    return self.followingUnloader
end

function CombineUnloaderMode:registerFollowingUnloader(followingUnloader)
    self.followingUnloader = followingUnloader
end

function CombineUnloaderMode:unregisterFollowingUnloader()
    self.followingUnloader = nil
end
