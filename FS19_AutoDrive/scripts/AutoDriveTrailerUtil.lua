function AutoDrive:handleTrailers(vehicle, dt)
    if vehicle.ad.isActive == true and (vehicle.ad.mode == AutoDrive.MODE_DELIVERTO or vehicle.ad.mode == AutoDrive.MODE_PICKUPANDDELIVER or vehicle.ad.mode == AutoDrive.MODE_UNLOAD or vehicle.ad.mode == AutoDrive.MODE_LOAD) then --and vehicle.isServer == true
        local trailers, trailerCount = AutoDrive:getTrailersOf(vehicle, true);
        local allFillables, fillableCount =  AutoDrive:getTrailersOf(vehicle, false);	

        if trailerCount == 0 and fillableCount == 0 then
            return
        end;     
                
        local fillLevel, leftCapacity = getFillLevelAndCapacityOfAll(trailers);

        AutoDrive:checkTrailerStatesAndAttributes(vehicle, trailers);      

        handleTrailersUnload(vehicle, trailers, fillLevel);

        fillLevel, leftCapacity = getFillLevelAndCapacityOfAll(allFillables);
        handleTrailersLoad(vehicle, allFillables, fillLevel, leftCapacity);
    end;
end;

function AutoDrive:fillTypesMatch(vehicle, fillTrigger, workTool,onlyCheckThisFillUnit)
    if fillTrigger ~= nil then
		local typesMatch = false
		local selectedFillType = vehicle.ad.unloadFillTypeIndex or FillType.UNKNOWN;
		local fillUnits = workTool:getFillUnits()
		local checkOnly = onlyCheckThisFillUnit or 0;
		-- go throught the single fillUnits and check:
		-- does the trigger support the tools filltype ?
		-- does the trigger support the single fillUnits filltype ?
		-- does the trigger and the fillUnit match the selectedFilltype or do they ignore it ?
		for i=1,#fillUnits do
			if checkOnly == 0 or i == checkOnly then
				local selectedFillTypeIsNotInMyFillUnit = true
				local matchInThisUnit = false
				for index,_ in pairs(workTool:getFillUnitSupportedFillTypes(i))do 
					--loadTriggers
					if fillTrigger.source ~= nil and fillTrigger.source.providedFillTypes[index] then
						typesMatch = true
						matchInThisUnit = true
					end
                    --fillTriggers
                    if fillTrigger.source ~= nil and fillTrigger.source.productLines ~= nil then --is gc trigger
                        for subIndex,subSource in pairs (fillTrigger.source.providedFillTypes) do
                            if type(subSource)== 'table' then
                                if subSource[index] ~= nil then					
                                    typesMatch = true
                                    matchInThisUnit =true
                                end
                            end						
                        end	
                    end;

                    if fillTrigger.sourceObject ~= nil then                        
                        local fillTypes = fillTrigger.sourceObject:getFillUnitSupportedFillTypes(1)  
                        if fillTypes[index] then 
                            typesMatch = true
                            matchInThisUnit =true
                        end
                    end
                    
					if index == selectedFillType and selectedFillType ~= FillType.UNKNOWN then
						selectedFillTypeIsNotInMyFillUnit = false;
					end
				end
				if matchInThisUnit and selectedFillTypeIsNotInMyFillUnit then
					return false;
				end
			end
		end	
		
		if typesMatch then
			if selectedFillType == FillType.UNKNOWN then
				return true;
			else
                if fillTrigger.source then
                    if fillTrigger.source.productLines ~= nil then --is gc trigger                         	
                        return true;
                    else
                        return fillTrigger.source.providedFillTypes[selectedFillType];
                    end;
				elseif fillTrigger.sourceObject ~= nil then
					local fillType = fillTrigger.sourceObject:getFillUnitFillType(1)  
					return fillType == selectedFillType;
				end
			end		
		end
	end
	return false;
end;

function AutoDrive:getTrailersOf(vehicle, onlyDischargeable)
    AutoDrive.tempTrailers = {};
    AutoDrive.tempTrailerCount = 0;

    if vehicle.getAttachedImplements ~= nil then
        for _, implement in pairs(vehicle:getAttachedImplements()) do
            AutoDrive:getTrailersOfImplement(implement.object, onlyDischargeable);
        end;
    end;

    return AutoDrive.tempTrailers, AutoDrive.tempTrailerCount;
end;

function AutoDrive:getTrailersOfImplement(attachedImplement, onlyDischargeable)
    if ((attachedImplement.typeDesc == g_i18n:getText("typeDesc_tipper") or attachedImplement.spec_dischargeable ~= nil) or (not onlyDischargeable)) and attachedImplement.getFillUnits ~= nil then
        trailer = attachedImplement;
        AutoDrive.tempTrailerCount = AutoDrive.tempTrailerCount + 1;
        AutoDrive.tempTrailers[AutoDrive.tempTrailerCount] = trailer;
    end;
    if attachedImplement.vehicleType.specializationsByName["hookLiftTrailer"] ~= nil then     
        if attachedImplement.spec_hookLiftTrailer.attachedContainer ~= nil then    
            trailer = attachedImplement.spec_hookLiftTrailer.attachedContainer.object
            AutoDrive.tempTrailerCount = AutoDrive.tempTrailerCount + 1;
            AutoDrive.tempTrailers[AutoDrive.tempTrailerCount] = trailer;
        end;
    end;

    if attachedImplement.getAttachedImplements ~= nil then
        for _, implement in pairs(attachedImplement:getAttachedImplements()) do
            AutoDrive:getTrailersOfImplement(implement.object);
        end;
    end;

    return;
end;

function getDistanceToUnloadPosition(vehicle)
    if vehicle.ad.targetSelected_Unload == nil or vehicle.ad.targetSelected == nil then
        return math.huge;
    end;
    local x,y,z = getWorldTranslation(vehicle.components[1].node);
    local destination = AutoDrive.mapWayPoints[vehicle.ad.targetSelected_Unload];        
    if vehicle.ad.mode == AutoDrive.MODE_DELIVERTO then
        destination = AutoDrive.mapWayPoints[vehicle.ad.targetSelected];
    end;
    if destination == nil then
        return math.huge;
    end;
    return AutoDrive:getDistance(x,z, destination.x, destination.z);
end;

function getDistanceToTargetPosition(vehicle)
    if vehicle.ad.targetSelected == nil then
        return math.huge;
    end;
    local x,y,z = getWorldTranslation(vehicle.components[1].node);
    local destination = AutoDrive.mapWayPoints[vehicle.ad.targetSelected];
    if destination == nil then
        return math.huge;
    end;
    return AutoDrive:getDistance(x,z, destination.x, destination.z);
end;

function getFillLevelAndCapacityOfAll(trailers) 
    local leftCapacity = 0;
    local fillLevel = 0;

    if trailers ~= nil then    
        for _,trailer in pairs(trailers) do
            for _,fillUnit in pairs(trailer:getFillUnits()) do
                leftCapacity = leftCapacity + trailer:getFillUnitFreeCapacity(_);
                fillLevel = fillLevel + trailer:getFillUnitFillLevel(_);
            end
        end;
    end;
    
    return fillLevel, leftCapacity;
end;

function getFillLevelAndCapacityOf(trailer, selectedFillType) 
    local leftCapacity = 0;
    local fillLevel = 0;

    if trailer ~= nil then    
        for _,fillUnit in pairs(trailer:getFillUnits()) do
            if selectedFillType == nil or trailer:getFillUnitSupportedFillTypes(_)[selectedFillType] == true then
                leftCapacity = leftCapacity + trailer:getFillUnitFreeCapacity(_);
                fillLevel = fillLevel + trailer:getFillUnitFillLevel(_);
            end;
        end
    end;
    
    return fillLevel, leftCapacity;
end;

function AutoDrive:checkTrailerStatesAndAttributes(vehicle, trailers)
    if vehicle == nil or trailers == nil then
        return;
    end;
    local fillLevel, leftCapacity = getFillLevelAndCapacityOfAll(trailers);
    
    if vehicle.ad.mode == AutoDrive.MODE_PICKUPANDDELIVER or vehicle.ad.mode == AutoDrive.MODE_LOAD then
        if getDistanceToTargetPosition(vehicle) > 25 and getDistanceToUnloadPosition(vehicle) > 25 then
            AutoDrive:setTrailerCoverOpen(trailers, false);
        else
            AutoDrive:setTrailerCoverOpen(trailers, true);
        end;
    end;

    stopDischargingWhenTrailerEmpty(vehicle, trailers, fillLevel);
    if vehicle.ad.mode == AutoDrive.MODE_UNLOAD then
        handleUnloaderSpecificStates(vehicle, trailers, fillLevel, leftCapacity);
    end;
end;

function stopDischargingWhenTrailerEmpty(vehicle, trailers, fillLevel)    
    if fillLevel == 0 then
        vehicle.ad.isUnloading = false;
        vehicle.ad.isUnloadingToBunkerSilo = false;
        for _,trailer in pairs(trailers) do
            if trailer.setDischargeState then
                trailer:setDischargeState(Dischargeable.DISCHARGE_STATE_OFF);
            end;
        end;            
    end;
end;

function handleUnloaderSpecificStates(vehicle, trailers, fillLevel, leftCapacity)
    if vehicle.ad.combineState == AutoDrive.DRIVE_TO_COMBINE then 
        AutoDrive:setTrailerCoverOpen(trailers, true); --open
        AutoDrive:setAugerPipeOpen(trailers, false);        
    end;  

    if vehicle.ad.combineState == AutoDrive.WAIT_FOR_COMBINE and leftCapacity == 0 then --was filled up manually
        AutoDrive:sendCombineUnloaderToStartOrToUnload(vehicle, false);
    end;

    if (vehicle.ad.combineState ~= AutoDrive.DRIVE_TO_COMBINE and vehicle.ad.combineState ~= AutoDrive.WAIT_TILL_UNLOADED) then
        if getDistanceToUnloadPosition(vehicle) < 20 then
            AutoDrive:setAugerPipeOpen(trailers, true); 
        end;
    end;
end;

function AutoDrive:setTrailerCoverOpen(trailers, open)
    if trailers == nil then
        return;
    end;

    local targetState = 0;
    if open then targetState = 1; end; 

    for _, trailer in pairs(trailers) do
        if trailer.spec_cover ~= nil then
            targetState = targetState * #trailer.spec_cover.covers
            if trailer.spec_cover.state ~= targetState and trailer:getIsNextCoverStateAllowed(targetState) then
                trailer:setCoverState(targetState,true);
            end
        end; 
    end;
end;

function AutoDrive:setAugerPipeOpen(trailers, open)
    if trailers == nil then
        return;
    end;

    local targetState = 1;
    if open then targetState = 2; end; 
    for _, trailer in pairs(trailers) do
        if trailer.spec_pipe ~= nil then
            if trailer.spec_pipe.currentState ~= targetState and trailer:getIsPipeStateChangeAllowed(targetState) then
                trailer:setPipeState(targetState,true);
            end
        end;
    end;
end;

function handleTrailersUnload(vehicle, trailers, fillLevel)    
    if vehicle.ad.mode == AutoDrive.MODE_LOAD then
        return;
    end;
    local distance = getDistanceToUnloadPosition(vehicle);
    if distance < 100 then
        continueIfAllTrailersClosed(vehicle, trailers); 
        --AutoDrive:setTrailerCoverOpen(trailers, true);

        for _,trailer in pairs(trailers) do
            for _,trigger in pairs(AutoDrive.Triggers.tipTriggers) do                
                if trailer.getCurrentDischargeNode == nil or fillLevel == 0 then
                    break;
                end;

                findAndSetBestTipPoint(vehicle, trailer)  
                
                if (trigger.bunkerSilo == nil)  then
                    if (distance > 20) then
                        break;
                    end;                          
                
                    if trailer:getCanDischargeToObject(trailer:getCurrentDischargeNode()) and trailer.setDischargeState ~= nil then
                        trailer:setDischargeState(Dischargeable.DISCHARGE_STATE_OBJECT)
                        vehicle.ad.isPaused = true;
                        vehicle.ad.isUnloading = true;
                    end;

                    if dischargeState ~= Trailer.TIPSTATE_CLOSED and dischargeState ~= Trailer.TIPSTATE_CLOSING then
                        vehicle.ad.isUnloading = true;
                    end;
                else
                    if isTrailerInBunkerSiloArea(trailer, trigger) and trailer.setDischargeState ~= nil then
                        trailer:setDischargeState(Dischargeable.DISCHARGE_STATE_GROUND);
                        vehicle.ad.isUnloadingToBunkerSilo = true;
                    end;
                end;
            end;              
        end;
    end;
end;

function continueIfAllTrailersClosed(vehicle, trailers)
    local allClosed = true;
    for _,trailer in pairs(trailers) do
        if trailer.getDischargeState ~= nil then
            local dischargeState = trailer:getDischargeState()
            if dischargeState ~= Trailer.TIPSTATE_CLOSED or vehicle.ad.isLoading then
                allClosed = false;
            end;
        end;
    end;
    if allClosed and (vehicle.ad.mode ~= AutoDrive.MODE_UNLOAD or vehicle.ad.combineState == AutoDrive.DRIVE_TO_UNLOAD_POS or vehicle.ad.combineState == AutoDrive.COMBINE_UNINITIALIZED) then
        vehicle.ad.isPaused = false;
        vehicle.ad.isUnloading = false;
    end;
end;

function findAndSetBestTipPoint(vehicle, trailer)
     if not trailer:getCanDischargeToObject(trailer:getCurrentDischargeNode()) then
        for i=1,#trailer.spec_dischargeable.dischargeNodes do
            if trailer:getCanDischargeToObject(trailer.spec_dischargeable.dischargeNodes[i])then
                trailer:setCurrentDischargeNodeIndex(trailer.spec_dischargeable.dischargeNodes[i]);
                currentDischargeNode = trailer:getCurrentDischargeNode()
                break
            end
        end
    end
end;

function isTrailerInBunkerSiloArea(trailer, trigger)    
    local x,y,z = getWorldTranslation(trailer:getCurrentDischargeNode().node)
    local tx,ty,tz = x,y,z+1
    local x1,z1 = trigger.bunkerSiloArea.sx,trigger.bunkerSiloArea.sz
    local x2,z2 = trigger.bunkerSiloArea.wx,trigger.bunkerSiloArea.wz
    local x3,z3 = trigger.bunkerSiloArea.hx,trigger.bunkerSiloArea.hz
    return MathUtil.hasRectangleLineIntersection2D(x1,z1,x2-x1,z2-z1,x3-x1,z3-z1,x,z,tx-x,tz-z)
end;

function handleTrailersLoad(vehicle, trailers, fillLevel, leftCapacity)
    if vehicle.ad.mode == AutoDrive.MODE_PICKUPANDDELIVER or vehicle.ad.mode == AutoDrive.MODE_LOAD then     
        local distance = getDistanceToTargetPosition(vehicle);
        if vehicle.ad.mode == AutoDrive.MODE_LOAD then
            distance = getDistanceToUnloadPosition(vehicle);
        end;
        if distance < 20 then
            --AutoDrive:setTrailerCoverOpen(trailers, true);
            for _,trailer in pairs(trailers) do
                local fillLevelTrailer, leftCapacityTrailer  = getFillLevelAndCapacityOf(trailer, vehicle.ad.unloadFillTypeIndex);
                if vehicle.ad.trigger ~= nil and vehicle.ad.trigger.isLoading and vehicle.ad.trigger.selectedFillType ~= vehicle.ad.unloadFillTypeIndex then --
                    fillLevelTrailer, leftCapacityTrailer  = getFillLevelAndCapacityOf(trailer, vehicle.ad.trigger.selectedFillType);                
                end;
                for _,trigger in pairs(AutoDrive.Triggers.siloTriggers) do
                    if AutoDrive:getSetting("continueOnEmptySilo") and trigger == vehicle.ad.trigger and vehicle.ad.isLoading and vehicle.ad.isPaused and not trigger.isLoading and vehicle.ad.trailerStartedLoadingAtTrigger then --trigger must be empty by now. Drive on!                      
                        AutoDrive:continueAfterLoadOrUnload(vehicle);
                    elseif AutoDrive:trailerInTriggerRange(trailer, trigger) and not trigger.isLoading and leftCapacity > 0 and trigger:getIsActivatable(trailer) and ((not vehicle.ad.trailerStartedLoadingAtTrigger) or (trigger ~= vehicle.ad.trigger and (not vehicle.ad.trigger.isLoading))) then -- and  and vehicle.ad.isLoading == false                      
                        if not AutoDrive:fillTypesMatch(vehicle, trigger, trailer) and AutoDrive:getSetting("refillSeedAndFertilizer") then  
                            local storedFillType = vehicle.ad.unloadFillTypeIndex;
                            local toCheck = {13, 43, 44};
                            local matches = checkIfTrailerAcceptsAlso(vehicle, trailer, trigger, toCheck);

                            if matches then                   
                                AutoDrive:startLoadingAtTrigger(vehicle, trigger, vehicle.ad.unloadFillTypeIndex); 
                                if vehicle.ad.trigger ~= nil then --and vehicle.ad.trigger.isLoading
                                    fillLevelTrailer, leftCapacityTrailer  = getFillLevelAndCapacityOf(trailer, vehicle.ad.trigger.selectedFillType);
                                end;
                            end;

                            vehicle.ad.unloadFillTypeIndex = storedFillType;
                        else
                            AutoDrive:startLoadingAtTrigger(vehicle, trigger, vehicle.ad.unloadFillTypeIndex); 
                        end;                        
                    elseif (leftCapacity == 0 or (leftCapacityTrailer == 0 and AutoDrive:trailerInTriggerRange(trailer, trigger))) and vehicle.ad.isPaused then
                        AutoDrive:continueAfterLoadOrUnload(vehicle);
                        vehicle.ad.trailerStartedLoadingAtTrigger = false;
                    end;
                end;
            end;			
        end;
    end;
end;

function AutoDrive:trailerInTriggerRange(trailer, trigger)
    if trigger.fillableObjects ~= nil then
        for __,fillableObject in pairs(trigger.fillableObjects) do
            if fillableObject.object == trailer then   
                return true;    
            end;
        end;
    end;
    return false;
end;

function AutoDrive:continueAfterLoadOrUnload(vehicle)
    vehicle.ad.isPaused = false;
    vehicle.ad.isUnloading = false;
    vehicle.ad.isLoading = false;
end;

function AutoDrive:startLoadingAtTrigger(vehicle, trigger, fillType)
    trigger.autoStart = true
    trigger.selectedFillType = fillType   
    trigger:onFillTypeSelection(fillType);
    trigger.selectedFillType = fillType 
    g_effectManager:setFillType(trigger.effects, trigger.selectedFillType)
    trigger.autoStart = false

    vehicle.ad.isPaused = true;
    vehicle.ad.isLoading = true;
    vehicle.ad.startedLoadingAtTrigger = true;
    vehicle.ad.trailerStartedLoadingAtTrigger = true;
    vehicle.ad.trigger = trigger;
end;

function checkIfTrailerAcceptsAlso(vehicle, trailer, trigger, listOfFillTypes)
    local matches = false;
    local storedType = vehicle.ad.unloadFillTypeIndex;
    local isInList = false;
    for _,fillType in pairs(listOfFillTypes) do
        if fillType == vehicle.ad.unloadFillTypeIndex then
            isInList = true;
            break;
        end;
    end;
    for _,fillType in pairs(listOfFillTypes) do
        if fillType ~= vehicle.ad.unloadFillTypeIndex then --now check all others
            vehicle.ad.unloadFillTypeIndex = fillType;
            matches = AutoDrive:fillTypesMatch(vehicle, trigger, trailer);
            if matches and isInList then
                return true;
            end;
            vehicle.ad.unloadFillTypeIndex = storedFillType; --always reset to storedFillType before next check
        end;
    end;
    return false;
end;