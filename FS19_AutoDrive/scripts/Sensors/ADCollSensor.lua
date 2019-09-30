ADCollSensor = ADInheritsFrom( ADSensor )



function ADCollSensor:new(vehicle, sensorParameters)
    local self = ADCollSensor:create();
    self:init(vehicle, ADSensor.TYPE_COLLISION, sensorParameters);
    self.hit = false;
    self.newHit = false;
    self.collisionHits = 0;
    self.timeOut = AutoDriveTON:new();
	
    return self;
end;

function ADCollSensor:onUpdate(dt)  
    local box = self:getBoxShape();
    if self.collisionHits == 0 or self.timeOut:timer(true, 20000, dt) then
        self.timeOut:timer(false);
        self.hit = self.newHit;
        self:setTriggered(self.hit)
        self.newHit = false;

        self.collisionHits = overlapBox(box.x,box.y,box.z, box.rx, box.ry, 0, box.size[1],box.size[2],box.size[3], "collisionTestCallback", self, 16783599 , true, true, true) --AIVehicleUtil.COLLISION_MASK
        
        --for some reason, I have to call this again if collisionHits > 0 to trigger the callback functions, which check if the hit object is me or is attached to me
        if self.collisionHits > 0 then
            overlapBox(box.x,box.y,box.z, box.rx, box.ry, 0, box.size[1],box.size[2],box.size[3], "collisionTestCallback", self, 16783599 , true, true, true)
        end;
    end;
  
    self:onDrawDebug(box);
end;

function ADCollSensor:collisionTestCallback(transformId)
    self.collisionHits = math.max(0, self.collisionHits - 1);
    if g_currentMission.nodeToObject[transformId] ~= nil or g_currentMission.players[transformId] ~= nil or g_currentMission:getNodeObject(transformId) ~= nil then
        if g_currentMission.nodeToObject[transformId] ~= self and g_currentMission.nodeToObject[transformId] ~= self.vehicle and not AutoDrive:checkIsConnected(self.vehicle, g_currentMission.nodeToObject[transformId]) then
            if self.vehicle.ad.currentDriver == nil or ( g_currentMission.nodeToObject[transformId] ~= self.vehicle.ad.currentDriver and (not AutoDrive:checkIsConnected(self.vehicle.ad.currentDriver, g_currentMission.nodeToObject[transformId]))) then
                self.newHit = true;     
            end;
        end
    end
end
