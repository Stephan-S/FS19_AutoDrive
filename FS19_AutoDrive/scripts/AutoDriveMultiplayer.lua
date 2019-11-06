function AutoDrive:handleMultiplayer(vehicle, dt)
    if AutoDrive == nil then
        return;
    end;

    if g_server ~= nil then
        if vehicle.lastUpdateEvent == nil then
            vehicle.lastUpdateEvent = AutoDriveUpdateEvent:new(vehicle)
            AutoDriveUpdateEvent:sendEvent(vehicle);
        else
            local newUpdate = AutoDriveUpdateEvent:new(vehicle);
            if newUpdate:compareTo(vehicle.lastUpdateEvent) == false then
                AutoDriveUpdateEvent:sendEvent(vehicle);
                vehicle.lastUpdateEvent = newUpdate;
            else
               -- print("No update required for " .. vehicle.name)
            end;
        end;
        
        local allAcksReceived, highestIndex = AutoDrive:checkUsers();    
        
        if allAcksReceived == true and AutoDrive.tableLength(AutoDrive.Server.Users) > 0 then
            if AutoDrive.requestedWaypointCount < AutoDrive.mapWayPointsCounter and AutoDrive.requestedWaypoints == true then
                AutoDrive.requestedWaypointCount = highestIndex;
                --print("Highest index of all users was: " .. highestIndex);
                for userID, user in pairs(AutoDrive.Server.Users) do
				    user.ackReceived = false;
			    end;
                AutoDriveCourseDownloadEvent:sendEvent(self);                
            else
                --print("Done sending network!");
                AutoDrive.requestedWaypoints = false;	
            end;
        end;

        if AutoDrive.tableLength(AutoDrive.Server.Users) == 0 then
            AutoDrive.requestedWaypoints = false;
        end;
    end;
    
    if g_server == nil then
        if vehicle.ad.requestWayPointTimer >= 0 then
            vehicle.ad.requestWayPointTimer = vehicle.ad.requestWayPointTimer - dt;
        end;

        if AutoDrive.requestedWaypoints ~= true and vehicle.ad.requestWayPointTimer < 0 and NetworkUtil.getObjectId(vehicle) ~= nil then
            AutoDriveRequestWayPointEvent:sendEvent(vehicle)	
            AutoDrive.requestedWaypoints = true;
        end;

        if AutoDrive.playerSendsMapToServer == true and AutoDrive.requestedWaypointCount < AutoDrive.mapWayPointsCounter then
            AutoDriveCourseDownloadEvent:sendEvent(vehicle);
        end;
    end;    
end;

function AutoDrive:checkUsers()
    local allAcksReceived = true;
    local aliveUsers = {};
    local highestIndex = AutoDrive.requestedWaypointCount;
    
    --print("Current users: " .. AutoDrive.tableLength(AutoDrive.Server.Users));
    for userID,user in pairs(AutoDrive.Server.Users) do 
        allAcksReceived = allAcksReceived and user.ackReceived;
        if user.ackReceived == false then
            user.keepAlive = math.max(user.keepAlive-1, 0);
        end;
        if user.keepAlive > 0 then
            aliveUsers[userID] = user;
            highestIndex = math.max(1, math.min(highestIndex, user.highestIndex));
        end;
        --print("User: " ..userID .. " ack: " .. AutoDrive.boolToString(user.ackReceived) .. " highest: " .. user.highestIndex .. " keepAlive: " .. user.keepAlive);
    end;
    AutoDrive.Server.Users = aliveUsers;

    return allAcksReceived, highestIndex;
end;

function AutoDrive:broadCastUpdateToClients()
    if g_server ~= nil then
        AutoDrive.requestedWaypoints = true;
        AutoDrive.requestedWaypointCount = 1;
    end;
end;