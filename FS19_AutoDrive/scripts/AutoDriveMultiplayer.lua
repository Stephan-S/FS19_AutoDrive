function AutoDrive.handleVehicleMultiplayer(vehicle, dt)
    if g_server ~= nil then
        if vehicle.lastUpdateEvent == nil then
            vehicle.lastUpdateEvent = AutoDriveUpdateEvent:new(vehicle)
            AutoDriveUpdateEvent:sendEvent(vehicle)
        else
            local newUpdate = AutoDriveUpdateEvent:new(vehicle)
            if newUpdate:compareTo(vehicle.lastUpdateEvent) == false then
                AutoDriveUpdateEvent:sendEvent(vehicle)
                vehicle.lastUpdateEvent = newUpdate
            else
                --g_logManager:devInfo("No update required for " .. vehicle.name)
            end
        end
    end
end

function AutoDrive:checkUsers()
    local allAcksReceived = true
    local aliveUsers = {}
    local highestIndex = AutoDrive.requestedWaypointCount

    --g_logManager:devInfo("Current users: " .. #AutoDrive.Server.Users);
    for userID, user in pairs(AutoDrive.Server.Users) do
        allAcksReceived = allAcksReceived and user.ackReceived
        if user.ackReceived == false then
            user.keepAlive = math.max(user.keepAlive - 1, 0)
        end
        if user.keepAlive > 0 then
            aliveUsers[userID] = user
            highestIndex = math.max(1, math.min(highestIndex, user.highestIndex))
        end
        --g_logManager:devInfo("User: " ..userID .. " ack: " .. AutoDrive.boolToString(user.ackReceived) .. " highest: " .. user.highestIndex .. " keepAlive: " .. user.keepAlive);
    end
    AutoDrive.Server.Users = aliveUsers

    return allAcksReceived, highestIndex
end

function AutoDrive:broadCastUpdateToClients()
    if g_server ~= nil then
        AutoDrive.requestedWaypoints = true
        AutoDrive.requestedWaypointCount = 1
    end
end
