--startX, startZ: World location
--startYRot: rotation in rad
--destinationID: ID of marker to find path to
--options (optional): options.minDistance, options.maxDistance (default 1m, 20m) define boundaries between the first AutoDrive waypoint and the starting location. 
function AutoDrive:GetPath(startX, startZ, startYRot, destinationID, options)
    if startX == nil or startZ == nil or startYRot == nil or destinationID == nil or AutoDrive.mapMarker[destinationID] == nil then
        return;
    end;
    local markerName = AutoDrive.mapMarker[destinationID].name;
    local startPoint = {x=startX, z=startZ};
    local minDistance = 1;
    local maxDistance = 20;
    if options ~= nil and options.minDistance ~= nil then
        minDistance = options.minDistance;
    end;
    if options ~= nil and options.maxDistance ~= nil then
        maxDistance = options.maxDistance;
    end;
    local directionVec = {x = -math.sin(startYRot), z = math.cos(startYRot)};
    local bestPoint = AutoDrive:findMatchingWayPoint(startPoint, directionVec, minDistance, maxDistance);	

	if bestPoint == -1 then
        bestPoint = AutoDrive:GetClosestPointToLocation(startX, startZ, minDistance, maxDistance);
        if bestPoint == -1 then
            return;
        end;
	end;

    return AutoDrive:FastShortestPath(AutoDrive.mapWayPoints,bestPoint,markerName, AutoDrive.mapMarker[destinationID].id);
end;

function AutoDrive:GetPathVia(startX, startZ, startYRot, viaID, destinationID, options)
    if startX == nil or startZ == nil or startYRot == nil or destinationID == nil or AutoDrive.mapMarker[destinationID] == nil or viaID == nil or AutoDrive.mapMarker[viaID] == nil  then
        return;
    end;

    local markerName = AutoDrive.mapMarker[viaID].name;
    local startPoint = {x=startX, z=startZ};
    local minDistance = 1;
    local maxDistance = 20;
    if options ~= nil and options.minDistance ~= nil then
        minDistance = options.minDistance;
    end;
    if options ~= nil and options.maxDistance ~= nil then
        maxDistance = options.maxDistance;
    end;
    local directionVec = {x = -math.sin(startYRot), z = math.cos(startYRot)};
    local bestPoint = AutoDrive:findMatchingWayPoint(startPoint, directionVec, minDistance, maxDistance);	

	if bestPoint == -1 then
        bestPoint = AutoDrive:GetClosestPointToLocation(startX, startZ, minDistance);
        if bestPoint == -1 then
            return;
        end;
	end;

    local toViaID = AutoDrive:FastShortestPath(AutoDrive.mapWayPoints,bestPoint,markerName, AutoDrive.mapMarker[viaID].id);

    if toViaID == nil or ADTableLength(toViaID) < 1 then
        return;
    end;

    local fromViaID = AutoDrive:FastShortestPath(AutoDrive.mapWayPoints, toViaID[ADTableLength(toViaID)].id, AutoDrive.mapMarker[destinationID].name, AutoDrive.mapMarker[destinationID].id);

    for i, wayPoint in pairs(fromViaID) do
        if i > 1 then
            table.insert(toViaID, wayPoint);
        end;
    end;

    return toViaID;
end;

function AutoDrive:GetAvailableDestinations()
    local destinations = {};
    for markerID, marker in pairs(AutoDrive.mapMarker) do
        local point = AutoDrive.mapWayPoints[marker.id];
        destinations[markerID] = {name=marker.name, x=point.x, y=point.y, z=point.z, id=markerID};
    end;
    return destinations;
end;

function AutoDrive:GetClosestPointToLocation(x, z, minDistance)
    local closest = -1;
    if AutoDrive.mapWayPoints[1] ~= nil then

        local distance = math.huge;
        
        for i in pairs(AutoDrive.mapWayPoints) do
            local dis = AutoDrive:getDistance(AutoDrive.mapWayPoints[i].x,AutoDrive.mapWayPoints[i].z,x,z);
            if dis < distance and dis >= minDistance then
                closest = i;
                distance = dis;
            end;
        end;
    end;

    return closest;
end;

function AutoDrive:StartDriving(vehicle, destinationID, unloadDestinationID, callBackObject, callBackFunction, callBackArg)
    if vehicle ~= nil and vehicle.ad ~= nil and vehicle.ad.isActive == false then
        vehicle.ad.callBackObject = callBackObject;
        vehicle.ad.callBackFunction = callBackFunction;
        vehicle.ad.callBackArg = callBackArg;

        if destinationID >= 0 and AutoDrive.mapMarker[destinationID] ~= nil then 
            vehicle.ad.mapMarkerSelected = destinationID;
            vehicle.ad.targetSelected = AutoDrive.mapMarker[vehicle.ad.mapMarkerSelected].id;
            vehicle.ad.nameOfSelectedTarget = AutoDrive.mapMarker[vehicle.ad.mapMarkerSelected].name;       

            if unloadDestinationID >= 0 and AutoDrive.mapMarker[unloadDestinationID] ~= nil then
                vehicle.ad.mapMarkerSelected_Unload = unloadDestinationID;
                vehicle.ad.targetSelected_Unload = AutoDrive.mapMarker[vehicle.ad.mapMarkerSelected_Unload].id;
                vehicle.ad.nameOfSelectedTarget_Unload = AutoDrive.mapMarker[vehicle.ad.mapMarkerSelected_Unload].name;       
            end;

            AutoDrive:startAD(vehicle);
        end;    
    end;
end;

function AutoDrive:StartDrivingWithPathFinder(vehicle, destinationID, unloadDestinationID, callBackObject, callBackFunction, callBackArg)
    if vehicle ~= nil and vehicle.ad ~= nil and vehicle.ad.isActive == false then
        AutoDrive:StartDriving(vehicle, destinationID, unloadDestinationID, callBackObject, callBackFunction, callBackArg);
        vehicle.ad.usePathFinder = true;    
        local ignoreFruit = false;
        AutoDrivePathFinder:startPathPlanningToStartPosition(vehicle, nil, ignoreFruit);   
    end;

end;

--These are just here for example purposes on how to use the interface to start an AD driver and receive a callback when it's finished

addConsoleCommand('adGetPath', 'Start current course and callback', 'adGetPath', AutoDrive);

function AutoDrive:adGetPath()
    local veh = g_currentMission.controlledVehicle;
    local x1,y1,z1 = getWorldTranslation(veh.components[1].node);
    local _, yRot, _ = getWorldRotation(veh.components[1].node)

    veh.ad.testVar = AutoDrive:GetPathVia(x1, z1, yRot, g_currentMission.controlledVehicle.ad.mapMarkerSelected, g_currentMission.controlledVehicle.ad.mapMarkerSelected_Unload);
    --DebugUtil.printTableRecursively(veh.ad.testVar, "::::", 0, 1);
end;

function AutoDrive:isFinished(vehicle)
    --print("AutoDrive has finished it's route");

    --here we enter an endless loop and restart the course when finished
    if vehicle.ad.mode == AutoDrive.MODE_PICKUPANDDELIVER or vehicle.ad.mode == AutoDrive.MODE_LOAD then
        AutoDrive:StartDriving(vehicle, vehicle.ad.mapMarkerSelected, vehicle.ad.mapMarkerSelected_Unload, AutoDrive, AutoDrive.isFinished, vehicle);
    end;
end;
