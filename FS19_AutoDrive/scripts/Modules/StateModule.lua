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
    self.mode = AutoDrive.MODE_DRIVETO
    self.firstMarker = ADGraphManager:getMapMarkerById(1)
    self.secondMarker = ADGraphManager:getMapMarkerById(1)
    self.creationMode = ADStateModule.CREATE_OFF
    self.editorMode = ADStateModule.EDITOR_OFF

    self.fillType = 2
    self.loopCounter = 0

    self.speedLimit = AutoDrive.getVehicleMaxSpeed(self.vehicle)

    self.pointToNeighbour = false
    self.currentNeighbourToPointAt = -1
    self.neighbourPoints = {}

    self.parkDestination = -1

    self.driverName = g_i18n:getText("UNKNOWN")
    if self.getName ~= nil then
        self.driverName = self:getName()
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
end

function ADStateModule:saveToXMLFile(xmlFile, key)
    setXMLInt(xmlFile, key .. "#mode", self.mode)
    setXMLInt(xmlFile, key .. "#speedLimit", self.speedLimit)
    setXMLInt(xmlFile, key .. "#firstMarker", self.firstMarker.markerIndex)
    setXMLInt(xmlFile, key .. "#secondMarker", self.secondMarker.markerIndex)
    setXMLInt(xmlFile, key .. "#fillType", self.fillType)
    setXMLString(xmlFile, key .. "#driverName", self.driverName)
    setXMLInt(xmlFile, key .. "#loopCounter", self.loopCounter)
    setXMLInt(xmlFile, key .. "#parkDestination", self.parkDestination)
end

function ADStateModule:getMode()
    return self.mode
end

function ADStateModule:getCurrentMode()
    return self.vehicle.ad.modes[self.mode]
end

function ADStateModule:nextMode()
    if self.mode < AutoDrive.MODE_BGA then
        self.mode = self.mode + 1
    else
        self.mode = AutoDrive.MODE_DRIVETO
    end
end

function ADStateModule:previousMode()
    if self.mode > AutoDrive.MODE_DRIVETO then
        self.mode = self.mode - 1
    else
        self.mode = AutoDrive.MODE_BGA
    end
end

function ADStateModule:setMode(newMode)
    if newMode >= AutoDrive.MODE_DRIVETO and newMode <= AutoDrive.MODE_BGA then
        self.mode = newMode
    end
end

function ADStateModule:isActive()
    return self.active
end

function ADStateModule:setActive(active)
    self.active = active

    if self.active then
        self.creationMode = ADStateModule.CREATE_OFF
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
    return self.editorMode ~= ADStateModule.EDITOR_OFF
end

function ADStateModule:cycleEditMode()
    if self.editorMode == ADStateModule.EDITOR_OFF then
        self.editorMode = ADStateModule.EDITOR_ON
    elseif self.editorMode == ADStateModule.EDITOR_ON then
        self.editorMode = ADStateModule.EDITOR_EXTENDED
    elseif self.editorMode == ADStateModule.EDITOR_EXTENDED or self.editorMode == ADStateModule.EDITOR_SHOW then
        self.editorMode = ADStateModule.EDITOR_OFF
    end
end

function ADStateModule:cycleEditorShowMode()
    if self.editorMode == ADStateModule.EDITOR_OFF then
        self.editorMode = ADStateModule.EDITOR_SHOW
    else
        self.editorMode = ADStateModule.EDITOR_OFF
    end
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
end

function ADStateModule:startNormalCreationMode()
    self.creationMode = ADStateModule.CREATE_NORMAL
    self:setActive(false)
end

function ADStateModule:startDualCreationMode()
    self.creationMode = ADStateModule.CREATE_DUAL
    self:setActive(false)
end

function ADStateModule:getSelectedNeighbourPoint()
    if not self.pointToNeighbour then
        return nil
    end
    return self.neighbourPoints[self.currentNeighbourToPointAt]
end

function ADStateModule:getLoopCounter()
    return self.loopCounter
end

function ADStateModule:increaseLoopCounter()
    self.loopCounter = (self.loopCounter + 1) % 10
end

function ADStateModule:decreaseLoopCounter()
    if self.loopCounter > 0 then
        self.loopCounter = self.loopCounter - 1
    else
        self.loopCounter = 9
    end
end

function ADStateModule:setName(newName)
    self.driverName = newName
end

function ADStateModule:getFirstMarker()
    return self.firstMarker
end

function ADStateModule:getFirstMarkerId()
    return self.firstMarker.markerIndex
end

function ADStateModule:getFirstWayPoint()
    return self.firstMarker.id
end

function ADStateModule:getFirstMarkerName()
    return self.secondMarker.name
end

function ADStateModule:setFirstMarker(markerId)
    self.firstMarker = ADGraphManager:getMapMarkerById(markerId)
end

function ADStateModule:setFirstMarkerByWayPointId(wayPointId)
    for markerId, mapMarker in pairs(ADGraphManager:getMapMarker()) do
        if mapMarker.id == wayPointId then
            self:setFirstMarker(markerId)
            break
        end
    end
end

function ADStateModule:setFirstMarkerByName(markerName)
    for markerId, mapMarker in pairs(ADGraphManager:getMapMarker()) do
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
    return self.secondMarker.markerIndex
end

function ADStateModule:getSecondWayPoint()
    return self.secondMarker.id
end

function ADStateModule:getSecondMarkerName()
    return self.secondMarker.name
end

function ADStateModule:setSecondMarker(markerId)
    self.secondMarker = ADGraphManager:getMapMarkerById(markerId)
end

function ADStateModule:setSecondMarkerByWayPointId(wayPointId)
    for markerId, mapMarker in pairs(ADGraphManager:getMapMarker()) do
        if mapMarker.id == wayPointId then
            self:setSecondMarker(markerId)
            break
        end
    end
end

function ADStateModule:setSecondMarkerByName(markerName)
    for markerId, mapMarker in pairs(ADGraphManager:getMapMarker()) do
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
end

function ADStateModule:nextFillType()
    self.fillType = self.fillType + 1
    if g_fillTypeManager:getFillTypeByIndex(self.fillType) == nil then
        self.fillType = 2
    end
end

function ADStateModule:previousFillType()
    self.fillType = self.fillType - 1
    if self.fillType <= 1 then
        while g_fillTypeManager:getFillTypeByIndex(self.fillType) ~= nil do
            self.fillType = self.fillType + 1
        end
        self.fillType = self.fillType - 1
    end
end

function ADStateModule:getSpeedLimit()
    return self.speedLimit
end

function ADStateModule:increaseSpeedLimit()
    if self.speedLimit < AutoDrive.getVehicleMaxSpeed(self.vehicle) then
        self.speedLimit = self.speedLimit + 1
    end
end

function ADStateModule:decreaseSpeedLimit()
    if self.speedLimit > 2 then
        self.speedLimit = self.speedLimit - 1
    end
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
    local x1, _, z1 = getWorldTranslation(self.vehicle.components[1].node)
    local candidateNeighborPoints = {}
    for _, point in pairs(ADGraphManager:getWayPoints()) do
        local distance = AutoDrive.getDistance(point.x, point.z, x1, z1)
        if distance < 15 then
            -- Add new element consisting of 'distance' (for sorting) and 'point'
            table.insert(candidateNeighborPoints, {distance = distance, point = point})
        end
    end
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
            table.insert(self.neighbourPoints, elem.point)
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
