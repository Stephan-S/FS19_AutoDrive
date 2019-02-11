function AutoDrive:handleDriving(vehicle, dt)
    AutoDrive:checkActiveAttributesSet(vehicle);
    AutoDrive:checkForDeadLock(vehicle, dt);   
	AutoDrive:handlePrintMessage(vehicle, dt);
	AutoDrive:handleTrailers(vehicle, dt)
	AutoDrive:handleDeadlock(vehicle, dt)	
	
	if vehicle.ad.isStopping == true then
		AutoDrive:stopVehicle(vehicle, dt)
		return;
	end;
	
	if vehicle.components ~= nil and vehicle.isServer then	
		local x,y,z = getWorldTranslation( vehicle.components[1].node );
		local xl,yl,zl = worldToLocal(vehicle.components[1].node, x,y,z);
			
		if vehicle.ad.isActive == true and vehicle.ad.isPaused == false then
			if vehicle.ad.initialized == false then
				AutoDrive:initializeAD(vehicle)
            else
                local min_distance  = AutoDrive:defineMinDistanceByVehicleType(vehicle);				

				if getDistance(x,z, vehicle.ad.targetX, vehicle.ad.targetZ) < min_distance then
					AutoDrive:handleReachedWayPoint(vehicle);
				end;
			end;

			if vehicle.ad.isActive == true and vehicle.isServer then
                if vehicle.ad.wayPoints[vehicle.ad.currentWayPoint+1] ~= nil then
                    AutoDrive:driveToNextWayPoint(vehicle, dt);                    
                else
                    AutoDrive:driveToLastWaypoint(vehicle, dt);                    
                end;				
			end;
		end;

		if vehicle.ad.isPaused == true then
			AutoDrive:getVehicleToStop(vehicle, dt);
			vehicle.ad.timeTillDeadLock = 15000;
			if vehicle.ad.pauseTimer > 0 then
				if vehicle.isServer == true then
					xl,yl,zl = worldToLocal(vehicle.components[1].node, vehicle.ad.targetX,y,vehicle.ad.targetZ);
					--AIVehicleUtil.driveToPoint(vehicle, dt, 0, false, vehicle.ad.drivingForward, xl, zl, 0, false );
					--vehicle:setCruiseControlState(Drivable.CRUISECONTROL_STATE_OFF);
				end;
				vehicle.ad.pauseTimer = vehicle.ad.pauseTimer - dt;
			end;
		else
			if vehicle.ad.pauseTimer < 5000 then
				vehicle.ad.pauseTimer = 5000;
			end;
		end;
	end;
end;

function AutoDrive:checkActiveAttributesSet(vehicle)
    if vehicle.ad.isActive == true and vehicle.isServer then
        --vehicle.forceIsActive = true;
        vehicle.spec_motorized.stopMotorOnLeave = false;
        vehicle.spec_enterable.disableCharacterOnLeave = false;
        vehicle.spec_aiVehicle.isActive = true
        
        if vehicle.steeringEnabled == true then
            vehicle.steeringEnabled = false;
        end
	end;
	
	if vehicle.startMotor and vehicle.stopMotor then
		if vehicle.ad.isActive then
			vehicle:startMotor();
		end;
	end;

	if vehicle.ad.isActive == true and vehicle.ad.isPaused == false then
		if vehicle.steeringEnabled then
			vehicle.steeringEnabled = false;
		end;
	end;
end;

function AutoDrive:checkForDeadLock(vehicle, dt)
    if vehicle.ad.isActive == true and vehicle.isServer then		
        vehicle.ad.timeTillDeadLock = vehicle.ad.timeTillDeadLock - dt;
		if vehicle.ad.timeTillDeadLock < 0 and vehicle.ad.timeTillDeadLock ~= -1 then
			print("Deadlock reached due to timer");
			vehicle.ad.inDeadLock = true;
		end;		
	else
		vehicle.ad.inDeadLock = false;
		vehicle.ad.timeTillDeadLock = 15000;
		vehicle.ad.inDeadLockRepairCounter = 4;
	end;
end;

function AutoDrive:handlePrintMessage(vehicle, dt)
    if vehicle.printMessage ~= nil then
        vehicle.nPrintTime = vehicle.nPrintTime - dt;
		if vehicle.nPrintTime < 0 then
            vehicle.nPrintTime = 3000;
            vehicle.printMessage = nil;
		end;
    end;
    
    if vehicle == g_currentMission.controlledVehicle then
		if AutoDrive.printMessage ~= nil then
			AutoDrive.nPrintTime = AutoDrive.nPrintTime - dt;
			if AutoDrive.nPrintTime < 0 then
				AutoDrive.nPrintTime = 3000;
				AutoDrive.printMessage = nil;
			end;
		end;

		if vehicle.ad.sToolTip ~= "" then
			if vehicle.ad.nToolTipWait <= 0 then
				if vehicle.ad.nToolTipTimer > 0 then
                    vehicle.ad.nToolTipTimer = vehicle.ad.nToolTipTimer - dt;
				else
					vehicle.ad.sToolTip = "";
				end;
			else
				vehicle.ad.nToolTipWait = vehicle.ad.nToolTipWait - dt;
			end;
		end;		
	end;
end;

function AutoDrive:initializeAD(vehicle)
    vehicle.ad.timeTillDeadLock = 15000;
    if vehicle.ad.targetMode == true then
        local closest = AutoDrive:findMatchingWayPoint(vehicle);
        vehicle.ad.wayPoints = AutoDrive:FastShortestPath(AutoDrive.mapWayPoints, closest, AutoDrive.mapMarker[vehicle.ad.mapMarkerSelected].name, vehicle.ad.targetSelected);
		
		if vehicle.ad.wayPoints[2] == nil and vehicle.ad.wayPoints[1].id ~= vehicle.ad.targetSelected then			
			AutoDrive.printMessage = g_i18n:getText("AD_Driver_of") .. " " .. vehicle.name .. " " .. g_i18n:getText("AD_cannot_reach") .. " " .. vehicle.ad.nameOfSelectedTarget;
            AutoDrive.nPrintTime = 6000;                    
			AutoDrive:stopAD(vehicle);
		end;
        
        if vehicle.ad.wayPoints[2] ~= nil then
            vehicle.ad.currentWayPoint = 2;
        else
            vehicle.ad.currentWayPoint = 1;
        end;
    else
        vehicle.ad.currentWayPoint = 1;
    end;
	
	if vehicle.ad.wayPoints[vehicle.ad.currentWayPoint] ~= nil then
        vehicle.ad.targetX = vehicle.ad.wayPoints[vehicle.ad.currentWayPoint].x;
        vehicle.ad.targetZ = vehicle.ad.wayPoints[vehicle.ad.currentWayPoint].z;
        vehicle.ad.initialized = true;
        vehicle.ad.drivingForward = true;
    else
        print("Autodrive hat ein Problem beim Initialisieren festgestellt");
        AutoDrive:stopAD(vehicle); 
    end;
end;

function AutoDrive:defineMinDistanceByVehicleType(vehicle)
    local min_distance = 1.8;
    if vehicle.typeDesc == "combine" or  vehicle.typeDesc == "harvester" then
        min_distance = 6;
    end;
    if vehicle.typeDesc == "telehandler" then
        min_distance = 3;
    end;
    return min_distance;
end;

function AutoDrive:handleReachedWayPoint(vehicle)
    vehicle.ad.lastSpeed = vehicle.ad.speedOverride;
    vehicle.ad.timeTillDeadLock = 15000;

    if vehicle.ad.wayPoints[vehicle.ad.currentWayPoint+1] ~= nil then
        vehicle.ad.currentWayPoint = vehicle.ad.currentWayPoint + 1;
        vehicle.ad.targetX = vehicle.ad.wayPoints[vehicle.ad.currentWayPoint].x;
        vehicle.ad.targetZ = vehicle.ad.wayPoints[vehicle.ad.currentWayPoint].z;
    else
        --print("Last waypoint reached");
        if vehicle.ad.unloadAtTrigger == false then
            if vehicle.ad.roundTrip == false then
                --print("No Roundtrip");
                if vehicle.ad.reverseTrack == true then
                    --print("Starting reverse track");
                    --reverse driving direction
                    if vehicle.ad.drivingForward == true then
                        vehicle.ad.drivingForward = false;
                    else
                        vehicle.ad.drivingForward = true;
                    end;
                    --reverse waypoints
                    local reverseWaypoints = {};
                    local _counterWayPoints = 0;
                    for n in pairs(vehicle.ad.wayPoints) do
                        _counterWayPoints = _counterWayPoints + 1;
                    end;
                    for n in pairs(vehicle.ad.wayPoints) do
                        reverseWaypoints[_counterWayPoints] = vehicle.ad.wayPoints[n];
                        _counterWayPoints = _counterWayPoints - 1;
                    end;
                    for n in pairs(reverseWaypoints) do
                        vehicle.ad.wayPoints[n] = reverseWaypoints[n];
                    end;
                    --start again:
                    vehicle.ad.currentWayPoint = 1
                    vehicle.ad.targetX = vehicle.ad.wayPoints[vehicle.ad.currentWayPoint].x;
                    vehicle.ad.targetZ = vehicle.ad.wayPoints[vehicle.ad.currentWayPoint].z;

                else
                    --print("Shutting down");
                    AutoDrive.printMessage = g_i18n:getText("AD_Driver_of") .. " " .. vehicle.name .. " " .. g_i18n:getText("AD_has_reached") .. " " .. vehicle.ad.nameOfSelectedTarget;
                    AutoDrive.nPrintTime = 6000;
                    AutoDrive:stopAD(vehicle); 
                end;
            else
                --print("Going into next round");
                vehicle.ad.currentWayPoint = 1
                if vehicle.ad.wayPoints[vehicle.ad.currentWayPoint] ~= nil then
                    vehicle.ad.targetX = vehicle.ad.wayPoints[vehicle.ad.currentWayPoint].x;
                    vehicle.ad.targetZ = vehicle.ad.wayPoints[vehicle.ad.currentWayPoint].z;
                else
                    print("Autodrive hat ein Problem beim Rundkurs festgestellt");
                    AutoDrive:stopAD(vehicle);
                end;
            end;
        else
            if vehicle.ad.unloadSwitch == true then
                vehicle.ad.timeTillDeadLock = 15000;

                local closest = vehicle.ad.wayPoints[vehicle.ad.currentWayPoint].id;
                vehicle.ad.wayPoints = AutoDrive:FastShortestPath(AutoDrive.mapWayPoints, closest, AutoDrive.mapMarker[vehicle.ad.mapMarkerSelected].name, vehicle.ad.targetSelected);
                vehicle.ad.currentWayPoint = 1;

                vehicle.ad.targetX = vehicle.ad.wayPoints[vehicle.ad.currentWayPoint].x;
                vehicle.ad.targetZ = vehicle.ad.wayPoints[vehicle.ad.currentWayPoint].z;

				vehicle.ad.isPaused = true;
                vehicle.ad.unloadSwitch = false;
            else
                vehicle.ad.timeTillDeadLock = 15000;

                local closest = vehicle.ad.wayPoints[vehicle.ad.currentWayPoint].id;
                vehicle.ad.wayPoints = AutoDrive:FastShortestPath(AutoDrive.mapWayPoints, closest, AutoDrive.mapMarker[vehicle.ad.mapMarkerSelected_Unload].name, AutoDrive.mapMarker[vehicle.ad.mapMarkerSelected_Unload].id);
                vehicle.ad.currentWayPoint = 1;

                vehicle.ad.targetX = vehicle.ad.wayPoints[vehicle.ad.currentWayPoint].x;
                vehicle.ad.targetZ = vehicle.ad.wayPoints[vehicle.ad.currentWayPoint].z;

                vehicle.ad.isPaused = true;
                vehicle.ad.unloadSwitch = true;
            end;
        end;
    end;
end;

function AutoDrive:driveToNextWayPoint(vehicle, dt)
	--AutoDrive:addlog("Issuing Drive Request");    
    local x,y,z = getWorldTranslation(vehicle.components[1].node);
    xl,yl,zl = worldToLocal(vehicle.components[1].node, vehicle.ad.targetX,y,vehicle.ad.targetZ);

    vehicle.ad.speedOverride = -1;
    if vehicle.ad.wayPoints[vehicle.ad.currentWayPoint-1] ~= nil and vehicle.ad.wayPoints[vehicle.ad.currentWayPoint+1] ~= nil then
        local wp_ahead = vehicle.ad.wayPoints[vehicle.ad.currentWayPoint+1];
        local wp_current = vehicle.ad.wayPoints[vehicle.ad.currentWayPoint];
        local wp_ref = vehicle.ad.wayPoints[vehicle.ad.currentWayPoint-1];
        local highestAngle = 0;
        local distanceToLookAhead = 15;
        local pointsToLookAhead = 3;
        local doneCheckingRoute = false;
        local currentLookAheadPoint = 1;
        while not doneCheckingRoute and currentLookAheadPoint <= pointsToLookAhead do
            if vehicle.ad.wayPoints[vehicle.ad.currentWayPoint+currentLookAheadPoint] ~= nil then
                local wp_ahead = vehicle.ad.wayPoints[vehicle.ad.currentWayPoint+currentLookAheadPoint];
                local wp_current = vehicle.ad.wayPoints[vehicle.ad.currentWayPoint+currentLookAheadPoint-1];
                local wp_ref = vehicle.ad.wayPoints[vehicle.ad.currentWayPoint+currentLookAheadPoint-2];    
                
                local angle = AutoDrive:angleBetween( 	{x=	wp_ahead.x	-	wp_ref.x, z = wp_ahead.z - wp_ref.z },
                                                {x=	wp_current.x-	wp_ref.x, z = wp_current.z - wp_ref.z } )
                if getDistance( vehicle.ad.wayPoints[vehicle.ad.currentWayPoint].x,  vehicle.ad.wayPoints[vehicle.ad.currentWayPoint].z,
                                wp_ahead.x,                                         wp_ahead.z) 
                    <= distanceToLookAhead then
                    highestAngle = math.max(highestAngle, angle);
                else
                    doneCheckingRoute = true;
                end;
            else
                doneCheckingRoute = true;
            end;
            currentLookAheadPoint = currentLookAheadPoint+1;
        end;


        if highestAngle < 3 then vehicle.ad.speedOverride = vehicle.ad.targetSpeed; end;
        if highestAngle >= 3 and highestAngle < 5 then vehicle.ad.speedOverride = 38; end;
        if highestAngle >= 5 and highestAngle < 8 then vehicle.ad.speedOverride = 27; end;
        if highestAngle >= 8 and highestAngle < 12 then vehicle.ad.speedOverride = 20; end;
        if highestAngle >= 12 and highestAngle < 15 then vehicle.ad.speedOverride = 13; end;
        if highestAngle >= 15 and highestAngle < 20 then vehicle.ad.speedOverride = 11; end;
        if highestAngle >= 20 and highestAngle < 30 then vehicle.ad.speedOverride = 9; end;
        if highestAngle >= 30 and highestAngle < 90 then vehicle.ad.speedOverride = 4; end;
    end;
    if vehicle.ad.speedOverride == -1 then vehicle.ad.speedOverride = vehicle.ad.targetSpeed; end;
    if vehicle.ad.speedOverride > vehicle.ad.targetSpeed then vehicle.ad.speedOverride = vehicle.ad.targetSpeed; end;

    local wp_new = nil;

    if wp_new ~= nil then
        xl,yl,zl = worldToLocal(vehicle.components[1].node, wp_new.x,y,wp_new.z);
    end;

    if vehicle.ad.unloadAtTrigger == true then
        local destination = AutoDrive.mapWayPoints[vehicle.ad.targetSelected_Unload];
        local start = AutoDrive.mapWayPoints[vehicle.ad.targetSelected];
        local distance1 = getDistance(x,z, destination.x, destination.z);
        local distance2 = getDistance(x,z, start.x, start.z);
        if distance1 < 20 or distance2 < 20 then
            if vehicle.ad.speedOverride > 12 then
                vehicle.ad.speedOverride = 12;
            end;
        end;
    end;

    local finalSpeed = vehicle.ad.speedOverride;
    local finalAcceleration = true;
    
    local node = vehicle.components[1].node;	
    if vehicle.getAIVehicleDirectionNode ~= nil then
      node = vehicle:getAIVehicleDirectionNode();
    end;	
    local maxAngle = 30;

    --start driving to the nextWayPoint when closing in on current waypoint in order to avoid harsh steering angles and oversteering
    if vehicle.ad.wayPoints[vehicle.ad.currentWayPoint+1] ~= nil then
        local wp_current = vehicle.ad.wayPoints[vehicle.ad.currentWayPoint];
        local wp_ahead = vehicle.ad.wayPoints[vehicle.ad.currentWayPoint+1];

        local distX = wp_ahead.x - wp_current.x;
        local distZ = wp_ahead.z - wp_current.z;

        local distanceToCurrentTarget = getDistance(x,z, wp_current.x, wp_current.z);
        local lookAheadDistance = 5 - distanceToCurrentTarget;

        if lookAheadDistance > 0 then
            local addX = lookAheadDistance * (math.abs(distX)/(math.abs(distX)+math.abs(distZ)));
            local addZ = lookAheadDistance * (math.abs(distZ)/(math.abs(distX)+math.abs(distZ)));
            if distX < 0 then
                addX = -addX;
            end;

            if distZ < 0 then
                addZ = -addZ;
            end;

            vehicle.ad.targetX = vehicle.ad.wayPoints[vehicle.ad.currentWayPoint].x + addX;
            vehicle.ad.targetZ = vehicle.ad.wayPoints[vehicle.ad.currentWayPoint].z + addZ;
        end;        
    end;

    local lx, lz = AIVehicleUtil.getDriveDirection(vehicle.components[1].node, vehicle.ad.targetX,y,vehicle.ad.targetZ);
    
    if vehicle.ad.drivingForward == false then
        lz = -lz;
        lx = -lx;
        maxAngle = 5;
        finalSpeed = finalSpeed / 2;
    end;
    --vehicle,dt,steeringAngleLimit,acceleration,slowAcceleration,slowAngleLimit,allowedToDrive,moveForwards,lx,lz,maxSpeed,slowDownFactor,angle
    AIVehicleUtil.driveInDirection(vehicle, dt, maxAngle, 1, 0.2, maxAngle, true, vehicle.ad.drivingForward, lx, lz, finalSpeed, 1);
end;

function AutoDrive:driveToLastWaypoint(vehicle, dt)
	--print("Reaching last waypoint - slowing down"); 
	local x,y,z = getWorldTranslation(vehicle.components[1].node);   
    local finalSpeed = 8;	
    local maxAngle = 50;				
    local lx, lz = AIVehicleUtil.getDriveDirection(vehicle.components[1].node, vehicle.ad.targetX,y,vehicle.ad.targetZ);
    if vehicle.ad.drivingForward == false then
        lz = -lz;
        lx = -lx;
        maxAngle = 5;
        finalSpeed = finalSpeed / 2;
    end;
    AIVehicleUtil.driveInDirection(vehicle, dt, maxAngle, 1, 0.2, maxAngle, true, vehicle.ad.drivingForward, lx, lz, finalSpeed, 1);
end;

function AutoDrive:handleDeadlock(vehicle, dt)
	if vehicle.ad.inDeadLock == true and vehicle.ad.isActive == true and vehicle.isServer then
		AutoDrive.printMessage = g_i18n:getText("AD_Driver_of") .. " " .. vehicle.name .. " " .. g_i18n:getText("AD_got_stuck");
		AutoDrive.nPrintTime = 10000;
		
		--deadlock handling
		if vehicle.ad.inDeadLockRepairCounter < 1 then
			AutoDrive.printMessage = g_i18n:getText("AD_Driver_of") .. " " .. vehicle.name .. " " .. g_i18n:getText("AD_got_stuck");
			AutoDrive.nPrintTime = 10000;
			vehicle.ad.stopAD = true;
			vehicle.ad.isActive = false;
		else
			--print("AD: Trying to recover from deadlock")
			if vehicle.ad.wayPoints[vehicle.ad.currentWayPoint+2] ~= nil then
				vehicle.ad.currentWayPoint = vehicle.ad.currentWayPoint + 1;
				vehicle.ad.targetX = vehicle.ad.wayPoints[vehicle.ad.currentWayPoint].x;
				vehicle.ad.targetZ = vehicle.ad.wayPoints[vehicle.ad.currentWayPoint].z;

				vehicle.ad.inDeadLock = false;
				vehicle.ad.timeTillDeadLock = 15000;
				vehicle.ad.inDeadLockRepairCounter = vehicle.ad.inDeadLockRepairCounter - 1;
			end;
		end;
	end;
end;