AutoDriveUserDataEvent = {}
AutoDriveUserDataEvent_mt = Class(AutoDriveUserDataEvent, Event)

InitEventClass(AutoDriveUserDataEvent, "AutoDriveUserDataEvent")

function AutoDriveUserDataEvent:emptyNew()
    local o = Event:new(AutoDriveUserDataEvent_mt)
    o.className = "AutoDriveUserDataEvent"
    return o
end

function AutoDriveUserDataEvent:new(hudX, hudY, guiScale, wideHUD, notifications)
    local o = AutoDriveUserDataEvent:emptyNew()
    o.hudX = hudX
    o.hudY = hudY
    o.guiScale = guiScale
    o.wideHUD = wideHUD
    o.notifications = notifications
    return o
end

function AutoDriveUserDataEvent:writeStream(streamId, connection)
    streamWriteFloat32(streamId, self.hudX)
    streamWriteFloat32(streamId, self.hudY)
    streamWriteUInt8(streamId, self.guiScale)
    streamWriteUInt8(streamId, self.wideHUD)
    streamWriteUInt8(streamId, self.notifications)
end

function AutoDriveUserDataEvent:readStream(streamId, connection)
    self.hudX = streamReadFloat32(streamId)
    self.hudY = streamReadFloat32(streamId)
    self.guiScale = streamReadUInt8(streamId)
    self.wideHUD = streamReadUInt8(streamId)
    self.notifications = streamReadUInt8(streamId)
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
        AutoDrive.usersData[uniqueId].wideHUD = self.wideHUD
        AutoDrive.usersData[uniqueId].notifications = self.notifications
    else
        -- Applying data if we are on the client
        AutoDrive.Hud:createHudAt(self.hudX, self.hudY)
        AutoDrive.setSettingState("guiScale", self.guiScale)
        AutoDrive.setSettingState("wideHUD", self.wideHUD)
        AutoDrive.setSettingState("notifications", self.notifications)
    end
end

function AutoDriveUserDataEvent.sendToClient(connection)
    local user = g_currentMission.userManager:getUserByConnection(connection)
    if g_server ~= nil and user ~= nil then
        local uniqueId = user.uniqueUserId
        if AutoDrive.usersData[uniqueId] ~= nil then
            connection:sendEvent(AutoDriveUserDataEvent:new(AutoDrive.usersData[uniqueId].hudX, AutoDrive.usersData[uniqueId].hudY, AutoDrive.usersData[uniqueId].guiScale, AutoDrive.usersData[uniqueId].wideHUD, AutoDrive.usersData[uniqueId].notifications))
        end
    end
end

function AutoDriveUserDataEvent.sendToServer()
    if g_server == nil then
        g_client:getServerConnection():sendEvent(AutoDriveUserDataEvent:new(AutoDrive.HudX, AutoDrive.HudY, AutoDrive.getSettingState("guiScale"), AutoDrive.getSettingState("wideHUD"), AutoDrive.getSettingState("notifications")))
    end
end
