AutoDriveSync = {}
AutoDriveSync.MWPC_SEND_NUM_BITS = 0 -- that's dynamic
AutoDriveSync.MWPC_SNB_SEND_NUM_BITS = 5 -- 0 -> 31
AutoDriveSync.OIWPC_SEND_NUM_BITS = 6 -- 0 -> 63
AutoDriveSync.MC_SEND_NUM_BITS = 12 -- 0 -> 4095
AutoDriveSync.GC_SEND_NUM_BITS = 10 -- 0 -> 1023

AutoDriveSync_mt = Class(AutoDriveSync, Object)

InitObjectClass(AutoDriveSync, "AutoDriveSyncc")

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

    -- reading the amount of bits we are going to use as "MWPC_SEND_NUM_BITS"
    AutoDriveSync.MWPC_SEND_NUM_BITS = streamReadUIntN(streamId, AutoDriveSync.MWPC_SNB_SEND_NUM_BITS)

    -- reading amount of waypoints we are going to send
    AutoDrive.mapWayPointsCounter = streamReadUIntN(streamId, AutoDriveSync.MWPC_SEND_NUM_BITS)
    g_logManager:devInfo(string.format("Reading %s way points", AutoDrive.mapWayPointsCounter))

    -- reading waypoints
    for i = 1, AutoDrive.mapWayPointsCounter do
        local wp = {}
        wp.id = i
        wp.x = NetworkUtil.readCompressedWorldPosition(streamId, paramsXZ)
        wp.y = NetworkUtil.readCompressedWorldPosition(streamId, paramsY)
        wp.z = NetworkUtil.readCompressedWorldPosition(streamId, paramsXZ)

        wp.out = {}
        -- reading amount of out nodes we are going to send
        local outCount = streamReadUIntN(streamId, AutoDriveSync.OIWPC_SEND_NUM_BITS)
        -- reading out nodes
        for ii = 1, outCount do
            wp.out[ii] = streamReadUIntN(streamId, AutoDriveSync.MWPC_SEND_NUM_BITS)
        end

        wp.incoming = {}
        -- reading amount of incoming nodes we are going to send
        local incomingCount = streamReadUIntN(streamId, AutoDriveSync.OIWPC_SEND_NUM_BITS)
        -- reading incoming nodes
        for ii = 1, incomingCount do
            wp.incoming[ii] = streamReadUIntN(streamId, AutoDriveSync.MWPC_SEND_NUM_BITS)
        end

        AutoDrive.mapWayPoints[wp.id] = wp
    end

    -- reading amount of markers we are going to send
    AutoDrive.mapMarkerCounter = streamReadUIntN(streamId, AutoDriveSync.MC_SEND_NUM_BITS)
    g_logManager:devInfo(string.format("Reading %s markers", AutoDrive.mapMarkerCounter))
    -- reading markers
    for ii = 1, AutoDrive.mapMarkerCounter do
        local markerId = streamReadUIntN(streamId, AutoDriveSync.MWPC_SEND_NUM_BITS)
        if AutoDrive.mapWayPoints[markerId] ~= nil then
            local marker = {}
            marker.id = markerId
            marker.name = AutoDrive.streamReadStringOrEmpty(streamId)
            marker.group = AutoDrive.streamReadStringOrEmpty(streamId)

            local node = createTransformGroup(marker.name)
            setTranslation(node, AutoDrive.mapWayPoints[markerId].x, AutoDrive.mapWayPoints[markerId].y + 4, AutoDrive.mapWayPoints[markerId].z)
            marker.node = node

            AutoDrive.mapMarker[ii] = marker
        else
            g_logManager:error(string.format("[AutoDrive] Error receiving marker %s (%s)", AutoDrive.streamReadStringOrEmpty(streamId), markerId))
            -- we have to read everything to keep the right reading order
            _ = AutoDrive.streamReadStringOrEmpty(streamId)
        end
    end

    -- reading amount of groups we are going to send
    local groupsCount = streamReadUIntN(streamId, AutoDriveSync.GC_SEND_NUM_BITS)
    g_logManager:devInfo(string.format("Reading %s groups", groupsCount))
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
    g_logManager:devInfo(string.format("Read %s bits (%s bytes)", offset, offset / 8))
    AutoDriveSync:superClass().readStream(self, streamId)
end

function AutoDriveSync:writeStream(streamId)
    local paramsXZ = self.highPrecisionPositionSynchronization and g_currentMission.vehicleXZPosHighPrecisionCompressionParams or g_currentMission.vehicleXZPosCompressionParams
    local paramsY = self.highPrecisionPositionSynchronization and g_currentMission.vehicleYPosHighPrecisionCompressionParams or g_currentMission.vehicleYPosCompressionParams

    local offset = streamGetWriteOffset(streamId)

    -- writing the amount of bits we are going to use as "MWPC_SEND_NUM_BITS"
    AutoDriveSync.MWPC_SEND_NUM_BITS = math.ceil(math.log(AutoDrive.mapWayPointsCounter, 2))
    streamWriteUIntN(streamId, AutoDriveSync.MWPC_SEND_NUM_BITS, AutoDriveSync.MWPC_SNB_SEND_NUM_BITS)

    -- writing the amount of waypoints we are going to send
    streamWriteUIntN(streamId, AutoDrive.tableLength(AutoDrive.mapWayPoints), AutoDriveSync.MWPC_SEND_NUM_BITS)
    g_logManager:info(string.format("Writing %s waypoints", AutoDrive.mapWayPointsCounter))

    -- writing waypoints
    for i = 1, AutoDrive.mapWayPointsCounter do
        local wp = AutoDrive.mapWayPoints[i]
        if wp.id ~= i then
            g_logManager:error(string.format("Waypoint number %s have a wrong id %s", i, wp.id))
        end
        NetworkUtil.writeCompressedWorldPosition(streamId, wp.x, paramsXZ)
        NetworkUtil.writeCompressedWorldPosition(streamId, wp.y, paramsY)
        NetworkUtil.writeCompressedWorldPosition(streamId, wp.z, paramsXZ)

        -- writing the amount of out nodes we are going to send
        streamWriteUIntN(streamId, AutoDrive.tableLength(wp.out), AutoDriveSync.OIWPC_SEND_NUM_BITS)
        -- writing out nodes
        for _, out in pairs(wp.out) do
            streamWriteUIntN(streamId, out, AutoDriveSync.MWPC_SEND_NUM_BITS)
        end

        -- writing the amount of incoming nodes we are going to send
        streamWriteUIntN(streamId, AutoDrive.tableLength(wp.incoming), AutoDriveSync.OIWPC_SEND_NUM_BITS)
        -- writing incoming nodes
        for _, incoming in pairs(wp.incoming) do
            streamWriteUIntN(streamId, incoming, AutoDriveSync.MWPC_SEND_NUM_BITS)
        end
    end

    -- writing the amount of markers we are going to send
    local markersCount = AutoDrive.tableLength(AutoDrive.mapMarker)
    g_logManager:info(string.format("Writing %s markers", markersCount))
    streamWriteUIntN(streamId, markersCount, AutoDriveSync.MC_SEND_NUM_BITS)
    -- writing markers
    for _, marker in pairs(AutoDrive.mapMarker) do
        streamWriteUIntN(streamId, marker.id, AutoDriveSync.MWPC_SEND_NUM_BITS)
        AutoDrive.streamWriteStringOrEmpty(streamId, marker.name)
        AutoDrive.streamWriteStringOrEmpty(streamId, marker.group)
    end

    -- writing the amount of groups we are going to send
    local groupsCount = AutoDrive.tableLength(AutoDrive.groups)
    streamWriteUIntN(streamId, groupsCount, AutoDriveSync.GC_SEND_NUM_BITS)
    g_logManager:info(string.format("Writing %s groups", groupsCount))
    -- writing groups
    for gName, gId in pairs(AutoDrive.groups) do
        streamWriteUIntN(streamId, gId, AutoDriveSync.GC_SEND_NUM_BITS)
        AutoDrive.streamWriteStringOrEmpty(streamId, gName)
    end

    offset = streamGetWriteOffset(streamId) - offset
    g_logManager:info(string.format("Written %s bits (%s bytes)", offset, offset / 8))
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
