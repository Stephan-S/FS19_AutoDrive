function AutoDrive:startAD(vehicle)
    vehicle.ad.isActive = true;
    vehicle.ad.creationMode = false;
    
    --vehicle.forceIsActive = true;
    vehicle.spec_motorized.stopMotorOnLeave = false;
    vehicle.spec_enterable.disableCharacterOnLeave = false;
    vehicle.currentHelper = g_helperManager:getRandomHelper()
    vehicle.spec_aiVehicle.isActive = true
    
    vehicle.ad.unloadType = AutoDrive:getCurrentFillType(vehicle);

    if vehicle.setRandomVehicleCharacter ~= nil then
        vehicle:setRandomVehicleCharacter()
    end
    
    if vehicle.steeringEnabled == true then
        vehicle.steeringEnabled = false;
    end

    vehicle.nPrintTime = 3000;
end;

function AutoDrive:stopAD(vehicle)
    vehicle.ad.isStopping = true;
end;

function AutoDrive:stopVehicle(vehicle, dt)
    if math.abs(vehicle.lastSpeedReal) < 0.001 then
        vehicle.ad.isStopping = false;
    end;
    
    if vehicle.ad.isStopping then
        AutoDrive:getVehicleToStop(vehicle, dt);
    else       
        vehicle.ad.currentWayPoint = 0;
        vehicle.ad.drivingForward = true;
        vehicle.ad.isActive = false;
        
        vehicle.spec_aiVehicle.isActive = false;
        vehicle.ad.isUnloading = false;
        vehicle.ad.isLoading = false;

        vehicle.ad.isActive = false; 
        vehicle.forceIsActive = false;
        vehicle.spec_motorized.stopMotorOnLeave = true;
        vehicle.spec_enterable.disableCharacterOnLeave = true;
        vehicle.currentHelper = nil
                        
        vehicle.ad.initialized = false;
        vehicle.ad.lastSpeed = 10;
        if vehicle.steeringEnabled == false then
            vehicle.steeringEnabled = true;
        end

        vehicle:setCruiseControlState(Drivable.CRUISECONTROL_STATE_OFF);
    end;
end;

function AutoDrive:getVehicleToStop(vehicle, dt)
    local finalSpeed = 0;
    local allowedToDrive = false;
    local node = vehicle.components[1].node;					
    if vehicle.getAIVehicleDirectionNode ~= nil then
        node = vehicle:getAIVehicleDirectionNode();
    end;
    local x,y,z = getWorldTranslation(vehicle.components[1].node);   
    local lx, lz = AIVehicleUtil.getDriveDirection(node, x, y, z);
    AIVehicleUtil.driveInDirection(vehicle, dt, 30, 1, 0.2, 20, allowedToDrive, vehicle.ad.drivingForward, lx, lz, finalSpeed, 1);
end;

function AutoDrive:isActive(vehicle)
    if vehicle ~= nil then
        return vehicle.ad.isActive;
    end;
    return false;
end;