ADStateModule = {}

ADStateModule.CREATE_OFF = 1
ADStateModule.CREATE_NORMAL = 2
ADStateModule.CREATE_DUAL = 3

ADStateModule.EDITOR_OFF = 1
ADStateModule.EDITOR_ON = 2
ADStateModule.EDITOR_EXTENDED = 3
ADStateModule.EDITOR_SHOW = 4

function ADStateModule:new(vehicle)
    local o = {}
    setmetatable(o, self)
    self.__index = self
    o.vehicle = vehicle
    ADStateModule.reset(o)
    return o
end

function ADStateModule:reset()
    self.active = false
    self.activeBeforeSave = false
    self.AIVEActiveBeforeSave = false
    self.mode = AutoDrive.MODE_DRIVETO
    self.firstMarker = ADGraphManager:getMapMarkerById(1)
    self.secondMarker = ADGraphManager:getMapMarkerById(1)
    self.creationMode = ADStateModule.CREATE_OFF
    self.editorMode = ADStateModule.EDITOR_OFF

    self.fillType = 2
    self.loopCounter = 0

    self.speedLimit = AutoDrive.getVehicleMaxSpeed(self.vehicle)
    self.fieldSpeedLimit = AutoDrive.getVehicleMaxSpeed(self.vehicle)

    self.parkDestination = -1

    self.currentDestination = nil

    self.currentTaskInfo = ""
    self.currentLocalizedTaskInfo = ""

    self.currentWayPointId = -1
    self.nextWayPointId = -1

    self.pointToNeighbour = false
    self.currentNeighbourToPointAt = -1
    self.neighbourPoints = {}

    self.startAI = false
    self.useCP = true

    self.driverName = g_i18n:getText("UNKNOWN")
    if self.vehicle.getName ~= nil then
        self.driverName = self.vehicle:getName()
    end
end

function ADStateModule:readFromXMLFile(xmlFile, key)
    local mode = getXMLInt(xmlFile, key .. "#mode")
    if mode ~= nil then
        self.mode = mode
    end

    local speedLimit = getXMLInt(xmlFile, key .. "#speedLimit")
    if speedLimit ~= nil then
        self.speedLimit = math.min(speedLimit, AutoDrive.getVehicleMaxSpeed(self.vehicle))
    end

    local fieldSpeedLimit = getXMLInt(xmlFile, key .. "#fieldSpeedLimit")
    if fieldSpeedLimit ~= nil then
        self.fieldSpeedLimit = math.min(fieldSpeedLimit, AutoDrive.getVehicleMaxSpeed(self.vehicle))
    end

    local firstMarker = getXMLInt(xmlFile, key .. "#firstMarker")
    if firstMarker ~= nil then
        self.firstMarker = ADGraphManager:getMapMarkerById(firstMarker)
    else
        self.firstMarker = ADGraphManager:getMapMarkerById(1)
    end

    local secondMarker = getXMLInt(xmlFile, key .. "#secondMarker")
    if secondMarker ~= nil then
        self.secondMarker = ADGraphManager:getMapMarkerById(secondMarker)
    else
        self.secondMarker = ADGraphManager:getMapMarkerById(1)
    end

    local fillType = getXMLInt(xmlFile, key .. "#fillType")
    if fillType ~= nil then
        self.fillType = fillType
    end

    local driverName = getXMLString(xmlFile, key .. "#driverName")
    if driverName ~= nil then
        self.driverName = driverName
    end

    local loopCounter = getXMLInt(xmlFile, key .. "#loopCounter")
    if loopCounter ~= nil then
        self.loopCounter = loopCounter
    end

    local parkDestination = getXMLInt(xmlFile, key .. "#parkDestination")
    if parkDestination ~= nil then
        self.parkDestination = parkDestination
    end

    local lastActive = getXMLBool(xmlFile, key .. "#lastActive")
    if lastActive ~= nil then
        self.activeBeforeSave = lastActive
    end

    local AIVElastActive = getXMLBool(xmlFile, key .. "#AIVElastActive")
    if AIVElastActive ~= nil then
        self.AIVEActiveBeforeSave = AIVElastActive
    end
end

function ADStateModule:saveToXMLFile(xmlFile, key)
    setXMLInt(xmlFile, key .. "#mode", self.mode)
    setXMLInt(xmlFile, key .. "#speedLimit", self.speedLimit)
    setXMLInt(xmlFile, key .. "#fieldSpeedLimit", self.fieldSpeedLimit)
    if self.firstMarker ~= nil then
        setXMLInt(xmlFile, key .. "#firstMarker", self.firstMarker.markerIndex)
    end
    if self.secondMarker ~= nil then
        setXMLInt(xmlFile, key .. "#secondMarker", self.secondMarker.markerIndex)
    end
    setXMLInt(xmlFile, key .. "#fillType", self.fillType)
    setXMLString(xmlFile, key .. "#driverName", self.driverName)
    setXMLInt(xmlFile, key .. "#loopCounter", self.loopCounter)
    setXMLInt(xmlFile, key .. "#parkDestination", self.parkDestination)
    setXMLBool(xmlFile, key .. "#lastActive", self.active)
    setXMLBool(xmlFile, key .. "#AIVElastActive", (self.vehicle.acParameters ~= nil and self.vehicle.acParameters.enabled and self.vehicle.spec_aiVehicle.isActive))
end

function ADStateModule:writeStream(streamId)
    streamWriteBool(streamId, self.active)
    streamWriteUIntN(streamId, self.mode, 4)
    streamWriteUIntN(streamId, self:getFirstMarkerId() + 1, 10)
    streamWriteUIntN(streamId, self:getSecondMarkerId() + 1, 10)
    streamWriteUIntN(streamId, self.creationMode, 3)
    streamWriteUIntN(streamId, self.editorMode, 3)
    streamWriteUIntN(streamId, self.fillType, 8)
    streamWriteUIntN(streamId, self.loopCounter, 4)
    streamWriteUIntN(streamId, self.speedLimit, 8)
    streamWriteUIntN(streamId, self.fieldSpeedLimit, 8)
    streamWriteUIntN(streamId, self.parkDestination + 1, 20)
    streamWriteUIntN(streamId, self:getCurrentDestinationId() + 1, 10)
    streamWriteString(streamId, self.currentTaskInfo)
    streamWriteUIntN(streamId, self.currentWayPointId + 1, 20)
    streamWriteUIntN(streamId, self.nextWayPointId + 1, 20)
    streamWriteBool(streamId, self.startAI)
    streamWriteBool(streamId, self.useCP)
end

function ADStateModule:readStream(streamId)
    self.active = streamReadBool(streamId)
    self.mode = streamReadUIntN(streamId, 4)
    self.firstMarker = ADGraphManager:getMapMarkerById(streamReadUIntN(streamId, 10) - 1)
    self.secondMarker = ADGraphManager:getMapMarkerById(streamReadUIntN(streamId, 10) - 1)
    self.creationMode = streamReadUIntN(streamId, 3)
    self.editorMode = streamReadUIntN(streamId, 3)
    self.fillType = streamReadUIntN(streamId, 8)
    self.loopCounter = streamReadUIntN(streamId, 4)
    self.speedLimit = streamReadUIntN(streamId, 8)
    self.fieldSpeedLimit = streamReadUIntN(streamId, 8)
    self.parkDestination = streamReadUIntN(streamId, 20) - 1
    self.currentDestination = ADGraphManager:getMapMarkerById(streamReadUIntN(streamId, 10) - 1)
    self.currentTaskInfo = streamReadString(streamId)
    self.currentLocalizedTaskInfo = AutoDrive.localize(self.currentTaskInfo)
    self.currentWayPointId = streamReadUIntN(streamId, 20) - 1
    self.nextWayPointId = streamReadUIntN(streamId, 20) - 1
    self.startAI = streamReadBool(streamId)
    self.useCP = streamReadBool(streamId)
end

function ADStateModule:writeUpdateStream(streamId)
    streamWriteBool(streamId, self.active)
    streamWriteUIntN(streamId, self.mode, 4)
    streamWriteUIntN(streamId, self:getFirstMarkerId() + 1, 10)
    streamWriteUIntN(streamId, self:getSecondMarkerId() + 1, 10)
    streamWriteUIntN(streamId, self.creationMode, 3)
    streamWriteUIntN(streamId, self.editorMode, 3)
    streamWriteUIntN(streamId, self.fillType, 8)
    streamWriteUIntN(streamId, self.loopCounter, 4)
    streamWriteUIntN(streamId, self.speedLimit, 8)
    streamWriteUIntN(streamId, self.fieldSpeedLimit, 8)
    streamWriteUIntN(streamId, self.parkDestination + 1, 20)
    streamWriteUIntN(streamId, self:getCurrentDestinationId() + 1, 10)
    streamWriteString(streamId, self.currentTaskInfo)
    streamWriteUIntN(streamId, self.currentWayPointId + 1, 20)
    streamWriteUIntN(streamId, self.nextWayPointId + 1, 20)
    streamWriteBool(streamId, self.startAI)
    streamWriteBool(streamId, self.useCP)
end

function ADStateModule:readUpdateStream(streamId)
    self.active = streamReadBool(streamId)
    self.mode = streamReadUIntN(streamId, 4)
    self.firstMarker = ADGraphManager:getMapMarkerById(streamReadUIntN(streamId, 10) - 1)
    self.secondMarker = ADGraphManager:getMapMarkerById(streamReadUIntN(streamId, 10) - 1)
    self.creationMode = streamReadUIntN(streamId, 3)
    self.editorMode = streamReadUIntN(streamId, 3)
    self.fillType = streamReadUIntN(streamId, 8)
    self.loopCounter = streamReadUIntN(streamId, 4)
    self.speedLimit = streamReadUIntN(streamId, 8)
    self.fieldSpeedLimit = streamReadUIntN(streamId, 8)
    self.parkDestination = streamReadUIntN(streamId, 20) - 1
    self.currentDestination = ADGraphManager:getMapMarkerById(streamReadUIntN(streamId, 10) - 1)
    self.currentTaskInfo = streamReadString(streamId)
    self.currentLocalizedTaskInfo = AutoDrive.localize(self.currentTaskInfo)
    self.currentWayPointId = streamReadUIntN(streamId, 20) - 1
    self.nextWayPointId = streamReadUIntN(streamId, 20) - 1
    self.startAI = streamReadBool(streamId)
    self.useCP = streamReadBool(streamId)
end

function ADStateModule:update(dt)
    if AutoDrive.getDebugChannelIsSet(AutoDrive.DC_VEHICLEINFO) then
        local debug = {}
        debug.active = self.active
        debug.mode = self.mode
        debug.firstMarker = self.firstMarker.name
        debug.secondMarker = self.secondMarker.name
        debug.creationMode = self.creationMode
        debug.editorMode = self.editorMode
        debug.fillType = self.fillType
        debug.loopCounter = self.loopCounter
        debug.speedLimit = self.speedLimit
        debug.fieldSpeedLimit = self.fieldSpeedLimit
        debug.parkDestination = self.parkDestination
        if self.currentDestination ~= nil then
            debug.currentDestination = self.currentDestination.name
        end
        debug.currentTaskInfo = self.currentTaskInfo
        debug.currentLocalizedTaskInfo = self.currentLocalizedTaskInfo
        debug.currentWayPointId = self.currentWayPointId
        debug.nextWayPointId = self.nextWayPointId
        debug.startAI = self.startAI
        debug.useCP = self.useCP
        if self.vehicle.ad.modes[AutoDrive.MODE_UNLOAD].combine ~= nil then
            debug.combine = self.vehicle.ad.modes[AutoDrive.MODE_UNLOAD].combine:getName()
        else
            debug.combine = "-"
        end
        if ADHarvestManager:getAssignedUnloader(self.vehicle) ~= nil then
            debug.unloader = ADHarvestManager:getAssignedUnloader(self.vehicle):getName()
        else
            debug.unloader = "-"
        end
        if self.vehicle.ad.modes[AutoDrive.MODE_UNLOAD]:getFollowingUnloader() ~= nil then
            debug.follower = self.vehicle.ad.modes[AutoDrive.MODE_UNLOAD]:getFollowingUnloader():getName()
        else
            debug.follower = "-"
        end
        AutoDrive.renderTable(0.4, 0.4, 0.014, debug)
    end
end

function ADStateModule:toggleStartAI()
    self.startAI = not self.startAI
    self:raiseDirtyFlag()
end

function ADStateModule:setStartAI(enabled)
    if enabled ~= self.startAI then
        self.startAI = enabled
        self:raiseDirtyFlag()
    end
end

function ADStateModule:getStartAI()
    return self.startAI
end

function ADStateModule:toggleUseCP()
    self.useCP = not self.useCP
    self:raiseDirtyFlag()
end

function ADStateModule:getUseCP()
    return self.useCP
end

function ADStateModule:getCurrentWayPointId()
    return self.currentWayPointId
end

function ADStateModule:setCurrentWayPointId(wayPointId)
    if wayPointId ~= self.currentWayPointId then
        self.currentWayPointId = wayPointId
        self:raiseDirtyFlag()
    end
end

function ADStateModule:getCurrentWayPoint()
    return ADGraphManager:getWayPointById(self.currentWayPointId)
end

function ADStateModule:getNextWayPointId()
    return self.nextWayPointId
end

function ADStateModule:setNextWayPointId(wayPointId)
    if wayPointId ~= self.nextWayPointId then
        self.nextWayPointId = wayPointId
        self:raiseDirtyFlag()
    end
end

function ADStateModule:getNextWayPoint()
    if self.nextWayPointId > 1 then
        return ADGraphManager:getWayPointById(self.nextWayPointId)
    end
    return nil
end

function ADStateModule:getCurrentTaskInfo()
    return self.currentTaskInfo
end

function ADStateModule:getCurrentLocalizedTaskInfo()
    return self.currentLocalizedTaskInfo
end

function ADStateModule:setCurrentTaskInfo(text)
    if text ~= nil and text ~= self.currentTaskInfo then
        self.currentTaskInfo = text
        self.currentLocalizedTaskInfo = AutoDrive.localize(text)
        self:raiseDirtyFlag()
    end
end

function ADStateModule:getCurrentDestination()
    return self.currentDestination
end

function ADStateModule:getCurrentDestinationId()
    if self.currentDestination ~= nil then
        return self.currentDestination.markerIndex
    end
    return -1
end

function ADStateModule:setCurrentDestination(marker)
    self.currentDestination = marker
    self:raiseDirtyFlag()
end

function ADStateModule:getMode()
    return self.mode
end

function ADStateModule:getCurrentMode()
    return self.vehicle.ad.modes[self.mode]
end

function ADStateModule:nextMode()
    if self.mode < AutoDrive.MODE_UNLOAD then
        self.mode = self.mode + 1
    else
        self.mode = AutoDrive.MODE_DRIVETO
    end
    self:raiseDirtyFlag()
end

function ADStateModule:previousMode()
    if self.mode > AutoDrive.MODE_DRIVETO then
        self.mode = self.mode - 1
    else
        self.mode = AutoDrive.MODE_UNLOAD
    end
    self:raiseDirtyFlag()
end

function ADStateModule:setMode(newMode)
    if newMode >= AutoDrive.MODE_DRIVETO and newMode <= AutoDrive.MODE_UNLOAD and newMode ~= self.mode then
        self.mode = newMode
        self:raiseDirtyFlag()
    end
end

function ADStateModule:isActive()
    return self.active
end

function ADStateModule:setActive(active)
    if active ~= self.active then
        self.active = active
        self:raiseDirtyFlag()
    end

    if self.active then
        self.creationMode = ADStateModule.CREATE_OFF
        self:raiseDirtyFlag()
    end
end

function ADStateModule:isEditorModeEnabled()
    return self.editorMode ~= ADStateModule.EDITOR_OFF and self.editorMode ~= ADStateModule.EDITOR_SHOW
end

function ADStateModule:isEditorShowEnabled()
    return self.editorMode == ADStateModule.EDITOR_SHOW
end

function ADStateModule:isInExtendedEditorMode()
    return self.editorMode == ADStateModule.EDITOR_EXTENDED
end

function ADStateModule:getEditorMode()
    return self.editorMode
end

function ADStateModule:setEditorMode(editorMode)
    self.editorMode = editorMode
end

function ADStateModule:cycleEditMode()
    if self.editorMode == ADStateModule.EDITOR_OFF then
        self.editorMode = ADStateModule.EDITOR_ON
    elseif self.editorMode == ADStateModule.EDITOR_ON and AutoDrive.getSetting("secondEditorModeAllowed") then
        self.editorMode = ADStateModule.EDITOR_EXTENDED
    elseif self.editorMode == ADStateModule.EDITOR_EXTENDED or self.editorMode == ADStateModule.EDITOR_SHOW or ((not AutoDrive.getSetting("secondEditorModeAllowed")) and self.editorMode == ADStateModule.EDITOR_ON) then
        self.editorMode = ADStateModule.EDITOR_OFF
        self.vehicle.ad.selectedNodeId = nil
    end
    self:raiseDirtyFlag()
end

function ADStateModule:cycleEditorShowMode()
    if self.editorMode == ADStateModule.EDITOR_OFF then
        self.editorMode = ADStateModule.EDITOR_SHOW
    else
        self.editorMode = ADStateModule.EDITOR_OFF
    end
    self:raiseDirtyFlag()
end

function ADStateModule:isInCreationMode()
    return self.creationMode ~= ADStateModule.CREATE_OFF
end

function ADStateModule:isInNormalCreationMode()
    return self.creationMode == ADStateModule.CREATE_NORMAL
end

function ADStateModule:isInDualCreationMode()
    return self.creationMode == ADStateModule.CREATE_DUAL
end

function ADStateModule:disableCreationMode()
    self.creationMode = ADStateModule.CREATE_OFF
    self:raiseDirtyFlag()
end

function ADStateModule:startNormalCreationMode()
    self.creationMode = ADStateModule.CREATE_NORMAL
    self:raiseDirtyFlag()
    self:setActive(false)
end

function ADStateModule:startDualCreationMode()
    self.creationMode = ADStateModule.CREATE_DUAL
    self:raiseDirtyFlag()
    self:setActive(false)
end

function ADStateModule:getLoopCounter()
    return self.loopCounter
end

function ADStateModule:increaseLoopCounter()
    self.loopCounter = (self.loopCounter + 1) % 10
    self:raiseDirtyFlag()
end

function ADStateModule:decreaseLoopCounter()
    if self.loopCounter > 0 then
        self.loopCounter = self.loopCounter - 1
    else
        self.loopCounter = 9
    end
    self:raiseDirtyFlag()
end

function ADStateModule:setName(newName)
    self.driverName = newName
end

function ADStateModule:getName()
    return self.driverName
end

function ADStateModule:getFirstMarker()
    return self.firstMarker
end

function ADStateModule:getFirstMarkerId()
    if self.firstMarker ~= nil then
        return self.firstMarker.markerIndex
    else
        return -1
    end
end

function ADStateModule:getFirstWayPoint()
    if self.firstMarker ~= nil then
        return self.firstMarker.id
    else
        return -1
    end
end

function ADStateModule:getFirstMarkerName()
    if self.firstMarker ~= nil then
        return self.firstMarker.name
    else
        return nil
    end
end

function ADStateModule:setFirstMarker(markerId)
    self.firstMarker = ADGraphManager:getMapMarkerById(markerId)
    self:raiseDirtyFlag()
end

function ADStateModule:setFirstMarkerByWayPointId(wayPointId)
    for markerId, mapMarker in pairs(ADGraphManager:getMapMarkers()) do
        if mapMarker.id == wayPointId then
            self:setFirstMarker(markerId)
            break
        end
    end
end

function ADStateModule:setFirstMarkerByName(markerName)
    for markerId, mapMarker in pairs(ADGraphManager:getMapMarkers()) do
        if mapMarker.name == markerName then
            self:setFirstMarker(markerId)
            break
        end
    end
end

function ADStateModule:getSecondMarker()
    return self.secondMarker
end

function ADStateModule:getSecondMarkerId()
    if self.secondMarker ~= nil then
        return self.secondMarker.markerIndex
    else
        return -1
    end
end

function ADStateModule:getSecondWayPoint()
    if self.secondMarker ~= nil then
        return self.secondMarker.id
    else
        return -1
    end
end

function ADStateModule:getSecondMarkerName()
    if self.secondMarker ~= nil then
        return self.secondMarker.name
    else
        return nil
    end
end

function ADStateModule:setSecondMarker(markerId)
    self.secondMarker = ADGraphManager:getMapMarkerById(markerId)
    self:raiseDirtyFlag()
end

function ADStateModule:setSecondMarkerByWayPointId(wayPointId)
    for markerId, mapMarker in pairs(ADGraphManager:getMapMarkers()) do
        if mapMarker.id == wayPointId then
            self:setSecondMarker(markerId)
            break
        end
    end
end

function ADStateModule:setSecondMarkerByName(markerName)
    for markerId, mapMarker in pairs(ADGraphManager:getMapMarkers()) do
        if mapMarker.name == markerName then
            self:setSecondMarker(markerId)
            break
        end
    end
end

function ADStateModule:getFillType()
    return self.fillType
end

function ADStateModule:setFillType(fillType)
    self.fillType = fillType
    self:raiseDirtyFlag()
end

function ADStateModule:nextFillType()
    self.fillType = self.fillType + 1
    if g_fillTypeManager:getFillTypeByIndex(self.fillType) == nil then
        self.fillType = 2
    end
    self:raiseDirtyFlag()
end

function ADStateModule:previousFillType()
    self.fillType = self.fillType - 1
    if self.fillType <= 1 then
        while g_fillTypeManager:getFillTypeByIndex(self.fillType) ~= nil do
            self.fillType = self.fillType + 1
        end
        self.fillType = self.fillType - 1
    end
    self:raiseDirtyFlag()
end

function ADStateModule:getSpeedLimit()
    return self.speedLimit
end

function ADStateModule:increaseSpeedLimit()
    if self.speedLimit < AutoDrive.getVehicleMaxSpeed(self.vehicle) then
        self.speedLimit = self.speedLimit + 1
    end
    self:raiseDirtyFlag()
end

function ADStateModule:decreaseSpeedLimit()
    if self.speedLimit > 2 then
        self.speedLimit = self.speedLimit - 1
    end
    self:raiseDirtyFlag()
end

function ADStateModule:getFieldSpeedLimit()
    return self.fieldSpeedLimit
end

function ADStateModule:increaseFieldSpeedLimit()
    if self.fieldSpeedLimit < AutoDrive.getVehicleMaxSpeed(self.vehicle) then
        self.fieldSpeedLimit = self.fieldSpeedLimit + 1
    end
    self:raiseDirtyFlag()
end

function ADStateModule:decreaseFieldSpeedLimit()
    if self.fieldSpeedLimit > 2 then
        self.fieldSpeedLimit = self.fieldSpeedLimit - 1
    end
    self:raiseDirtyFlag()
end

function ADStateModule:getParkDestination()
    return self.parkDestination
end

function ADStateModule:setParkDestination(parkDestination)
    self.parkDestination = parkDestination
    self:raiseDirtyFlag()
end

function ADStateModule:hasParkDestination(parkDestination)
    return self.parkDestination ~= nil and self.parkDestination >= 1 and ADGraphManager:getMapMarkerById(self.parkDestination) ~= nil
end

function ADStateModule:getSelectedNeighbourPoint()
    if not self.pointToNeighbour then
        return nil
    end
    return self.neighbourPoints[self.currentNeighbourToPointAt]
end

function ADStateModule:getPointToNeighbor()
    return self.pointToNeighbour
end

function ADStateModule:togglePointToNeighbor()
    self.pointToNeighbour = not self.pointToNeighbour
    if self.pointToNeighbour then
        self:updateNeighborPoint()
    end
end

function ADStateModule:changeNeighborPoint(increase)
    self.currentNeighbourToPointAt = self.currentNeighbourToPointAt + increase
    if self.currentNeighbourToPointAt < 1 then
        self.currentNeighbourToPointAt = #self.neighbourPoints
    end
    if self.neighbourPoints[self.currentNeighbourToPointAt] == nil then
        self.currentNeighbourToPointAt = 1
    end
end

function ADStateModule:updateNeighborPoint()
    -- Find all candidate points, no further away than 15 units from vehicle
    local candidateNeighborPoints =
        table.f_filter(
        self.vehicle:getWayPointsDistance(),
        function(elem)
            return elem.distance <= 15
        end
    )

    -- If more than one point found, then arrange them from inner closest to further out
    if #candidateNeighborPoints > 1 then
        -- Sort by distance
        table.sort(
            candidateNeighborPoints,
            function(left, right)
                return left.distance < right.distance
            end
        )
        -- Clear the array for any previous 'points'
        self.neighbourPoints = {}
        -- Only need 'point' in the neighbourPoints-array
        for _, elem in pairs(candidateNeighborPoints) do
            table.insert(self.neighbourPoints, elem.wayPoint)
        end
        -- Begin at the 2nd closest one (assuming 1st is 'ourself / the closest')
        self.currentNeighbourToPointAt = 2

        -- But try to find a node with no IncomingRoads, and use that as starting from
        for idx, point in pairs(self.neighbourPoints) do
            if #point.incoming < 1 then
                self.currentNeighbourToPointAt = idx
                break -- Since array was already sorted by distance, we dont need to search for another one
            end
        end
    end
end

function ADStateModule:raiseDirtyFlag()
    self.vehicle:raiseDirtyFlags(self.vehicle.ad.dirtyFlag)
end

function ADStateModule:setNextTargetInFolder()
    local group = self.secondMarker.group
    if group ~= "All" then
        local nextMarkerInGroup = nil
        local markerSeen = false
        local firstMarkerInGroup = nil
        for _, marker in ipairs(ADGraphManager:getMapMarkersInGroup(group)) do
            if marker.group == group then
                if firstMarkerInGroup == nil then
                    firstMarkerInGroup = marker.markerIndex
                end

                if markerSeen and nextMarkerInGroup == nil then
                    nextMarkerInGroup = marker.markerIndex
                end

                if marker.markerIndex == self.secondMarker.markerIndex then
                    markerSeen = true
                end
            end
        end

        local markerToSet = self.secondMarker
        if nextMarkerInGroup ~= nil then
            markerToSet = nextMarkerInGroup
        elseif firstMarkerInGroup ~= nil then
            markerToSet = firstMarkerInGroup
        end

        self:setSecondMarker(markerToSet)
        AutoDrive.Hud.lastUIScale = 0
    end
end

function ADStateModule:removeCPCallback()
    self.vehicle.ad.callBackFunction = nil
    self.vehicle.ad.callBackObject = nil
    self.vehicle.ad.callBackArg = nil
	if self:isActive() then			-- if AD active and CP callbacks are cleared CP to be stopped
		AutoDrive:StopCP(self.vehicle)
	end
end

function ADStateModule:resetMarkersOnReload()
    local newFirstMarker = nil
    if self.firstMarker ~= nil and self.firstMarker.id ~= nil then
        newFirstMarker = ADGraphManager:getMapMarkerByWayPointId(self.firstMarker.id)
    end
    if newFirstMarker ~= nil then
        self.firstMarker = newFirstMarker
    else
        self.firstMarker = ADGraphManager:getMapMarkerById(1)
    end

    local newSecondMarker = nil
    if self.secondMarker ~= nil and self.secondMarker.id ~= nil then
        newSecondMarker = ADGraphManager:getMapMarkerByWayPointId(self.secondMarker.id)
    end
    if newSecondMarker ~= nil then
        self.secondMarker = newSecondMarker
    else
        self.secondMarker = ADGraphManager:getMapMarkerById(1)
    end
    self:raiseDirtyFlag()
end
