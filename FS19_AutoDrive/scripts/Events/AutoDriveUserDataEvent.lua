AutoDriveUserDataEvent = {}
AutoDriveUserDataEvent_mt = Class(AutoDriveUserDataEvent, Event)

InitEventClass(AutoDriveUserDataEvent, "AutoDriveUserDataEvent")

function AutoDriveUserDataEvent:emptyNew()
    local o = Event:new(AutoDriveUserDataEvent_mt)
    o.className = "AutoDriveUserDataEvent"
    return o
end

function AutoDriveUserDataEvent:new(hudX, hudY, guiScale)
    local o = AutoDriveUserDataEvent:emptyNew()
    o.hudX = hudX
    o.hudY = hudY
    o.guiScale = guiScale
    return o
end

function AutoDriveUserDataEvent:writeStream(streamId, connection)
    streamWriteFloat32(streamId, self.hudX)
    streamWriteFloat32(streamId, self.hudY)
    streamWriteUInt8(streamId, self.guiScale)
end

function AutoDriveUserDataEvent:readStream(streamId, connection)
    self.hudX = streamReadFloat32(streamId)
    self.hudY = streamReadFloat32(streamId)
    self.guiScale = streamReadUInt8(streamId)
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
        AutoDrive.usersData[uniqueId].guiScale = self.guiScale
    else
        -- Applyng data if we are on the client
        AutoDrive.Hud:createHudAt(self.hudX, self.hudY)
        AutoDrive.setSettingState("guiScale", self.guiScale)
    end
end

function AutoDriveUserDataEvent.sendToClient(connection)
    local user = g_currentMission.userManager:getUserByConnection(connection)
    if g_server ~= nil and user ~= nil then
        local uniqueId = user.uniqueUserId
        if AutoDrive.usersData[uniqueId] ~= nil then
            connection:sendEvent(AutoDriveUserDataEvent:new(AutoDrive.usersData[uniqueId].hudX, AutoDrive.usersData[uniqueId].hudY, AutoDrive.usersData[uniqueId].guiScale))
        end
    end
end

function AutoDriveUserDataEvent.sendToServer()
    if g_server == nil then
        g_client:getServerConnection():sendEvent(AutoDriveUserDataEvent:new(AutoDrive.HudX, AutoDrive.HudY, AutoDrive.getSettingState("guiScale")))
    end
end
