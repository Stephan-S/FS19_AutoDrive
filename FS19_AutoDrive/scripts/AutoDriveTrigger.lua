AutoDrive.MAX_REFUEL_TRIGGER_DISTANCE = 15
AutoDrive.REFUEL_LEVEL = 0.15

function AutoDrive.hasToRefuel(vehicle)
    local spec = vehicle.spec_motorized

    if spec.consumersByFillTypeName ~= nil and spec.consumersByFillTypeName.diesel ~= nil and spec.consumersByFillTypeName.diesel.fillUnitIndex ~= nil then
        return vehicle:getFillUnitFillLevelPercentage(spec.consumersByFillTypeName.diesel.fillUnitIndex) <= AutoDrive.REFUEL_LEVEL
    end
    
    return false;
end

function AutoDrive.startRefuelingWhenInRange(vehicle, dt)
    local refuelTrigger = ADTriggerManager.getClosestRefuelTrigger(vehicle)

    local spec = vehicle.spec_motorized
    local fillUnitIndex = spec.consumersByFillTypeName.diesel.fillUnitIndex
    local isInRange = false
    if refuelTrigger ~= nil and refuelTrigger.fillableObjects ~= nil then
        for _, fillableObject in pairs(refuelTrigger.fillableObjects) do
            if fillableObject == vehicle or (fillableObject.object ~= nil and fillableObject.object == vehicle and fillableObject.fillUnitIndex == fillUnitIndex) then
                isInRange = true
            end
        end
    end

    local isFull = vehicle:getFillUnitFillLevelPercentage(spec.consumersByFillTypeName.diesel.fillUnitIndex) >= 0.99

    if isInRange and (not refuelTrigger.isLoading) and (not isFull) then
        AutoDrive.debugPrint(vehicle, AutoDrive.DC_VEHICLEINFO, "Start refueling")
        refuelTrigger.autoStart = true
        refuelTrigger.selectedFillType = 32
        refuelTrigger:onFillTypeSelection(32)
        refuelTrigger.selectedFillType = 32
        g_effectManager:setFillType(refuelTrigger.effects, refuelTrigger.selectedFillType)
        vehicle.ad.startedRefueling = true
        vehicle.ad.isPaused = true
    else
        if vehicle.ad.startedRefueling and (not refuelTrigger.isLoading) then
            AutoDrive.debugPrint(vehicle, AutoDrive.DC_VEHICLEINFO, "Done refueling")
            vehicle.ad.startedRefueling = false
            AutoDrive.continueAfterRefueling(vehicle)
        end
    end

    if vehicle.ad.startedRefueling then
        AutoDrive:getVehicleToStop(vehicle, false, dt)
    end
end

function AutoDrive.goToRefuelStation(vehicle)
    AutoDrive.debugPrint(vehicle, AutoDrive.DC_VEHICLEINFO, "goToRefuelStation")
    vehicle.ad.storedMapMarkerSelected = vehicle.ad.mapMarkerSelected
    vehicle.ad.storedMode = vehicle.ad.mode

    local refuelDestination = ADTriggerManager.getClosestRefuelDestination(vehicle)

    if refuelDestination ~= nil then
        vehicle.ad.mapMarkerSelected = refuelDestination
        vehicle.ad.targetSelected = ADGraphManager:getMapMarkerById(vehicle.ad.mapMarkerSelected).id
        vehicle.ad.nameOfSelectedTarget = ADGraphManager:getMapMarkerById(vehicle.ad.mapMarkerSelected).name
        if AutoDrive:isActive(vehicle) then
            AutoDrive:InputHandling(vehicle, "input_start_stop") --disable if already active
        end
        vehicle.ad.mode = 1
        AutoDrive:InputHandling(vehicle, "input_start_stop")
        vehicle.ad.onRouteToRefuel = true
    end
end

function AutoDrive.continueAfterRefueling(vehicle)
    vehicle.ad.mapMarkerSelected = vehicle.ad.storedMapMarkerSelected
    vehicle.ad.targetSelected = ADGraphManager:getMapMarkerById(vehicle.ad.mapMarkerSelected).id
    vehicle.ad.nameOfSelectedTarget = ADGraphManager:getMapMarkerById(vehicle.ad.mapMarkerSelected).name
    if AutoDrive:isActive(vehicle) then
        AutoDrive:InputHandling(vehicle, "input_start_stop") --disable if already active
    end
    vehicle.ad.mode = vehicle.ad.storedMode
    AutoDrive:InputHandling(vehicle, "input_start_stop")
    vehicle.ad.onRouteToRefuel = false
end
