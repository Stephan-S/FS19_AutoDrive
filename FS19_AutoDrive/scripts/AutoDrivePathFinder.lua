AutoDrive.MAX_PATHFINDER_STEPS_PER_FRAME = 10;
AutoDrive.MAX_PATHFINDER_STEPS_TOTAL = 2500;
AutoDrive.PATHFINDER_TARGET_DISTANCE = 25;
AutoDrive.PATHFINDER_START_DISTANCE = 5;
AutoDrive.PP_UP = 0;
AutoDrive.PP_UP_RIGHT = 1;
AutoDrive.PP_RIGHT = 2;
AutoDrive.PP_DOWN_RIGHT = 3;
AutoDrive.PP_DOWN = 4;
AutoDrive.PP_DOWN_LEFT = 5;
AutoDrive.PP_LEFT = 6;
AutoDrive.PP_UP_LEFT = 7;

AutoDrive.PP_MIN_DISTANCE = 20;
AutoDrive.PP_CELL_X = 8;
AutoDrive.PP_CELL_Z = 8;
AutoDrivePathFinder = {};

function AutoDrivePathFinder:startPathPlanningToCombine(driver, combine, dischargeNode)       
    --print("startPathPlanningToCombine " .. driver.name );
    local worldX,worldY,worldZ = getWorldTranslation( combine.components[1].node );
	local rx,ry,rz = localDirectionToWorld(combine.components[1].node, 0,0,1);	
    local combineVector = {x= math.sin(rx) ,z= math.sin(rz)};	
    local combineNormalVector = {x= -combineVector.z ,z= combineVector.x};	
    
    local nodeX,nodeY,nodeZ = getWorldTranslation(dischargeNode);       
    local pipeOffset = AutoDrive:getSetting("pipeOffset");
    local wpAhead = {x= (nodeX + 8*rx) - pipeOffset * combineNormalVector.x, y = worldY, z = nodeZ + 8*rz  - pipeOffset * combineNormalVector.z};
    local wpCurrent = {x= (nodeX - pipeOffset * combineNormalVector.x ), y = worldY, z = nodeZ - pipeOffset * combineNormalVector.z};
    local wpBehind_close = {x= (nodeX - 5*rx - pipeOffset * combineNormalVector.x), y = worldY, z = nodeZ - 5*rz - pipeOffset * combineNormalVector.z };
    
	local wpBehind = {x= (nodeX - AutoDrive.PATHFINDER_TARGET_DISTANCE*rx - pipeOffset * combineNormalVector.x), y = worldY, z = nodeZ - AutoDrive.PATHFINDER_TARGET_DISTANCE*rz - pipeOffset * combineNormalVector.z }; --make this target
    

    local driverWorldX,driverWorldY,driverWorldZ = getWorldTranslation( driver.components[1].node );
	local driverRx,driverRy,driverRz = localDirectionToWorld(driver.components[1].node, 0,0,1);	
	local driverVector = {x= math.sin(driverRx) ,z= math.sin(driverRz)};	
	local startX = driverWorldX + AutoDrive.PATHFINDER_START_DISTANCE*driverRx;
	local startZ = driverWorldZ + AutoDrive.PATHFINDER_START_DISTANCE*driverRz;
	
	local angleGrid = math.atan2(driverVector.z, driverVector.x);
	angleGrid = normalizeAngle(angleGrid);

    local atan = angleGrid;
	
	local sin = math.sin(atan);
	local cos = math.cos(atan);

	local vectorX = {};
	vectorX.x = cos * AutoDrive.PP_CELL_X;
	vectorX.z = sin * AutoDrive.PP_CELL_X;

	local vectorZ = {};
	vectorZ.x = -sin * AutoDrive.PP_CELL_Z;
    vectorZ.z = cos * AutoDrive.PP_CELL_Z;
    
    -- AutoDrivePathFinder:init(driver, startX, startZ, targetX, targetY, targetVector, vectorX, vectorZ)
    AutoDrivePathFinder:init(driver, startX, startZ, wpBehind.x, wpBehind.z, combineVector, vectorX, vectorZ, combine) 
    
    driver.ad.pf.appendWayPoints = {};
	driver.ad.pf.appendWayPoints[1] = wpBehind_close;
	driver.ad.pf.appendWayPoints[2] = wpCurrent;
	driver.ad.pf.appendWayPoints[3] = wpAhead;
    driver.ad.pf.appendWayPointCount = 3;	   
    
    driver.ad.pf.goingToCombine = true;
end;

function AutoDrivePathFinder:startPathPlanningToStartPosition(driver, combine)       
    --print("startPathPlanningToStartPosition " .. driver.name );
    local driverWorldX,driverWorldY,driverWorldZ = getWorldTranslation( driver.components[1].node );
	local driverRx,driverRy,driverRz = localDirectionToWorld(driver.components[1].node, 0,0,1);	
	local driverVector = {x= math.sin(driverRx) ,z= math.sin(driverRz)};	
	local startX = driverWorldX + AutoDrive.PATHFINDER_START_DISTANCE*driverRx;
	local startZ = driverWorldZ + AutoDrive.PATHFINDER_START_DISTANCE*driverRz;
	
	local angleGrid = math.atan2(driverVector.z, driverVector.x);
	angleGrid = normalizeAngle(angleGrid);

	local atan = angleGrid;
	
	local sin = math.sin(atan);
	local cos = math.cos(atan);

	local vectorX = {};
	vectorX.x = cos * AutoDrive.PP_CELL_X;
	vectorX.z = sin * AutoDrive.PP_CELL_X;

	local vectorZ = {};
	vectorZ.x = -sin * AutoDrive.PP_CELL_Z;
    vectorZ.z = cos * AutoDrive.PP_CELL_Z;

    local targetPoint = AutoDrive.mapWayPoints[AutoDrive.mapMarker[driver.ad.mapMarkerSelected].id]
	local preTargetPoint = AutoDrive.mapWayPoints[targetPoint.incoming[1]];
	local targetVector = {};

    local exitStrategy =  AutoDrive:getSetting("exitField");
    if exitStrategy == 1 then
        local waypointsToUnload = AutoDrive:FastShortestPath(AutoDrive.mapWayPoints, AutoDrive.mapMarker[driver.ad.mapMarkerSelected].id, AutoDrive.mapMarker[driver.ad.mapMarkerSelected_Unload].name, AutoDrive.mapMarker[driver.ad.mapMarkerSelected_Unload].id);
        if waypointsToUnload ~= nil and waypointsToUnload[6] ~= nil then
            preTargetPoint = AutoDrive.mapWayPoints[waypointsToUnload[5].id];
            targetPoint = AutoDrive.mapWayPoints[waypointsToUnload[6].id];
        end;
    elseif exitStrategy == 2 then
        local closest = AutoDrive:findClosestWayPoint(driver);
        local waypointsToUnload = AutoDrive:FastShortestPath(AutoDrive.mapWayPoints, closest, AutoDrive.mapMarker[driver.ad.mapMarkerSelected_Unload].name, AutoDrive.mapMarker[driver.ad.mapMarkerSelected_Unload].id);
        if waypointsToUnload ~= nil and waypointsToUnload[2] ~= nil then
            preTargetPoint = AutoDrive.mapWayPoints[waypointsToUnload[1].id];
            targetPoint = AutoDrive.mapWayPoints[waypointsToUnload[2].id];
        end;
    end;
    
	targetVector.x = preTargetPoint.x - targetPoint.x
	targetVector.z = preTargetPoint.z - targetPoint.z

	local angleRad = math.atan2(targetVector.z, targetVector.x);

	angleRad = normalizeAngle(angleRad);

	local targetX = preTargetPoint.x + math.cos(angleRad) * AutoDrive.PATHFINDER_TARGET_DISTANCE; --Make the target a few meters ahead of the road to the start point
	local targetZ = preTargetPoint.z + math.sin(angleRad) * AutoDrive.PATHFINDER_TARGET_DISTANCE;
    
    targetVector.x = -targetVector.x;
	targetVector.z = -targetVector.z;

    -- AutoDrivePathFinder:init(driver, startX, startZ, targetX, targetY, targetVector, vectorX, vectorZ)
    AutoDrivePathFinder:init(driver, startX, startZ, targetX, targetZ, targetVector, vectorX, vectorZ, combine) 
    
	driver.ad.pf.appendWayPoints = {};
	driver.ad.pf.appendWayPoints[1] = preTargetPoint;
    driver.ad.pf.appendWayPoints[2] = targetPoint;
    driver.ad.pf.appendWayPointCount = 2;
    
    driver.ad.pf.goingToCombine = false;
end;

function AutoDrivePathFinder:init(driver, startX, startZ, targetX, targetZ, targetVector, vectorX, vectorZ, combine)    
    startCell = {x=0, z=0};
    startCell.direction = AutoDrive.PP_UP;
    startCell.visited = false;
    startCell.isRestricted = false;
    startCell.hasCollision = false;
    startCell.hasInfo = true;
    startCell.steps = 0;

    driver.ad.pf = {};
    driver.ad.pf.driver = driver;    
	driver.ad.combineUnloadInFruit = false;
	driver.ad.combineUnloadInFruitWaitTimer = AutoDrive.UNLOAD_WAIT_TIMER;
    driver.ad.pf.grid = {};
    driver.ad.pf.startX = startX;
    driver.ad.pf.startZ = startZ;
    driver.ad.pf.vectorX = vectorX;
    driver.ad.pf.vectorZ = vectorZ;
    driver.ad.pf.targetVector = targetVector;
    driver.ad.pf.startCell = startCell;
    driver.ad.pf.steps = 0;
    driver.ad.pf.isFinished = false;
    driver.ad.pf.fallBackMode = false;
    driver.ad.pf.combine = combine;
    driver.ad.pf.fruitToCheck = driver.ad.combineFruitToCheck;
    driver.ad.pf.fieldArea = driver.ad.combineFieldArea;
    
    driver.ad.pf.targetCell = AutoDrivePathFinder:worldLocationToGridLocation(driver.ad.pf, targetX, targetZ);
    local targetDirection = AutoDrivePathFinder:worldDirectionToGridDirection(driver.ad.pf, targetVector)
    AutoDrivePathFinder:determineBlockedCells(driver.ad.pf, targetDirection, driver.ad.pf.targetCell);

    table.insert(driver.ad.pf.grid, startCell)
end;

function AutoDrivePathFinder:updatePathPlanning(driver)    
    local pf = driver.ad.pf;
    --AutoDrivePathFinder:drawDebugForPF(pf);
    pf.steps = pf.steps + 1;

    if pf.isFinished then
        return;
    end;

    if pf.steps > AutoDrive.MAX_PATHFINDER_STEPS_TOTAL then
        if not pf.fallBackMode then --look for path through fruit
            pf.fallBackMode = true;
            pf.steps = 0;
            pf.grid = {};
            pf.startCell.visited = false;
            table.insert(pf.grid, pf.startCell)
            local targetDirection = AutoDrivePathFinder:worldDirectionToGridDirection(pf, pf.targetVector)
            AutoDrivePathFinder:determineBlockedCells(pf, targetDirection, pf.targetCell);
            print("Going into fallback mode - no fruit free path found in reasonable time");
        else
            --stop searching
            pf.isFinished = true;
            pf.wayPoints = {};
            print("Stop searching - no path found in reasonable time");
        end;
    end;    

    for i=1,AutoDrive.MAX_PATHFINDER_STEPS_PER_FRAME,1 do
        if pf.currentCell == nil then 
            local minDistance = math.huge;
            local bestCell = nil;
            local bestSteps = math.huge;
            
            for _,cell in pairs(pf.grid) do
                if not cell.visited and ((not cell.isRestricted) or pf.fallBackMode) and (not cell.hasCollision) and cell.hasInfo == true then
                    local distance = cellDistance(pf, cell);
                    if distance < minDistance then
                        minDistance = distance;
                        bestCell = cell;
                        bestSteps = cell.steps;
                    elseif distance == minDistance and cell.steps < bestSteps then
                        minDistance = distance;
                        bestCell = cell;
                        bestSteps = cell.steps;
                    end;
                end;
            end;
        
            if bestCell ~= nil then
                pf.currentCell = bestCell;
                if cellDistance(pf, bestCell) == 0 then
                    --print("Found target cell: " .. bestCell.x .. "/" .. bestCell.z);
                    pf.isFinished = true;
                    pf.targetCell.incoming = bestCell.incoming;
                    if pf.currentCell.hasFruit ~= nil then
                        pf.driver.ad.combineUnloadInFruit = pf.currentCell.hasFruit;                        
                    end;
                    --print("Driver " .. pf.driver.name .. " is unloading combine in fruit: " .. ADBoolToString(pf.driver.ad.combineUnloadInFruit));
                    AutoDrivePathFinder:createWayPoints(pf);
                end;
            end;
        else
            if pf.currentCell.out == nil then
                AutoDrivePathFinder:determineNextGridCells(pf, pf.currentCell);
            end;
            AutoDrivePathFinder:testNextCells(pf, pf.currentCell);
        end;
    end;
end;

function AutoDrivePathFinder:isPathPlanningFinished(driver)
	if driver.ad.pf ~= nil then
		if driver.ad.pf.isFinished == true then
			return true;
		end;
	end;
	return false;
end;

function AutoDrivePathFinder:determineNextGridCells(pf, cell)
	cell.out = {};
	if cell.direction == AutoDrive.PP_UP then
		cell.out[1] = {x=cell.x + 1, z=cell.z - 1};
		cell.out[1].direction = AutoDrive.PP_UP_LEFT;
		cell.out[2] = {x=cell.x + 1, z=cell.z + 0};
		cell.out[2].direction = AutoDrive.PP_UP;
		cell.out[3] = {x=cell.x + 1, z=cell.z + 1};
		cell.out[3].direction = AutoDrive.PP_UP_RIGHT;
	elseif cell.direction == AutoDrive.PP_UP_RIGHT then
		cell.out[1] = {x=cell.x + 1, z=cell.z + 0};
		cell.out[1].direction = AutoDrive.PP_UP;
		cell.out[2] = {x=cell.x + 1, z=cell.z + 1};
		cell.out[2].direction = AutoDrive.PP_UP_RIGHT;
		cell.out[3] = {x=cell.x + 0, z=cell.z + 1};
		cell.out[3].direction = AutoDrive.PP_RIGHT;
	elseif cell.direction == AutoDrive.PP_RIGHT then
		cell.out[1] = {x=cell.x + 1, z=cell.z + 1};
		cell.out[1].direction = AutoDrive.PP_UP_RIGHT;
		cell.out[2] = {x=cell.x + 0, z=cell.z + 1};
		cell.out[2].direction = AutoDrive.PP_RIGHT;
		cell.out[3] = {x=cell.x - 1, z=cell.z + 1};
		cell.out[3].direction = AutoDrive.PP_DOWN_RIGHT;
	elseif cell.direction == AutoDrive.PP_DOWN_RIGHT then
		cell.out[1] = {x=cell.x + 0, z=cell.z + 1};
		cell.out[1].direction = AutoDrive.PP_RIGHT;
		cell.out[2] = {x=cell.x - 1, z=cell.z + 1};
		cell.out[2].direction = AutoDrive.PP_DOWN_RIGHT;
		cell.out[3] = {x=cell.x - 1, z=cell.z + 0};
		cell.out[3].direction = AutoDrive.PP_DOWN;
	elseif cell.direction == AutoDrive.PP_DOWN then
		cell.out[1] = {x=cell.x - 1, z=cell.z + 1};
		cell.out[1].direction = AutoDrive.PP_DOWN_RIGHT;
		cell.out[2] = {x=cell.x - 1, z=cell.z + 0};
		cell.out[2].direction = AutoDrive.PP_DOWN;
		cell.out[3] = {x=cell.x - 1, z=cell.z - 1};
		cell.out[3].direction = AutoDrive.PP_DOWN_LEFT;
	elseif cell.direction == AutoDrive.PP_DOWN_LEFT then
		cell.out[1] = {x=cell.x - 1, z=cell.z - 0};
		cell.out[1].direction = AutoDrive.PP_DOWN;
		cell.out[2] = {x=cell.x - 1, z=cell.z - 1};
		cell.out[2].direction = AutoDrive.PP_DOWN_LEFT;
		cell.out[3] = {x=cell.x - 0, z=cell.z - 1};
		cell.out[3].direction = AutoDrive.PP_LEFT;
	elseif cell.direction == AutoDrive.PP_LEFT then
		cell.out[1] = {x=cell.x - 1, z=cell.z - 1};
		cell.out[1].direction = AutoDrive.PP_DOWN_LEFT;
		cell.out[2] = {x=cell.x - 0, z=cell.z - 1};
		cell.out[2].direction = AutoDrive.PP_LEFT;
		cell.out[3] = {x=cell.x + 1, z=cell.z - 1};
		cell.out[3].direction = AutoDrive.PP_UP_LEFT;
	elseif cell.direction == AutoDrive.PP_UP_LEFT then
		cell.out[1] = {x=cell.x - 0, z=cell.z - 1};
		cell.out[1].direction = AutoDrive.PP_LEFT;
		cell.out[2] = {x=cell.x + 1, z=cell.z - 1};
		cell.out[2].direction = AutoDrive.PP_UP_LEFT;
		cell.out[3] = {x=cell.x + 1, z=cell.z + 0};
		cell.out[3].direction = AutoDrive.PP_UP;
    end;	

    for _, outGoing in pairs(cell.out) do
        outGoing.incoming = cell;
        outGoing.steps = cell.steps + 1;
    end;
end;

function AutoDrivePathFinder:testNextCells(pf, cell)
    local allResultsIn = true;
    for _,location in pairs(cell.out) do
        local createPoint = true;
        for _, c in pairs(pf.grid) do
            if c.x == location.x and c.z == location.z and c.direction == location.direction then
                createPoint = false;
                if c.steps > (cell.steps + 1) then --found shortcut
                    c.incoming = cell;
                    c.steps = cell.steps + 1;
                end;
                location.hasInfo = c.hasInfo;
            end;

            if c.x == location.x and c.z == location.z and c.direction == -1 then
                location.isRestricted = true;
                location.hasInfo = true;
                createPoint = false;
            end;
        end;

		if createPoint then			
            AutoDrivePathFinder:createGridCells(pf, location);
        end;

        if not location.hasInfo then
            AutoDrivePathFinder:checkGridCell(pf, location)
        end;

        allResultsIn = allResultsIn and location.hasInfo;
    end;

    if allResultsIn then
        --print("All result are in for: " .. cell.x .. "/" .. cell.z);
        cell.visited = true;
        pf.currentCell = nil;
    end;
end;

function AutoDrivePathFinder:createGridCells(pf, location)	
    location.visited=false;
    location.isRestricted=false;
    location.hasInfo=false;
    location.hasRequested=false;
    location.hasCollision = false;
    table.insert(pf.grid, location);
end;

function AutoDrivePathFinder:checkGridCell(pf, cell)
    if cell.hasInfo == false then
        if cell.hasRequested == false then            
            local worldPos = AutoDrivePathFinder:gridLocationToWorldLocation(pf, cell);

            local cornerX = worldPos.x + (-pf.vectorX.x - pf.vectorZ.x)/2
            local cornerZ = worldPos.z + (-pf.vectorX.z - pf.vectorZ.z)/2

            local corner2X = worldPos.x + (pf.vectorX.x - pf.vectorZ.x)/2
            local corner2Z = worldPos.z + (pf.vectorX.z - pf.vectorZ.z)/2

            local corner3X = worldPos.x + (-pf.vectorX.x + pf.vectorZ.x)/2
            local corner3Z = worldPos.z + (-pf.vectorX.z + pf.vectorZ.z)/2

            local corner4X = worldPos.x + (pf.vectorX.x + pf.vectorZ.x)/2
            local corner4Z = worldPos.z + (pf.vectorX.z + pf.vectorZ.z)/2

            local angleRad = math.atan2(pf.targetVector.z, pf.targetVector.x);
            local y = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, worldPos.x, 1, worldPos.z)
            local shapes = overlapBox(worldPos.x,y,worldPos.z, 0,angleRad,0, AutoDrive.PP_CELL_X,5,AutoDrive.PP_CELL_Z, "collisionTestCallbackIgnore", nil, AIVehicleUtil.COLLISION_MASK, true, true, true)
            cell.hasCollision = (shapes > 0);

            local previousCell = cell.incoming
            local worldPosPrevious = AutoDrivePathFinder:gridLocationToWorldLocation(pf, previousCell);
            
            local terrain1 = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, worldPos.x, 0, worldPos.z)
            local terrain2 = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, worldPosPrevious.x, 0, worldPosPrevious.z)
            local length = MathUtil.vector3Length(worldPos.x-worldPosPrevious.x, terrain1-terrain2, worldPos.z-worldPosPrevious.z)
            local angleBetween = math.atan(math.abs(terrain1-terrain2)/length)

            if angleBetween > AITurnStrategy.SLOPE_DETECTION_THRESHOLD then
                cell.hasCollision = true;
            end

            shapes = overlapBox(worldPos.x,y,worldPos.z, 0,angleRad,0, AutoDrive.PP_CELL_X,5,AutoDrive.PP_CELL_Z, "collisionTestCallbackIgnore", nil, Player.COLLISIONMASK_TRIGGER, true, true, true)
            cell.hasCollision = cell.hasCollision or (shapes > 0);    

            --allow collision in the first few grid. as it also detects the driver and trailer itself
            if ((math.abs(cell.x) <= 2) and (math.abs(cell.z) <= 2)) or cellDistance(pf, cell) <= 3 then --also allow collision at the end if other drivers are waiting in line
                cell.hasCollision = false;
            end;

            if pf.fruitToCheck == nil then
                --make async query until fruittype is known
                local callBack = PathFinderCallBack:new(pf, cell);
                FSDensityMapUtil.getFieldStatusAsync(cornerX, cornerZ, corner2X, corner2Z, corner3X, corner3Z, callBack.onFieldDataUpdateFinished,  callBack);
                local box = {}
                cell.hasRequested = true;
            else
                local fruitValue, _, _, _ = FSDensityMapUtil.getFruitArea(pf.fruitToCheck, cornerX, cornerZ, corner2X, corner2Z, corner3X, corner3Z, nil, false);
                cell.isRestricted = fruitValue > (0.3 * pf.fieldArea);
                cell.hasFruit = cell.isRestricted;

                --Allow fruit in the first few grid cells
                if (((math.abs(cell.x) <= 2) and (math.abs(cell.z) <= 2)) and pf.driver.ad.combineUnloadInFruit) or cellDistance(pf, cell) <= 2 then
                    cell.isRestricted = false;
                end;
                cell.hasInfo = true;
            end;

            local boundingBox = {};
            boundingBox[1] ={ 	x = cornerX,
                                y = 0,
                                z = cornerZ; };
            boundingBox[2] ={ 	x = corner2X,
                                y = 0,
                                z = corner2Z; };
            boundingBox[3] ={ 	x = corner3X,
                                y = 0,
                                z = corner3Z; };
            boundingBox[4] ={ 	x = corner4X,
                                y = 0,
                                z = corner4Z; };

            if pf.combine ~= nil and pf.combine.components ~= nil and pf.combine.sizeWidth ~= nil and pf.combine.sizeLength ~= nil and pf.combine.rootNode ~= nil then     
                local otherWidth = pf.combine.sizeWidth;
                local otherLength = pf.combine.sizeLength;
                local otherPos = {};
                otherPos.x,otherPos.y,otherPos.z = getWorldTranslation( pf.combine.components[1].node ); 

                local rx,ry,rz = localDirectionToWorld(pf.combine.components[1].node, 0, 0, 1);

                local otherVectorToWp = {};
                otherVectorToWp.x = rx;
                otherVectorToWp.z = rz;

                local otherPos2 = {};
                otherPos2.x = otherPos.x + (otherLength/2) * (otherVectorToWp.x/(math.abs(otherVectorToWp.x)+math.abs(otherVectorToWp.z)));
                otherPos2.y = 0;
                otherPos2.z = otherPos.z + (otherLength/2) * (otherVectorToWp.z/(math.abs(otherVectorToWp.x)+math.abs(otherVectorToWp.z)));
                local otherOrtho = { x=-otherVectorToWp.z, z=otherVectorToWp.x };

                local otherBoundingBox = {};
                otherBoundingBox[1] ={ 	x = otherPos.x + (otherWidth/2) * ( otherOrtho.x / (math.abs(otherOrtho.x)+math.abs(otherOrtho.z))) + (otherLength/2) * (otherVectorToWp.x/(math.abs(otherVectorToWp.x)+math.abs(otherVectorToWp.z))),
                                        y = 0,
                                        z = otherPos.z + (otherWidth/2) * ( otherOrtho.z / (math.abs(otherOrtho.x)+math.abs(otherOrtho.z))) + (otherLength/2) * (otherVectorToWp.z/(math.abs(otherVectorToWp.x)+math.abs(otherVectorToWp.z)))};

                otherBoundingBox[2] ={ 	x = otherPos.x - (otherWidth/2) * ( otherOrtho.x / (math.abs(otherOrtho.x)+math.abs(otherOrtho.z))) + (otherLength/2) * (otherVectorToWp.x/(math.abs(otherVectorToWp.x)+math.abs(otherVectorToWp.z))),
                                        y = 0,
                                        z = otherPos.z - (otherWidth/2) * ( otherOrtho.z / (math.abs(otherOrtho.x)+math.abs(otherOrtho.z))) + (otherLength/2) * (otherVectorToWp.z/(math.abs(otherVectorToWp.x)+math.abs(otherVectorToWp.z)))};
                otherBoundingBox[3] ={ 	x = otherPos.x - (otherWidth/2) * ( otherOrtho.x / (math.abs(otherOrtho.x)+math.abs(otherOrtho.z))) - (otherLength/2) * (otherVectorToWp.x/(math.abs(otherVectorToWp.x)+math.abs(otherVectorToWp.z))),
                                        y = 0,
                                        z = otherPos.z - (otherWidth/2) * ( otherOrtho.z / (math.abs(otherOrtho.x)+math.abs(otherOrtho.z))) - (otherLength/2) * (otherVectorToWp.z/(math.abs(otherVectorToWp.x)+math.abs(otherVectorToWp.z)))};

                otherBoundingBox[4] ={ 	x = otherPos.x + (otherWidth/2) * ( otherOrtho.x / (math.abs(otherOrtho.x)+math.abs(otherOrtho.z))) - (otherLength/2) * (otherVectorToWp.x/(math.abs(otherVectorToWp.x)+math.abs(otherVectorToWp.z))),
                                        y = 0,
                                        z = otherPos.z + (otherWidth/2) * ( otherOrtho.z / (math.abs(otherOrtho.x)+math.abs(otherOrtho.z))) - (otherLength/2) * (otherVectorToWp.z/(math.abs(otherVectorToWp.x)+math.abs(otherVectorToWp.z)))};
				
                if AutoDrive:BoxesIntersect(boundingBox, otherBoundingBox) == true then
                    cell.isRestricted = true;
                    cell.hasInfo = true;
                    cell.hasCollision = true;
                end;
            end;
        end;
    end;
end;

function AutoDrivePathFinder:createWayPoints(pf)
    local currentCell = pf.targetCell;
    pf.chainTargetToStart = {};
    local index = 1;
    while currentCell.x ~= 0 or currentCell.z ~= 0 do
        pf.chainTargetToStart[index] = currentCell.incoming;
        currentCell = currentCell.incoming;
        if currentCell == nil then
            break;
        end;
        index = index + 1;
    end;
    index = index - 1;

    pf.chainStartToTarget = {};
    for reversedIndex=0,index,1 do
        pf.chainStartToTarget[reversedIndex+1] = pf.chainTargetToStart[index-reversedIndex];
    end;

    --Now build actual world coordinates as waypoints and include pre and append points
    pf.wayPoints = {};  
    local index = 0
	if pf.prependWayPointCount ~= nil then
		for i=1, pf.prependWayPointCount, 1 do
			index = index + 1;
			pf.wayPoints[i] = pf.prependWayPoints[i];
		end;
    end;

    for chainIndex, cell in pairs(pf.chainStartToTarget) do
        pf.wayPoints[index+chainIndex] = AutoDrivePathFinder:gridLocationToWorldLocation(pf, cell);
        pf.wayPoints[index+chainIndex].y = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, pf.wayPoints[index+chainIndex].x, 1, pf.wayPoints[index+chainIndex].z);
        pf.wayPoints[index+chainIndex].lastDirection = cell.direction;
    end;

    index = index + ADTableLength(pf.chainStartToTarget);

	if pf.appendWayPointCount ~= nil then
		for i=1, pf.appendWayPointCount, 1 do
			pf.wayPoints[index+i] = pf.appendWayPoints[i];
		end;
    end;
    
    --print("Found path!");
    --DebugUtil.printTableRecursively(pf.wayPoints, ":::",0,1);

	AutoDrivePathFinder:smoothResultingPPPath(pf);
end;

function AutoDrivePathFinder:smoothResultingPPPath(pf)
	local index = 1;
	local filteredIndex = 1;
	local filteredWPs = {};

	while index < ADTableLength(pf.wayPoints) - 2 do
		local node = pf.wayPoints[index];
		local nodeAhead = pf.wayPoints[index+1];
		local nodeTwoAhead = pf.wayPoints[index+2];

		filteredWPs[filteredIndex] = node;
		filteredIndex = filteredIndex + 1;

		if node.lastDirection ~= nil and nodeAhead.lastDirection ~= nil and nodeTwoAhead.lastDirection ~= nil then
			if node.lastDirection == nodeTwoAhead.lastDirection and node.lastDirection ~= nodeAhead.lastDirection then
				index = index + 1; --skip next point because it is a zig zag line. Cut right through instead
			end;
		end;
		
		index = index + 1;
	end;
	
	while index <= ADTableLength(pf.wayPoints) do
		local node = pf.wayPoints[index];
		filteredWPs[filteredIndex] = node;
		filteredIndex = filteredIndex + 1;
		index = index + 1;
	end;

	pf.wayPoints = filteredWPs;
end;

function AutoDrivePathFinder:onFieldDataUpdateFinished(pf, fielddata, cell)
    local totalFruitPixels = 0;
    if fielddata ~= nil then
		local maxAmount = 0;
		local maxIndex = 0;
		for fruitIndex,fruitAmount in pairs(fielddata.fruitPixels) do
			if fruitIndex ~= 13 then --13 should be grass				
                totalFruitPixels = totalFruitPixels + fruitAmount;
                if fruitAmount > maxAmount then
                    maxAmount = fruitAmount;
                    maxIndex = fruitIndex;
                end;
			end;
        end;
        
        cell.isRestricted = (maxAmount > (0.3 * fielddata.fieldArea) and (fielddata.fieldArea > 150))
        cell.hasFruit = cell.isRestricted;

        if maxIndex > 0 and maxAmount > (0.2 * fielddata.fieldArea) and pf.fruitToCheck == nil  and fielddata.fieldArea > 150 then
            --print("Avoiding fruit: " .. maxIndex .. " from now on. FieldArea: " .. fielddata.fieldArea);
			pf.fruitToCheck = maxIndex;
            pf.fieldArea = fielddata.fieldArea;
            pf.driver.ad.combineFieldArea = pf.fieldArea;
            pf.driver.ad.combineFruitToCheck = pf.fruitToCheck; 
		end;
	
		--Allow fruit in the first few grid cells
		if (math.abs(cell.x) <= 2 and math.abs(cell.z) <= 2) or cellDistance(pf, cell) <= 3 then
			cell.isRestricted = false;
		end;
	else
        --Not on field == not restricted
		cell.isRestricted = false;
	end;	

	cell.hasInfo = true;
end;

function AutoDrivePathFinder:gridLocationToWorldLocation(pf, cell)
	local result = {x= 0, z=0};

	result.x = pf.startX + cell.x * pf.vectorX.x + cell.z * pf.vectorZ.x;
	result.z = pf.startZ + cell.x * pf.vectorX.z + cell.z * pf.vectorZ.z;

	return result;
end;

function AutoDrivePathFinder:worldLocationToGridLocation(pf, worldX, worldZ)
	local result = {x= 0, z=0};

	result.z = (((worldX - pf.startX) / pf.vectorX.x) * pf.vectorX.z -worldZ + pf.startZ) / (((pf.vectorZ.x / pf.vectorX.x) * pf.vectorX.z) - pf.vectorZ.z);
	result.x = (worldZ - pf.startZ - result.z * pf.vectorZ.z) / pf.vectorX.z;

	result.x = AutoDrive:round(result.x);
	result.z = AutoDrive:round(result.z);

	return result;
end;

function AutoDrivePathFinder:worldDirectionToGridDirection(pf, vector)
	local vecUp = {x = pf.vectorX.x + pf.vectorZ.x, z = pf.vectorX.z + pf.vectorZ.z};

	local angleWorldDirection = math.atan2(vector.z, vector.x);
	angleWorldDirection = normalizeAngle2(angleWorldDirection);

    --local angleRad = math.atan2(vecUp.z, vecUp.x);
    local angleRad = math.atan2(pf.vectorX.z, pf.vectorX.x);
	angleRad = normalizeAngle2(angleRad);

	local upRightAngle = normalizeAngle2(angleRad + math.rad(45));
	local rightAngle = normalizeAngle2(angleRad + math.rad(90));
	local downRightAngle = normalizeAngle2(angleRad + math.rad(135));
	local downAngle = normalizeAngle2(angleRad + math.rad(180));
	local downLeftAngle = normalizeAngle2(angleRad + math.rad(225));
	local leftAngle = normalizeAngle2(angleRad + math.rad(270));
	local upLeftAngle = normalizeAngle2(angleRad + math.rad(315));

    local direction = AutoDrive.PP_UP;
    --print("vectorUp: " .. math.deg(angleRad) ..  " angle target: " .. math.deg(angleWorldDirection));

	if math.abs( math.deg( normalizeAngle2( angleWorldDirection - upRightAngle ) )) <= 22.5 or math.abs( math.deg( normalizeAngle2( angleWorldDirection - upRightAngle ) )) >= 337.5 then
		direction = AutoDrive.PP_UP_RIGHT;
	elseif math.abs( math.deg( normalizeAngle2( angleWorldDirection - rightAngle ) )) <= 22.5 or math.abs( math.deg( normalizeAngle2( angleWorldDirection - rightAngle ) )) >= 337.5 then
		direction = AutoDrive.PP_RIGHT;
	elseif math.abs( math.deg( normalizeAngle2( angleWorldDirection - downRightAngle ) )) <= 22.5 or math.abs( math.deg( normalizeAngle2( angleWorldDirection - downRightAngle ) )) >= 337.5 then
		direction = AutoDrive.PP_DOWN_RIGHT;
	elseif math.abs( math.deg( normalizeAngle2( angleWorldDirection - downAngle ) )) <= 22.5 or math.abs( math.deg( normalizeAngle2( angleWorldDirection - downAngle ) )) >= 337.5 then
		direction = AutoDrive.PP_DOWN;
	elseif math.abs( math.deg( normalizeAngle2( angleWorldDirection - downLeftAngle ) )) <= 22.5 or math.abs( math.deg( normalizeAngle2( angleWorldDirection - downLeftAngle ) )) >= 337.5 then
		direction = AutoDrive.PP_DOWN_LEFT;
	elseif math.abs( math.deg( normalizeAngle2( angleWorldDirection - leftAngle ) )) <= 22.5 or math.abs( math.deg( normalizeAngle2( angleWorldDirection - leftAngle ) )) >= 337.5 then
		direction = AutoDrive.PP_LEFT;
	elseif math.abs( math.deg( normalizeAngle2( angleWorldDirection - upLeftAngle ) )) <= 22.5 or math.abs( math.deg( normalizeAngle2( angleWorldDirection - upLeftAngle ) )) >= 337.5 then
		direction = AutoDrive.PP_UP_LEFT;
	end;

	return direction;
end;

function AutoDrivePathFinder:determineBlockedCells(pf, endDirection, cell)
    local x = cell.x;
    local z = cell.z;
	--block cells which would result in bad angles to the end/start point
	-- \|/  x|/  xx/  xxx  xxx  xxx  \xx  \|x
	-- x|x  x/-  x>-  x\-  x|x  -/x  -<x  -\x
	-- xxx  xxx  xx\  x|\  /|\  /|x  /xx  xxx
    if endDirection == AutoDrive.PP_DOWN then
        table.insert(pf.grid, {x=x-1,   z=z,      direction=-1, hasInfo=true, isRestricted=true, hasCollision=true, steps=1000})
        table.insert(pf.grid, {x=x-1,   z=z-1,    direction=-1, hasInfo=true, isRestricted=true, hasCollision=true, steps=1000})
        table.insert(pf.grid, {x=x-1,   z=z+1,    direction=-1, hasInfo=true, isRestricted=true, hasCollision=true, steps=1000})
        table.insert(pf.grid, {x=x+0,   z=z-1,    direction=-1, hasInfo=true, isRestricted=true, hasCollision=true, steps=1000})
        table.insert(pf.grid, {x=x+0,   z=z+1,    direction=-1, hasInfo=true, isRestricted=true, hasCollision=true, steps=1000})
	elseif endDirection == AutoDrive.PP_DOWN_LEFT then
        table.insert(pf.grid, {x=x-1,   z=z,      direction=-1, hasInfo=true, isRestricted=true, hasCollision=true, steps=1000})
        table.insert(pf.grid, {x=x-1,   z=z-1,    direction=-1, hasInfo=true, isRestricted=true, hasCollision=true, steps=1000})
        table.insert(pf.grid, {x=x,     z=z-1,    direction=-1, hasInfo=true, isRestricted=true, hasCollision=true, steps=1000})
        table.insert(pf.grid, {x=x-1,   z=z+1,    direction=-1, hasInfo=true, isRestricted=true, hasCollision=true, steps=1000})
        table.insert(pf.grid, {x=x+1,   z=z-1,    direction=-1, hasInfo=true, isRestricted=true, hasCollision=true, steps=1000})
	elseif endDirection == AutoDrive.PP_LEFT then
        table.insert(pf.grid, {x=x-1,   z=z-1,    direction=-1, hasInfo=true, isRestricted=true, hasCollision=true, steps=1000})
        table.insert(pf.grid, {x=x-1,   z=z+0,    direction=-1, hasInfo=true, isRestricted=true, hasCollision=true, steps=1000})
        table.insert(pf.grid, {x=x+0,   z=z-1,    direction=-1, hasInfo=true, isRestricted=true, hasCollision=true, steps=1000})
        table.insert(pf.grid, {x=x+1,   z=z+0,    direction=-1, hasInfo=true, isRestricted=true, hasCollision=true, steps=1000})
        table.insert(pf.grid, {x=x+1,   z=z-1,    direction=-1, hasInfo=true, isRestricted=true, hasCollision=true, steps=1000})
	elseif endDirection == AutoDrive.PP_UP_LEFT then
        table.insert(pf.grid, {x=x+1,   z=z+0,    direction=-1, hasInfo=true, isRestricted=true, hasCollision=true, steps=1000})
        table.insert(pf.grid, {x=x+1,   z=z-1,    direction=-1, hasInfo=true, isRestricted=true, hasCollision=true, steps=1000})
        table.insert(pf.grid, {x=x+0,   z=z-1,    direction=-1, hasInfo=true, isRestricted=true, hasCollision=true, steps=1000})
        table.insert(pf.grid, {x=x+1,   z=z+1,    direction=-1, hasInfo=true, isRestricted=true, hasCollision=true, steps=1000})
        table.insert(pf.grid, {x=x-1,   z=z-1,    direction=-1, hasInfo=true, isRestricted=true, hasCollision=true, steps=1000})
	elseif endDirection == AutoDrive.PP_UP then
        table.insert(pf.grid, {x=x+1,   z=z+0,    direction=-1, hasInfo=true, isRestricted=true, hasCollision=true, steps=1000})
        table.insert(pf.grid, {x=x+1,   z=z-1,    direction=-1, hasInfo=true, isRestricted=true, hasCollision=true, steps=1000})
        table.insert(pf.grid, {x=x+0,   z=z+1,    direction=-1, hasInfo=true, isRestricted=true, hasCollision=true, steps=1000})
        table.insert(pf.grid, {x=x+1,   z=z+1,    direction=-1, hasInfo=true, isRestricted=true, hasCollision=true, steps=1000})
        table.insert(pf.grid, {x=x+0,   z=z-1,    direction=-1, hasInfo=true, isRestricted=true, hasCollision=true, steps=1000})
	elseif endDirection == AutoDrive.PP_UP_RIGHT then
        table.insert(pf.grid, {x=x+1,   z=z+0,    direction=-1, hasInfo=true, isRestricted=true, hasCollision=true, steps=1000})
        table.insert(pf.grid, {x=x+1,   z=z+1,    direction=-1, hasInfo=true, isRestricted=true, hasCollision=true, steps=1000})
        table.insert(pf.grid, {x=x+0,   z=z+1,    direction=-1, hasInfo=true, isRestricted=true, hasCollision=true, steps=1000})
        table.insert(pf.grid, {x=x+1,   z=z-1,    direction=-1, hasInfo=true, isRestricted=true, hasCollision=true, steps=1000})
        table.insert(pf.grid, {x=x-1,   z=z+1,    direction=-1, hasInfo=true, isRestricted=true, hasCollision=true, steps=1000})
	elseif endDirection == AutoDrive.PP_RIGHT then
        table.insert(pf.grid, {x=x-1,   z=z+1,    direction=-1, hasInfo=true, isRestricted=true, hasCollision=true, steps=1000})
        table.insert(pf.grid, {x=x+1,   z=z+1,    direction=-1, hasInfo=true, isRestricted=true, hasCollision=true, steps=1000})
        table.insert(pf.grid, {x=x+0,   z=z+1,    direction=-1, hasInfo=true, isRestricted=true, hasCollision=true, steps=1000})
        table.insert(pf.grid, {x=x+1,   z=z+0,    direction=-1, hasInfo=true, isRestricted=true, hasCollision=true, steps=1000})
        table.insert(pf.grid, {x=x-1,   z=z+0,    direction=-1, hasInfo=true, isRestricted=true, hasCollision=true, steps=1000})
	elseif endDirection == AutoDrive.PP_DOWN_RIGHT then
        table.insert(pf.grid, {x=x-1,   z=z+1,    direction=-1, hasInfo=true, isRestricted=true, hasCollision=true, steps=1000})
        table.insert(pf.grid, {x=x+1,   z=z+1,    direction=-1, hasInfo=true, isRestricted=true, hasCollision=true, steps=1000})
        table.insert(pf.grid, {x=x+0,   z=z+1,    direction=-1, hasInfo=true, isRestricted=true, hasCollision=true, steps=1000})
        table.insert(pf.grid, {x=x-1,   z=z+0,    direction=-1, hasInfo=true, isRestricted=true, hasCollision=true, steps=1000})
        table.insert(pf.grid, {x=x-0,   z=z-1,    direction=-1, hasInfo=true, isRestricted=true, hasCollision=true, steps=1000})
    end;    
end;

function cellDistance(pf, cell)
    return math.sqrt(math.pow(pf.targetCell.x - cell.x, 2) + math.pow(pf.targetCell.z - cell.z,2));
end;

function AutoDrivePathFinder:drawDebugForPF(pf)	
	--if AutoDrive.drawCounter == nil then
		--AutoDrive.drawCounter = 120;
	--else
		--if AutoDrive.drawCounter <= 0 then
            --AutoDrive.drawCounter = 120;
            for _, cell in pairs(pf.grid) do
                local size = 0.3;
                local pointA = AutoDrivePathFinder:gridLocationToWorldLocation(pf, cell);
                pointA.x = pointA.x + pf.vectorX.x * size + pf.vectorZ.x * size;
                pointA.z = pointA.z + pf.vectorX.z * size + pf.vectorZ.z * size;
                pointA.y = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, pointA.x, 1, pointA.z) + 3;
                local pointB = AutoDrivePathFinder:gridLocationToWorldLocation(pf, cell);
                pointB.x = pointB.x - pf.vectorX.x * size - pf.vectorZ.x * size;
                pointB.z = pointB.z - pf.vectorX.z * size - pf.vectorZ.z * size;
                pointB.y = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, pointB.x, 1, pointB.z) + 3;
                local pointC = AutoDrivePathFinder:gridLocationToWorldLocation(pf, cell);
                pointC.x = pointC.x + pf.vectorX.x * size - pf.vectorZ.x * size;
                pointC.z = pointC.z + pf.vectorX.z * size - pf.vectorZ.z * size;
                pointC.y = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, pointC.x, 1, pointC.z) + 3;
                local pointD = AutoDrivePathFinder:gridLocationToWorldLocation(pf, cell);
                pointD.x = pointD.x - pf.vectorX.x * size + pf.vectorZ.x * size;
                pointD.z = pointD.z - pf.vectorX.z * size + pf.vectorZ.z * size;
                pointD.y = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, pointD.x, 1, pointD.z) + 3;
                
                if cell.hasInfo == true then
                    if cell.isRestricted == true then
                        AutoDrive:drawLine(pointA, pointB, 1, 0, 0, 1);
                        if cell.hasCollision == true then
                            AutoDrive:drawLine(pointC, pointD, 1, 1, 0, 1);
                        else
                            AutoDrive:drawLine(pointC, pointD, 1, 0, 1, 1);
                        end;
                    else
                        AutoDrive:drawLine(pointA, pointB, 0, 1, 0, 1);
                        if cell.hasCollision == true then
                            AutoDrive:drawLine(pointC, pointD, 1, 1, 0, 1);
                        else
                            AutoDrive:drawLine(pointC, pointD, 1, 0, 1, 1);
                        end;
                    end;
                else
                    AutoDrive:drawLine(pointA, pointB, 0, 0, 1, 1);
                    AutoDrive:drawLine(pointC, pointD, 0, 0, 1, 1);
                end;
            end;
            
            local size = 0.3;
            local pointA = AutoDrivePathFinder:gridLocationToWorldLocation(pf, pf.targetCell);
            pointA.x = pointA.x + pf.vectorX.x * size + pf.vectorZ.x * size;
            pointA.z = pointA.z + pf.vectorX.z * size + pf.vectorZ.z * size;
            pointA.y = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, pointA.x, 1, pointA.z) + 3;
            local pointB = AutoDrivePathFinder:gridLocationToWorldLocation(pf, pf.targetCell);
            pointB.x = pointB.x - pf.vectorX.x * size - pf.vectorZ.x * size;
            pointB.z = pointB.z - pf.vectorX.z * size - pf.vectorZ.z * size;
            pointB.y = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, pointB.x, 1, pointB.z) + 3;
            local pointC = AutoDrivePathFinder:gridLocationToWorldLocation(pf, pf.targetCell);
            pointC.x = pointC.x + pf.vectorX.x * size - pf.vectorZ.x * size;
            pointC.z = pointC.z + pf.vectorX.z * size - pf.vectorZ.z * size;
            pointC.y = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, pointC.x, 1, pointC.z) + 3;
            local pointD = AutoDrivePathFinder:gridLocationToWorldLocation(pf, pf.targetCell);
            pointD.x = pointD.x - pf.vectorX.x * size + pf.vectorZ.x * size;
            pointD.z = pointD.z - pf.vectorX.z * size + pf.vectorZ.z * size;
            pointD.y = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, pointD.x, 1, pointD.z) + 3;

            AutoDrive:drawLine(pointA, pointB, 1, 1, 1, 1);
            AutoDrive:drawLine(pointC, pointD, 1, 1, 1, 1);


            local pointAB = AutoDrivePathFinder:gridLocationToWorldLocation(pf, pf.targetCell);
            pointAB.y = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, pointAB.x, 1, pointAB.z) + 3;

            local pointTargetVector = AutoDrivePathFinder:gridLocationToWorldLocation(pf, pf.targetCell);
            pointTargetVector.x = pointTargetVector.x + pf.targetVector.x * 10;
            pointTargetVector.z = pointTargetVector.z + pf.targetVector.z * 10;
            pointTargetVector.y = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, pointTargetVector.x, 1, pointTargetVector.z) + 3;
            AutoDrive:drawLine(pointAB, pointTargetVector, 1, 1, 1, 1);

		--else
			--AutoDrive.drawCounter = AutoDrive.drawCounter - 1;
		--end;
	--end;
end;