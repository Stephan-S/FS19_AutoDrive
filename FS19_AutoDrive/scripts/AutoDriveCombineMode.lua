AutoDrive.COMBINE_UNINITIALIZED = 0;
AutoDrive.WAIT_FOR_COMBINE = 1;
AutoDrive.DRIVE_TO_COMBINE = 2;
AutoDrive.WAIT_TILL_UNLOADED = 3;
AutoDrive.DRIVE_TO_PARK_POS = 4;
AutoDrive.DRIVE_TO_START_POS = 5;
AutoDrive.DRIVE_TO_UNLOAD_POS = 6;

function AutoDrive:handleCombineHarvester(vehicle, dt)    
    if vehicle.ad.currentDriver ~= nil then
        return;
    end;

    if vehicle.spec_dischargeable ~= nil then
        for _,dischargeNode in pairs(vehicle.spec_dischargeable.dischargeNodes) do
            local nodeX,nodeY,nodeZ = getWorldTranslation( dischargeNode.node );

            local worldX,worldY,worldZ = getWorldTranslation( vehicle.components[1].node );
            local rx,ry,rz = localDirectionToWorld(vehicle.components[1].node, math.sin(vehicle.rotatedTime),0,math.cos(vehicle.rotatedTime));	
            local vehicleVector = {x= math.sin(rx) ,z= math.sin(rz)};

            local leftCapacity = 0;
            local maxCapacity = 0;
            if vehicle.getFillUnits ~= nil then
                for fillUnitIndex,fillUnit in pairs(vehicle:getFillUnits()) do
                    if vehicle:getFillUnitCapacity(fillUnitIndex) > 2000 then
                        maxCapacity = maxCapacity + vehicle:getFillUnitCapacity(fillUnitIndex);
                        leftCapacity = leftCapacity + vehicle:getFillUnitFreeCapacity(fillUnitIndex)
                    end;
                end
            end;

            if maxCapacity > 0 and (leftCapacity/maxCapacity) <= 0.0 then


                local spec = vehicle.spec_pipe
                if spec.currentState == spec.targetState and spec.currentState == 2 then
                    if ADTableLength(AutoDrive.waitingUnloadDrivers) > 0 then
                        local closestDriver = nil;
                        local closestDistance = math.huge;
                        for _,driver in pairs(AutoDrive.waitingUnloadDrivers) do
                            local driverX, driverY, driverZ = getWorldTranslation( driver.components[1].node );
                            local distance = math.sqrt( math.pow((driverX-worldX),2) + math.pow((driverZ - worldZ), 2));
                            
                            if distance < closestDistance then
                                closestDistance = distance;
                                closestDriver = driver;							
                            end;
                        end;

                        if closestDriver ~= nil then                    		
                            AutoDrive:startPathPlanningToCombine(closestDriver, vehicle, dischargeNode.node);
                            closestDriver.ad.currentCombine = vehicle;
                            AutoDrive.waitingUnloadDrivers[closestDriver] = nil;
                            closestDriver.ad.combineState = AutoDrive.DRIVE_TO_COMBINE;
                            vehicle.ad.currentDriver = closestDriver;
                            closestDriver.ad.isPaused = false;
                            closestDriver.ad.isUnloading = false;
                            closestDriver.ad.isLoading = false;
                            closestDriver.ad.initialized = false 
                            closestDriver.ad.wayPoints = {};
                        end;
                    end;
                end;
            end;
        end;
    end;
end;