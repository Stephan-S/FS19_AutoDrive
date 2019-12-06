AutoDrive.DEADLOCKSPEED = 5

function AutoDrive:handleDriving(vehicle, dt)
    AutoDrive:checkActiveAttributesSet(vehicle)
    AutoDrive:checkForDeadLock(vehicle, dt)
    --AutoDrive:handlePrintMessage(vehicle, dt);
    AutoDrive.handleTrailers(vehicle, dt)
    AutoDrive:handleDeadlock(vehicle, dt)
    AutoDrive.handleRefueling(vehicle, dt)

    if vehicle.ad.isStopping == true then
        AutoDrive:stopVehicle(vehicle, dt)
        return
    end

    if vehicle.bga.isActive == true then
        return
    end

    if vehicle.components ~= nil and vehicle.isServer then
        local x, _, z = getWorldTranslation(vehicle.components[1].node)
        --local xl, yl, zl = worldToLocal(vehicle.components[1].node, x, y, z)

        if vehicle.ad.isActive == true and vehicle.ad.isPaused == false then
            if vehicle.ad.initialized == false then
                AutoDrive:initializeAD(vehicle, dt)
            else
                local min_distance = AutoDrive:defineMinDistanceByVehicleType(vehicle)
                --if AutoDrive:isOnField(vehicle) then
                --  min_distance = math.max(1, min_distance - 1)
                --end

                local closeToWayPoint = false
                if vehicle.ad.wayPoints[vehicle.ad.currentWayPoint] ~= nil and vehicle.ad.wayPoints[vehicle.ad.currentWayPoint + 1] ~= nil then
                    if AutoDrive:getDistance(x, z, vehicle.ad.wayPoints[vehicle.ad.currentWayPoint].x, vehicle.ad.wayPoints[vehicle.ad.currentWayPoint].z) < min_distance then
                        closeToWayPoint = true
                    elseif (not AutoDrive:isOnField(vehicle)) and vehicle.ad.currentWayPoint <= 3 and AutoDrive:getDistance(x, z, vehicle.ad.wayPoints[vehicle.ad.currentWayPoint].x, vehicle.ad.wayPoints[vehicle.ad.currentWayPoint].z) < (min_distance * 5) then
                        closeToWayPoint = true
                    end
                end

                if closeToWayPoint or AutoDrive:getDistance(x, z, vehicle.ad.targetX, vehicle.ad.targetZ) < min_distance then
                    AutoDrive:handleReachedWayPoint(vehicle)
                end

                if vehicle.ad.isActive == true and vehicle.isServer then
                    vehicle.ad.trafficDetected = AutoDrive:detectAdTrafficOnRoute(vehicle) or AutoDrive:detectTraffic(vehicle)

                    if vehicle.ad.isPausedCauseTraffic == true and vehicle.ad.trafficDetected == false then
                        vehicle.ad.isPaused = false
                        vehicle.ad.isPausedCauseTraffic = false
                    end

                    if vehicle.ad.wayPoints[vehicle.ad.currentWayPoint + 1] ~= nil then
                        --if vehicle.ad.combineState == AutoDrive.PREDRIVE_COMBINE then
                        --AutoDrive:checkIfShortcutToCombinePossible(vehicle, dt);
                        --end;
                        AutoDrive:driveToNextWayPoint(vehicle, dt)
                    else
                        AutoDrive:driveToLastWaypoint(vehicle, dt)
                    end
                end
            end
        end

        if vehicle.ad.isPausedCauseTraffic then
            vehicle.ad.trafficDetected = AutoDrive:detectAdTrafficOnRoute(vehicle) or AutoDrive:detectTraffic(vehicle)

            if vehicle.ad.trafficDetected == false then
                vehicle.ad.isPaused = false
                vehicle.ad.isPausedCauseTraffic = false
            end
        end

        if vehicle.ad.isPaused == true then
            AutoDrive:getVehicleToStop(vehicle, false, dt)
            vehicle.ad.timeTillDeadLock = 15000
            vehicle.ad.inDeadLock = false

            if math.abs(vehicle.lastSpeedReal) < 0.002 then
                if vehicle.ad.combineState == AutoDrive.WAIT_TILL_UNLOADED then
                    vehicle.ad.isPaused = false
                end
            end
        end
    end
end

function AutoDrive.shouldStopMotor(vehicle)
    return (vehicle.ad.combineState == AutoDrive.WAIT_FOR_COMBINE or AutoDrive.getIsStuckInTraffic(vehicle)) and vehicle.lastSpeedReal < 0.0001
end

function AutoDrive:checkActiveAttributesSet(vehicle)
    if vehicle.ad.isActive == true and vehicle.isServer then
        vehicle.forceIsActive = true
        vehicle.spec_motorized.stopMotorOnLeave = false
        vehicle.spec_enterable.disableCharacterOnLeave = false
        --vehicle.spec_aiVehicle.isActive = true

        if vehicle.steeringEnabled == true then
            vehicle.steeringEnabled = false
        end
        vehicle.spec_aiVehicle.aiTrafficCollisionTranslation[2] = -1000

        if vehicle.setBeaconLightsVisibility ~= nil and AutoDrive.getSetting("useBeaconLights") then
            if not AutoDrive:isOnField(vehicle) and vehicle.spec_motorized.isMotorStarted then
                vehicle:setBeaconLightsVisibility(true)
            else
                vehicle:setBeaconLightsVisibility(false)
            end
        end

        -- Only the server have to start/stop motor
        if vehicle.startMotor and vehicle.stopMotor then
            if not AutoDrive.shouldStopMotor(vehicle) and not vehicle.spec_motorized.isMotorStarted and vehicle:getCanMotorRun() then
                vehicle:startMotor()
            end

            if AutoDrive.shouldStopMotor(vehicle) and vehicle.spec_motorized.isMotorStarted then
                vehicle:stopMotor()
            end
        end
    end

    if not vehicle:getCanMotorRun() then
        vehicle.ad.isPaused = true
        vehicle.ad.inDeadLock = false
        vehicle.ad.timeTillDeadLock = 15000
        vehicle.ad.inDeadLockRepairCounter = 4
    end

    if vehicle.ad.isActive == true and vehicle.ad.isPaused == false then
        if vehicle.steeringEnabled then
            vehicle.steeringEnabled = false
        end
    end

    if vehicle.ad.isActive == false then
        if vehicle.currentHelper == nil then
            if vehicle.steeringEnabled == false then
                vehicle.steeringEnabled = true
            end
        end
    end
end

function AutoDrive:checkForDeadLock(vehicle, dt)
    if (vehicle.ad.isActive == true) and (vehicle.bga.isActive == false) and vehicle.isServer and vehicle.ad.isStopping == false then
        local x, _, z = getWorldTranslation(vehicle.components[1].node)
        if (AutoDrive:getDistance(x, z, vehicle.ad.targetX, vehicle.ad.targetZ) < 15) then
            vehicle.ad.timeTillDeadLock = vehicle.ad.timeTillDeadLock - dt
            if vehicle.ad.timeTillDeadLock < 0 and vehicle.ad.timeTillDeadLock ~= -1 then
                --g_logManager:devInfo("Deadlock reached due to timer");
                vehicle.ad.inDeadLock = true
            end
        else
            vehicle.ad.inDeadLock = false
            vehicle.ad.timeTillDeadLock = 15000
            vehicle.ad.inDeadLockRepairCounter = 4
        end
    else
        vehicle.ad.inDeadLock = false
        vehicle.ad.timeTillDeadLock = 15000
        vehicle.ad.inDeadLockRepairCounter = 4
    end

    if math.abs(vehicle.lastSpeedReal) <= 0.0005 then
        vehicle.ad.stoppedTimer = math.max(0, vehicle.ad.stoppedTimer - dt)
    else
        vehicle.ad.stoppedTimer = 5000
    end

    local vehicleSteering = vehicle.rotatedTime ~= nil and (math.deg(vehicle.rotatedTime) > 10)
    if (not vehicleSteering) and ((vehicle.lastSpeedReal * vehicle.movingDirection) >= 0.0008) then
        vehicle.ad.driveForwardTimer:timer(true, 12000, dt)
    else
        vehicle.ad.driveForwardTimer:timer(false)
    end
end

function AutoDrive:initializeAD(vehicle, dt)
    vehicle.ad.timeTillDeadLock = 15000

    if AutoDrive.handledRecalculation == false and AutoDrive.getSetting("autoRecalculate") then
        if AutoDrive.Recalculation ~= nil then
            if AutoDrive.Recalculation.continue == nil or AutoDrive.Recalculation.continue == false then
                AutoDrive:ContiniousRecalculation()
            end
        end
        return
    end

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
                if AutoDrive.getSetting("parkInField", vehicle) and AutoDrive:getDistance(x, z, node.x, node.z) > 20 then
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
                AutoDrive.printMessage(vehicle, g_i18n:getText("AD_Driver_of") .. " " .. vehicle.ad.driverName .. " " .. g_i18n:getText("AD_cannot_reach") .. " " .. vehicle.ad.nameOfSelectedTarget)
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
        g_logManager:error("[AutoDrive] Encountered a problem during initialization - shutting down")
        AutoDrive:stopAD(vehicle, true)
    end
end

function AutoDrive:defineMinDistanceByVehicleType(vehicle)
    local min_distance = 1.8
    if
        vehicle.typeDesc == "combine" or vehicle.typeDesc == "harvester" or vehicle.typeName == "combineDrivable" or vehicle.typeName == "selfPropelledMower" or vehicle.typeName == "woodHarvester" or vehicle.typeName == "combineCutterFruitPreparer" or vehicle.typeName == "drivableMixerWagon" or
            vehicle.typeName == "cottonHarvester" or
            vehicle.typeName == "pdlc_claasPack.combineDrivableCrawlers"
     then
        min_distance = 6
    end
    if vehicle.typeDesc == "telehandler" then
        min_distance = 3
    end
    if vehicle.typeDesc == "truck" then
        min_distance = 3
    end
    -- If vehicle is quadtrack then also min_distance = 6;
    if vehicle.spec_articulatedAxis ~= nil and vehicle.spec_articulatedAxis.rotSpeed ~= nil then
        min_distance = 6
    end
    return min_distance
end

function AutoDrive:handleReachedWayPoint(vehicle)
    --vehicle.ad.lastSpeed = vehicle.ad.speedOverride
    vehicle.ad.timeTillDeadLock = 15000

    if vehicle.ad.wayPoints[vehicle.ad.currentWayPoint + 1] ~= nil then
        vehicle.ad.currentWayPoint = vehicle.ad.currentWayPoint + 1
        vehicle.ad.targetX = vehicle.ad.wayPoints[vehicle.ad.currentWayPoint].x
        vehicle.ad.targetZ = vehicle.ad.wayPoints[vehicle.ad.currentWayPoint].z
    else
        if
            (vehicle.ad.mode ~= AutoDrive.MODE_PICKUPANDDELIVER or (vehicle.ad.loopCounterCurrent ~= 0 and vehicle.ad.loopCounterCurrent == vehicle.ad.loopCounterSelected)) and vehicle.ad.mode ~= AutoDrive.MODE_UNLOAD and
                (vehicle.ad.mode ~= AutoDrive.MODE_LOAD or not vehicle.ad.onRouteToSecondTarget)
         then
            local target = vehicle.ad.nameOfSelectedTarget
            for _, mapMarker in pairs(AutoDrive.mapMarker) do
                if vehicle.ad.wayPoints[vehicle.ad.currentWayPoint] ~= nil and mapMarker.id == vehicle.ad.wayPoints[vehicle.ad.currentWayPoint].id then
                    target = mapMarker.name
                end
            end
            AutoDrive.printMessage(vehicle, g_i18n:getText("AD_Driver_of") .. " " .. vehicle.ad.driverName .. " " .. g_i18n:getText("AD_has_reached") .. " " .. target)
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

                    vehicle.ad.targetX = vehicle.ad.wayPoints[vehicle.ad.currentWayPoint].x
                    vehicle.ad.targetZ = vehicle.ad.wayPoints[vehicle.ad.currentWayPoint].z

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

                    if vehicle.ad.callBackFunction ~= nil then
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
                        if vehicle.ad.wayPoints[vehicle.ad.currentWayPoint] ~= nil then
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

function AutoDrive:driveToNextWayPoint(vehicle, dt)
    local x, y, z = getWorldTranslation(vehicle.components[1].node)
    --local xl, yl, zl = worldToLocal(vehicle.components[1].node, vehicle.ad.targetX, y, vehicle.ad.targetZ)

    vehicle.ad.speedOverride = -1
    if vehicle.ad.wayPoints[vehicle.ad.currentWayPoint - 1] ~= nil and vehicle.ad.wayPoints[vehicle.ad.currentWayPoint + 1] ~= nil then
        --local wp_ahead = vehicle.ad.wayPoints[vehicle.ad.currentWayPoint + 1]
        --local wp_current = vehicle.ad.wayPoints[vehicle.ad.currentWayPoint]
        --local wp_ref = vehicle.ad.wayPoints[vehicle.ad.currentWayPoint - 1]
        local highestAngle = 0
        local distanceToLookAhead = math.min(15, AutoDrive.getSetting("lookAheadBraking")) --restrict lookahead braking for now and see how it goes

        local totalMass = vehicle:getTotalMass(false)
        local massFactor = math.max(1, math.min(3, (totalMass + 20) / 30))
        local speedFactor = math.max(0.5, math.min(4, (((vehicle.lastSpeedReal * 3600) + 10) / 20.0)))
        if speedFactor <= 1 then
            massFactor = 1
        end
        distanceToLookAhead = math.min(distanceToLookAhead * massFactor * speedFactor, 100)
        --g_logManager:devInfo("Default: " .. AutoDrive.getSetting("lookAheadBraking") .. " massFactor: " .. massFactor .. " speedFactor: " .. speedFactor .. " result: " .. distanceToLookAhead)

        local pointsToLookAhead = 20
        local doneCheckingRoute = false
        local currentLookAheadPoint = 1
        while not doneCheckingRoute and currentLookAheadPoint <= pointsToLookAhead do
            if vehicle.ad.wayPoints[vehicle.ad.currentWayPoint + currentLookAheadPoint] ~= nil then
                local wp_ahead = vehicle.ad.wayPoints[vehicle.ad.currentWayPoint + currentLookAheadPoint]
                local wp_current = vehicle.ad.wayPoints[vehicle.ad.currentWayPoint + currentLookAheadPoint - 1]
                local wp_ref = vehicle.ad.wayPoints[vehicle.ad.currentWayPoint + currentLookAheadPoint - 2]

                local angle = AutoDrive.angleBetween({x = wp_ahead.x - wp_ref.x, z = wp_ahead.z - wp_ref.z}, {x = wp_current.x - wp_ref.x, z = wp_current.z - wp_ref.z})
                angle = math.abs(angle)
                if
                    AutoDrive:getDistance(vehicle.ad.wayPoints[vehicle.ad.currentWayPoint].x, vehicle.ad.wayPoints[vehicle.ad.currentWayPoint].z, wp_ahead.x, wp_ahead.z) <= distanceToLookAhead and
                        AutoDrive:getDistance(vehicle.ad.wayPoints[vehicle.ad.currentWayPoint].x, vehicle.ad.wayPoints[vehicle.ad.currentWayPoint].z, x, z) <= distanceToLookAhead
                 then
                    highestAngle = math.max(highestAngle, angle)
                else
                    doneCheckingRoute = true
                end
            else
                doneCheckingRoute = true
            end
            currentLookAheadPoint = currentLookAheadPoint + 1
        end

        if highestAngle < 3 then
            vehicle.ad.speedOverride = vehicle.ad.targetSpeed
        elseif highestAngle < 5 then
            vehicle.ad.speedOverride = 38
        elseif highestAngle < 8 then
            vehicle.ad.speedOverride = 27
        elseif highestAngle < 12 then
            vehicle.ad.speedOverride = 20
        elseif highestAngle < 15 then
            vehicle.ad.speedOverride = 17
        elseif highestAngle < 20 then
            vehicle.ad.speedOverride = 16
        else
            vehicle.ad.speedOverride = 13
        end
    end

    local distanceToTarget = AutoDrive:getDistanceToLastWaypoint(vehicle, 10)

    if vehicle.ad.speedOverride == -1 then
        vehicle.ad.speedOverride = vehicle.ad.targetSpeed
    end
    if vehicle.ad.speedOverride > vehicle.ad.targetSpeed then
        vehicle.ad.speedOverride = vehicle.ad.targetSpeed
    end

    if distanceToTarget > 45 then
        -- no change
    elseif distanceToTarget > 20 then
        vehicle.ad.speedOverride = math.min(distanceToTarget, vehicle.ad.speedOverride)
    elseif distanceToTarget > 13 then
        vehicle.ad.speedOverride = math.min(15, vehicle.ad.speedOverride)
    else
        vehicle.ad.speedOverride = math.min(8, vehicle.ad.speedOverride)
    end

    --if vehicle.ad.currentWayPoint <= 2 then
    --vehicle.ad.speedOverride = math.min(15, vehicle.ad.speedOverride);
    --end;
    if AutoDrive.checkForTriggerProximity(vehicle) then
        vehicle.ad.speedOverride = math.min(5, vehicle.ad.speedOverride)
    end
    if vehicle.ad.inDeadLock then
        vehicle.ad.speedOverride = math.min(AutoDrive.DEADLOCKSPEED, vehicle.ad.speedOverride)
    end

    --local wp_new = nil
    --
    --if wp_new ~= nil then
    --    xl, yl, zl = worldToLocal(vehicle.components[1].node, wp_new.x, y, wp_new.z)
    --end

    if vehicle.ad.mode == AutoDrive.MODE_DELIVERTO or vehicle.ad.mode == AutoDrive.MODE_PICKUPANDDELIVER or vehicle.ad.mode == AutoDrive.MODE_LOAD then --or vehicle.ad.mode == AutoDrive.MODE_UNLOAD
        local destination = AutoDrive.mapWayPoints[vehicle.ad.targetSelected_Unload]
        local start = AutoDrive.mapWayPoints[vehicle.ad.targetSelected]
        if destination ~= nil and start ~= nil then
            local distance1 = AutoDrive:getDistance(x, z, destination.x, destination.z)
            local distance2 = AutoDrive:getDistance(x, z, start.x, start.z)
            if distance1 < 20 or distance2 < 20 then
                if vehicle.ad.speedOverride > 12 then
                    vehicle.ad.speedOverride = 12
                end
            end
        end
    end

    if vehicle.ad.mode == AutoDrive.MODE_UNLOAD and (vehicle.ad.combineState == AutoDrive.DRIVE_TO_COMBINE or vehicle.ad.combineState == AutoDrive.DRIVE_TO_PARK_POS or vehicle.ad.combineState == AutoDrive.PREDRIVE_COMBINE or vehicle.ad.combineState == AutoDrive.DRIVE_TO_START_POS) then
        vehicle.ad.speedOverride = math.min(AutoDrive.SPEED_ON_FIELD, vehicle.ad.speedOverride)
    end

    if vehicle.ad.isUnloadingToBunkerSilo == true and vehicle.ad.isPaused == false then
        vehicle.ad.speedOverride = math.min(AutoDrive.getBunkerSiloSpeed(vehicle), vehicle.ad.speedOverride)
    end

    local finalSpeed = vehicle.ad.speedOverride
    --local finalAcceleration = true

    local node = vehicle.components[1].node
    -- if vehicle.getAIVehicleDirectionNode ~= nil then
    --   node = vehicle:getAIVehicleDirectionNode();
    -- end;
    local maxAngle = 60
    if vehicle.maxRotation then
        if vehicle.maxRotation > (2 * math.pi) then
            maxAngle = vehicle.maxRotation
        else
            maxAngle = math.deg(vehicle.maxRotation)
        end
    end

    vehicle.ad.targetX, vehicle.ad.targetZ = AutoDrive:getLookAheadTarget(vehicle)

    local lx, lz = AIVehicleUtil.getDriveDirection(node, vehicle.ad.targetX, y, vehicle.ad.targetZ) --vehicle.components[1].node

    if vehicle.ad.drivingForward == false then
        lz = -lz
        lx = -lx
        maxAngle = maxAngle * 2
        finalSpeed = finalSpeed / 2
    end

    if vehicle.ad.lastUsedSpeed == nil then
        vehicle.ad.lastUsedSpeed = finalSpeed
    end

    -- if vehicle.ad.wayPoints[vehicle.ad.currentWayPoint+5] ~= nil then --allow hard braking when getting close to destination
    --     if finalSpeed > vehicle.ad.lastUsedSpeed then
    --         finalSpeed = math.min(vehicle.ad.lastUsedSpeed + (dt/1000)*10, finalSpeed);
    --     elseif finalSpeed < vehicle.ad.lastUsedSpeed then
    --         finalSpeed = math.max(vehicle.ad.lastUsedSpeed - (dt/1000)*18, finalSpeed);
    --     end;
    -- end;

    vehicle.ad.lastUsedSpeed = finalSpeed

    local acceleration = 1
    if vehicle.ad.trafficDetected == true then
        vehicle.ad.timeTillDeadLock = 15000
        if math.abs(vehicle.lastSpeedReal) > 0.0013 then
            finalSpeed = 0.001
            acceleration = -0.6
            AIVehicleUtil.driveInDirection(vehicle, dt, maxAngle, acceleration, 0.2, maxAngle / 2, vehicle.ad.allowedToDrive, vehicle.ad.drivingForward, lx, lz, finalSpeed, 0.5)
        else
            AutoDrive:getVehicleToStop(vehicle, false, dt)
            if math.abs(vehicle.lastSpeedReal) < 0.002 then
                vehicle.ad.isPaused = true
                vehicle.ad.isPausedCauseTraffic = true
            end
        end
    else
        if vehicle.ad.isPausedCauseTraffic == true then
            vehicle.ad.isPaused = false
            vehicle.ad.isPausedCauseTraffic = false
        end
        vehicle.ad.allowedToDrive = true
        AIVehicleUtil.driveInDirection(vehicle, dt, maxAngle, acceleration, 0.8, maxAngle / 1.5, vehicle.ad.allowedToDrive, vehicle.ad.drivingForward, lx, lz, finalSpeed, 0.65)
    end
    --vehicle,dt,steeringAngleLimit,acceleration,slowAcceleration,slowAngleLimit,allowedToDrive,moveForwards,lx,lz,maxSpeed,slowDownFactor,angle
end

function AutoDrive:getDistanceToLastWaypoint(vehicle, maxLookAheadPar)
    local distance = 0
    local maxLookAhead = maxLookAheadPar
    if maxLookAhead == nil then
        maxLookAhead = 10
    end
    if vehicle ~= nil and vehicle.ad.wayPoints ~= nil and vehicle.ad.currentWayPoint ~= nil then
        local lookAhead = 1
        while vehicle.ad.wayPoints[vehicle.ad.currentWayPoint + lookAhead] ~= nil and lookAhead < maxLookAhead do
            local p1 = vehicle.ad.wayPoints[vehicle.ad.currentWayPoint + lookAhead]
            local p2 = vehicle.ad.wayPoints[vehicle.ad.currentWayPoint + lookAhead - 1]
            distance = distance + MathUtil.vector2Length(p2.x - p1.x, p2.z - p1.z)

            lookAhead = lookAhead + 1
        end
    end

    return distance
end

function AutoDrive:driveToLastWaypoint(vehicle, dt)
    --g_logManager:devInfo("Reaching last waypoint - slowing down");
    local _, y, _ = getWorldTranslation(vehicle.components[1].node)
    local finalSpeed = 8
    -- if vehicle.ad.mode == AutoDrive.MODE_UNLOAD and vehicle.ad.combineState == AutoDrive.PREDRIVE_COMBINE then
    --     finalSpeed = vehicle.ad.lastUsedSpeed;
    -- end;
    local maxAngle = 50
    local lx, lz = AIVehicleUtil.getDriveDirection(vehicle.components[1].node, vehicle.ad.targetX, y, vehicle.ad.targetZ)
    if vehicle.ad.drivingForward == false then
        lz = -lz
        lx = -lx
        maxAngle = 5
        finalSpeed = finalSpeed / 2
    end

    if vehicle.ad.trafficDetected == true then
        vehicle.ad.timeTillDeadLock = 15000
        if math.abs(vehicle.lastSpeedReal) > 0.0013 then
            finalSpeed = 0.001
            local acceleration = -0.6
            AIVehicleUtil.driveInDirection(vehicle, dt, maxAngle, acceleration, 0.2, maxAngle / 2, vehicle.ad.allowedToDrive, vehicle.ad.drivingForward, lx, lz, finalSpeed, 0.5)
        else
            AutoDrive:getVehicleToStop(vehicle, false, dt)
            if math.abs(vehicle.lastSpeedReal) < 0.002 then
                vehicle.ad.isPaused = true
                vehicle.ad.isPausedCauseTraffic = true
            end
        end
    else
        if vehicle.ad.isPausedCauseTraffic == true then
            vehicle.ad.isPaused = false
            vehicle.ad.isPausedCauseTraffic = false
        end
        vehicle.ad.allowedToDrive = true

        AIVehicleUtil.driveInDirection(vehicle, dt, maxAngle, 1, 0.2, maxAngle, true, vehicle.ad.drivingForward, lx, lz, finalSpeed, 0.4)
    end
end

function AutoDrive:handleDeadlock(vehicle, dt)
    if vehicle.ad.inDeadLock == true and vehicle.ad.isActive == true and vehicle.isServer then
        AutoDrive.printMessage(vehicle, g_i18n:getText("AD_Driver_of") .. " " .. vehicle.ad.driverName .. " " .. g_i18n:getText("AD_got_stuck"))

        --deadlock handling
        if vehicle.ad.inDeadLockRepairCounter < 1 then
            AutoDrive.printMessage(vehicle, g_i18n:getText("AD_Driver_of") .. " " .. vehicle.ad.driverName .. " " .. g_i18n:getText("AD_got_stuck"))
            AutoDrive:stopAD(vehicle, true)
        else
            --g_logManager:devInfo("AD: Trying to recover from deadlock")
            local lookAhead = 3
            if vehicle.ad.wayPoints[vehicle.ad.currentWayPoint + lookAhead] == nil then
                lookAhead = 2
            end
            if vehicle.ad.wayPoints[vehicle.ad.currentWayPoint + lookAhead] ~= nil then
                --figure out best moment to switch to next waypoint!

                local x, _, z = getWorldTranslation(vehicle.components[1].node)
                local rx, _, rz = localDirectionToWorld(vehicle.components[1].node, math.sin(vehicle.rotatedTime), 0, math.cos(vehicle.rotatedTime))
                local vehicleVector = {x = rx, z = rz}

                local wpAhead = vehicle.ad.wayPoints[vehicle.ad.currentWayPoint + lookAhead - 1]
                local wpTwoAhead = vehicle.ad.wayPoints[vehicle.ad.currentWayPoint + lookAhead]

                local wpVector = {x = (wpTwoAhead.x - wpAhead.x), z = (wpTwoAhead.z - wpAhead.z)}
                local vehicleToWPVector = {x = (wpAhead.x - x), z = (wpAhead.z - z)}

                local angleBetweenVehicleVectorAndNextCourse = AutoDrive.angleBetween(vehicleVector, wpVector)
                local angleBetweenVehicleAndLookAheadWp = AutoDrive.angleBetween(vehicleVector, vehicleToWPVector)

                if (math.abs(angleBetweenVehicleVectorAndNextCourse) < 30 and math.abs(angleBetweenVehicleAndLookAheadWp) < 20) or (vehicle.ad.timeTillDeadLock < -30000) then
                    vehicle.ad.currentWayPoint = vehicle.ad.currentWayPoint + lookAhead - 1
                    vehicle.ad.targetX = vehicle.ad.wayPoints[vehicle.ad.currentWayPoint].x
                    vehicle.ad.targetZ = vehicle.ad.wayPoints[vehicle.ad.currentWayPoint].z

                    vehicle.ad.inDeadLock = false
                    vehicle.ad.timeTillDeadLock = 15000
                    vehicle.ad.inDeadLockRepairCounter = vehicle.ad.inDeadLockRepairCounter - 1
                end
            end

            if vehicle.ad.combineState == AutoDrive.PREDRIVE_COMBINE then
                AutoDrive:disableAutoDriveFunctions(vehicle)
                AutoDrive:startAD(vehicle)
            end
        end
    end
end

function AutoDrive:getLookAheadTarget(vehicle)
    --start driving to the nextWayPoint when closing in on current waypoint in order to avoid harsh steering angles and oversteering

    local x, _, z = getWorldTranslation(vehicle.components[1].node)
    local targetX = vehicle.ad.targetX
    local targetZ = vehicle.ad.targetZ
    if vehicle.ad.wayPoints[vehicle.ad.currentWayPoint + 1] ~= nil then
        local wp_current = vehicle.ad.wayPoints[vehicle.ad.currentWayPoint]

        local lookAheadID = 1
        local lookAheadDistance = AutoDrive.getSetting("lookAheadTurning")
        local distanceToCurrentTarget = AutoDrive:getDistance(x, z, wp_current.x, wp_current.z)
        --if vehicle.ad.currentWayPoint <= 2 then
        --lookAheadDistance = 0;
        --end;
        local wp_ahead = vehicle.ad.wayPoints[vehicle.ad.currentWayPoint + lookAheadID]
        local distanceToNextTarget = AutoDrive:getDistance(x, z, wp_ahead.x, wp_ahead.z)
        if distanceToCurrentTarget < distanceToNextTarget then
            lookAheadDistance = lookAheadDistance - distanceToCurrentTarget
        end

        while lookAheadDistance > distanceToNextTarget do
            lookAheadDistance = lookAheadDistance - distanceToNextTarget
            lookAheadID = lookAheadID + 1
            if vehicle.ad.wayPoints[vehicle.ad.currentWayPoint + lookAheadID] == nil then
                break
            end
            wp_current = wp_ahead
            wp_ahead = vehicle.ad.wayPoints[vehicle.ad.currentWayPoint + lookAheadID]
            distanceToNextTarget = AutoDrive:getDistance(wp_current.x, wp_current.z, wp_ahead.x, wp_ahead.z)
        end

        local distX = wp_ahead.x - wp_current.x
        local distZ = wp_ahead.z - wp_current.z

        if lookAheadDistance > 0 then
            local addX = lookAheadDistance * (math.abs(distX) / (math.abs(distX) + math.abs(distZ)))
            local addZ = lookAheadDistance * (math.abs(distZ) / (math.abs(distX) + math.abs(distZ)))
            if distX < 0 then
                addX = -addX
            end

            if distZ < 0 then
                addZ = -addZ
            end

            if (math.abs(distX) + math.abs(distZ)) > 0 then
                targetX = wp_current.x + addX
                targetZ = wp_current.z + addZ
            end
        end
    end

    --local x,y,z = getWorldTranslation(vehicle.components[1].node);
    --AutoDrive:drawLine(AutoDrive.createVector(targetX,y, targetZ), AutoDrive.createVector(x,y,z), 1, 0, 1, 1);
    return targetX, targetZ
end

function AutoDrive.handleRefueling(vehicle, dt)
    if AutoDrive.Triggers == nil or (vehicle.ad.isActive == false) or (not AutoDrive.getSetting("autoRefuel", vehicle)) then
        return
    end
    if AutoDrive.hasToRefuel(vehicle) and (not vehicle.ad.onRouteToRefuel) and (not AutoDrive:isOnField(vehicle)) then
        AutoDrive.goToRefuelStation(vehicle)
    end

    if vehicle.ad.onRouteToRefuel then
        AutoDrive.startRefuelingWhenInRange(vehicle, dt)
    end
end
