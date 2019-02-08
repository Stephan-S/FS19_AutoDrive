function AutoDrive:startAD(vehicle)
    vehicle.ad.isActive = true;
    vehicle.ad.creationMode = false;
    
    vehicle.forceIsActive = true;
    vehicle.stopMotorOnLeave = false;
    vehicle.disableCharacterOnLeave = true;
    vehicle.currentHelper = g_helperManager:getRandomHelper()
    vehicle.spec_aiVehicle.isActive = true
    
    vehicle.ad.unloadType = AutoDrive:getCurrentFillType(vehicle);

    vehicle.nPrintTime = 3000;
end;

function AutoDrive:stopAD(vehicle)    
    vehicle.ad.currentWayPoint = 0;
    vehicle.ad.drivingForward = true;
    vehicle.ad.isActive = false;
    
    vehicle.spec_aiVehicle.isActive = false;
    
    vehicle.ad.stopAD = true;
    vehicle.ad.isUnloading = false;
    vehicle.ad.isLoading = false;

    vehicle.ad.isActive = false; 
	vehicle.forceIsActive = false;
	vehicle.stopMotorOnLeave = true;
	vehicle.disableCharacterOnLeave = true;
					
	vehicle.ad.initialized = false;
	vehicle.ad.lastSpeed = 10;
	if vehicle.steeringEnabled == false then
		vehicle.steeringEnabled = true;
	end

    vehicle:setCruiseControlState(Drivable.CRUISECONTROL_STATE_OFF);
end;

function AutoDrive:isActive(vehicle)
    if vehicle ~= nil then
        return vehicle.ad.isActive;
    end;
    return false;
end;