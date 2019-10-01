AutoDrive.COMBINE_UNINITIALIZED = 0;
AutoDrive.WAIT_FOR_COMBINE = 1;
AutoDrive.DRIVE_TO_COMBINE = 2;
AutoDrive.WAIT_TILL_UNLOADED = 3;
AutoDrive.DRIVE_TO_PARK_POS = 4;
AutoDrive.DRIVE_TO_START_POS = 5;
AutoDrive.DRIVE_TO_UNLOAD_POS = 6;
AutoDrive.PREDRIVE_COMBINE = 7;
AutoDrive.CHASE_COMBINE = 8;
AutoDrive.UNLOAD_WAIT_TIMER = 15000;

function AutoDrive:handleCombineHarvester(vehicle, dt)    
    if vehicle.ad.currentDriver ~= nil and (not vehicle.ad.preCalledDriver) then
        vehicle.ad.driverOnTheWay = true;
        vehicle.ad.tryingToCallDriver = false;
        if (vehicle.ad.currentDriver.ad.combineUnloadInFruitWaitTimer >= AutoDrive.UNLOAD_WAIT_TIMER) then
            if vehicle.cp and vehicle.cp.driver and vehicle.cp.driver.holdForUnloadOrRefill then
                vehicle.cp.driver:holdForUnloadOrRefill();
            end;
        end;
        return;
    end;

    vehicle.ad.driverOnTheWay = false;     
    vehicle.ad.tryingToCallDriver = false;  

    if vehicle.spec_dischargeable ~= nil and vehicle.ad.currentDriver == nil then
        local fillLevel, leftCapacity = getFilteredFillLevelAndCapacityOfAllUnits(vehicle);
        local maxCapacity = fillLevel + leftCapacity;

        local cpIsCalling = false;
        if vehicle.cp and vehicle.cp.driver and vehicle.cp.driver.isWaitingForUnload then
            cpIsCalling = vehicle.cp.driver:isWaitingForUnload();
        end;

        if (((maxCapacity > 0 and leftCapacity <= 1.0) or cpIsCalling) and vehicle.ad.stoppedTimer <= 0) then
            vehicle.ad.tryingToCallDriver = true;  
            AutoDrive:callDriverToCombine(vehicle);  
        elseif ((fillLevel / maxCapacity) >= AutoDrive:getSetting("preCallLevel") or vehicle:getIsBufferCombine()) and (not vehicle.ad.preCalledDriver) and AutoDrive:getSetting("preCallDriver") then
            vehicle.ad.tryingToCallDriver = true;  
            AutoDrive:preCallDriverToCombine(vehicle);
        end;
    end;    
end;

function AutoDrive:callDriverToCombine(combine)
    local spec = combine.spec_pipe
    if spec.currentState == spec.targetState and (spec.currentState == 2 or combine.typeName == "combineCutterFruitPreparer") then
        
        local worldX,worldY,worldZ = getWorldTranslation( combine.components[1].node );

        for _,dischargeNode in pairs(combine.spec_dischargeable.dischargeNodes) do
            local nodeX,nodeY,nodeZ = getWorldTranslation( dischargeNode.node );
            if ADTableLength(AutoDrive.waitingUnloadDrivers) > 0 then
                local closestDriver = nil;
                local closestDistance = math.huge;
                for _,driver in pairs(AutoDrive.waitingUnloadDrivers) do
                    local driverX, driverY, driverZ = getWorldTranslation( driver.components[1].node );
                    local distance = math.sqrt( math.pow((driverX-worldX),2) + math.pow((driverZ - worldZ), 2));
                    
                    if distance < closestDistance and ((distance < 300 and AutoDrive:getSetting("findDriver") == true) or (driver.ad.targetSelected == combine.ad.targetSelected)) then
                        closestDistance = distance;
                        closestDriver = driver;							
                    end;
                end;

                if closestDriver ~= nil then                    		
                    AutoDrivePathFinder:startPathPlanningToCombine(closestDriver, combine, dischargeNode.node);
                    closestDriver.ad.currentCombine = combine;
                    AutoDrive.waitingUnloadDrivers[closestDriver] = nil;
                    closestDriver.ad.combineState = AutoDrive.DRIVE_TO_COMBINE;
                    combine.ad.currentDriver = closestDriver;
                    closestDriver.ad.isPaused = false;
                    closestDriver.ad.isUnloading = false;
                    closestDriver.ad.isLoading = false;
                    closestDriver.ad.initialized = false 
                    closestDriver.ad.designatedTrailerFillLevel = math.huge;
                    closestDriver.ad.wayPoints = {};        
                    
                    combine.ad.tryingToCallDriver = false; 
                    combine.ad.driverOnTheWay = true;
                    combine.ad.preCalledDriver = false;
                end;
            end;
        end;
    else
        combine.ad.tryingToCallDriver = true;    
    end;
end;

function AutoDrive:preCallDriverToCombine(combine)        
    local worldX,worldY,worldZ = getWorldTranslation( combine.components[1].node );
    
    if ADTableLength(AutoDrive.waitingUnloadDrivers) > 0 then
        local closestDriver = nil;
        local closestDistance = math.huge;
        for _,driver in pairs(AutoDrive.waitingUnloadDrivers) do
            local driverX, driverY, driverZ = getWorldTranslation( driver.components[1].node );
            local distance = math.sqrt( math.pow((driverX-worldX),2) + math.pow((driverZ - worldZ), 2));
            
            if distance < closestDistance and ((distance < 300 and AutoDrive:getSetting("findDriver") == true) or (driver.ad.targetSelected == combine.ad.targetSelected)) then
                closestDistance = distance;
                closestDriver = driver;							
            end;
        end;

        if closestDriver ~= nil then                    		
            AutoDrivePathFinder:startPathPlanningToCombine(closestDriver, combine, nil);
            closestDriver.ad.currentCombine = combine;
            AutoDrive.waitingUnloadDrivers[closestDriver] = nil;
            closestDriver.ad.combineState = AutoDrive.PREDRIVE_COMBINE;
            combine.ad.currentDriver = closestDriver;
            closestDriver.ad.isPaused = false;
            closestDriver.ad.isUnloading = false;
            closestDriver.ad.isLoading = false;
            closestDriver.ad.initialized = false 
            closestDriver.ad.designatedTrailerFillLevel = math.huge;
            closestDriver.ad.wayPoints = {};        
            
            combine.ad.tryingToCallDriver = false; 
            combine.ad.driverOnTheWay = true;
            combine.ad.preCalledDriver = true;
        end;
    end;
end;

function AutoDrive:combineIsCallingDriver(combine)
    return (combine.ad ~= nil) and ((combine.ad.tryingToCallDriver and ADTableLength(AutoDrive.waitingUnloadDrivers) > 0) or combine.ad.driverOnTheWay);
end;

function AutoDrive:handleReachedWayPointCombine(vehicle)
    if vehicle.ad.combineState == AutoDrive.COMBINE_UNINITIALIZED then --register Driver as available unloader if target point is reached (Hopefully field position!)
        --print("Registering " .. vehicle.ad.driverName .. " as driver");
        AutoDrive.waitingUnloadDrivers[vehicle] = vehicle;
        vehicle.ad.combineState = AutoDrive.WAIT_FOR_COMBINE;
        vehicle.ad.isPaused = true;
        vehicle.ad.wayPoints = {};
    elseif vehicle.ad.combineState == AutoDrive.DRIVE_TO_COMBINE then
        vehicle.ad.combineState = AutoDrive.WAIT_TILL_UNLOADED;
        vehicle.ad.initialized = false;
        vehicle.ad.wayPoints = {};
        vehicle.ad.isPaused = true;
    elseif vehicle.ad.combineState == AutoDrive.DRIVE_TO_PARK_POS then
        AutoDrive.waitingUnloadDrivers[vehicle] = vehicle;
        vehicle.ad.combineState = AutoDrive.WAIT_FOR_COMBINE;
        vehicle.ad.wayPoints = {};
        vehicle.ad.isPaused = true;
        if vehicle.ad.currentCombine ~= nil then
            vehicle.ad.currentCombine.ad.currentDriver = nil;            
		    vehicle.ad.currentCombine.ad.preCalledDriver = false;
		    vehicle.ad.currentCombine.ad.driverOnTheWay = false;
            vehicle.ad.currentCombine = nil;
        end;
    elseif vehicle.ad.combineState == AutoDrive.DRIVE_TO_START_POS then        
        AutoDrive:sendCombineUnloaderToStartOrToUnload(vehicle, false);
    elseif vehicle.ad.combineState == AutoDrive.DRIVE_TO_UNLOAD_POS then
        AutoDrive:sendCombineUnloaderToStartOrToUnload(vehicle, true);
    elseif vehicle.ad.combineState == AutoDrive.PREDRIVE_COMBINE then
        if AutoDrive:getSetting("chaseCombine") then
            vehicle.ad.wayPoints = {};
            vehicle.ad.combineState = AutoDrive.CHASE_COMBINE;
            vehicle.ad.initialized = false;
            --print("Switching to chasing combine");
        else
            AutoDrive.waitingUnloadDrivers[vehicle] = vehicle;
            vehicle.ad.combineState = AutoDrive.WAIT_FOR_COMBINE;
            vehicle.ad.wayPoints = {};
            vehicle.ad.isPaused = true;
            if vehicle.ad.currentCombine ~= nil then
                vehicle.ad.currentCombine.ad.currentDriver = nil;
                vehicle.ad.currentCombine.ad.preCalledDriver = false;
                vehicle.ad.currentCombine.ad.driverOnTheWay = false;
                vehicle.ad.currentCombine = nil;
            end;
        end;
    end;
end;

function AutoDrive:initializeADCombine(vehicle, dt)   
    if vehicle.ad.wayPoints == nil or vehicle.ad.wayPoints[1] == nil then
        vehicle.ad.initialized = false;
        vehicle.ad.timeTillDeadLock = 15000;        
        vehicle.ad.inDeadLock = false;

        if vehicle.ad.combineState == AutoDrive.DRIVE_TO_COMBINE or vehicle.ad.combineState == AutoDrive.PREDRIVE_COMBINE or vehicle.ad.combineState == AutoDrive.DRIVE_TO_START_POS or vehicle.ad.combineState == AutoDrive.DRIVE_TO_PARK_POS then
            return not AutoDrive:handlePathPlanning(vehicle, dt)
        elseif vehicle.ad.combineState == AutoDrive.WAIT_TILL_UNLOADED then
            local doneUnloading, trailerFillLevel = AutoDrive:checkDoneUnloading(vehicle);
            local trailers, trailerCount = AutoDrive:getTrailersOf(vehicle); 
            vehicle.ad.trailerCount = trailerCount;
            vehicle.ad.trailerFillLevel = trailerFillLevel;

            if trailers[vehicle.ad.currentTrailer+1] ~= nil then
                local lastFillLevel = vehicle.ad.designatedTrailerFillLevel;
                                
                local fillLevel, leftCapacity = getFilteredFillLevelAndCapacityOfAllUnits(trailers[vehicle.ad.currentTrailer+1]);
                local maxCapacity = fillLevel + leftCapacity;
                
                vehicle.ad.designatedTrailerFillLevel = (maxCapacity - leftCapacity)/maxCapacity;

                if lastFillLevel < vehicle.ad.designatedTrailerFillLevel then
                    --print("lastFillLevel: " .. lastFillLevel .. " designated: " .. vehicle.ad.designatedTrailerFillLevel .. " currentTrailer: " .. vehicle.ad.currentTrailer .. " trailerCount: " .. trailerCount);
                    vehicle.ad.currentTrailer = vehicle.ad.currentTrailer + 1;
                    --Reload trailerFillLevel when switching to next trailer
                    doneUnloading, trailerFillLevel = AutoDrive:checkDoneUnloading(vehicle);
                end;
            end;

            local drivingEnabled = false;
            if trailerFillLevel > 0.99 and vehicle.ad.currentTrailer < trailerCount then
                local finalSpeed = 8;
                local acc = 1;
                local allowedToDrive = true;
                
                local x,y,z = getWorldTranslation(vehicle.components[1].node);   
                local rx,ry,rz = localDirectionToWorld(vehicle.components[1].node, 0,0,1);	
                x = x + rx;
                z = z + rz;
                local lx, lz = AIVehicleUtil.getDriveDirection(vehicle.components[1].node, x, y, z);
                AIVehicleUtil.driveInDirection(vehicle, dt, 30, acc, 0.2, 20, allowedToDrive, true, nil, nil, finalSpeed, 1);
                drivingEnabled = true;
            end;

            if (doneUnloading or (vehicle.ad.combineUnloadInFruitWaitTimer < AutoDrive.UNLOAD_WAIT_TIMER)) or (trailerFillLevel >= 0.99 and vehicle.ad.currentTrailer == trailerCount) then
                
                --wait for combine to move away. Currently by fixed timer of 15s
                if vehicle.ad.combineUnloadInFruitWaitTimer > 0 then
                    vehicle.ad.combineUnloadInFruitWaitTimer = vehicle.ad.combineUnloadInFruitWaitTimer - dt;
                    if vehicle.ad.combineUnloadInFruitWaitTimer > 10500 then
                        local finalSpeed = 9;
                        local acc = 1;
                        local allowedToDrive = true;
                        
                        local node = vehicle.components[1].node;					
                        if vehicle.getAIVehicleDirectionNode ~= nil then
                            node = vehicle:getAIVehicleDirectionNode();
                        end;
                        local x,y,z = getWorldTranslation(vehicle.components[1].node);   
                        local rx,ry,rz = localDirectionToWorld(vehicle.components[1].node, 0,0,-1);	
                        x = x + rx;
                        z = z + rz;
                        local lx, lz = AIVehicleUtil.getDriveDirection(vehicle.components[1].node, x, y, z);
                        AIVehicleUtil.driveInDirection(vehicle, dt, 30, acc, 0.2, 20, allowedToDrive, false, nil, nil, finalSpeed, 1);
                        drivingEnabled = true;
                    else
                        AutoDrive:getVehicleToStop(vehicle, false, dt);
                    end;

                    return true;
                end;                

                if trailerFillLevel > AutoDrive:getSetting("unloadFillLevel", vehicle) or vehicle.ad.combineUnloadInFruit == true or (AutoDrive:getSetting("parkInField", vehicle) == false) then
                    if trailerFillLevel > AutoDrive:getSetting("unloadFillLevel", vehicle) then
                        vehicle.ad.combineState = AutoDrive.DRIVE_TO_START_POS;
                    else
                        vehicle.ad.combineState = AutoDrive.DRIVE_TO_PARK_POS;
                    end;
                    AutoDrivePathFinder:startPathPlanningToStartPosition(vehicle, vehicle.ad.currentCombine);
                    if vehicle.ad.currentCombine ~= nil then
                        vehicle.ad.currentCombine.ad.currentDriver = nil;
                        vehicle.ad.currentCombine.ad.preCalledDriver = false;
                        vehicle.ad.currentCombine.ad.driverOnTheWay = false;
                        vehicle.ad.currentCombine = nil;
                    end;
                else
                    --wait in field                        
                    AutoDrive.waitingUnloadDrivers[vehicle] = vehicle;
                    vehicle.ad.combineState = AutoDrive.WAIT_FOR_COMBINE;
                    --vehicle.ad.initialized = false;
                    vehicle.ad.wayPoints = {};
                    vehicle.ad.isPaused = true;
                    if vehicle.ad.currentCombine ~= nil then
                        vehicle.ad.currentCombine.ad.currentDriver = nil;
                        vehicle.ad.currentCombine.ad.preCalledDriver = false;
                        vehicle.ad.currentCombine.ad.driverOnTheWay = false;
                        vehicle.ad.currentCombine = nil;
                    end;
                end;
            end;
            
            if drivingEnabled == false then
                AutoDrive:getVehicleToStop(vehicle, false, dt);
            end;

            return true;          
        
        elseif vehicle.ad.combineState == AutoDrive.CHASE_COMBINE then
            AutoDrive:chaseCombine(vehicle, dt);
            return true;
        end;        
    end; 

    return false;
end;

function AutoDrive:chaseCombine(vehicle, dt)
    local keepFollowing = true;
    local pauseFollowing = false;
    local combine = vehicle.ad.currentCombine;  

    local combineWorldX, combineWorldY, combineWorldZ = getWorldTranslation( combine.components[1].node );    
    local worldX,worldY,worldZ = getWorldTranslation( vehicle.components[1].node );

    local angleToCombineHeading = AutoDrive:getAngleToCombineHeading(vehicle, combine);
    if vehicle.ad.combineHeadingDiff == nil then
        vehicle.ad.combineHeadingDiff = AutoDriveTON:new();
    end;
    if vehicle.ad.combineHeadingDiff:timer((angleToCombineHeading > 20), 5000, dt) then        
        --print("Chasing combine - stopped - angleToCombineHeading > 20");
        keepFollowing = false;
    end;
    
    local combineSpeed = combine.lastSpeedReal;
    --if combineSpeed < 0 then
        --pauseFollowing = true;
    --end;
    
    local isChopper = combine:getIsBufferCombine()
    local leftBlocked = combine.ad.sensors.leftSensorFruit:pollInfo() or combine.ad.sensors.leftSensor:pollInfo();
    local rightBlocked = combine.ad.sensors.rightSensorFruit:pollInfo() or combine.ad.sensors.rightSensor:pollInfo();
    local chasePos = AutoDrive:getPipeChasePosition(vehicle, combine, isChopper, leftBlocked, rightBlocked);
    if leftBlocked and (not isChopper) then
        chasePos = AutoDrive:getCombineChasePosition(vehicle, combine);
    end;

    local distanceToCombine = MathUtil.vector2Length(combineWorldX - worldX, combineWorldZ - worldZ);
    local distanceToChasePos = MathUtil.vector2Length(chasePos.x - worldX, chasePos.z - worldZ);
    
    --pause if angle to chasepos is too high -> probably a switch between chase positions. Let's see if combine keeps driving on and the angle is fine again
    if getAngleToChasePos(vehicle, chasePos) > 60 then
        pauseFollowing = true;
        if combineSpeed < 0.0008 then --no, if combine is stopping, we have to fallback to pathfinding
            keepFollowing = false;
        end;
    end;

    if distanceToChasePos > 60 then
        --print("Chasing combine - stopped - distanceToChasePos > 60");
        keepFollowing = false;
    end;

    if vehicle.ad.sensors.frontSensor:pollInfo() then
        --print("Traffic collision triggered - pausing");
        pauseFollowing = true;
    end;

    local fillLevel, leftCapacity = getFilteredFillLevelAndCapacityOfAllUnits(combine);
    local maxCapacity = fillLevel + leftCapacity;
    local combineFillLevel = (fillLevel / maxCapacity);

    if (combineFillLevel >= 0.98 or combine.ad.noMovementTimer.elapsedTime > 10000) and (not isChopper) then
        --print("Chasing combine - stopped - park in Field now");
        AutoDrive:getVehicleToStop(vehicle, false, dt);

        AutoDrive.waitingUnloadDrivers[vehicle] = vehicle;
        vehicle.ad.combineState = AutoDrive.WAIT_FOR_COMBINE;
        vehicle.ad.wayPoints = {};
        vehicle.ad.isPaused = true;
        if vehicle.ad.currentCombine ~= nil then
            vehicle.ad.currentCombine.ad.currentDriver = nil;
            vehicle.ad.currentCombine.ad.preCalledDriver = false;
            vehicle.ad.currentCombine.ad.driverOnTheWay = false;
            vehicle.ad.currentCombine = nil;
        end;

        return;
    end;

    if AutoDrive:combineIsTurning(vehicle, combine, isChopper) then        
        --print("Chasing combine - stopped - combineIsTurning");
        pauseFollowing = true;
    end;

    if (not pauseFollowing) and keepFollowing then
        --print("Chasing combine")
        local x1,y1,z1 = getWorldTranslation(vehicle.components[1].node);
        --AutoDrive:drawLine(AutoDrive:createVector(x1,y1+3.5-AutoDrive:getSetting("lineHeight"),z1), chasePos, 1, 0, 0, 1);
        
        local finalSpeed = 25;
        local acc = 1;
        local allowedToDrive = true;

        if distanceToChasePos < 5 then
            finalSpeed = (combine.lastSpeedReal * 3600);
        end;

        local lx, lz = AIVehicleUtil.getDriveDirection(vehicle.components[1].node, chasePos.x, chasePos.y, chasePos.z);
        AIVehicleUtil.driveInDirection(vehicle, dt, 30, acc, 0.2, 20, allowedToDrive, true, lx, lz, finalSpeed, 1);
        drivingEnabled = true;
    else    
        if pauseFollowing and keepFollowing then
            if vehicle.ad.reverseTimer == nil then
                vehicle.ad.reverseTimer = 0;
            end;
            if vehicle.ad.reverseTimer < 2000 or distanceToCombine < 10 then
                --print("Reversing from combine")
                --print("Chasing combine - paused")
                --AutoDrive:getVehicleToStop(vehicle, false, dt);
                --reverse a little to make room for turn maneuvers
                local finalSpeed = 9;
                local acc = 1;
                local allowedToDrive = true;
                
                local node = vehicle.components[1].node;					
                if vehicle.getAIVehicleDirectionNode ~= nil then
                    node = vehicle:getAIVehicleDirectionNode();
                end;
                local x,y,z = getWorldTranslation(vehicle.components[1].node);   
                local rx,ry,rz = localDirectionToWorld(vehicle.components[1].node, 0,0,-1);	
                x = x + rx;
                z = z + rz;
                local lx, lz = AIVehicleUtil.getDriveDirection(vehicle.components[1].node, x, y, z);
                AIVehicleUtil.driveInDirection(vehicle, dt, 30, acc, 0.2, 20, allowedToDrive, false, nil, nil, finalSpeed, 1);
                drivingEnabled = true;
                vehicle.ad.reverseTimer = vehicle.ad.reverseTimer + dt;
            else
                AutoDrive:getVehicleToStop(vehicle, false, dt);
                keepFollowing = false;
            end;
        else
            AutoDrive:getVehicleToStop(vehicle, false, dt);
        end;
    end;

    local doneUnloading, trailerFillLevel = AutoDrive:checkDoneUnloading(vehicle);
    if trailerFillLevel > AutoDrive:getSetting("unloadFillLevel", vehicle) then
        vehicle.ad.combineState = AutoDrive.DRIVE_TO_START_POS;
        AutoDrivePathFinder:startPathPlanningToStartPosition(vehicle, vehicle.ad.currentCombine);
        if vehicle.ad.currentCombine ~= nil then
            vehicle.ad.currentCombine.ad.currentDriver = nil;
            vehicle.ad.currentCombine.ad.preCalledDriver = false;
            vehicle.ad.currentCombine.ad.driverOnTheWay = false;
            vehicle.ad.currentCombine = nil;
            return;
        end;
    end;   
    
    if keepFollowing == false then
        --print("Chasing combine - stopped - recalculating new path when combine ready")
        AutoDrive:getVehicleToStop(vehicle, false, dt);
        local pausedForSomeTime = vehicle.ad.noMovementTimer:done();
        if ((not AutoDrive:combineIsTurning(vehicle, combine, isChopper)) and pausedForSomeTime) or (vehicle.ad.noMovementTimer.elapsedTime > 15000) then
            --print("Chasing combine - stopped - recalculating new path");
            AutoDrivePathFinder:startPathPlanningToCombine(vehicle, combine, nil);
            vehicle.ad.currentCombine = combine;
            AutoDrive.waitingUnloadDrivers[vehicle] = nil;
            vehicle.ad.combineState = AutoDrive.PREDRIVE_COMBINE;
            vehicle.ad.reverseTimer = 0;
            vehicle.ad.combineHeadingDiff:timer(false);
        end;
    end;
end;

function AutoDrive:combineIsTurning(vehicle, combine, isChopper)
    local cpIsTurning = combine.cp ~= nil and (combine.cp.isTurning or (combine.cp.turnStag ~= nil and combine.cp.turnStage > 0)) ;
    local aiIsTurning = (combine.getAIIsTurning ~= nil and combine:getAIIsTurning() == true);
    local combineSteering = combine.rotatedTime ~= nil and (math.deg(combine.rotatedTime) > 10);
    local combineIsTurning = cpIsTurning or aiIsTurning or combineSteering;    
    --print("cpIsTurning: " .. ADBoolToString(cpIsTurning) .. " aiIsTurning: " .. ADBoolToString(aiIsTurning) .. " combineSteering: " .. ADBoolToString(combineSteering) .. " isChopper: " .. ADBoolToString(isChopper) .. " combine.ad.driveForwardTimer:done(): " .. ADBoolToString(combine.ad.driveForwardTimer:done()));
    if (combine.ad.driveForwardTimer:done() or isChopper) and (not combineIsTurning) then
       return false;
    end;
    return true;
end;

function AutoDrive:getPipeChasePosition(vehicle, combine, isChopper, leftBlocked, rightBlocked)    
    local worldX,worldY,worldZ = getWorldTranslation( combine.components[1].node );
	local rx,ry,rz = localDirectionToWorld(combine.components[1].node, 0,0,1);	
    local combineVector = {x= rx ,z= rz};	
    local combineNormalVector = {x= -combineVector.z ,z= combineVector.x};	
    local nodeX,nodeY,nodeZ = worldX, worldY, worldZ;
    if isChopper and (not leftBlocked) then
        --print("Taking left side");
        nodeX,nodeY,nodeZ = worldX - combineNormalVector.x * 8, worldY, worldZ - combineNormalVector.z * 8;
    elseif isChopper and (not rightBlocked) then
        --print("Taking right side");
        nodeX,nodeY,nodeZ = worldX + combineNormalVector.x * 8, worldY, worldZ + combineNormalVector.z * 8;
    elseif isChopper then
        --print("Taking rear side");
        nodeX,nodeY,nodeZ = worldX - combineVector.x * 6, worldY, worldZ - combineVector.z * 6;
    else        
        nodeX,nodeY,nodeZ = worldX - combineNormalVector.x * 9, worldY, worldZ - combineNormalVector.z * 9; --default aim left on combine harvesters
        local spec = combine.spec_pipe
        if (spec.currentState == spec.targetState and (spec.currentState == 2 or combine.typeName == "combineCutterFruitPreparer")) and (not isChopper) then
            local dischargeNode = nil;
            for _,dischargeNodeIter in pairs(combine.spec_dischargeable.dischargeNodes) do
                dischargeNode = dischargeNodeIter;
            end;
        
            local pipeOffset = AutoDrive:getSetting("pipeOffset", vehicle);     
            local trailerOffset = AutoDrive:getSetting("trailerOffset", vehicle);

            nodeX,nodeY,nodeZ = getWorldTranslation( dischargeNode.node );
            nodeX,nodeY,nodeZ = (nodeX + (vehicle.sizeLength/2 + 8 + trailerOffset)*rx) - pipeOffset * combineNormalVector.x, nodeY, nodeZ + (vehicle.sizeLength/2 + 8 + trailerOffset)*rz  - pipeOffset * combineNormalVector.z;
        end;
    end;

    return {x= nodeX, y = nodeY, z = nodeZ};
end;

function AutoDrive:getCombineChasePosition(vehicle, combine)    
    local worldX,worldY,worldZ = getWorldTranslation( combine.components[1].node );
	local rx,ry,rz = localDirectionToWorld(combine.components[1].node, 0,0,1);	
    local combineVector = {x= rx ,z= rz};	
       
    return {x= worldX - (AutoDrive.PATHFINDER_FOLLOW_DISTANCE-35)*rx, y = worldY, z = worldZ + (AutoDrive.PATHFINDER_FOLLOW_DISTANCE-35)*rz};
end;

function AutoDrive:getAngleToCombineHeading(vehicle, combine)
    if vehicle == nil or combine == nil then
        return math.huge;
    end;

    local combineWorldX, combineWorldY, combineWorldZ = getWorldTranslation( combine.components[1].node );
    local combineRx, combineRy, combineRz = localDirectionToWorld(combine.components[1].node, 0,0,1);	
    
    local worldX,worldY,worldZ = getWorldTranslation( vehicle.components[1].node );
    local rx,ry,rz = localDirectionToWorld(vehicle.components[1].node, 0,0,1);	

    return math.abs(AutoDrive:angleBetween( {x=rx, z=rz}, {x=combineRx, z=combineRz} ));
end;

function AutoDrive:getAngleToChasePos(vehicle, chasePos) {
    if vehicle == nil or chasePos == nil then
        return math.huge;
    end;

    local worldX,worldY,worldZ = getWorldTranslation( vehicle.components[1].node );
    local rx,ry,rz = localDirectionToWorld(vehicle.components[1].node, 0,0,1);	

    return math.abs(AutoDrive:angleBetween( {x=rx, z=rz}, {x=chasePos.x - worldX, z=chasePos.z - worldZ} ));
}

function AutoDrive:handlePathPlanning(vehicle, dt)
    local storedPathFinderTime = AutoDrive.settings["pathFinderTime"].current;
    if vehicle.ad.combineState == AutoDrive.PREDRIVE_COMBINE then
        AutoDrive.settings["pathFinderTime"].current = 2;
    end;
    AutoDrivePathFinder:updatePathPlanning(vehicle);
    if vehicle.ad.combineState == AutoDrive.PREDRIVE_COMBINE then
        AutoDrive.settings["pathFinderTime"].current = storedPathFinderTime;
    end;

    if AutoDrivePathFinder:isPathPlanningFinished(vehicle) then
        vehicle.ad.wayPoints = vehicle.ad.pf.wayPoints;
        vehicle.ad.currentWayPoint = 1;

        if vehicle.ad.combineState == AutoDrive.PREDRIVE_COMBINE then
            if #vehicle.ad.wayPoints <= 1 then
                vehicle.ad.wayPoints = nil;
                if vehicle.ad.waitForPreDriveTimer <= 0 then
                    if not AutoDrive:restartPathFinder(vehicle) then
                        return true; --error
                    end;
                else
                    vehicle.ad.waitForPreDriveTimer = vehicle.ad.waitForPreDriveTimer - dt;
                end;
                return false;
            end;
        end;

        return true
    end;
    return false;
end;

function AutoDrive:restartPathFinder(vehicle)
    local combine = vehicle.ad.currentCombine;
    if combine == nil then
        return false;
    end;
    AutoDrivePathFinder:startPathPlanningToCombine(vehicle, combine, nil);
    vehicle.ad.currentCombine = combine;
    AutoDrive.waitingUnloadDrivers[vehicle] = nil;
    vehicle.ad.combineState = AutoDrive.PREDRIVE_COMBINE;
    return true;
end;

function AutoDrive:checkDoneUnloading(vehicle)
    local trailers, trailerCount = AutoDrive:getTrailersOf(vehicle);  
    local fillLevel, leftCapacity = getFilteredFillLevelAndCapacityOfAllUnits(trailers[vehicle.ad.currentTrailer]);
    local maxCapacity = fillLevel + leftCapacity;      

    local combineFillLevel, combineLeftCapacity = getFilteredFillLevelAndCapacityOfAllUnits(vehicle.ad.currentCombine);
    local combineMaxCapacity = combineFillLevel + combineLeftCapacity;       

    return ((combineMaxCapacity - combineLeftCapacity) < 100) , (1-(leftCapacity/maxCapacity));
end;

function AutoDrive:combineStateToDescription(vehicle)
    if vehicle.ad.combineState == AutoDrive.WAIT_FOR_COMBINE then
        return g_i18n:getText('ad_wait_for_combine');
    elseif vehicle.ad.combineState == AutoDrive.DRIVE_TO_COMBINE or vehicle.ad.combineState == AutoDrive.PREDRIVE_COMBINE then
        return g_i18n:getText('ad_drive_to_combine');
    elseif vehicle.ad.combineState == AutoDrive.WAIT_TILL_UNLOADED then
        return g_i18n:getText('ad_unloading_combine');
    elseif vehicle.ad.combineState == AutoDrive.DRIVE_TO_PARK_POS then
        return g_i18n:getText('ad_drive_to_parkpos');
    elseif vehicle.ad.combineState == AutoDrive.DRIVE_TO_START_POS then
        return g_i18n:getText('ad_drive_to_startpos');
    elseif vehicle.ad.combineState == AutoDrive.DRIVE_TO_UNLOAD_POS then
        return g_i18n:getText('ad_drive_to_unloadpos');
    end

    return;
end;

function AutoDrive:isOnField(vehicle)
    if vehicle ~= nil and vehicle.ad ~= nil and vehicle.ad.combineState ~= nil then
        if vehicle.ad.combineState == AutoDrive.DRIVE_TO_COMBINE or vehicle.ad.combineState == AutoDrive.PREDRIVE_COMBINE or vehicle.ad.combineState == AutoDrive.DRIVE_TO_PARK_POS or vehicle.ad.combineState == AutoDrive.DRIVE_TO_START_POS  then
            return true;
        end;
    end;

    return false;
end;

function AutoDrive:sendCombineUnloaderToStartOrToUnload(vehicle, toStart)
    if vehicle == nil then
        return;
    end;

    local closest = AutoDrive:findClosestWayPoint(vehicle);
    vehicle.ad.wayPointsChanged = true;

    if toStart == false then --going to unload position
        vehicle.ad.wayPoints = AutoDrive:FastShortestPath(AutoDrive.mapWayPoints, closest, AutoDrive.mapMarker[vehicle.ad.mapMarkerSelected_Unload].name, AutoDrive.mapMarker[vehicle.ad.mapMarkerSelected_Unload].id);   
        AutoDrive.waitingUnloadDrivers[vehicle] = nil;
        vehicle.ad.combineState = AutoDrive.DRIVE_TO_UNLOAD_POS;
    else --going to start position
        vehicle.ad.timeTillDeadLock = 15000;
        if vehicle.ad.wayPoints[vehicle.ad.currentWayPoint] ~= nil then --Don't search starting waypoint if we were already driving to the unload pos. Just use this point.
            closest = vehicle.ad.wayPoints[vehicle.ad.currentWayPoint].id;
        end;
        vehicle.ad.wayPoints = AutoDrive:FastShortestPath(AutoDrive.mapWayPoints, closest, AutoDrive.mapMarker[vehicle.ad.mapMarkerSelected].name, vehicle.ad.targetSelected);
        vehicle.ad.isPaused = true;                    
        vehicle.ad.combineState = AutoDrive.COMBINE_UNINITIALIZED;        
        vehicle.ad.currentTrailer = 1;
        vehicle.ad.designatedTrailerFillLevel = math.huge;
    end;
    
    vehicle.ad.currentWayPoint = 1;
    vehicle.ad.targetX = vehicle.ad.wayPoints[vehicle.ad.currentWayPoint].x;
    vehicle.ad.targetZ = vehicle.ad.wayPoints[vehicle.ad.currentWayPoint].z;
    if vehicle.ad.currentCombine ~= nil then
        vehicle.ad.currentCombine.ad.currentDriver = nil;
		vehicle.ad.currentCombine.ad.preCalledDriver = false;
		vehicle.ad.currentCombine.ad.driverOnTheWay = false;
        vehicle.ad.currentCombine = nil;
    end;
end;

function AutoDrive:checkIfShortcutToCombinePossible(vehicle, dt)
    if vehicle.ad.checkShortcutTimer == nil then
        vehicle.ad.checkShortcutTimer = AutoDriveTON:new();
    end;

    vehicle.ad.checkShortcutTimer:timer(true, 5000, dt);

    if vehicle.ad.checkShortcutTimer:done() then
        vehicle.ad.checkShortcutTimer:timer(false);    

        AutoDrivePathFinder:startPathPlanningToCombine(closestDriver, combine, nil);
        AutoDrivePathFinder:updatePathPlanning(vehicle);
        if AutoDrivePathFinder:isPathPlanningFinished(vehicle) then
            vehicle.ad.wayPoints = vehicle.ad.pf.wayPoints;
            vehicle.ad.currentWayPoint = 1;

            if vehicle.ad.combineState == AutoDrive.PREDRIVE_COMBINE then
                if #vehicle.ad.wayPoints <= 1 then
                    vehicle.ad.wayPoints = nil;
                    if vehicle.ad.waitForPreDriveTimer <= 0 then
                        if not AutoDrive:restartPathFinder(vehicle) then
                            return true; --error
                        end;
                    else
                        vehicle.ad.waitForPreDriveTimer = vehicle.ad.waitForPreDriveTimer - dt;
                    end;
                    return false;
                end;
            end;

            return true
        end;
    end;
end;