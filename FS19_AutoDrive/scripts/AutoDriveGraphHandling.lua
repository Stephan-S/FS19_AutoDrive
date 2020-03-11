function AutoDrive:handleRecording(vehicle)
	if vehicle == nil or vehicle.ad.creationMode == false then
		return
	end

	if g_server == nil then
		return
	end

	--first entry
	if vehicle.ad.lastCreatedWp == nil and vehicle.ad.secondLastCreatedWp == nil then
		local startPoint, _ = ADGraphManager:findClosestWayPoint(vehicle)
		local x1, y1, z1 = getWorldTranslation(vehicle.components[1].node)
		vehicle.ad.lastCreatedWp = ADGraphManager:createWayPoint(vehicle, x1, y1, z1, false, vehicle.ad.creationModeDual)

		if AutoDrive.getSetting("autoConnectStart") then
			if startPoint ~= nil then
				local startNode = ADGraphManager:getWayPointById(startPoint)
				if startNode ~= nil then
					if ADGraphManager:getDistanceBetweenNodes(startPoint, vehicle.ad.lastCreatedWp.id) < 20 then
						table.insert(startNode.out, vehicle.ad.lastCreatedWp.id)
						table.insert(vehicle.ad.lastCreatedWp.incoming, startNode.id)

						if vehicle.ad.creationModeDual then
							table.insert(ADGraphManager:getWayPointById(startPoint).incoming, vehicle.ad.lastCreatedWp.id)
							table.insert(vehicle.ad.lastCreatedWp.out, startPoint)
						end

						AutoDriveCourseEditEvent:sendEvent(startNode)
					end
				end
			end
		end
	else
		if vehicle.ad.secondLastCreatedWp == nil then
			local x, y, z = getWorldTranslation(vehicle.components[1].node)
			local wp = vehicle.ad.lastCreatedWp
			if AutoDrive.getDistance(x, z, wp.x, wp.z) > 3 then
				if vehicle.ad.createMapPoints == true then
					vehicle.ad.secondLastCreatedWp = vehicle.ad.lastCreatedWp
					vehicle.ad.lastCreatedWp = ADGraphManager:createWayPoint(vehicle, x, y, z, true, vehicle.ad.creationModeDual)
				end
			end
		else
			local x, y, z = getWorldTranslation(vehicle.components[1].node)
			local angle = math.abs(AutoDrive.angleBetween({x = x - vehicle.ad.secondLastCreatedWp.x, z = z - vehicle.ad.secondLastCreatedWp.z},
			 {x = vehicle.ad.lastCreatedWp.x - vehicle.ad.secondLastCreatedWp.x, z = vehicle.ad.lastCreatedWp.z - vehicle.ad.secondLastCreatedWp.z}))
			local max_distance = 6
			if angle < 1 then
				max_distance = 6
			elseif angle < 3 then
				max_distance = 4
			elseif angle < 5 then
				max_distance = 3
			elseif angle < 8 then
				max_distance = 2
			elseif angle < 15 then
				max_distance = 1
			elseif angle < 50 then
				max_distance = 0.5
			end

			if AutoDrive.getDistance(x, z, vehicle.ad.lastCreatedWp.x, vehicle.ad.lastCreatedWp.z) > max_distance then
				if vehicle.ad.createMapPoints == true then
					vehicle.ad.secondLastCreatedWp = vehicle.ad.lastCreatedWp
					vehicle.ad.lastCreatedWp = ADGraphManager:createWayPoint(vehicle, x, y, z, true, vehicle.ad.creationModeDual)
				end
			end
		end
	end
end











