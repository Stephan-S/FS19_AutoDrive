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
CombineUnloaderMode.STATE_REVERSE_FROM_BAD_LOCATION = 12

CombineUnloaderMode.MAX_COMBINE_FILLLEVEL_CHASING = 101
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
    self.failedPathFinder = 0
end

function CombineUnloaderMode:start()
    AutoDrive.debugPrint(self.vehicle, AutoDrive.DC_COMBINEINFO, "[AD] CombineUnloaderMode:start start self.state %s", tostring(self.state))
    if not self.vehicle.ad.stateModule:isActive() then
        self.vehicle:startAutoDrive()
    end

    if self.vehicle.ad.stateModule:getFirstMarker() == nil or self.vehicle.ad.stateModule:getSecondMarker() == nil then
        return
    end

    self:reset()
    self.activeTask = self:getNextTask()
    if self.activeTask ~= nil then
        self.vehicle.ad.taskModule:addTask(self.activeTask)
    end
    AutoDrive.debugPrint(self.vehicle, AutoDrive.DC_COMBINEINFO, "[AD] CombineUnloaderMode:start end self.state %s", tostring(self.state))
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
    --We are stuck
    if self.failedPathFinder >= 5 or ((self.vehicle.ad.specialDrivingModule:shouldStopMotor() or self.vehicle.ad.specialDrivingModule.stoppedTimer:done()) and self.vehicle.ad.specialDrivingModule.isBlocked) then
        AutoDrive.debugPrint(self.vehicle, AutoDrive.DC_COMBINEINFO, "CombineUnloaderMode:monitorTasks() - detected stuck vehicle - try reversing out of it now")
        self.vehicle.ad.specialDrivingModule:releaseVehicle()
        self.vehicle.ad.taskModule:abortAllTasks()
        self.activeTask = ReverseFromBadLocationTask:new(self.vehicle)
        self.state = self.STATE_REVERSE_FROM_BAD_LOCATION
        self.vehicle.ad.taskModule:addTask(self.activeTask)
        self.failedPathFinder = 0
    end

    if self.vehicle.lastSpeedReal > 0.0013 then
        self.failedPathFinder = 0
    end

    if self.combine ~= nil and self.combine.getIsBufferCombine ~= nil then
        self.combineIsBufferCombine = self.combine:getIsBufferCombine()
    end
end

function CombineUnloaderMode:notifyAboutFailedPathfinder()
    --print("CombineUnloaderMode:notifyAboutFailedPathfinder() - blocked: " .. AutoDrive.boolToString(self.vehicle.ad.pathFinderModule.completelyBlocked) .. " distance: " .. ADGraphManager:getDistanceFromNetwork(self.vehicle))
    if self.vehicle.ad.pathFinderModule.completelyBlocked and ADGraphManager:getDistanceFromNetwork(self.vehicle) > 20 then
        self.failedPathFinder = self.failedPathFinder + 1
    --print("Increased Failed pathfinder count to: " .. self.failedPathFinder)
    end
end

function CombineUnloaderMode:leaveBreadCrumbs()
    local x, y, z = getWorldTranslation(self.vehicle.components[1].node)
    local rx, _, rz = localDirectionToWorld(self.vehicle.components[1].node, 0, 0, 1)

    if self.lastBreadCrumb == nil then
        self.lastBreadCrumb = {x = x, y = y, z = z, dirX = rx, dirZ = rz}
        self.breadCrumbs:Enqueue(self.lastBreadCrumb)
    else
        if (self.vehicle.lastSpeedReal * self.vehicle.movingDirection) > 0 then
            local _, _, diffZ = worldToLocal(self.vehicle.components[1].node, self.lastBreadCrumb.x, self.lastBreadCrumb.y, self.lastBreadCrumb.z)
            local vec1 = {x = x - self.lastBreadCrumb.x, z = z - self.lastBreadCrumb.z}
            local angleToNewPoint = AutoDrive.angleBetween({x = self.lastBreadCrumb.dirX, z = self.lastBreadCrumb.dirZ}, vec1)
            local minDistance = 2.5
            if math.abs(angleToNewPoint) > 40 then
                minDistance = 15
            end
            if diffZ < -1 and MathUtil.vector2Length(x - self.lastBreadCrumb.x, z - self.lastBreadCrumb.z) > minDistance and math.abs(angleToNewPoint) < 90 then
                self.lastBreadCrumb = {x = x, y = y, z = z, dirX = vec1.x, dirZ = vec1.z}
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
    local x, y, z = getWorldTranslation(self.vehicle.components[1].node)
    local point = nil
    local distanceToStart = 0
    if
        self.vehicle.ad ~= nil and ADGraphManager.getWayPointById ~= nil and self.vehicle.ad.stateModule ~= nil and self.vehicle.ad.stateModule.getFirstMarker ~= nil and self.vehicle.ad.stateModule:getFirstMarker() ~= nil and
            self.vehicle.ad.stateModule:getFirstMarker() ~= 0 and
            self.vehicle.ad.stateModule:getFirstMarker().id ~= nil
     then
        point = ADGraphManager:getWayPointById(self.vehicle.ad.stateModule:getFirstMarker().id)
        if point ~= nil then
            distanceToStart = MathUtil.vector2Length(x - point.x, z - point.z)
        end
    end

    if self.state == self.STATE_DRIVE_TO_UNLOAD then
        AutoDrive.debugPrint(self.vehicle, AutoDrive.DC_PATHINFO, "[AD] CombineUnloaderMode:continue self.STATE_DRIVE_TO_UNLOAD")
        self.activeTask:continue()
    else
        AutoDrive.debugPrint(self.vehicle, AutoDrive.DC_PATHINFO, "[AD] CombineUnloaderMode:continue self.state" .. tostring(self.state))
        self.vehicle.ad.taskModule:abortCurrentTask()

        if AutoDrive.checkIsOnField(x, y, z) and distanceToStart > 30 then
            -- is activated on a field - use ExitFieldTask to leave field according to setting
            AutoDrive.debugPrint(self.vehicle, AutoDrive.DC_PATHINFO, "[AD] CombineUnloaderMode:continue ExitFieldTask...")
            self.activeTask = ExitFieldTask:new(self.vehicle)
            self.state = self.STATE_EXIT_FIELD
        else
            if (AutoDrive.getSetting("rotateTargets", self.vehicle) == AutoDrive.RT_ONLYDELIVER or AutoDrive.getSetting("rotateTargets", self.vehicle) == AutoDrive.RT_PICKUPANDDELIVER) and AutoDrive.getSetting("useFolders") then
                local nextTarget = ADMultipleTargetsManager:getNextTarget(self.vehicle, false)
                if nextTarget ~= nil then
                    self.vehicle.ad.stateModule:setSecondMarker(nextTarget)
                end
            end
            AutoDrive.debugPrint(self.vehicle, AutoDrive.DC_PATHINFO, "[AD] CombineUnloaderMode:continue UnloadAtDestinationTask...")
            self.activeTask = UnloadAtDestinationTask:new(self.vehicle, self.vehicle.ad.stateModule:getSecondMarker().id)
            self.state = self.STATE_DRIVE_TO_UNLOAD
        end

        ADHarvestManager:unregisterAsUnloader(self.vehicle)
        self.followingUnloader = nil
        self.combine = nil
        self.vehicle.ad.taskModule:addTask(self.activeTask)
    end
end

function CombineUnloaderMode:getNextTask()
    AutoDrive.debugPrint(self.vehicle, AutoDrive.DC_COMBINEINFO, "[AD] CombineUnloaderMode:getNextTask start self.state %s", tostring(self.state))
    local nextTask

    local x, y, z = getWorldTranslation(self.vehicle.components[1].node)
    local point = nil
    local distanceToStart = 0
    if
        self.vehicle.ad ~= nil and ADGraphManager.getWayPointById ~= nil and self.vehicle.ad.stateModule ~= nil and self.vehicle.ad.stateModule.getFirstMarker ~= nil and self.vehicle.ad.stateModule:getFirstMarker() ~= nil and
            self.vehicle.ad.stateModule:getFirstMarker() ~= 0 and
            self.vehicle.ad.stateModule:getFirstMarker().id ~= nil
     then
        point = ADGraphManager:getWayPointById(self.vehicle.ad.stateModule:getFirstMarker().id)
        if point ~= nil then
            distanceToStart = MathUtil.vector2Length(x - point.x, z - point.z)
        end
    end

    local trailers, _ = AutoDrive.getTrailersOf(self.vehicle, false)
    local fillLevel, leftCapacity = AutoDrive.getFillLevelAndCapacityOfAll(trailers)
    local maxCapacity = fillLevel + leftCapacity
    local filledToUnload = (leftCapacity <= (maxCapacity * (1 - AutoDrive.getSetting("unloadFillLevel", self.vehicle) + 0.001)))

    if self.state == self.STATE_INIT then
        AutoDrive.debugPrint(self.vehicle, AutoDrive.DC_COMBINEINFO, "[AD] CombineUnloaderMode:getNextTask STATE_INIT filledToUnload %s", tostring(filledToUnload))
        if filledToUnload then -- fill level above setting unload level
            if (AutoDrive.getSetting("rotateTargets", self.vehicle) == AutoDrive.RT_ONLYDELIVER or AutoDrive.getSetting("rotateTargets", self.vehicle) == AutoDrive.RT_PICKUPANDDELIVER) and AutoDrive.getSetting("useFolders") then
                local nextTarget = ADMultipleTargetsManager:getNextTarget(self.vehicle, false)
                if nextTarget ~= nil then
                    self.vehicle.ad.stateModule:setSecondMarker(nextTarget)
                end
            end

            nextTask = self:getTaskAfterUnload(filledToUnload)

            ADHarvestManager:unregisterAsUnloader(self.vehicle)
            self.followingUnloader = nil
            self.combine = nil
        else
            if not AutoDrive.checkIsOnField(x, y, z) then
                nextTask = DriveToDestinationTask:new(self.vehicle, self.vehicle.ad.stateModule:getFirstMarker().id)
                self.state = self.STATE_DRIVE_TO_START
            else
                self:setToWaitForCall()
            end
        end
        AutoDrive.debugPrint(self.vehicle, AutoDrive.DC_COMBINEINFO, "[AD] CombineUnloaderMode:getNextTask - STATE_INIT end self.state %s", tostring(self.state))
    elseif self.state == self.STATE_DRIVE_TO_COMBINE then
        AutoDrive.debugPrint(self.vehicle, AutoDrive.DC_COMBINEINFO, "[AD] CombineUnloaderMode:getNextTask - STATE_DRIVE_TO_COMBINE")
        -- we finished the precall to combine route
        -- check if we should wait / pull up to combines pipe
        nextTask = FollowCombineTask:new(self.vehicle, self.combine)
        self.state = self.STATE_ACTIVE_UNLOAD_COMBINE
        self.breadCrumbs = Queue:new()
        self.lastBreadCrumb = nil
    elseif self.state == self.STATE_DRIVE_TO_PIPE or self.state == self.STATE_REVERSE_FROM_BAD_LOCATION then
        AutoDrive.debugPrint(self.vehicle, AutoDrive.DC_COMBINEINFO, "[AD] CombineUnloaderMode:getNextTask - STATE_DRIVE_TO_PIPE | STATE_REVERSE_FROM_BAD_LOCATION")
        --Drive to pipe can be finished when combine is emptied or when vehicle has reached 'old' pipe position and should switch to active mode
        nextTask = self:getTaskAfterUnload(filledToUnload)
    elseif self.state == self.STATE_LEAVE_CROP then
        AutoDrive.debugPrint(self.vehicle, AutoDrive.DC_COMBINEINFO, "[AD] CombineUnloaderMode:getNextTask - STATE_LEAVE_CROP")
        self:setToWaitForCall()
    elseif self.state == self.STATE_DRIVE_TO_UNLOAD then
        AutoDrive.debugPrint(self.vehicle, AutoDrive.DC_COMBINEINFO, "[AD] CombineUnloaderMode:getNextTask - STATE_DRIVE_TO_UNLOAD")
        nextTask = DriveToDestinationTask:new(self.vehicle, self.vehicle.ad.stateModule:getFirstMarker().id)
        if (AutoDrive.getSetting("rotateTargets", self.vehicle) == AutoDrive.RT_ONLYDELIVER or AutoDrive.getSetting("rotateTargets", self.vehicle) == AutoDrive.RT_PICKUPANDDELIVER) and AutoDrive.getSetting("useFolders") then
            local nextTarget = ADMultipleTargetsManager:getNextTarget(self.vehicle, true)
            if nextTarget ~= nil then
                self.vehicle.ad.stateModule:setSecondMarker(nextTarget)
            end
        end
        self.state = self.STATE_DRIVE_TO_START
    elseif self.state == self.STATE_DRIVE_TO_START then
        AutoDrive.debugPrint(self.vehicle, AutoDrive.DC_COMBINEINFO, "[AD] CombineUnloaderMode:getNextTask - STATE_DRIVE_TO_START")
        self:setToWaitForCall()
    elseif self.state == self.STATE_ACTIVE_UNLOAD_COMBINE then
        AutoDrive.debugPrint(self.vehicle, AutoDrive.DC_COMBINEINFO, "[AD] CombineUnloaderMode:getNextTask - STATE_ACTIVE_UNLOAD_COMBINE")
        nextTask = self:getTaskAfterUnload(filledToUnload)
    elseif self.state == self.STATE_FOLLOW_CURRENT_UNLOADER then
        AutoDrive.debugPrint(self.vehicle, AutoDrive.DC_COMBINEINFO, "[AD] CombineUnloaderMode:getNextTask - STATE_FOLLOW_CURRENT_UNLOADER")
        if self.targetUnloader ~= nil then
            self.targetUnloader.ad.modes[AutoDrive.MODE_UNLOAD]:unregisterFollowingUnloader()
        end
        nextTask = self:getTaskAfterUnload(filledToUnload)
    elseif self.state == self.STATE_EXIT_FIELD then
        AutoDrive.debugPrint(self.vehicle, AutoDrive.DC_COMBINEINFO, "[AD] CombineUnloaderMode:getNextTask - STATE_EXIT_FIELD")
        if (AutoDrive.getSetting("rotateTargets", self.vehicle) == AutoDrive.RT_ONLYDELIVER or AutoDrive.getSetting("rotateTargets", self.vehicle) == AutoDrive.RT_PICKUPANDDELIVER) and AutoDrive.getSetting("useFolders") then
            local nextTarget = ADMultipleTargetsManager:getNextTarget(self.vehicle, false)
            if nextTarget ~= nil then
                self.vehicle.ad.stateModule:setSecondMarker(nextTarget)
            end
        end
        nextTask = UnloadAtDestinationTask:new(self.vehicle, self.vehicle.ad.stateModule:getSecondMarker().id)
        self.state = self.STATE_DRIVE_TO_UNLOAD
    end

    AutoDrive.debugPrint(self.vehicle, AutoDrive.DC_PATHINFO, "[AD] CombineUnloaderMode:getNextTask end self.state %s", tostring(self.state))
    return nextTask
end

function CombineUnloaderMode:setToWaitForCall()
    AutoDrive.debugPrint(self.vehicle, AutoDrive.DC_COMBINEINFO, "[AD] CombineUnloaderMode:setToWaitForCall start self.state %s", self.state)
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
            local cFillRatio = cfillLevel / (cfillLevel + cleftCapacity)
            local cpIsCalling = false
            if harvester.cp and harvester.cp.driver and harvester.cp.driver.isWaitingForUnload then
                cpIsCalling = harvester.cp.driver:isWaitingForUnload()
            end

            if (self.combine.getIsBufferCombine == nil or not self.combine:getIsBufferCombine()) and (self.combine.ad.noMovementTimer.elapsedTime > 500 or cleftCapacity < 1.0 or cpIsCalling or cFillRatio > 0.945) then
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
    AutoDrive.debugPrint(self.vehicle, AutoDrive.DC_PATHINFO, "[AD] CombineUnloaderMode:getTaskAfterUnload start filledToUnload %s", tostring(filledToUnload))

    local x, y, z = getWorldTranslation(self.vehicle.components[1].node)
    local point = nil
    local distanceToStart = 0
    if
        self.vehicle.ad ~= nil and ADGraphManager.getWayPointById ~= nil and self.vehicle.ad.stateModule ~= nil and self.vehicle.ad.stateModule.getFirstMarker ~= nil and self.vehicle.ad.stateModule:getFirstMarker() ~= nil and
            self.vehicle.ad.stateModule:getFirstMarker() ~= 0 and
            self.vehicle.ad.stateModule:getFirstMarker().id ~= nil
     then
        point = ADGraphManager:getWayPointById(self.vehicle.ad.stateModule:getFirstMarker().id)
        if point ~= nil then
            distanceToStart = MathUtil.vector2Length(x - point.x, z - point.z)
        end
    end

    if filledToUnload then
        --ADHarvestManager:unregisterAsUnloader(self.vehicle)
        --self.followingUnloader = nil
        --self.combine = nil
        if AutoDrive.checkIsOnField(x, y, z) and distanceToStart > 30 then
            -- is activated on a field - use ExitFieldTask to leave field according to setting
            AutoDrive.debugPrint(self.vehicle, AutoDrive.DC_PATHINFO, "[AD] CombineUnloaderMode:getTaskAfterUnload ExitFieldTask...")
            nextTask = ExitFieldTask:new(self.vehicle)
            self.state = self.STATE_EXIT_FIELD
        else
            AutoDrive.debugPrint(self.vehicle, AutoDrive.DC_PATHINFO, "[AD] CombineUnloaderMode:getTaskAfterUnload UnloadAtDestinationTask...")
            nextTask = UnloadAtDestinationTask:new(self.vehicle, self.vehicle.ad.stateModule:getSecondMarker().id)
            self.state = self.STATE_DRIVE_TO_UNLOAD
        end
    else
        -- Should we park in the field?
        if self.combineIsBufferCombine or (AutoDrive.getSetting("parkInField", self.vehicle) or (self.lastTask ~= nil and self.lastTask.stayOnField)) then
            -- If we are in fruit, we should clear it
            if AutoDrive.isVehicleOrTrailerInCrop(self.vehicle, true) then
                AutoDrive.debugPrint(self.vehicle, AutoDrive.DC_PATHINFO, "[AD] CombineUnloaderMode:getTaskAfterUnload ClearCropTask...")
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
    AutoDrive.debugPrint(self.vehicle, AutoDrive.DC_PATHINFO, "[AD] CombineUnloaderMode:getTaskAfterUnload end")
    return nextTask
end

function CombineUnloaderMode:shouldLoadOnTrigger()
    return false
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

function CombineUnloaderMode:getUnloaderOnSide()
    local vehicleX, vehicleY, vehicleZ = getWorldTranslation(self.vehicle.components[1].node)
    local combineX, combineY, combineZ = getWorldTranslation(self.combine.components[1].node)

    --local diffX, _, _ = worldToLocal(self.vehicle.components[1].node, combineX, combineY, combineZ)
    local diffX, _, diffZ = worldToLocal(self.combine.components[1].node, vehicleX, vehicleY, vehicleZ)
    local leftright = AutoDrive.CHASEPOS_UNKNOWN
    local frontback = AutoDrive.CHASEPOS_FRONT
    -- If we're not clearly on one side or the other of the combine, we don't
    -- give a clear answer
    if math.abs(diffX) > self.combine.sizeWidth / 2 then
        leftright = AutoDrive.sign(diffX)
    end

    local maxZ = AutoDrive.getTractorTrainLength(self.vehicle, true, false)
    if diffZ < maxZ then
        frontback = AutoDrive.CHASEPOS_REAR
    end

    return leftright, frontback
end

function CombineUnloaderMode:isUnloaderOnCorrectSide(chaseSide)
    local sideIndex = chaseSide

    if sideIndex == nil and self.chasePosIndex == nil then
        return false
    elseif sideIndex == nil then
        sideIndex = self.chasePosIndex
    end

    local leftRight, frontBack = self:getUnloaderOnSide()
    if (leftRight == sideIndex and frontBack == AutoDrive.CHASEPOS_REAR) or (leftRight == AutoDrive.CHASEPOS_UNKNOWN and frontBack == AutoDrive.CHASEPOS_REAR) or frontBack == sideIndex then
        return true
    else
        return false
    end
end

function CombineUnloaderMode:getPipeSlopeCorrection2()
    self.combineNode = self.combine.components[1].node
    local dischargeX, dichargeY, dischargeZ = getWorldTranslation(AutoDrive.getDischargeNode(self.combine))
    local diffX, diffY, _ = worldToLocal(self.combineNode, dischargeX, dichargeY, dischargeZ)
    if math.abs(diffX) < self.combine.sizeWidth / 2 then
        -- Some pipes curl up so tight they cause a collisions.
        -- We just don't try to correct in this case.
        return 0
    end

    local heightUnderPipe = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, dischargeX, dichargeY, dischargeZ)
    -- It would be nice if we could use the discharge node direction and the terrain under the harveser,
    -- but discharge node rotations are untrustworthy.
    wux, wuy, wuz = getTerrainNormalAtWorldPos(g_currentMission.terrainRootNode, dischargeX, dichargeY - heightUnderPipe, dischargeZ)
    ux, uy, uz = worldDirectionToLocal(self.combineNode, wux, wuy, wuz)

    -- This is backwards from the usual order of these variables, but I need deviation from 0 and pi, not
    -- pi/2 and 3pi/4, so we adjust the coordinate system
    local theta = math.atan(ux / uy)

    local pipePosition = diffX * math.cos(theta) + diffY * math.sin(theta)
    local currentElevationCorrection = pipePosition - diffX

    if math.abs(currentElevationCorrection) > 1 then
        -- Assume something has gone very wrong if the correction gets too large.
        return 0
    end

    return currentElevationCorrection
end

function CombineUnloaderMode:getPipeSlopeCorrection1()
    self.combineNode = self.combine.components[1].node
    self.combineX, self.combineY, self.combineZ = getWorldTranslation(self.combineNode)
    local nodeX, nodeY, nodeZ = getWorldTranslation(AutoDrive.getDischargeNode(self.combine))
    local heightUnderCombine = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, self.combineX, self.combineY, self.combineZ)
    local heightUnderPipe = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, nodeX, nodeY, nodeZ)
    -- want this to be negative if the ground is lower under the pipe
    local dh = heightUnderPipe - heightUnderCombine
    local hyp = MathUtil.vector3Length(self.combineX - nodeX, heightUnderCombine - heightUnderPipe, self.combineZ - nodeZ)
    local run = math.sqrt(hyp * hyp - dh * dh)
    local elevationCorrection = (hyp + (nodeY - heightUnderPipe) * (dh / hyp)) - run
    return elevationCorrection * self.pipeSide
end

function CombineUnloaderMode:getPipeSlopeCorrection()
    return self:getPipeSlopeCorrection2()
end

function CombineUnloaderMode:getTargetTrailer()
    local trailers, trailerCount = AutoDrive.getTrailersOf(self.vehicle, false)
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
    local pipeOffset = AutoDrive.getSetting("pipeOffset", self.vehicle)
    local unloaderWidest = math.max(self.vehicle.sizeWidth, self.targetTrailer.sizeWidth)
    local headerExtra = math.max((AutoDrive.getFrontToolWidth(self.combine) - self.combine.sizeWidth) / 2, 0)

    local sideChaseTermPipeIn = self.combine.sizeWidth / 2 + unloaderWidest + headerExtra
    local sideChaseTermPipeOut = self.combine.sizeWidth / 2 + (AutoDrive.getPipeLength(self.combine))
    -- Some combines fold up their pipe so tight that targeting it could cause a collision.
    -- So, choose the max between the two to avoid a collison
    local sideChaseTermX = math.max(sideChaseTermPipeIn, sideChaseTermPipeOut)

    local spec = self.combine.spec_pipe
    if self.combine:getIsBufferCombine() and not AutoDrive.isSugarcaneHarvester(self.combine) then
        sideChaseTermX = sideChaseTermPipeIn + CombineUnloaderMode.STATIC_X_OFFSET_FROM_HEADER
    elseif (self.combine.ad ~= nil and self.combine.ad.storedPipeLength ~= nil) or (spec.currentState == spec.targetState and (spec.currentState == 2 or self.combine.typeName == "combineCutterFruitPreparer")) then
        -- If the pipe is extended, though, target it regardless
        sideChaseTermX = sideChaseTermPipeOut
    end

    return sideChaseTermX + pipeOffset
end

function CombineUnloaderMode:getDynamicSideChaseOffsetZ()
    -- The default maximum will place the front of the unloader at the back of the header
    local pipeZOffsetToCombine = 0
    if AutoDrive.isPipeOut(self.combine) then
        local nodeX, nodeY, nodeZ = getWorldTranslation(AutoDrive.getDischargeNode(self.combine))
        local _, _, diffZ = worldToLocal(self.combine.components[1].node, nodeX, nodeY, nodeZ)
        pipeZOffsetToCombine = diffZ
    end
    local vehicleX, vehicleY, vehicleZ = getWorldTranslation(self.vehicle.components[1].node)
    local _, _, diffZ = worldToLocal(self.targetTrailer.components[1].node, vehicleX, vehicleY, vehicleZ)

    -- We gradually move the chase node forward as a function of fill level because it's pretty and
    -- helps the sugarcane harvester. We start at at the front of the trailer. We use an exponential
    -- to increase dwell time towards the front of the trailer, since loads migrate towards the back.

    -- The constant additions should put at precisely at the joint of the vehicle and trailer, then correct for
    -- only moving the midpoint of the tractor
    local constantAdditionsZ = 1 + self.vehicle.sizeLength / 2 - self.targetTrailer.sizeLength / 2
    -- We then gradually move back, but don't use the last part of trailer for cosmetic reasons
    local dynamicAdditionsZ = diffZ + pipeZOffsetToCombine
    dynamicAdditionsZ = dynamicAdditionsZ + math.max((self.targetTrailer.sizeLength * 0.5 - 2) ^ self.targetTrailerFillRatio, 0)
    local sideChaseTermZ = constantAdditionsZ + dynamicAdditionsZ
    return sideChaseTermZ
end

function CombineUnloaderMode:getSideChaseOffsetZ(dynamic)
    if dynamic then
        return self:getDynamicSideChaseOffsetZ()
    else
        return (self.combine.sizeLength - self.vehicle.sizeLength + AutoDrive.getFrontToolLength(self.combine)) / 2
    end
end

function CombineUnloaderMode:getRearChaseOffsetX(leftBlocked, rightBlocked)
    local rearChaseOffset = (self.combine.sizeWidth / 2 + math.max(self.vehicle.sizeWidth, self.targetTrailer.sizeWidth) / 2) + 1

    if self.combine:getIsBufferCombine() and not AutoDrive.isSugarcaneHarvester(self.combine) then
        return 0
    elseif rightBlocked and leftBlocked then
        return 0
    elseif leftBlocked then
        return -rearChaseOffset
    else
        return rearChaseOffset
    end
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
        if AutoDrive.isSugarcaneHarvester(self.combine) then
            rearChaseOffset = -self.combine.sizeLength / 2 - AutoDrive.getTractorTrainLength(self.vehicle, true, false) * math.sqrt(2)
        else
            if self.combine.lastSpeedReal > 0.002 and self.combine.ad.sensors.frontSensorFruit:pollInfo() then
                rearChaseOffset = -10
            else
                --there is no need to be close to the rear of the harvester here. We can make it hard on the pathfinder since we have no strong desire to chase there anyway for normal harvesters
                --Especially when they are CP driven, we have to be prepared for that massive reverse maneuver when the combine is filled and wants to avoid the crop.
                rearChaseOffset = -45
            end
        end
    end

    return rearChaseOffset
end

function CombineUnloaderMode:getPipeChasePosition(planningPhase)
    self.combineNode = self.combine.components[1].node
    self.combineX, self.combineY, self.combineZ = getWorldTranslation(self.combineNode)

    local chaseNode
    local sideIndex = AutoDrive.CHASEPOS_REAR

    local leftBlocked = self.combine.ad.sensors.leftSensorFruit:pollInfo() or self.combine.ad.sensors.leftSensor:pollInfo() or (AutoDrive.getSetting("followOnlyOnField", self.vehicle) and (not self.combine.ad.sensors.leftSensorField:pollInfo()))
    local leftFrontBlocked = self.combine.ad.sensors.leftFrontSensorFruit:pollInfo() or self.combine.ad.sensors.leftFrontSensor:pollInfo()
    local rightBlocked = self.combine.ad.sensors.rightSensorFruit:pollInfo() or self.combine.ad.sensors.rightSensor:pollInfo() or (AutoDrive.getSetting("followOnlyOnField", self.vehicle) and (not self.combine.ad.sensors.rightSensorField:pollInfo()))
    local rightFrontBlocked = self.combine.ad.sensors.rightFrontSensorFruit:pollInfo() or self.combine.ad.sensors.rightFrontSensor:pollInfo()
    rightBlocked = rightBlocked or rightFrontBlocked
    leftBlocked = leftBlocked or leftFrontBlocked

    -- prefer side where front is also free
    if (not leftBlocked) and (not rightBlocked) then
        if (not leftFrontBlocked) and rightFrontBlocked then
            rightBlocked = true
        elseif leftFrontBlocked and (not rightFrontBlocked) then
            leftBlocked = true
        end
    end

    self.pipeSide = AutoDrive.getPipeSide(self.combine)
    self.targetTrailer, self.targetTrailerFillRatio = self:getTargetTrailer()
    local sideChaseTermX = self:getSideChaseOffsetX()
    local sideChaseTermZ = self:getSideChaseOffsetZ(AutoDrive.experimentalFeatures.dynamicChaseDistance or not self.combine:getIsBufferCombine())
    local rearChaseTermZ = self:getRearChaseOffsetZ()

    if self.combine.getIsBufferCombine ~= nil and self.combine:getIsBufferCombine() then
        --AutoDrive.debugPrint(self.vehicle, AutoDrive.DC_COMBINEINFO, "CombineUnloaderMode:getPipeChasePosition=IsBufferCombine")
        local leftChasePos = AutoDrive.createWayPointRelativeToVehicle(self.combine, sideChaseTermX + self:getPipeSlopeCorrection(), sideChaseTermZ)
        local rightChasePos = AutoDrive.createWayPointRelativeToVehicle(self.combine, -(sideChaseTermX + self:getPipeSlopeCorrection()), sideChaseTermZ)
        local rearChasePos = AutoDrive.createWayPointRelativeToVehicle(self.combine, 0, rearChaseTermZ)
        local angleToLeftChaseSide = self:getAngleToChasePos(leftChasePos)
        local angleToRearChaseSide = self:getAngleToChasePos(rearChasePos)

        -- Default to the side of the harvester the unloader is already on
        -- then check if there is a better side
        chaseNode = leftChasePos
        sideIndex = AutoDrive.CHASEPOS_LEFT
        local unloaderPos, _ = self:getUnloaderOnSide()
        if unloaderPos == AutoDrive.CHASEPOS_RIGHT then
            chaseNode = rightChasePos
            sideIndex = AutoDrive.CHASEPOS_RIGHT
        end

        if (not leftBlocked) and ((self:isUnloaderOnCorrectSide(AutoDrive.CHASEPOS_LEFT) and angleToLeftChaseSide < angleToRearChaseSide) or planningPhase) then
            chaseNode = leftChasePos
            sideIndex = AutoDrive.CHASEPOS_LEFT
        elseif (not rightBlocked) and (self:isUnloaderOnCorrectSide(AutoDrive.CHASEPOS_RIGHT) or planningPhase) then
            chaseNode = rightChasePos
            sideIndex = AutoDrive.CHASEPOS_RIGHT
        elseif not AutoDrive.isSugarcaneHarvester(self.combine) then
            chaseNode = rearChasePos
            sideIndex = AutoDrive.CHASEPOS_REAR
        end
    else
        --AutoDrive.debugPrint(self.vehicle, AutoDrive.DC_COMBINEINFO, "CombineUnloaderMode:getPipeChasePosition:IsNormalCombine")
        local rearChaseTermX = self:getRearChaseOffsetX(leftBlocked, rightBlocked)

        local combineFillLevel, combineLeftCapacity = AutoDrive.getFilteredFillLevelAndCapacityOfAllUnits(self.combine)
        local combineMaxCapacity = combineFillLevel + combineLeftCapacity
        local combineFillPercent = (combineFillLevel / combineMaxCapacity) * 100

        local sideChasePos = AutoDrive.createWayPointRelativeToVehicle(self.combine, self.pipeSide * (sideChaseTermX + self:getPipeSlopeCorrection()), sideChaseTermZ)
        local rearChasePos = AutoDrive.createWayPointRelativeToVehicle(self.combine, rearChaseTermX, rearChaseTermZ)
        local angleToSideChaseSide = self:getAngleToChasePos(sideChasePos)
        local angleToRearChaseSide = self:getAngleToChasePos(rearChasePos)

        if
            (((self.pipeSide == AutoDrive.CHASEPOS_LEFT and not leftBlocked) or (self.pipeSide == AutoDrive.CHASEPOS_RIGHT and not rightBlocked)) and combineFillPercent < self.MAX_COMBINE_FILLLEVEL_CHASING and
                ((not AutoDrive.isSugarcaneHarvester(self.combine)) or self:isUnloaderOnCorrectSide(self.pipeSide) and math.abs(angleToSideChaseSide) < math.abs(angleToRearChaseSide))) or
                (self.combine.ad.noMovementTimer.elapsedTime > 1000)
         then
            -- Take into account a right sided harvester, e.g. potato harvester.
            chaseNode = sideChasePos
            sideIndex = self.pipeSide
        else
            sideIndex = AutoDrive.CHASEPOS_REAR
            chaseNode = rearChasePos
        end
    end

    self.chasePosIndex = sideIndex
    return chaseNode, self.chasePosIndex
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

    local vehicleX, _, vehicleZ = getWorldTranslation(self.vehicle.components[1].node)
    local combineX, _, combineZ = getWorldTranslation(self.combine.components[1].node)
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
