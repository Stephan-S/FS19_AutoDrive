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

CombineUnloaderMode.CHASEPOS_LEFT = 1
CombineUnloaderMode.CHASEPOS_RIGHT = -1
CombineUnloaderMode.CHASEPOS_REAR = 3

CombineUnloaderMode.MAX_COMBINE_FILLLEVEL_CHASING = 90

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
                nextTask = ClearCropTask:new(self.vehicle)
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

function CombineUnloaderMode:getDischargeNode()
    local dischargeNode = nil
    for _, dischargeNodeIter in pairs(self.combine.spec_dischargeable.dischargeNodes) do
        dischargeNode = dischargeNodeIter
    end
    if self.combine.getPipeDischargeNodeIndex ~= nil then
        dischargeNode = self.combine.spec_dischargeable.dischargeNodes[self.combine:getPipeDischargeNodeIndex()]
    end
    return dischargeNode.node
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

function CombineUnloaderMode:getPipeRoot()
    local count = 0
    local pipeRoot = self:getDischargeNode()
    local parentStack = Buffer:new()
    local combineNode = self.combine.components[1].node
    AutoDrive.debugPrint(self.combine, AutoDrive.DC_COMBINEINFO, "CombineUnloaderMode:getPipeRoot - Combine Node " .. combineNode .. " " .. self:getNodeName(combineNode))
    
    while (pipeRoot ~= combineNode) and (count < 100) and (pipeRoot ~= nil) do
        parentStack:Insert(pipeRoot)
        pipeRoot = getParent(pipeRoot)
        if pipeRoot == 0 or pipeRoot == nil then
            -- Something unexpected happened, like the discharge node not belonging to self.combine.
            -- This can happen with harvesters with multiple components
            -- KNOWN ISSUE: The Panther 2 beet harvester triggers this condition
            return combineNode
        end
        count = count + 1
    end

    local translationMagnitude = 0
    local pipeRootX, pipeRootY, pipeRootZ = getTranslation(pipeRoot)
    -- Pop the first thing off the stack. This should refer to a large chunk of the harvester and it useless
    -- for our purposes.
    -- Another clue: The index path of our root should include a '|' character. Don't know what that means
    -- programtically yet.
    -- parentStack:Get()
    while ((translationMagnitude < 0.01) or 
            ((pipeRootY < 0) or (math.abs(pipeRootX) > self.combine.sizeLength/2) or (math.abs(pipeRootY) > self.combine.sizeWidth/2)) or
            (AutoDrive.sign(pipeRootX) ~= self:getPipeSide()) and
            parentStack:Count() > 0) do
        pipeRoot = parentStack:Get()
        pipeRootX, pipeRootY, pipeRootZ = getTranslation(pipeRoot)

        translationMagnitude = MathUtil.vector3Length(pipeRootX, pipeRootY, pipeRootZ)
        AutoDrive.debugPrint(self.combine, AutoDrive.DC_COMBINEINFO, "CombineUnloaderMode:getPipeTranslationRoot - Search Stack " .. pipeRoot .. " " .. self:getNodeName(pipeRoot) .. " " .. translationMagnitude)
    end

    return pipeRoot
end

function CombineUnloaderMode:getPipeRootZOffset()
    local combineNode = self.combine.components[1].node
    local pipeRoot = self:getPipeRoot()
    local pipeRootX, pipeRootY, pipeRootZ = getWorldTranslation(pipeRoot)
    local _, _, diffZ = worldToLocal(combineNode, pipeRootX, pipeRootY, pipeRootZ)
    AutoDrive.debugPrint(self.combine, AutoDrive.DC_COMBINEINFO, "CombineUnloaderMode:getPipeRootZOffset - " .. diffZ )
    return diffZ
end

function CombineUnloaderMode:getPipeSide()
    local combineNode = self.combine.components[1].node
    local dischargeNode = self:getDischargeNode()
    local dischargeX, dichargeY, dischargeZ = getWorldTranslation(dischargeNode)
    local diffX, _, _ = worldToLocal(combineNode, dischargeX, dichargeY, dischargeZ)
    return AutoDrive.sign(diffX)
end

function CombineUnloaderMode:getPipeLength()
    local pipeRootX, _ , pipeRootZ = getWorldTranslation(self:getPipeRoot())
    local dischargeX, dischargeY, dischargeZ = getWorldTranslation(self:getDischargeNode())
    local length = MathUtil.vector3Length(pipeRootX - dischargeX, 
                                          0, 
                                          pipeRootZ - dischargeZ)
    AutoDrive.debugPrint(self.combine, AutoDrive.DC_COMBINEINFO, "CombineUnloaderMode:getPipeLength - " .. length)
    return length
end

function CombineUnloaderMode:getPipeSlopeCorrection()
    local combineNode = self.combine.components[1].node
    local combineX, combineY, combineZ = getWorldTranslation(combineNode)
    local nodeX, nodeY, nodeZ = getWorldTranslation(self:getDischargeNode())
    local heightUnderCombine = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, combineX, combineY, combineZ)
    local heightUnderPipe = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, nodeX, nodeY, nodeZ)
    -- want this to be negative if the ground is lower under the pipe
    local dh = heightUnderPipe - heightUnderCombine
    local hyp = MathUtil.vector3Length(combineX - nodeX, heightUnderCombine - heightUnderPipe, combineZ - nodeZ)
    local run = math.sqrt(hyp * hyp - dh * dh)
    local elevationCorrection = (hyp + (nodeY - heightUnderPipe) * (dh/hyp)) - run
    return elevationCorrection * self:getPipeSide()
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
    AutoDrive.debugPrint(self.vehicle, AutoDrive.DC_COMBINEINFO, "CombineUnloaderMode:getTargetTrailer - " ..
    currentTrailer .. "/" .. trailerCount .. ":" .. trailerFillLevel .. "/" .. trailerLeftCapacity)
    return targetTrailer, fillRatio
end

function CombineUnloaderMode:isSugarcaneHarvester(combine)
    local isSugarCaneHarvester = true
    for _, implement in pairs(combine:getAttachedImplements()) do
        if implement ~= nil and implement ~= combine and (implement.object == nil or implement.object ~= combine) then
            isSugarCaneHarvester = false
        end
    end
    return isSugarCaneHarvester
end

function CombineUnloaderMode:getPipeChasePosition()
    local worldX, worldY, worldZ = getWorldTranslation(self.combine.components[1].node)
    local vehicleX, _, vehicleZ = getWorldTranslation(self.vehicle.components[1].node)
    local rx, _, rz = localDirectionToWorld(self.combine.components[1].node, 0, 0, 1)
    local combineVector = {x = rx, z = rz}
    local combineNormalVector = {x = -combineVector.z, z = combineVector.x}

    local chaseNode = {x = worldX, y = worldY, z = worldZ}
    local sideIndex = self.CHASEPOS_REAR

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
        elseif not self:isSugarcaneHarvester(self.combine) then
            chaseNode = rearChasePos
            sideIndex = self.CHASEPOS_REAR
        end
    end

    local targetTrailer, targetTrailerFillRatio = self:getTargetTrailer()
    local dischargeNode = self:getDischargeNode()
    local pipeSide = self:getPipeSide()
    -- Slope correction is a very fickle thing for buffer harvesters since you can't know
    -- whether the pipe will be on the same side as the chase.
    --local slopeCorrection = self:getPipeSlopeCorrection(self.combine.components[1].node, dischargeNode.node)
    local slopeCorrection = self:getPipeSlopeCorrection()
    local pipeOffset = AutoDrive.getSetting("pipeOffset", self.vehicle)
    local followDistance = AutoDrive.getSetting("followDistance", self.vehicle)
    -- Using the implement width would be a better heuristic on X than the combine.
    --local sideChaseTermX = (self.combine.sizeWidth/2)*3 + pipeOffset
    --local sideChaseTermX = (self.combine.sizeWidth/2) + self:getPipeLength() + pipeOffset
    local sideChaseTermX = math.max(targetTrailer.sizeWidth/2, self.vehicle.sizeWidth/2) + self:getPipeLength() + pipeOffset
    
    local trailerX, trailerY, trailerZ = getWorldTranslation(targetTrailer.components[1].node)
    local _, _, diffZ = worldToLocal(self.vehicle.components[1].node, trailerX, trailerY, trailerZ)
    -- We gradually move the chose node forward as a function of fill level to more efftively fill
    -- buffer combines. We start ot at the front of the trailer +4 units. We use an exponential
    -- to increase dwell time towards the front of the trailer, since loads migrate towards the back.
    local ZConstantAdditions = self:getPipeRootZOffset() + 2 
    local sideChaseTermZ = -diffZ - (targetTrailer.sizeLength / 2) + ZConstantAdditions --+ (targetTrailer.sizeLength - 1 - ZConstantAdditions) ^ targetTrailerFillRatio
    --AutoDrive.debugPrint(self.vehicle, AutoDrive.DC_COMBINEINFO, "CombineUnloaderMode:getPipeChasePosition - " .. 
    --slopeCorrection .. " " .. AutoDrive.getSetting("pipeOffset", self.vehicle) .. " " .. pipeOffset .. " " .. sideChaseTermX*pipeSide ..
    --" " .. sideChaseTermZ)
    if self.combine.getIsBufferCombine ~= nil and self.combine:getIsBufferCombine() then
        if not CombineUnloaderMode:isSugarcaneHarvester(self.combine) then
            sideChaseTermZ = sideChaseTermZ - self.combine.sizeLength/2 - followDistance
        end
        AutoDrive.debugPrint(self.vehicle, AutoDrive.DC_COMBINEINFO, "CombineUnloaderMode:getPipeChasePosition:IsBufferCombine")
        local leftChasePos = AutoDrive.createWayPointRelativeToVehicle(self.combine, sideChaseTermX  + slopeCorrection, sideChaseTermZ)
        local rightChasePos = AutoDrive.createWayPointRelativeToVehicle(self.combine, -sideChaseTermX  + slopeCorrection, sideChaseTermZ)
        --if CombineUnloaderMode:isSugarcaneHarvester(self.combine) then
            -- Sugarcane harvesters don't need to be precise and never have their pipe in the right place
        --    leftChasePos = AutoDrive.createWayPointRelativeToVehicle(self.combine, sideChaseTermX , sideChaseTermZ)
        --    rightChasePos = AutoDrive.createWayPointRelativeToVehicle(self.combine, -sideChaseTermX, sideChaseTermZ)
        --end
        local rearChasePos = AutoDrive.createWayPointRelativeToVehicle(self.combine, 0, -followDistance - (self.combine.sizeLength / 2))
        local angleToLeftChaseSide = self:getAngleToChasePos(leftChasePos)
        local angleToRearChaseSide = self:getAngleToChasePos(rearChasePos)
        chaseNode = leftChasePos
        sideIndex = self.CHASEPOS_LEFT
        if (not leftBlocked) and angleToLeftChaseSide < angleToRearChaseSide then
            chaseNode = leftChasePos
            sideIndex = self.CHASEPOS_LEFT
        elseif (not rightBlocked) then
            chaseNode = rightChasePos
            sideIndex = self.CHASEPOS_RIGHT
        end
    else
        AutoDrive.debugPrint(self.vehicle, AutoDrive.DC_COMBINEINFO, "CombineUnloaderMode:getPipeChasePosition:IsNormalCombine")
        local combineFillLevel, combineLeftCapacity = AutoDrive.getFilteredFillLevelAndCapacityOfAllUnits(self.combine)
        local combineMaxCapacity = combineFillLevel + combineLeftCapacity
        local combineFillPercent = (combineFillLevel / combineMaxCapacity) * 100

        if (((pipeSide == self.CHASEPOS_LEFT and not leftBlocked) or 
             (pipeSide == self.CHASEPOS_RIGHT and not rightBlocked)) and 
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
            sideIndex = self.CHASEPOS_REAR
            chaseNode = AutoDrive.createWayPointRelativeToVehicle(self.combine, 0, -followDistance - (self.combine.sizeLength / 2) - AutoDrive.getTractorAndTrailersLength(self.vehicle, true))
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
