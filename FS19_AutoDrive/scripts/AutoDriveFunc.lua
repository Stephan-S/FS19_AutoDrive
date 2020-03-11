function AutoDrive:startAD(vehicle)
	print("AutoDrive:startAD")
	vehicle.ad.isActive = true
	vehicle.ad.creationMode = false
	vehicle.ad.onRouteToPark = false
	vehicle.ad.isStoppingWithError = false

	vehicle.forceIsActive = true
	vehicle.spec_motorized.stopMotorOnLeave = false
	vehicle.spec_enterable.disableCharacterOnLeave = false
	if vehicle.currentHelper == nil then
		vehicle.currentHelper = g_helperManager:getRandomHelper()
		if vehicle.setRandomVehicleCharacter ~= nil then
			vehicle:setRandomVehicleCharacter()
			vehicle.ad.vehicleCharacter = vehicle.spec_enterable.vehicleCharacter
		end
		if vehicle.spec_enterable.controllerFarmId ~= 0 then
			vehicle.spec_aiVehicle.startedFarmId = vehicle.spec_enterable.controllerFarmId
		end
	end
	vehicle.spec_aiVehicle.isActive = true

	if vehicle.steeringEnabled == true then
		vehicle.steeringEnabled = false
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
	end

	if g_server ~= nil then
		vehicle.ad.enableAI = 5
	end

	vehicle.ad.driverOnTheWay = false
	vehicle.ad.tryingToCallDriver = false
	vehicle.ad.currentTrailer = 1

	AutoDriveHud:createMapHotspot(vehicle)
	if vehicle.isServer then
		--g_currentMission:farmStats(vehicle:getOwnerFarmId()):updateStats("workersHired", 1)
		g_currentMission:farmStats(vehicle:getOwnerFarmId()):updateStats("driversHired", 1)
	end
end

function AutoDrive:stopAD(vehicle, withError)
	vehicle.ad.isStopping = true
	vehicle.ad.isStoppingWithError = withError
end

function AutoDrive:disableAutoDriveFunctions(vehicle)
	--g_logManager:devInfo("Disabling vehicle .. " .. vehicle.name);
	if vehicle.isServer and vehicle.ad.isActive then
		--g_currentMission:farmStats(vehicle:getOwnerFarmId()):updateStats("workersHired", -1)
		g_currentMission:farmStats(vehicle:getOwnerFarmId()):updateStats("driversHired", -1)
	end
	
	vehicle.ad.drivePathModule:reset()
	vehicle.ad.specialDrivingModule:reset()
	vehicle.ad.trailerModule:reset()
	
	for _, mode in pairs(vehicle.ad.modes) do
		mode:reset()
	end

	vehicle.ad.isActive = false	
	vehicle.ad.initialized = false

	vehicle.ad.combineState = AutoDrive.COMBINE_UNINITIALIZED
	vehicle.ad.combineUnloadInFruit = false
	vehicle.ad.combineUnloadInFruitWaitTimer = AutoDrive.UNLOAD_WAIT_TIMER
	vehicle.ad.combineFruitToCheck = nil
	vehicle.ad.usePathFinder = false

	vehicle.ad.loopCounterCurrent = 0

	if vehicle.ad.currentCombine ~= nil then
		vehicle.ad.currentCombine.ad.currentDriver = nil
		vehicle.ad.currentCombine.ad.preCalledDriver = false
		vehicle.ad.currentCombine.ad.driverOnTheWay = false
		vehicle.ad.currentCombine = nil
	end
	AutoDrive.waitingUnloadDrivers[vehicle] = nil

	if vehicle.ad.callBackFunction ~= nil and (vehicle.ad.isStoppingWithError == nil or vehicle.ad.isStoppingWithError == false) then
		--work with copys, so we can remove the callBackObjects before calling the function
		local callBackFunction = vehicle.ad.callBackFunction
		local callBackObject = vehicle.ad.callBackObject
		local callBackArg = vehicle.ad.callBackArg
		vehicle.ad.callBackFunction = nil
		vehicle.ad.callBackObject = nil
		vehicle.ad.callBackArg = nil

		if callBackObject ~= nil then
			if callBackArg ~= nil then
				callBackFunction(callBackObject, callBackArg)
			else
				callBackFunction(callBackObject)
			end
		else
			if callBackArg ~= nil then
				callBackFunction(callBackArg)
			else
				callBackFunction()
			end
		end
	else
		vehicle.spec_aiVehicle.isActive = false
		vehicle.forceIsActive = false
		vehicle.spec_motorized.stopMotorOnLeave = true
		vehicle.spec_enterable.disableCharacterOnLeave = true
		vehicle.currentHelper = nil

		if vehicle.restoreVehicleCharacter ~= nil then
			vehicle:restoreVehicleCharacter()
		end

		if vehicle.steeringEnabled == false then
			vehicle.steeringEnabled = true
		end

		vehicle:setCruiseControlState(Drivable.CRUISECONTROL_STATE_OFF)
		AIVehicleUtil.driveInDirection(vehicle, 16, 30, 0, 0.2, 20, false, vehicle.ad.drivingForward, 0, 0, 0, 1)

		--tell clients to dismiss ai worker etc.
		if g_server ~= nil then
			vehicle.ad.disableAI = 5
		end

		if vehicle.ad.onRouteToPark == true then
			vehicle.ad.onRouteToPark = false
			-- We don't need that, since the motor is turned off automatically when the helper is kicked out
			--vehicle:stopMotor()
			if vehicle.spec_lights ~= nil then
				vehicle:deactivateLights()
			end
		end

		vehicle:requestActionEventUpdate()
		if vehicle.raiseAIEvent ~= nil then
			vehicle:raiseAIEvent("onAIEnd", "onAIImplementEnd")
		end
	end

	if vehicle.ad.sensors ~= nil then
		for _, sensor in pairs(vehicle.ad.sensors) do
			sensor:setEnabled(false)
		end
	end
	vehicle.ad.reverseTimer = 3000
	AutoDriveHud:deleteMapHotspot(vehicle)
	vehicle.ad.ccMode = AutoDrive.CC_MODE_IDLE

	if vehicle.setBeaconLightsVisibility ~= nil then
		vehicle:setBeaconLightsVisibility(false)
	end
	
	vehicle.ad.taskModule:reset()
end

function AutoDrive:isActive(vehicle)
	if vehicle ~= nil then
		return vehicle.ad.isActive
	end
	return false
end

function AutoDrive:handleVehicleIntegrity(vehicle)
	if g_server ~= nil then
		vehicle.ad.enableAI = math.max(vehicle.ad.enableAI - 1, 0)
		vehicle.ad.disableAI = math.max(vehicle.ad.disableAI - 1, 0)
	else
		if vehicle.ad.enableAI > 0 then
			AutoDrive:startAD(vehicle)
		end
		if vehicle.ad.disableAI > 0 then
			AutoDrive:disableAutoDriveFunctions(vehicle)
		end
	end
end

function AutoDrive:checkIsConnected(toCheck, other)
	local isAttachedToMe = false
	if toCheck == nil or other == nil then
		return false
	end
	if toCheck.getAttachedImplements == nil then
		return false
	end

	for _, impl in pairs(toCheck:getAttachedImplements()) do
		if impl.object ~= nil then
			if impl.object == other then
				return true
			end

			if impl.object.getAttachedImplements ~= nil then
				isAttachedToMe = isAttachedToMe or AutoDrive:checkIsConnected(impl.object, other)
			end
		end
	end

	return isAttachedToMe
end

function AutoDrive.defineMinDistanceByVehicleType(vehicle)
    local min_distance = 1.8
    if
        vehicle.typeDesc == "combine" or vehicle.typeDesc == "harvester" or vehicle.typeName == "combineDrivable" or vehicle.typeName == "selfPropelledMower" or vehicle.typeName == "woodHarvester" or vehicle.typeName == "combineCutterFruitPreparer" or vehicle.typeName == "drivableMixerWagon" or
            vehicle.typeName == "cottonHarvester" or
            vehicle.typeName == "pdlc_claasPack.combineDrivableCrawlers"
     then
        min_distance = 6
    elseif vehicle.typeDesc == "telehandler" or vehicle.spec_crabSteering ~= nil then --If vehicle has 4 steering wheels like xerion or hardi self Propelled sprayer then also min_distance = 3;
        min_distance = 3
    elseif vehicle.typeDesc == "truck" then
        min_distance = 3
    end
    -- If vehicle is quadtrack then also min_distance = 6;
    if vehicle.spec_articulatedAxis ~= nil and vehicle.spec_articulatedAxis.rotSpeed ~= nil then
        min_distance = 6
    end
    return min_distance
end
