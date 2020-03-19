ADCollisionDetectionModule = {}

function ADCollisionDetectionModule:new(vehicle)
	local o = {}
	setmetatable(o, self)
	self.__index = self
	o.vehicle = vehicle
	o.detectedObstable = false
	return o
end

function ADCollisionDetectionModule:hasDetectedObstable()
	self.detectedObstable = self:detectObstacle() or self:detectAdTrafficOnRoute()
	return self.detectedObstable
end

function ADCollisionDetectionModule:update(dt)
end

function ADCollisionDetectionModule:detectObstacle()
	local x, y, z = getWorldTranslation(self.vehicle.components[1].node)
	local rx, _, rz = localDirectionToWorld(self.vehicle.components[1].node, math.sin(self.vehicle.rotatedTime), 0, math.cos(self.vehicle.rotatedTime))
	local vehicleVector = {x = rx, z = rz}
	local width = self.vehicle.sizeWidth
	local length = self.vehicle.sizeLength
	local lookAheadDistance = math.min(self.vehicle.lastSpeedReal * 3600 / 40, 1) * 10 + 1.5

	if AutoDrive.getSetting("enableTrafficDetection") == true then
		local box = {}
		box.center = {}
		box.size = {}
		box.center[1] = 0
		box.center[2] = 1.5
		box.center[3] = length
		box.size[1] = width * 0.35
		box.size[2] = 0.75
		box.size[3] = (lookAheadDistance) / 2
		box.x, box.y, box.z = localToWorld(self.vehicle.components[1].node, box.center[1], box.center[2], box.center[3])
		box.zx, box.zy, box.zz = localDirectionToWorld(self.vehicle.components[1].node, math.sin(self.vehicle.rotatedTime), 0, math.cos(self.vehicle.rotatedTime))
		box.xx, box.xy, box.xz = localDirectionToWorld(self.vehicle.components[1].node, -math.cos(self.vehicle.rotatedTime), 0, math.sin(self.vehicle.rotatedTime))
		box.dirX, box.dirY, box.dirZ = localDirectionToWorld(self.vehicle.components[1].node, 0, 0, 1)
		box.ry = math.atan2(box.zx, box.zz)
		local rotX = -MathUtil.getYRotationFromDirection(box.dirY, 1)

		local offsetCompensation = -math.tan(rotX) * box.size[3]

		local heightOffset = 2.2

		local boxCenter = {
			x = x + ((length / 2 + box.size[3] + 0) * vehicleVector.x),
			y = y + heightOffset,
			z = z + ((length / 2 + box.size[3] + 0) * vehicleVector.z)
		}

		boxCenter.y = math.max(getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, boxCenter.x, 300, boxCenter.z), y) + 1.5 + offsetCompensation
		local shapes = overlapBox(boxCenter.x, boxCenter.y, boxCenter.z, rotX, box.ry, 0, box.size[1], box.size[2], box.size[3], "collisionTestCallback", nil, AIVehicleUtil.COLLISION_MASK, true, true, true)

		local red = 0
		if shapes > 0 then
			red = 1
		end
		DebugUtil.drawOverlapBox(boxCenter.x, boxCenter.y, boxCenter.z, rotX, box.ry, 0, box.size[1], box.size[2], box.size[3], red, 0, 0)

		if shapes > 0 then
			return true
		end
	end

	local excludedList = self.vehicle.ad.taskModule:getActiveTask():getExcludedVehiclesForCollisionCheck()

	if AutoDrive:checkForVehicleCollision(self.vehicle, excludedList, true) then
		return true
	end

	return false
end

function ADCollisionDetectionModule:detectAdTrafficOnRoute()
	local wayPoints, currentWayPoint = self.vehicle.ad.drivePathModule:getWayPoints()
	if self.vehicle.ad.stateModule:isActive() and wayPoints ~= nil and self.vehicle.ad.drivePathModule:isOnRoadNetwork() then
		local idToCheck = 3
		local alreadyOnDualRoute = false
		if wayPoints[currentWayPoint - 1] ~= nil and wayPoints[currentWayPoint] ~= nil then
			alreadyOnDualRoute = ADGraphManager:isDualRoad(wayPoints[currentWayPoint - 1], wayPoints[currentWayPoint])
		end

		if wayPoints[currentWayPoint + idToCheck] ~= nil and wayPoints[currentWayPoint + idToCheck + 1] ~= nil and not alreadyOnDualRoute then
			local dualRoute = ADGraphManager:isDualRoad(wayPoints[currentWayPoint + idToCheck], wayPoints[currentWayPoint + idToCheck + 1])

			local dualRoutePoints = {}
			local counter = 0
			idToCheck = 0
			while (dualRoute == true) or (idToCheck < 5) do
				local startNode = wayPoints[currentWayPoint + idToCheck]
				local targetNode = wayPoints[currentWayPoint + idToCheck + 1]
				if (startNode ~= nil) and (targetNode ~= nil) then
					local testDual = ADGraphManager:isDualRoad(startNode, targetNode)
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

			self.trafficVehicle = nil
			if counter > 0 then
				for _, other in pairs(g_currentMission.vehicles) do
					if other ~= self.vehicle and other.ad ~= nil and other.ad.stateModule ~= nil and other.ad.stateModule:isActive() and self.vehicle.ad.drivePathModule:isOnRoadNetwork() then
						local onSameRoute = false
						local sameDirection = false
						local window = 4
						local i = -window
						local otherWayPoints, otherCurrentWayPoint = other.ad.drivePathModule:getWayPoints()
						while i <= window do
							if otherWayPoints ~= nil and otherWayPoints[otherCurrentWayPoint + i] ~= nil then
								for _, point in pairs(dualRoutePoints) do
									if point == otherWayPoints[otherCurrentWayPoint + i].id then
										onSameRoute = true
										--check if going in same direction
										if dualRoutePoints[_ + 1] ~= nil and otherWayPoints[otherCurrentWayPoint + i + 1] ~= nil then
											if dualRoutePoints[_ + 1] == otherWayPoints[otherCurrentWayPoint + i + 1].id then
												sameDirection = true
											end
										end
										--check if going in same direction
										if dualRoutePoints[_ - 1] ~= nil and otherWayPoints[otherCurrentWayPoint + i - 1] ~= nil then
											if dualRoutePoints[_ - 1] == otherWayPoints[otherCurrentWayPoint + i - 1].id then
												sameDirection = true
											end
										end
									end
								end
							end
							i = i + 1
						end

						if onSameRoute == true and other.ad.collisionDetectionModule:getDetectedVehicle() == nil and (sameDirection == false) then
							self.trafficVehicle = other
							return true
						end
					end
				end
			end
		end
	end
	return false
end

function ADCollisionDetectionModule:getDetectedVehicle()
	return self.trafficVehicle
end
