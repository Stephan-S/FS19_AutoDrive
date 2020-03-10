EmptyHarvesterTask = ADInheritsFrom(AbstractTask)

EmptyHarvesterTask.STATE_PATHPLANNING = 1
EmptyHarvesterTask.STATE_DRIVING = 2
EmptyHarvesterTask.STATE_UNLOADING = 3
EmptyHarvesterTask.STATE_REVERSING = 4
EmptyHarvesterTask.STATE_WAITING = 5

EmptyHarvesterTask.REVERSE_TIME = 7000

function EmptyHarvesterTask:new(vehicle, combine)
    local o = EmptyHarvesterTask:create()
    o.vehicle = vehicle
    o.combine = combine
    o.state = EmptyHarvesterTask.STATE_PATHPLANNING
    o.wayPoints = nil
    o.reverseStartLocation = nil
    o.waitTimer = AutoDriveTON:new()
    return o
end

function EmptyHarvesterTask:setUp()
    AutoDrive.debugPrint(vehicle, AutoDrive.DC_COMBINEINFO, "Setting up EmptyHarvesterTask")
    self.vehicle.ad.pathFinderModule:startPathPlanningToPipe(self.combine, false)
end

function EmptyHarvesterTask:update(dt)
    if self.state == EmptyHarvesterTask.STATE_PATHPLANNING then
        if self.vehicle.ad.pathFinderModule:hasFinished() then
            self.wayPoints = self.vehicle.ad.pathFinderModule:getPath()
            self.vehicle.ad.drivePathModule:setWayPoints(self.wayPoints)
            if self.wayPoints == nil or #self.wayPoints == 0 then                
                self:finished()
            else
                AutoDrive.debugPrint(vehicle, AutoDrive.DC_COMBINEINFO, "EmptyHarvesterTask:update - next: EmptyHarvesterTask.STATE_DRIVING")
                self.state = EmptyHarvesterTask.STATE_DRIVING
            end
        else
            self.vehicle.ad.pathFinderModule:update()
            self.vehicle.ad.specialDrivingModule:stopVehicle()
            self.vehicle.ad.specialDrivingModule:update(dt)
        end
    elseif self.state == EmptyHarvesterTask.STATE_DRIVING then
        if self.vehicle.ad.drivePathModule:isTargetReached() then
            AutoDrive.debugPrint(vehicle, AutoDrive.DC_COMBINEINFO, "EmptyHarvesterTask:update - next: EmptyHarvesterTask.STATE_UNLOADING 1")
            self.state = EmptyHarvesterTask.STATE_UNLOADING
        else
            if self.combine.getDischargeState ~= nil and self.combine:getDischargeState() ~= Dischargeable.DISCHARGE_STATE_OFF then
                AutoDrive.debugPrint(vehicle, AutoDrive.DC_COMBINEINFO, "EmptyHarvesterTask:update - next: EmptyHarvesterTask.STATE_UNLOADING 2")
                self.state = EmptyHarvesterTask.STATE_UNLOADING
            else
                self.vehicle.ad.drivePathModule:update(dt)
            end
        end
    elseif self.state == EmptyHarvesterTask.STATE_UNLOADING then
        -- Stopping CP drivers for now
        if self.combine.cp and self.combine.cp.driver and self.combine.cp.driver.holdForUnloadOrRefill then
            self.combine.cp.driver:holdForUnloadOrRefill()
        end

        --Check if the combine is moving / has already moved away and we are supposed to actively unload
        if self.combine.ad.stoppedTimer > 0 then
            self:finished()
        end

        if self.combine.getDischargeState ~= nil and self.combine:getDischargeState() ~= Dischargeable.DISCHARGE_STATE_OFF then
            self.vehicle.ad.specialDrivingModule:stopVehicle()
            self.vehicle.ad.specialDrivingModule:update(dt)
        else
            --Is the current trailer filled or is the combine empty?
            local combineFillLevel, _ = AutoDrive.getFilteredFillLevelAndCapacityOfAllUnits(self.combine)
            local trailers, _ = AutoDrive.getTrailersOf(self.vehicle, false)
            local _, leftCapacity = AutoDrive.getFillLevelAndCapacityOfAll(trailers)
            local distanceToCombine = AutoDrive.getDistanceBetween(self.vehicle, self.combine)

            if combineFillLevel <= 0.1 or leftCapacity <= 0.1 then
                local x, y, z = getWorldTranslation(self.vehicle.components[1].node)
                self.reverseStartLocation = {x=x, y=y, z=z}
                AutoDrive.debugPrint(vehicle, AutoDrive.DC_COMBINEINFO, "EmptyHarvesterTask:update - next: EmptyHarvesterTask.STATE_REVERSING")
                self.state = EmptyHarvesterTask.STATE_REVERSING
            else
                -- Drive forward with collision checks active and only for a limited distance
                if distanceToCombine > 30 then
                    self:finished()
                else
                    self.vehicle.ad.specialDrivingModule:driveForward(dt)
                end
            end
        end
    elseif self.state == EmptyHarvesterTask.STATE_REVERSING then
        local x, y, z = getWorldTranslation(self.vehicle.components[1].node)
        local distanceToReversStart = MathUtil.vector2Length(x - self.reverseStartLocation.x, z - self.reverseStartLocation.z)
        if distanceToReversStart > 10 then
            AutoDrive.debugPrint(vehicle, AutoDrive.DC_COMBINEINFO, "EmptyHarvesterTask:update - next: EmptyHarvesterTask.STATE_WAITING")
            self.state = EmptyHarvesterTask.STATE_WAITING
        else
            self.vehicle.ad.specialDrivingModule:driveReverse(dt, 15, 1)
        end
    elseif self.state == EmptyHarvesterTask.STATE_WAITING then
        self.waitTimer:timer(true, EmptyHarvesterTask.REVERSE_TIME, dt)
        if self.waitTimer:done() then
            self:finished()
        else
            self.vehicle.ad.specialDrivingModule:stopVehicle()
            self.vehicle.ad.specialDrivingModule:update(dt)
        end
    end
end

function EmptyHarvesterTask:abort()
end

function EmptyHarvesterTask:finished()
    AutoDrive.debugPrint(vehicle, AutoDrive.DC_COMBINEINFO, "EmptyHarvesterTask:finished()")
    self.vehicle.ad.taskModule:setCurrentTaskFinished()
end
