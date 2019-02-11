function AutoDrive:removeMapWayPoint(toDelete)
		AutoDrive:MarkChanged();
		
		--remove node on all out going nodes
		for _,node in pairs(toDelete.out) do			
			local IncomingCounter = 1;
			local deleted = false;
			for __,incoming in pairs(AutoDrive.mapWayPoints[node].incoming) do
				if incoming == toDelete.id then
					deleted = true
				end				
				if deleted then
					if AutoDrive.mapWayPoints[node].incoming[__ + 1] ~= nil then
						AutoDrive.mapWayPoints[node].incoming[__] = AutoDrive.mapWayPoints[node].incoming[__ + 1];
						--AutoDrive.mapWayPoints[node].incoming[__ + 1] = nil;
					else
						AutoDrive.mapWayPoints[node].incoming[__] = nil;
					end;
				end;								
			end;			
		end;
		
		--remove node on all incoming nodes
		
		for _,node in pairs(AutoDrive.mapWayPoints) do
			
			local deleted = false;
			for __,out_id in pairs(node.out) do
				if out_id == toDelete.id then
					deleted = true;
				end;
				
				
				if deleted then
					if node.out[__ + 1 ] ~= nil then
						node.out[__] = node.out[__+1];
						node.out_cost[__] = node.out_cost[__+1];
					else
						node.out[__] = nil;
						node.out_cost[__] = nil;
					end;
				end;
			end;
			
		end;
		
		--adjust ids for all succesive nodes :(
		
		local deleted = false;
		for _,node in pairs(AutoDrive.mapWayPoints) do
			if _ > toDelete.id then
				local oldID = node.id;				
				--adjust all possible references in nodes that have a connection with this node
				
				for __,innerNode in pairs(AutoDrive.mapWayPoints) do
					for ___,innerNodeOutID in pairs(innerNode.out) do
						if innerNodeOutID == oldID then
							innerNode.out[___] = oldID - 1;
						end;
					end;
				end;

				for __,outGoingID in pairs(node.out) do
					for ___,innerNodeIncoming in pairs(AutoDrive.mapWayPoints[outGoingID].incoming) do
						if innerNodeIncoming == oldID then
							AutoDrive.mapWayPoints[outGoingID].incoming[___] = oldID - 1;
						end;
					end;
				end;
				
				AutoDrive.mapWayPoints[_ - 1] = node;
				node.id = node.id - 1;
				
				if AutoDrive.mapWayPoints[_ + 1] == nil then
					deleted = true;
					AutoDrive.mapWayPoints[_] = nil;
					AutoDrive.mapWayPointsCounter = AutoDrive.mapWayPointsCounter - 1;
				end;
				
			end;
		end;
		--must have been last added waypoint that got deleted. handle this here:
		if deleted == false then
			AutoDrive.mapWayPoints[AutoDrive.mapWayPointsCounter] = nil;
			AutoDrive.mapWayPointsCounter = AutoDrive.mapWayPointsCounter - 1;
		end;
		
		--adjust all mapmarkers
		local deletedMarker = false;
		for _,marker in pairs(AutoDrive.mapMarker) do
			if marker.id == toDelete.id then
				deletedMarker = true;
			end;
			if deletedMarker then
				if AutoDrive.mapMarker[_+1] ~= nil then
					AutoDrive.mapMarker[_] =  AutoDrive.mapMarker[_+1];
				else
					AutoDrive.mapMarker[_] = nil;
				end;
			end;
			if marker.id > toDelete.id then
				marker.id = marker.id -1;
			end;
		end;
end;

function AutoDrive:removeMapMarker(toDelete)
	--adjust all mapmarkers
	local deletedMarker = false;
	for _,marker in pairs(AutoDrive.mapMarker) do
		if marker.id == toDelete.id then
			deletedMarker = true;
			AutoDrive.mapMarkerCounter = AutoDrive.mapMarkerCounter - 1;
		end;
		if deletedMarker then
			if AutoDrive.mapMarker[_+1] ~= nil then
				AutoDrive.mapMarker[_] =  AutoDrive.mapMarker[_+1];
			else
				AutoDrive.mapMarker[_] = nil;
			end;
		end;
	end;
	AutoDrive:MarkChanged()
end

function AutoDrive:createWayPoint(x, y, z, connectPrevious, dual)
	if vehicle.ad.createMapPoints == true then
		AutoDrive.mapWayPointsCounter = AutoDrive.mapWayPointsCounter + 1;
		if AutoDrive.mapWayPointsCounter > 1 and connectPrevious then
			--edit previous point
			local out_index = 1;
			if AutoDrive.mapWayPoints[AutoDrive.mapWayPointsCounter-1].out[out_index] ~= nil then out_index = out_index+1; end;
			AutoDrive.mapWayPoints[AutoDrive.mapWayPointsCounter-1].out[out_index] = AutoDrive.mapWayPointsCounter;
			AutoDrive.mapWayPoints[AutoDrive.mapWayPointsCounter-1].out_cost[out_index] = 1;
		end;
		
		--edit current point
		--print("Creating Waypoint #" .. AutoDrive.mapWayPointsCounter);
		AutoDrive.mapWayPoints[AutoDrive.mapWayPointsCounter] = createNode(AutoDrive.mapWayPointsCounter,{},{},{},{});
		if connectPrevious then
			AutoDrive.mapWayPoints[AutoDrive.mapWayPointsCounter].incoming[1] = AutoDrive.mapWayPointsCounter-1;
		end;
		AutoDrive.mapWayPoints[AutoDrive.mapWayPointsCounter].x = x;
		AutoDrive.mapWayPoints[AutoDrive.mapWayPointsCounter].y = y;
		AutoDrive.mapWayPoints[AutoDrive.mapWayPointsCounter].z = z;
	end;
	if vehicle.ad.creationModeDual == true then
		local incomingNodes = 1;
		for _,__ in pairs(AutoDrive.mapWayPoints[AutoDrive.mapWayPointsCounter-1].incoming) do
			incomingNodes = incomingNodes + 1;
		end;
		AutoDrive.mapWayPoints[AutoDrive.mapWayPointsCounter-1].incoming[incomingNodes] = AutoDrive.mapWayPointsCounter;
		--edit current point
		AutoDrive.mapWayPoints[AutoDrive.mapWayPointsCounter].out[1] = AutoDrive.mapWayPointsCounter-1;
		AutoDrive.mapWayPoints[AutoDrive.mapWayPointsCounter].out_cost[1] = 1;
	end;
end;

function AutoDrive:handleRecording(vehicle)
	if vehicle ~= g_currentMission.controlledVehicle or vehicle == nil or vehicle.ad.creationMode == false then
		return;
	end;

	local i = 1;
	for n in pairs(vehicle.ad.wayPoints) do 
		i = i+1;
	end;
	
	--first entry
	if i == 1 then
		local x1,y1,z1 = getWorldTranslation(vehicle.components[1].node);
		vehicle.ad.wayPoints[i] = createVector(x1,y1,z1);
		
		if vehicle.ad.createMapPoints == true then
			AutoDrive:createWayPoint(x1, y1, z1, false, vehicle.ad.creationModeDual)		
		end;
		
		i = i+1;
	else
		if i == 2 then
			local x,y,z = getWorldTranslation(vehicle.components[1].node);
			local wp = vehicle.ad.wayPoints[i-1];
			if getDistance(x,z,wp.x,wp.z) > 3 then
				vehicle.ad.wayPoints[i] = createVector(x,y,z);
				if vehicle.ad.createMapPoints == true then
					AutoDrive:createWayPoint(x, y, z, true, vehicle.ad.creationModeDual)		
				end;
				i = i+1;
			end;
		else
			local x,y,z = getWorldTranslation(vehicle.components[1].node);
			local wp = vehicle.ad.wayPoints[i-1];
			local wp_ref = vehicle.ad.wayPoints[i-2]
			local angle = AutoDrive:angleBetween( {x=x-wp_ref.x,z=z-wp_ref.z},{x=wp.x-wp_ref.x, z = wp.z - wp_ref.z } )
			local max_distance = 6;
			if angle < 1 then max_distance = 20; end;
			if angle >= 1 and angle < 2 then max_distance = 12; end;
			if angle >= 2 and angle < 3 then max_distance = 9; end;
			if angle >= 3 and angle < 5 then max_distance = 6; end;
			if angle >= 5 and angle < 8 then max_distance = 4; end;
			if angle >= 8 and angle < 12 then max_distance = 2; end;
			if angle >= 12 and angle < 15 then max_distance = 1; end;
			if angle >= 15 and angle < 50 then max_distance = 0.5; end;

			if getDistance(x,z,wp.x,wp.z) > max_distance then
				vehicle.ad.wayPoints[i] = createVector(x,y,z);
				if vehicle.ad.createMapPoints == true then
					AutoDrive:createWayPoint(x, y, z, true, vehicle.ad.creationModeDual)		
				end;
				i = i+1;
			end;
		end;
	end;
end;

function AutoDrive:handleRecalculation(vehicle)
	if AutoDrive.Recalculation ~= nil and vehicle == g_currentMission.controlledVehicle then
		if AutoDrive.Recalculation.continue == true then
			if AutoDrive.Recalculation.nextCalculationSkipFrames <= 0 then
				AutoDrive.recalculationPercentage = AutoDrive:ContiniousRecalculation();
				AutoDrive.Recalculation.nextCalculationSkipFrames = 0;

				AutoDrive.nPrintTime = 10000;
				AutoDrive.printMessage = g_i18n:getText("AD_Recalculationg_routes_status") .. " " .. AutoDrive.recalculationPercentage .. "%";
			else
				AutoDrive.Recalculation.nextCalculationSkipFrames =  AutoDrive.Recalculation.nextCalculationSkipFrames - 1;
			end;
		end;
	end;
end;