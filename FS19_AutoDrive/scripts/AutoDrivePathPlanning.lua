AutoDrive.PP_UP = 0;
AutoDrive.PP_UP_RIGHT = 1;
AutoDrive.PP_RIGHT = 2;
AutoDrive.PP_DOWN_RIGHT = 3;
AutoDrive.PP_DOWN = 4;
AutoDrive.PP_DOWN_LEFT = 5;
AutoDrive.PP_LEFT = 6;
AutoDrive.PP_UP_LEFT = 7;

AutoDrive.PP_MIN_DISTANCE = 14;
AutoDrive.PP_CELL_X = 8;
AutoDrive.PP_CELL_Z = 8;
AutoDrive.PP_MAX_STEPS = 300;

function AutoDrive:startPathPlanningToCombine(driver, combine, dischargeNode)
	driver.ad.pp = {};
	driver.ad.pp.isFinished = false;
	driver.ad.pp.grid = {};

	local nodeX,nodeY,nodeZ = getWorldTranslation(dischargeNode);

	local worldX,worldY,worldZ = getWorldTranslation( combine.components[1].node );
	local rx,ry,rz = localDirectionToWorld(combine.components[1].node, math.sin(combine.rotatedTime),0,math.cos(combine.rotatedTime));	
	driver.ad.pp.combineVector = {x= math.sin(rx) ,z= math.sin(rz)};

	local driverWorldX,driverWorldY,driverWorldZ = getWorldTranslation( driver.components[1].node );
	local driverRx,driverRy,driverRz = localDirectionToWorld(driver.components[1].node, math.sin(driver.rotatedTime),0,math.cos(driver.rotatedTime));	
	driver.ad.pp.driverVector = {x= math.sin(driverRx) ,z= math.sin(driverRz)};	
	driver.ad.pp.targetX = driverWorldX + 12*driverRx;
	driver.ad.pp.targetZ = driverWorldZ + 12*driverRz;

	driver.ad.pp.wpAhead = {x= (nodeX + 8*rx), y = worldY, z = nodeZ + 8*rz };
	driver.ad.pp.wpBehind = {x= (nodeX - 7*rx), y = worldY, z = nodeZ - 7*rz };
	driver.ad.pp.wpCurrent = {x= (nodeX), y = worldY, z = nodeZ };
	
	driver.ad.pp.startX = driver.ad.pp.wpBehind.x;
	driver.ad.pp.startZ =  driver.ad.pp.wpBehind.z;	

	driver.ad.pp.currentX = 0;
	driver.ad.pp.currentZ = 0;

	driver.ad.pp.lastX = -1;
	driver.ad.pp.lastZ = 0;

	driver.ad.pp.lastDirection = AutoDrive.PP_UP;

	local angleDriver = math.atan2(-driver.ad.pp.combineVector.z, -driver.ad.pp.combineVector.x); --Reversed combine angle to show in the direction of the node search
	angleDriver = normalizeAngle(angleDriver);

	driver.ad.pp.atan = angleDriver;
	
	local sin = math.sin(driver.ad.pp.atan);
	local cos = math.cos(driver.ad.pp.atan);

	driver.ad.pp.vectorX = {};
	driver.ad.pp.vectorX.x = cos * AutoDrive.PP_CELL_X;
	driver.ad.pp.vectorX.z = sin * AutoDrive.PP_CELL_X;

	driver.ad.pp.vectorZ = {};
	driver.ad.pp.vectorZ.x = -sin * AutoDrive.PP_CELL_Z;
	driver.ad.pp.vectorZ.z = cos * AutoDrive.PP_CELL_Z;

	driver.ad.pp.chain = {};
	driver.ad.pp.chain[1] = {x= driver.ad.pp.currentX, z = driver.ad.pp.currentZ};
	driver.ad.pp.chainIndex = 1;
	driver.ad.pp.waitForRequest = false;

	driver.ad.pp.reverseChain = true;

	driver.ad.pp.appendWayPoints = {};
	driver.ad.pp.appendWayPoints[1] = driver.ad.pp.wpCurrent;
	driver.ad.pp.appendWayPoints[2] = driver.ad.pp.wpAhead;
	driver.ad.pp.appendWayPointCount = 2;

	
	driver.ad.pp.fallBackMode = false; --Ignore fruits when this is true
	driver.ad.pp.steps = 0;

	driver.ad.pp.fruitToCheck = 0;

	local driverGrid = AutoDrive:worldLocationToGridLocation(driver, driverWorldX, driverWorldZ)
	local driverDirection = AutoDrive:worldDirectionToGridDirection(driver, driver.ad.pp.driverVector)
	AutoDrive:determineBlockedCells(driver, driverDirection, driverGrid.x, driverGrid.z);

	AutoDrive:createGridLocation(driver, 0, 0);
	AutoDrive:setGridLocationRestricted(driver, 0, 0, true)
	AutoDrive:createGridLocation(driver, -1, 0);
	AutoDrive:setGridLocationRestricted(driver, -1, 0, false)
	
	--restrict combine area for pp
	AutoDrive:createGridLocation(driver, 1, -1);
	AutoDrive:setGridLocationRestricted(driver, 1, -1, true);
	AutoDrive:createGridLocation(driver, 0, -1);
	AutoDrive:setGridLocationRestricted(driver, 0, -1, true);
	AutoDrive:createGridLocation(driver, -1, -1);
	AutoDrive:setGridLocationRestricted(driver, -1, -1, true);
	AutoDrive:createGridLocation(driver, -2, -1);
	AutoDrive:setGridLocationRestricted(driver, -2, -1, true);
	
	AutoDrive:createGridLocation(driver, 1, -2);
	AutoDrive:setGridLocationRestricted(driver, 1, -2, true);
	AutoDrive:createGridLocation(driver, 0, -2);
	AutoDrive:setGridLocationRestricted(driver, 0, -2, true);
	AutoDrive:createGridLocation(driver, -1, -2);
	AutoDrive:setGridLocationRestricted(driver, -1, -2, true);
	AutoDrive:createGridLocation(driver, -2, -2);
	AutoDrive:setGridLocationRestricted(driver, -2, -2, true);

	--restrict combine header area for pp
	AutoDrive:createGridLocation(driver, -2, -3);
	AutoDrive:setGridLocationRestricted(driver, -2, -3, true);
	AutoDrive:createGridLocation(driver, -2, 0);
	AutoDrive:setGridLocationRestricted(driver, -2, 0, true);
end;

function AutoDrive:startPathPlanningToStartPosition(driver)
	driver.ad.pp = {};
	driver.ad.pp.isFinished = false;
	driver.ad.pp.grid = {};

	local driverWorldX,driverWorldY,driverWorldZ = getWorldTranslation( driver.components[1].node );
	local driverRx,driverRy,driverRz = localDirectionToWorld(driver.components[1].node, math.sin(driver.rotatedTime),0,math.cos(driver.rotatedTime));	
	driver.ad.pp.driverVector = {x= math.sin(driverRx) ,z= math.sin(driverRz)};	
	driver.ad.pp.startX = driverWorldX;
	driver.ad.pp.startZ = driverWorldZ;

	local targetPoint = AutoDrive.mapWayPoints[AutoDrive.mapMarker[driver.ad.mapMarkerSelected].id]
	local preTargetPoint = AutoDrive.mapWayPoints[targetPoint.incoming[1]];
	local targetVector = {};
	targetVector.x = preTargetPoint.x - targetPoint.x
	targetVector.z = preTargetPoint.z - targetPoint.z

	local angleRad = math.atan2(targetVector.z, targetVector.x);

	angleRad = normalizeAngle(angleRad);

	local vectorLength = 14;

	driver.ad.pp.targetX = preTargetPoint.x + math.cos(angleRad) * vectorLength; --Make the target a few meters ahead of the road to the start point
	driver.ad.pp.targetZ = preTargetPoint.z + math.sin(angleRad) * vectorLength;

	driver.ad.pp.currentX = 0;
	driver.ad.pp.currentZ = 0;

	driver.ad.pp.lastX = -1;
	driver.ad.pp.lastZ = 0;

	driver.ad.pp.lastDirection = AutoDrive.PP_UP;

	local angleDriver = math.atan2(driver.ad.pp.driverVector.z, driver.ad.pp.driverVector.x);
	angleDriver = normalizeAngle(angleDriver);

	driver.ad.pp.atan = angleDriver;
	
	local sin = math.sin(driver.ad.pp.atan);
	local cos = math.cos(driver.ad.pp.atan);

	driver.ad.pp.vectorX = {};
	driver.ad.pp.vectorX.x = cos * AutoDrive.PP_CELL_X;
	driver.ad.pp.vectorX.z = sin * AutoDrive.PP_CELL_X;

	driver.ad.pp.vectorZ = {};
	driver.ad.pp.vectorZ.x = -sin * AutoDrive.PP_CELL_Z;
	driver.ad.pp.vectorZ.z = cos * AutoDrive.PP_CELL_Z;

	driver.ad.pp.chain = {};
	driver.ad.pp.chain[1] = {x= driver.ad.pp.currentX, z = driver.ad.pp.currentZ};
	driver.ad.pp.chainIndex = 1;
	driver.ad.pp.waitForRequest = false;

	driver.ad.pp.reverseChain = false;
	driver.ad.pp.appendWayPoints = {};
	driver.ad.pp.appendWayPoints[1] = preTargetPoint;
	driver.ad.pp.appendWayPoints[2] = targetPoint;
	driver.ad.pp.appendWayPointCount = 2;

	driver.ad.pp.fallBackMode = false; --Ignore fruits when this is true
	driver.ad.pp.steps = 0;

	driver.ad.pp.fruitToCheck = 0;

	AutoDrive:createGridLocation(driver, 0, 0);
	AutoDrive:setGridLocationRestricted(driver, 0, 0, false)

	local endVector = { x = preTargetPoint.x - targetPoint.x, z = preTargetPoint.z - targetPoint.z };
	local driverGrid = AutoDrive:worldLocationToGridLocation(driver, targetPoint.x, targetPoint.z)
	local driverDirection = AutoDrive:worldDirectionToGridDirection(driver, endVector)
	AutoDrive:determineBlockedCells(driver, driverDirection, driverGrid.x, driverGrid.z);
end;

function AutoDrive:updatePathPlanning(driver)
	AutoDrive:drawDebugForPP(driver);

	if driver.ad.pp == nil then
		return;
	end;

	if driver.ad.pp.isFinished then
		return;
	end;

	local pp = driver.ad.pp;

	--look for next best grid point
	if pp.waitForRequest == false then
		AutoDrive:makeRequest(driver);
	else
		local requestDone = true;
		for index, testLocation in pairs(pp.testGrid) do
			requestDone = requestDone and pp.grid[testLocation.x][testLocation.z].hasInfo; 
		end;

		if requestDone == false then
			return;
		end;

		pp.steps = pp.steps + 1;
		if pp.steps > AutoDrive.PP_MAX_STEPS then
			print("Error in pathfinding. Could not find a route in the correct time - AutoDrive shuts down");
			pp.isFinished = true;
			pp.wayPoints = {};
		end;
				
		pp.bestIndex = 0;
		local nextBestIndex = 0;
		local bestDistance = math.huge;
		local nextBestDistance = math.huge;
		for index, testLocation in pairs(pp.testGrid) do
			if pp.grid[testLocation.x][testLocation.z].isRestricted == false or pp.fallBackMode == true then
				local worldPos = AutoDrive:gridLocationToWorldLocation(driver, testLocation.x, testLocation.z);
				local distance = math.sqrt(math.pow((worldPos.x - pp.targetX) , 2) + math.pow((worldPos.z - pp.targetZ) , 2));

				if distance < bestDistance then
					bestDistance = distance;
					pp.bestIndex = index;
				end;

				if nextBestIndex == 0 and pp.bestIndex ~= 0 and pp.bestIndex ~= index and distance < nextBestDistance then
					nextBestDistance = distance;
					nextBestIndex = index;
				end;
			end;
		end;

		AutoDrive:checkForStraightLineAway(driver, pp.bestIndex, nextBestIndex);
		AutoDrive:checkForSnakeSyndrom(driver, pp.bestIndex);

		if pp.bestIndex == 0 then
			--we have to trace back our greedy algorithm
			AutoDrive:stepBackPPAlgorithm(driver);
		else
			AutoDrive:stepForwardPPAlgorithm(driver, pp.bestIndex);
		end;
	end;
end;

function AutoDrive:isPathPlanningFinished(driver)
	if driver.ad.pp ~= nil then
		if driver.ad.pp.isFinished == true then
			return true;
		end;
	end;
	return false;
end;

function AutoDrive:makeRequest(driver)
	local pp = driver.ad.pp;
	
	AutoDrive:determineTestGridLocations(driver);
	pp.waitForRequest = true;	
end;

function AutoDrive:determineTestGridLocations(driver)
	local pp = driver.ad.pp;

	pp.testGrid = {};
	if pp.lastDirection == AutoDrive.PP_UP then
		pp.testGrid[1] = {x=pp.currentX + 1, z=pp.currentZ - 1};
		pp.testGrid[1].direction = AutoDrive.PP_UP_LEFT;
		pp.testGrid[2] = {x=pp.currentX + 1, z=pp.currentZ + 0};
		pp.testGrid[2].direction = AutoDrive.PP_UP;
		pp.testGrid[3] = {x=pp.currentX + 1, z=pp.currentZ + 1};
		pp.testGrid[3].direction = AutoDrive.PP_UP_RIGHT;
	elseif pp.lastDirection == AutoDrive.PP_UP_RIGHT then
		pp.testGrid[1] = {x=pp.currentX + 1, z=pp.currentZ + 0};
		pp.testGrid[1].direction = AutoDrive.PP_UP;
		pp.testGrid[2] = {x=pp.currentX + 1, z=pp.currentZ + 1};
		pp.testGrid[2].direction = AutoDrive.PP_UP_RIGHT;
		pp.testGrid[3] = {x=pp.currentX + 0, z=pp.currentZ + 1};
		pp.testGrid[3].direction = AutoDrive.PP_RIGHT;
	elseif pp.lastDirection == AutoDrive.PP_RIGHT then
		pp.testGrid[1] = {x=pp.currentX + 1, z=pp.currentZ + 1};
		pp.testGrid[1].direction = AutoDrive.PP_UP_RIGHT;
		pp.testGrid[2] = {x=pp.currentX + 0, z=pp.currentZ + 1};
		pp.testGrid[2].direction = AutoDrive.PP_RIGHT;
		pp.testGrid[3] = {x=pp.currentX - 1, z=pp.currentZ + 1};
		pp.testGrid[3].direction = AutoDrive.PP_DOWN_RIGHT;
	elseif pp.lastDirection == AutoDrive.PP_DOWN_RIGHT then
		pp.testGrid[1] = {x=pp.currentX + 0, z=pp.currentZ + 1};
		pp.testGrid[1].direction = AutoDrive.PP_RIGHT;
		pp.testGrid[2] = {x=pp.currentX - 1, z=pp.currentZ + 1};
		pp.testGrid[2].direction = AutoDrive.PP_DOWN_RIGHT;
		pp.testGrid[3] = {x=pp.currentX - 1, z=pp.currentZ + 0};
		pp.testGrid[3].direction = AutoDrive.PP_DOWN;
	elseif pp.lastDirection == AutoDrive.PP_DOWN then
		pp.testGrid[1] = {x=pp.currentX - 1, z=pp.currentZ + 1};
		pp.testGrid[1].direction = AutoDrive.PP_DOWN_RIGHT;
		pp.testGrid[2] = {x=pp.currentX - 1, z=pp.currentZ + 0};
		pp.testGrid[2].direction = AutoDrive.PP_DOWN;
		pp.testGrid[3] = {x=pp.currentX - 1, z=pp.currentZ - 1};
		pp.testGrid[3].direction = AutoDrive.PP_DOWN_LEFT;
	elseif pp.lastDirection == AutoDrive.PP_DOWN_LEFT then
		pp.testGrid[1] = {x=pp.currentX - 1, z=pp.currentZ - 0};
		pp.testGrid[1].direction = AutoDrive.PP_DOWN;
		pp.testGrid[2] = {x=pp.currentX - 1, z=pp.currentZ - 1};
		pp.testGrid[2].direction = AutoDrive.PP_DOWN_LEFT;
		pp.testGrid[3] = {x=pp.currentX - 0, z=pp.currentZ - 1};
		pp.testGrid[3].direction = AutoDrive.PP_LEFT;
	elseif pp.lastDirection == AutoDrive.PP_LEFT then
		pp.testGrid[1] = {x=pp.currentX - 1, z=pp.currentZ - 1};
		pp.testGrid[1].direction = AutoDrive.PP_DOWN_LEFT;
		pp.testGrid[2] = {x=pp.currentX - 0, z=pp.currentZ - 1};
		pp.testGrid[2].direction = AutoDrive.PP_LEFT;
		pp.testGrid[3] = {x=pp.currentX + 1, z=pp.currentZ - 1};
		pp.testGrid[3].direction = AutoDrive.PP_UP_LEFT;
	elseif pp.lastDirection == AutoDrive.PP_UP_LEFT then
		pp.testGrid[1] = {x=pp.currentX - 0, z=pp.currentZ - 1};
		pp.testGrid[1].direction = AutoDrive.PP_LEFT;
		pp.testGrid[2] = {x=pp.currentX + 1, z=pp.currentZ - 1};
		pp.testGrid[2].direction = AutoDrive.PP_UP_LEFT;
		pp.testGrid[3] = {x=pp.currentX + 1, z=pp.currentZ + 0};
		pp.testGrid[3].direction = AutoDrive.PP_UP;
	end;

	for _,testLocation in pairs(pp.testGrid) do
		local createPoint = true;
		if pp.grid[testLocation.x] ~= nil then
			if pp.grid[testLocation.x][testLocation.z] ~= nil then
				createPoint = false;
			end;
		end;

		if createPoint then			
			AutoDrive:createGridLocation(driver, testLocation.x, testLocation.z);	
			AutoDrive:calculateBoundingBoxForGrid(driver, testLocation.x, testLocation.z);
		end;
	end;
end;

function AutoDrive:createGridLocation(driver, x, z)	
	local pp = driver.ad.pp;

	if pp.grid[x] == nil then
		pp.grid[x] = {};
	end;
	if pp.grid[x][z] == nil then
		pp.grid[x][z] = {};
		pp.grid[x][z].isFruitFree = false; -- should be false when making actual FieldInfo Request
		pp.grid[x][z].hasInfo = false; -- should be false when making actual FieldInfo Request	
		pp.grid[x][z].isRestricted = false;
		pp.grid[x][z].hasRequested = false;
		return true;
	end;
	return false;
end;

function AutoDrive:setGridLocationRestricted(driver, x, z, restricted)
	local pp = driver.ad.pp;
	if pp.grid[x] ~= nil then
		if pp.grid[x][z] ~= nil then
			pp.grid[x][z].hasInfo = true;
			pp.grid[x][z].isFruitFree = not restricted;
			pp.grid[x][z].isRestricted = restricted;
			pp.grid[x][z].hasRequested = true;
		end;
	end;
end;

function AutoDrive:gridLocationToWorldLocation(driver, x, z)
	local pp = driver.ad.pp;
	local result = {x= 0, z=0};

	result.x = pp.startX + x * pp.vectorX.x + z * pp.vectorZ.x;
	result.z = pp.startZ + x * pp.vectorX.z + z * pp.vectorZ.z;

	return result;
end;

function AutoDrive:worldLocationToGridLocation(driver, worldX, worldZ)
	local pp = driver.ad.pp;
	local result = {x= 0, z=0};

	result.z = (((worldX - pp.startX) / pp.vectorX.x) * pp.vectorX.z -worldZ + pp.startZ) / (((pp.vectorZ.x / pp.vectorX.x) * pp.vectorX.z) - pp.vectorZ.z);
	result.x = (worldZ - pp.startZ - result.z * pp.vectorZ.z) / pp.vectorX.z;

	result.x = AutoDrive:round(result.x);
	result.z = AutoDrive:round(result.z);

	return result;
end;

function AutoDrive:worldDirectionToGridDirection(driver, vector)
	local pp = driver.ad.pp;

	local vecUp = {x = pp.vectorX.x + pp.vectorZ.x, z = pp.vectorX.z + pp.vectorZ.z};

	local angleWorldDirection = math.atan2(vector.z, vector.x);
	angleWorldDirection = normalizeAngle2(angleWorldDirection);

	local angleRad = math.atan2(vecUp.z, vecUp.x);
	angleRad = normalizeAngle2(angleRad);

	local upRightAngle = normalizeAngle2(angleRad + math.rad(45));
	local rightAngle = normalizeAngle2(angleRad + math.rad(90));
	local downRightAngle = normalizeAngle2(angleRad + math.rad(135));
	local downAngle = normalizeAngle2(angleRad + math.rad(180));
	local downLeftAngle = normalizeAngle2(angleRad + math.rad(225));
	local leftAngle = normalizeAngle2(angleRad + math.rad(270));
	local upLeftAngle = normalizeAngle2(angleRad + math.rad(315));

	local direction = AutoDrive.PP_UP;

	if math.abs( math.deg( normalizeAngle2( angleWorldDirection - upRightAngle ) )) <= 22.5 then
		direction = AutoDrive.PP_UP_RIGHT;
	elseif math.abs( math.deg( normalizeAngle2( angleWorldDirection - rightAngle ) )) <= 22.5 then
		direction = AutoDrive.PP_RIGHT;
	elseif math.abs( math.deg( normalizeAngle2( angleWorldDirection - downRightAngle ) )) <= 22.5 then
		direction = AutoDrive.PP_DOWN_RIGHT;
	elseif math.abs( math.deg( normalizeAngle2( angleWorldDirection - downAngle ) )) <= 22.5 then
		direction = AutoDrive.PP_DOWN;
	elseif math.abs( math.deg( normalizeAngle2( angleWorldDirection - downLeftAngle ) )) <= 22.5 then
		direction = AutoDrive.PP_DOWN_LEFT;
	elseif math.abs( math.deg( normalizeAngle2( angleWorldDirection - leftAngle ) )) <= 22.5 then
		direction = AutoDrive.PP_LEFT;
	elseif math.abs( math.deg( normalizeAngle2( angleWorldDirection - upLeftAngle ) )) <= 22.5 then
		direction = AutoDrive.PP_UP_LEFT;
	end;

	return direction;
end;

function AutoDrive:determineBlockedCells(driver, endDirection, x, z)
	local pp = driver.ad.pp;

	--block cells which would result in bad angles to the end/start point
	--  xx
	--  x->
	--  xx
	if endDirection == AutoDrive.PP_UP then
		AutoDrive:createGridLocation(driver, x-1, z)
		AutoDrive:setGridLocationRestricted(driver, x-1, z, true)
		AutoDrive:createGridLocation(driver, x-1, z-1)
		AutoDrive:setGridLocationRestricted(driver, x-1, z-1, true)
		AutoDrive:createGridLocation(driver, x-1, z+1)
		AutoDrive:setGridLocationRestricted(driver, x-1, z+1, true)
		--AutoDrive:createGridLocation(driver, x, z-1)
		--AutoDrive:setGridLocationRestricted(driver, x, z-1, true)
		--AutoDrive:createGridLocation(driver, x, z+1)
		--AutoDrive:setGridLocationRestricted(driver, x, z+1, true)
	elseif endDirection == AutoDrive.PP_UP_RIGHT then
		AutoDrive:createGridLocation(driver, x-1, z)
		AutoDrive:setGridLocationRestricted(driver, x-1, z, true)
		AutoDrive:createGridLocation(driver, x-1, z-1)
		AutoDrive:setGridLocationRestricted(driver, x-1, z-1, true)
		--AutoDrive:createGridLocation(driver, x-1, z+1)
		--AutoDrive:setGridLocationRestricted(driver, x-1, z+1, true)
		AutoDrive:createGridLocation(driver, x, z-1)
		AutoDrive:setGridLocationRestricted(driver, x, z-1, true)
		--AutoDrive:createGridLocation(driver, x+1, z-1)
		--AutoDrive:setGridLocationRestricted(driver, x+1, z-1, true)
	elseif endDirection == AutoDrive.PP_RIGHT then
		--AutoDrive:createGridLocation(driver, x-1, z)
		--AutoDrive:setGridLocationRestricted(driver, x-1, z, true)
		AutoDrive:createGridLocation(driver, x-1, z-1)
		AutoDrive:setGridLocationRestricted(driver, x-1, z-1, true)
		AutoDrive:createGridLocation(driver, x+1, z)
		AutoDrive:setGridLocationRestricted(driver, x+1, z, true)
		AutoDrive:createGridLocation(driver, x+1, z-1)
		AutoDrive:setGridLocationRestricted(driver, x+1, z-1, true)
		--AutoDrive:createGridLocation(driver, x, z-1)
		--AutoDrive:setGridLocationRestricted(driver, x, z-1, true)
	elseif endDirection == AutoDrive.PP_DOWN_RIGHT then
		AutoDrive:createGridLocation(driver, x+1, z)
		AutoDrive:setGridLocationRestricted(driver, x+1, z, true)
		AutoDrive:createGridLocation(driver, x+1, z-1)
		AutoDrive:setGridLocationRestricted(driver, x+1, z-1, true)
		--AutoDrive:createGridLocation(driver, x+1, z+1)
		--AutoDrive:setGridLocationRestricted(driver, x+1, z+1, true)
		AutoDrive:createGridLocation(driver, x, z-1)
		AutoDrive:setGridLocationRestricted(driver, x, z-1, true)
		--AutoDrive:createGridLocation(driver, x-1, z-1)
		--AutoDrive:setGridLocationRestricted(driver, x-1, z-1, true)
	elseif endDirection == AutoDrive.PP_DOWN then
		AutoDrive:createGridLocation(driver, x+1, z)
		AutoDrive:setGridLocationRestricted(driver, x+1, z, true)
		AutoDrive:createGridLocation(driver, x+1, z-1)
		AutoDrive:setGridLocationRestricted(driver, x+1, z-1, true)
		AutoDrive:createGridLocation(driver, x+1, z+1)
		AutoDrive:setGridLocationRestricted(driver, x+1, z+1, true)
		--AutoDrive:createGridLocation(driver, x, z-1)
		--AutoDrive:setGridLocationRestricted(driver, x, z-1, true)
		--AutoDrive:createGridLocation(driver, x, z+1)
		--AutoDrive:setGridLocationRestricted(driver, x, z+1, true)
	elseif endDirection == AutoDrive.PP_DOWN_LEFT then
		AutoDrive:createGridLocation(driver, x+1, z)
		AutoDrive:setGridLocationRestricted(driver, x+1, z, true)
		--AutoDrive:createGridLocation(driver, x+1, z-1)
		--AutoDrive:setGridLocationRestricted(driver, x+1, z-1, true)
		AutoDrive:createGridLocation(driver, x+1, z+1)
		AutoDrive:setGridLocationRestricted(driver, x+1, z+1, true)
		AutoDrive:createGridLocation(driver, x, z+1)
		AutoDrive:setGridLocationRestricted(driver, x, z+1, true)
		--AutoDrive:createGridLocation(driver, x-1, z+1)
		--AutoDrive:setGridLocationRestricted(driver, x-1, z+1, true)
	elseif endDirection == AutoDrive.PP_LEFT then
		--AutoDrive:createGridLocation(driver, x-1, z)
		--AutoDrive:setGridLocationRestricted(driver, x-1, z, true)
		AutoDrive:createGridLocation(driver, x-1, z+1)
		AutoDrive:setGridLocationRestricted(driver, x-1, z+1, true)
		AutoDrive:createGridLocation(driver, x+1, z)
		--AutoDrive:setGridLocationRestricted(driver, x+1, z, true)
		--AutoDrive:createGridLocation(driver, x+1, z+1)
		AutoDrive:setGridLocationRestricted(driver, x+1, z+1, true)
		AutoDrive:createGridLocation(driver, x, z+1)
		AutoDrive:setGridLocationRestricted(driver, x, z+1, true)
	elseif endDirection == AutoDrive.PP_UP_LEFT then
		AutoDrive:createGridLocation(driver, x-1, z)
		AutoDrive:setGridLocationRestricted(driver, x-1, z, true)
		AutoDrive:createGridLocation(driver, x-1, z+1)
		AutoDrive:setGridLocationRestricted(driver, x-1, z+1, true)
		--AutoDrive:createGridLocation(driver, x-1, z-1)
		--AutoDrive:setGridLocationRestricted(driver, x-1, z-1, true)
		AutoDrive:createGridLocation(driver, x, z+1)
		AutoDrive:setGridLocationRestricted(driver, x, z+1, true)
		--AutoDrive:createGridLocation(driver, x+1, z+1)
		--AutoDrive:setGridLocationRestricted(driver, x+1, z+1, true)
	end;
end;

function AutoDrive:stepBackPPAlgorithm(driver)
	local pp = driver.ad.pp;

	pp.grid[pp.currentX][pp.currentZ].isRestricted = true;

	if pp.chain[pp.chainIndex-1] ~= nil then
		pp.currentX = pp.chain[pp.chainIndex-1].x;
		pp.currentZ = pp.chain[pp.chainIndex-1].z;
		pp.lastDirection = pp.chain[pp.chainIndex].lastDirection;
		pp.chain[pp.chainIndex] = nil;
		pp.chainIndex = pp.chainIndex-1;
		pp.waitForRequest = false;
		pp.steps = pp.steps - 1;
	else
		print("Error in pathfinding. Could not trace back any further - switching to fallback mode and ignoring fruit");
		--DebugUtil.printTableRecursively(pp.grid, "-", 0,2);
		--pp.isFinished = true;
		--pp.wayPoints = {};
		pp.fallBackMode = true;
		pp.steps = 0;
	end;
end;

function AutoDrive:getPPDirection(start, target)
	if start.x == target.x and start.z < target.z then
		return AutoDrive.PP_RIGHT;
	elseif start.x < target.x and start.z < target.z then
		return AutoDrive.PP_DOWN_RIGHT;
	elseif start.x < target.x and start.z == target.z then
		return AutoDrive.PP_DOWN;
	elseif start.x < target.x and start.z > target.z then
		return AutoDrive.PP_DOWN_LEFT;
	elseif start.x == target.x and start.z > target.z then
		return AutoDrive.PP_LEFT; 
	elseif start.x > target.x and start.z > target.z then
		return AutoDrive.PP_UP_LEFT;
	elseif start.x > target.x and start.z == target.z then
		return AutoDrive.PP_UP;
	elseif start.x > target.x and start.z < target.z then
		return AutoDrive.PP_UP_RIGHT;
	end;

	return AutoDrive.PP_UP;
end;

function AutoDrive:stepForwardPPAlgorithm(driver, bestIndex)
	local pp = driver.ad.pp;

	pp.chainIndex = pp.chainIndex + 1;
	pp.chain[pp.chainIndex] = {x = pp.testGrid[bestIndex].x, z = pp.testGrid[bestIndex].z, lastDirection = pp.lastDirection};

	pp.lastDirection = pp.testGrid[bestIndex].direction;

	pp.currentX = pp.testGrid[bestIndex].x;
	pp.currentZ = pp.testGrid[bestIndex].z;

	pp.waitForRequest = false;

	local worldPos = AutoDrive:gridLocationToWorldLocation(driver, pp.testGrid[bestIndex].x, pp.testGrid[bestIndex].z);
	local distance = math.sqrt(math.pow((worldPos.x - pp.targetX) , 2) + math.pow((worldPos.z - pp.targetZ) , 2));

	if distance < AutoDrive.PP_MIN_DISTANCE then
		pp.isFinished = true;
		AutoDrive:createWayPointsFromPPChain(driver);
	end;
end;

function AutoDrive:checkForSnakeSyndrom(driver, bestIndex)
	local pp = driver.ad.pp;

	if bestIndex == 0 then
		return;
	end;
	local bestPoint = {x = pp.testGrid[bestIndex].x, z = pp.testGrid[bestIndex].z, lastDirection = pp.lastDirection};

	for index,chainElement in pairs(pp.chain) do
		if chainElement.x == bestPoint.x and chainElement.z == bestPoint.z and chainElement.lastDirection == bestPoint.lastDirection then
			pp.grid[bestPoint.x][bestPoint.z].isRestricted = true;
			pp.bestPoint = 0;
			break;
		end;
	end;
end;

function AutoDrive:checkForStraightLineAway(driver, bestIndex, nextBestIndex)
	local pp = driver.ad.pp;

	if bestIndex == 0 then
		return;
	end;

	local hasRestrictedAreas = false;
	for index, testLocation in pairs(pp.testGrid) do
		if pp.grid[testLocation.x][testLocation.z].isRestricted == true and pp.fallBackMode == false then
			hasRestrictedAreas = true;
		end;
	end;
	
	if pp.lastDirection == pp.testGrid[bestIndex].direction and hasRestrictedAreas == false then
		local worldPosCurrent = AutoDrive:gridLocationToWorldLocation(driver, pp.currentX, pp.currentZ);
		local distanceCurrent = math.sqrt(math.pow((worldPosCurrent.x - pp.targetX) , 2) + math.pow((worldPosCurrent.z - pp.targetZ) , 2));
		local worldPosNew = AutoDrive:gridLocationToWorldLocation(driver, pp.testGrid[bestIndex].x, pp.testGrid[bestIndex].z);
		local distanceNew = math.sqrt(math.pow((worldPosNew.x - pp.targetX) , 2) + math.pow((worldPosNew.z - pp.targetZ) , 2));

		if distanceNew > distanceCurrent then
			pp.bestIndex = nextBestIndex;
		end;
	end;
end;

function AutoDrive:createWayPointsFromPPChain(driver)
	local pp = driver.ad.pp;

	pp.wayPoints = {};

	local index = 1
	if pp.prependWayPointCount ~= nil then
		for i=1, pp.prependWayPointCount, 1 do
			pp.wayPoints[i] = pp.prependWayPoints[i];
			index = index + 1;
		end;
	end;

	local originalIndex = pp.chainIndex;
	if driver.ad.pp.reverseChain == false then
		index = pp.chainIndex;
		if pp.prependWayPointCount ~= nil then
			index = index + pp.prependWayPointCount;			
		end;
	end;
	while pp.chainIndex > 0 do		
		--print("point: " .. pp.chainIndex .. ": " .. pp.chain[pp.chainIndex].x .. " / " .. pp.chain[pp.chainIndex].z)
		pp.wayPoints[index] = AutoDrive:gridLocationToWorldLocation(driver, pp.chain[pp.chainIndex].x, pp.chain[pp.chainIndex].z);
		pp.wayPoints[index].y = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, pp.wayPoints[index].x, 1, pp.wayPoints[index].z);
		pp.wayPoints[index].lastDirection = pp.chain[pp.chainIndex].lastDirection;
		pp.chainIndex = pp.chainIndex - 1;
		if driver.ad.pp.reverseChain == false then
			index = index - 1;
		else
			index = index + 1;
		end;		
	end;

	if pp.appendWayPointCount ~= nil then
		for i=1, pp.appendWayPointCount, 1 do
			pp.wayPoints[originalIndex+i] = pp.appendWayPoints[i];
		end;
	end;

	AutoDrive:smoothResultingPPPath(driver);
end;

function AutoDrive:calculateBoundingBoxForGrid(driver, x, z)
	local pp = driver.ad.pp;
	local worldPos = AutoDrive:gridLocationToWorldLocation(driver, x, z);

	local cornerX = worldPos.x - (pp.vectorX.x + pp.vectorZ.x)/2
	local cornerZ = worldPos.z - (pp.vectorX.z + pp.vectorZ.z)/2

	local corner2X = worldPos.x - (pp.vectorX.x + pp.vectorZ.x)/2
	local corner2Z = worldPos.z + (pp.vectorX.z + pp.vectorZ.z)/2

	local corner3X = worldPos.x + (pp.vectorX.x + pp.vectorZ.x)/2
	local corner3Z = worldPos.z - (pp.vectorX.z + pp.vectorZ.z)/2

	local corner4X = worldPos.x + (pp.vectorX.x + pp.vectorZ.x)/2
	local corner4Z = worldPos.z + (pp.vectorX.z + pp.vectorZ.z)/2

	if pp.grid[x][z].hasRequested == nil or pp.grid[x][z].hasRequested == false then
		if pp.fruitToCheck == 0 then 		
			local callBack = FieldDataCallback:new(driver, x, z);
			FSDensityMapUtil.getFieldStatusAsync(cornerX, cornerZ, corner2X, corner2Z, corner3X, corner3Z, callBack.onFieldDataUpdateFinished,  callBack);
			pp.grid[x][z].hasRequested = true;	
		else
			local fruitValue, _, _, _ = FSDensityMapUtil.getFruitArea(pp.fruitToCheck, cornerX, cornerZ, corner2X, corner2Z, corner3X, corner3Z, nil, false);
			if fruitValue < (0.3 * pp.fieldArea) then
				pp.grid[x][z].isFruitFree = true;
				pp.grid[x][z].isRestricted = false;
			else
				pp.grid[x][z].isFruitFree = false;
				pp.grid[x][z].isRestricted = true;
			end;

			--Allow fruit in the first few grid cells
			if pp.chainIndex < 3 then
				pp.grid[x][z].isRestricted = false;
				pp.grid[x][z].isFruitFree = true;
			end;
			pp.grid[x][z].hasInfo = true;
		end;
	end;
end;

function AutoDrive:onFieldDataUpdateFinished(driver, fielddata, x, z)
	driver.ad.pp.grid[x][z].fielddata = fielddata;
	local totalFruitPixels = 0;
	if fielddata ~= nil then
		local maxAmount = 0;
		local maxIndex = 0;
		for fruitIndex,fruitAmount in pairs(fielddata.fruitPixels) do
			if fruitIndex ~= 13 then --13 should be grass
				if fielddata.fruits[fruitIndex] > 2 and fielddata.fruits[fruitIndex] <  9 then
					totalFruitPixels = totalFruitPixels + fruitAmount;
					if fruitAmount > maxAmount then
						maxAmount = fruitAmount;
						maxIndex = fruitIndex;
					end;
				end;
			end;
		end;
		if totalFruitPixels < (0.3 * fielddata.fieldArea) then
			driver.ad.pp.grid[x][z].isFruitFree = true;
			driver.ad.pp.grid[x][z].isRestricted = false;
		else
			driver.ad.pp.grid[x][z].isFruitFree = false;
			driver.ad.pp.grid[x][z].isRestricted = true;
		end;
		driver.ad.pp.grid[x][z].fruitArea = totalFruitPixels;

		if maxIndex > 0 then
			driver.ad.pp.fruitToCheck = maxIndex;
			driver.ad.pp.fieldArea = fielddata.fieldArea;
		end;
	
		--Allow fruit in the first few grid cells
		if driver.ad.pp.chainIndex < 3 then
			driver.ad.pp.grid[x][z].isRestricted = false;
			driver.ad.pp.grid[x][z].isFruitFree = true;
		end;

		--DebugUtil.printTableRecursively(fielddata, "::" , 0, 2);
	else
		--Not on field == not restricted
		driver.ad.pp.grid[x][z].isFruitFree = true;
		driver.ad.pp.grid[x][z].isRestricted = false;
	end;
	

	driver.ad.pp.grid[x][z].hasInfo = true;
end;

function AutoDrive:smoothResultingPPPath(driver)
	local pp = driver.ad.pp;
	local index = 1;
	local filteredIndex = 1;
	local filteredWPs = {};

	--print("Waypoints: " .. ADTableLength(pp.wayPoints));

	while index < ADTableLength(pp.wayPoints) - 2 do
		local node = pp.wayPoints[index];
		local nodeAhead = pp.wayPoints[index+1];
		local nodeTwoAhead = pp.wayPoints[index+2];

		filteredWPs[filteredIndex] = node;
		filteredIndex = filteredIndex + 1;

		if node.lastDirection ~= nil and nodeAhead.lastDirection ~= nil and nodeTwoAhead.lastDirection ~= nil then
			if node.lastDirection == nodeTwoAhead.lastDirection and node.lastDirection ~= nodeAhead.lastDirection then
				--print("Skipping index: " .. (index+1));
				index = index + 1; --skip next point because it is a zig zag line. Cut right through instead
			end;
		else
			--print("Not all nodes have a direction set at index: " .. index);
		end;
		
		index = index + 1;
	end;
	
	while index <= ADTableLength(pp.wayPoints) do
		--print("Adding index: " .. index);
		local node = pp.wayPoints[index];
		filteredWPs[filteredIndex] = node;
		filteredIndex = filteredIndex + 1;
		index = index + 1;
	end;

	pp.wayPoints = filteredWPs;
end;

function AutoDrive:drawDebugForPP(driver)
	if ADTableLength(driver.ad.pp.chain) > 1 then
		for i=2, ADTableLength(driver.ad.pp.chain), 1 do
			local pointA = AutoDrive:gridLocationToWorldLocation(driver, driver.ad.pp.chain[i-1].x, driver.ad.pp.chain[i-1].z);
			pointA.y = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, pointA.x, 1, pointA.z) + 3;
			local pointB = AutoDrive:gridLocationToWorldLocation(driver, driver.ad.pp.chain[i].x, driver.ad.pp.chain[i].z);
			pointB.y = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, pointB.x, 1, pointB.z) + 3;
			AutoDrive:drawLine(pointA, pointB, 1, 1, 1, 1);
		end;
	end;
	--if AutoDrive.drawCounter == nil then
		--AutoDrive.drawCounter = 120;
	--else
		--if AutoDrive.drawCounter <= 0 then
			--AutoDrive.drawCounter = 120;
			for rowIndex, row in pairs(driver.ad.pp.grid) do
				for zIndex, cell in pairs(driver.ad.pp.grid[rowIndex]) do
					local size = 0.3;
					local pointA = AutoDrive:gridLocationToWorldLocation(driver, rowIndex, zIndex);
					pointA.x = pointA.x + driver.ad.pp.vectorX.x * size + driver.ad.pp.vectorZ.x * size;
					pointA.z = pointA.z + driver.ad.pp.vectorX.z * size + driver.ad.pp.vectorZ.z * size;
					pointA.y = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, pointA.x, 1, pointA.z) + 3;
					local pointB = AutoDrive:gridLocationToWorldLocation(driver, rowIndex, zIndex);
					pointB.x = pointB.x - driver.ad.pp.vectorX.x * size - driver.ad.pp.vectorZ.x * size;
					pointB.z = pointB.z - driver.ad.pp.vectorX.z * size - driver.ad.pp.vectorZ.z * size;
					pointB.y = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, pointB.x, 1, pointB.z) + 3;
					local pointC = AutoDrive:gridLocationToWorldLocation(driver, rowIndex, zIndex);
					pointC.x = pointC.x - driver.ad.pp.vectorX.x * size - driver.ad.pp.vectorZ.x * size;
					pointC.z = pointC.z + driver.ad.pp.vectorX.z * size + driver.ad.pp.vectorZ.z * size;
					pointC.y = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, pointC.x, 1, pointC.z) + 3;
					local pointD = AutoDrive:gridLocationToWorldLocation(driver, rowIndex, zIndex);
					pointD.x = pointD.x + driver.ad.pp.vectorX.x * size + driver.ad.pp.vectorZ.x * size;
					pointD.z = pointD.z - driver.ad.pp.vectorX.z * size - driver.ad.pp.vectorZ.z * size;
					pointD.y = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, pointD.x, 1, pointD.z) + 3;
					
					if cell.hasInfo == true then
						if cell.isRestricted == true then
							AutoDrive:drawLine(pointA, pointB, 1, 0, 0, 1);
							AutoDrive:drawLine(pointC, pointD, 1, 0, 0, 1);
						else
							AutoDrive:drawLine(pointA, pointB, 0, 1, 0, 1);
							AutoDrive:drawLine(pointC, pointD, 0, 1, 0, 1);
						end;
					else
						AutoDrive:drawLine(pointA, pointB, 0, 0, 1, 1);
						AutoDrive:drawLine(pointC, pointD, 0, 0, 1, 1);
					end;					
				end;
			end;
		--else
			--AutoDrive.drawCounter = AutoDrive.drawCounter - 1;
		--end;
	--end;
end;