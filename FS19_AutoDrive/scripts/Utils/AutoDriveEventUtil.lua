function AutoDrive:writeWaypointsToStream(streamId, startId, endId)
    local idFullTable = {}
    local idCounter = 0

    local xTable = {}

    local yTable = {}

    local zTable = {}

    local outTable = {}

    local incomingTable = {}

    for i = startId, endId, 1 do
        local p = ADGraphManager:getWayPointById(i)

        idCounter = idCounter + 1
        idFullTable[idCounter] = p.id
        xTable[idCounter] = p.x
        yTable[idCounter] = p.y
        zTable[idCounter] = p.z

        outTable[idCounter] = table.concat(p.out, ",")

        local innerIncomingTable = {}
        for incomingIndex, incomingID in pairs(p.incoming) do
            innerIncomingTable[incomingIndex] = incomingID
        end
        incomingTable[idCounter] = table.concat(innerIncomingTable, ",")
    end

    if idFullTable[1] ~= nil then
        streamWriteInt32(streamId, idCounter)
        local i = 1
        while i <= idCounter do
            streamWriteInt32(streamId, idFullTable[i])
            streamWriteFloat32(streamId, xTable[i])
            streamWriteFloat32(streamId, yTable[i])
            streamWriteFloat32(streamId, zTable[i])
            AutoDrive.streamWriteStringOrEmpty(streamId, outTable[i])
            AutoDrive.streamWriteStringOrEmpty(streamId, incomingTable[i])

            i = i + 1
        end
    end
end

function AutoDrive:writeMapMarkersToStream(streamId)
    local markerCounter = #ADGraphManager:getMapMarker()
    streamWriteInt32(streamId, markerCounter)
    local i = 1
    while i <= markerCounter do
        streamWriteInt32(streamId, ADGraphManager:getMapMarkerById(i).id)
        AutoDrive.streamWriteStringOrEmpty(streamId, ADGraphManager:getMapMarkerById(i).name)
        AutoDrive.streamWriteStringOrEmpty(streamId, ADGraphManager:getMapMarkerById(i).group)
        i = i + 1
    end

    if g_server == nil then
        AutoDrive.requestedWaypoints = false
        AutoDrive.playerSendsMapToServer = false
    end
end

function AutoDrive:writeGroupsToStream(streamId)
    streamWriteInt32(streamId, table.count(AutoDrive.groups))
    for groupName, groupID in pairs(AutoDrive.groups) do
        AutoDrive.streamWriteStringOrEmpty(streamId, groupName)
        streamWriteFloat32(streamId, groupID)
    end
end

function AutoDrive:readWayPointsFromStream(streamId, numberOfWayPoints)
    local wp_counter = 0
    local highestId = 0
    local lowestId = math.huge
    while wp_counter < numberOfWayPoints do
        wp_counter = wp_counter + 1
        local wp = {}
        wp["id"] = streamReadInt32(streamId)
        wp.x = streamReadFloat32(streamId)
        wp.y = streamReadFloat32(streamId)
        wp.z = streamReadFloat32(streamId)

        local outTable = StringUtil.splitString(",", AutoDrive.streamReadStringOrEmpty(streamId))
        wp["out"] = {}
        for i2, outString in pairs(outTable) do
            wp["out"][i2] = tonumber(outString)
        end

        local incomingString = AutoDrive.streamReadStringOrEmpty(streamId)
        local incomingTable = StringUtil.splitString(",", incomingString)
        wp["incoming"] = {}
        local incoming_counter = 1
        for _, incomingID in pairs(incomingTable) do
            if incomingID ~= "" then
                wp["incoming"][incoming_counter] = tonumber(incomingID)
            end
            incoming_counter = incoming_counter + 1
        end

        ADGraphManager:setWayPoint(wp)

        highestId = math.max(highestId, wp.id)
        lowestId = math.min(lowestId, wp.id)

        --g_logManager:devInfo("Received waypoint from #" .. lowestId .. " to #" .. highestId);
    end
end

function AutoDrive:readMapMarkerFromStream(streamId, numberOfMapMarkers)
    local mapMarkerCount = 1
    while mapMarkerCount <= numberOfMapMarkers do
        local markerId = streamReadInt32(streamId)
        local markerName = AutoDrive.streamReadStringOrEmpty(streamId)
        local markerGroup = AutoDrive.streamReadStringOrEmpty(streamId)
        local marker = {}

        if ADGraphManager:getWayPointById(markerId) ~= nil then
            marker.id = markerId
            marker.name = markerName
            marker.group = markerGroup

            ADGraphManager:setMapMarker(marker)
            mapMarkerCount = mapMarkerCount + 1
        else
            g_logManager:error("[AutoDrive] Error receiving marker " .. markerName)
        end
    end
    AutoDrive:notifyDestinationListeners()
end

function AutoDrive:readGroupsFromStream(streamId)
    AutoDrive.groups = {}
    local numberOfGroups = streamReadInt32(streamId)
    local loopCounter = 1
    while loopCounter <= numberOfGroups do
        local groupName = AutoDrive.streamReadStringOrEmpty(streamId)
        local groupID = streamReadFloat32(streamId)
        if groupName ~= nil and groupName ~= "" then
            AutoDrive.groups[groupName] = groupID
        end
        loopCounter = loopCounter + 1
    end
    AutoDrive.groups["All"] = 1
end

function AutoDrive.streamReadStringOrEmpty(streamId)
    local string = streamReadString(streamId)
    if string == nil or string == "nil" then
        string = ""
    end
    return string
end

function AutoDrive.streamWriteStringOrEmpty(streamId, string)
    if string == nil or string == "" then
        string = "nil"
    end
    streamWriteString(streamId, string)
end

function AutoDrive.streamWriteInt32OrEmpty(streamId, value)
    if value == nil then
        value = 0
    end
    streamWriteInt32(streamId, value)
end

function AutoDrive.streamWriteInt16Or1337(streamId, value)
    if value == nil then
        value = 1337
    end
    streamWriteInt16(streamId, value)
end

function AutoDrive.streamReadInt16Or1337(streamId)
    local val = streamReadInt16(streamId)
    if val == nil then
        val = 1337
    end
    return val
end
