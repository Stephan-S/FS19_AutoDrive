--startX, startZ: World location
--startYRot: rotation in rad
--destinationID: ID of marker to find path to
--options (optional): options.minDistance, options.maxDistance (default 1m, 20m) define boundaries between the first AutoDrive waypoint and the starting location.
function AutoDrive:GetPath(startX, startZ, startYRot, destinationID, options)
    AutoDrive.debugPrint(nil, AutoDrive.DC_EXTERNALINTERFACEINFO, "AutoDrive:GetPath(%s, %s, %s, %s, %s)", startX, startZ, startYRot, destinationID, options)
    if startX == nil or startZ == nil or startYRot == nil or destinationID == nil or AutoDrive.mapMarker[destinationID] == nil then
        return
    end
    startYRot = AutoDrive.normalizeAngleToPlusMinusPI(startYRot)
    local markerName = AutoDrive.mapMarker[destinationID].name
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
    local bestPoint = AutoDrive:findMatchingWayPoint(startPoint, directionVec, minDistance, maxDistance)

    if bestPoint == -1 then
        bestPoint = AutoDrive:GetClosestPointToLocation(startX, startZ, minDistance, maxDistance)
        if bestPoint == -1 then
            return
        end
    end

    return AutoDrive:FastShortestPath(AutoDrive.mapWayPoints, bestPoint, markerName, AutoDrive.mapMarker[destinationID].id)
end

function AutoDrive:GetPathVia(startX, startZ, startYRot, viaID, destinationID, options)
    AutoDrive.debugPrint(nil, AutoDrive.DC_EXTERNALINTERFACEINFO, "AutoDrive:GetPathVia(%s, %s, %s, %s, %s, %s)", startX, startZ, startYRot, viaID, destinationID, options)
    if startX == nil or startZ == nil or startYRot == nil or destinationID == nil or AutoDrive.mapMarker[destinationID] == nil or viaID == nil or AutoDrive.mapMarker[viaID] == nil then
        return
    end
    startYRot = AutoDrive.normalizeAngleToPlusMinusPI(startYRot)

    local markerName = AutoDrive.mapMarker[viaID].name
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
    local bestPoint = AutoDrive:findMatchingWayPoint(startPoint, directionVec, minDistance, maxDistance)

    if bestPoint == -1 then
        bestPoint = AutoDrive:GetClosestPointToLocation(startX, startZ, minDistance)
        if bestPoint == -1 then
            return
        end
    end

    local toViaID = AutoDrive:FastShortestPath(AutoDrive.mapWayPoints, bestPoint, markerName, AutoDrive.mapMarker[viaID].id)

    if toViaID == nil or #toViaID < 1 then
        return
    end

    local fromViaID = AutoDrive:FastShortestPath(AutoDrive.mapWayPoints, toViaID[#toViaID].id, AutoDrive.mapMarker[destinationID].name, AutoDrive.mapMarker[destinationID].id)

    for i, wayPoint in pairs(fromViaID) do
        if i > 1 then
            table.insert(toViaID, wayPoint)
        end
    end

    return toViaID
end

function AutoDrive:GetAvailableDestinations()
    AutoDrive.debugPrint(nil, AutoDrive.DC_EXTERNALINTERFACEINFO, "AutoDrive:GetAvailableDestinations()")
    local destinations = {}
    for markerID, marker in pairs(AutoDrive.mapMarker) do
        local point = AutoDrive.mapWayPoints[marker.id]
        destinations[markerID] = {name = marker.name, x = point.x, y = point.y, z = point.z, id = markerID}
    end
    return destinations
end

function AutoDrive:GetClosestPointToLocation(x, z, minDistance)
    AutoDrive.debugPrint(nil, AutoDrive.DC_EXTERNALINTERFACEINFO, "AutoDrive:GetClosestPointToLocation(%s, %s, %s)", x, z, minDistance)
    local closest = -1
    if AutoDrive.mapWayPoints[1] ~= nil then
        local distance = math.huge

        for i in pairs(AutoDrive.mapWayPoints) do
            local dis = AutoDrive.getDistance(AutoDrive.mapWayPoints[i].x, AutoDrive.mapWayPoints[i].z, x, z)
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
    if vehicle ~= nil and vehicle.ad ~= nil and vehicle.ad.isActive == false then
        vehicle.ad.callBackObject = callBackObject
        vehicle.ad.callBackFunction = callBackFunction
        vehicle.ad.callBackArg = callBackArg

        if destinationID >= 0 and AutoDrive.mapMarker[destinationID] ~= nil then
            vehicle.ad.mapMarkerSelected = destinationID
            vehicle.ad.targetSelected = AutoDrive.mapMarker[vehicle.ad.mapMarkerSelected].id
            vehicle.ad.nameOfSelectedTarget = AutoDrive.mapMarker[vehicle.ad.mapMarkerSelected].name

            if unloadDestinationID >= 0 and AutoDrive.mapMarker[unloadDestinationID] ~= nil then
                vehicle.ad.mapMarkerSelected_Unload = unloadDestinationID
                vehicle.ad.targetSelected_Unload = AutoDrive.mapMarker[vehicle.ad.mapMarkerSelected_Unload].id
                vehicle.ad.nameOfSelectedTarget_Unload = AutoDrive.mapMarker[vehicle.ad.mapMarkerSelected_Unload].name
                AutoDrive:startAD(vehicle)
            elseif unloadDestinationID == -3 then --park
                --must be using 'Drive' mode if only one destination is supplied. For now, also set the onRouteToPark variable to true, so AD will shutdown motor and lights on arrival
                vehicle.ad.mode = 1
                AutoDrive:startAD(vehicle)
                vehicle.ad.onRouteToPark = true
            else --unloadDestinationID == -2 refuel
                AutoDrive:startAD(vehicle)
            end
        end
    end
end

function AutoDrive:StartDrivingWithPathFinder(vehicle, destinationID, unloadDestinationID, callBackObject, callBackFunction, callBackArg)
    AutoDrive.debugPrint(vehicle, AutoDrive.DC_EXTERNALINTERFACEINFO, "AutoDrive:StartDrivingWithPathFinder(%s, %s, %s, %s, %s)", destinationID, unloadDestinationID, callBackObject, callBackFunction, callBackArg)
    if vehicle ~= nil and vehicle.ad ~= nil and vehicle.ad.isActive == false then
        if unloadDestinationID < -1 then
            if unloadDestinationID == -3 then --park
                local PreviousStartPosition = vehicle.ad.mapMarkerSelected
                AutoDrive:StartDriving(vehicle, destinationID, unloadDestinationID, callBackObject, callBackFunction, callBackArg)
                vehicle.ad.usePathFinder = true
                local ignoreFruit = false
                AutoDrivePathFinder:startPathPlanningToStartPosition(vehicle, nil, ignoreFruit, PreviousStartPosition)
            elseif unloadDestinationID == -2 then --refuel
                vehicle.ad.storedMapMarkerSelected = vehicle.ad.mapMarkerSelected
                vehicle.ad.storedMode = vehicle.ad.mode

                local refuelDestination = AutoDrive.getClosestRefuelDestination(vehicle)

                if refuelDestination ~= nil then
                    vehicle.ad.mapMarkerSelected = refuelDestination
                    vehicle.ad.targetSelected = AutoDrive.mapMarker[vehicle.ad.mapMarkerSelected].id
                    vehicle.ad.nameOfSelectedTarget = AutoDrive.mapMarker[vehicle.ad.mapMarkerSelected].name
                    vehicle.ad.mode = 1
                    vehicle.ad.onRouteToRefuel = true
                    AutoDrive:StartDriving(vehicle, vehicle.ad.mapMarkerSelected, unloadDestinationID, callBackObject, callBackFunction, callBackArg)
                    vehicle.ad.usePathFinder = true
                    local ignoreFruit = false
                    AutoDrivePathFinder:startPathPlanningToStartPosition(vehicle, nil, ignoreFruit, vehicle.ad.storedMapMarkerSelected)
                end
            end
        else
            AutoDrive:StartDriving(vehicle, destinationID, unloadDestinationID, callBackObject, callBackFunction, callBackArg)
            vehicle.ad.usePathFinder = true
            local ignoreFruit = false
            AutoDrivePathFinder:startPathPlanningToStartPosition(vehicle, nil, ignoreFruit, nil)
        end
    end
end

function AutoDrive:GetParkDestination(vehicle)
    AutoDrive.debugPrint(vehicle, AutoDrive.DC_EXTERNALINTERFACEINFO, "AutoDrive:GetParkDestination()")
    if vehicle ~= nil and vehicle.ad ~= nil and vehicle.ad.parkDestination ~= nil and vehicle.ad.parkDestination >= 1 and AutoDrive.mapMarker[vehicle.ad.parkDestination] ~= nil then
        return vehicle.ad.parkDestination
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
end
