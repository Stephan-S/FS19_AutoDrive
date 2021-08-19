AutoDrive.destinationListeners = {}

--startX, startZ: World location
--startYRot: rotation in rad
--destinationID: ID of marker to find path to
--options (optional): options.minDistance, options.maxDistance (default 1m, 20m) define boundaries between the first AutoDrive waypoint and the starting location.
function AutoDrive:GetPath(startX, startZ, startYRot, destinationID, options)
    AutoDrive.debugPrint(nil, AutoDrive.DC_EXTERNALINTERFACEINFO, "AutoDrive:GetPath(%s, %s, %s, %s, %s)", startX, startZ, startYRot, destinationID, options)
    if startX == nil or startZ == nil or startYRot == nil or destinationID == nil or ADGraphManager:getMapMarkerById(destinationID) == nil then
        return
    end
    startYRot = AutoDrive.normalizeAngleToPlusMinusPI(startYRot)
    local markerName = ADGraphManager:getMapMarkerById(destinationID).name
    local startPoint = {x = startX, z = startZ}
    local minDistance = 1
    local maxDistance = 20
    if options ~= nil and options.minDistance ~= nil then
        minDistance = options.minDistance
    end
    if options ~= nil and options.maxDistance ~= nil then
        maxDistance = options.maxDistance
    end
    local directionVec = {x = math.sin(startYRot), z = math.cos(startYRot)}
    local bestPoint = ADGraphManager:findMatchingWayPoint(startPoint, directionVec, ADGraphManager:getWayPointsInRange(startPoint, minDistance, maxDistance))

    if bestPoint == -1 then
        bestPoint = AutoDrive:GetClosestPointToLocation(startX, startZ, minDistance)
        if bestPoint == -1 then
            return
        end
    end

    return ADGraphManager:FastShortestPath(bestPoint, markerName, ADGraphManager:getMapMarkerById(destinationID).id)
end

function AutoDrive:GetPathVia(startX, startZ, startYRot, viaID, destinationID, options)
    AutoDrive.debugPrint(nil, AutoDrive.DC_EXTERNALINTERFACEINFO, "AutoDrive:GetPathVia(%s, %s, %s, %s, %s, %s)", startX, startZ, startYRot, viaID, destinationID, options)
    if startX == nil or startZ == nil or startYRot == nil or destinationID == nil or ADGraphManager:getMapMarkerById(destinationID) == nil or viaID == nil or ADGraphManager:getMapMarkerById(viaID) == nil then
        return
    end
    startYRot = AutoDrive.normalizeAngleToPlusMinusPI(startYRot)

    local markerName = ADGraphManager:getMapMarkerById(viaID).name
    local startPoint = {x = startX, z = startZ}
    local minDistance = 1
    local maxDistance = 20
    if options ~= nil and options.minDistance ~= nil then
        minDistance = options.minDistance
    end
    if options ~= nil and options.maxDistance ~= nil then
        maxDistance = options.maxDistance
    end
    local directionVec = {x = math.sin(startYRot), z = math.cos(startYRot)}
    local bestPoint = ADGraphManager:findMatchingWayPoint(startPoint, directionVec, ADGraphManager:getWayPointsInRange(startPoint, minDistance, maxDistance))

    if bestPoint == -1 then
        bestPoint = AutoDrive:GetClosestPointToLocation(startX, startZ, minDistance)
        if bestPoint == -1 then
            return
        end
    end

    local toViaID = ADGraphManager:FastShortestPath(bestPoint, markerName, ADGraphManager:getMapMarkerById(viaID).id)

    if toViaID == nil or #toViaID < 1 then
        return
    end

    local fromViaID = ADGraphManager:FastShortestPath(toViaID[#toViaID].id, ADGraphManager:getMapMarkerById(destinationID).name, ADGraphManager:getMapMarkerById(destinationID).id)

    for i, wayPoint in pairs(fromViaID) do
        if i > 1 then
            table.insert(toViaID, wayPoint)
        end
    end

    return toViaID
end

function AutoDrive:GetDriverName(vehicle)
    return vehicle.ad.stateModule:getName()
end

function AutoDrive:GetAvailableDestinations()
    AutoDrive.debugPrint(nil, AutoDrive.DC_EXTERNALINTERFACEINFO, "AutoDrive:GetAvailableDestinations()")
    local destinations = {}
    for markerID, marker in pairs(ADGraphManager:getMapMarkers()) do
        local point = ADGraphManager:getWayPointById(marker.id)
        if point ~= nil then
            destinations[markerID] = {name = marker.name, x = point.x, y = point.y, z = point.z, id = markerID}
        end
    end
    return destinations
end

function AutoDrive:GetClosestPointToLocation(x, z, minDistance)
    AutoDrive.debugPrint(nil, AutoDrive.DC_EXTERNALINTERFACEINFO, "AutoDrive:GetClosestPointToLocation(%s, %s, %s)", x, z, minDistance)
    local closest = -1
    if ADGraphManager:getWayPointsCount() < 1 then
        local distance = math.huge

        for i in pairs(ADGraphManager:getWayPoints()) do
            local dis = MathUtil.vector2Length(ADGraphManager:getWayPointById(i).x - x, ADGraphManager:getWayPointById(i).z - z)
            if dis < distance and dis >= minDistance then
                closest = i
                distance = dis
            end
        end
    end

    return closest
end

function AutoDrive:StartDriving(vehicle, destinationID, unloadDestinationID, callBackObject, callBackFunction, callBackArg)
    AutoDrive.debugPrint(vehicle, AutoDrive.DC_EXTERNALINTERFACEINFO, "AutoDrive:StartDriving(%s, %s, %s, %s, %s)", destinationID, unloadDestinationID, callBackObject, callBackFunction, callBackArg)
    if vehicle ~= nil and vehicle.ad ~= nil and not vehicle.ad.stateModule:isActive() then
        vehicle.ad.callBackObject = callBackObject
        vehicle.ad.callBackFunction = callBackFunction
        vehicle.ad.callBackArg = callBackArg

        if destinationID ~= nil and destinationID >= 0 and ADGraphManager:getMapMarkerById(destinationID) ~= nil then
            vehicle.ad.stateModule:setFirstMarker(destinationID)
        end
        if unloadDestinationID ~= nil then
            if unloadDestinationID >= 0 and ADGraphManager:getMapMarkerById(unloadDestinationID) ~= nil then
                vehicle.ad.stateModule:setSecondMarker(unloadDestinationID)
                vehicle.ad.stateModule:getCurrentMode():start()
            elseif unloadDestinationID == -3 then --park
                --must be using 'Drive' mode if only one destination is supplied. For now, also set the onRouteToPark variable to true, so AD will shutdown motor and lights on arrival
                local parkDestinationAtJobFinished = vehicle.ad.stateModule:getParkDestinationAtJobFinished()
                if parkDestinationAtJobFinished >= 1 then
                    vehicle.ad.stateModule:setMode(AutoDrive.MODE_DRIVETO)
                    vehicle.ad.stateModule:setFirstMarker(parkDestinationAtJobFinished)
                    vehicle.ad.stateModule:getCurrentMode():start()
                    vehicle.ad.onRouteToPark = true
                else
                    AutoDriveMessageEvent.sendMessage(vehicle, ADMessagesManager.messageTypes.ERROR, "$l10n_AD_parkVehicle_noPosSet;", 5000)
                    -- stop vehicle movement
                    AIVehicleUtil.driveInDirection(vehicle, 16, 30, 0, 0.2, 20, false, false, 0, 0, 0, 1)
                    vehicle:setCruiseControlState(Drivable.CRUISECONTROL_STATE_OFF)
                    if vehicle.stopMotor ~= nil then
                        vehicle:stopMotor()
                    end
                end
            else --unloadDestinationID == -2 refuel
                -- vehicle.ad.stateModule:setMode(AutoDrive.MODE_DRIVETO) -- should fix #1477
                vehicle.ad.stateModule:getCurrentMode():start()
            end
        end
    end
end

function AutoDrive:StartDrivingWithPathFinder(vehicle, destinationID, unloadDestinationID, callBackObject, callBackFunction, callBackArg)
    AutoDrive.debugPrint(vehicle, AutoDrive.DC_EXTERNALINTERFACEINFO, "AutoDrive:StartDrivingWithPathFinder(%s, %s, %s, %s, %s)", destinationID, unloadDestinationID, callBackObject, callBackFunction, callBackArg)
    if vehicle ~= nil and vehicle.ad ~= nil and not vehicle.ad.stateModule:isActive() then
        if unloadDestinationID < -1 then
            if unloadDestinationID == -3 then --park
                AutoDrive:StartDriving(vehicle, destinationID, unloadDestinationID, callBackObject, callBackFunction, callBackArg)
            elseif unloadDestinationID == -2 then --refuel
                AutoDrive:StartDriving(vehicle, vehicle.ad.stateModule:getFirstMarkerId(), unloadDestinationID, callBackObject, callBackFunction, callBackArg)
            end
        else
            AutoDrive:StartDriving(vehicle, destinationID, unloadDestinationID, callBackObject, callBackFunction, callBackArg)
        end
    end
end

function AutoDrive:GetParkDestination(vehicle)
    AutoDrive.debugPrint(vehicle, AutoDrive.DC_EXTERNALINTERFACEINFO, "AutoDrive:GetParkDestination()")
    if vehicle ~= nil and vehicle.ad ~= nil and vehicle.ad.stateModule ~= nil then
        local parkDestinationAtJobFinished = vehicle.ad.stateModule:getParkDestinationAtJobFinished()
        if parkDestinationAtJobFinished >= 1 then
            return parkDestinationAtJobFinished
        end
    end
    return nil
end

function AutoDrive:registerDestinationListener(callBackObject, callBackFunction)
    AutoDrive.debugPrint(nil, AutoDrive.DC_EXTERNALINTERFACEINFO, "AutoDrive:registerDestinationListener(%s, %s)", callBackObject, callBackFunction)
    if AutoDrive.destinationListeners[callBackObject] == nil then
        AutoDrive.destinationListeners[callBackObject] = callBackFunction
    end
end

function AutoDrive:unRegisterDestinationListener(callBackObject)
    AutoDrive.debugPrint(nil, AutoDrive.DC_EXTERNALINTERFACEINFO, "AutoDrive:unRegisterDestinationListener(%s)", callBackObject)
    if AutoDrive.destinationListeners[callBackObject] ~= nil then
        AutoDrive.destinationListeners[callBackObject] = nil
    end
end

function AutoDrive:notifyDestinationListeners()
    AutoDrive.debugPrint(nil, AutoDrive.DC_EXTERNALINTERFACEINFO, "AutoDrive:notifyDestinationListeners()")
    for object, callBackFunction in pairs(AutoDrive.destinationListeners) do
        callBackFunction(object, true)
    end
    AutoDrive.triggerStaticOutput()
end

function AutoDrive:combineIsCallingDriver(combine)	--only for CoursePlay
	local openPipe,_ = ADHarvestManager.getOpenPipePercent(combine)
	return openPipe or ADHarvestManager.doesHarvesterNeedUnloading(combine, true)
end

function AutoDrive:getCombineOpenPipePercent(combine)	--for AIVE
	local _, pipePercent = ADHarvestManager.getOpenPipePercent(combine)
	return pipePercent
end

-- start CP
function AutoDrive:StartCP(vehicle)
    if vehicle == nil then 
        return 
    end
    AutoDrive.debugPrint(vehicle, AutoDrive.DC_EXTERNALINTERFACEINFO, "AutoDrive:StartCP...")
    if vehicle.startCpDriver then
        -- newer CP versions use this function to start the CP driver
        vehicle:startCpDriver()
    else
        -- for backward compatibility for older CP versions
        g_courseplay.courseplay:start(vehicle)
    end
end

-- stop CP if it is active
function AutoDrive:StopCP(vehicle)
    if vehicle == nil then 
        return 
    end
    AutoDrive.debugPrint(vehicle, AutoDrive.DC_EXTERNALINTERFACEINFO, "AutoDrive:StopCP...")
    if g_courseplay ~= nil and vehicle.cp ~= nil and vehicle.getIsCourseplayDriving ~= nil and vehicle:getIsCourseplayDriving() then
        if vehicle.ad.stateModule:getStartCP_AIVE() then
            vehicle.ad.stateModule:toggleStartCP_AIVE()
        end
        AutoDrive.debugPrint(vehicle, AutoDrive.DC_EXTERNALINTERFACEINFO, "AutoDrive:StopCP call CP stop")
        if vehicle.stopCpDriver then
            -- newer CP versions use this function to stop the CP driver
            vehicle:stopCpDriver()
        else
            -- for backward compatibility for older CP versions
            g_courseplay.courseplay:stop(vehicle)
        end
    end
end

function AutoDrive:HoldDriving(vehicle)
    if vehicle ~= nil and vehicle.ad ~= nil and vehicle.ad.stateModule:isActive() then
        AutoDrive.debugPrint(vehicle, AutoDrive.DC_EXTERNALINTERFACEINFO, "AutoDrive:HoldDriving should set setPaused")
        vehicle.ad.drivePathModule:setPaused()
    end
end

function AutoDrive:holdCPCombine(combine)
    -- Stopping CP drivers for now
    if combine ~= nil then
        if combine.trailingVehicle ~= nil then
            -- harvester is trailed - CP use the trailing vehicle
            if combine.trailingVehicle.cp and combine.trailingVehicle.cp.driver and combine.trailingVehicle.cp.driver.holdForUnloadOrRefill then
                combine.trailingVehicle.cp.driver:holdForUnloadOrRefill()
            end
        else
            if combine.cp and combine.cp.driver and combine.cp.driver.holdForUnloadOrRefill then
                combine.cp.driver:holdForUnloadOrRefill()
            end
        end
    end
end

function AutoDrive:getIsCPActive(vehicle)
    return vehicle ~= nil and g_courseplay ~= nil and vehicle.cp ~= nil and vehicle.getIsCourseplayDriving ~= nil and vehicle:getIsCourseplayDriving()
end

-- Autoloader
--[[
easyAutoLoader:
- old, i.e. embedded in mod, has easyAutoLoaderActionEvents
- new, standalone FS19_EasyAutoLoad has the variables in spec_easyAutoLoader, but functions direct in vehicle type
]]
function AutoDrive:hasAL(object)
    if object == nil then
        return false
    end
    -- g_logManager:info("[AD] AutoDrive:hasAL object.easyAutoLoaderActionEvents %s object.spec_easyAutoLoader %s", tostring(object.easyAutoLoaderActionEvents), tostring(object.easyAutoLoaderActionEvents))
    return object.easyAutoLoaderActionEvents ~= nil or (object.spec_easyAutoLoader ~= nil and object.spec_easyAutoLoader.workMode ~= nil )
end

function AutoDrive:setALOn(object)
    if object == nil or not AutoDrive:hasAL(object) then
        return false
    end
    local workMode = true
    if object.easyAutoLoaderActionEvents ~= nil then
        workMode = object.workMode
    elseif object.spec_easyAutoLoader ~= nil and object.spec_easyAutoLoader.workMode ~= nil then
        workMode = object.spec_easyAutoLoader.workMode
    end
    -- g_logManager:info("[AD] AutoDrive:setALOn object.workMode %s", tostring(object.workMode))
    if workMode == false then
        -- g_logManager:info("[AD] AutoDrive:setALOn setWorkMode")
        object:setWorkMode()
    end
    -- g_logManager:info("[AD] AutoDrive:setALOn object.workMode %s", tostring(object.workMode))
end

function AutoDrive:setALOff(object)
    if object == nil or not AutoDrive:hasAL(object) then
        return false
    end
    local workMode = false
    if object.easyAutoLoaderActionEvents ~= nil then
        workMode = object.workMode
    elseif object.spec_easyAutoLoader ~= nil and object.spec_easyAutoLoader.workMode ~= nil then
        workMode = object.spec_easyAutoLoader.workMode
    end
    -- g_logManager:info("[AD] AutoDrive:setALOff object.workMode %s", tostring(object.workMode))
    if workMode == true then
        -- g_logManager:info("[AD] AutoDrive:setALOff setWorkMode")
        object:setWorkMode()
    end
    -- g_logManager:info("[AD] AutoDrive:setALOff object.workMode %s", tostring(object.workMode))
end

function AutoDrive.activateTrailerAL(vehicle, trailers)
    if vehicle == nil or trailers == nil then
        return false
    end
    if #trailers > 0 then
        for i=1, #trailers do
            AutoDrive:setALOn(trailers[i])
        end
    end
end

function AutoDrive.deactivateTrailerAL(vehicle, trailers)
    if vehicle == nil or trailers == nil then
        return false
    end
    if #trailers > 0 then
        for i=1, #trailers do
            AutoDrive:setALOff(trailers[i])
        end
    end
end

--[[
    values = {0, 1, 2, 3, 4},
    texts = {"gui_ad_AL_off", "gui_ad_AL_center", "gui_ad_AL_left", "gui_ad_AL_behind", "gui_ad_AL_right"},

]]

function AutoDrive:unloadAL(object)
    if object == nil or not AutoDrive:hasAL(object) then
        return false
    end
    -- g_logManager:info("[AD] AutoDrive:unloadAL start ")
    local rootVehicle = object:getRootVehicle()
    local unloadPosition = AutoDrive.getSetting("ALUnload", rootVehicle)
    if unloadPosition ~= nil and unloadPosition > 0 then
        -- g_logManager:info("[AD] AutoDrive:unloadAL should unload unloadPosition %s", tostring(unloadPosition))
        -- should unload
        AutoDrive:setALOff(object)
        if unloadPosition > 1 then
            for i=1, unloadPosition-1 do
                object:changeMarkerPosition()
            end
        end
        object:setUnload()
    end
    -- g_logManager:info("[AD] AutoDrive:unloadAL end")
end

function AutoDrive:unloadALAll(vehicle)
    if vehicle == nil then
        return false
    end
    -- g_logManager:info("[AD] AutoDrive:unloadALAll start ")
    local trailers, trailerCount = AutoDrive.getTrailersOf(vehicle, false)
    if trailerCount > 0 then
        for i=1, trailerCount do
            AutoDrive:unloadAL(trailers[i])
        end
    end
    -- g_logManager:info("[AD] AutoDrive:unloadALAll end")
end

function AutoDrive:getALOverallFillLevelPercentage(vehicle, trailers)
    if vehicle == nil or trailers == nil then
        return 0
    end
    local percentage = 0
    local percentages = 0
    if #trailers > 0 then
        for i=1, #trailers do
            if trailers[i].easyAutoLoaderActionEvents ~= nil then
                    percentages = percentages + (trailers[i].currentNumObjects / trailers[i].autoLoadObjects[trailers[i].state].maxNumObjects)
            elseif trailers[i].spec_easyAutoLoader ~= nil and trailers[i].spec_easyAutoLoader.workMode ~= nil then
                    percentages = percentages + (trailers[i].spec_easyAutoLoader.currentNumObjects / trailers[i].spec_easyAutoLoader.autoLoadObjects[trailers[i].spec_easyAutoLoader.state].maxNumObjects)
            end
        end
        percentage = percentages / #trailers
    end
    return percentage
end

function AutoDrive:getALFillLevelPercentage(object)
    if object == nil then
        return 0
    end
    local currentNumObjects = 0
    local maxNumObjects = 1
    if object.easyAutoLoaderActionEvents ~= nil then
        currentNumObjects = object.currentNumObjects
        maxNumObjects = object.autoLoadObjects[object.state].maxNumObjects
    elseif object.spec_easyAutoLoader ~= nil and object.spec_easyAutoLoader.workMode ~= nil then
        currentNumObjects = object.spec_easyAutoLoader.currentNumObjects
        maxNumObjects = object.spec_easyAutoLoader.autoLoadObjects[object.spec_easyAutoLoader.state].maxNumObjects
    end
    if maxNumObjects == 0 then
        maxNumObjects = 1
    end
    return (currentNumObjects / maxNumObjects)
end

function AutoDrive:getALFillLevelAndCapacityOfAllUnits(object)
    if object == nil then
        return 0,0
    end
    local fillLevel = 0
    local leftCapacity = 0

    if object.easyAutoLoaderActionEvents ~= nil then
        fillLevel = object.currentNumObjects
        leftCapacity = object.autoLoadObjects[object.state].maxNumObjects - fillLevel
    elseif object.spec_easyAutoLoader ~= nil and object.spec_easyAutoLoader.workMode ~= nil then
        fillLevel = object.spec_easyAutoLoader.currentNumObjects
        leftCapacity = object.spec_easyAutoLoader.autoLoadObjects[object.spec_easyAutoLoader.state].maxNumObjects - fillLevel
    end
    return fillLevel, leftCapacity
end