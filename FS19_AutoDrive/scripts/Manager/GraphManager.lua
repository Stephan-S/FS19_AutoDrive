ADGraphManager = {}

function ADGraphManager:new()
    local o = {}
    setmetatable(o, self)
    self.__index = self
    return o
end

function ADGraphManager:getPathTo(vehicle, waypointID)
    local wp = {}
    local closestWaypoint = AutoDrive:findMatchingWayPointForVehicle(vehicle)
    if closestWaypoint ~= nil then
        wp = self:pathFromTo(closestWaypoint, waypointID)
    end
        
    return wp
end

function ADGraphManager:pathFromTo(startWaypointID, targetWaypointID)
    local wp = {}
    if startWaypointID ~= nil and AutoDrive.mapWayPoints[startWaypointID] ~= nil and targetWaypointID ~= nil and AutoDrive.mapWayPoints[targetWaypointID] ~= nil then
        if startWaypointID == targetWaypointID then
            table.insert(wp, 1, AutoDrive.mapWayPoints[targetWaypointID])
            return wp
        else
            wp = AutoDrive:dijkstraLiveShortestPath(AutoDrive.mapWayPoints, startWaypointID, targetWaypointID)
        end        
    end
    return wp
end

function ADGraphManager:pathFromToMarker(startWaypointID, markerID)
    local wp = {}
    if startWaypointID ~= nil and AutoDrive.mapWayPoints[startWaypointID] ~= nil and AutoDrive.mapMarker[markerID] ~= nil and AutoDrive.mapMarker[markerID].id ~= nil then
        local targetID = AutoDrive.mapMarker[markerID].id
        if targetID == startWaypointID then
            table.insert(wp, 1, AutoDrive.mapWayPoints[targetID])
            return wp
        else
            wp = AutoDrive:dijkstraLiveShortestPath(AutoDrive.mapWayPoints, startWaypointID, targetID)
        end        
    end
    return wp
end

function ADGraphManager:FastShortestPath(Graph, start, markerName, markerID)
	local wp = {}
	local start_id = start
	local target_id = 0

	if start_id == nil or start_id == 0 then
		return wp
	end

	for i in pairs(AutoDrive.mapMarker) do
		if AutoDrive.mapMarker[i].name == markerName then
			target_id = AutoDrive.mapMarker[i].id
			break
		end
	end

	if target_id == 0 then
		return wp
	end

	if target_id == start_id then
		table.insert(wp, 1, Graph[target_id])
		return wp
	end

	wp = AutoDrive:dijkstraLiveShortestPath(Graph, start_id, target_id)

	return wp
end