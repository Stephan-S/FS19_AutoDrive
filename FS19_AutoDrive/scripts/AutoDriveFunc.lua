function AutoDrive:startAD(vehicle)
    vehicle.ad.isActive = true;
	vehicle.ad.creationMode = false;
	vehicle.ad.startedLoadingAtTrigger = false;
    
    vehicle.forceIsActive = true;
    vehicle.spec_motorized.stopMotorOnLeave = false;
	vehicle.spec_enterable.disableCharacterOnLeave = false;
	if vehicle.currentHelper == nil then
		vehicle.currentHelper = g_helperManager:getRandomHelper()
		if vehicle.setRandomVehicleCharacter ~= nil then
			vehicle:setRandomVehicleCharacter()
			vehicle.ad.vehicleCharacter = vehicle.spec_enterable.vehicleCharacter;
		end
		vehicle.spec_aiVehicle.startedFarmId = vehicle.spec_enterable.controllerFarmId;
	end;
	vehicle.spec_aiVehicle.isActive = true	
    
    if vehicle.steeringEnabled == true then
       vehicle.steeringEnabled = false;
	end
	

	--vehicle.spec_aiVehicle.aiTrafficCollision = nil;
	--Code snippet from function AIVehicle:startAIVehicle(helperIndex, noEventSend, startedFarmId):
	if vehicle.getAINeedsTrafficCollisionBox ~= nil then
		if vehicle:getAINeedsTrafficCollisionBox() then
			local collisionRoot = g_i3DManager:loadSharedI3DFile(AIVehicle.TRAFFIC_COLLISION_BOX_FILENAME, vehicle.baseDirectory, false, true, false)
			if collisionRoot ~= nil and collisionRoot ~= 0 then
				local collision = getChildAt(collisionRoot, 0)
				link(getRootNode(), collision)

				vehicle.spec_aiVehicle.aiTrafficCollision = collision

				delete(collisionRoot)
			end
		end
	end;

	if g_server ~= nil then
		vehicle.ad.enableAI = 5;
	end;
	
	if g_server ~= nil then
		local leftCapacity = 0;
		local trailers, trailerCount = AutoDrive:getTrailersOf(vehicle);     
		if trailerCount > 0 then        
			for _,trailer in pairs(trailers) do
				if trailer.getFillUnits ~= nil then
					for _,fillUnit in pairs(trailer:getFillUnits()) do
						leftCapacity = leftCapacity + trailer:getFillUnitFreeCapacity(_)
					end
				end;
			end;
		end;
				
		if (vehicle.ad.mode == AutoDrive.MODE_PICKUPANDDELIVER or vehicle.ad.mode == AutoDrive.MODE_UNLOAD) and leftCapacity < 5000 then
			if AutoDrive.mapMarker[vehicle.ad.mapMarkerSelected_Unload] ~= nil then
				vehicle.ad.skipStart = true;
				vehicle.ad.wayPoints = AutoDrive:FastShortestPath(AutoDrive.mapWayPoints, closest, AutoDrive.mapMarker[vehicle.ad.mapMarkerSelected_Unload].name, AutoDrive.mapMarker[vehicle.ad.mapMarkerSelected_Unload].id);
				vehicle.ad.wayPointsChanged = true;
				vehicle.ad.unloadSwitch = true;   
			end;
		else
			if AutoDrive.mapMarker[vehicle.ad.mapMarkerSelected] ~= nil then
				vehicle.ad.wayPoints = AutoDrive:FastShortestPath(AutoDrive.mapWayPoints, closest, AutoDrive.mapMarker[vehicle.ad.mapMarkerSelected].name, vehicle.ad.targetSelected);    
				vehicle.ad.wayPointsChanged = true;
			end;
		end;	
	end;

	
	vehicle.ad.driverOnTheWay = false;
	vehicle.ad.tryingToCallDriver = false;
end;

function AutoDrive:stopAD(vehicle)
    vehicle.ad.isStopping = true;
end;

function AutoDrive:stopVehicle(vehicle, dt)
    if math.abs(vehicle.lastSpeedReal) < 0.0015 then
        vehicle.ad.isStopping = false;
    end;
    
    if vehicle.ad.isStopping then
        AutoDrive:getVehicleToStop(vehicle, true, dt);
    else       
        AutoDrive:disableAutoDriveFunctions(vehicle);
    end;
end;

function AutoDrive:disableAutoDriveFunctions(vehicle) 
	--print("Disabling vehicle .. " .. vehicle.name);
	vehicle.ad.currentWayPoint = 0;
	vehicle.ad.drivingForward = true;
	vehicle.ad.isActive = false;
	vehicle.ad.isPaused = false;

	vehicle.spec_aiVehicle.isActive = false;
	vehicle.ad.isUnloading = false;
	vehicle.ad.isLoading = false;

	vehicle.forceIsActive = false;
	vehicle.spec_motorized.stopMotorOnLeave = true;
	vehicle.spec_enterable.disableCharacterOnLeave = true;
	vehicle.currentHelper = nil

	if vehicle.restoreVehicleCharacter ~= nil then
		vehicle:restoreVehicleCharacter()
	end;

	vehicle.ad.initialized = false;
	vehicle.ad.lastSpeed = 10;
	if vehicle.steeringEnabled == false then
		vehicle.steeringEnabled = true;
	end

	vehicle:setCruiseControlState(Drivable.CRUISECONTROL_STATE_OFF);
	AIVehicleUtil.driveInDirection(vehicle, 16, 30, 0, 0.2, 20, false, vehicle.ad.drivingForward, 0, 0, 0, 1);

	--tell clients to dismiss ai worker etc.
	if g_server ~= nil then
		vehicle.ad.disableAI = 5;
	end;

	vehicle.ad.combineState = AutoDrive.COMBINE_UNINITIALIZED;
	
	if vehicle.ad.currentCombine ~= nil then
		vehicle.ad.currentCombine.ad.currentDriver = nil;
		vehicle.ad.currentCombine = nil;
	end;
	
	vehicle.ad.combineUnloadInFruit = false;
	vehicle.ad.combineUnloadInFruitWaitTimer = AutoDrive.UNLOAD_WAIT_TIMER;
	
	vehicle.ad.combineFieldArea = nil;
	vehicle.ad.combineFruitToCheck = nil; 

	AutoDrive.waitingUnloadDrivers[vehicle] = nil;

	vehicle:requestActionEventUpdate();
end

function AutoDrive:getVehicleToStop(vehicle, brake, dt)
	local finalSpeed = 0;
	local acc = -1;
	local allowedToDrive = false;
	
	if brake == true or math.abs(vehicle.lastSpeedReal) > 0.002 then
		finalSpeed = 0.01;
		acc = -0.6;
		allowedToDrive = true;
	end;

    local node = vehicle.components[1].node;					
    if vehicle.getAIVehicleDirectionNode ~= nil then
        node = vehicle:getAIVehicleDirectionNode();
    end;
    local x,y,z = getWorldTranslation(vehicle.components[1].node);   
	local rx,ry,rz = localDirectionToWorld(vehicle.components[1].node, 0,0,1);	
	x = x + rx;
	z = z + rz;
	local lx, lz = AIVehicleUtil.getDriveDirection(vehicle.components[1].node, x, y, z);
    AIVehicleUtil.driveInDirection(vehicle, dt, 30, acc, 0.2, 20, allowedToDrive, vehicle.ad.drivingForward, lx, lz, finalSpeed, 1);
end;

function AutoDrive:isActive(vehicle)
    if vehicle ~= nil then
        return vehicle.ad.isActive;
    end;
    return false;
end;

function AutoDrive:handleClientIntegrity(vehicle)
	if g_server ~= nil then
		vehicle.ad.enableAI = math.max(vehicle.ad.enableAI-1,0);
		vehicle.ad.disableAI = math.max(vehicle.ad.disableAI-1,0);
	else
		if vehicle.ad.enableAI > 0 then
			AutoDrive:startAD(vehicle);
		end;
		if vehicle.ad.disableAI > 0 then
			AutoDrive:disableAutoDriveFunctions(vehicle)
		end;
	end;
end;

function AutoDrive:detectAdTrafficOnRoute(vehicle)
	if vehicle.ad.isActive == true then
		if vehicle.ad.combineState == AutoDrive.DRIVE_TO_COMBINE or vehicle.ad.combineState == AutoDrive.DRIVE_TO_PARK_POS or vehicle.ad.combineState == AutoDrive.DRIVE_TO_START_POS and vehicle.ad.mode == AutoDrive.MODE_UNLOAD then
			return false;
		end;

		local idToCheck = 3;
		local alreadyOnDualRoute = false;
		if vehicle.ad.wayPoints[vehicle.ad.currentWayPoint-1] ~= nil and vehicle.ad.wayPoints[vehicle.ad.currentWayPoint] ~= nil then
			alreadyOnDualRoute = AutoDrive:isDualRoad(vehicle.ad.wayPoints[vehicle.ad.currentWayPoint-1], vehicle.ad.wayPoints[vehicle.ad.currentWayPoint]);
        end;
		
		if vehicle.ad.wayPoints[vehicle.ad.currentWayPoint+idToCheck] ~= nil and vehicle.ad.wayPoints[vehicle.ad.currentWayPoint+idToCheck+1] ~= nil and not alreadyOnDualRoute then
			local dualRoute = AutoDrive:isDualRoad(vehicle.ad.wayPoints[vehicle.ad.currentWayPoint+idToCheck], vehicle.ad.wayPoints[vehicle.ad.currentWayPoint+idToCheck+1]);
			
			local dualRoutePoints = {};
			local counter = 0;
			idToCheck = -3;
            while (dualRoute == true) or (idToCheck < 5) do
                local startNode = vehicle.ad.wayPoints[vehicle.ad.currentWayPoint+idToCheck];
                local targetNode = vehicle.ad.wayPoints[vehicle.ad.currentWayPoint+idToCheck+1];
				if (startNode ~= nil) and (targetNode ~= nil) then
                    local testDual = AutoDrive:isDualRoad(startNode, targetNode)					
					if testDual == true then
						counter = counter + 1;
						dualRoutePoints[counter] = startNode.id;
						dualRoute = true;
					else
						dualRoute = false;
					end;
				else
					dualRoute = false;
				end;
				idToCheck = idToCheck + 1;
			end;

			local trafficDetected = false;
			vehicle.ad.trafficVehicle = nil;
			if counter > 0 then
				for _,other in pairs(g_currentMission.vehicles) do
					if other ~= vehicle and other.ad ~= nil and other.ad.isActive == true then
						local onSameRoute = false;
						local window = 4;
						local i = -window;
						while i <= window do
							if other.ad.wayPoints[other.ad.currentWayPoint+i] ~= nil then
								for _,point in pairs(dualRoutePoints) do
									if point == other.ad.wayPoints[other.ad.currentWayPoint+i].id then
										onSameRoute = true;
									end;
								end;
							end;
							i = i + 1;
						end;

						if onSameRoute == true and other.ad.trafficVehicle == nil then
							trafficDetected = true;
							vehicle.ad.trafficVehicle = other;
						end;
					end;
				end;
			end;

			if trafficDetected == true then
				--print("Traffic on same road deteced");
				return true;
			end;

		end;

	end;
	return false;

end

function AutoDrive:detectTraffic(vehicle)
	local x,y,z = getWorldTranslation( vehicle.components[1].node );
	--create bounding box to check for vehicle
	local rx,ry,rz = localDirectionToWorld(vehicle.components[1].node, math.sin(vehicle.rotatedTime),0,math.cos(vehicle.rotatedTime));	
	local vehicleVector = {x= math.sin(rx) ,z= math.sin(rz)};
	local width = vehicle.sizeWidth;
	local length = vehicle.sizeLength;
	local ortho = { x=-vehicleVector.z, z=vehicleVector.x };
	local lookAheadDistance = math.min(vehicle.lastSpeedReal*3600/40, 1) * 10 + 2;
	local boundingBox = {};
    boundingBox[1] ={ 	x = x + (width/2) * ortho.x,
                        y = y+2,
						z = z + (width/2) * ortho.z};
	boundingBox[2] ={ 	x = x - (width/2) * ortho.x,
                        y = y+2,
						z = z - (width/2) * ortho.z};
	boundingBox[3] ={ 	x = x - (width/2) * ortho.x +  (length/2 + lookAheadDistance) * vehicleVector.x,
                        y = y+2,
						z = z - (width/2) * ortho.z +  (length/2 + lookAheadDistance) * vehicleVector.z };
	boundingBox[4] ={ 	x = x + (width/2) * ortho.x +  (length/2 + lookAheadDistance) * vehicleVector.x,
                        y = y+2,
						z = z + (width/2) * ortho.z +  (length/2 + lookAheadDistance) * vehicleVector.z};


	--local box = {};
	--box.center = {};
	--box.size = {};
	--box.center[1] = 0;
	--box.center[2] = 3;
	--box.center[3] = length;
	--box.size[1] = width/2;
	--box.size[2] = 1.5;
	--box.size[3] = lookAheadDistance/2;
	--box.x, box.y, box.z = localToWorld(vehicle.components[1].node, box.center[1], box.center[2], box.center[3])
	--box.zx, box.zy, box.zz = localDirectionToWorld(vehicle.components[1].node, math.sin(vehicle.rotatedTime),0,math.cos(vehicle.rotatedTime))
	--box.xx, box.xy, box.xz = localDirectionToWorld(vehicle.components[1].node, -math.cos(vehicle.rotatedTime),0,math.sin(vehicle.rotatedTime))
	--box.ry = math.atan2(box.zx, box.zz)
	--local boxCenter = { x = x + (((length/2 + (lookAheadDistance/2)) * vehicleVector.x)),
						--y = y+3,
						--z = z + (((length/2 + (lookAheadDistance/2)) * vehicleVector.z)) };

	--local shapes = overlapBox(boxCenter.x,boxCenter.y,boxCenter.z, 0,box.ry,0, box.size[1],box.size[2],box.size[3], "collisionTestCallback", nil, AIVehicleUtil.COLLISION_MASK, true, true, true)
	--local red = 0;
	--if shapes > 0 then
		--red = 1;
	--end;
	--DebugUtil.drawOverlapBox(boxCenter.x,boxCenter.y,boxCenter.z, 0,box.ry,0, box.size[1],box.size[2],box.size[3], red, 0, 0);

	--if shapes > 0 then
		--return true;
	--end;

    --AutoDrive:drawLine(boundingBox[1], boundingBox[2], 0, 0, 0, 1);
    --AutoDrive:drawLine(boundingBox[2], boundingBox[3], 0, 0, 0, 1);
    --AutoDrive:drawLine(boundingBox[3], boundingBox[4], 0, 0, 0, 1);
    --AutoDrive:drawLine(boundingBox[4], boundingBox[1], 0, 0, 0, 1);	

	for _,other in pairs(g_currentMission.vehicles) do --pairs(g_currentMission.nodeToVehicle) do
		if other ~= vehicle and other ~= vehicle.ad.currentCombine then
			local isAttachedToMe = AutoDrive:checkIsConnected(vehicle, other);		
			local isAttachedToMyCombine = AutoDrive:checkIsConnected(vehicle.ad.currentCombine, other) and (vehicle.ad.combineState == AutoDrive.DRIVE_TO_COMBINE);		
            
			if isAttachedToMe == false and other.components ~= nil and isAttachedToMyCombine == false then
				if other.sizeWidth == nil then
					--print("vehicle " .. other.configFileName .. " has no width");
				else
					if other.sizeLength == nil then
						--print("vehicle " .. other.configFileName .. " has no length");
					else
						if other.rootNode == nil then
							--print("vehicle " .. other.configFileName .. " has no root node");
						else

							local otherWidth = other.sizeWidth;
							local otherLength = other.sizeLength;
							local otherPos = {};
							otherPos.x,otherPos.y,otherPos.z = getWorldTranslation( other.components[1].node ); 

							local distance = AutoDrive:getDistance(x,z,otherPos.x,otherPos.z);
							if distance < 100 then
								local rx,ry,rz = localDirectionToWorld(other.components[1].node, 0, 0, 1);

								local otherVectorToWp = {};
								otherVectorToWp.x = rx;
								otherVectorToWp.z = rz;

								local otherPos2 = {};
								otherPos2.x = otherPos.x + (otherLength/2) * (otherVectorToWp.x/(math.abs(otherVectorToWp.x)+math.abs(otherVectorToWp.z)));
								otherPos2.y = y;
								otherPos2.z = otherPos.z + (otherLength/2) * (otherVectorToWp.z/(math.abs(otherVectorToWp.x)+math.abs(otherVectorToWp.z)));
								local otherOrtho = { x=-otherVectorToWp.z, z=otherVectorToWp.x };

								local otherBoundingBox = {};
								otherBoundingBox[1] ={ 	x = otherPos.x + (otherWidth/2) * ( otherOrtho.x / (math.abs(otherOrtho.x)+math.abs(otherOrtho.z))) + (otherLength/2) * (otherVectorToWp.x/(math.abs(otherVectorToWp.x)+math.abs(otherVectorToWp.z))),
														y = y,
														z = otherPos.z + (otherWidth/2) * ( otherOrtho.z / (math.abs(otherOrtho.x)+math.abs(otherOrtho.z))) + (otherLength/2) * (otherVectorToWp.z/(math.abs(otherVectorToWp.x)+math.abs(otherVectorToWp.z)))};

								otherBoundingBox[2] ={ 	x = otherPos.x - (otherWidth/2) * ( otherOrtho.x / (math.abs(otherOrtho.x)+math.abs(otherOrtho.z))) + (otherLength/2) * (otherVectorToWp.x/(math.abs(otherVectorToWp.x)+math.abs(otherVectorToWp.z))),
														y = y,
														z = otherPos.z - (otherWidth/2) * ( otherOrtho.z / (math.abs(otherOrtho.x)+math.abs(otherOrtho.z))) + (otherLength/2) * (otherVectorToWp.z/(math.abs(otherVectorToWp.x)+math.abs(otherVectorToWp.z)))};
								otherBoundingBox[3] ={ 	x = otherPos.x - (otherWidth/2) * ( otherOrtho.x / (math.abs(otherOrtho.x)+math.abs(otherOrtho.z))) - (otherLength/2) * (otherVectorToWp.x/(math.abs(otherVectorToWp.x)+math.abs(otherVectorToWp.z))),
														y = y,
														z = otherPos.z - (otherWidth/2) * ( otherOrtho.z / (math.abs(otherOrtho.x)+math.abs(otherOrtho.z))) - (otherLength/2) * (otherVectorToWp.z/(math.abs(otherVectorToWp.x)+math.abs(otherVectorToWp.z)))};

								otherBoundingBox[4] ={ 	x = otherPos.x + (otherWidth/2) * ( otherOrtho.x / (math.abs(otherOrtho.x)+math.abs(otherOrtho.z))) - (otherLength/2) * (otherVectorToWp.x/(math.abs(otherVectorToWp.x)+math.abs(otherVectorToWp.z))),
														y = y,
														z = otherPos.z + (otherWidth/2) * ( otherOrtho.z / (math.abs(otherOrtho.x)+math.abs(otherOrtho.z))) - (otherLength/2) * (otherVectorToWp.z/(math.abs(otherVectorToWp.x)+math.abs(otherVectorToWp.z)))};

								
								--AutoDrive:drawLine(otherBoundingBox[1], otherBoundingBox[2], 0, 0, 1, 1);
								--AutoDrive:drawLine(otherBoundingBox[2], otherBoundingBox[3], 0, 0, 1, 1);
								--AutoDrive:drawLine(otherBoundingBox[3], otherBoundingBox[4], 0, 0, 1, 1);
								--AutoDrive:drawLine(otherBoundingBox[4], otherBoundingBox[1], 0, 0, 1, 1);							

								if AutoDrive:BoxesIntersect(boundingBox, otherBoundingBox) == true then
									return true;
								end;
							end;
						end;
					end;
				end;
			end;
		end;
	end;

	return false;
end

function AutoDrive:checkIsConnected(toCheck, other)
	local isAttachedToMe = false;
	if toCheck == nil or other == nil then
		return false;
	end;
	if toCheck.getAttachedImplements == nil then
		return false;
	end;

	for _i,impl in pairs(toCheck:getAttachedImplements()) do
		if impl.object ~= nil then
			if impl.object == other then  
				return true;
			end;
			
			if impl.object.getAttachedImplements ~= nil then
				isAttachedToMe = isAttachedToMe or AutoDrive:checkIsConnected(impl.object, other)
			end;
		end;
	end;

	return isAttachedToMe;
end;