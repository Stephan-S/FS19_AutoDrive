RefuelTask = ADInheritsFrom(AbstractTask)

RefuelTask.STATE_PATHPLANNING = 1
RefuelTask.STATE_DRIVING = 2

function RefuelTask:new(vehicle)
    local o = RefuelTask:create()
    o.vehicle = vehicle
    o.hasRefueled = false
    return o
end

function RefuelTask:setUp()
    print("Setting up RefuelTask")
    if ADGraphManager:getDistanceFromNetwork(self.vehicle) > 30 then
        self.state = RefuelTask.STATE_PATHPLANNING
        self.vehicle.ad.pathFinderModule:startPathPlanningToNetwork(self.destinationID)
    else
        self.state = RefuelTask.STATE_DRIVING
        self.vehicle.ad.drivePathModule:setPathTo(self.destinationID)
    end
end

function RefuelTask:update(dt)
    self.refuelTrigger = ADTriggerManager.getClosestRefuelTrigger(self.vehicle)
    self.isRefueled = self.vehicle:getFillUnitFillLevelPercentage(spec.consumersByFillTypeName.diesel.fillUnitIndex) >= 0.99

    if self.state == RefuelTask.STATE_PATHPLANNING then
        if self.vehicle.ad.pathFinderModule:hasFinished() then
            self.wayPoints = self.vehicle.ad.pathFinderModule:getPath()
            self.vehicle.ad.drivePathModule:setWayPoints(self.wayPoints)
            self.vehicle.ad.drivePathModule:appendPathTo(self.destinationID)
            self.state = RefuelTask.STATE_DRIVING
        else
            self.vehicle.ad.pathFinderModule:update()
            self.vehicle.ad.specialDrivingModule:stopVehicle()
            self.vehicle.ad.specialDrivingModule:update(dt)
        end
    else
        if self.vehicle.ad.drivePathModule:isTargetReached() then
            self:finished()
        else
            if self:isInRefuelRange() and not self.hasRefueled then
                self:startRefueling()
            end
            if self.hasRefueled and not self.isRefueled then
                self.vehicle.ad.specialDrivingModule:stopVehicle()
                self.vehicle.ad.specialDrivingModule:update(dt)
            else
                self.vehicle.ad.drivePathModule:update(dt)
            end
        end
    end
end

function RefuelTask:abort()
end

function RefuelTask:finished()
    self.vehicle.ad.taskModule:setCurrentTaskFinished()
end

function RefuelTask:isInRefuelRange()
    if self.refuelTrigger ~= nil then
        local spec = self.vehicle.spec_motorized
        local fillUnitIndex = spec.consumersByFillTypeName.diesel.fillUnitIndex
        for _, fillableObject in pairs(self.refuelTrigger.fillableObjects) do
            if fillableObject == self.vehicle or (fillableObject.object ~= nil and fillableObject.object == self.vehicle and fillableObject.fillUnitIndex == fillUnitIndex) then
                return true
            end
        end
    end
    return false
end

function RefuelTask:startRefueling()
    if isInRange and (not self.refuelTrigger.isLoading) and (not self.isRefueled) then
        AutoDrive.debugPrint(self.vehicle, AutoDrive.DC_VEHICLEINFO, "Start refueling")
        self.refuelTrigger.autoStart = true
        self.refuelTrigger.selectedFillType = 32
        self.refuelTrigger:onFillTypeSelection(32)
        self.refuelTrigger.selectedFillType = 32
        self.hasRefueled = true
        g_effectManager:setFillType(self.refuelTrigger.effects, self.refuelTrigger.selectedFillType)
    end
end

function RefuelTask:getInfoText()
    if self.state == RefuelTask.STATE_PATHPLANNING then
        return g_i18n:getText("AD_task_pathfinding")
    else
        return g_i18n:getText("AD_task_drive_to_refuel_point")
    end
end