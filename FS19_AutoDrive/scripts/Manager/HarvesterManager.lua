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



function AutoDrive:callDriverToCombine(combine)
    local spec = combine.spec_pipe
    if spec.currentState == spec.targetState and (spec.currentState == 2 or combine.typeName == "combineCutterFruitPreparer") then
        local worldX, _, worldZ = getWorldTranslation(combine.components[1].node)

        for _, dischargeNode in pairs(combine.spec_dischargeable.dischargeNodes) do
            --local nodeX, nodeY, nodeZ = getWorldTranslation(dischargeNode.node)
            if table.count(AutoDrive.waitingUnloadDrivers) > 0 then
                local closestDriver = nil
                local closestDistance = math.huge
                for _, driver in pairs(AutoDrive.waitingUnloadDrivers) do
                    local driverX, _, driverZ = getWorldTranslation(driver.components[1].node)
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
                    closestDriver.ad.fieldParkLocations = nil
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
    local worldX, _, worldZ = getWorldTranslation(combine.components[1].node)

    if table.count(AutoDrive.waitingUnloadDrivers) > 0 then
        local closestDriver = nil
        local closestDistance = math.huge
        for _, driver in pairs(AutoDrive.waitingUnloadDrivers) do
            local driverX, _, driverZ = getWorldTranslation(driver.components[1].node)
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
    return (combine.ad ~= nil) and ((combine.ad.tryingToCallDriver and table.count(AutoDrive.waitingUnloadDrivers) > 0) or combine.ad.driverOnTheWay)
end