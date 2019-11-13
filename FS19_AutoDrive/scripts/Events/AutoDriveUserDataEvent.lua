AutoDriveUserDataEvent = {}
AutoDriveUserDataEvent_mt = Class(AutoDriveUserDataEvent, Event)

InitEventClass(AutoDriveUserDataEvent, "AutoDriveUserDataEvent")

function AutoDriveUserDataEvent:emptyNew()
    local self = Event:new(AutoDriveUserDataEvent_mt)
    self.className = "AutoDriveUserDataEvent"
    return self
end

function AutoDriveUserDataEvent:new(hudX, hudY)
    local self = AutoDriveUserDataEvent:emptyNew()
    self.hudX = hudX
    self.hudY = hudY
    return self
end

function AutoDriveUserDataEvent:writeStream(streamId, connection)
    streamWriteFloat32(streamId, self.hudX)
    streamWriteFloat32(streamId, self.hudY)
end

function AutoDriveUserDataEvent:readStream(streamId, connection)
    self.hudX = streamReadFloat32(streamId)
    self.hudY = streamReadFloat32(streamId)
    self:run(connection)
end

function AutoDriveUserDataEvent:run(connection)
    if g_server ~= nil then
        -- Saving data if we are on the server
        local user = g_currentMission.userManager:getUserByConnection(connection)
        if user == nil then
            return
        end
        local uniqueId = user.uniqueUserId
        if AutoDrive.usersData[uniqueId] == nil then
            AutoDrive.usersData[uniqueId] = {}
        end
        AutoDrive.usersData[uniqueId].hudX = self.hudX
        AutoDrive.usersData[uniqueId].hudY = self.hudY
    else
        -- Applyng data if we are on the client
        AutoDrive.Hud:createHudAt(self.hudX, self.hudY)
    end
end

function AutoDriveUserDataEvent.sendToClient(connection)
    local user = g_currentMission.userManager:getUserByConnection(connection)
    if g_server ~= nil and user ~= nil then
        local uniqueId = user.uniqueUserId
        if AutoDrive.usersData[uniqueId] ~= nil then
            connection:sendEvent(AutoDriveUserDataEvent:new(AutoDrive.usersData[uniqueId].hudX, AutoDrive.usersData[uniqueId].hudY))
        end
    end
end

function AutoDriveUserDataEvent.sendToServer()
    if g_server == nil then
        g_client:getServerConnection():sendEvent(AutoDriveUserDataEvent:new(AutoDrive.HudX, AutoDrive.HudY))
    end
end
