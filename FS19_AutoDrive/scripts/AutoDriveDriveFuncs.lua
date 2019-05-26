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
				AutoDrive:initializeAD(vehicle, dt)
            else
                local min_distance  = AutoDrive:defineMinDistanceByVehicleType(vehicle);				

				if AutoDrive:getDistance(x,z, vehicle.ad.targetX, vehicle.ad.targetZ) < min_distance then
                    AutoDrive:handleReachedWayPoint(vehicle);  
                end;
                
                if vehicle.ad.isActive == true and vehicle.isServer then
                    vehicle.ad.trafficDetected =    AutoDrive:detectAdTrafficOnRoute(vehicle) or 
                                                    AutoDrive:detectTraffic(vehicle)
                    
                    if vehicle.ad.isPausedCauseTraffic == true and vehicle.ad.trafficDetected == false then
                        vehicle.ad.isPaused = false;
                        vehicle.ad.isPausedCauseTraffic = false;
                    end;
                                                    
                    if vehicle.ad.wayPoints[vehicle.ad.currentWayPoint+1] ~= nil then                
                        AutoDrive:driveToNextWayPoint(vehicle, dt);                    
                    else
                        AutoDrive:driveToLastWaypoint(vehicle, dt);                    
                    end;	                			
                end;
			end;            
		end;

        if vehicle.ad.isPausedCauseTraffic then
            vehicle.ad.trafficDetected =    AutoDrive:detectAdTrafficOnRoute(vehicle) or 
                                            AutoDrive:detectTraffic(vehicle)

            if vehicle.ad.trafficDetected == false then
                vehicle.ad.isPaused = false;
                vehicle.ad.isPausedCauseTraffic = false;
            end;
        end;

		if vehicle.ad.isPaused == true then
			AutoDrive:getVehicleToStop(vehicle, false, dt);
            vehicle.ad.timeTillDeadLock = 15000;
            vehicle.ad.inDeadLock = false;
            
            if math.abs(vehicle.lastSpeedReal) < 0.002 then
                if vehicle.ad.combineState == AutoDrive.WAIT_TILL_UNLOADED then
                    vehicle.ad.isPaused = false;
                end;
            end;
		end;
	end;
end;

function AutoDrive:checkActiveAttributesSet(vehicle)
    if vehicle.ad.isActive == true and vehicle.isServer then
        vehicle.forceIsActive = true;
        vehicle.spec_motorized.stopMotorOnLeave = false;
        vehicle.spec_enterable.disableCharacterOnLeave = false;
        --vehicle.spec_aiVehicle.isActive = true
        
        if vehicle.steeringEnabled == true then
            vehicle.steeringEnabled = false;
        end
	end;
	
	if vehicle.startMotor and vehicle.stopMotor then
		if vehicle.ad.isActive and vehicle:getCanMotorRun() then
			vehicle:startMotor();
		end;
    end;
    
    if not vehicle:getCanMotorRun() then
        vehicle.ad.isPaused = true;
        vehicle.ad.inDeadLock = false;
		vehicle.ad.timeTillDeadLock = 15000;
		vehicle.ad.inDeadLockRepairCounter = 4;
    end;

	if vehicle.ad.isActive == true and vehicle.ad.isPaused == false then
		if vehicle.steeringEnabled then
			vehicle.steeringEnabled = false;
		end;
    end;
    
    if vehicle.ad.isActive == false then       
        if vehicle.currentHelper == nil then
            --vehicle.spec_aiVehicle.isActive = false;

            if vehicle.steeringEnabled == false then
                vehicle.steeringEnabled = true;
            end
        end;
    end;
end;

function AutoDrive:checkForDeadLock(vehicle, dt)
    if vehicle.ad.isActive == true and vehicle.isServer and vehicle.ad.isStopping == false then		
        vehicle.ad.timeTillDeadLock = vehicle.ad.timeTillDeadLock - dt;
		if vehicle.ad.timeTillDeadLock < 0 and vehicle.ad.timeTillDeadLock ~= -1 then
			--print("Deadlock reached due to timer");
			vehicle.ad.inDeadLock = true;
		end;		
	else
		vehicle.ad.inDeadLock = false;
		vehicle.ad.timeTillDeadLock = 15000;
		vehicle.ad.inDeadLockRepairCounter = 4;
    end;
    
    if vehicle.lastSpeedReal <= 0.0005 then
        vehicle.ad.stoppedTimer = math.max(0, vehicle.ad.stoppedTimer-dt);
    else
        vehicle.ad.stoppedTimer = 5000;
    end;
end;

function AutoDrive:handlePrintMessage(vehicle, dt)    
    if vehicle == g_currentMission.controlledVehicle or (g_dedicatedServerInfo ~= nil and (not AutoDrive.runThisFrame)) then                
    
        if AutoDrive.print.currentMessage ~= nil then
            AutoDrive.print.currentMessageActiveSince = AutoDrive.print.currentMessageActiveSince + dt;
            if AutoDrive.print.nextMessage ~= nil then
                if AutoDrive.print.currentMessageActiveSince > 6000 then
                    AutoDrive.print.currentMessage = AutoDrive.print.nextMessage;
                    AutoDrive.print.referencedVehicle = AutoDrive.print.nextReferencedVehicle;
                    AutoDrive.print.nextMessage = nil;
                    AutoDrive.print.nextReferencedVehicle = nil;
                    AutoDrive.print.currentMessageActiveSince = 0;
                end;
            end;
            if AutoDrive.print.currentMessageActiveSince > AutoDrive.print.showMessageFor then
                AutoDrive.print.currentMessage = nil;
                AutoDrive.print.currentMessageActiveSince = 0;
                AutoDrive.print.referencedVehicle = nil;
                AutoDrive.print.showMessageFor = 12000;
            end;
        else
            if AutoDrive.print.nextMessage ~= nil then
                AutoDrive.print.currentMessage = AutoDrive.print.nextMessage;
                AutoDrive.print.referencedVehicle = AutoDrive.print.nextReferencedVehicle;
                AutoDrive.print.nextMessage = nil;
                AutoDrive.print.nextReferencedVehicle = nil;
                AutoDrive.print.currentMessageActiveSince = 0;
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

function AutoDrive:initializeAD(vehicle, dt)   
    vehicle.ad.timeTillDeadLock = 15000;

    if vehicle.ad.mode == AutoDrive.MODE_UNLOAD and vehicle.ad.combineState ~= AutoDrive.COMBINE_UNINITIALIZED then
        if AutoDrive:initializeADCombine(vehicle, dt) == true then
            return;
        end;
    else
        local closest = AutoDrive:findMatchingWayPointForVehicle(vehicle);
        if vehicle.ad.skipStart == true then
            vehicle.ad.skipStart = false;
            if AutoDrive.mapMarker[vehicle.ad.mapMarkerSelected_Unload] == nil then
                return;
            end;
            vehicle.ad.wayPoints = AutoDrive:FastShortestPath(AutoDrive.mapWayPoints, closest, AutoDrive.mapMarker[vehicle.ad.mapMarkerSelected_Unload].name, AutoDrive.mapMarker[vehicle.ad.mapMarkerSelected_Unload].id);
            vehicle.ad.wayPointsChanged = true;
            vehicle.ad.unloadSwitch = true;   
            vehicle.ad.combineState = AutoDrive.DRIVE_TO_UNLOAD_POS;
        else
            if AutoDrive.mapMarker[vehicle.ad.mapMarkerSelected] == nil then
                return;
            end;
            vehicle.ad.wayPoints = AutoDrive:FastShortestPath(AutoDrive.mapWayPoints, closest, AutoDrive.mapMarker[vehicle.ad.mapMarkerSelected].name, vehicle.ad.targetSelected);    
            vehicle.ad.wayPointsChanged = true;
        end;
        
        if vehicle.ad.wayPoints ~= nil then
            if vehicle.ad.wayPoints[2] == nil and vehicle.ad.wayPoints[1] ~= nil and vehicle.ad.wayPoints[1].id ~= vehicle.ad.targetSelected then			
                AutoDrive:printMessage(vehicle, g_i18n:getText("AD_Driver_of") .. " " .. vehicle.name .. " " .. g_i18n:getText("AD_cannot_reach") .. " " .. vehicle.ad.nameOfSelectedTarget);               
                AutoDrive:stopAD(vehicle);
            end;
            
            if vehicle.ad.wayPoints[2] ~= nil then
                vehicle.ad.currentWayPoint = 2;
            else
                vehicle.ad.currentWayPoint = 1;
            end;
        end;
    end;
    
	if vehicle.ad.wayPoints ~= nil and vehicle.ad.wayPoints[vehicle.ad.currentWayPoint] ~= nil then
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
    if vehicle.typeDesc == "combine" or  vehicle.typeDesc == "harvester" or vehicle.typeName == "combineDrivable" then
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
        if vehicle.ad.mode ~= AutoDrive.MODE_PICKUPANDDELIVER and vehicle.ad.mode ~= AutoDrive.MODE_UNLOAD then            
            --print("Shutting down");
            local target = vehicle.ad.nameOfSelectedTarget;
            for markerIndex, mapMarker in pairs(AutoDrive.mapMarker) do
                if mapMarker.id == vehicle.ad.wayPoints[vehicle.ad.currentWayPoint].id then
                    target = mapMarker.name;
                end;
            end;
            
            AutoDrive:printMessage(vehicle, g_i18n:getText("AD_Driver_of") .. " " .. vehicle.name .. " " .. g_i18n:getText("AD_has_reached") .. " " .. target);
            AutoDrive:stopAD(vehicle);           
        else
            vehicle.ad.startedLoadingAtTrigger = false;
            if vehicle.ad.mode == AutoDrive.MODE_UNLOAD then
                AutoDrive:handleReachedWayPointCombine(vehicle);
            else
                if vehicle.ad.unloadSwitch == true then
                    vehicle.ad.timeTillDeadLock = 15000;

                    local closest = vehicle.ad.wayPoints[vehicle.ad.currentWayPoint].id;
                    vehicle.ad.wayPoints = AutoDrive:FastShortestPath(AutoDrive.mapWayPoints, closest, AutoDrive.mapMarker[vehicle.ad.mapMarkerSelected].name, vehicle.ad.targetSelected);
                    vehicle.ad.wayPointsChanged = true;
                    vehicle.ad.currentWayPoint = 1;

                    vehicle.ad.targetX = vehicle.ad.wayPoints[vehicle.ad.currentWayPoint].x;
                    vehicle.ad.targetZ = vehicle.ad.wayPoints[vehicle.ad.currentWayPoint].z;

                    vehicle.ad.isPaused = true;
                    vehicle.ad.unloadSwitch = false;
                else
                    vehicle.ad.timeTillDeadLock = 15000;

                    if vehicle.ad.mode == AutoDrive.MODE_PICKUPANDDELIVER then
                        local closest = vehicle.ad.wayPoints[vehicle.ad.currentWayPoint].id;
                        vehicle.ad.wayPoints = AutoDrive:FastShortestPath(AutoDrive.mapWayPoints, closest, AutoDrive.mapMarker[vehicle.ad.mapMarkerSelected_Unload].name, AutoDrive.mapMarker[vehicle.ad.mapMarkerSelected_Unload].id);
                        vehicle.ad.wayPointsChanged = true;
                        vehicle.ad.currentWayPoint = 1;

                        vehicle.ad.targetX = vehicle.ad.wayPoints[vehicle.ad.currentWayPoint].x;
                        vehicle.ad.targetZ = vehicle.ad.wayPoints[vehicle.ad.currentWayPoint].z;
                        vehicle.ad.unloadSwitch = true;                        
                    end;

                    vehicle.ad.isPaused = true;
                end;
            end;
        end;
    end;
end;

function AutoDrive:driveToNextWayPoint(vehicle, dt) 
    local x,y,z = getWorldTranslation(vehicle.components[1].node);
    xl,yl,zl = worldToLocal(vehicle.components[1].node, vehicle.ad.targetX,y,vehicle.ad.targetZ);

    vehicle.ad.speedOverride = -1;
    if vehicle.ad.wayPoints[vehicle.ad.currentWayPoint-1] ~= nil and vehicle.ad.wayPoints[vehicle.ad.currentWayPoint+1] ~= nil then
        local wp_ahead = vehicle.ad.wayPoints[vehicle.ad.currentWayPoint+1];
        local wp_current = vehicle.ad.wayPoints[vehicle.ad.currentWayPoint];
        local wp_ref = vehicle.ad.wayPoints[vehicle.ad.currentWayPoint-1];
        local highestAngle = 0;
        local distanceToLookAhead = AutoDrive:getSetting("lookAheadBraking");
        local pointsToLookAhead = 20;
        local doneCheckingRoute = false;
        local currentLookAheadPoint = 1;
        while not doneCheckingRoute and currentLookAheadPoint <= pointsToLookAhead do
            if vehicle.ad.wayPoints[vehicle.ad.currentWayPoint+currentLookAheadPoint] ~= nil then
                local wp_ahead = vehicle.ad.wayPoints[vehicle.ad.currentWayPoint+currentLookAheadPoint];
                local wp_current = vehicle.ad.wayPoints[vehicle.ad.currentWayPoint+currentLookAheadPoint-1];
                local wp_ref = vehicle.ad.wayPoints[vehicle.ad.currentWayPoint+currentLookAheadPoint-2];    
                
                local angle = AutoDrive:angleBetween( 	{x=	wp_ahead.x	-	wp_ref.x, z = wp_ahead.z - wp_ref.z },
                                                {x=	wp_current.x-	wp_ref.x, z = wp_current.z - wp_ref.z } )
                angle = math.abs(angle);
                if AutoDrive:getDistance( vehicle.ad.wayPoints[vehicle.ad.currentWayPoint].x,  vehicle.ad.wayPoints[vehicle.ad.currentWayPoint].z,
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
        if highestAngle >= 15 and highestAngle < 20 then vehicle.ad.speedOverride = 13; end;
        if highestAngle >= 20 and highestAngle < 30 then vehicle.ad.speedOverride = 13; end;
        if highestAngle >= 30 and highestAngle < 90 then vehicle.ad.speedOverride = 13; end;
    end;
    if vehicle.ad.speedOverride == -1 then vehicle.ad.speedOverride = vehicle.ad.targetSpeed; end;
    if vehicle.ad.speedOverride > vehicle.ad.targetSpeed then vehicle.ad.speedOverride = vehicle.ad.targetSpeed; end;
    if vehicle.ad.wayPoints[vehicle.ad.currentWayPoint+2] == nil then
        vehicle.ad.speedOverride = math.min(12, vehicle.ad.speedOverride);
    end;
    if vehicle.ad.wayPoints[vehicle.ad.currentWayPoint+3] == nil then
        vehicle.ad.speedOverride = math.min(24, vehicle.ad.speedOverride);
    end;

    local wp_new = nil;

    if wp_new ~= nil then
        xl,yl,zl = worldToLocal(vehicle.components[1].node, wp_new.x,y,wp_new.z);
    end;

    if vehicle.ad.mode == AutoDrive.MODE_DELIVERTO or vehicle.ad.mode == AutoDrive.MODE_PICKUPANDDELIVER or vehicle.ad.mode == AutoDrive.MODE_UNLOAD then
        local destination = AutoDrive.mapWayPoints[vehicle.ad.targetSelected_Unload];
        local start = AutoDrive.mapWayPoints[vehicle.ad.targetSelected];
        if destination ~= nil and start ~= nil then
            local distance1 = AutoDrive:getDistance(x,z, destination.x, destination.z);
            local distance2 = AutoDrive:getDistance(x,z, start.x, start.z);
            if distance1 < 20 or distance2 < 20 then
                if vehicle.ad.speedOverride > 12 then
                    vehicle.ad.speedOverride = 12;
                end;
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
    if vehicle.maxRotation then
        maxAngle = math.deg(vehicle.maxRotation);
	end

    vehicle.ad.targetX, vehicle.ad.targetZ = AutoDrive:getLookAheadTarget(vehicle);    

    local lx, lz = AIVehicleUtil.getDriveDirection(vehicle.components[1].node, vehicle.ad.targetX,y,vehicle.ad.targetZ);
    
    if vehicle.ad.drivingForward == false then
        lz = -lz;
        lx = -lx;
        maxAngle = maxAngle*2;
        finalSpeed = finalSpeed / 2;
    end;

    if vehicle.ad.lastUsedSpeed == nil then
        vehicle.ad.lastUsedSpeed = finalSpeed;
    end;

    if finalSpeed > vehicle.ad.lastUsedSpeed then
        finalSpeed = math.min(vehicle.ad.lastUsedSpeed + (dt/1000)*5, finalSpeed);
    elseif finalSpeed < vehicle.ad.lastUsedSpeed then
        finalSpeed = math.max(vehicle.ad.lastUsedSpeed - (dt/1000)*5, finalSpeed);
    end;

    vehicle.ad.lastUsedSpeed = finalSpeed;

    local acceleration = 1;
    if vehicle.ad.trafficDetected == true then
        AutoDrive:getVehicleToStop(vehicle, false, dt);
        vehicle.ad.timeTillDeadLock = 15000;
        if math.abs(vehicle.lastSpeedReal) < 0.002 then
            vehicle.ad.isPaused = true;
            vehicle.ad.isPausedCauseTraffic = true;
        end;
    else   
        if vehicle.ad.isPausedCauseTraffic == true then
            vehicle.ad.isPaused = false;
            vehicle.ad.isPausedCauseTraffic = false;
        end;
        vehicle.ad.allowedToDrive = true;
        AIVehicleUtil.driveInDirection(vehicle, dt, maxAngle, acceleration, 0.2, maxAngle/2, vehicle.ad.allowedToDrive, vehicle.ad.drivingForward, lx, lz, finalSpeed, 0.5);    
    end;
    --vehicle,dt,steeringAngleLimit,acceleration,slowAcceleration,slowAngleLimit,allowedToDrive,moveForwards,lx,lz,maxSpeed,slowDownFactor,angle
    
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
    AIVehicleUtil.driveInDirection(vehicle, dt, maxAngle, 1, 0.2, maxAngle, true, vehicle.ad.drivingForward, lx, lz, finalSpeed, 0.4);
end;

function AutoDrive:handleDeadlock(vehicle, dt)
	if vehicle.ad.inDeadLock == true and vehicle.ad.isActive == true and vehicle.isServer then
		AutoDrive:printMessage(vehicle, g_i18n:getText("AD_Driver_of") .. " " .. vehicle.name .. " " .. g_i18n:getText("AD_got_stuck"));
		
		--deadlock handling
		if vehicle.ad.inDeadLockRepairCounter < 1 then
			AutoDrive:printMessage(vehicle, g_i18n:getText("AD_Driver_of") .. " " .. vehicle.name .. " " .. g_i18n:getText("AD_got_stuck"));
            AutoDrive:stopAD(vehicle);
		else
            --print("AD: Trying to recover from deadlock")
            local lookAhead = 3;
            if vehicle.ad.wayPoints[vehicle.ad.currentWayPoint+lookAhead] == nil then
                lookAhead = 2;
            end;
            if vehicle.ad.wayPoints[vehicle.ad.currentWayPoint+lookAhead] ~= nil then
                --figure out best moment to switch to next waypoint!

                local x,y,z = getWorldTranslation( vehicle.components[1].node );
                local rx,ry,rz = localDirectionToWorld(vehicle.components[1].node, math.sin(vehicle.rotatedTime),0,math.cos(vehicle.rotatedTime));	
                local vehicleVector = {x= math.sin(rx) ,z= math.sin(rz)};

                local wpAhead = vehicle.ad.wayPoints[vehicle.ad.currentWayPoint+lookAhead-1]
                local wpTwoAhead = vehicle.ad.wayPoints[vehicle.ad.currentWayPoint+lookAhead]

                local wpVector = {x= (wpTwoAhead.x - wpAhead.x), z= (wpTwoAhead.z - wpAhead.z) };
                local vehicleToWPVector = {x= (wpAhead.x - x), z= (wpAhead.z - z) };

                local angleBetweenVehicleVectorAndNextCourse = AutoDrive:angleBetween(vehicleVector, wpVector);
                local angleBetweenVehicleAndLookAheadWp = AutoDrive:angleBetween(vehicleVector, vehicleToWPVector);

                if (math.abs(angleBetweenVehicleVectorAndNextCourse) < 20 and math.abs(angleBetweenVehicleAndLookAheadWp) < 20) or (vehicle.ad.timeTillDeadLock < -10000) then                            
                    vehicle.ad.currentWayPoint = vehicle.ad.currentWayPoint + lookAhead-1;
                    vehicle.ad.targetX = vehicle.ad.wayPoints[vehicle.ad.currentWayPoint].x;
                    vehicle.ad.targetZ = vehicle.ad.wayPoints[vehicle.ad.currentWayPoint].z;

                    vehicle.ad.inDeadLock = false;
                    vehicle.ad.timeTillDeadLock = 15000;
                    vehicle.ad.inDeadLockRepairCounter = vehicle.ad.inDeadLockRepairCounter - 1;
                end;
			end;
		end;
	end;
end;

function AutoDrive:getLookAheadTarget(vehicle)
    --start driving to the nextWayPoint when closing in on current waypoint in order to avoid harsh steering angles and oversteering
    
    local x,y,z = getWorldTranslation(vehicle.components[1].node);
    local targetX = vehicle.ad.targetX;
    local targetZ = vehicle.ad.targetZ;
    if vehicle.ad.wayPoints[vehicle.ad.currentWayPoint+1] ~= nil then
        local wp_current = vehicle.ad.wayPoints[vehicle.ad.currentWayPoint];
        local wp_ahead = vehicle.ad.wayPoints[vehicle.ad.currentWayPoint+1];

        local lookAheadID = 1;
        local lookAheadDistance = AutoDrive:getSetting("lookAheadTurning");
        local distanceToCurrentTarget = AutoDrive:getDistance(x,z, wp_current.x, wp_current.z);
        lookAheadDistance = lookAheadDistance - distanceToCurrentTarget;

        local wp_ahead = vehicle.ad.wayPoints[vehicle.ad.currentWayPoint+lookAheadID];
        local distanceToNextTarget = AutoDrive:getDistance(x,z, wp_ahead.x, wp_ahead.z);
        while lookAheadDistance > distanceToNextTarget do
            lookAheadDistance = lookAheadDistance - distanceToNextTarget;
            lookAheadID = lookAheadID + 1;
            if vehicle.ad.wayPoints[vehicle.ad.currentWayPoint+lookAheadID] == nil then
                break;
            end;
            wp_current = wp_ahead;
            wp_ahead = vehicle.ad.wayPoints[vehicle.ad.currentWayPoint+lookAheadID];
            distanceToNextTarget = AutoDrive:getDistance(wp_current.x, wp_current.z, wp_ahead.x, wp_ahead.z);
        end;

        local distX = wp_ahead.x - wp_current.x;
        local distZ = wp_ahead.z - wp_current.z;
                
        if lookAheadDistance > 0 then
            local addX = lookAheadDistance * (math.abs(distX)/(math.abs(distX)+math.abs(distZ)));
            local addZ = lookAheadDistance * (math.abs(distZ)/(math.abs(distX)+math.abs(distZ)));
            if distX < 0 then
                addX = -addX;
            end;

            if distZ < 0 then
                addZ = -addZ;
            end;


            targetX = wp_current.x + addX;
            targetZ = wp_current.z + addZ;
        end;        
    end;

    --local x,y,z = getWorldTranslation(vehicle.components[1].node);    
    --AutoDrive:drawLine(AutoDrive:createVector(targetX,y, targetZ), AutoDrive:createVector(x,y,z), 1, 0, 1, 1);
    return targetX, targetZ;
end;