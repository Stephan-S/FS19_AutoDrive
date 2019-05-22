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
        local point = AutoDrive.mapWayPoints[markerID];
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