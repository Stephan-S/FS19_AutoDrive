AutoDriveAcknowledgeCourseUpdateEvent = {}
AutoDriveAcknowledgeCourseUpdateEvent_mt = Class(AutoDriveAcknowledgeCourseUpdateEvent, Event)

InitEventClass(AutoDriveAcknowledgeCourseUpdateEvent, "AutoDriveAcknowledgeCourseUpdateEvent")

function AutoDriveAcknowledgeCourseUpdateEvent:emptyNew()
    local o = Event:new(AutoDriveAcknowledgeCourseUpdateEvent_mt)
    o.className = "AutoDriveAcknowledgeCourseUpdateEvent"
    return o
end

function AutoDriveAcknowledgeCourseUpdateEvent:new(highestIndex)
    local o = AutoDriveAcknowledgeCourseUpdateEvent:emptyNew()
    o.highestIndex = highestIndex
    return o
end

function AutoDriveAcknowledgeCourseUpdateEvent:writeStream(streamId, connection)
    if g_server == nil then
        local user = g_currentMission.userManager:getUserByUserId(g_currentMission.playerUserId)
        streamWriteInt32(streamId, user:getId())
        streamWriteInt32(streamId, self.highestIndex)
    end
end

function AutoDriveAcknowledgeCourseUpdateEvent:readStream(streamId, connection)
    if g_server ~= nil then
        local userID = streamReadInt32(streamId)
        local highestIndexFromPlayer = streamReadInt32(streamId)

        if AutoDrive.Server.Users[userID] ~= nil then
            AutoDrive.Server.Users[userID].highestIndex = highestIndexFromPlayer
            AutoDrive.Server.Users[userID].ackReceived = true
            AutoDrive.Server.Users[userID].keepAlive = 300
        end
    end
end

function AutoDriveAcknowledgeCourseUpdateEvent:sendEvent(highestIndex)
    if g_server == nil then
        g_client:getServerConnection():sendEvent(AutoDriveAcknowledgeCourseUpdateEvent:new(highestIndex))
    end
end
