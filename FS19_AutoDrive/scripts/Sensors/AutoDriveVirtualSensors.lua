ADSensor = {};
ADSensor_mt = { __index = ADSensor }

ADSensor.TYPE_COLLISION = 1;
ADSensor.TYPE_FRUIT = 2;
ADSensor.TYPE_TRIGGER = 3;
ADSensor.TYPE_FIELDBORDER = 4;

ADSensor.POS_FRONT = 1;
ADSensor.POS_REAR = 2;
ADSensor.POS_LEFT = 3;
ADSensor.POS_RIGHT = 4;
ADSensor.POS_FRONT_LEFT = 5;
ADSensor.POS_FRONT_RIGHT = 6;
ADSensor.POS_REAR_LEFT = 7;
ADSensor.POS_REAR_RIGHT = 8;
ADSensor.POS_FIXED = 9;

ADSensor.WIDTH_FACTOR = 0.7;

--
--          <x>   
--       ^  o-o
--       z  |||
--       v  O-O
--

function ADSensor:init(vehicle, sensorType, sensorParameters)
    --o = {}
    --setmetatable(o, self)
    --self.__index = self
    self.vehicle = vehicle;
    self.sensorType = sensorType;
    self.sensorParameters = sensorParameters;
    self.enabled = true;
    self.triggered = false;
    self.initialized = false;
    self.drawDebug = true;
    
    self:loadBaseParameters();
    self:loadDynamicParameters(sensorParameters);
end;

function ADSensor:loadBaseParameters()
    local vehicle = self.vehicle;
    if vehicle ~= nil and vehicle.sizeLength ~= nil and vehicle.sizeWidth ~= nil then
        self.dynamicLength = true;
        self.dynamicRotation = true;
        self.length = vehicle.sizeLength;
        self.width = vehicle.sizeWidth * ADSensor.WIDTH_FACTOR;
        self.collisionMask = AIVehicleUtil.COLLISION_MASK;
        self.position = ADSensor.POS_FRONT;
        self.location = self:getLocationByPosition();
        self.initialized = true;
        self.frontFactor = 1;
        self.sideFactor = 1;
    end;
end;

function ADSensor:loadDynamicParameters(sensorParameters)
    if sensorParameters == nil then
        return;
    end;

    if sensorParameters.dynamicLength ~= nil then
        self.dynamicLength = sensorParameters.dynamicLength == true;
    end;
    if sensorParameters.dynamicRotation ~= nil then
        self.dynamicRotation = sensorParameters.dynamicRotation == true;
    end;
    if sensorParameters.length ~= nil then
        self.length = sensorParameters.length;
    end;
    if sensorParameters.width ~= nil then
        self.width = sensorParameters.width;
    end;
    if sensorParameters.collisionMask ~= nil then
        self.collisionMask = sensorParameters.collisionMask;
    end;
    if sensorParameters.position ~= nil then
        if sensorParameters.position >= ADSensor.POS_FRONT and sensorParameters.position <= ADSensor.POS_FIXED then
            self.position = sensorParameters.position;
        end;
    end;
    if sensorParameters.location ~= nil then
        if self.position == ADSensor.POS_FIXED then
            self.location = sensorParameters.location;
        end;
    end;    
    self.location = self:getLocationByPosition();
end;

function ADSensor:getLocationByPosition()
    local vehicle = self.vehicle;
    local location = {x=0, z=0};

    if self.position == ADSensor.POS_FRONT then
        location.z = vehicle.sizeLength/2 + 1;
    elseif self.position == ADSensor.POS_REAR then
        location.z = -vehicle.sizeLength/2 - 1;
        self.frontFactor = -1;
    elseif self.position == ADSensor.POS_RIGHT then
        location.x = -vehicle.sizeWidth/2 - 1 - self.width/2; 
        location.z = -vehicle.sizeLength/2;
        self.sideFactor = -1;
    elseif self.position == ADSensor.POS_LEFT then
        location.x = vehicle.sizeWidth/2 + 1 + self.width/2; 
        location.z = -vehicle.sizeLength/2;
    elseif self.position == ADSensor.POS_FIXED and self.location ~= nil then
        return self.location; 
    end;

    return location;
end;

function ADSensor:getBoxShape()
    local vehicle = self.vehicle;
    local lookAheadDistance = self.length;
    if self.dynamicLength then
        lookAheadDistance =  math.min(vehicle.lastSpeedReal*3600/40, 1) * 7; --full distance at 40 kp/h -> 7 meters
    end;

    local vecZ = {x=0, z=1};
    if self.dynamicRotation then
        vecZ.x, vecZ.z = math.sin(vehicle.rotatedTime), math.cos(vehicle.rotatedTime);
    end;	    
    local vecX = {x=vecZ.z, z=-vecZ.x};
    if self.sideFactor == -1 then
        vecX = {x=-vecX.x, z=-vecX.z};
    end;
    if self.frontFactor == -1 then
        vecZ = {x=vecZ.x, z=-vecZ.z};
    end;

    local box = {};
    box.center = {};
    box.offset = {};
    box.size = {};
    box.size[1] = self.width * 0.5-- * self.sideFactor;
    box.size[2] = 0.75;                 -- fixed height for now
    box.size[3] = lookAheadDistance * 0.5-- * self.frontFactor;
    box.offset[1] = self.location.x;
    box.offset[2] = 2.2;                -- fixed y pos for now
    box.offset[3] = self.location.z;
    box.center[1] = box.offset[1]  + vecZ.x * box.size[3]; --+ (vecX.x * box.size[1])
    box.center[2] = 2.2;                -- fixed y pos for now
    box.center[3] = box.offset[3] + vecZ.z * box.size[3]; -- + vecX.z * box.size[1]
    box.dirX, box.dirY, box.dirZ = localDirectionToWorld(vehicle.components[1].node, 0,0,1)
    box.zx, box.zy, box.zz = localDirectionToWorld(vehicle.components[1].node, vecZ.x, 0, vecZ.z)
    box.ry = math.atan2(box.zx, box.zz)
    box.rx = -MathUtil.getYRotationFromDirection(box.dirY, 1) * self.frontFactor;
    box.x, box.y, box.z = localToWorld(vehicle.components[1].node, box.center[1], box.center[2], box.center[3]);

    box.vector = { x=vecZ.x*box.size[3] + vecX.x*box.size[1], z=vecZ.z*box.size[3] + vecX.z*box.size[1] };

    return box;
end;

function ADSensor:getCorners(box)
    local box = box;
    if box == nil then
        box = self:getBoxShape();
    end;

    local corners = {};
    corners[1] = { x=box.x + box.vector.x, z=box.z + box.vector.z } --"cornerRightUp"
    corners[2] = { x=box.x + box.vector.x, z=box.z - box.vector.z } --"cornerRightDown"
    corners[3] = { x=box.x - box.vector.x, z=box.z - box.vector.z } --"cornerLeftDown"
    corners[4] = { x=box.x - box.vector.x, z=box.z + box.vector.z } --"cornerLeftUp"

    return corners;
end;

function ADSensor:updateSensor(dt)
    --print("updateSensor called")
    if self:isEnabled() then
        self:onUpdate(dt);
    else
        self:setTriggered(false)        
    end;
end;

function ADSensor:onUpdate()
    print("ADSensor:onUpdate() called - Please override this in instance class");
end;

function ADSensor:onDrawDebug(box)
    if self.drawDebug then
        local red = 0;
        if self:isTriggered() then
            red = 1;
        end;

        DebugUtil.drawOverlapBox(box.x,box.y,box.z, box.rx, box.ry, 0, box.size[1],box.size[2],box.size[3], red, 0, 0);   
    end;
end;

function ADSensor:setEnabled(enabled)
    if enabled ~= nil and enabled == true then
        self.enabled = true;
    else
        self.enabled = false;
    end;
end;

function ADSensor:isEnabled()
    return self.enabled and self.initialized;
end;

function ADSensor:setTriggered(triggered)
    if triggered ~= nil and triggered == true then
        self.triggered = true;
    else
        self.triggered = false;
    end;
end;

function ADSensor:isTriggered()
    return self.triggered;
end;