AutoDriveSync = {}
AutoDriveSync.MWPC_SEND_NUM_BITS = 0 -- that's dynamic
AutoDriveSync.MWPC_SNB_SEND_NUM_BITS = 5 -- 0 -> 31
AutoDriveSync.OIWPC_SEND_NUM_BITS = 6 -- 0 -> 63
AutoDriveSync.MC_SEND_NUM_BITS = 12 -- 0 -> 4095
AutoDriveSync.GC_SEND_NUM_BITS = 10 -- 0 -> 1023

AutoDriveSync_mt = Class(AutoDriveSync, Object)

InitObjectClass(AutoDriveSync, "AutoDriveSync")

function AutoDriveSync:new(isServer, isClient, customMt)
    local ads = Object:new(isServer, isClient, customMt or AutoDriveSync_mt)
    ads.dirtyFlag = ads:getNextDirtyFlag()
    registerObjectClassName(ads, "AutoDriveSync")
    return ads
end

function AutoDriveSync:delete()
    unregisterObjectClassName(self)
    AutoDriveSync:superClass().delete(self)
end

function AutoDriveSync:readStream(streamId)
    local paramsXZ = self.highPrecisionPositionSynchronization and g_currentMission.vehicleXZPosHighPrecisionCompressionParams or g_currentMission.vehicleXZPosCompressionParams
    local paramsY = self.highPrecisionPositionSynchronization and g_currentMission.vehicleYPosHighPrecisionCompressionParams or g_currentMission.vehicleYPosCompressionParams

    local offset = streamGetReadOffset(streamId)
    local time = netGetTime()

    -- reading the amount of bits we are going to use as "MWPC_SEND_NUM_BITS"
    AutoDriveSync.MWPC_SEND_NUM_BITS = streamReadUIntN(streamId, AutoDriveSync.MWPC_SNB_SEND_NUM_BITS)

    -- reading amount of waypoints we are going to read
    local wpsToRead = streamReadUIntN(streamId, AutoDriveSync.MWPC_SEND_NUM_BITS)
    g_logManager:devInfo(string.format("[AutoDriveSync] Reading %s way points", wpsToRead))

    -- reading waypoints
    for i = 1, wpsToRead do
        local x = NetworkUtil.readCompressedWorldPosition(streamId, paramsXZ)
        local y = NetworkUtil.readCompressedWorldPosition(streamId, paramsY)
        local z = NetworkUtil.readCompressedWorldPosition(streamId, paramsXZ)

        local wp = {id = i, x = x, y = y, z = z, out = {}, incoming = {}}

        -- reading amount of out nodes we are going to read
        local outCount = streamReadUIntN(streamId, AutoDriveSync.OIWPC_SEND_NUM_BITS)
        -- reading out nodes
        for ii = 1, outCount do
            wp.out[ii] = streamReadUIntN(streamId, AutoDriveSync.MWPC_SEND_NUM_BITS)
        end

        -- reading amount of incoming nodes we are going to read
        local incomingCount = streamReadUIntN(streamId, AutoDriveSync.OIWPC_SEND_NUM_BITS)
        -- reading incoming nodes
        for ii = 1, incomingCount do
            wp.incoming[ii] = streamReadUIntN(streamId, AutoDriveSync.MWPC_SEND_NUM_BITS)
        end

        ADGraphManager:setWayPoint(wp)
    end

    -- reading amount of markers we are going to read
    local mapMarkerCounter = streamReadUIntN(streamId, AutoDriveSync.MC_SEND_NUM_BITS)
    g_logManager:devInfo(string.format("[AutoDriveSync] Reading %s markers", mapMarkerCounter))
    -- reading markers
    for i = 1, mapMarkerCounter do
        local markerId = streamReadUIntN(streamId, AutoDriveSync.MWPC_SEND_NUM_BITS)
        if ADGraphManager:getWayPointById(markerId) ~= nil then
            local marker = {id = markerId, markerIndex=i, name = AutoDrive.streamReadStringOrEmpty(streamId), group = AutoDrive.streamReadStringOrEmpty(streamId)}
            ADGraphManager:setMapMarker(marker)
        else
            g_logManager:error(string.format("[AutoDriveSync] Error receiving marker %s (%s)", AutoDrive.streamReadStringOrEmpty(streamId), markerId))
            -- we have to read everything to keep the right reading order
            _ = AutoDrive.streamReadStringOrEmpty(streamId)
        end
    end

    -- reading amount of groups we are going to read
    local groupsCount = streamReadUIntN(streamId, AutoDriveSync.GC_SEND_NUM_BITS)
    g_logManager:devInfo(string.format("[AutoDriveSync] Reading %s groups", groupsCount))
    -- reading groups
    for i = 1, groupsCount do
        local gId = streamReadUIntN(streamId, AutoDriveSync.GC_SEND_NUM_BITS)
        local gName = AutoDrive.streamReadStringOrEmpty(streamId)
        if gName ~= nil and gName ~= "" then
            AutoDrive.groups[gName] = gId
        end
    end
    AutoDrive.groups["All"] = 1

    offset = streamGetReadOffset(streamId) - offset
    g_logManager:devInfo(string.format("[AutoDriveSync] Read %s bits (%s bytes) in %s ms", offset, offset / 8, netGetTime() - time))
    AutoDriveSync:superClass().readStream(self, streamId)
end

function AutoDriveSync:writeStream(streamId)
    local paramsXZ = self.highPrecisionPositionSynchronization and g_currentMission.vehicleXZPosHighPrecisionCompressionParams or g_currentMission.vehicleXZPosCompressionParams
    local paramsY = self.highPrecisionPositionSynchronization and g_currentMission.vehicleYPosHighPrecisionCompressionParams or g_currentMission.vehicleYPosCompressionParams

    local offset = streamGetWriteOffset(streamId)
    local time = netGetTime()

    -- writing the amount of bits we are going to use as "MWPC_SEND_NUM_BITS"
    AutoDriveSync.MWPC_SEND_NUM_BITS = math.ceil(math.log(ADGraphManager:getWayPointsCount() + 1, 2))
    streamWriteUIntN(streamId, AutoDriveSync.MWPC_SEND_NUM_BITS, AutoDriveSync.MWPC_SNB_SEND_NUM_BITS)

    -- writing the amount of waypoints we are going to send
    streamWriteUIntN(streamId, ADGraphManager:getWayPointsCount(), AutoDriveSync.MWPC_SEND_NUM_BITS)
    g_logManager:info(string.format("[AutoDriveSync] Writing %s waypoints", ADGraphManager:getWayPointsCount()))

    -- writing waypoints
    for i, wp in pairs(ADGraphManager:getWayPoints()) do
        if wp.id ~= i then
            g_logManager:error(string.format("[AutoDriveSync] Waypoint number %s have a wrong id %s", i, wp.id))
        end
        NetworkUtil.writeCompressedWorldPosition(streamId, wp.x, paramsXZ)
        NetworkUtil.writeCompressedWorldPosition(streamId, wp.y, paramsY)
        NetworkUtil.writeCompressedWorldPosition(streamId, wp.z, paramsXZ)

        -- writing the amount of out nodes we are going to send
        streamWriteUIntN(streamId, #wp.out, AutoDriveSync.OIWPC_SEND_NUM_BITS)
        -- writing out nodes
        for _, out in pairs(wp.out) do
            streamWriteUIntN(streamId, out, AutoDriveSync.MWPC_SEND_NUM_BITS)
        end

        -- writing the amount of incoming nodes we are going to send
        streamWriteUIntN(streamId, #wp.incoming, AutoDriveSync.OIWPC_SEND_NUM_BITS)
        -- writing incoming nodes
        for _, incoming in pairs(wp.incoming) do
            streamWriteUIntN(streamId, incoming, AutoDriveSync.MWPC_SEND_NUM_BITS)
        end
    end

    -- writing the amount of markers we are going to send
    local markersCount = #ADGraphManager:getMapMarkers()
    g_logManager:info(string.format("[AutoDriveSync] Writing %s markers", markersCount))
    streamWriteUIntN(streamId, markersCount, AutoDriveSync.MC_SEND_NUM_BITS)
    -- writing markers
    for _, marker in pairs(ADGraphManager:getMapMarkers()) do
        streamWriteUIntN(streamId, marker.id, AutoDriveSync.MWPC_SEND_NUM_BITS)
        AutoDrive.streamWriteStringOrEmpty(streamId, marker.name)
        AutoDrive.streamWriteStringOrEmpty(streamId, marker.group)
    end

    -- writing the amount of groups we are going to send
    local groupsCount = table.count(AutoDrive.groups)
    streamWriteUIntN(streamId, groupsCount, AutoDriveSync.GC_SEND_NUM_BITS)
    g_logManager:info(string.format("[AutoDriveSync] Writing %s groups", groupsCount))
    -- writing groups
    for gName, gId in pairs(AutoDrive.groups) do
        streamWriteUIntN(streamId, gId, AutoDriveSync.GC_SEND_NUM_BITS)
        AutoDrive.streamWriteStringOrEmpty(streamId, gName)
    end

    offset = streamGetWriteOffset(streamId) - offset
    g_logManager:info(string.format("[AutoDriveSync] Written %s bits (%s bytes) in %s ms", offset, offset / 8, netGetTime() - time))
    AutoDriveSync:superClass().writeStream(self, streamId)
end

function AutoDriveSync:readUpdateStream(streamId, timestamp, connection)
    --print(string.format("AutoDriveSync:readUpdateStream(%s, %s, %s)", streamId, timestamp, connection))
    AutoDriveSync:superClass().readUpdateStream(self, streamId, timestamp, connection)
end

function AutoDriveSync:writeUpdateStream(streamId, connection, dirtyMask)
    --print(string.format("AutoDriveSync:writeUpdateStream(%s, %s, %s)", streamId, connection, dirtyMask))
    AutoDriveSync:superClass().writeUpdateStream(self, streamId, connection, dirtyMask)
end

function AutoDriveSync:update(dt)
    AutoDriveSync:superClass().update(self, dt)
end

function AutoDriveSync:updateTick(dt)
    -- we need "update" both on server and client
    --self:raiseActive()

    -- we need "writeUpdateStream" only on server
    --if self.isServer then
    --    self:raiseDirtyFlags(self.dirtyFlag)
    --end

    AutoDriveSync:superClass().updateTick(self, dt)
end

function AutoDriveSync:draw()
    -- currently not called
    AutoDriveSync:superClass().draw(self)
end

function AutoDriveSync:mouseEvent(posX, posY, isDown, isUp, button)
    -- currently not called
    AutoDriveSync:superClass().mouseEvent(self, posX, posY, isDown, isUp, button)
end
