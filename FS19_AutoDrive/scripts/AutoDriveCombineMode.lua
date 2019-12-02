AutoDrive.COMBINE_UNINITIALIZED = 0
AutoDrive.WAIT_FOR_COMBINE = 1
AutoDrive.DRIVE_TO_COMBINE = 2
AutoDrive.WAIT_TILL_UNLOADED = 3
AutoDrive.DRIVE_TO_PARK_POS = 4
AutoDrive.DRIVE_TO_START_POS = 5
AutoDrive.DRIVE_TO_UNLOAD_POS = 6
AutoDrive.PREDRIVE_COMBINE = 7
AutoDrive.CHASE_COMBINE = 8
AutoDrive.UNLOAD_WAIT_TIMER = 15000

AutoDrive.ccSIDE_REAR = 0
AutoDrive.ccSIDE_LEFT = 1
AutoDrive.ccSIDE_RIGHT = 2

AutoDrive.CC_MODE_IDLE = 0
AutoDrive.CC_MODE_CHASING = 1
AutoDrive.CC_MODE_WAITING_FOR_COMBINE_TO_TURN = 2
AutoDrive.CC_MODE_WAITING_FOR_COMBINE_TO_PASS_BY = 3
AutoDrive.CC_MODE_REVERSE_FROM_COLLISION = 4

function AutoDrive:handleCombineHarvester(vehicle, dt)
    if vehicle.ad.currentDriver ~= nil and (not vehicle.ad.preCalledDriver) then
        vehicle.ad.driverOnTheWay = true
        vehicle.ad.tryingToCallDriver = false
        if (vehicle.ad.currentDriver.ad.combineUnloadInFruitWaitTimer >= AutoDrive.UNLOAD_WAIT_TIMER) then
            if vehicle.cp and vehicle.cp.driver and vehicle.cp.driver.holdForUnloadOrRefill then
                vehicle.cp.driver:holdForUnloadOrRefill()
            end
        end
        return
    end

    vehicle.ad.driverOnTheWay = false
    vehicle.ad.tryingToCallDriver = false

    if vehicle.spec_dischargeable ~= nil and vehicle.ad.currentDriver == nil then
        local fillLevel, leftCapacity = AutoDrive.getFilteredFillLevelAndCapacityOfAllUnits(vehicle)
        local maxCapacity = fillLevel + leftCapacity

        local cpIsCalling = false
        if vehicle.cp and vehicle.cp.driver and vehicle.cp.driver.isWaitingForUnload then
            cpIsCalling = vehicle.cp.driver:isWaitingForUnload()
        end

        if (((maxCapacity > 0 and leftCapacity <= 1.0) or cpIsCalling) and vehicle.ad.stoppedTimer <= 0) then
            vehicle.ad.tryingToCallDriver = true
            AutoDrive:callDriverToCombine(vehicle)
        elseif (((fillLevel / maxCapacity) >= AutoDrive.getSetting("preCallLevel", vehicle) and (fillLevel / maxCapacity) <= 0.96 and AutoDrive.getSetting("preCallDriver", vehicle)) or vehicle:getIsBufferCombine()) and (not vehicle.ad.preCalledDriver) then
            if vehicle.ad.sensors.frontSensorFruit:pollInfo() or (vehicle:getIsAIActive() and vehicle.lastSpeedReal <= 0.0003 and vehicle:getIsBufferCombine()) then
                vehicle.ad.tryingToCallDriver = true
                AutoDrive:preCallDriverToCombine(vehicle)
            end
        end
    end
end

function AutoDrive:callDriverToCombine(combine)
    local spec = combine.spec_pipe
    if spec.currentState == spec.targetState and (spec.currentState == 2 or combine.typeName == "combineCutterFruitPreparer") then
        local worldX, worldY, worldZ = getWorldTranslation(combine.components[1].node)

        for _, dischargeNode in pairs(combine.spec_dischargeable.dischargeNodes) do
            local nodeX, nodeY, nodeZ = getWorldTranslation(dischargeNode.node)
            if AutoDrive.tableLength(AutoDrive.waitingUnloadDrivers) > 0 then
                local closestDriver = nil
                local closestDistance = math.huge
                for _, driver in pairs(AutoDrive.waitingUnloadDrivers) do
                    local driverX, driverY, driverZ = getWorldTranslation(driver.components[1].node)
                    local distance = math.sqrt(math.pow((driverX - worldX), 2) + math.pow((driverZ - worldZ), 2))

                    if distance < closestDistance and ((distance < 300 and AutoDrive.getSetting("findDriver") == true) or (driver.ad.targetSelected == combine.ad.targetSelected)) then
                        closestDistance = distance
                        closestDriver = driver
                    end
                end

                if closestDriver ~= nil then
                    AutoDrive.debugPrint(combine, AutoDrive.DC_COMBINEINFO, " callDriverToCombine")
                    AutoDrivePathFinder:startPathPlanningToCombine(closestDriver, combine, dischargeNode.node)
                    closestDriver.ad.currentCombine = combine
                    AutoDrive.waitingUnloadDrivers[closestDriver] = nil
                    closestDriver.ad.combineState = AutoDrive.DRIVE_TO_COMBINE
                    combine.ad.currentDriver = closestDriver
                    closestDriver.ad.isPaused = false
                    closestDriver.ad.isUnloading = false
                    closestDriver.ad.isLoading = false
                    closestDriver.ad.initialized = false
                    closestDriver.ad.designatedTrailerFillLevel = math.huge
                    closestDriver.ad.wayPoints = {}

                    combine.ad.tryingToCallDriver = false
                    combine.ad.driverOnTheWay = true
                    combine.ad.preCalledDriver = false

                    closestDriver.ad.driveToUnloadNext = false
                    if combine.cp and combine.cp.driver and combine.cp.driver.isWaitingForUnloadAfterCourseEnded then
                        closestDriver.ad.driveToUnloadNext = combine.cp.driver:isWaitingForUnloadAfterCourseEnded()
                    end
                end
            end
        end
    else
        combine.ad.tryingToCallDriver = true
    end
end

function AutoDrive:preCallDriverToCombine(combine)
    local worldX, worldY, worldZ = getWorldTranslation(combine.components[1].node)

    if AutoDrive.tableLength(AutoDrive.waitingUnloadDrivers) > 0 then
        local closestDriver = nil
        local closestDistance = math.huge
        for _, driver in pairs(AutoDrive.waitingUnloadDrivers) do
            local driverX, driverY, driverZ = getWorldTranslation(driver.components[1].node)
            local distance = math.sqrt(math.pow((driverX - worldX), 2) + math.pow((driverZ - worldZ), 2))

            if distance < closestDistance and ((distance < 300 and AutoDrive.getSetting("findDriver") == true) or (driver.ad.targetSelected == combine.ad.targetSelected)) then
                closestDistance = distance
                closestDriver = driver
            end
        end

        if closestDriver ~= nil then
            AutoDrive.debugPrint(combine, AutoDrive.DC_COMBINEINFO, " preCallDriverToCombine")
            AutoDrivePathFinder:startPathPlanningToCombine(closestDriver, combine, nil)
            closestDriver.ad.currentCombine = combine
            AutoDrive.waitingUnloadDrivers[closestDriver] = nil
            closestDriver.ad.combineState = AutoDrive.PREDRIVE_COMBINE
            combine.ad.currentDriver = closestDriver
            closestDriver.ad.isPaused = false
            closestDriver.ad.isUnloading = false
            closestDriver.ad.isLoading = false
            closestDriver.ad.initialized = false
            closestDriver.ad.designatedTrailerFillLevel = math.huge
            closestDriver.ad.wayPoints = {}

            combine.ad.tryingToCallDriver = false
            combine.ad.driverOnTheWay = true
            combine.ad.preCalledDriver = true

            closestDriver.ad.driveToUnloadNext = false
            if combine.cp and combine.cp.driver and combine.cp.driver.isWaitingForUnloadAfterCourseEnded then
                closestDriver.ad.driveToUnloadNext = combine.cp.driver:isWaitingForUnloadAfterCourseEnded()
            end
        end
    end
end

function AutoDrive:combineIsCallingDriver(combine)
    return (combine.ad ~= nil) and ((combine.ad.tryingToCallDriver and AutoDrive.tableLength(AutoDrive.waitingUnloadDrivers) > 0) or combine.ad.driverOnTheWay)
end

function AutoDrive:handleReachedWayPointCombine(vehicle)
    if vehicle.ad.combineState == AutoDrive.COMBINE_UNINITIALIZED then --register Driver as available unloader if target point is reached (Hopefully field position!)
        --g_logManager:devInfo("Registering " .. vehicle.ad.driverName .. " as driver");
        AutoDrive.waitingUnloadDrivers[vehicle] = vehicle
        vehicle.ad.combineState = AutoDrive.WAIT_FOR_COMBINE
        vehicle.ad.isPaused = true
        vehicle.ad.wayPoints = {}
    elseif vehicle.ad.combineState == AutoDrive.DRIVE_TO_COMBINE then
        vehicle.ad.combineState = AutoDrive.WAIT_TILL_UNLOADED
        vehicle.ad.initialized = false
        vehicle.ad.wayPoints = {}
        vehicle.ad.isPaused = true
    elseif vehicle.ad.combineState == AutoDrive.DRIVE_TO_PARK_POS then
        AutoDrive.waitingUnloadDrivers[vehicle] = vehicle
        vehicle.ad.combineState = AutoDrive.WAIT_FOR_COMBINE
        vehicle.ad.wayPoints = {}
        vehicle.ad.isPaused = true
        if vehicle.ad.currentCombine ~= nil then
            vehicle.ad.currentCombine.ad.currentDriver = nil
            vehicle.ad.currentCombine.ad.preCalledDriver = false
            vehicle.ad.currentCombine.ad.driverOnTheWay = false
            vehicle.ad.currentCombine = nil
        end
    elseif vehicle.ad.combineState == AutoDrive.DRIVE_TO_START_POS then
        AutoDrive:sendCombineUnloaderToStartOrToUnload(vehicle, false)
    elseif vehicle.ad.combineState == AutoDrive.DRIVE_TO_UNLOAD_POS then
        AutoDrive:sendCombineUnloaderToStartOrToUnload(vehicle, true)
    elseif vehicle.ad.combineState == AutoDrive.PREDRIVE_COMBINE then
        if AutoDrive.getSetting("chaseCombine", vehicle) or (vehicle.ad.currentCombine ~= nil and vehicle.ad.currentCombine:getIsBufferCombine()) then
            --g_logManager:devInfo("Switching to chasing combine");
            vehicle.ad.wayPoints = {}
            vehicle.ad.combineState = AutoDrive.CHASE_COMBINE
            vehicle.ad.initialized = false
        else
            AutoDrive.waitingUnloadDrivers[vehicle] = vehicle
            vehicle.ad.combineState = AutoDrive.WAIT_FOR_COMBINE
            vehicle.ad.wayPoints = {}
            vehicle.ad.isPaused = true
            if vehicle.ad.currentCombine ~= nil then
                vehicle.ad.currentCombine.ad.currentDriver = nil
                vehicle.ad.currentCombine.ad.preCalledDriver = false
                vehicle.ad.currentCombine.ad.driverOnTheWay = false
                vehicle.ad.currentCombine = nil
            end
        end
    end
end

function AutoDrive:initializeADCombine(vehicle, dt)
    if vehicle.ad.wayPoints == nil or vehicle.ad.wayPoints[1] == nil then
        vehicle.ad.initialized = false
        vehicle.ad.timeTillDeadLock = 15000
        vehicle.ad.inDeadLock = false

        if vehicle.ad.combineState == AutoDrive.DRIVE_TO_COMBINE or vehicle.ad.combineState == AutoDrive.PREDRIVE_COMBINE or vehicle.ad.combineState == AutoDrive.DRIVE_TO_START_POS or vehicle.ad.combineState == AutoDrive.DRIVE_TO_PARK_POS then
            AutoDrive:getVehicleToStop(vehicle, false, dt)
            vehicle.ad.ccMode = AutoDrive.CC_MODE_IDLE
            return not AutoDrive:handlePathPlanning(vehicle, dt)
        elseif vehicle.ad.combineState == AutoDrive.WAIT_TILL_UNLOADED then
            local doneUnloading, trailerFillLevel = AutoDrive:checkDoneUnloading(vehicle)
            local trailers, trailerCount = AutoDrive.getTrailersOf(vehicle)
            vehicle.ad.ccMode = AutoDrive.CC_MODE_IDLE
            vehicle.ad.trailerCount = trailerCount
            vehicle.ad.trailerFillLevel = trailerFillLevel

            if trailers[vehicle.ad.currentTrailer + 1] ~= nil then
                local lastFillLevel = vehicle.ad.designatedTrailerFillLevel

                local fillLevel, leftCapacity = AutoDrive.getFilteredFillLevelAndCapacityOfAllUnits(trailers[vehicle.ad.currentTrailer + 1])
                local maxCapacity = fillLevel + leftCapacity

                vehicle.ad.designatedTrailerFillLevel = (maxCapacity - leftCapacity) / maxCapacity

                if lastFillLevel < vehicle.ad.designatedTrailerFillLevel then
                    --g_logManager:devInfo("lastFillLevel: " .. lastFillLevel .. " designated: " .. vehicle.ad.designatedTrailerFillLevel .. " currentTrailer: " .. vehicle.ad.currentTrailer .. " trailerCount: " .. trailerCount);
                    vehicle.ad.currentTrailer = vehicle.ad.currentTrailer + 1
                    --Reload trailerFillLevel when switching to next trailer
                    doneUnloading, trailerFillLevel = AutoDrive:checkDoneUnloading(vehicle)
                end
            end

            local drivingEnabled = false
            if trailerFillLevel > 0.99 and vehicle.ad.currentTrailer < trailerCount then
                local finalSpeed = 8
                local acc = 1
                local allowedToDrive = true

                local x, y, z = getWorldTranslation(vehicle.components[1].node)
                local rx, ry, rz = localDirectionToWorld(vehicle.components[1].node, 0, 0, 1)
                x = x + rx
                z = z + rz
                local lx, lz = AIVehicleUtil.getDriveDirection(vehicle.components[1].node, x, y, z)
                AIVehicleUtil.driveInDirection(vehicle, dt, 30, acc, 0.2, 20, allowedToDrive, true, nil, nil, finalSpeed, 1)
                drivingEnabled = true
            end

            if (doneUnloading or (vehicle.ad.combineUnloadInFruitWaitTimer < AutoDrive.UNLOAD_WAIT_TIMER)) or (trailerFillLevel >= 0.99 and vehicle.ad.currentTrailer == trailerCount) then
                --wait for combine to move away. Currently by fixed timer of 15s
                if vehicle.ad.combineUnloadInFruitWaitTimer > 0 then
                    vehicle.ad.combineUnloadInFruitWaitTimer = vehicle.ad.combineUnloadInFruitWaitTimer - dt
                    if vehicle.ad.combineUnloadInFruitWaitTimer > 10500 then
                        local finalSpeed = 9
                        local acc = 1
                        local allowedToDrive = true

                        local node = vehicle.components[1].node
                        if vehicle.getAIVehicleDirectionNode ~= nil then
                            node = vehicle:getAIVehicleDirectionNode()
                        end
                        local x, y, z = getWorldTranslation(vehicle.components[1].node)
                        local rx, ry, rz = localDirectionToWorld(vehicle.components[1].node, 0, 0, -1)
                        x = x + rx
                        z = z + rz
                        local lx, lz = AIVehicleUtil.getDriveDirection(vehicle.components[1].node, x, y, z)
                        AIVehicleUtil.driveInDirection(vehicle, dt, 30, acc, 0.2, 20, allowedToDrive, false, nil, nil, finalSpeed, 1)
                        drivingEnabled = true
                    else
                        AutoDrive:getVehicleToStop(vehicle, false, dt)
                    end

                    return true
                end

                if trailerFillLevel >= (AutoDrive.getSetting("unloadFillLevel", vehicle) - 0.001) or vehicle.ad.sensors.centerSensorFruit:pollInfo() or (AutoDrive.getSetting("parkInField", vehicle) == false) or vehicle.ad.driveToUnloadNext then
                    if trailerFillLevel >= (AutoDrive.getSetting("unloadFillLevel", vehicle) - 0.001) or vehicle.ad.driveToUnloadNext then
                        vehicle.ad.combineState = AutoDrive.DRIVE_TO_START_POS
                    else
                        vehicle.ad.combineState = AutoDrive.DRIVE_TO_PARK_POS
                    end
                    AutoDrivePathFinder:startPathPlanningToStartPosition(vehicle, vehicle.ad.currentCombine)
                    if vehicle.ad.currentCombine ~= nil then
                        vehicle.ad.currentCombine.ad.currentDriver = nil
                        vehicle.ad.currentCombine.ad.preCalledDriver = false
                        vehicle.ad.currentCombine.ad.driverOnTheWay = false
                        vehicle.ad.currentCombine = nil
                    end
                else
                    --wait in field
                    AutoDrive.waitingUnloadDrivers[vehicle] = vehicle
                    vehicle.ad.combineState = AutoDrive.WAIT_FOR_COMBINE
                    --vehicle.ad.initialized = false;
                    vehicle.ad.wayPoints = {}
                    vehicle.ad.isPaused = true
                    if vehicle.ad.currentCombine ~= nil then
                        vehicle.ad.currentCombine.ad.currentDriver = nil
                        vehicle.ad.currentCombine.ad.preCalledDriver = false
                        vehicle.ad.currentCombine.ad.driverOnTheWay = false
                        vehicle.ad.currentCombine = nil
                    end
                end
            end

            if drivingEnabled == false then
                AutoDrive:getVehicleToStop(vehicle, false, dt)
            end

            return true
        elseif vehicle.ad.combineState == AutoDrive.CHASE_COMBINE then
            AutoDrive:chaseCombine(vehicle, dt)
            return true
        end
    end

    return false
end

function AutoDrive:registerDriverAsAvailableUnloader(vehicle)
    AutoDrive.waitingUnloadDrivers[vehicle] = vehicle
    vehicle.ad.combineState = AutoDrive.WAIT_FOR_COMBINE
    vehicle.ad.wayPoints = {}
    vehicle.ad.isPaused = true
    if vehicle.ad.currentCombine ~= nil then
        vehicle.ad.currentCombine.ad.currentDriver = nil
        vehicle.ad.currentCombine.ad.preCalledDriver = false
        vehicle.ad.currentCombine.ad.driverOnTheWay = false
        vehicle.ad.currentCombine = nil
    end
end

function AutoDrive:unregisterDriverAsUnloader(vehicle)
    if vehicle.ad.currentCombine ~= nil then
        vehicle.ad.currentCombine.ad.currentDriver = nil
        vehicle.ad.currentCombine.ad.preCalledDriver = false
        vehicle.ad.currentCombine.ad.driverOnTheWay = false
        vehicle.ad.currentCombine = nil
        return
    end
end

function AutoDrive:updateChaseModeInfos(vehicle, dt)
    local combine = vehicle.ad.currentCombine

    vehicle.ccInfos.combineWorldX, vehicle.ccInfos.combineWorldY, vehicle.ccInfos.combineWorldZ = getWorldTranslation(combine.components[1].node)
    vehicle.ccInfos.worldX, vehicle.ccInfos.worldY, vehicle.ccInfos.worldZ = getWorldTranslation(vehicle.components[1].node)
    vehicle.ccInfos.angleToCombineHeading = AutoDrive:getAngleToCombineHeading(vehicle, combine)
    if vehicle.ccInfos.combineHeadingDiff == nil then
        vehicle.ccInfos.combineHeadingDiff = AutoDriveTON:new()
    end
    vehicle.ccInfos.combineHeadingDiff:timer((vehicle.ccInfos.angleToCombineHeading > 20), 7000, dt)

    vehicle.ccInfos.isChopper = combine:getIsBufferCombine()
    vehicle.ccInfos.leftBlocked = combine.ad.sensors.leftSensorFruit:pollInfo() or combine.ad.sensors.leftSensor:pollInfo() or (not combine.ad.sensors.leftSensorField:pollInfo())
    vehicle.ccInfos.rightBlocked = combine.ad.sensors.rightSensorFruit:pollInfo() or combine.ad.sensors.rightSensor:pollInfo() or (not combine.ad.sensors.rightSensorField:pollInfo())

    --start looking ahead a little if both sides are free currently
    vehicle.ccInfos.frontLeftBlocked = combine.ad.sensors.leftFrontSensorFruit:pollInfo()
    vehicle.ccInfos.frontRightBlocked = combine.ad.sensors.rightFrontSensorFruit:pollInfo()
    if (not vehicle.ccInfos.leftBlocked) and (not vehicle.ccInfos.rightBlocked) then
        if vehicle.ccInfos.frontLeftBlocked then
            vehicle.ccInfos.leftBlocked = true
        elseif vehicle.ccInfos.frontRightBlocked then
            vehicle.ccInfos.rightBlocked = true
        end
    end

    vehicle.ccInfos.chasePos, vehicle.ccInfos.chaseSide = AutoDrive:getPipeChasePosition(vehicle, combine, vehicle.ccInfos.isChopper, vehicle.ccInfos.leftBlocked, vehicle.ccInfos.rightBlocked)
    vehicle.ccInfos.distanceToCombine = MathUtil.vector2Length(vehicle.ccInfos.combineWorldX - vehicle.ccInfos.worldX, vehicle.ccInfos.combineWorldZ - vehicle.ccInfos.worldZ)
    vehicle.ccInfos.distanceToChasePos = MathUtil.vector2Length(vehicle.ccInfos.chasePos.x - vehicle.ccInfos.worldX, vehicle.ccInfos.chasePos.z - vehicle.ccInfos.worldZ)

    vehicle.ccInfos.fillLevel, vehicle.ccInfos.leftCapacity = AutoDrive.getFilteredFillLevelAndCapacityOfAllUnits(combine)
    vehicle.ccInfos.maxCapacity = vehicle.ccInfos.fillLevel + vehicle.ccInfos.leftCapacity
    vehicle.ccInfos.combineFillLevel = (vehicle.ccInfos.fillLevel / vehicle.ccInfos.maxCapacity)

    vehicle.ccInfos.doneUnloading, vehicle.ccInfos.trailerFillLevel = AutoDrive:checkDoneUnloading(vehicle)
end

function AutoDrive:initChaseMode(vehicle, dt)
    vehicle.ccInfos.lastChaseSide = vehicle.ccInfos.chaseSide
    vehicle.ad.ccMode = AutoDrive.CC_MODE_CHASING
    vehicle.ccInfos.combineHeadingDiff:timer(false)
    vehicle.ad.reverseTimer = 11000
end

function AutoDrive:checkForChaseModeStopCondition(vehicle, dt)
    local keepFollowing = true
    if vehicle.ccInfos.combineHeadingDiff:done() then
        keepFollowing = false
    end
    if vehicle.ccInfos.distanceToChasePos > 120 then
        --g_logManager:devInfo("Chasing combine - stopped - distanceToChasePos > 60");
        keepFollowing = false
    end

    if not keepFollowing and (vehicle.ad.ccMode ~= AutoDrive.CC_MODE_WAITING_FOR_COMBINE_TO_PASS_BY and vehicle.ad.ccMode ~= AutoDrive.CC_MODE_WAITING_FOR_COMBINE_TO_TURN) then
        if vehicle.ad.currentCombine ~= nil then
            AutoDrive:retriggerPreDrive(vehicle, dt)
        end
    end

    --only stop chasing if combine turn includes reversing or there is no fruit in front of the combine at this stage
    if AutoDrive:combineIsTurning(vehicle, vehicle.ad.currentCombine, vehicle.ccInfos.isChopper) and (vehicle.ad.currentCombine.lastSpeedReal < 0) then
        --g_logManager:devInfo("Chasing combine - stopped - combineIsTurning");
        vehicle.ad.ccMode = AutoDrive.CC_MODE_WAITING_FOR_COMBINE_TO_TURN
    end

    if vehicle.ccInfos.trailerFillLevel >= 0.999 and vehicle.ad.ccMode == AutoDrive.CC_MODE_CHASING then
        vehicle.ad.ccMode = AutoDrive.CC_MODE_REVERSE_FROM_COLLISION
    end

    if vehicle.ccInfos.trailerFillLevel >= 0.999 and (vehicle.ad.ccMode ~= AutoDrive.CC_MODE_REVERSE_FROM_COLLISION) then
        vehicle.ad.combineState = AutoDrive.DRIVE_TO_START_POS
        AutoDrivePathFinder:startPathPlanningToStartPosition(vehicle, vehicle.ad.currentCombine)
        AutoDrive:unregisterDriverAsUnloader(vehicle)
    end

    if vehicle.ad.currentCombine ~= nil then
        if (vehicle.ccInfos.combineFillLevel >= 0.98 or vehicle.ad.currentCombine.ad.noMovementTimer.elapsedTime > 10000) and (not vehicle.ccInfos.isChopper) then
            --g_logManager:devInfo("Chasing combine - stopped - park in Field now");
            AutoDrive:getVehicleToStop(vehicle, false, dt)
            AutoDrive:registerDriverAsAvailableUnloader(vehicle)
        end
    end
end

function AutoDrive:checkForChaseModePauseCondition(vehicle, dt)
    if vehicle.ad.currentCombine == nil then
        return
    end

    --if not vehicle.ad.currentCombine.ad.sensors.frontSensorFruit:pollInfo() then
    --vehicle.ad.ccMode = AutoDrive.CC_MODE_WAITING_FOR_COMBINE_TO_TURN
    --end

    --pause if angle to chasepos is too high -> probably a switch between chase positions. Let's see if combine keeps driving on and the angle is fine again
    if AutoDrive:getAngleToChasePos(vehicle, vehicle.ccInfos.chasePos) > 60 then
        --g_logManager:devInfo("Angle to chase pos too high: " .. AutoDrive:getAngleToChasePos(vehicle, chasePos));
        vehicle.ad.ccMode = AutoDrive.CC_MODE_WAITING_FOR_COMBINE_TO_PASS_BY
        vehicle.ad.reverseTimer = 2000
    end

    if vehicle.ad.sensors.frontSensor:pollInfo() and (vehicle.ccInfos.chaseSide ~= AutoDrive.ccSIDE_REAR) then
        AutoDrive.debugPrint(vehicle, AutoDrive.DC_COMBINEINFO, "Front sensor collision")
        vehicle.ad.ccMode = AutoDrive.CC_MODE_REVERSE_FROM_COLLISION
        vehicle.ad.reverseTimer = 2000
    end
end

function AutoDrive:chaseModeWaitForCombineToPassBy(vehicle, dt)
    if vehicle.ad.reverseTimer > 0 then
        AutoDrive:reverseVehicle(vehicle, dt)
        vehicle.ad.reverseTimer = vehicle.ad.reverseTimer - dt
    elseif vehicle.ccInfos.distanceToCombine < 7 or (AutoDrive:combineIsTurning(vehicle, vehicle.ad.currentCombine, vehicle.ccInfos.isChopper) and vehicle.ccInfos.distanceToCombine < 20) then --(not vehicle.ad.currentCombine:getIsBufferCombine()) and
        AutoDrive:reverseVehicle(vehicle, dt)
    else
        AutoDrive:getVehicleToStop(vehicle, false, dt)
    end

    --if not vehicle.ad.currentCombine.ad.sensors.frontSensorFruit:pollInfo() then
    --vehicle.ad.ccMode = AutoDrive.CC_MODE_WAITING_FOR_COMBINE_TO_TURN
    --end

    --if vehicle.ad.currentCombine.lastSpeedReal < 0.0008 then --if combine is stopping, we have to fallback to pathfinding
    --vehicle.ad.ccMode = AutoDrive.CC_MODE_REVERSE_FROM_COLLISION
    --end
    if vehicle.ad.currentCombine.ad.sensors.frontSensorFruit:pollInfo() and AutoDrive:getAngleToChasePos(vehicle, vehicle.ccInfos.chasePos) < 50 and (not vehicle.ad.sensors.frontSensor:pollInfo()) then
        vehicle.ad.ccMode = AutoDrive.CC_MODE_CHASING
        vehicle.ad.reverseTimer = 11000
    end
    if vehicle.ad.noMovementTimer.elapsedTime > 20000 then
        AutoDrive:registerDriverAsAvailableUnloader(vehicle)
        vehicle.ad.reverseTimer = 11000
    end
end

function AutoDrive:driveToChasePosition(vehicle, dt)
    --g_logManager:devInfo("Chasing combine")
    local finalSpeed = AutoDrive.SPEED_ON_FIELD
    local acc = 1
    local allowedToDrive = true

    if vehicle.ccInfos.distanceToChasePos < 2 then
        finalSpeed = 2
    elseif vehicle.ccInfos.distanceToChasePos < 5 then
        finalSpeed = (vehicle.ad.currentCombine.lastSpeedReal * 3600)
    elseif vehicle.ccInfos.distanceToChasePos < 10 then
        finalSpeed = math.max((vehicle.ad.currentCombine.lastSpeedReal * 3600), 10)
    end

    local lx, lz = AIVehicleUtil.getDriveDirection(vehicle.components[1].node, vehicle.ccInfos.chasePos.x, vehicle.ccInfos.chasePos.y, vehicle.ccInfos.chasePos.z)
    AIVehicleUtil.driveInDirection(vehicle, dt, 30, acc, 0.2, 20, allowedToDrive, true, lx, lz, finalSpeed, 1)
    --drivingEnabled = true
end

function AutoDrive:chaseModeWaitForCombineToTurn(vehicle, dt)
    if vehicle.ccInfos.distanceToCombine < 10 or (vehicle.ad.reverseTimer > 4000) then --(not vehicle.ad.currentCombine:getIsBufferCombine()) and
        AutoDrive:reverseVehicle(vehicle, dt)
        vehicle.ad.reverseTimer = vehicle.ad.reverseTimer - dt
    else
        AutoDrive:getVehicleToStop(vehicle, false, dt)
    end

    local pausedForSomeTime = vehicle.ad.noMovementTimer:done()
    if vehicle.ad.currentCombine ~= nil then
        if ((not AutoDrive:combineIsTurning(vehicle, vehicle.ad.currentCombine, vehicle.ccInfos.isChopper)) and pausedForSomeTime and vehicle.ad.currentCombine.ad.sensors.frontSensorFruit:pollInfo()) or (vehicle.ad.noMovementTimer.elapsedTime > 30000) then
            AutoDrive:retriggerPreDrive(vehicle)
            vehicle.ad.reverseTimer = 11000
        end
    end
end

function AutoDrive:retriggerPreDrive(vehicle)
    --g_logManager:devInfo("Chasing combine - stopped - recalculating new path");
    if vehicle.ad.currentCombine ~= nil then
        if vehicle.ccInfos.distanceToChasePos < 25 and AutoDrive:getAngleToChasePos(vehicle, vehicle.ccInfos.chasePos) < 40 and vehicle.ccInfos.angleToCombineHeading < 90 then
            vehicle.ad.ccMode = AutoDrive.CC_MODE_CHASING
        else
            AutoDrivePathFinder:startPathPlanningToCombine(vehicle, vehicle.ad.currentCombine, nil, true)
            AutoDrive.waitingUnloadDrivers[vehicle] = nil
            vehicle.ad.combineState = AutoDrive.PREDRIVE_COMBINE
            vehicle.ad.reverseTimer = 11000
            vehicle.ccInfos.combineHeadingDiff:timer(false)
            vehicle.ad.ccMode = AutoDrive.CC_MODE_IDLE
        end
    end
end

function AutoDrive:chaseModeReverse(vehicle, dt)
    if vehicle.ad.reverseTimer > 0 then
        AutoDrive:reverseVehicle(vehicle, dt)
        vehicle.ad.reverseTimer = vehicle.ad.reverseTimer - dt
    else
        vehicle.ad.chaseCombineReverse = false
        AutoDrive:getVehicleToStop(vehicle, false, dt)
        if vehicle.lastSpeedReal <= 0.0008 then
            vehicle.ad.ccMode = AutoDrive.CC_MODE_IDLE
            vehicle.ad.reverseTimer = 11000
        end
    end
end

function AutoDrive:reverseVehicle(vehicle, dt)
    local finalSpeed = 9
    local acc = 1
    local allowedToDrive = true

    local node = vehicle.components[1].node
    if vehicle.getAIVehicleDirectionNode ~= nil then
        node = vehicle:getAIVehicleDirectionNode()
    end
    local x, y, z = getWorldTranslation(vehicle.components[1].node)
    local rx, ry, rz = localDirectionToWorld(vehicle.components[1].node, 0, 0, -1)
    x = x + rx
    z = z + rz
    --local lx, lz = AIVehicleUtil.getDriveDirection(vehicle.components[1].node, x, y, z)
    AIVehicleUtil.driveInDirection(vehicle, dt, 30, acc, 0.2, 20, allowedToDrive, false, nil, nil, finalSpeed, 1)
    --drivingEnabled = true
end

function AutoDrive:handlePureChaseMode(vehicle, dt)
    if vehicle.ccInfos.chaseSide ~= vehicle.ccInfos.lastChaseSide then
        vehicle.ad.ccMode = AutoDrive.CC_MODE_WAITING_FOR_COMBINE_TO_PASS_BY
    else
        AutoDrive:driveToChasePosition(vehicle, dt)
    end
end

function AutoDrive:chaseCombine(vehicle, dt)
    if vehicle.ad.currentCombine == nil then
        --g_logManager:devInfo("No combine assigned");
        return
    end

    AutoDrive:updateChaseModeInfos(vehicle, dt)

    if vehicle.ad.ccMode == AutoDrive.CC_MODE_IDLE then
        --g_logManager:devInfo("Init chase mode")
        AutoDrive:initChaseMode(vehicle, dt)
    elseif vehicle.ad.ccMode == AutoDrive.CC_MODE_CHASING then
        --g_logManager:devInfo("Chasing chase mode")
        AutoDrive:handlePureChaseMode(vehicle, dt)
    elseif vehicle.ad.ccMode == AutoDrive.CC_MODE_REVERSE_FROM_COLLISION then
        --g_logManager:devInfo("Reversing chase mode")
        AutoDrive:chaseModeReverse(vehicle, dt)
    elseif vehicle.ad.ccMode == AutoDrive.CC_MODE_WAITING_FOR_COMBINE_TO_PASS_BY then
        --g_logManager:devInfo("Pass by chase mode")
        AutoDrive:chaseModeWaitForCombineToPassBy(vehicle, dt)
    elseif vehicle.ad.ccMode == AutoDrive.CC_MODE_WAITING_FOR_COMBINE_TO_TURN then
        --g_logManager:devInfo("Wait for turn chase mode")
        AutoDrive:chaseModeWaitForCombineToTurn(vehicle, dt)
    end

    AutoDrive:checkForChaseModePauseCondition(vehicle, dt)
    AutoDrive:checkForChaseModeStopCondition(vehicle, dt)

    vehicle.ccInfos.lastChaseSide = vehicle.ccInfos.chaseSide
end

function AutoDrive:combineIsTurning(vehicle, combine, isChopper)
    if combine == nil then
        return false
    end
    local cpIsTurning = combine.cp ~= nil and (combine.cp.isTurning or (combine.cp.turnStage ~= nil and combine.cp.turnStage > 0))
    local cpIsTurningTwo = combine.cp ~= nil and combine.cp.driver and (combine.cp.driver.turnIsDriving or combine.cp.driver.fieldworkState == combine.cp.driver.states.TURNING)
    local aiIsTurning = (combine.getAIIsTurning ~= nil and combine:getAIIsTurning() == true)
    local combineSteering = false --combine.rotatedTime ~= nil and (math.deg(combine.rotatedTime) > 10);
    local combineIsTurning = cpIsTurning or cpIsTurningTwo or aiIsTurning or combineSteering
    --g_logManager:devInfo("cpIsTurning: " .. AutoDrive.boolToString(cpIsTurning) .. " aiIsTurning: " .. AutoDrive.boolToString(aiIsTurning) .. " combineSteering: " .. AutoDrive.boolToString(combineSteering) .. " isChopper: " .. AutoDrive.boolToString(isChopper) .. " combine.ad.driveForwardTimer:done(): " .. AutoDrive.boolToString(combine.ad.driveForwardTimer:done()) .. " noTurningTimer: " .. AutoDrive.boolToString(combine.ad.noTurningTimer:done()) .. " vehicle no movement: " .. vehicle.ad.noMovementTimer.elapsedTime);
    if ((isChopper and combine.ad.noTurningTimer:done()) or (combine.ad.driveForwardTimer:done() and (not isChopper))) and (not combineIsTurning) then
        return false
    end
    return true
end

function AutoDrive:getPipeChasePosition(vehicle, combine, isChopper, leftBlocked, rightBlocked)
    local worldX, worldY, worldZ = getWorldTranslation(combine.components[1].node)
    local rx, ry, rz = localDirectionToWorld(combine.components[1].node, 0, 0, 1)
    local combineVector = {x = rx, z = rz}
    local combineNormalVector = {x = -combineVector.z, z = combineVector.x}
    local nodeX, nodeY, nodeZ = worldX, worldY, worldZ
    local sideIndex = AutoDrive.ccSIDE_REAR
    if isChopper then
        if (not leftBlocked) then
            --g_logManager:devInfo("Taking left side");
            nodeX, nodeY, nodeZ = worldX - combineNormalVector.x * 7 + combineVector.x * 3, worldY, worldZ - combineNormalVector.z * 7 + combineVector.z * 3
            sideIndex = AutoDrive.ccSIDE_LEFT
        elseif (not rightBlocked) then
            --g_logManager:devInfo("Taking right side");
            nodeX, nodeY, nodeZ = worldX + combineNormalVector.x * 7 + combineVector.x * 3, worldY, worldZ + combineNormalVector.z * 7 + combineVector.z * 3
            sideIndex = AutoDrive.ccSIDE_RIGHT
        else
            --g_logManager:devInfo("Taking rear side");
            nodeX, nodeY, nodeZ = worldX - combineVector.x * 6, worldY, worldZ - combineVector.z * 6
            sideIndex = AutoDrive.ccSIDE_REAR
        end
    else
        local combineFillLevel, combineLeftCapacity = AutoDrive.getFilteredFillLevelAndCapacityOfAllUnits(combine)
        local combineMaxCapacity = combineFillLevel + combineLeftCapacity
        local combineFillPercent = (combineFillLevel / combineMaxCapacity) * 100

        if (not leftBlocked) and combineFillPercent < 90 then
            AutoDrive.debugPrint(vehicle, AutoDrive.DC_COMBINEINFO, " getPipeChasePosition - combineFillPercent: " .. combineFillPercent .. " -> taking left side")
            nodeX, nodeY, nodeZ = worldX - combineNormalVector.x * 9.5 + combineVector.x * 6, worldY, worldZ - combineNormalVector.z * 9.5 + combineVector.z * 6

            local spec = combine.spec_pipe
            if (spec.currentState == spec.targetState and (spec.currentState == 2 or combine.typeName == "combineCutterFruitPreparer")) and (not isChopper) then
                local dischargeNode = nil
                for _, dischargeNodeIter in pairs(combine.spec_dischargeable.dischargeNodes) do
                    dischargeNode = dischargeNodeIter
                end

                local pipeOffset = AutoDrive.getSetting("pipeOffset", vehicle)
                local trailerOffset = AutoDrive.getSetting("trailerOffset", vehicle)

                nodeX, nodeY, nodeZ = getWorldTranslation(dischargeNode.node)
                nodeX, nodeY, nodeZ = (nodeX + (vehicle.sizeLength / 2 + 8 + trailerOffset) * rx) - pipeOffset * combineNormalVector.x, nodeY, nodeZ + (vehicle.sizeLength / 2 + 8 + trailerOffset) * rz - pipeOffset * combineNormalVector.z

                sideIndex = AutoDrive.ccSIDE_LEFT
            end
        else
            AutoDrive.debugPrint(vehicle, AutoDrive.DC_COMBINEINFO, " getPipeChasePosition - combineFillPercent: " .. combineFillPercent .. " -> taking rear side")
            sideIndex = AutoDrive.ccSIDE_REAR
            local chaseCombinePos = AutoDrive:getCombineChasePosition(vehicle, combine)
            nodeX = chaseCombinePos.x
            nodeY = chaseCombinePos.y
            nodeZ = chaseCombinePos.z
        end
    end

    return {x = nodeX, y = nodeY, z = nodeZ}, sideIndex
end

function AutoDrive:getCombineChasePosition(vehicle, combine)
    local worldX, worldY, worldZ = getWorldTranslation(combine.components[1].node)
    local rx, ry, rz = localDirectionToWorld(combine.components[1].node, 0, 0, 1)
    local combineVector = {x = rx, z = rz}

    local distance = AutoDrive.PATHFINDER_FOLLOW_DISTANCE
    if combine:getIsBufferCombine() then
        distance = distance - 35
    end

    return {x = worldX - distance * rx, y = worldY, z = worldZ - distance * rz}
end

function AutoDrive:getAngleToCombineHeading(vehicle, combine)
    if vehicle == nil or combine == nil then
        return math.huge
    end

    local combineWorldX, combineWorldY, combineWorldZ = getWorldTranslation(combine.components[1].node)
    local combineRx, combineRy, combineRz = localDirectionToWorld(combine.components[1].node, 0, 0, 1)

    local worldX, worldY, worldZ = getWorldTranslation(vehicle.components[1].node)
    local rx, ry, rz = localDirectionToWorld(vehicle.components[1].node, 0, 0, 1)

    return math.abs(AutoDrive.angleBetween({x = rx, z = rz}, {x = combineRx, z = combineRz}))
end

function AutoDrive:getAngleToChasePos(vehicle, chasePos)
    if vehicle == nil or chasePos == nil then
        return math.huge
    end

    local worldX, worldY, worldZ = getWorldTranslation(vehicle.components[1].node)
    local rx, ry, rz = localDirectionToWorld(vehicle.components[1].node, 0, 0, 1)

    return math.abs(AutoDrive.angleBetween({x = rx, z = rz}, {x = chasePos.x - worldX, z = chasePos.z - worldZ}))
end

function AutoDrive:handlePathPlanning(vehicle, dt)
    local storedPathFinderTime = AutoDrive.settings["pathFinderTime"].current
    if vehicle.ad.combineState == AutoDrive.PREDRIVE_COMBINE then
        AutoDrive.settings["pathFinderTime"].current = 2
    end
    AutoDrivePathFinder:updatePathPlanning(vehicle)
    if vehicle.ad.combineState == AutoDrive.PREDRIVE_COMBINE then
        AutoDrive.settings["pathFinderTime"].current = storedPathFinderTime
    end

    if AutoDrivePathFinder:isPathPlanningFinished(vehicle) then
        vehicle.ad.wayPoints = vehicle.ad.pf.wayPoints
        vehicle.ad.currentWayPoint = 1

        if vehicle.ad.combineState == AutoDrive.PREDRIVE_COMBINE then
            if #vehicle.ad.wayPoints <= 1 then
                vehicle.ad.wayPoints = nil
                if vehicle.ad.waitForPreDriveTimer <= 0 then
                    if not AutoDrive:restartPathFinder(vehicle) then
                        return true --error
                    end
                else
                    vehicle.ad.waitForPreDriveTimer = vehicle.ad.waitForPreDriveTimer - dt
                end
                return false
            end
        end

        return true
    end
    return false
end

function AutoDrive:restartPathFinder(vehicle)
    local combine = vehicle.ad.currentCombine
    if combine == nil then
        return false
    end
    AutoDrivePathFinder:startPathPlanningToCombine(vehicle, combine, nil)
    vehicle.ad.currentCombine = combine
    AutoDrive.waitingUnloadDrivers[vehicle] = nil
    vehicle.ad.combineState = AutoDrive.PREDRIVE_COMBINE
    return true
end

function AutoDrive:checkDoneUnloading(vehicle)
    local trailers, trailerCount = AutoDrive.getTrailersOf(vehicle)
    local fillLevel, leftCapacity = AutoDrive.getFilteredFillLevelAndCapacityOfAllUnits(trailers[vehicle.ad.currentTrailer])
    local maxCapacity = fillLevel + leftCapacity

    local combineFillLevel, combineLeftCapacity = AutoDrive.getFilteredFillLevelAndCapacityOfAllUnits(vehicle.ad.currentCombine)
    local combineMaxCapacity = combineFillLevel + combineLeftCapacity

    return ((combineMaxCapacity - combineLeftCapacity) < 100), (1 - (leftCapacity / maxCapacity))
end

function AutoDrive:combineStateToDescription(vehicle)
    if vehicle.ad.combineState == AutoDrive.WAIT_FOR_COMBINE then
        return g_i18n:getText("ad_wait_for_combine")
    elseif vehicle.ad.combineState == AutoDrive.DRIVE_TO_COMBINE or vehicle.ad.combineState == AutoDrive.PREDRIVE_COMBINE then
        return g_i18n:getText("ad_drive_to_combine")
    elseif vehicle.ad.combineState == AutoDrive.WAIT_TILL_UNLOADED then
        return g_i18n:getText("ad_unloading_combine")
    elseif vehicle.ad.combineState == AutoDrive.DRIVE_TO_PARK_POS then
        return g_i18n:getText("ad_drive_to_parkpos")
    elseif vehicle.ad.combineState == AutoDrive.DRIVE_TO_START_POS then
        return g_i18n:getText("ad_drive_to_startpos")
    elseif vehicle.ad.combineState == AutoDrive.DRIVE_TO_UNLOAD_POS then
        return g_i18n:getText("ad_drive_to_unloadpos")
    end

    return
end

function AutoDrive:isOnField(vehicle)
    if vehicle ~= nil and vehicle.ad ~= nil and vehicle.ad.combineState ~= nil then
        if vehicle.ad.combineState == AutoDrive.CHASE_COMBINE or vehicle.ad.combineState == AutoDrive.DRIVE_TO_COMBINE or vehicle.ad.combineState == AutoDrive.PREDRIVE_COMBINE or vehicle.ad.combineState == AutoDrive.DRIVE_TO_PARK_POS or vehicle.ad.combineState == AutoDrive.DRIVE_TO_START_POS then
            return true
        end
    end

    return false
end

function AutoDrive:sendCombineUnloaderToStartOrToUnload(vehicle, toStart)
    if vehicle == nil then
        return
    end

    local closest = AutoDrive:findClosestWayPoint(vehicle)
    vehicle.ad.wayPointsChanged = true

    if toStart == false then --going to unload position
        vehicle.ad.wayPoints = AutoDrive:FastShortestPath(AutoDrive.mapWayPoints, closest, AutoDrive.mapMarker[vehicle.ad.mapMarkerSelected_Unload].name, AutoDrive.mapMarker[vehicle.ad.mapMarkerSelected_Unload].id)
        AutoDrive.waitingUnloadDrivers[vehicle] = nil
        vehicle.ad.combineState = AutoDrive.DRIVE_TO_UNLOAD_POS
        vehicle.ad.onRouteToSecondTarget = true
    else --going to start position
        vehicle.ad.timeTillDeadLock = 15000
        if vehicle.ad.wayPoints[vehicle.ad.currentWayPoint] ~= nil then --Don't search starting waypoint if we were already driving to the unload pos. Just use this point.
            closest = vehicle.ad.wayPoints[vehicle.ad.currentWayPoint].id
        end
        vehicle.ad.wayPoints = AutoDrive:FastShortestPath(AutoDrive.mapWayPoints, closest, AutoDrive.mapMarker[vehicle.ad.mapMarkerSelected].name, vehicle.ad.targetSelected)
        --vehicle.ad.isPaused = true why was that in there?
        vehicle.ad.combineState = AutoDrive.COMBINE_UNINITIALIZED
        vehicle.ad.onRouteToSecondTarget = false
        vehicle.ad.currentTrailer = 1
        vehicle.ad.designatedTrailerFillLevel = math.huge
        if AutoDrive.getSetting("distributeToFolder", vehicle) and AutoDrive.getSetting("useFolders") then
            AutoDrive:setNextTargetInFolder(vehicle)
        end
    end

    vehicle.ad.currentWayPoint = 1
    vehicle.ad.targetX = vehicle.ad.wayPoints[vehicle.ad.currentWayPoint].x
    vehicle.ad.targetZ = vehicle.ad.wayPoints[vehicle.ad.currentWayPoint].z
    if vehicle.ad.currentCombine ~= nil then
        vehicle.ad.currentCombine.ad.currentDriver = nil
        vehicle.ad.currentCombine.ad.preCalledDriver = false
        vehicle.ad.currentCombine.ad.driverOnTheWay = false
        vehicle.ad.currentCombine = nil
    end
end

function AutoDrive:setNextTargetInFolder(vehicle)
    local mapMarkerCurrent = AutoDrive.mapMarker[vehicle.ad.mapMarkerSelected_Unload]
    local group = mapMarkerCurrent.group
    if group ~= "All" then
        local firstMarkerInGroup = nil
        local nextMarkerInGroup = nil
        local markerSeen = false
        for markerID, marker in pairs(AutoDrive.mapMarker) do
            if marker.group == group then
                if firstMarkerInGroup == nil then
                    firstMarkerInGroup = markerID
                end

                if markerSeen and nextMarkerInGroup == nil then
                    nextMarkerInGroup = markerID
                end

                if markerID == vehicle.ad.mapMarkerSelected_Unload then
                    markerSeen = true
                end
            end
        end

        local markerToSet = vehicle.ad.mapMarkerSelected_Unload
        if nextMarkerInGroup ~= nil then
            markerToSet = nextMarkerInGroup
        elseif firstMarkerInGroup ~= nil then
            markerToSet = firstMarkerInGroup
        end

        vehicle.ad.mapMarkerSelected_Unload = markerToSet
        if AutoDrive.mapMarker[markerToSet] ~= nil then
            vehicle.ad.targetSelected_Unload = AutoDrive.mapMarker[markerToSet].id
            vehicle.ad.nameOfSelectedTarget_Unload = AutoDrive.mapMarker[markerToSet].name
        end
    end
end

function AutoDrive:checkIfShortcutToCombinePossible(vehicle, dt)
    if vehicle.ad.checkShortcutTimer == nil then
        vehicle.ad.checkShortcutTimer = AutoDriveTON:new()
    end
    if vehicle.ad.currentCombine == nil then
        return
    end

    vehicle.ad.checkShortcutTimer:timer(true, 5000, dt)

    if vehicle.ad.checkShortcutTimer:done() then
        vehicle.ad.checkShortcutTimer:timer(false)

        local worldX, worldY, worldZ = getWorldTranslation(vehicle.components[1].node)
        local distanceToLastWayPoint = math.huge
        if vehicle.ad.wayPoints ~= nil then
            distanceToLastWayPoint = MathUtil.vector2Length(worldX - vehicle.ad.wayPoints[#vehicle.ad.wayPoints].x, worldZ - vehicle.ad.wayPoints[#vehicle.ad.wayPoints].z)
        end

        if distanceToLastWayPoint < 35 then
            return
        end

        AutoDrivePathFinder:startPathPlanningToCombine(vehicle, vehicle.ad.currentCombine, nil)
        AutoDrivePathFinder:updatePathPlanning(vehicle)
        if AutoDrivePathFinder:isPathPlanningFinished(vehicle) then
            vehicle.ad.wayPoints = vehicle.ad.pf.wayPoints
            vehicle.ad.currentWayPoint = 1

            if vehicle.ad.combineState == AutoDrive.PREDRIVE_COMBINE then
                if #vehicle.ad.wayPoints <= 1 then
                    vehicle.ad.wayPoints = nil
                    if vehicle.ad.waitForPreDriveTimer <= 0 then
                        if not AutoDrive:restartPathFinder(vehicle) then
                            return true --error
                        end
                    else
                        vehicle.ad.waitForPreDriveTimer = vehicle.ad.waitForPreDriveTimer - dt
                    end
                    return false
                end
            end

            return true
        end
    end
end
