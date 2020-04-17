ADSensor = {}
ADSensor_mt = {__index = ADSensor}

ADSensor.TYPE_COLLISION = 1
ADSensor.TYPE_FRUIT = 2
ADSensor.TYPE_TRIGGER = 3
ADSensor.TYPE_FIELDBORDER = 4

ADSensor.POS_FRONT = 1
ADSensor.POS_REAR = 2
ADSensor.POS_LEFT = 3
ADSensor.POS_RIGHT = 4
ADSensor.POS_FRONT_LEFT = 5
ADSensor.POS_FRONT_RIGHT = 6
ADSensor.POS_REAR_LEFT = 7
ADSensor.POS_REAR_RIGHT = 8
ADSensor.POS_FIXED = 9
ADSensor.POS_CENTER = 10

ADSensor.WIDTH_FACTOR = 0.7

ADSensor.EXECUTION_DELAY = 10

--
--          <x>
--       ^  o-o
--       z  |||
--       v  O-O
--

function ADSensor:handleSensors(vehicle, dt)
    if vehicle.ad.sensors == nil then
        ADSensor:addSensorsToVehicle(vehicle)
    end

    for _, sensor in pairs(vehicle.ad.sensors) do
        sensor:updateSensor(dt)
    end
end

function ADSensor:addSensorsToVehicle(vehicle)
    vehicle.ad.sensors = {}
    local sensorParameters = {}
    sensorParameters.dynamicLength = true
    sensorParameters.position = ADSensor.POS_FRONT
    sensorParameters.width = vehicle.sizeWidth * 0.75
    local frontSensorDynamic = ADCollSensor:new(vehicle, sensorParameters)
    --frontSensorDynamic.drawDebug = true --test
    --frontSensorDynamic.enabled = true --test
    vehicle.ad.sensors["frontSensorDynamic"] = frontSensorDynamic

    sensorParameters.dynamicLength = false
    sensorParameters.width = vehicle.sizeWidth * 0.65
    sensorParameters.length = 0.1
    local frontSensor = ADCollSensor:new(vehicle, sensorParameters)
    vehicle.ad.sensors["frontSensor"] = frontSensor

    sensorParameters.dynamicLength = false
    sensorParameters.width = vehicle.sizeWidth * 1.3
    sensorParameters.length = vehicle.sizeLength * 2
    local frontSensorLong = ADCollSensor:new(vehicle, sensorParameters)
    vehicle.ad.sensors["frontSensorLong"] = frontSensorLong

    sensorParameters.dynamicLength = false
    sensorParameters.width = vehicle.sizeWidth * 1.3
    sensorParameters.length = vehicle.sizeLength * 2
    local frontSensorLongFruit = ADFruitSensor:new(vehicle, sensorParameters)
    vehicle.ad.sensors["frontSensorLongFruit"] = frontSensorLongFruit

    sensorParameters.dynamicLength = false
    sensorParameters.length = vehicle.sizeLength
    sensorParameters.width = vehicle.sizeWidth * 2
    local frontSensorFruit = ADFruitSensor:new(vehicle, sensorParameters)
    vehicle.ad.sensors["frontSensorFruit"] = frontSensorFruit

    sensorParameters.dynamicLength = false
    sensorParameters.length = 2
    sensorParameters.width = vehicle.sizeWidth * 0.5
    local frontSensorField = ADFieldSensor:new(vehicle, sensorParameters)
    vehicle.ad.sensors["frontSensorField"] = frontSensorField

    sensorParameters = {}
    sensorParameters.dynamicLength = true
    sensorParameters.width = vehicle.sizeWidth * 0.75
    sensorParameters.position = ADSensor.POS_REAR
    local rearSensor = ADCollSensor:new(vehicle, sensorParameters)
    local rearSensorFruit = ADFruitSensor:new(vehicle, sensorParameters)
    vehicle.ad.sensors["rearSensor"] = rearSensor
    vehicle.ad.sensors["rearSensorFruit"] = rearSensorFruit

    sensorParameters = {}
    sensorParameters.position = ADSensor.POS_LEFT
    sensorParameters.dynamicLength = false
    sensorParameters.dynamicRotation = false
    sensorParameters.width = 6.5
    sensorParameters.length = vehicle.sizeLength * 0.8
    local leftSensor = ADCollSensor:new(vehicle, sensorParameters)
    local leftSensorFruit = ADFruitSensor:new(vehicle, sensorParameters)
    sensorParameters.width = 6.5
    local leftSensorField = ADFieldSensor:new(vehicle, sensorParameters)
    vehicle.ad.sensors["leftSensor"] = leftSensor
    vehicle.ad.sensors["leftSensorFruit"] = leftSensorFruit
    vehicle.ad.sensors["leftSensorField"] = leftSensorField

    sensorParameters.position = ADSensor.POS_RIGHT
    sensorParameters.dynamicLength = false
    sensorParameters.dynamicRotation = false
    sensorParameters.width = 6.5
    sensorParameters.length = vehicle.sizeLength * 0.8
    local rightSensor = ADCollSensor:new(vehicle, sensorParameters)
    local rightSensorFruit = ADFruitSensor:new(vehicle, sensorParameters)
    sensorParameters.width = 6.5
    local rightSensorField = ADFieldSensor:new(vehicle, sensorParameters)
    vehicle.ad.sensors["rightSensor"] = rightSensor
    vehicle.ad.sensors["rightSensorFruit"] = rightSensorFruit
    vehicle.ad.sensors["rightSensorField"] = rightSensorField

    sensorParameters.position = ADSensor.POS_FRONT_LEFT
    sensorParameters.dynamicLength = false
    sensorParameters.dynamicRotation = false
    sensorParameters.width = 4
    sensorParameters.length = vehicle.sizeLength * 1
    local leftFrontSensor = ADCollSensor:new(vehicle, sensorParameters)
    local leftFrontSensorFruit = ADFruitSensor:new(vehicle, sensorParameters)
    vehicle.ad.sensors["leftFrontSensor"] = leftFrontSensor
    vehicle.ad.sensors["leftFrontSensorFruit"] = leftFrontSensorFruit

    sensorParameters.position = ADSensor.POS_FRONT_RIGHT
    sensorParameters.dynamicLength = false
    sensorParameters.dynamicRotation = false
    sensorParameters.width = 4
    sensorParameters.length = vehicle.sizeLength * 1
    local rightFrontSensor = ADCollSensor:new(vehicle, sensorParameters)
    local rightFrontSensorFruit = ADFruitSensor:new(vehicle, sensorParameters)
    vehicle.ad.sensors["rightFrontSensor"] = rightFrontSensor
    vehicle.ad.sensors["rightFrontSensorFruit"] = rightFrontSensorFruit

    sensorParameters.position = ADSensor.POS_CENTER
    sensorParameters.dynamicLength = false
    sensorParameters.dynamicRotation = false
    sensorParameters.width = vehicle.sizeWidth * 0.95
    sensorParameters.length = vehicle.sizeLength * 1.4
    local centerSensorFruit = ADFruitSensor:new(vehicle, sensorParameters)
    vehicle.ad.sensors["centerSensorFruit"] = centerSensorFruit
end

function ADSensor:init(vehicle, sensorType, sensorParameters)
    --o = {}
    --setmetatable(o, self)
    --self.__index = self
    self.vehicle = vehicle
    self.sensorType = sensorType
    self.sensorParameters = sensorParameters
    self.enabled = false
    self.triggered = false
    self.initialized = false
    self.drawDebug = false
    self.executionDelay = 0

    self:loadBaseParameters()
    self:loadDynamicParameters(sensorParameters)
end

function ADSensor:loadBaseParameters()
    local vehicle = self.vehicle
    if vehicle ~= nil and vehicle.sizeLength ~= nil and vehicle.sizeWidth ~= nil then
        self.dynamicLength = true
        self.dynamicRotation = true
        self.length = vehicle.sizeLength
        self.width = vehicle.sizeWidth * ADSensor.WIDTH_FACTOR
        self.collisionMask = AIVehicleUtil.COLLISION_MASK
        self.position = ADSensor.POS_FRONT
        self.location = self:getLocationByPosition()
        self.initialized = true
        self.frontFactor = 1
        self.sideFactor = 1
    end
end

function ADSensor:loadDynamicParameters(sensorParameters)
    if sensorParameters == nil then
        return
    end

    if sensorParameters.dynamicLength ~= nil then
        self.dynamicLength = sensorParameters.dynamicLength == true
    end
    if sensorParameters.dynamicRotation ~= nil then
        self.dynamicRotation = sensorParameters.dynamicRotation == true
    end
    if sensorParameters.length ~= nil then
        self.length = sensorParameters.length
    end
    if sensorParameters.width ~= nil then
        self.width = sensorParameters.width
    end
    if sensorParameters.collisionMask ~= nil then
        self.collisionMask = sensorParameters.collisionMask
    end
    if sensorParameters.position ~= nil then
        if sensorParameters.position >= ADSensor.POS_FRONT and sensorParameters.position <= ADSensor.POS_CENTER then
            self.position = sensorParameters.position
        end
    end
    if sensorParameters.location ~= nil then
        if self.position == ADSensor.POS_FIXED then
            self.location = sensorParameters.location
        end
    end
    self.location = self:getLocationByPosition()
end

function ADSensor:getLocationByPosition()
    local vehicle = self.vehicle
    local location = {x = 0, z = 0}

    if self.position == ADSensor.POS_FRONT then
        --location.z = vehicle.sizeLength / 2 + lengthOffset
        --local lengthOffset = 1
        --if self.dynamicLength then
        --local frontToolLength = 0 --AutoDrive.getFrontToolLength(self.vehicle)
        --lengthOffset = frontToolLength / 2
        --end
        location = self:getRotatedFront()
        if location == nil then
            location = {x = 0, z = vehicle.sizeLength / 2}
        end
    elseif self.position == ADSensor.POS_REAR then
        location.z = - vehicle.sizeLength / 2
        self.frontFactor = -1
    elseif self.position == ADSensor.POS_RIGHT then
        location.x = -vehicle.sizeWidth / 2 - 1 - self.width / 2
        location.z = -vehicle.sizeLength / 2 - 2
        self.sideFactor = -1
    elseif self.position == ADSensor.POS_LEFT then
        location.x = vehicle.sizeWidth / 2 + 1 + self.width / 2
        location.z = -vehicle.sizeLength / 2 - 2
    elseif self.position == ADSensor.POS_FRONT_LEFT then
        location.x = vehicle.sizeWidth + 1.5 + self.width / 2
        location.z = vehicle.sizeLength * 0.3 - 2
    elseif self.position == ADSensor.POS_FRONT_RIGHT then
        location.x = -vehicle.sizeWidth - 1.5 - self.width / 2
        location.z = vehicle.sizeLength * 0.3 - 2
    elseif self.position == ADSensor.POS_FIXED and self.location ~= nil then
        return self.location
    elseif self.position == ADSensor.POS_CENTER then
        location.z = -self.length / 2
    end

    return location
end

function ADSensor:getBoxShape()
    local vehicle = self.vehicle
    self.location = self:getLocationByPosition()
    local lookAheadDistance = self.length
    if self.dynamicLength then
        lookAheadDistance = math.clamp(0.13, vehicle.lastSpeedReal * 3600 / 40, 1) * 11.5
        if self.position == ADSensor.POS_REAR then
            lookAheadDistance = math.clamp(0.02, vehicle.lastSpeedReal * 3600 / 40, 1) * 11.5
        end
    end

    local vecZ = {x = 0, z = 1}
    if self.dynamicRotation then
        vecZ.x, vecZ.z = math.sin(vehicle.rotatedTime), math.cos(vehicle.rotatedTime)
    end
    local vecX = {x = vecZ.z, z = -vecZ.x}

    if self.frontFactor == -1 then
        vecZ = {x = vecZ.x, z = -vecZ.z}
    end

    local boxYPos = 2
    if self.position == ADSensor.POS_FRONT_LEFT or self.position == ADSensor.POS_FRONT_RIGHT then
        boxYPos = 2.25
    end

    local box = {}
    box.offset = {}
    box.size = {}
    box.center = {}
    box.size[1] = self.width * 0.5
    box.size[2] = 0.75 -- fixed height for now
    box.size[3] = lookAheadDistance * 0.5
    box.offset[1] = self.location.x
    box.offset[2] = boxYPos -- fixed y pos for now
    box.offset[3] = self.location.z
    box.center[1] = box.offset[1] + vecZ.x * box.size[3] -- + vecX.x * box.size[1]
    box.center[2] = boxYPos -- fixed y pos for now
    box.center[3] = box.offset[3] + vecZ.z * box.size[3] -- + vecX.z * box.size[1]

    box.topLeft = {}
    box.topLeft[1] = box.center[1] - vecX.x * box.size[1] + vecZ.x * box.size[3]
    box.topLeft[2] = boxYPos
    box.topLeft[3] = box.center[3] - vecX.z * box.size[1] + vecZ.z * box.size[3]

    box.topRight = {}
    box.topRight[1] = box.center[1] + vecX.x * box.size[1] + vecZ.x * box.size[3]
    box.topRight[2] = boxYPos
    box.topRight[3] = box.center[3] + vecX.z * box.size[1] + vecZ.z * box.size[3]

    box.downRight = {}
    box.downRight[1] = box.center[1] + vecX.x * box.size[1] - vecZ.x * box.size[3]
    box.downRight[2] = boxYPos
    box.downRight[3] = box.center[3] + vecX.z * box.size[1] - vecZ.z * box.size[3]

    box.downLeft = {}
    box.downLeft[1] = box.center[1] - vecX.x * box.size[1] - vecZ.x * box.size[3]
    box.downLeft[2] = boxYPos
    box.downLeft[3] = box.center[3] - vecX.z * box.size[1] - vecZ.z * box.size[3]

    if self.sideFactor == -1 then
        vecX = {x = -vecX.x, z = -vecX.z}
    end

    box.dirX, box.dirY, box.dirZ = localDirectionToWorld(vehicle.components[1].node, 0, 0, 1)
    box.zx, box.zy, box.zz = localDirectionToWorld(vehicle.components[1].node, vecZ.x, 0, vecZ.z)
    box.ry = math.atan2(box.zx, box.zz)
    local angleOffset = 4
    local x, y, z = getWorldTranslation(self.vehicle.components[1].node)
    if not AutoDrive.checkIsOnField(x, y, z) and self.vehicle.ad.stateModule ~= nil and self.vehicle.ad.stateModule:isActive() then
        local heightDiff = self.vehicle.ad.drivePathModule:getApproachingHeightDiff()
        if heightDiff < 1.5 and heightDiff > -1 then
            angleOffset = 0
        end
    end
    box.rx = -MathUtil.getYRotationFromDirection(box.dirY, 1) * self.frontFactor - math.rad(angleOffset)
    box.x, box.y, box.z = localToWorld(vehicle.components[1].node, box.center[1], box.center[2], box.center[3])

    box.topLeft.x, box.topLeft.y, box.topLeft.z = localToWorld(vehicle.components[1].node, box.topLeft[1], box.topLeft[2], box.topLeft[3])
    box.topRight.x, box.topRight.y, box.topRight.z = localToWorld(vehicle.components[1].node, box.topRight[1], box.topRight[2], box.topRight[3])
    box.downRight.x, box.downRight.y, box.downRight.z = localToWorld(vehicle.components[1].node, box.downRight[1], box.downRight[2], box.downRight[3])
    box.downLeft.x, box.downLeft.y, box.downLeft.z = localToWorld(vehicle.components[1].node, box.downLeft[1], box.downLeft[2], box.downLeft[3])

    return box
end

function ADSensor:getCorners(box)
    --local box = box
    if box == nil then
        box = self:getBoxShape()
    end

    local corners = {}
    corners[1] = {x = box.downLeft.x, z = box.downLeft.z}
    corners[2] = {x = box.topLeft.x, z = box.topLeft.z}
    corners[3] = {x = box.downRight.x, z = box.downRight.z}
    corners[4] = {x = box.topRight.x, z = box.topRight.z}

    return corners
end

function ADSensor:updateSensor(dt)
    --g_logManager:devInfo("updateSensor called")
    if self:isEnabled() then
        self:onUpdate(dt)
    else
        self:setTriggered(false)
    end
end

function ADSensor:onUpdate()
    g_logManager:devWarning("[AutoDrive] ADSensor:onUpdate() called - Please override this in instance class")
end

function ADSensor:onDrawDebug(box)
    if self.drawDebug or AutoDrive.getDebugChannelIsSet(AutoDrive.DC_SENSORINFO) then
        local red = 0
        local blue = 0
        if self:isTriggered() then
            if self.sensorType == ADSensor.TYPE_FRUIT or self.sensorType == ADSensor.TYPE_FIELDBORDER then
                blue = 1
            else
                red = 1
            end
        end

        if self.sensorType == ADSensor.TYPE_FRUIT or self.sensorType == ADSensor.TYPE_FIELDBORDER then
            local corners = self:getCorners(box)
            corners[1].y = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, corners[1].x, 1, corners[1].z)
            corners[2].y = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, corners[2].x, 1, corners[2].z)
            corners[3].y = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, corners[3].x, 1, corners[3].z)
            corners[4].y = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, corners[4].x, 1, corners[4].z)

            local AutoDriveDM = ADDrawingManager

            AutoDriveDM:addLineTask(corners[1].x, corners[1].y, corners[1].z, corners[2].x, corners[2].y, corners[2].z, 1, blue, 0)
            AutoDriveDM:addLineTask(corners[2].x, corners[2].y, corners[2].z, corners[3].x, corners[3].y, corners[3].z, 1, blue, 0)
            AutoDriveDM:addLineTask(corners[3].x, corners[3].y, corners[3].z, corners[1].x, corners[1].y, corners[1].z, 1, blue, 0)

            AutoDriveDM:addLineTask(corners[2].x, corners[2].y, corners[2].z, corners[3].x, corners[3].y, corners[3].z, 1, blue, 1)
            AutoDriveDM:addLineTask(corners[3].x, corners[3].y, corners[3].z, corners[4].x, corners[4].y, corners[4].z, 1, blue, 1)
            AutoDriveDM:addLineTask(corners[4].x, corners[4].y, corners[4].z, corners[2].x, corners[2].y, corners[2].z, 1, blue, 1)
        else
            DebugUtil.drawOverlapBox(box.x, box.y, box.z, box.rx, box.ry, 0, box.size[1], box.size[2], box.size[3], red, blue, 0)
        end
    end
end

function ADSensor:pollInfo(forced, widthFactor)
    self.executionDelay = self.executionDelay -1
    if self.executionDelay <= 0 or forced or AutoDrive.getDebugChannelIsSet(AutoDrive.DC_SENSORINFO) then
        local storedWidth = self.width
        if widthFactor ~= nil then
            self.width = self.width * widthFactor
        end
        local wasEnabled = self.enabled
        self:setEnabled(true)
        if not wasEnabled then
            self:setEnabled(false)
        end
        self.lastTriggered = self:isTriggered()
        self.executionDelay = ADSensor.EXECUTION_DELAY
        self.width = storedWidth
    end

    return self.lastTriggered
end

function ADSensor:setEnabled(enabled)
    if enabled ~= nil and enabled == true then
        if self.enabled == false then
            self.enabled = true
            self:updateSensor(16)
        end
    else
        self.enabled = false
    end
end

function ADSensor:isEnabled()
    return self.enabled and self.initialized
end

function ADSensor:setTriggered(triggered)
    if triggered ~= nil and triggered == true then
        self.triggered = true
    else
        self.triggered = false
    end
end

function ADSensor:isTriggered()
    return self.triggered
end

function ADSensor:getRotatedFront()
    if self.frontAxle == nil then
        local frontWheel = nil
        local pairWheel = nil
        local frontDistance = math.huge
        local spec = self.vehicle.spec_wheels
        for _, wheel in pairs(spec.wheels) do
            local wheelNode = wheel.driveNode
            local sx, sy, sz = getWorldTranslation(wheelNode)
            local _, _, diffZ = worldToLocal(self.vehicle.components[1].node, sx, sy, sz)
            if diffZ > 0 and diffZ < frontDistance and math.abs(frontDistance - diffZ) > 0.5 then
                frontWheel = wheel
                frontDistance = diffZ
            end
            if diffZ > 0 and (math.abs(frontDistance - diffZ) < 0.2) and wheel ~= frontWheel then
                pairWheel = wheel
            end
        end

        if frontWheel ~= nil and pairWheel ~= nil then
            local frontWheelX, frontWheelY, frontWheelZ = getWorldTranslation(frontWheel.driveNode)
            local pairWheelX, pairWheelY, pairWheelZ = getWorldTranslation(pairWheel.driveNode)
            local axleCenterX = frontWheelX + 0.5 * (pairWheelX - frontWheelX)
            local axleCenterY = frontWheelY + 0.5 * (pairWheelY - frontWheelY)
            local axleCenterZ = frontWheelZ + 0.5 * (pairWheelZ - frontWheelZ)
            local _, _, diffZ = worldToLocal(self.vehicle.components[1].node, axleCenterX, axleCenterY, axleCenterZ)
            local wheelBaseToFront = self.vehicle.sizeLength / 2 - diffZ

            self.frontAxleLength = wheelBaseToFront
            self.frontAxle = {}
            self.frontAxle.x, self.frontAxle.y, self.frontAxle.z = worldToLocal(self.vehicle.components[1].node, axleCenterX, axleCenterY, axleCenterZ)
        end
    else
        local rx, _, rz = localDirectionToWorld(self.vehicle.components[1].node, math.sin(self.vehicle.rotatedTime), 0, math.cos(self.vehicle.rotatedTime))
        local frontPoint = {x = self.frontAxle.x + self.frontAxleLength * math.sin(self.vehicle.rotatedTime), y = self.frontAxle.y, z = self.frontAxle.z + self.frontAxleLength * math.cos(self.vehicle.rotatedTime)}

        return frontPoint
    end

    return nil
end
