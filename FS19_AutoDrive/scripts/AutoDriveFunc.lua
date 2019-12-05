function AutoDrive:startAD(vehicle)
	vehicle.ad.isActive = true
	vehicle.ad.creationMode = false
	vehicle.ad.startedLoadingAtTrigger = false
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

	if g_server ~= nil then
		local trailers, _ = AutoDrive.getTrailersOf(vehicle, false) --(vehicle.ad.mode ~= AutoDrive.MODE_LOAD)
		local fillLevel, leftCapacity = AutoDrive.getFillLevelAndCapacityOfAll(trailers)
		local maxCapacity = fillLevel + leftCapacity

		vehicle.ad.skipStart = false
		if ((vehicle.ad.mode == AutoDrive.MODE_PICKUPANDDELIVER or vehicle.ad.mode == AutoDrive.MODE_UNLOAD) and (leftCapacity <= (maxCapacity * (1 - AutoDrive.getSetting("unloadFillLevel", vehicle) + 0.001)))) or (vehicle.ad.mode == AutoDrive.MODE_LOAD and leftCapacity > (maxCapacity * 0.3)) then -- 0.3 value can be changed in the future for a modifiable fill percentage threshold in setings
			if AutoDrive.mapMarker[vehicle.ad.mapMarkerSelected_Unload] ~= nil then
				vehicle.ad.skipStart = true
				vehicle.ad.onRouteToSecondTarget = true
			end
		else
			vehicle.ad.onRouteToSecondTarget = false
		end
	end

	vehicle.ad.driverOnTheWay = false
	vehicle.ad.tryingToCallDriver = false
	vehicle.ad.currentTrailer = 1
	vehicle.ad.loopCounterCurrent = 0
	vehicle.ad.waitingToBeLoaded = false

	if vehicle.ad.mode == AutoDrive.MODE_BGA then
		vehicle.bga.state = AutoDriveBGA.STATE_INIT
	end

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

function AutoDrive:stopVehicle(vehicle, dt)
	if math.abs(vehicle.lastSpeedReal) < 0.0015 then
		vehicle.ad.isStopping = false
		-- We don't need that, since the motor is turned off automatically when the helper is kicked out
		--if AutoDrive.getSetting("fuelSaving") and vehicle.isServer and (vehicle.getIsEntered == nil or not vehicle:getIsEntered()) and vehicle.spec_motorized.isMotorStarted then
		--	vehicle:stopMotor()
		--end
		AutoDrive:disableAutoDriveFunctions(vehicle)
	else
		AutoDrive:getVehicleToStop(vehicle, true, dt)
	end
end

function AutoDrive:disableAutoDriveFunctions(vehicle)
	--g_logManager:devInfo("Disabling vehicle .. " .. vehicle.name);
	if vehicle.isServer and vehicle.ad.isActive then
		--g_currentMission:farmStats(vehicle:getOwnerFarmId()):updateStats("workersHired", -1)
		g_currentMission:farmStats(vehicle:getOwnerFarmId()):updateStats("driversHired", -1)
	end
	vehicle.ad.currentWayPoint = 0
	vehicle.ad.drivingForward = true
	vehicle.ad.isActive = false
	vehicle.ad.isPaused = false
	vehicle.ad.isUnloading = false
	vehicle.ad.isLoading = false
	vehicle.ad.initialized = false
	--vehicle.ad.lastSpeed = 10
	vehicle.ad.combineState = AutoDrive.COMBINE_UNINITIALIZED
	vehicle.ad.combineUnloadInFruit = false
	vehicle.ad.combineUnloadInFruitWaitTimer = AutoDrive.UNLOAD_WAIT_TIMER
	vehicle.ad.combineFruitToCheck = nil
	vehicle.ad.usePathFinder = false
	vehicle.ad.loopCounterCurrent = 0
	vehicle.ad.isLoadingToFillUnitIndex = nil
	vehicle.ad.isLoadingToTrailer = nil
	vehicle.ad.trigger = nil
	vehicle.ad.waitingToBeLoaded = false

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

	if vehicle.bga ~= nil then
		vehicle.bga.state = AutoDriveBGA.STATE_IDLE
		vehicle.bga.targetTrailer = nil
		vehicle.bga.targetDriver = nil
		vehicle.bga.targetBunker = nil
		vehicle.bga.loadingSideP1 = nil
		vehicle.bga.loadingSideP2 = nil
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
end

function AutoDrive:getVehicleToStop(vehicle, brake, dt)
	local finalSpeed = 0
	local acc = -1
	local allowedToDrive = false

	if brake == true or math.abs(vehicle.lastSpeedReal) > 0.002 then
		finalSpeed = 0.01
		acc = -0.6
		allowedToDrive = true
	end

	--local node = vehicle.components[1].node
	--if vehicle.getAIVehicleDirectionNode ~= nil then
	--	node = vehicle:getAIVehicleDirectionNode()
	--end
	local x, y, z = getWorldTranslation(vehicle.components[1].node)
	local rx, _, rz = localDirectionToWorld(vehicle.components[1].node, 0, 0, 1)
	x = x + rx
	z = z + rz
	local lx, lz = AIVehicleUtil.getDriveDirection(vehicle.components[1].node, x, y, z)
	AIVehicleUtil.driveInDirection(vehicle, dt, 30, acc, 0.2, 20, allowedToDrive, vehicle.ad.drivingForward, lx, lz, finalSpeed, 1)
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

function AutoDrive:detectAdTrafficOnRoute(vehicle)
	if vehicle.ad.isActive == true then
		if vehicle.ad.combineState == AutoDrive.DRIVE_TO_COMBINE or vehicle.ad.combineState == AutoDrive.PREDRIVE_COMBINE or vehicle.ad.combineState == AutoDrive.DRIVE_TO_PARK_POS or vehicle.ad.combineState == AutoDrive.DRIVE_TO_START_POS and vehicle.ad.mode == AutoDrive.MODE_UNLOAD then
			return false
		end

		local idToCheck = 3
		local alreadyOnDualRoute = false
		if vehicle.ad.wayPoints[vehicle.ad.currentWayPoint - 1] ~= nil and vehicle.ad.wayPoints[vehicle.ad.currentWayPoint] ~= nil then
			alreadyOnDualRoute = AutoDrive:isDualRoad(vehicle.ad.wayPoints[vehicle.ad.currentWayPoint - 1], vehicle.ad.wayPoints[vehicle.ad.currentWayPoint])
		end

		if vehicle.ad.wayPoints[vehicle.ad.currentWayPoint + idToCheck] ~= nil and vehicle.ad.wayPoints[vehicle.ad.currentWayPoint + idToCheck + 1] ~= nil and not alreadyOnDualRoute then
			local dualRoute = AutoDrive:isDualRoad(vehicle.ad.wayPoints[vehicle.ad.currentWayPoint + idToCheck], vehicle.ad.wayPoints[vehicle.ad.currentWayPoint + idToCheck + 1])

			local dualRoutePoints = {}
			local counter = 0
			idToCheck = 0 -- dont look behind anymore -3
			while (dualRoute == true) or (idToCheck < 5) do
				local startNode = vehicle.ad.wayPoints[vehicle.ad.currentWayPoint + idToCheck]
				local targetNode = vehicle.ad.wayPoints[vehicle.ad.currentWayPoint + idToCheck + 1]
				if (startNode ~= nil) and (targetNode ~= nil) then
					local testDual = AutoDrive:isDualRoad(startNode, targetNode)
					if testDual == true then
						counter = counter + 1
						dualRoutePoints[counter] = startNode.id
						dualRoute = true
					else
						dualRoute = false
					end
				else
					dualRoute = false
				end
				idToCheck = idToCheck + 1
			end

			local trafficDetected = false
			vehicle.ad.trafficVehicle = nil
			if counter > 0 then
				for _, other in pairs(g_currentMission.vehicles) do
					if other ~= vehicle and other.ad ~= nil and other.ad.isActive == true then
						local onSameRoute = false
						local sameDirection = false
						local window = 4
						local i = -window
						while i <= window do
							if other.ad.wayPoints ~= nil and other.ad.wayPoints[other.ad.currentWayPoint + i] ~= nil then
								for _, point in pairs(dualRoutePoints) do
									if point == other.ad.wayPoints[other.ad.currentWayPoint + i].id then
										onSameRoute = true
										if dualRoutePoints[_ + 1] ~= nil and other.ad.wayPoints[other.ad.currentWayPoint + i + 1] ~= nil then --check if going in same direction
											if dualRoutePoints[_ + 1] == other.ad.wayPoints[other.ad.currentWayPoint + i + 1].id then
												sameDirection = true
											end
										end
										if dualRoutePoints[_ - 1] ~= nil and other.ad.wayPoints[other.ad.currentWayPoint + i - 1] ~= nil then --check if going in same direction
											if dualRoutePoints[_ - 1] == other.ad.wayPoints[other.ad.currentWayPoint + i - 1].id then
												sameDirection = true
											end
										end
									end
								end
							end
							i = i + 1
						end

						if onSameRoute == true and other.ad.trafficVehicle == nil and (sameDirection == false) then
							trafficDetected = true
							vehicle.ad.trafficVehicle = other
						end
					end
				end
			end

			if trafficDetected == true then
				--g_logManager:devInfo("Traffic on same road deteced");
				return true
			end
		end
	end
	return false
end

function AutoDrive:detectTraffic(vehicle)
	local x, y, z = getWorldTranslation(vehicle.components[1].node)
	local rx, _, rz = localDirectionToWorld(vehicle.components[1].node, math.sin(vehicle.rotatedTime), 0, math.cos(vehicle.rotatedTime))
	local vehicleVector = {x = rx, z = rz}
	local width = vehicle.sizeWidth
	local length = vehicle.sizeLength
	local lookAheadDistance = math.min(vehicle.lastSpeedReal * 3600 / 40, 1) * 10 + 1.5

	local approachingLastWayPoints = false
	if vehicle.ad.wayPoints ~= nil and vehicle.ad.wayPoints[vehicle.ad.currentWayPoint] ~= nil and vehicle.ad.wayPoints[vehicle.ad.currentWayPoint + 2] == nil then
		approachingLastWayPoints = true
	end

	if AutoDrive.getSetting("enableTrafficDetection") == true then --GC have now updated their triggers. so remove this: and (AutoDrive.getDistanceToTargetPosition(vehicle) > 15 and AutoDrive.getDistanceToUnloadPosition(vehicle) > 15)
		local box = {}
		box.center = {}
		box.size = {}
		box.center[1] = 0
		box.center[2] = 1.5
		box.center[3] = length
		box.size[1] = width * 0.35
		box.size[2] = 0.75
		box.size[3] = (lookAheadDistance) / 2
		box.x, box.y, box.z = localToWorld(vehicle.components[1].node, box.center[1], box.center[2], box.center[3])
		box.zx, box.zy, box.zz = localDirectionToWorld(vehicle.components[1].node, math.sin(vehicle.rotatedTime), 0, math.cos(vehicle.rotatedTime))
		box.xx, box.xy, box.xz = localDirectionToWorld(vehicle.components[1].node, -math.cos(vehicle.rotatedTime), 0, math.sin(vehicle.rotatedTime))
		box.dirX, box.dirY, box.dirZ = localDirectionToWorld(vehicle.components[1].node, 0, 0, 1)
		box.ry = math.atan2(box.zx, box.zz)
		local rotX = -MathUtil.getYRotationFromDirection(box.dirY, 1)

		local offsetCompensation = -math.tan(rotX) * box.size[3]

		local heightOffset = 2.2
		if approachingLastWayPoints then
			box.size[2] = 0.25
			heightOffset = 1.2
		end

		local boxCenter = {
			x = x + ((length / 2 + box.size[3] + 0) * vehicleVector.x),
			y = y + heightOffset,
			z = z + ((length / 2 + box.size[3] + 0) * vehicleVector.z)
		}

		boxCenter.y = math.max(getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, boxCenter.x, 300, boxCenter.z), y) + 1.5 + offsetCompensation
		--local rx, ry, rz = getWorldRotation(vehicle.components[1].node)
		local shapes = overlapBox(boxCenter.x, boxCenter.y, boxCenter.z, rotX, box.ry, 0, box.size[1], box.size[2], box.size[3], "collisionTestCallback", nil, AIVehicleUtil.COLLISION_MASK, true, true, true) --AIVehicleUtil.COLLISION_MASK

		local red = 0
		if shapes > 0 then
			red = 1
		end
		DebugUtil.drawOverlapBox(boxCenter.x, boxCenter.y, boxCenter.z, rotX, box.ry, 0, box.size[1], box.size[2], box.size[3], red, 0, 0)

		if shapes > 0 then
			return true
		end
	end

	local excludedList = {}
	if (vehicle.ad.combineState == AutoDrive.DRIVE_TO_COMBINE or vehicle.ad.combineState == AutoDrive.PREDRIVE_COMBINE or vehicle.ad.combineState == AutoDrive.CHASE_COMBINE) then
		if vehicle.ad.currentCombine ~= nil then
			table.insert(excludedList, vehicle.ad.currentCombine)
		end
	end

	if AutoDrive:checkForVehicleCollision(vehicle, excludedList, true) then
		return true
	end

	return false
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
