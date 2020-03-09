AutoDrive.DEADLOCKSPEED = 5

function AutoDrive:initializeAD(vehicle, dt)
    vehicle.ad.timeTillDeadLock = 15000

    if vehicle.ad.mode == AutoDrive.MODE_UNLOAD and vehicle.ad.combineState ~= AutoDrive.COMBINE_UNINITIALIZED then
        if AutoDrive:initializeADCombine(vehicle, dt) == true then
            return
        end
    elseif vehicle.ad.usePathFinder ~= nil and vehicle.ad.usePathFinder == true then
        if AutoDrive:handlePathPlanning(vehicle, dt) == false then
            return
        end
        vehicle.ad.usePathFinder = false
    else
        local closest = AutoDrive:findMatchingWayPointForVehicle(vehicle)
        if vehicle.ad.skipStart == true then
            vehicle.ad.skipStart = false
            if AutoDrive.mapMarker[vehicle.ad.mapMarkerSelected_Unload] == nil then
                return
            end
            vehicle.ad.wayPoints = AutoDrive:FastShortestPath(AutoDrive.mapWayPoints, closest, AutoDrive.mapMarker[vehicle.ad.mapMarkerSelected_Unload].name, AutoDrive.mapMarker[vehicle.ad.mapMarkerSelected_Unload].id)
            vehicle.ad.wayPointsChanged = true
            vehicle.ad.onRouteToSecondTarget = true
            vehicle.ad.combineState = AutoDrive.DRIVE_TO_UNLOAD_POS
        else
            if vehicle.ad.mode == AutoDrive.MODE_UNLOAD and vehicle.ad.combineState == AutoDrive.COMBINE_UNINITIALIZED then --decide if we are already on field and are allowed to park on field then
                local x, _, z = getWorldTranslation(vehicle.components[1].node)
                local node = AutoDrive.mapWayPoints[closest]
                if AutoDrive.getSetting("parkInField", vehicle) and AutoDrive.getDistance(x, z, node.x, node.z) > 20 then
                    AutoDrive.waitingUnloadDrivers[vehicle] = vehicle
                    vehicle.ad.combineState = AutoDrive.WAIT_FOR_COMBINE
                    vehicle.ad.wayPoints = {}
                    vehicle.ad.isPaused = true
                    vehicle.ad.initialized = true
                    return
                end
            end

            if AutoDrive.mapMarker[vehicle.ad.mapMarkerSelected] == nil then
                return
            end
            vehicle.ad.wayPoints = AutoDrive:FastShortestPath(AutoDrive.mapWayPoints, closest, AutoDrive.mapMarker[vehicle.ad.mapMarkerSelected].name, vehicle.ad.targetSelected)
            vehicle.ad.wayPointsChanged = true
            vehicle.ad.onRouteToSecondTarget = false
        end

        if vehicle.ad.wayPoints ~= nil then
            if vehicle.ad.wayPoints[2] == nil and vehicle.ad.wayPoints[1] ~= nil and vehicle.ad.wayPoints[1].id ~= vehicle.ad.targetSelected then
                AutoDriveMessageEvent.sendMessageOrNotification(vehicle, MessagesManager.messageTypes.ERROR, "$l10n_AD_Driver_of; %s $l10n_AD_cannot_reach; %s", 5000, vehicle.ad.driverName, vehicle.ad.nameOfSelectedTarget)
                AutoDrive:stopAD(vehicle, true)
            end

            if vehicle.ad.wayPoints[2] ~= nil then
                vehicle.ad.currentWayPoint = 2
            else
                vehicle.ad.currentWayPoint = 1
            end
        end
    end

    if vehicle.ad.wayPoints ~= nil and vehicle.ad.wayPoints[vehicle.ad.currentWayPoint] ~= nil then
        vehicle.ad.targetX = vehicle.ad.wayPoints[vehicle.ad.currentWayPoint].x
        vehicle.ad.targetZ = vehicle.ad.wayPoints[vehicle.ad.currentWayPoint].z
        vehicle.ad.initialized = true
        vehicle.ad.drivingForward = true
        if (not vehicle.ad.isUnloading) and (not vehicle.ad.isLoading) then
            vehicle.ad.isPaused = false
        end
    else
        g_logManager:devError("[AutoDrive] Encountered a problem during initialization - shutting down")
        AutoDriveMessageEvent.sendMessage(vehicle, MessagesManager.messageTypes.ERROR, "Encountered a problem during initialization, shutting down!", 3000)
        AutoDrive:stopAD(vehicle, true)
    end
end

function AutoDrive:handleReachedWayPoint(vehicle)
    --vehicle.ad.lastSpeed = vehicle.ad.speedOverride
    vehicle.ad.timeTillDeadLock = 15000

    if vehicle.ad.wayPoints[vehicle.ad.currentWayPoint + 1] ~= nil then
        vehicle.ad.currentWayPoint = vehicle.ad.currentWayPoint + 1
        vehicle.ad.targetX = vehicle.ad.wayPoints[vehicle.ad.currentWayPoint].x
        vehicle.ad.targetZ = vehicle.ad.wayPoints[vehicle.ad.currentWayPoint].z
    else
        if (vehicle.ad.mode ~= AutoDrive.MODE_PICKUPANDDELIVER or (vehicle.ad.loopCounterCurrent ~= 0 and vehicle.ad.loopCounterCurrent == vehicle.ad.loopCounterSelected)) and vehicle.ad.mode ~= AutoDrive.MODE_UNLOAD and (vehicle.ad.mode ~= AutoDrive.MODE_LOAD) then
            local target = vehicle.ad.nameOfSelectedTarget
            for _, mapMarker in pairs(AutoDrive.mapMarker) do
                if vehicle.ad.wayPoints[vehicle.ad.currentWayPoint] ~= nil and mapMarker.id == vehicle.ad.wayPoints[vehicle.ad.currentWayPoint].id then
                    target = mapMarker.name
                end
            end
            AutoDriveMessageEvent.sendNotification(vehicle, MessagesManager.messageTypes.INFO, "$l10n_AD_Driver_of; %s $l10n_AD_has_reached; %s", 5000, vehicle.ad.driverName, target)
            AutoDrive:stopAD(vehicle, false)
        else
            if vehicle.ad.mode == AutoDrive.MODE_UNLOAD then
                AutoDrive:handleReachedWayPointCombine(vehicle)
            else
                if vehicle.ad.onRouteToSecondTarget == true then
                    vehicle.ad.timeTillDeadLock = 15000

                    local closest, _ = AutoDrive:findClosestWayPoint(vehicle)
                    if vehicle.ad.wayPoints[vehicle.ad.currentWayPoint] ~= nil then
                        closest = vehicle.ad.wayPoints[vehicle.ad.currentWayPoint].id
                    end
                    vehicle.ad.wayPoints = AutoDrive:FastShortestPath(AutoDrive.mapWayPoints, closest, AutoDrive.mapMarker[vehicle.ad.mapMarkerSelected].name, vehicle.ad.targetSelected)
                    vehicle.ad.wayPointsChanged = true
                    vehicle.ad.currentWayPoint = 1

                    if vehicle.ad.wayPoints ~= nil and vehicle.ad.wayPoints[vehicle.ad.currentWayPoint] ~= nil then
                        vehicle.ad.targetX = vehicle.ad.wayPoints[vehicle.ad.currentWayPoint].x
                        vehicle.ad.targetZ = vehicle.ad.wayPoints[vehicle.ad.currentWayPoint].z
                    end

                    if vehicle.ad.isUnloadingToBunkerSilo ~= true then
                        --vehicle.ad.isPaused = true
                        local fillLevel, leftCapacity = AutoDrive.getFillLevelAndCapacityOfAll(nil)
                        local maxCapacity = fillLevel + leftCapacity

                        if vehicle.ad.mode == AutoDrive.MODE_LOAD and (leftCapacity <= (maxCapacity * (1 - AutoDrive.getSetting("unloadFillLevel", vehicle) + 0.001))) then
                            vehicle.ad.isPaused = false
                        end
                    end
                    vehicle.ad.onRouteToSecondTarget = false
                else
                    vehicle.ad.timeTillDeadLock = 15000

                    if vehicle.ad.callBackFunction ~= nil or (vehicle.ad.mode == AutoDrive.MODE_LOAD) then
                        AutoDrive:stopAD(vehicle, false)
                        return
                    end

                    if vehicle.ad.mode == AutoDrive.MODE_PICKUPANDDELIVER then
                        if AutoDrive.getSetting("distributeToFolder", vehicle) and AutoDrive.getSetting("useFolders") then
                            AutoDrive:setNextTargetInFolder(vehicle)
                        end

                        local closest, _ = AutoDrive:findClosestWayPoint(vehicle)
                        if vehicle.ad.wayPoints[vehicle.ad.currentWayPoint] ~= nil then
                            closest = vehicle.ad.wayPoints[vehicle.ad.currentWayPoint].id
                        end
                        vehicle.ad.wayPoints = AutoDrive:FastShortestPath(AutoDrive.mapWayPoints, closest, AutoDrive.mapMarker[vehicle.ad.mapMarkerSelected_Unload].name, AutoDrive.mapMarker[vehicle.ad.mapMarkerSelected_Unload].id)
                        if vehicle.ad.wayPoints[1] ~= nil then
                            vehicle.ad.wayPointsChanged = true
                            vehicle.ad.currentWayPoint = 1

                            vehicle.ad.targetX = vehicle.ad.wayPoints[vehicle.ad.currentWayPoint].x
                            vehicle.ad.targetZ = vehicle.ad.wayPoints[vehicle.ad.currentWayPoint].z
                            vehicle.ad.onRouteToSecondTarget = true
                        end
                    end

                    if vehicle.ad.startedLoadingAtTrigger == false then
                        vehicle.ad.isPaused = true
                        vehicle.ad.waitingToBeLoaded = true
                    end

                    vehicle.ad.loopCounterCurrent = vehicle.ad.loopCounterCurrent + 1
                end
            end
            vehicle.ad.startedLoadingAtTrigger = false
        end
    end
end

function AutoDrive.handleRefueling(vehicle, dt)
    if AutoDrive.Triggers == nil or (((vehicle.ad.isActive == false) or (not AutoDrive.getSetting("autoRefuel", vehicle))) and not vehicle.ad.onRouteToRefuel) then
        return
    end
    if AutoDrive.hasToRefuel(vehicle) and (not vehicle.ad.onRouteToRefuel) and (not AutoDrive:checkIsOnField(vehicle)) then
        AutoDrive.goToRefuelStation(vehicle)
    end

    if vehicle.ad.onRouteToRefuel then
        AutoDrive.startRefuelingWhenInRange(vehicle, dt)
    end
end
