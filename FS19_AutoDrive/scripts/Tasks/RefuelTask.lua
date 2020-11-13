RefuelTask = ADInheritsFrom(AbstractTask)

RefuelTask.STATE_PATHPLANNING = 1
RefuelTask.STATE_DRIVING = 2

function RefuelTask:new(vehicle, destinationID)
    local o = RefuelTask:create()
    o.vehicle = vehicle
    o.hasRefueled = false
    o.destinationID = destinationID
    return o
end

function RefuelTask:setUp()
    if ADGraphManager:getDistanceFromNetwork(self.vehicle) > 30 then
        self.state = RefuelTask.STATE_PATHPLANNING
        self.vehicle.ad.pathFinderModule:startPathPlanningToNetwork(self.destinationID)
    else
        self.state = RefuelTask.STATE_DRIVING
        self.vehicle.ad.drivePathModule:setPathTo(self.destinationID)
    end
    AutoDriveMessageEvent.sendNotification(self.vehicle, ADMessagesManager.messageTypes.WARN, "$l10n_AD_Driver_of; %s $l10n_AD_task_drive_to_refuel_point;", 5000, self.vehicle.ad.stateModule:getName())
end

function RefuelTask:update(dt)
    local spec = self.vehicle.spec_motorized
    self.refuelTrigger = ADTriggerManager.getClosestRefuelTrigger(self.vehicle)
    self.isRefueled = self.vehicle:getFillUnitFillLevelPercentage(spec.consumersByFillTypeName.diesel.fillUnitIndex) >= 0.99

    if self.state == RefuelTask.STATE_PATHPLANNING then
        if self.vehicle.ad.pathFinderModule:hasFinished() then
            self.wayPoints = self.vehicle.ad.pathFinderModule:getPath()
            if self.wayPoints == nil or #self.wayPoints == 0 then
                g_logManager:error("[AutoDrive] Could not calculate path - shutting down")
                self.vehicle.ad.taskModule:abortAllTasks()
                self.vehicle:stopAutoDrive()
                AutoDriveMessageEvent.sendMessageOrNotification(self.vehicle, ADMessagesManager.messageTypes.ERROR, "$l10n_AD_Driver_of; %s $l10n_AD_cannot_find_path;", 5000, self.vehicle.ad.stateModule:getName())
            else
                self.vehicle.ad.drivePathModule:setWayPoints(self.wayPoints)
                --self.vehicle.ad.drivePathModule:appendPathTo(self.wayPoints[#self.wayPoints], self.destinationID)
                self.state = RefuelTask.STATE_DRIVING
            end
        else
            self.vehicle.ad.pathFinderModule:update(dt)
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
    local callBackFunction = self.vehicle.ad.callBackFunction
    local callBackObject = self.vehicle.ad.callBackObject
    local callBackArg = self.vehicle.ad.callBackArg
    self.vehicle.ad.callBackFunction = nil
    self.vehicle.ad.callBackObject = nil
    self.vehicle.ad.callBackArg = nil

    self.vehicle:stopAutoDrive()
    self.vehicle.ad.stateModule:getCurrentMode():start()
    self.vehicle.ad.taskModule:setCurrentTaskFinished(ADTaskModule.DONT_PROPAGATE)
    
    self.vehicle.ad.callBackFunction = callBackFunction
    self.vehicle.ad.callBackObject = callBackObject
    self.vehicle.ad.callBackArg = callBackArg

end

function RefuelTask:isInRefuelRange()
    if self.refuelTrigger ~= nil and not self.refuelTrigger.isLoading then
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
    if (not self.refuelTrigger.isLoading) and (not self.isRefueled) then
        AutoDrive.debugPrint(self.vehicle, AutoDrive.DC_VEHICLEINFO, "Start refueling")
        
        local fuelFillTypeIndex = g_currentMission.fillTypeManager:getFillTypeIndexByName('DIESEL')
        
        self.refuelTrigger.autoStart = true
        self.refuelTrigger.selectedFillType = fuelFillTypeIndex
        self.refuelTrigger:onFillTypeSelection(fuelFillTypeIndex)
        self.refuelTrigger.selectedFillType = fuelFillTypeIndex
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

function RefuelTask:getI18nInfo()
    if self.state == RefuelTask.STATE_PATHPLANNING then
        return "$l10n_AD_task_pathfinding;"
    else
        return "$l10n_AD_task_drive_to_refuel_point;"
    end
end
