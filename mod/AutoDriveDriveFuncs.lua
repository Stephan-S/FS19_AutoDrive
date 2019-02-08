function AutoDrive:handleDriving(vehicle, dt)
    AutoDrive:checkActiveAttributesSet(vehicle);
    AutoDrive:checkForDeadLock(vehicle, dt);   
	AutoDrive:handlePrintMessage(vehicle, dt);
	
	--follow waypoints on route:	
	if vehicle.ad.stopAD == true and vehicle.isServer then
		AutoDrive:stopAD(vehicle);
		vehicle.ad.stopAD = false;
		vehicle.ad.isPaused = false;
	end;
	
	if vehicle.components ~= nil and vehicle.isServer then	
		local x,y,z = getWorldTranslation( vehicle.components[1].node );
		local xl,yl,zl = worldToLocal(vehicle.components[1].node, x,y,z);
			
		if vehicle.ad.isActive == true and vehicle.ad.isPaused == false then
			if vehicle.steeringEnabled then
                vehicle.steeringEnabled = false;
			end

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
	

	if vehicle.ad.isActive == true and vehicle.ad.unloadAtTrigger == true and vehicle.isServer == true then
		local trailers = {};
		local trailerCount = 0;
		local trailer = nil;
		if vehicle.attachedImplements ~= nil then
			for _, implement in pairs(vehicle.attachedImplements) do
				if implement.object ~= nil then
					if implement.object.typeDesc == g_i18n:getText("typeDesc_tipper") then
						trailer = implement.object;
						trailers[1] = trailer;
						trailerCount = 1;
						for __,impl in pairs(trailer.attachedImplements) do
							if impl.object ~= nil then
								if impl.object.typeDesc == g_i18n:getText("typeDesc_tipper") then
									trailers[2] = impl.object;
									trailerCount = 2;
									for ___,implement3 in pairs(trailers[2].attachedImplements) do
										if implement3.object ~= nil then
											if implement3.object.typeDesc == g_i18n:getText("typeDesc_tipper") then
												trailers[3] = implement3.object;
												trailerCount = 3;
											end;
										end;
									end;
								end;
							end;
						end;
					end;
				end;
			end;

			--check distance to unloading destination, do not unload too far from it. You never know where the tractor might already drive over an unloading trigger before that
			local x,y,z = getWorldTranslation(vehicle.components[1].node);
			local destination = AutoDrive.mapWayPoints[vehicle.ad.targetSelected_Unload];
			local distance = getDistance(x,z, destination.x, destination.z);
			if distance < 40 then
				--check trailer trigger: trailerTipTriggers
				local globalUnload = false;
				for _,trailer in pairs(trailers) do
					if trailer ~= nil then
						for _,trigger in pairs(g_currentMission.tipTriggers) do

							local allowed,minDistance,bestPoint = trigger:getTipInfoForTrailer(trailer, trailer.preferedTipReferencePointIndex);
							--print("Min distance: " .. minDistance);
							if allowed and minDistance == 0 then
								if trailer.tipping ~= true  then
									--print("toggling tip state for " .. trigger.stationName .. " distance: " .. minDistance );
									trailer:toggleTipState(trigger, bestPoint);
									vehicle.ad.isPaused = true;
									vehicle.ad.isUnloading = true;
									trailer.tipping = true;
								end;
							end;

							if trailer.tipState == Trailer.TIPSTATE_CLOSED and vehicle.ad.isUnloading == true and trailer.tipping == true then
								--print("trailer is unloaded. continue");
								trailer.tipping = false;
							end;

							if trailer.tipping == true or vehicle.ad.isPaused == false then
								globalUnload = true;
							end;

						end;
					end;
				end;
				if (globalUnload == false and vehicle.ad.isUnloading == true) or vehicle.ad.isPaused == false then
					vehicle.ad.isPaused = false;
					vehicle.ad.isUnloading = false;
				end;
			end;

			--check distance to unloading destination, do not unload too far from it. You never know where the tractor might already drive over an unloading trigger before that
			local x,y,z = getWorldTranslation(vehicle.components[1].node);
			local destination = AutoDrive.mapWayPoints[vehicle.ad.targetSelected];
			local distance = getDistance(x,z, destination.x, destination.z);
			if distance < 40 then
				--print("distance < 40");
				local globalLoading = false;

				for _,trailer in pairs(trailers) do
					if trailer ~= nil and vehicle.ad.unloadType ~= -1 then
						--print("Trailer detected. unloadType = " .. vehicle.ad.unloadType .. " level: " .. trailer:getFillLevel(vehicle.ad.unloadType));
						for _,trigger in pairs(g_currentMission.siloTriggers) do

							local valid = trigger:getIsValidTrailer(trailer);
							local level = trigger:getFillLevel(vehicle.ad.unloadType);
							local activatable = trigger.activeTriggers >=4 --trigger:getIsActivatable()
							local correctTrailer = false;
							if trigger.siloTrailer == trailer then correctTrailer = true; end;

							--print("valid: " .. tostring(valid) .. " level: " ..  tostring(level) .. " activatable: " .. tostring(activatable) .. " correctTrailer: " .. tostring(correctTrailer) );
							if valid and level > 0 and activatable and correctTrailer and trailer.ad.isLoading ~= true then --
								if	trailer:getFreeCapacity() > 1 then
									--print("Starting to unload into trailer" );
									trigger:startFill(vehicle.ad.unloadType);
									vehicle.ad.isPaused = true;
									vehicle.ad.isLoading = true;
									trailer.ad.isLoading = true;
								end;
							end;

							if (trailer:getFreeCapacity(vehicle.ad.unloadType) <= 0 or vehicle.ad.isPaused == false) and trailer.ad.isLoading == true and correctTrailer == true then
								--print("trailer is full. continue");
								trigger:stopFill();
								trailer.ad.isLoading = false;
							end;

							if trailer.ad.isLoading == true then
								globalLoading = true;
							end;

						end;
					end;
				end;
				if (globalLoading == false and vehicle.ad.isLoading == true) or vehicle.ad.isPaused == false then
					vehicle.ad.isPaused = false;
					vehicle.ad.isLoading = false;
				end;
			end;

		end;

		if vehicle.ad.isPaused == true and not vehicle.ad.isUnloading and not vehicle.ad.isLoading then
			if trailer == nil or trailer:getFreeCapacity() <= 0 then
				vehicle.ad.isPaused = false;
			end;
		end;

	end;
end;

function AutoDrive:checkActiveAttributesSet(vehicle)
    if vehicle.ad.isActive == true and vehicle.isServer then
        vehicle.forceIsActive = true;
        vehicle.stopMotorOnLeave = false;
		vehicle.disableCharacterOnLeave = true;
		if vehicle.isMotorStarted == false then
            vehicle:startMotor();
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
        
        DebugUtil.printTableRecursively(vehicle.ad.wayPoints, "--", 0,2);
        
        if vehicle.ad.wayPoints[2] ~= nil then
            vehicle.ad.currentWayPoint = 2;
        else
            vehicle.ad.currentWayPoint = 1;
        end;
    else
        vehicle.ad.currentWayPoint = 1;
    end;
	--print("currentWayPoint: " .. vehicle.ad.currentWayPoint .. " waypoint.id: "  .. vehicle.ad.wayPoints[vehicle.ad.currentWayPoint].id);
    if vehicle.ad.wayPoints[vehicle.ad.currentWayPoint] ~= nil then
        vehicle.ad.targetX = vehicle.ad.wayPoints[vehicle.ad.currentWayPoint].x;
        vehicle.ad.targetZ = vehicle.ad.wayPoints[vehicle.ad.currentWayPoint].z;
        vehicle.ad.initialized = true;
        vehicle.ad.drivingForward = true;
    else
        --print("Autodrive hat ein Problem festgestellt");
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
        print("Last waypoint reached");
        if vehicle.ad.unloadAtTrigger == false then
            if vehicle.ad.roundTrip == false then
                print("No Roundtrip");
                if vehicle.ad.reverseTrack == true then
                    print("Starting reverse track");
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
                    print("Shutting down");
                    AutoDrive.printMessage = g_i18n:getText("AD_Driver_of") .. " " .. vehicle.name .. " " .. g_i18n:getText("AD_has_reached") .. " " .. vehicle.ad.nameOfSelectedTarget;
                    AutoDrive.nPrintTime = 6000;
                    AutoDrive:stopAD(vehicle); 
                end;
            else
                print("Going into next round");
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
        local angle = AutoDrive:angleBetween( 	{x=	wp_ahead.x	-	wp_ref.x, z = wp_ahead.z - wp_ref.z },
                                                {x=	wp_current.x-	wp_ref.x, z = wp_current.z - wp_ref.z } )


        if angle < 3 then vehicle.ad.speedOverride = vehicle.ad.targetSpeed; end;
        if angle >= 3 and angle < 5 then vehicle.ad.speedOverride = 30; end;
        if angle >= 5 and angle < 8 then vehicle.ad.speedOverride = 22; end;
        if angle >= 8 and angle < 12 then vehicle.ad.speedOverride = 16; end;
        if angle >= 12 and angle < 15 then vehicle.ad.speedOverride = 10; end;
        if angle >= 15 and angle < 20 then vehicle.ad.speedOverride = 6; end;
        if angle >= 20 and angle < 30 then vehicle.ad.speedOverride = 4; end;
        if angle >= 30 and angle < 90 then vehicle.ad.speedOverride = 2; end;
        --print("Speed override: " .. vehicle.ad.speedOverride);
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
    
	--vehicle:setCruiseControlState(Drivable.CRUISECONTROL_STATE_ACTIVE);
	local node = vehicle.components[1].node;					
	if vehicle.getAIVehicleDirectionNode ~= nil then
		node = vehicle:getAIVehicleDirectionNode();
	end;
    local lx, lz = AIVehicleUtil.getDriveDirection(node, vehicle.ad.targetX,y,vehicle.ad.targetZ);
    --vehicle,dt,steeringAngleLimit,acceleration,slowAcceleration,slowAngleLimit,allowedToDrive,moveForwards,lx,lz,maxSpeed,slowDownFactor,angle
    AIVehicleUtil.driveInDirection(vehicle, dt, 30, 1, 0.2, 20, true, vehicle.ad.drivingForward, lx, lz, finalSpeed, 1);
    --AIVehicleUtil.driveToPoint(vehicle, dt, 1, true, vehicle.ad.drivingForward, xl, zl, finalSpeed, false );
end;

function AutoDrive:driveToLastWaypoint(vehicle, dt)
	--print("Reaching last waypoint - slowing down"); 
	local x,y,z = getWorldTranslation(vehicle.components[1].node);   
    local finalSpeed = 8;					
    local lx, lz = AIVehicleUtil.getDriveDirection(vehicle.components[1].node, vehicle.ad.targetX,y,vehicle.ad.targetZ);
    AIVehicleUtil.driveInDirection(vehicle, dt, 75, 1, 0.2, 20, true, vehicle.ad.drivingForward, lx, lz, finalSpeed, 1);
end;