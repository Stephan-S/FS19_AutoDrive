-- positive X -> left
-- negative X -> right
function AutoDrive.createWayPointRelativeToVehicle(vehicle, offsetX, offsetZ)
    local wayPoint = {}
    wayPoint.x, wayPoint.y, wayPoint.z = localToWorld(vehicle.components[1].node, offsetX, offsetZ)
    return wayPoint
end

function AutoDrive.isTrailerInCrop(vehicle)
    local trailers, trailerCount = AutoDrive.getTrailersOf(vehicle)
    local trailer = trailers[#trailerCount]
    local inCrop = false
    if trailer ~= nil then
        if trailer.ad == nil then
            trailer.ad = {}
        end
        ADSensor:handleSensors(trailer, dt)
        inCrop = trailer.ad.sensors.centerSensorFruit:pollInfo()
    end
    return inCrop
end

function AutoDrive.isVehicleOrTrailerInCrop(vehicle)
    return AutoDrive.isTrailerInCrop(vehicle) or vehicle.ad.sensors.centerSensorFruit:pollInfo()
end