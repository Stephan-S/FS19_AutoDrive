AutoDrive.COMBINE_UNINITIALIZED = 0;
AutoDrive.WAIT_FOR_COMBINE = 1;
AutoDrive.DRIVE_TO_COMBINE = 2;
AutoDrive.WAIT_TILL_UNLOADED = 3;
AutoDrive.DRIVE_TO_PARK_POS = 4;
AutoDrive.DRIVE_TO_START_POS = 5;
AutoDrive.DRIVE_TO_UNLOAD_POS = 6;
AutoDrive.UNLOAD_WAIT_TIMER = 15000;

function AutoDrive:handleCombineHarvester(vehicle, dt)    
    if vehicle.ad.currentDriver ~= nil then
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

    if vehicle.spec_dischargeable ~= nil then
        local leftCapacity = 0;
        local maxCapacity = 0;
        if vehicle.getFillUnits ~= nil then
            for fillUnitIndex,fillUnit in pairs(vehicle:getFillUnits()) do
                local fillTypeIsProhibited = false;
                for fillType, isSupported in pairs(vehicle:getFillUnitSupportedFillTypes(fillUnitIndex)) do
                    if fillType == 1 or fillType == 34  then
                        fillTypeIsProhibited = true;
                    end;
                end;

                if vehicle:getFillUnitCapacity(fillUnitIndex) > 1500 and (not fillTypeIsProhibited) then    
                    maxCapacity = maxCapacity + vehicle:getFillUnitCapacity(fillUnitIndex);
                    leftCapacity = leftCapacity + vehicle:getFillUnitFreeCapacity(fillUnitIndex)
                end;
            end
        end;

        local cpIsCalling = false;
        if vehicle.cp and vehicle.cp.driver and vehicle.cp.driver.isWaitingForUnload then
            cpIsCalling = vehicle.cp.driver:isWaitingForUnload();
        end;

        if (((maxCapacity > 0 and leftCapacity <= 1.0) or cpIsCalling) and vehicle.ad.stoppedTimer <= 0) then
            vehicle.ad.tryingToCallDriver = true;  
            AutoDrive:callDriverToCombine(vehicle);            
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
                end;
            end;
        end;
    else
        combine.ad.tryingToCallDriver = true;    
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
        --vehicle.ad.initialized = false;
        vehicle.ad.wayPoints = {};
        vehicle.ad.isPaused = true;
        if vehicle.ad.currentCombine ~= nil then
            vehicle.ad.currentCombine.ad.currentDriver = nil;
            vehicle.ad.currentCombine = nil;
        end;
    elseif vehicle.ad.combineState == AutoDrive.DRIVE_TO_START_POS then        
        AutoDrive:sendCombineUnloaderToStartOrToUnload(vehicle, false);
    elseif vehicle.ad.combineState == AutoDrive.DRIVE_TO_UNLOAD_POS then
        AutoDrive:sendCombineUnloaderToStartOrToUnload(vehicle, true);
    end;
end;

function AutoDrive:initializeADCombine(vehicle, dt)   
    if vehicle.ad.wayPoints == nil or vehicle.ad.wayPoints[1] == nil then
        vehicle.ad.initialized = false;
        vehicle.ad.timeTillDeadLock = 15000;        
        vehicle.ad.inDeadLock = false;

        if vehicle.ad.combineState == AutoDrive.DRIVE_TO_COMBINE or vehicle.ad.combineState == AutoDrive.DRIVE_TO_START_POS or vehicle.ad.combineState == AutoDrive.DRIVE_TO_PARK_POS then
            return not AutoDrive:handlePathPlanning(vehicle)
        elseif vehicle.ad.combineState == AutoDrive.WAIT_TILL_UNLOADED then
            local doneUnloading, trailerFillLevel = AutoDrive:checkDoneUnloading(vehicle);
            local trailers, trailerCount = AutoDrive:getTrailersOf(vehicle); 

            if trailers[vehicle.ad.currentTrailer+1] ~= nil then
                local lastFillLevel = vehicle.ad.designatedTrailerFillLevel;
                if trailers[vehicle.ad.currentTrailer+1].getFillUnits ~= nil then
                    for fillUnitIndex,fillUnit in pairs(trailers[vehicle.ad.currentTrailer+1]:getFillUnits()) do
                        local fillTypeIsProhibited = false;
                        for fillType, isSupported in pairs(trailers[vehicle.ad.currentTrailer+1]:getFillUnitSupportedFillTypes(fillUnitIndex)) do
                            if fillType == 1 or fillType == 34  then
                                fillTypeIsProhibited = true;
                            end;
                        end;

                        if trailers[vehicle.ad.currentTrailer+1]:getFillUnitCapacity(fillUnitIndex) > 1500 and (not fillTypeIsProhibited) then  
                            maxCapacity = trailers[vehicle.ad.currentTrailer+1]:getFillUnitCapacity(fillUnitIndex);
                            leftCapacity = trailers[vehicle.ad.currentTrailer+1]:getFillUnitFreeCapacity(fillUnitIndex)
                        end;
                    end
                    vehicle.ad.designatedTrailerFillLevel = (maxCapacity - leftCapacity)/maxCapacity;
                end;
                if lastFillLevel < vehicle.ad.designatedTrailerFillLevel then
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

                if trailerFillLevel > AutoDrive:getSetting("unloadFillLevel") or vehicle.ad.combineUnloadInFruit == true or (AutoDrive:getSetting("parkInField") == false) then
                    if trailerFillLevel > AutoDrive:getSetting("unloadFillLevel") then
                        vehicle.ad.combineState = AutoDrive.DRIVE_TO_START_POS;
                    else
                        vehicle.ad.combineState = AutoDrive.DRIVE_TO_PARK_POS;
                    end;
                    AutoDrivePathFinder:startPathPlanningToStartPosition(vehicle, vehicle.ad.currentCombine);
                    if vehicle.ad.currentCombine ~= nil then
                        vehicle.ad.currentCombine.ad.currentDriver = nil;
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
                        vehicle.ad.currentCombine = nil;
                    end;
                end;
            end;
            
            if drivingEnabled == false then
                AutoDrive:getVehicleToStop(vehicle, false, dt);
            end;

            return true;          
        end;        
    end; 

    return false;
end;

function AutoDrive:handlePathPlanning(vehicle)
    AutoDrivePathFinder:updatePathPlanning(vehicle);

    if AutoDrivePathFinder:isPathPlanningFinished(vehicle) then
        vehicle.ad.wayPoints = vehicle.ad.pf.wayPoints;
        vehicle.ad.currentWayPoint = 1;
        return true
    end;
    return false;
end;

function AutoDrive:checkDoneUnloading(vehicle)
    local maxCapacity = 0;
    local leftCapacity = 0;
    local trailers, trailerCount = AutoDrive:getTrailersOf(vehicle);     
    if trailerCount > 0 and trailers[vehicle.ad.currentTrailer] ~= nil then
        if trailers[vehicle.ad.currentTrailer].getFillUnits ~= nil then
            for fillUnitIndex,fillUnit in pairs(trailers[vehicle.ad.currentTrailer]:getFillUnits()) 
            local fillTypeIsProhibited = false;
            for fillType, isSupported in pairs(trailers[vehicle.ad.currentTrailer]:getFillUnitSupportedFillTypes(fillUnitIndex)) do
                if fillType == 1 or fillType == 34  then
                    fillTypeIsProhibited = true;
                end;
            end;

            if trailers[vehicle.ad.currentTrailer]:getFillUnitCapacity(fillUnitIndex) > 1500 and (not fillTypeIsProhibited) then  
                    maxCapacity = maxCapacity + trailers[vehicle.ad.currentTrailer]:getFillUnitCapacity(fillUnitIndex);
                    leftCapacity = leftCapacity + trailers[vehicle.ad.currentTrailer]:getFillUnitFreeCapacity(fillUnitIndex);
                end;
            end
        end;
    end;

    local combineLeftCapacity = 0;
    local combineMaxCapacity = 0;
    if vehicle.ad.currentCombine.getFillUnits ~= nil then
        for fillUnitIndex,fillUnit in pairs(vehicle.ad.currentCombine:getFillUnits()) do
            local fillTypeIsProhibited = false;
            for fillType, isSupported in pairs(vehicle.ad.currentCombine:getFillUnitSupportedFillTypes(fillUnitIndex)) do
                if fillType == 1 or fillType == 34  then
                    fillTypeIsProhibited = true;
                end;
            end;

            if vehicle.ad.currentCombine:getFillUnitCapacity(fillUnitIndex) > 1500 and (not fillTypeIsProhibited) then  
                combineMaxCapacity = combineMaxCapacity + vehicle.ad.currentCombine:getFillUnitCapacity(fillUnitIndex);
                combineLeftCapacity = combineLeftCapacity + vehicle.ad.currentCombine:getFillUnitFreeCapacity(fillUnitIndex)
            end;
        end
    end;

    return ((combineMaxCapacity - combineLeftCapacity) < 100) , (1-(leftCapacity/maxCapacity));
end;

function AutoDrive:combineStateToDescription(vehicle)
    if vehicle.ad.combineState == AutoDrive.WAIT_FOR_COMBINE then
        return g_i18n:getText('ad_wait_for_combine');
    elseif vehicle.ad.combineState == AutoDrive.DRIVE_TO_COMBINE then
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
        if vehicle.ad.combineState == AutoDrive.DRIVE_TO_COMBINE or vehicle.ad.combineState == AutoDrive.DRIVE_TO_PARK_POS or vehicle.ad.combineState == AutoDrive.DRIVE_TO_START_POS  then
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
    end;
    
    vehicle.ad.currentWayPoint = 1;
    vehicle.ad.targetX = vehicle.ad.wayPoints[vehicle.ad.currentWayPoint].x;
    vehicle.ad.targetZ = vehicle.ad.wayPoints[vehicle.ad.currentWayPoint].z;
    if vehicle.ad.currentCombine ~= nil then
        vehicle.ad.currentCombine.ad.currentDriver = nil;
        vehicle.ad.currentCombine = nil;
    end;
end;