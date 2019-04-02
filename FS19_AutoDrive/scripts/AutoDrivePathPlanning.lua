AutoDrive.PP_UP = 0;
AutoDrive.PP_UP_RIGHT = 1;
AutoDrive.PP_RIGHT = 2;
AutoDrive.PP_DOWN_RIGHT = 3;
AutoDrive.PP_DOWN = 4;
AutoDrive.PP_DOWN_LEFT = 5;
AutoDrive.PP_LEFT = 6;
AutoDrive.PP_UP_LEFT = 7;

AutoDrive.PP_MIN_DISTANCE = 10;
AutoDrive.PP_CELL_X = 8;
AutoDrive.PP_CELL_Z = 6;
AutoDrive.PP_MAX_STEPS = 300;

function AutoDrive:plotWayToPipe(driver, combine, dischargeNode)
	local nodeX,nodeY,nodeZ = getWorldTranslation( dischargeNode);

	local worldX,worldY,worldZ = getWorldTranslation( combine.components[1].node );
	local rx,ry,rz = localDirectionToWorld(combine.components[1].node, math.sin(combine.rotatedTime),0,math.cos(combine.rotatedTime));	
	local combineVector = {x= math.sin(rx) ,z= math.sin(rz)};

	local wpAhead = {x= (nodeX + 8*rx), y = worldY, z = nodeZ + 8*rz };
	local wpBehind = {x= (nodeX - 7*rx), y = worldY, z = nodeZ - 7*rz };
	local wpBehindTwo = {x= (nodeX - 14*rx), y = worldY, z = nodeZ - 14*rz };
	local wpBehindThree = {x= (nodeX - 21*rx), y = worldY, z = nodeZ - 21*rz };
	local wpCurrent = {x= (nodeX), y = worldY, z = nodeZ };

	local driverWorldX,driverWorldY,driverWorldZ = getWorldTranslation( driver.components[1].node );
	local driverRx,driverRy,driverRz = localDirectionToWorld(driver.components[1].node, math.sin(driver.rotatedTime),0,math.cos(driver.rotatedTime));	
	local driverVector = {x= math.sin(driverRx) ,z= math.sin(driverRz)};

	local vecX = combineVector.x - driverVector.x;
	local vecZ = combineVector.z - driverVector.z;
	
	local angleRad = math.atan2(vecZ, vecX);

	angleRad = normalizeAngle(angleRad);

	local wayPoints = {};
	wayPoints[1] = wpBehindThree;
	wayPoints[2] = wpBehindTwo;
	wayPoints[3] = wpBehind;
	wayPoints[4] = wpCurrent;
	wayPoints[5] = wpAhead;
	local wayPointCounter = 5;
	return wayPoints;
	--FSDensityMapUtil.getFieldStatusAsync(x, z, corner2x, z, corner2x, corner2z, self.triggerCallbacks[currentPartition][2].onFieldDataUpdateFinished,  self.triggerCallbacks[currentPartition][2]);
end;

function AutoDrive:startPathPlanningToCombine(driver, combine, dischargeNode)
	driver.ad.pp = {};
	driver.ad.pp.isFinished = false;
	driver.ad.pp.combine = combine;
	driver.ad.pp.dischargeNode = dischargeNode;
	driver.ad.pp.grid = {};

	local nodeX,nodeY,nodeZ = getWorldTranslation(dischargeNode);

	local worldX,worldY,worldZ = getWorldTranslation( combine.components[1].node );
	local rx,ry,rz = localDirectionToWorld(combine.components[1].node, math.sin(combine.rotatedTime),0,math.cos(combine.rotatedTime));	
	driver.ad.pp.combineVector = {x= math.sin(rx) ,z= math.sin(rz)};

	local driverWorldX,driverWorldY,driverWorldZ = getWorldTranslation( driver.components[1].node );
	local driverRx,driverRy,driverRz = localDirectionToWorld(driver.components[1].node, math.sin(driver.rotatedTime),0,math.cos(driver.rotatedTime));	
	driver.ad.pp.driverVector = {x= math.sin(driverRx) ,z= math.sin(driverRz)};	
	driver.ad.pp.targetX = driverWorldX + 8*driverRx;
	driver.ad.pp.targetZ = driverWorldZ + 8*driverRz;

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

	AutoDrive:createGridLocation(driver, 0, 0);
	AutoDrive:setGridLocationRestricted(driver, 0, 0, false)
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

	local vectorLength = 8;

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

	AutoDrive:createGridLocation(driver, 0, 0);
	AutoDrive:setGridLocationRestricted(driver, 0, 0, false)
end;

function AutoDrive:updatePathPlanning(driver)
	if ADTableLength(driver.ad.pp.chain) > 1 then
		for i=2, ADTableLength(driver.ad.pp.chain), 1 do
			local pointA = AutoDrive:gridLocationToWorldLocation(driver, driver.ad.pp.chain[i-1].x, driver.ad.pp.chain[i-1].z);
			pointA.y = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, pointA.x, 1, pointA.z);
			local pointB = AutoDrive:gridLocationToWorldLocation(driver, driver.ad.pp.chain[i].x, driver.ad.pp.chain[i].z);
			pointB.y = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, pointB.x, 1, pointB.z);
			AutoDrive:drawLine(pointA, pointB, 1, 1, 1, 1);
		end;
	end;

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
			--DebugUtil.printTableRecursively(pp.grid, "-", 0,2);
			pp.isFinished = true;
			pp.wayPoints = {};
		end;
				
		local bestIndex = 0;
		local bestDistance = math.huge;
		for index, testLocation in pairs(pp.testGrid) do
			if pp.grid[testLocation.x][testLocation.z].isRestricted == false or pp.fallBackMode == true then
				local worldPos = AutoDrive:gridLocationToWorldLocation(driver, testLocation.x, testLocation.z);
				local distance = math.sqrt(math.pow((worldPos.x - pp.targetX) , 2) + math.pow((worldPos.z - pp.targetZ) , 2));

				if distance < bestDistance then
					bestDistance = distance;
					bestIndex = index;
				end;
			end;
		end;

		if bestIndex == 0 then
			--we have to trace back our greedy algorithm
			AutoDrive:stepBackPPAlgorithm(driver);
		else
			AutoDrive:stepForwardPPAlgorithm(driver, bestIndex);
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
	end;
end;

function AutoDrive:setGridLocationRestricted(driver, x, z, restricted)
	local pp = driver.ad.pp;
	if pp.grid[x] ~= nil then
		if pp.grid[x][z] ~= nil then
			pp.grid[x][z].hasInfo = true;
			pp.grid[x][z].isFruitFree = not restricted;
			pp.grid[x][z].isRestricted = restricted;
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
	else
		print("Error in pathfinding. Could not trace back any further");
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
		pp.wayPoints[index] = AutoDrive:gridLocationToWorldLocation(driver, pp.chain[pp.chainIndex].x, pp.chain[pp.chainIndex].z);
		pp.wayPoints[index].y = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, pp.wayPoints[index].x, 1, pp.wayPoints[index].z);
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
end;

function AutoDrive:calculateBoundingBoxForGrid(driver, x, z)
	--FSDensityMapUtil.getFieldStatusAsync(x, z, corner2x, z, corner2x, corner2z, self.triggerCallbacks[currentPartition][2].onFieldDataUpdateFinished,  self.triggerCallbacks[currentPartition][2]);
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

	local callBack = FieldDataCallback:new(driver, x, z);
	FSDensityMapUtil.getFieldStatusAsync(cornerX, cornerZ, corner2X, corner2Z, corner3X, corner3Z, callBack.onFieldDataUpdateFinished,  callBack);	
end;

function AutoDrive:onFieldDataUpdateFinished(driver, fielddata, x, z)
	driver.ad.pp.grid[x][z].fielddata = fielddata;
	local totalFruitPixels = 0;
	if fielddata ~= nil then
		for fruitIndex,fruitAmount in pairs(fielddata.fruitPixels) do	
			--ToDo: filter out grass and growthstate < x	
			if fruitIndex ~= 13 then --13 should be grass
				if fielddata.fruits[fruitIndex] > 2 and fielddata.fruits[fruitIndex] <  9 then
					totalFruitPixels = totalFruitPixels + fruitAmount;
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
	
		--Allow fruit in the first few grid cells
		if driver.ad.pp.chainIndex < 2 then
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