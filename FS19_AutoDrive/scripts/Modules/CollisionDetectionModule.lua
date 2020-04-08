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
	local box = self.vehicle.ad.sensors.frontSensorDynamic:getBoxShape()

	if AutoDrive.getSetting("enableTrafficDetection") == true then
		if self.vehicle.ad.sensors.frontSensorDynamic:pollInfo() then
			return true
		end
	end

	local excludedList = self.vehicle.ad.taskModule:getActiveTask():getExcludedVehiclesForCollisionCheck()

	local boundingBox = {}
    boundingBox[1] = box.topLeft
    boundingBox[2] = box.topRight
    boundingBox[3] = box.downRight
	boundingBox[4] = box.downLeft
	
	if AutoDrive:checkForVehicleCollision(self.vehicle, boundingBox, excludedList) then
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

function ADCollisionDetectionModule:checkReverseCollision()
    local trailers, trailerCount = AutoDrive.getTrailersOf(self.vehicle)
    if trailerCount > 0 then
        local trailer = trailers[trailerCount]
        if trailer ~= nil then
            if trailer.ad == nil then
                trailer.ad = {}
            end
            ADSensor:handleSensors(trailer, 0)
            trailer.ad.sensors.rearSensor.drawDebug = true
            trailer.ad.sensors.rearSensor.enabled = true
            return trailer.ad.sensors.rearSensor:pollInfo()
        end
	end
	return self.vehicle.ad.sensors.rearSensor:pollInfo()
end
