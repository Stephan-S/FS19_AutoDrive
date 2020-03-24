ADRecordingModule = {}

function ADRecordingModule:new(vehicle)
    local o = {}
    setmetatable(o, self)
    self.__index = self
    o.vehicle = vehicle
    o.isRecording = false
    o.isDual = false
    o.lastWp = nil
    o.secondLastWp = nil
    return o
end

function ADRecordingModule:toggle(dual)
    if self.isRecording then
        self:stop()
    else
        self:start(dual)
    end
end

function ADRecordingModule:start(dual)
    self.isDual = dual
    if self.isDual then
        self.vehicle.ad.stateModule:startDualCreationMode()
    else
        self.vehicle.ad.stateModule:startNormalCreationMode()
    end
    self.vehicle:stopAutoDrive()

    local x1, y1, z1 = getWorldTranslation(self.vehicle.components[1].node)
    self.lastWp = ADGraphManager:recordWayPoint(x1, y1, z1, false, false)

    if AutoDrive.getSetting("autoConnectStart") then
        local startNodeId, _ = self.vehicle:getClosestWayPoint()
        local startNode = ADGraphManager:getWayPointById(startNodeId)
        if startNode ~= nil then
            if ADGraphManager:getDistanceBetweenNodes(startNodeId, self.lastWp.id) < 12 then
                ADGraphManager:toggleConnectionBetween(startNode, self.lastWp)
                if self.isDual then
                    ADGraphManager:toggleConnectionBetween(self.lastWp, startNode)
                end
            end
        end
    end
    self.isRecording = true
end

function ADRecordingModule:stop()
    self.vehicle.ad.stateModule:disableCreationMode()

    if AutoDrive.getSetting("autoConnectEnd") then
        if self.lastWp ~= nil then
            local targetId = ADGraphManager:findMatchingWayPointForVehicle(self.vehicle)
            local targetNode = ADGraphManager:getWayPointById(targetId)
            if targetNode ~= nil then
                ADGraphManager:toggleConnectionBetween(self.lastWp, targetNode)
                if self.isDual then
                    ADGraphManager:toggleConnectionBetween(targetNode, self.lastWp)
                end
            end
        end
    end

    self.isRecording = false
    self.isDual = false
    self.lastWp = nil
    self.secondLastWp = nil
end

function ADRecordingModule:updateTick(dt, isActiveForInput, isActiveForInputIgnoreSelection, isSelected)
    if self.lastWp == nil or not self.isRecording or not self.vehicle.ad.stateModule:isInCreationMode() then
        return
    end

    local x, y, z = getWorldTranslation(self.vehicle.components[1].node)

    if self.secondLastWp == nil then
        if MathUtil.vector2Length(x - self.lastWp.x, z - self.lastWp.z) > 3 then
            self.secondLastWp = self.lastWp
            self.lastWp = ADGraphManager:recordWayPoint(x, y, z, true, self.isDual)
        end
    else
        local angle = math.abs(AutoDrive.angleBetween({x = x - self.secondLastWp.x, z = z - self.secondLastWp.z}, {x = self.lastWp.x - self.secondLastWp.x, z = self.lastWp.z - self.secondLastWp.z}))
        local max_distance = 6
        if angle < 0.5 then
            max_distance = 12
        elseif angle < 1 then
            max_distance = 6
        elseif angle < 2 then
            max_distance = 4
        elseif angle < 4 then
            max_distance = 3
        elseif angle < 7 then
            max_distance = 2
        elseif angle < 14 then
            max_distance = 1
        elseif angle < 27 then
            max_distance = 0.5
        else
            max_distance = 0.25
        end

        if MathUtil.vector2Length(x - self.lastWp.x, z - self.lastWp.z) > max_distance then
            self.secondLastWp = self.lastWp
            self.lastWp = ADGraphManager:recordWayPoint(x, y, z, true, self.isDual)
        end
    end
end

function ADRecordingModule:update(dt)
end
