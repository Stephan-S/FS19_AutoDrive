ADFieldSensor = ADInheritsFrom(ADSensor)

function ADFieldSensor:new(vehicle, sensorParameters)
    local self = ADFieldSensor:create()
    self:init(vehicle, ADSensor.TYPE_FIELDBORDER, sensorParameters)

    return self
end

function ADFieldSensor:onUpdate(dt)   
    local box = self:getBoxShape()
    local corners = self:getCorners(box)

    local onField = true;
    for _, corner in pairs(corners) do
        local y = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, corner.x, 1, corner.z);
        onField = onField and (getDensityAtWorldPos(g_currentMission.terrainDetailId, corner.x, y, corner.z) ~= 0)
    end;

    self:setTriggered(onField)
    
    self:onDrawDebug(box)
end