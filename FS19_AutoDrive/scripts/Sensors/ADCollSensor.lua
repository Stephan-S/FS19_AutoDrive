ADCollSensor = ADInheritsFrom( ADSensor )

ADCollSensor.collisionMask = 28317935;
ADCollSensor.mask_Non_Pushable_1            = 1;
ADCollSensor.mask_Non_Pushable_2            = 2;
ADCollSensor.mask_static_world_1            = 3;
ADCollSensor.mask_static_world_2            = 4;
ADCollSensor.mask_tractors                  = 6;
ADCollSensor.mask_combines                  = 7;
ADCollSensor.mask_trailers                  = 8;
ADCollSensor.mask_dynamic_objects           = 12;
ADCollSensor.mask_dynamic_objects_machines  = 13;
ADCollSensor.mask_trigger_player            = 20;
ADCollSensor.mask_trigger_tractor           = 21;
ADCollSensor.mask_trigger_combines          = 22;
ADCollSensor.mask_trigger_fillables         = 23;
ADCollSensor.mask_trigger_dynamic_objects   = 24;
ADCollSensor.mask_trigger_trafficVehicles   = 25;
ADCollSensor.mask_trigger_cutters           = 26;
ADCollSensor.mask_kinematic_objects_wo_coll = 30;

function ADCollSensor:new(vehicle, sensorParameters)
    local self = ADCollSensor:create();
    self:init(vehicle, ADSensor.TYPE_COLLISION, sensorParameters);
    self.hit = false;
    self.newHit = false;
    self.collisionHits = 0;
    self.timeOut = AutoDriveTON:new();

    self.mask = ADCollSensor:buildMask();

    return self;
end;

function ADCollSensor:buildMask() 
    local mask = 0;
    
    mask = mask + math.pow(2, ADCollSensor.mask_Non_Pushable_1 - 1);
    mask = mask + math.pow(2, ADCollSensor.mask_Non_Pushable_2 - 1);
    mask = mask + math.pow(2, ADCollSensor.mask_static_world_1 - 1);
    mask = mask + math.pow(2, ADCollSensor.mask_static_world_2 - 1);
    mask = mask + math.pow(2, ADCollSensor.mask_tractors - 1);
    mask = mask + math.pow(2, ADCollSensor.mask_combines - 1);
    mask = mask + math.pow(2, ADCollSensor.mask_trailers - 1);
    mask = mask + math.pow(2, ADCollSensor.mask_dynamic_objects - 1);
    mask = mask + math.pow(2, ADCollSensor.mask_dynamic_objects_machines - 1);
    mask = mask + math.pow(2, ADCollSensor.mask_trigger_trafficVehicles - 1);
    mask = mask + math.pow(2, ADCollSensor.mask_trigger_dynamic_objects - 1);

    return mask;
end;

function ADCollSensor:onUpdate(dt)  
    local box = self:getBoxShape();
    if self.collisionHits == 0 or self.timeOut:timer(true, 20000, dt) then
        self.timeOut:timer(false);
        self.hit = self.newHit;
        self:setTriggered(self.hit)
        self.newHit = false;

        self.collisionHits = overlapBox(box.x,box.y,box.z, box.rx, box.ry, 0, box.size[1],box.size[2],box.size[3], "collisionTestCallback", self, self.mask , true, true, true) --AIVehicleUtil.COLLISION_MASK --16783599
        
        --for some reason, I have to call this again if collisionHits > 0 to trigger the callback functions, which check if the hit object is me or is attached to me
        if self.collisionHits > 0 then
            overlapBox(box.x,box.y,box.z, box.rx, box.ry, 0, box.size[1],box.size[2],box.size[3], "collisionTestCallback", self, self.mask , true, true, true)
        end;
    end;
  
    self:onDrawDebug(box);
end;

function ADCollSensor:collisionTestCallback(transformId)
    self.collisionHits = math.max(0, self.collisionHits - 1);
    if g_currentMission.nodeToObject[transformId] ~= nil then -- or g_currentMission.players[transformId] ~= nil or g_currentMission:getNodeObject(transformId) ~= nil
        if g_currentMission.nodeToObject[transformId] ~= self and g_currentMission.nodeToObject[transformId] ~= self.vehicle and not AutoDrive:checkIsConnected(self.vehicle, g_currentMission.nodeToObject[transformId]) then
            if self.vehicle.ad.currentDriver == nil or ( g_currentMission.nodeToObject[transformId] ~= self.vehicle.ad.currentDriver and (not AutoDrive:checkIsConnected(self.vehicle.ad.currentDriver, g_currentMission.nodeToObject[transformId]))) then
                self.newHit = true;     
            end;
        end
    else
        self.newHit = true;
    end
end
