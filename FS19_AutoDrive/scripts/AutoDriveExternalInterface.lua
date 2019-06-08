--startX, startZ: World location
--startYRot: rotation in rad
--destinationID: ID of marker to find path to
--options (optional): options.minDistance, options.maxDistance (default 1m, 20m) define boundaries between the first AutoDrive waypoint and the starting location. 
function AutoDrive:GetPath(startX, startZ, startYRot, destinationID, options)
    if startX == nil or startZ == nil or startYRot == nil or destinationID == nil or AutoDrive.mapMarker[markerID] == nil then
        return;
    end;
    local markerName = AutoDrive.mapMarker[markerID].name;
    local startPoint = {x=startX, z=startZ};
    local minDistance = 1;
    local maxDistance = 20;
    if options ~= nil and options.minDistance ~= nil then
        minDistance = options.minDistance;
    end;
    if options ~= nil and options.maxDistance ~= nil then
        maxDistance = options.maxDistance;
    end;
    
    local bestPoint = AutoDrive:findMatchingWayPoint(startPoint, startYRot, minDistance, maxDistance);	

	if bestPoint == -1 then
        bestPoint = AutoDrive:GetClosestPointToLocation(x, z, minDistance, maxDistance);
        if bestPoint == -1 then
            return;
        end;
	end;

    return AutoDrive:FastShortestPath(AutoDrive.mapWayPoints,bestPoint,markerName, destinationID);
end;

function AutoDrive:GetAvailableDestinations()
    local destinations = {};
    for markerID, marker in AutoDrive.mapMarker do
        local point = AutoDrive.mapWayPoints[marker.id];
        destinations[markerID] = {name=marker.name, x=point.x, y=point.y, z=point.z, id=markerID};
    end;
    return destinations;
end;

function AutoDrive:GetClosestPointToLocation(x, z, minDistance, maxDistance)
    local closest = -1;
    if AutoDrive.mapWayPoints[1] ~= nil then

        local distance = math.huge;
        
        for i in pairs(AutoDrive.mapWayPoints) do
            local dis = AutoDrive:getDistance(AutoDrive.mapWayPoints[i].x,AutoDrive.mapWayPoints[i].z,x,z);
            if dis < distance and dis >= minDistance and dis <= maxDistance then
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

--These are just here for example purposes on how to use the interface to start an AD driver and receive a callback when it's finished

addConsoleCommand('adStartDriving', 'Start current course and callback', 'adStartDriving', AutoDrive);

function AutoDrive:adStartDriving()
    --print("AutoDrive:adStartDriving called")
    AutoDrive:StartDriving(g_currentMission.controlledVehicle, g_currentMission.controlledVehicle.ad.mapMarkerSelected, g_currentMission.controlledVehicle.ad.mapMarkerSelected_Unload, AutoDrive, AutoDrive.isFinished, g_currentMission.controlledVehicle);
end;

function AutoDrive:isFinished(vehicle)
    --print("AutoDrive has finished it's route");

    --here we enter an endless loop and restart the course when finished
    if vehicle.ad.mode == AutoDrive.MODE_PICKUPANDDELIVER then
        AutoDrive:StartDriving(vehicle, vehicle.ad.mapMarkerSelected, vehicle.ad.mapMarkerSelected_Unload, AutoDrive, AutoDrive.isFinished, vehicle);
    end;
end;