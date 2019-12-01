AutoDrive.MODE_BGA = 6

AutoDriveBGA = {}
AutoDriveBGA.STATE_IDLE = 0
AutoDriveBGA.STATE_INIT = 1
AutoDriveBGA.STATE_INIT_AXIS = 2
AutoDriveBGA.STATE_ACTIVE = 3
AutoDriveBGA.STATE_WAITING_FOR_RESTART = 4

AutoDriveBGA.ACTION_DRIVETOSILO_COMMON_POINT = 0
AutoDriveBGA.ACTION_DRIVETOSILO_CLOSE_POINT = 1
AutoDriveBGA.ACTION_DRIVETOSILO_REVERSE_POINT = 2
AutoDriveBGA.ACTION_DRIVETOSILO_REVERSE_STRAIGHT = 3
AutoDriveBGA.ACTION_LOAD_ALIGN = 4
AutoDriveBGA.ACTION_LOAD = 5
AutoDriveBGA.ACTION_REVERSEFROMLOAD = 6
AutoDriveBGA.ACTION_DRIVETOUNLOAD_INIT = 7
AutoDriveBGA.ACTION_DRIVETOUNLOAD = 8
AutoDriveBGA.ACTION_UNLOAD = 9
AutoDriveBGA.ACTION_REVERSEFROMUNLOAD = 10

AutoDriveBGA.SHOVELSTATE_UNKNOWN = 0
AutoDriveBGA.SHOVELSTATE_LOW = 1
AutoDriveBGA.SHOVELSTATE_LOADING = 2
AutoDriveBGA.SHOVELSTATE_TRANSPORT = 3
AutoDriveBGA.SHOVELSTATE_BEFORE_UNLOAD = 4
AutoDriveBGA.SHOVELSTATE_UNLOAD = 5

AutoDriveBGA.DRIVESTRATEGY_REVERSE_LEFT = 0
AutoDriveBGA.DRIVESTRATEGY_REVERSE_RIGHT = 1
AutoDriveBGA.DRIVESTRATEGY_FORWARD_LEFT = 2
AutoDriveBGA.DRIVESTRATEGY_FORWARD_RIGHT = 3
AutoDriveBGA.DRIVESTRATEGY_FORWARDS = 4
AutoDriveBGA.DRIVESTRATEGY_REVERSE = 5

AutoDriveBGA.INITAXIS_STATE_INIT = 0
AutoDriveBGA.INITAXIS_STATE_ARM_INIT = 1
AutoDriveBGA.INITAXIS_STATE_ARM_STEER = 2
AutoDriveBGA.INITAXIS_STATE_ARM_CHECK = 3
AutoDriveBGA.INITAXIS_STATE_EXTENDER_INIT = 4
AutoDriveBGA.INITAXIS_STATE_EXTENDER_STEER = 5
AutoDriveBGA.INITAXIS_STATE_EXTENDER_CHECK = 6
AutoDriveBGA.INITAXIS_STATE_ROTATOR_INIT = 7
AutoDriveBGA.INITAXIS_STATE_ROTATOR_STEER = 8
AutoDriveBGA.INITAXIS_STATE_ROTATOR_CHECK = 9
AutoDriveBGA.INITAXIS_STATE_DONE = 10

AutoDriveBGA.SHOVEL_WIDTH_OFFSET = 0.8

function AutoDriveBGA:handleBGA(vehicle, dt)
    if vehicle.bga.state == AutoDriveBGA.STATE_IDLE then
        vehicle.bga.isActive = false
        vehicle.bga.shovel = nil
        return
    else
        vehicle.bga.isActive = true
    end

    AutoDriveBGA:getCurrentStates(vehicle)

    --if vehicle.bga.targetPoint ~= nil then
    --local x,y,z = getWorldTranslation( vehicle.components[1].node );
    --AutoDrive:drawLine({x=x,y=y+3,z=z}, {x=vehicle.bga.targetPoint.x, y=y+3,z=vehicle.bga.targetPoint.z}, 0, 0, 1, 1);
    --end;

    if vehicle.bga.state == AutoDriveBGA.STATE_INIT then
        self:initializeBGA(vehicle)
    elseif vehicle.bga.state == AutoDriveBGA.STATE_INIT_AXIS then
        if self:handleInitAxis(vehicle, dt) then
            vehicle.bga.state = AutoDriveBGA.STATE_ACTIVE
        end
    elseif vehicle.bga.state == AutoDriveBGA.STATE_ACTIVE then
        if vehicle.bga.action == AutoDriveBGA.ACTION_DRIVETOSILO_COMMON_POINT then
            self:driveToSiloCommonPoint(vehicle, dt)
        elseif vehicle.bga.action == AutoDriveBGA.ACTION_DRIVETOSILO_CLOSE_POINT then
            self:driveToSiloClosePoint(vehicle, dt)
        elseif vehicle.bga.action == AutoDriveBGA.ACTION_DRIVETOSILO_REVERSE_POINT then
            self:driveToSiloReversePoint(vehicle, dt)
        elseif vehicle.bga.action == AutoDriveBGA.ACTION_DRIVETOSILO_REVERSE_STRAIGHT then
            self:driveToSiloReverseStraight(vehicle, dt)
        elseif vehicle.bga.action == AutoDriveBGA.ACTION_LOAD_ALIGN then
            self:alignLoadFromBGA(vehicle, dt)
        elseif vehicle.bga.action == AutoDriveBGA.ACTION_LOAD then
            self:loadFromBGA(vehicle, dt)
        elseif vehicle.bga.action == AutoDriveBGA.ACTION_REVERSEFROMLOAD then
            self:reverseFromBGALoad(vehicle, dt)
        elseif vehicle.bga.action == AutoDriveBGA.ACTION_DRIVETOUNLOAD_INIT then
            self:driveToBGAUnloadInit(vehicle, dt)
        elseif vehicle.bga.action == AutoDriveBGA.ACTION_DRIVETOUNLOAD then
            self:driveToBGAUnload(vehicle, dt)
        elseif vehicle.bga.action == AutoDriveBGA.ACTION_UNLOAD then
            self:handleBGAUnload(vehicle, dt)
        elseif vehicle.bga.action == AutoDriveBGA.ACTION_REVERSEFROMUNLOAD then
            self:reverseFromBGAUnload(vehicle, dt)
        end
    elseif vehicle.bga.state == AutoDriveBGA.STATE_WAITING_FOR_RESTART then
        if self:checkIfPossibleToRestart(vehicle, dt) then
            vehicle.bga.state = AutoDriveBGA.STATE_ACTIVE
        else
            AutoDrive:getVehicleToStop(vehicle, false, dt)
        end
    end

    self:handleShovel(vehicle, dt)

    if (vehicle.bga.lastAction ~= nil) and (vehicle.bga.lastAction ~= vehicle.bga.action) then
        vehicle.bga.strategyActiveTimer.elapsedTime = math.huge
        vehicle.bga.storedDirection = nil
        vehicle.bga.lastAngleStrategyChange = nil
        vehicle.bga.checkedCurrentRow = false
    end

    vehicle.bga.lastState = vehicle.bga.state
    vehicle.bga.lastAction = vehicle.bga.action
end

function AutoDriveBGA:getCurrentStates(vehicle)
    vehicle.bga.shovelFillLevel = self:getShovelFillLevel(vehicle)
    vehicle.bga.trailerFillLevel, vehicle.bga.trailerLeftCapacity = AutoDrive.getFillLevelAndCapacityOf(vehicle.bga.targetTrailer)
    vehicle.bga.bunkerFillLevel = 10000 --self:getBunkerFillLevel();

    if not self:checkCurrentTrailerStillValid(vehicle) then
        vehicle.bga.targetTrailer = nil
        vehicle.bga.targetDriver = nil
    end
end

function AutoDriveBGA:checkIfPossibleToRestart(vehicle)
    if vehicle.bga.targetTrailer == nil then
        vehicle.bga.targetTrailer, vehicle.bga.targetDriver = self:findCloseTrailer(vehicle)
        vehicle.bga.trailerFillLevel, vehicle.bga.trailerLeftCapacity = AutoDrive.getFillLevelAndCapacityOf(vehicle.bga.targetTrailer)
    end
    if vehicle.bga.targetBunker == nil then
        vehicle.bga.targetBunker = self:getTargetBunker(vehicle)
    end

    if vehicle.bga.targetTrailer ~= nil and vehicle.bga.trailerLeftCapacity >= 1 and vehicle.bga.targetBunker ~= nil and vehicle.bga.bunkerFillLevel > 0 then
        return true
    end
end

function AutoDriveBGA:getShovelFillLevel(vehicle)
    if vehicle.bga ~= nil and vehicle.bga.shovel ~= nil then
        local fillLevel = 0
        local capacity = 0
        local fillUnitCount = 0
        for _, shovelNode in pairs(vehicle.bga.shovel.spec_shovel.shovelNodes) do
            fillLevel = fillLevel + vehicle.bga.shovel:getFillUnitFillLevel(shovelNode.fillUnitIndex)
            capacity = capacity + vehicle.bga.shovel:getFillUnitCapacity(shovelNode.fillUnitIndex)
            fillUnitCount = fillUnitCount + 1
            if vehicle.bga.shovelWidthTool == nil or vehicle.bga.shovelWidthTool < shovelNode.width then
                vehicle.bga.shovelWidthTool = shovelNode.width
            end
        end
        if vehicle.bga.shovelWidthTool ~= nil then
            vehicle.bga.shovelWidth = vehicle.bga.shovelWidthTool + AutoDrive.getSetting("shovelWidth", vehicle)
        else
            vehicle.bga.shovelWidth = 3.0 + AutoDrive.getSetting("shovelWidth", vehicle)
        end

        if vehicle.bga.targetBunker ~= nil then
            self:determineHighestShovelOffset(vehicle)
        end

        return fillLevel / capacity
    end

    return 0
end

function AutoDriveBGA:initializeBGA(vehicle)
    vehicle.bga.state = AutoDriveBGA.STATE_INIT_AXIS
    vehicle.bga.action = AutoDriveBGA.ACTION_DRIVETOSILO_COMMON_POINT
    vehicle.bga.shovelTarget = AutoDriveBGA.SHOVELSTATE_LOW
    vehicle.bga.targetTrailer, vehicle.bga.targetDriver = self:findCloseTrailer(vehicle)
    vehicle.bga.targetBunker = self:getTargetBunker(vehicle)

    vehicle.bga.inShovelRangeTimer = AutoDriveTON:new()
    vehicle.bga.strategyActiveTimer = AutoDriveTON:new()
    vehicle.bga.shovelActiveTimer = AutoDriveTON:new()
    vehicle.bga.wheelsOnGround = AutoDriveTON:new()
    vehicle.bga.wheelsOffGround = AutoDriveTON:new()
    vehicle.bga.strategyActiveTimer.elapsedTime = math.huge
    vehicle.bga.shovelOffsetCounter = 0
    vehicle.bga.reachedPreTargetLoadPoint = false

    if vehicle.bga.shovel == nil then
        self:getVehicleShovel(vehicle)
        if vehicle.bga.shovel == nil then
            AutoDrive.printMessage(vehicle, vehicle.ad.driverName .. " " .. g_i18n:getText("AD_No_Shovel"))
            vehicle.bga.state = AutoDriveBGA.STATE_IDLE
            AutoDrive:stopAD(vehicle, true)
            return
        end
    end

    if vehicle.bga.targetBunker == nil then
        AutoDrive.printMessage(vehicle, vehicle.ad.driverName .. " " .. g_i18n:getText("AD_No_Bunker"))
        vehicle.bga.state = AutoDriveBGA.STATE_IDLE
        AutoDrive:stopAD(vehicle, true)
    end

    if self:checkForUnloadCondition(vehicle) then
        vehicle.bga.action = AutoDriveBGA.ACTION_DRIVETOUNLOAD
    end
end

function AutoDriveBGA:handleInitAxis(vehicle, dt)
    self:handleShovel(vehicle, dt)
    if vehicle.bga.shovel ~= nil then
        local rotationObject
        local rotationTarget = 0
        local translationObject
        local translationTarget = 0
        if vehicle.bga.initAxisState == nil then
            vehicle.bga.initAxisState = AutoDriveBGA.INITAXIS_STATE_ARM_INIT
        elseif vehicle.bga.initAxisState == AutoDriveBGA.INITAXIS_STATE_ARM_INIT then
            if vehicle.bga.armMain ~= nil then
                rotationObject = vehicle.bga.armMain
                vehicle.bga.initAxisStartHeight = self:getShovelHeight(vehicle)
                vehicle.bga.initAxisStartRotation = rotationObject.curRot[1]
                rotationTarget = (rotationObject.rotMax - rotationObject.rotMin) / 2 + rotationObject.rotMin
                if math.abs(rotationTarget - rotationObject.curRot[1]) <= 0.1 then
                    rotationTarget = rotationObject.rotMin
                end
                vehicle.bga.armMain.rotationTarget = rotationTarget
                vehicle.bga.initAxisState = AutoDriveBGA.INITAXIS_STATE_ARM_STEER
            else
                vehicle.bga.initAxisState = AutoDriveBGA.INITAXIS_STATE_EXTENDER_INIT
            end
        elseif vehicle.bga.initAxisState == AutoDriveBGA.INITAXIS_STATE_ARM_STEER then
            rotationObject = vehicle.bga.armMain
            rotationTarget = vehicle.bga.armMain.rotationTarget
        elseif vehicle.bga.initAxisState == AutoDriveBGA.INITAXIS_STATE_ARM_CHECK then
            rotationObject = vehicle.bga.armMain
            rotationTarget = vehicle.bga.armMain.rotationTarget
            local newHeight = self:getShovelHeight(vehicle)
            if (newHeight > vehicle.bga.initAxisStartHeight) == (rotationTarget > vehicle.bga.initAxisStartRotation) then
                vehicle.bga.armMain.moveUpSign = 1
                vehicle.bga.armMain.moveDownSign = -1
            else
                vehicle.bga.armMain.moveUpSign = -1
                vehicle.bga.armMain.moveDownSign = 1
            end
            vehicle.bga.initAxisState = AutoDriveBGA.INITAXIS_STATE_EXTENDER_INIT
        elseif vehicle.bga.initAxisState == AutoDriveBGA.INITAXIS_STATE_EXTENDER_INIT then
            if vehicle.bga.armExtender ~= nil then
                translationObject = vehicle.bga.armExtender
                vehicle.bga.initAxisStartHeight = self:getShovelHeight(vehicle)
                vehicle.bga.initAxisStartTranslation = translationObject.curTrans[translationObject.translationAxis]
                translationTarget = (translationObject.transMax - translationObject.transMin) / 2 + translationObject.transMin
                if math.abs(translationTarget - translationObject.curTrans[translationObject.translationAxis]) <= 0.1 then
                    translationTarget = translationTarget.transMin
                end
                vehicle.bga.armExtender.translationTarget = translationTarget
                vehicle.bga.initAxisState = AutoDriveBGA.INITAXIS_STATE_EXTENDER_STEER
            else
                vehicle.bga.initAxisState = AutoDriveBGA.INITAXIS_STATE_ROTATOR_INIT
            end
        elseif vehicle.bga.initAxisState == AutoDriveBGA.INITAXIS_STATE_EXTENDER_STEER then
            translationObject = vehicle.bga.armExtender
            translationTarget = vehicle.bga.armExtender.translationTarget
        elseif vehicle.bga.initAxisState == AutoDriveBGA.INITAXIS_STATE_EXTENDER_CHECK then
            translationObject = vehicle.bga.armExtender
            translationTarget = vehicle.bga.armExtender.translationTarget
            local newHeight = self:getShovelHeight(vehicle)
            if (newHeight > vehicle.bga.initAxisStartHeight) == (translationTarget > vehicle.bga.initAxisStartTranslation) then
                vehicle.bga.armExtender.moveUpSign = 1
                vehicle.bga.armExtender.moveDownSign = -1
            else
                vehicle.bga.armExtender.moveUpSign = -1
                vehicle.bga.armExtender.moveDownSign = 1
            end
            vehicle.bga.initAxisState = AutoDriveBGA.INITAXIS_STATE_ROTATOR_INIT
        elseif vehicle.bga.initAxisState == AutoDriveBGA.INITAXIS_STATE_ROTATOR_INIT then
            if vehicle.bga.shovelRotator ~= nil then
                rotationObject = vehicle.bga.shovelRotator
                vehicle.bga.initAxisStartHeight = self:getShovelHeight(vehicle)
                vehicle.bga.initAxisStartRotation = rotationObject.curRot[1]
                local _, dy, _ = localDirectionToWorld(vehicle.bga.shovel.spec_shovel.shovelDischargeInfo.node, 0, 0, 1)
                local angle = math.acos(dy)
                vehicle.bga.initAxisStartShovelRotation = angle
                rotationTarget = (rotationObject.rotMax - rotationObject.rotMin) / 2 + rotationObject.rotMin

                if math.abs(rotationTarget - rotationObject.curRot[1]) <= 0.1 then
                    rotationTarget = rotationObject.rotMin
                end
                vehicle.bga.shovelRotator.rotationTarget = rotationTarget

                vehicle.bga.shovelRotator.horizontalPosition = math.pi / 2.0

                vehicle.bga.initAxisState = AutoDriveBGA.INITAXIS_STATE_ROTATOR_STEER
            else
                vehicle.bga.initAxisState = AutoDriveBGA.INITAXIS_STATE_DONE
            end
        elseif vehicle.bga.initAxisState == AutoDriveBGA.INITAXIS_STATE_ROTATOR_STEER then
            rotationObject = vehicle.bga.shovelRotator
            rotationTarget = vehicle.bga.shovelRotator.rotationTarget
        elseif vehicle.bga.initAxisState == AutoDriveBGA.INITAXIS_STATE_ROTATOR_CHECK then
            rotationObject = vehicle.bga.shovelRotator
            rotationTarget = vehicle.bga.shovelRotator.rotationTarget
            --local newHeight = self:getShovelHeight(vehicle)
            local _, dy, _ = localDirectionToWorld(vehicle.bga.shovel.spec_shovel.shovelDischargeInfo.node, 0, 0, 1)
            local newAngle = math.acos(dy)
            if (newAngle > vehicle.bga.initAxisStartShovelRotation) == (rotationTarget > vehicle.bga.initAxisStartRotation) then
                vehicle.bga.shovelRotator.moveUpSign = 1
                vehicle.bga.shovelRotator.moveDownSign = -1
            else
                vehicle.bga.shovelRotator.moveUpSign = -1
                vehicle.bga.shovelRotator.moveDownSign = 1
            end
            vehicle.bga.initAxisState = AutoDriveBGA.INITAXIS_STATE_DONE
        elseif vehicle.bga.initAxisState == AutoDriveBGA.INITAXIS_STATE_DONE then
            return true
        end

        if rotationObject ~= nil then
            if self:steerAxisTo(vehicle, rotationObject, rotationTarget, 100, dt) then
                if vehicle.bga.initAxisState == AutoDriveBGA.INITAXIS_STATE_ARM_STEER then
                    vehicle.bga.initAxisState = AutoDriveBGA.INITAXIS_STATE_ARM_CHECK
                elseif vehicle.bga.initAxisState == AutoDriveBGA.INITAXIS_STATE_EXTENDER_STEER then
                    vehicle.bga.initAxisState = AutoDriveBGA.INITAXIS_STATE_EXTENDER_CHECK
                elseif vehicle.bga.initAxisState == AutoDriveBGA.INITAXIS_STATE_ROTATOR_STEER then
                    vehicle.bga.initAxisState = AutoDriveBGA.INITAXIS_STATE_ROTATOR_CHECK
                end
            end
        end
        if translationObject ~= nil then
            if self:steerAxisToTrans(vehicle, translationObject, translationTarget, 100, dt) then
                if vehicle.bga.initAxisState == AutoDriveBGA.INITAXIS_STATE_ARM_STEER then
                    vehicle.bga.initAxisState = AutoDriveBGA.INITAXIS_STATE_ARM_CHECK
                elseif vehicle.bga.initAxisState == AutoDriveBGA.INITAXIS_STATE_EXTENDER_STEER then
                    vehicle.bga.initAxisState = AutoDriveBGA.INITAXIS_STATE_EXTENDER_CHECK
                elseif vehicle.bga.initAxisState == AutoDriveBGA.INITAXIS_STATE_ROTATOR_STEER then
                    vehicle.bga.initAxisState = AutoDriveBGA.INITAXIS_STATE_ROTATOR_CHECK
                end
            end
        end
    end
end

function AutoDriveBGA:getShovelHeight(vehicle)
    local x, y, z = getWorldTranslation(vehicle.bga.shovel.spec_shovel.shovelDischargeInfo.node)
    local height = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, x, 1, z)
    return y - height
end

function AutoDriveBGA:steerAxisTo(vehicle, rotationObject, rotationTarget, targetFactor, dt)
    local reachedTarget = false
    if rotationObject ~= nil then
        local curRot = rotationObject.curRot[1]
        if curRot ~= rotationTarget then
            if math.abs(rotationTarget - curRot) < (dt * rotationObject.rotSpeed * (targetFactor * 0.01)) then
                curRot = rotationTarget
                reachedTarget = true
            else
                if curRot > rotationTarget then
                    curRot = curRot - (dt * rotationObject.rotSpeed * (targetFactor * 0.01))
                else
                    curRot = curRot + (dt * rotationObject.rotSpeed * (targetFactor * 0.01))
                end
            end
            curRot = math.min(math.max(curRot, rotationObject.rotMin), rotationObject.rotMax)
            rotationObject.curRot[1] = curRot
            setRotation(rotationObject.node, unpack(rotationObject.curRot))
            SpecializationUtil.raiseEvent(vehicle, "onMovingToolChanged", rotationObject, rotationObject.rotSpeed, dt)

            Cylindered.setDirty(vehicle, rotationObject)
            vehicle:raiseDirtyFlags(vehicle.spec_cylindered.cylinderedDirtyFlag)
        end
    end
    return reachedTarget
end

function AutoDriveBGA:steerAxisToTrans(vehicle, translationObject, translationTarget, targetFactor, dt)
    local reachedTarget = false
    if translationObject ~= nil then
        local curTrans = translationObject.curTrans[translationObject.translationAxis]
        if curTrans ~= translationTarget then
            if math.abs(translationTarget - curTrans) < (dt * translationObject.transSpeed * (targetFactor * 0.01)) then
                curTrans = translationTarget
                reachedTarget = true
            else
                if curTrans > translationTarget then
                    curTrans = curTrans - (dt * translationObject.transSpeed * (targetFactor * 0.01))
                else
                    curTrans = curTrans + (dt * translationObject.transSpeed * (targetFactor * 0.01))
                end
            end
            curTrans = math.min(math.max(curTrans, translationObject.transMin), translationObject.transMax)
            translationObject.curTrans[translationObject.translationAxis] = curTrans
            setTranslation(translationObject.node, unpack(translationObject.curTrans))
            SpecializationUtil.raiseEvent(vehicle, "onMovingToolChanged", translationObject, translationObject.transSpeed, dt)

            Cylindered.setDirty(vehicle, translationObject)
            vehicle:raiseDirtyFlags(vehicle.spec_cylindered.cylinderedDirtyFlag)
        end
    end
    return reachedTarget
end

function AutoDriveBGA:checkForUnloadCondition(vehicle) --can unload if shovel is filled and trailer available
    if vehicle.bga.action == AutoDriveBGA.ACTION_DRIVETOSILO_COMMON_POINT then
        return vehicle.bga.shovelFillLevel > 0 and vehicle.bga.targetTrailer ~= nil and vehicle.bga.trailerLeftCapacity > 1
    elseif vehicle.bga.action == AutoDriveBGA.ACTION_LOAD then
        return vehicle.bga.shovelFillLevel >= 0.98 and vehicle.bga.targetTrailer ~= nil and vehicle.bga.trailerLeftCapacity > 1
    end
    return false
end

function AutoDriveBGA:checkForStopLoading(vehicle) --stop loading when shovel is filled
    return vehicle.bga.shovelFillLevel >= 0.98
end

function AutoDriveBGA:checkForIdleCondition(vehicle) --idle if shovel filled and no trailer available to fill;
    if vehicle.bga.shovelFillLevel >= 0.98 and (vehicle.bga.targetTrailer ~= nil or vehicle.bga.trailerLeftCapacity <= 1) or vehicle.bga.targetTrailer == nil then
        return true
    end
    return false
end

function AutoDriveBGA:handleShovel(vehicle, dt)
    if vehicle.bga.shovelState == nil then
        vehicle.bga.shovelState = AutoDriveBGA.SHOVELSTATE_UNKNOWN
    end

    vehicle.bga.shovelActiveTimer:timer(((vehicle.bga.shovelState ~= vehicle.bga.shovelTarget) and (vehicle.bga.state > AutoDriveBGA.STATE_INIT_AXIS)), 7000, dt)

    if vehicle.bga.state > AutoDriveBGA.STATE_INIT_AXIS then
        if vehicle.bga.shovelState == AutoDriveBGA.SHOVELSTATE_UNKNOWN then
            if not vehicle.bga.shovelActiveTimer:done() then
                self:moveShovelToTarget(vehicle, AutoDriveBGA.SHOVELSTATE_LOW, dt)
            else
                --After timeout, assume we reached desired position as good as possible
                vehicle.bga.shovelState = vehicle.bga.shovelTarget
            end
        else
            if vehicle.bga.shovelState ~= vehicle.bga.shovelTarget then
                if not vehicle.bga.shovelActiveTimer:done() then
                    self:moveShovelToTarget(vehicle, vehicle.bga.shovelTarget, dt)
                else
                    --After timeout, assume we reached desired position as good as possible
                    vehicle.bga.shovelState = vehicle.bga.shovelTarget
                end
            else
                --make sure shovel hasnt't lifted wheels
                local allWheelsOnGround = self:checkIfAllWheelsOnGround(vehicle)
                --local onGroundForLongTime = vehicle.bga.wheelsOnGround:timer(allWheelsOnGround, 300, dt)
                local liftedForLongTime = vehicle.bga.wheelsOffGround:timer(not allWheelsOnGround, 300, dt)
                if liftedForLongTime and vehicle.bga.armMain ~= nil then --or (not onGroundForLongTime)
                    self:steerAxisTo(vehicle, vehicle.bga.armMain, vehicle.bga.armMain.moveUpSign * math.pi, 33, dt)
                end
            end
        end
    end
end

function AutoDriveBGA:moveShovelToTarget(vehicle, _, dt)
    if vehicle.bga.shovelTarget == AutoDriveBGA.SHOVELSTATE_LOADING then
        vehicle.bga.shovelTargetHeight = -0.20 + AutoDrive.getSetting("shovelHeight", vehicle)
        vehicle.bga.shovelTargetAngle = vehicle.bga.shovelRotator.horizontalPosition + vehicle.bga.shovelRotator.moveUpSign * 0.07
        if vehicle.bga.armExtender ~= nil then
            vehicle.bga.shovelTargetExtension = vehicle.bga.armExtender.transMin
        end
    elseif vehicle.bga.shovelTarget == AutoDriveBGA.SHOVELSTATE_LOW then
        vehicle.bga.shovelTargetHeight = 1.1
        vehicle.bga.shovelTargetAngle = vehicle.bga.shovelRotator.horizontalPosition - vehicle.bga.shovelRotator.moveUpSign * 0.3
        if vehicle.bga.armExtender ~= nil then
            vehicle.bga.shovelTargetExtension = vehicle.bga.armExtender.transMin
        end
    elseif vehicle.bga.shovelTarget == AutoDriveBGA.SHOVELSTATE_TRANSPORT then
        vehicle.bga.shovelTargetHeight = 2.1
        vehicle.bga.shovelTargetAngle = vehicle.bga.shovelRotator.horizontalPosition - vehicle.bga.shovelRotator.moveUpSign * 0.3
        if vehicle.bga.armExtender ~= nil then
            vehicle.bga.shovelTargetExtension = vehicle.bga.armExtender.transMin
        end
    elseif vehicle.bga.shovelTarget == AutoDriveBGA.SHOVELSTATE_BEFORE_UNLOAD then
        vehicle.bga.shovelTargetHeight = 4.7
        vehicle.bga.shovelTargetAngle = vehicle.bga.shovelRotator.horizontalPosition - vehicle.bga.shovelRotator.moveUpSign * 0.1
        if vehicle.bga.armExtender ~= nil then
            vehicle.bga.shovelTargetExtension = vehicle.bga.armExtender.transMax
        end
    elseif vehicle.bga.shovelTarget == AutoDriveBGA.SHOVELSTATE_UNLOAD then
        vehicle.bga.shovelTargetHeight = 4.7
        vehicle.bga.shovelTargetAngle = vehicle.bga.shovelRotator.horizontalPosition + vehicle.bga.shovelRotator.moveUpSign * 0.5
        if vehicle.bga.armExtender ~= nil then
            vehicle.bga.shovelTargetExtension = vehicle.bga.armExtender.transMax
        end
    end

    local targetFactorHeight = math.max(5, math.min((math.abs(self:getShovelHeight(vehicle) - vehicle.bga.shovelTargetHeight) * 200), 100))
    local targetFactorExtender = 0
    --local extenderTargetReached = true
    if vehicle.bga.armExtender ~= nil then
        --if math.abs(vehicle.bga.shovelTargetExtension - vehicle.bga.armExtender.curTrans[vehicle.bga.armExtender.translationAxis]) >= 0.01 then
        --extenderTargetReached = false
        --end
        targetFactorExtender = math.max(5, math.min((math.abs(vehicle.bga.shovelTargetExtension - vehicle.bga.armExtender.curTrans[vehicle.bga.armExtender.translationAxis]) * 100), 70))
    end

    local _, dy, _ = localDirectionToWorld(vehicle.bga.shovel.spec_shovel.shovelDischargeInfo.node, 0, 0, 1)
    local angle = math.acos(dy)
    local shovelTargetAngleReached = false
    if math.abs(angle - vehicle.bga.shovelTargetAngle) <= 0.05 then
        shovelTargetAngleReached = true
    end
    if vehicle.bga.shovelTarget == AutoDriveBGA.SHOVELSTATE_UNLOAD then
        if (math.abs(vehicle.bga.shovelRotator.curRot[1] - vehicle.bga.shovelRotator.rotMax) <= 0.01 or math.abs(vehicle.bga.shovelRotator.curRot[1] - vehicle.bga.shovelRotator.rotMin) <= 0.01) then
            shovelTargetAngleReached = true
        end
    end
    local targetFactorHorizontal = math.max(1, math.min(self:getAngleBetweenTwoRadValues(angle, vehicle.bga.shovelTargetAngle) * 100, 100))

    --keep shovel in targetPosition
    if not shovelTargetAngleReached then
        local targetRotation = vehicle.bga.shovelRotator.moveUpSign * math.pi
        if (angle - vehicle.bga.shovelTargetAngle) >= 0 then
            targetRotation = vehicle.bga.shovelRotator.moveDownSign * math.pi
        end
        self:steerAxisTo(vehicle, vehicle.bga.shovelRotator, targetRotation, targetFactorHorizontal, dt)
    end

    if shovelTargetAngleReached and (vehicle.bga.action ~= AutoDriveBGA.ACTION_UNLOAD) then
        if self:getShovelHeight(vehicle) >= vehicle.bga.shovelTargetHeight then
            self:steerAxisTo(vehicle, vehicle.bga.armMain, vehicle.bga.armMain.moveDownSign * math.pi, targetFactorHeight, dt)
            if vehicle.bga.armExtender ~= nil then
                self:steerAxisToTrans(vehicle, vehicle.bga.armExtender, vehicle.bga.armExtender.moveDownSign * math.pi, targetFactorExtender, dt)
            end
        else
            self:steerAxisTo(vehicle, vehicle.bga.armMain, vehicle.bga.armMain.moveUpSign * math.pi, targetFactorHeight, dt)
            if vehicle.bga.armExtender ~= nil then
                self:steerAxisToTrans(vehicle, vehicle.bga.armExtender, vehicle.bga.armExtender.moveUpSign * math.pi, targetFactorExtender, dt)
            end
        end
    end

    local allAxisFullyExtended = false
    if
        (vehicle.bga.armMain ~= nil and (math.abs(vehicle.bga.armMain.curRot[1] - vehicle.bga.armMain.rotMax) <= 0.01 or math.abs(vehicle.bga.armMain.curRot[1] - vehicle.bga.armMain.rotMin) <= 0.01)) and
            (vehicle.bga.armExtender == nil or math.abs(vehicle.bga.armExtender.curTrans[vehicle.bga.armExtender.translationAxis] - vehicle.bga.armExtender.transMax) <= 0.01)
     then
        allAxisFullyExtended = true
    end

    if ((math.abs(self:getShovelHeight(vehicle) - vehicle.bga.shovelTargetHeight) <= 0.01) or (allAxisFullyExtended and (vehicle.bga.shovelTargetHeight > 4 or vehicle.bga.shovelTargetHeight < 0.5)) or (vehicle.bga.action == AutoDriveBGA.ACTION_UNLOAD)) and shovelTargetAngleReached then
        vehicle.bga.shovelState = vehicle.bga.shovelTarget
    end
end

function AutoDriveBGA:checkIfAllWheelsOnGround(vehicle)
    local spec = vehicle.spec_wheels
    for _, wheel in pairs(spec.wheels) do
        if wheel.contact ~= Wheels.WHEEL_GROUND_CONTACT then
            return false
        end
    end
    return true
end

function AutoDriveBGA:getAngleBetweenTwoRadValues(valueOne, valueTwo)
    local abs = math.abs(valueOne - valueTwo)
    if abs > math.pi then
        abs = math.abs(abs - (2 * math.pi))
    end
    return abs
end

function AutoDriveBGA:getVehicleShovel(vehicle)
    for _, implement in pairs(vehicle:getAttachedImplements()) do
        if implement.object.spec_shovel ~= nil then
            vehicle.bga.shovelAxisOne = vehicle.spec_cylindered.movingTools
            vehicle.bga.shovelAxisTwo = implement.object.spec_cylindered.movingTools
            vehicle.bga.shovel = implement.object
        else
            if implement.object.getAttachedImplements ~= nil then
                for _, implementInner in pairs(implement.object:getAttachedImplements()) do
                    if implementInner.object.spec_shovel ~= nil then
                        vehicle.bga.shovelAxisOne = vehicle.spec_cylindered.movingTools
                        vehicle.bga.shovelAxisTwo = implement.object.spec_cylindered.movingTools
                        vehicle.bga.shovel = implementInner.object
                    end
                end
            end
        end
    end

    if vehicle.bga.shovel ~= nil then
        --split into axis
        for _, axis in pairs(vehicle.bga.shovelAxisOne) do
            if axis.axis == "AXIS_FRONTLOADER_ARM" then
                vehicle.bga.armMain = axis
            elseif axis.axis == "AXIS_FRONTLOADER_ARM2" then
                vehicle.bga.armExtender = axis
            elseif axis.axis == "AXIS_FRONTLOADER_TOOL" then
                vehicle.bga.shovelRotator = axis
            end
        end
        for _, axis in pairs(vehicle.bga.shovelAxisTwo) do
            if axis.axis == "AXIS_FRONTLOADER_ARM" then
                vehicle.bga.armMain = axis
            elseif axis.axis == "AXIS_FRONTLOADER_ARM2" then
                vehicle.bga.armExtender = axis
            elseif axis.axis == "AXIS_FRONTLOADER_TOOL" then
                vehicle.bga.shovelRotator = axis
            end
        end
    end
end

function AutoDriveBGA:findCloseTrailer(bgaVehicle)
    local closestDistance = 50
    local closest = nil
    local closestTrailer = nil
    for _, vehicle in pairs(g_currentMission.vehicles) do
        if vehicle ~= bgaVehicle and self:vehicleHasTrailersAttached(vehicle) and vehicle.ad ~= nil then
            if self:getDistanceBetween(vehicle, bgaVehicle) < closestDistance and vehicle.ad.noMovementTimer:done() and (not vehicle.ad.isUnloading) then
                local _, trailers = self:vehicleHasTrailersAttached(vehicle)
                for _, trailer in pairs(trailers) do
                    if trailer ~= nil then
                        --local trailerFillLevel = 0
                        local trailerLeftCapacity = 0
                        _, trailerLeftCapacity = AutoDrive.getFillLevelAndCapacityOf(trailer)
                        if trailerLeftCapacity >= 10 then
                            closestDistance = self:getDistanceBetween(trailer, bgaVehicle)
                            closest = vehicle
                            closestTrailer = trailer
                        end
                    end
                end
            end
        end
    end
    if closest ~= nil then
        --local trailerFillLevel = 0
        --local trailerLeftCapacity = 0
        --trailerFillLevel, trailerLeftCapacity = AutoDrive.getFillLevelAndCapacityOf(closestTrailer)
        return closestTrailer, closest
    end
    return
end

function AutoDriveBGA:getDistanceBetween(vehicleOne, vehicleTwo)
    local x1, _, z1 = getWorldTranslation(vehicleOne.components[1].node)
    local x2, _, z2 = getWorldTranslation(vehicleTwo.components[1].node)

    return math.sqrt(math.pow(x2 - x1, 2) + math.pow(z2 - z1, 2))
end

function AutoDriveBGA:vehicleHasTrailersAttached(vehicle)
    local trailers, _ = AutoDrive.getTrailersOf(vehicle)
    local tipTrailers = {}
    if trailers ~= nil then
        for _, trailer in pairs(trailers) do
            local trailerFillLevel = 0
            local trailerLeftCapacity = 0
            trailerFillLevel, trailerLeftCapacity = AutoDrive.getFillLevelAndCapacityOf(trailer)
            local maxCapacity = trailerFillLevel + trailerLeftCapacity
            if trailer.typeName == "trailer" or (maxCapacity >= 7000) then
                table.insert(tipTrailers, trailer)
            end
        end
    end

    return (#tipTrailers > 0), tipTrailers
end

function AutoDriveBGA:checkCurrentTrailerStillValid(vehicle)
    if vehicle.bga.targetTrailer ~= nil and vehicle.bga.targetDriver ~= nil then
        local tooFast = math.abs(vehicle.bga.targetDriver.lastSpeedReal) > 0.002
        --local trailerFillLevel = 0
        local trailerLeftCapacity = 0
        _, trailerLeftCapacity = AutoDrive.getFillLevelAndCapacityOf(vehicle.bga.targetTrailer)
        local tooFull = trailerLeftCapacity < 1

        return not (tooFull or tooFast)
    end

    return false
end

function AutoDriveBGA:getTargetBunker(vehicle)
    local x, _, z = getWorldTranslation(vehicle.components[1].node)
    local closestDistance = math.huge
    local closest = nil
    for _, trigger in pairs(AutoDrive.Triggers.tipTriggers) do
        if trigger.bunkerSiloArea ~= nil then
            local centerX, centerZ = self:getBunkerCenter(trigger)
            local distance = math.sqrt(math.pow(centerX - x, 2) + math.pow(centerZ - z, 2))
            if distance < closestDistance and distance < 100 then
                closest = trigger
                closestDistance = distance
            end
        end
    end

    return closest
end

function AutoDriveBGA:getTargetBunkerLoadingSide(vehicle)
    if vehicle.bga.targetBunker == nil then
        self:getTargetBunker(vehicle)
        if vehicle.bga.targetBunker == nil then
            return
        end
    end

    if vehicle.bga.loadingSideP1 ~= nil then
        return vehicle.bga.loadingSideP1, vehicle.bga.loadingSideP2
    end

    local trigger = vehicle.bga.targetBunker
    --        vecW
    local x1, z1 = trigger.bunkerSiloArea.sx, trigger.bunkerSiloArea.sz --      1 ---- 2
    local x2, z2 = trigger.bunkerSiloArea.wx, trigger.bunkerSiloArea.wz -- vecH | ---- |
    local x3, z3 = trigger.bunkerSiloArea.hx, trigger.bunkerSiloArea.hz --      | ---- |
    local x4, z4 = x2 + (x3 - x1), z2 + (z3 - z1) --      3 ---- 4    4 = 2 + vecH

    local x, _, z = getWorldTranslation(vehicle.components[1].node)

    vehicle.bga.vecW = {x = (x2 - x1), z = (z2 - z1)}
    vehicle.bga.vecH = {x = (x3 - x1), z = (z3 - z1)}
    vehicle.bga.vecWLength = MathUtil.vector2Length(vehicle.bga.vecW.x, vehicle.bga.vecW.z)
    vehicle.bga.vecHLength = MathUtil.vector2Length(vehicle.bga.vecH.x, vehicle.bga.vecH.z)

    if vehicle.bga.vecWLength < vehicle.bga.vecHLength then
        if MathUtil.vector2Length(x - x1, z - z1) <= MathUtil.vector2Length(x - x3, z - z3) then
            vehicle.bga.loadingSideP1 = {x = x1, z = z1}
            vehicle.bga.loadingSideP2 = {x = x2, z = z2}
        else
            vehicle.bga.vecH.x = -vehicle.bga.vecH.x
            vehicle.bga.vecH.z = -vehicle.bga.vecH.z
            vehicle.bga.loadingSideP1 = {x = x3, z = z3}
            vehicle.bga.loadingSideP2 = {x = x4, z = z4}
        end
    else
        if MathUtil.vector2Length(x - x1, z - z1) <= MathUtil.vector2Length(x - x2, z - z2) then
            vehicle.bga.loadingSideP1 = {x = x1, z = z1}
            vehicle.bga.loadingSideP2 = {x = x3, z = z3}
        else
            vehicle.bga.vecW.x = -vehicle.bga.vecW.x
            vehicle.bga.vecW.z = -vehicle.bga.vecW.z
            vehicle.bga.loadingSideP1 = {x = x2, z = z2}
            vehicle.bga.loadingSideP2 = {x = x4, z = z4}
        end
    end

    return vehicle.bga.loadingSideP1, vehicle.bga.loadingSideP2
end

function AutoDriveBGA:getBunkerCenter(trigger)
    local x1, z1 = trigger.bunkerSiloArea.sx, trigger.bunkerSiloArea.sz
    local x2, z2 = trigger.bunkerSiloArea.wx, trigger.bunkerSiloArea.wz
    local x3, z3 = trigger.bunkerSiloArea.hx, trigger.bunkerSiloArea.hz

    return x1 + 0.5 * ((x2 - x1) + (x3 - x1)), z1 + 0.5 * ((z2 - z1) + (z3 - z1))
end

function AutoDriveBGA:isAlmostInBunkerSiloArea(vehicle, distanceToCheck)
    --local x, y, z = getWorldTranslation(vehicle.components[1].node)
    --local tx, ty, tz = x, y, z + distanceToCheck
    local trigger = vehicle.bga.targetBunker
    local x1, z1 = trigger.bunkerSiloArea.sx, trigger.bunkerSiloArea.sz
    local x2, z2 = trigger.bunkerSiloArea.wx, trigger.bunkerSiloArea.wz
    local x3, z3 = trigger.bunkerSiloArea.hx, trigger.bunkerSiloArea.hz

    local otherBoundingBox = {{x = x1, z = z1}, {x = x2, z = z2}, {x = x3, z = z3}, {x = x2 + (x3 - x1), z = z2 + (z3 - z1)}}

    local x, y, z = getWorldTranslation(vehicle.components[1].node)
    --create bounding box to check for vehicle
    local rx, _, rz = localDirectionToWorld(vehicle.components[1].node, math.sin(vehicle.rotatedTime), 0, math.cos(vehicle.rotatedTime))
    local vehicleVector = {x = rx, z = rz}
    local width = vehicle.sizeWidth
    local length = vehicle.sizeLength
    local ortho = {x = -vehicleVector.z, z = vehicleVector.x}
    local boundingBox = {}
    boundingBox[1] = {
        x = x + (width / 2) * ortho.x,
        y = y + 2,
        z = z + (width / 2) * ortho.z
    }
    boundingBox[2] = {
        x = x - (width / 2) * ortho.x,
        y = y + 2,
        z = z - (width / 2) * ortho.z
    }
    boundingBox[3] = {
        x = x - (width / 2) * ortho.x + (length / 2 + distanceToCheck) * vehicleVector.x,
        y = y + 2,
        z = z - (width / 2) * ortho.z + (length / 2 + distanceToCheck) * vehicleVector.z
    }
    boundingBox[4] = {
        x = x + (width / 2) * ortho.x + (length / 2 + distanceToCheck) * vehicleVector.x,
        y = y + 2,
        z = z + (width / 2) * ortho.z + (length / 2 + distanceToCheck) * vehicleVector.z
    }

    return AutoDrive.boxesIntersect(boundingBox, otherBoundingBox)
end

function AutoDriveBGA:driveToSiloCommonPoint(vehicle, dt)
    if (vehicle.bga.checkedCurrentRow == nil or vehicle.bga.checkedCurrentRow == false) then
        self:setShovelOffsetToNonEmptyRow(vehicle)
        vehicle.bga.checkedCurrentRow = true
    end

    vehicle.bga.targetPoint = self:getTargetForShovelOffset(vehicle, 14)
    local angleToSilo = self:getAngleToTarget(vehicle) -- in +/- 180°

    if vehicle.bga.storedDirection == nil then
        vehicle.bga.storedDirection = true
        if math.abs(angleToSilo) > 90 then
            vehicle.bga.storedDirection = false
        end
    end
    vehicle.bga.driveStrategy = self:getDriveStrategyByAngle(vehicle, angleToSilo, vehicle.bga.storedDirection, dt)

    vehicle.bga.shovelTarget = AutoDriveBGA.SHOVELSTATE_LOW

    if self:getDistanceToTarget(vehicle) <= 4 then
        vehicle.bga.action = AutoDriveBGA.ACTION_DRIVETOSILO_CLOSE_POINT
    end

    self:handleDriveStrategy(vehicle, dt)
end

function AutoDriveBGA:driveToSiloClosePoint(vehicle, dt)
    vehicle.bga.targetPoint = self:getTargetForShovelOffset(vehicle, 6)
    vehicle.bga.driveStrategy = self:getDriveStrategyToTarget(vehicle, true, dt)

    vehicle.bga.shovelTarget = AutoDriveBGA.SHOVELSTATE_LOW

    if self:getDistanceToTarget(vehicle) <= 4 then
        vehicle.bga.action = AutoDriveBGA.ACTION_DRIVETOSILO_REVERSE_POINT
    end

    self:handleDriveStrategy(vehicle, dt)
end

function AutoDriveBGA:driveToSiloReversePoint(vehicle, dt)
    vehicle.bga.targetPoint = self:getTargetForShovelOffset(vehicle, 18)
    vehicle.bga.driveStrategy = self:getDriveStrategyToTarget(vehicle, false, dt)

    vehicle.bga.shovelTarget = AutoDriveBGA.SHOVELSTATE_LOW

    local angleToSilo = self:getAngleToTarget(vehicle)

    if self:getDistanceToTarget(vehicle) <= 9 or (math.abs(angleToSilo) >= 177) then
        vehicle.bga.action = AutoDriveBGA.ACTION_DRIVETOSILO_REVERSE_STRAIGHT
    end

    self:handleDriveStrategy(vehicle, dt)
end

function AutoDriveBGA:driveToSiloReverseStraight(vehicle, dt)
    vehicle.bga.targetPoint = self:getTargetForShovelOffset(vehicle, 68)
    vehicle.bga.driveStrategy = self:getDriveStrategyToTarget(vehicle, false, dt)

    vehicle.bga.shovelTarget = AutoDriveBGA.SHOVELSTATE_LOW

    local angleToSilo = self:getAngleToTarget(vehicle)
    if self:getDistanceToTarget(vehicle) <= 53 or (math.abs(angleToSilo) >= 177) then
        vehicle.bga.action = AutoDriveBGA.ACTION_LOAD_ALIGN
    end

    self:handleDriveStrategy(vehicle, dt)
end

function AutoDriveBGA:alignLoadFromBGA(vehicle, dt)
    vehicle.bga.targetPoint = self:getTargetForShovelOffset(vehicle, 5)
    vehicle.bga.driveStrategy = self:getDriveStrategyToTarget(vehicle, true, dt)

    vehicle.bga.shovelTarget = AutoDriveBGA.SHOVELSTATE_LOADING

    if vehicle.bga.shovelState ~= vehicle.bga.shovelTarget then
        AutoDrive:getVehicleToStop(vehicle, false, dt)
        return
    end

    if self:getDistanceToTarget(vehicle) <= 4 then
        vehicle.bga.action = AutoDriveBGA.ACTION_LOAD
    end

    self:handleDriveStrategy(vehicle, dt)
end

function AutoDriveBGA:handleDriveStrategy(vehicle, dt)
    if vehicle.bga.driveStrategy == AutoDriveBGA.DRIVESTRATEGY_REVERSE_LEFT or vehicle.bga.driveStrategy == AutoDriveBGA.DRIVESTRATEGY_REVERSE_RIGHT then
        local finalSpeed = 8
        local acc = 0.4
        local allowedToDrive = true

        local node = vehicle.components[1].node
        -- if vehicle.getAIVehicleDirectionNode ~= nil then
        --     node = vehicle:getAIVehicleDirectionNode();
        -- end;
        local offsetZ = -5
        local offsetX = 5
        if vehicle.bga.driveStrategy == AutoDriveBGA.DRIVESTRATEGY_REVERSE_LEFT then
            offsetX = -5
        end
        local x, y, z = getWorldTranslation(node)
        local rx, _, rz = localDirectionToWorld(node, offsetX, 0, offsetZ)
        x = x + rx
        z = z + rz
        local lx, lz = AIVehicleUtil.getDriveDirection(node, x, y, z)
        self:driveInDirection(vehicle, dt, 30, acc, 0.2, 20, allowedToDrive, false, lx, lz, finalSpeed, 1)
    elseif vehicle.bga.driveStrategy == AutoDriveBGA.DRIVESTRATEGY_FORWARD_LEFT or vehicle.bga.driveStrategy == AutoDriveBGA.DRIVESTRATEGY_FORWARD_RIGHT then
        local finalSpeed = 8
        local acc = 0.4
        local allowedToDrive = true

        local node = vehicle.components[1].node
        -- if vehicle.getAIVehicleDirectionNode ~= nil then
        --     node = vehicle:getAIVehicleDirectionNode();
        -- end;
        local offsetZ = 5
        local offsetX = 5
        if vehicle.bga.driveStrategy == AutoDriveBGA.DRIVESTRATEGY_FORWARD_LEFT then
            offsetX = -5
        end
        local x, y, z = getWorldTranslation(node)
        local rx, _, rz = localDirectionToWorld(node, offsetX, 0, offsetZ)
        x = x + rx
        z = z + rz
        local lx, lz = AIVehicleUtil.getDriveDirection(node, x, y, z)
        self:driveInDirection(vehicle, dt, 30, acc, 0.2, 20, allowedToDrive, true, lx, lz, finalSpeed, 1)
    else
        local finalSpeed = 10
        local acc = 0.6
        local allowedToDrive = true

        local node = vehicle.components[1].node
        -- if vehicle.getAIVehicleDirectionNode ~= nil then
        --node = vehicle:getAIVehicleDirectionNode();
        --end;
        local _, y, _ = getWorldTranslation(node)
        local lx, lz = AIVehicleUtil.getDriveDirection(node, vehicle.bga.targetPoint.x, y, vehicle.bga.targetPoint.z)
        local driveForwards = true
        if vehicle.bga.driveStrategy == AutoDriveBGA.DRIVESTRATEGY_REVERSE then
            lx = -lx
            lz = -lz
            driveForwards = false
            finalSpeed = 20
        end
        self:driveInDirection(vehicle, dt, 30, acc, 0.2, 20, allowedToDrive, driveForwards, lx, lz, finalSpeed, 1)
    end
end

function AutoDriveBGA:getDriveStrategyToTarget(vehicle, drivingForward, dt)
    local angleToSilo = self:getAngleToTarget(vehicle) -- in +/- 180°

    return self:getDriveStrategyByAngle(vehicle, angleToSilo, drivingForward, dt)
end

function AutoDriveBGA:getDriveStrategyToTrailerInit(vehicle, dt)
    local xT, _, zT = getWorldTranslation(vehicle.bga.targetTrailer.components[1].node)

    local rx, _, rz = localDirectionToWorld(vehicle.bga.targetTrailer.components[1].node, 1, 0, 0)
    --local vehicleVector = {x = rx, z = rz}
    local offSideLeft = {x = xT + rx * 10, z = zT + rz * 10}

    local lx, _, lz = localDirectionToWorld(vehicle.bga.targetTrailer.components[1].node, -1, 0, 0)
    --local vehicleVector = {x = lx, z = lz}
    local offSideRight = {x = xT + lx * 10, z = zT + lz * 10}

    local x, _, z = getWorldTranslation(vehicle.components[1].node)

    local distanceToLeft = math.sqrt(math.pow(offSideLeft.x - x, 2) + math.pow(offSideLeft.z - z, 2))
    local distanceToRight = math.sqrt(math.pow(offSideRight.x - x, 2) + math.pow(offSideRight.z - z, 2))

    if distanceToLeft <= distanceToRight then
        vehicle.bga.targetPoint = {x = offSideLeft.x, z = offSideLeft.z}
    else
        vehicle.bga.targetPoint = {x = offSideRight.x, z = offSideRight.z}
    end

    local angleToTrailer = self:getAngleToTarget(vehicle) -- in +/- 180°

    return self:getDriveStrategyByAngle(vehicle, angleToTrailer, true, dt)
end

function AutoDriveBGA:getDriveStrategyToTrailer(vehicle, dt)
    local xT, _, zT = getWorldTranslation(vehicle.bga.targetTrailer.components[1].node)

    vehicle.bga.targetPoint = {x = xT, z = zT}

    local angleToTrailer = self:getAngleToTarget(vehicle) -- in +/- 180°

    return self:getDriveStrategyByAngle(vehicle, angleToTrailer, true, dt)
end

function AutoDriveBGA:getDriveStrategyByAngle(vehicle, angleToTarget, drivingForward, dt)
    if vehicle.bga.lastAngleStrategyChange == nil then
        vehicle.bga.lastAngleStrategyChange = math.huge
    end

    local angleDiffToLast = math.deg(self:getAngleBetweenTwoRadValues(math.rad(vehicle.bga.lastAngleStrategyChange), math.rad(angleToTarget)))

    local time = 3000
    local timeToChange = vehicle.bga.strategyActiveTimer:timer(true, time, dt)
    local angleToCheckFor = 30
    local newStrategy = vehicle.bga.lastAngleStrategy
    local minimumAngleDiff = 9
    if vehicle.spec_articulatedAxis ~= nil and vehicle.spec_articulatedAxis.rotSpeed ~= nil then
        minimumAngleDiff = 40
    end

    if timeToChange or (angleDiffToLast > minimumAngleDiff) or (math.abs(angleToTarget) < 10) or (math.abs(angleToTarget) > 170) then
        if drivingForward then
            if angleToTarget < -angleToCheckFor then
                newStrategy = AutoDriveBGA.DRIVESTRATEGY_REVERSE_RIGHT
            elseif angleToTarget > angleToCheckFor then
                newStrategy = AutoDriveBGA.DRIVESTRATEGY_REVERSE_LEFT
            elseif (math.abs(angleToTarget) <= angleToCheckFor) then
                newStrategy = AutoDriveBGA.DRIVESTRATEGY_FORWARDS
            end
        else
            angleToCheckFor = 180 - angleToCheckFor
            if ((angleToTarget < angleToCheckFor) and (angleToTarget >= 0)) then
                newStrategy = AutoDriveBGA.DRIVESTRATEGY_FORWARD_RIGHT
            elseif ((angleToTarget > -angleToCheckFor) and (angleToTarget < 0)) then
                newStrategy = AutoDriveBGA.DRIVESTRATEGY_FORWARD_LEFT
            elseif (math.abs(angleToTarget) >= angleToCheckFor) then
                newStrategy = AutoDriveBGA.DRIVESTRATEGY_REVERSE
            end
        end
    end

    if vehicle.bga.lastAngleStrategy ~= newStrategy then
        vehicle.bga.lastAngleStrategyChange = angleToTarget
        vehicle.bga.strategyActiveTimer:timer(false)
    end
    vehicle.bga.lastAngleStrategy = newStrategy

    return vehicle.bga.lastAngleStrategy
end

function AutoDriveBGA:getAngleToTarget(vehicle)
    local x, _, z = getWorldTranslation(vehicle.components[1].node)
    local rx, _, rz = localDirectionToWorld(vehicle.components[1].node, 0, 0, 1)
    if vehicle.spec_articulatedAxis ~= nil and vehicle.spec_articulatedAxis.rotSpeed ~= nil then
        rx, _, rz = localDirectionToWorld(vehicle.components[1].node, MathUtil.sign(vehicle.spec_articulatedAxis.rotSpeed) * math.sin(vehicle.rotatedTime), 0, math.cos(vehicle.rotatedTime))
        rx, _, rz = localDirectionToWorld(vehicle.components[1].node, MathUtil.sign(vehicle.spec_articulatedAxis.rotSpeed) * math.sin(vehicle.rotatedTime) / 2, 0, (1 + math.cos(vehicle.rotatedTime)) / 2)
    end
    local vehicleVector = {x = rx, z = rz}

    local vecToTrailer = {x = vehicle.bga.targetPoint.x - x, z = vehicle.bga.targetPoint.z - z}

    return AutoDrive.angleBetween(vehicleVector, vecToTrailer)
end

function AutoDriveBGA:loadFromBGA(vehicle, dt)
    vehicle.bga.shovelTarget = AutoDriveBGA.SHOVELSTATE_LOADING

    if self:checkForStopLoading(vehicle) then
        vehicle.bga.action = AutoDriveBGA.ACTION_REVERSEFROMLOAD
    end

    vehicle.bga.targetPoint = self:getTargetForShovelOffset(vehicle, -MathUtil.vector2Length(vehicle.bga.vecH.x, vehicle.bga.vecH.z))
    vehicle.bga.driveStrategy = AutoDriveBGA.DRIVESTRATEGY_FORWARDS

    if self:getDistanceToTarget(vehicle) <= 4 then
        vehicle.bga.action = AutoDriveBGA.ACTION_REVERSEFROMLOAD
    end

    self:handleDriveStrategy(vehicle, dt)
end

function AutoDriveBGA:getTargetForShovelOffset(vehicle, inFront)
    local offsetToUse = vehicle.bga.shovelOffsetCounter
    local fromOtherSide = false
    if vehicle.bga.shovelOffsetCounter > vehicle.bga.highestShovelOffsetCounter then
        offsetToUse = 0
        fromOtherSide = true
    end
    local offset = (vehicle.bga.shovelWidth * (0.5 + offsetToUse)) + AutoDriveBGA.SHOVEL_WIDTH_OFFSET
    return self:getPointXInFrontAndYOffsetFromBunker(vehicle, inFront, offset, fromOtherSide)
end

function AutoDriveBGA:getPointXInFrontAndYOffsetFromBunker(vehicle, inFront, offset, fromOtherSide)
    local p1, p2 = self:getTargetBunkerLoadingSide(vehicle)
    if fromOtherSide ~= nil and fromOtherSide == true then
        p1, p2 = p2, p1
    end
    local normalizedVec = {x = (p2.x - p1.x) / (math.abs(p2.x - p1.x) + math.abs(p2.z - p1.z)), z = (p2.z - p1.z) / (math.abs(p2.x - p1.x) + math.abs(p2.z - p1.z))}
    --get ortho for 'inFront' parameter
    local ortho = {x = -normalizedVec.z, z = normalizedVec.x}
    --get shovel offset correct position on silo line
    local targetPoint = {x = p1.x + normalizedVec.x * offset, z = p1.z + normalizedVec.z * offset}

    local pointPositive = {x = targetPoint.x + ortho.x * inFront, z = targetPoint.z + ortho.z * inFront}
    local pointNegative = {x = targetPoint.x - ortho.x * inFront, z = targetPoint.z - ortho.z * inFront}
    local bunkerCenter = {}
    bunkerCenter.x, bunkerCenter.z = self:getBunkerCenter(vehicle.bga.targetBunker)

    local result = pointNegative
    if inFront < 0 then --we want a point inside the bunker. So use the closer one
        result = pointPositive
    end
    if math.sqrt(math.pow(bunkerCenter.x - pointPositive.x, 2) + math.pow(bunkerCenter.z - pointPositive.z, 2)) >= math.sqrt(math.pow(bunkerCenter.x - pointNegative.x, 2) + math.pow(bunkerCenter.z - pointNegative.z, 2)) then
        result = pointPositive
        if inFront < 0 then --we want a point inside the bunker. So use the closer one
            result = pointNegative
        end
    end

    return result
end

function AutoDriveBGA:reverseFromBGALoad(vehicle, dt)
    vehicle.bga.shovelTarget = AutoDriveBGA.SHOVELSTATE_LOW

    vehicle.bga.targetPoint = self:getTargetForShovelOffset(vehicle, 200)
    vehicle.bga.targetPointClose = self:getTargetForShovelOffset(vehicle, 16)

    local finalSpeed = 30
    local acc = 1
    local allowedToDrive = true

    local node = vehicle.components[1].node
    -- if vehicle.getAIVehicleDirectionNode ~= nil then
    --     node = vehicle:getAIVehicleDirectionNode();
    -- end;
    local x, y, z = getWorldTranslation(node)
    local lx, lz = AIVehicleUtil.getDriveDirection(node, vehicle.bga.targetPoint.x, y, vehicle.bga.targetPoint.z)
    AIVehicleUtil.driveInDirection(vehicle, dt, 30, acc, 0.2, 20, allowedToDrive, false, -lx, -lz, finalSpeed, 1)

    if math.sqrt(math.pow(x - vehicle.bga.targetPointClose.x, 2) + math.pow(z - vehicle.bga.targetPointClose.z, 2)) < 5 then
        vehicle.bga.action = AutoDriveBGA.ACTION_DRIVETOUNLOAD_INIT
        if vehicle.bga.shovelFillLevel <= 0.01 then
            vehicle.bga.action = AutoDriveBGA.ACTION_DRIVETOSILO_COMMON_POINT
        end
        if vehicle.bga.shovelOffsetCounter > vehicle.bga.highestShovelOffsetCounter then
            vehicle.bga.shovelOffsetCounter = 0
        else
            vehicle.bga.shovelOffsetCounter = vehicle.bga.shovelOffsetCounter + 1
        end
    end
end

function AutoDriveBGA:driveToBGAUnloadInit(vehicle, dt)
    if vehicle.bga.targetTrailer == nil then
        self:getVehicleToPause(vehicle)
        AutoDrive:getVehicleToStop(vehicle, false, dt)
        return
    end

    vehicle.bga.shovelTarget = AutoDriveBGA.SHOVELSTATE_BEFORE_UNLOAD

    vehicle.bga.driveStrategy = self:getDriveStrategyToTrailerInit(vehicle, dt)

    self:handleDriveStrategy(vehicle, dt)

    local x, _, z = getWorldTranslation(vehicle.components[1].node)

    if math.sqrt(math.pow(vehicle.bga.targetPoint.x - x, 2) + math.pow(vehicle.bga.targetPoint.z - z, 2)) <= 4 then
        vehicle.bga.action = AutoDriveBGA.ACTION_DRIVETOUNLOAD
    end
    if vehicle.bga.targetTrailer == nil or (vehicle.bga.trailerLeftCapacity <= 0.001) then
        vehicle.bga.action = AutoDriveBGA.ACTION_REVERSEFROMUNLOAD
        vehicle.bga.shovelTarget = AutoDriveBGA.SHOVELSTATE_BEFORE_UNLOAD
        vehicle.bga.shovel:setDischargeState(Dischargeable.DISCHARGE_STATE_OFF, true)
    end
end

function AutoDriveBGA:driveToBGAUnload(vehicle, dt)
    if vehicle.bga.targetTrailer == nil then
        AutoDrive.printMessage(vehicle, vehicle.ad.driverName .. " " .. g_i18n:getText("AD_No_Trailer"))
        self:getVehicleToPause(vehicle)
        AutoDrive:getVehicleToStop(vehicle, false, dt)
        return
    end
    if self:getDistanceBetween(vehicle, vehicle.bga.targetTrailer) <= 10 then
        vehicle.bga.shovelTarget = AutoDriveBGA.SHOVELSTATE_BEFORE_UNLOAD
    elseif self:getDistanceBetween(vehicle, vehicle.bga.targetTrailer) > 20 then
        vehicle.bga.shovelTarget = AutoDriveBGA.SHOVELSTATE_TRANSPORT
    end
    if vehicle.bga.shovelState ~= vehicle.bga.shovelTarget then
        AutoDrive:getVehicleToStop(vehicle, false, dt)
        return
    end

    vehicle.bga.driveStrategy = self:getDriveStrategyToTrailer(vehicle, dt)

    self:handleDriveStrategy(vehicle, dt)

    if vehicle.bga.inShovelRangeTimer:timer(self:getShovelInTrailerRange(vehicle), 350, dt) then
        vehicle.bga.action = AutoDriveBGA.ACTION_UNLOAD
    end
    if vehicle.bga.targetTrailer == nil or (vehicle.bga.trailerLeftCapacity <= 0.1) then
        vehicle.bga.action = AutoDriveBGA.ACTION_REVERSEFROMUNLOAD
        vehicle.bga.shovelTarget = AutoDriveBGA.SHOVELSTATE_BEFORE_UNLOAD
        vehicle.bga.shovel:setDischargeState(Dischargeable.DISCHARGE_STATE_OFF, true)
    end
end

function AutoDriveBGA:handleBGAUnload(vehicle, dt)
    AutoDrive:getVehicleToStop(vehicle, false, dt)
    vehicle.bga.shovelTarget = AutoDriveBGA.SHOVELSTATE_UNLOAD
    local xV, _, zV = getWorldTranslation(vehicle.components[1].node)
    vehicle.bga.shovelUnloadPosition = {x = xV, z = zV}

    if vehicle.bga.shovelFillLevel <= 0.01 then
        vehicle.bga.strategyActiveTimer.elapsedTime = math.huge
        vehicle.bga.shovelState = AutoDriveBGA.SHOVELSTATE_UNLOAD
        vehicle.bga.action = AutoDriveBGA.ACTION_REVERSEFROMUNLOAD
        vehicle.bga.shovel:setDischargeState(Dischargeable.DISCHARGE_STATE_OFF, true)
    end
    if vehicle.bga.targetTrailer == nil or (vehicle.bga.trailerLeftCapacity <= 0.1) then
        vehicle.bga.action = AutoDriveBGA.ACTION_REVERSEFROMUNLOAD
        vehicle.bga.shovelState = AutoDriveBGA.SHOVELSTATE_UNLOAD
        vehicle.bga.shovelTarget = AutoDriveBGA.SHOVELSTATE_BEFORE_UNLOAD
        vehicle.bga.shovel:setDischargeState(Dischargeable.DISCHARGE_STATE_OFF, true)
    end
end

function AutoDriveBGA:reverseFromBGAUnload(vehicle, dt)
    vehicle.bga.shovelTarget = AutoDriveBGA.SHOVELSTATE_BEFORE_UNLOAD
    vehicle.bga.shovel:setDischargeState(Dischargeable.DISCHARGE_STATE_OFF, true)

    for _, shovelNode in pairs(vehicle.bga.shovel.spec_shovel.shovelNodes) do
        shovelNode.litersToDrop = 0
    end

    if vehicle.bga.shovelState ~= vehicle.bga.shovelTarget then
        AutoDrive:getVehicleToStop(vehicle, false, dt)
        return
    end

    local finalSpeed = 9
    local acc = 1
    local allowedToDrive = true

    local node = vehicle.components[1].node
    -- if vehicle.getAIVehicleDirectionNode ~= nil then
    --     node = vehicle:getAIVehicleDirectionNode();
    -- end;
    local x, _, z = getWorldTranslation(node)
    local rx, _, rz = localDirectionToWorld(node, 0, 0, -1)
    x = x + rx
    z = z + rz
    --local lx, lz = AIVehicleUtil.getDriveDirection(node, x, y, z)
    AIVehicleUtil.driveInDirection(vehicle, dt, 30, acc, 0.2, 20, allowedToDrive, false, nil, nil, finalSpeed, 1)

    if vehicle.bga.shovelUnloadPosition ~= nil then
        if MathUtil.vector2Length(x - vehicle.bga.shovelUnloadPosition.x, z - vehicle.bga.shovelUnloadPosition.z) >= 6 then
            vehicle.bga.shovelTarget = AutoDriveBGA.SHOVELSTATE_LOW
        else
            vehicle.bga.shovelTarget = AutoDriveBGA.SHOVELSTATE_BEFORE_UNLOAD
        end
    end

    if MathUtil.vector2Length(x - vehicle.bga.shovelUnloadPosition.x, z - vehicle.bga.shovelUnloadPosition.z) >= 8 then
        vehicle.bga.shovel:setDischargeState(Dischargeable.DISCHARGE_STATE_OFF, true)
        vehicle.bga.action = AutoDriveBGA.ACTION_DRIVETOSILO_COMMON_POINT
    end
end

function AutoDriveBGA:getVehicleToPause(vehicle)
    vehicle.bga.state = AutoDriveBGA.STATE_WAITING_FOR_RESTART
end

function AutoDriveBGA:getShovelInTrailerRange(vehicle)
    --local x, y, z = getWorldTranslation(vehicle.components[1].node)
    --local xT, yT, zT = getWorldTranslation(vehicle.bga.targetTrailer.components[1].node)
    local dischargeNode = vehicle.bga.shovel:getCurrentDischargeNode()
    if dischargeNode ~= nil then
        local dischargeTarget = dischargeNode.dischargeObject
        if dischargeTarget ~= nil then
            local result = vehicle.bga.shovel:getDischargeState() == Dischargeable.DISCHARGE_STATE_OBJECT and dischargeTarget == vehicle.bga.targetTrailer
            return result
        end
    end
    return false
end

function AutoDriveBGA:determineHighestShovelOffset(vehicle)
    local width = vehicle.bga.shovelWidth
    local p1, p2 = self:getTargetBunkerLoadingSide(vehicle)
    local sideLength = MathUtil.vector2Length(p1.x - p2.x, p1.z - p2.z)
    vehicle.bga.highestShovelOffsetCounter = math.floor((sideLength - 2 * AutoDriveBGA.SHOVEL_WIDTH_OFFSET) / width) - 1
end

function AutoDriveBGA:getDistanceToTarget(vehicle)
    local x, _, z = getWorldTranslation(vehicle.components[1].node)
    return MathUtil.vector2Length(x - vehicle.bga.targetPoint.x, z - vehicle.bga.targetPoint.z)
end

function AutoDriveBGA:stateToText(vehicle)
    local text = nil
    if vehicle.bga.state == AutoDriveBGA.STATE_INIT or vehicle.bga.state == AutoDriveBGA.STATE_INIT_AXIS then
        text = g_i18n:getText("ad_bga_init")
    elseif vehicle.bga.state == AutoDriveBGA.STATE_WAITING_FOR_RESTART then
        text = g_i18n:getText("ad_bga_waiting")
    elseif vehicle.bga.state == AutoDriveBGA.STATE_ACTIVE then
        text = g_i18n:getText("ad_bga_active")
    end

    return text
end

function AutoDriveBGA:checkForFillLevelInCurrentRow(vehicle)
    local offsetToUse = vehicle.bga.shovelOffsetCounter
    local fromOtherSide = false
    if vehicle.bga.shovelOffsetCounter > vehicle.bga.highestShovelOffsetCounter then
        offsetToUse = 0
        fromOtherSide = true
    end
    --local inFront = 0

    local p1, p2 = self:getTargetBunkerLoadingSide(vehicle)
    if fromOtherSide ~= nil and fromOtherSide == true then
        p1, p2 = p2, p1
    end
    local normalizedVec = {x = (p2.x - p1.x) / (math.abs(p2.x - p1.x) + math.abs(p2.z - p1.z)), z = (p2.z - p1.z) / (math.abs(p2.x - p1.x) + math.abs(p2.z - p1.z))}
    --get ortho for 'inFront' parameter
    --local ortho = {x = -normalizedVec.z, z = normalizedVec.x}
    --get shovel offset correct position on silo line
    local offset = (vehicle.bga.shovelWidth * (0.0 + offsetToUse))
    local targetPoint = {x = p1.x + normalizedVec.x * offset, z = p1.z + normalizedVec.z * offset}
    offset = (vehicle.bga.shovelWidth * (1.0 + offsetToUse))
    local targetPoint2 = {x = p1.x + normalizedVec.x * offset, z = p1.z + normalizedVec.z * offset}

    local pointPositive = {x = targetPoint.x + vehicle.bga.vecH.x, z = targetPoint.z + vehicle.bga.vecH.z}
    local pointNegative = {x = targetPoint.x - vehicle.bga.vecH.x, z = targetPoint.z - vehicle.bga.vecH.z}
    local bunkerCenter = {}
    bunkerCenter.x, bunkerCenter.z = self:getBunkerCenter(vehicle.bga.targetBunker)

    local result = pointNegative
    if math.sqrt(math.pow(bunkerCenter.x - pointPositive.x, 2) + math.pow(bunkerCenter.z - pointPositive.z, 2)) <= math.sqrt(math.pow(bunkerCenter.x - pointNegative.x, 2) + math.pow(bunkerCenter.z - pointNegative.z, 2)) then
        result = pointPositive
    end

    local innerFillLevel1 = 0 --DensityMapHeightUtil.getFillLevelAtArea(vehicle.bga.targetBunker.fermentingFillType, targetPoint.x,targetPoint.z, targetPoint2.x,targetPoint2.z, result.x,result.z)
    local innerFillLevel2 = DensityMapHeightUtil.getFillLevelAtArea(vehicle.bga.targetBunker.outputFillType, targetPoint.x, targetPoint.z, targetPoint2.x, targetPoint2.z, result.x, result.z)
    local innerFillLevel = innerFillLevel1 + innerFillLevel2

    return innerFillLevel
end

function AutoDriveBGA:setShovelOffsetToNonEmptyRow(vehicle)
    local currentFillLevel = self:checkForFillLevelInCurrentRow(vehicle)
    local iterations = vehicle.bga.highestShovelOffsetCounter + 1
    while ((currentFillLevel == 0) and (iterations >= 0)) do
        iterations = iterations - 1
        if vehicle.bga.shovelOffsetCounter > vehicle.bga.highestShovelOffsetCounter then
            vehicle.bga.shovelOffsetCounter = 0
        else
            vehicle.bga.shovelOffsetCounter = vehicle.bga.shovelOffsetCounter + 1
        end
        currentFillLevel = self:checkForFillLevelInCurrentRow(vehicle)
    end

    if ((currentFillLevel == 0) and (iterations < 0)) then
        AutoDrive.printMessage(vehicle, vehicle.ad.driverName .. " " .. g_i18n:getText("AD_No_Bunker"))
        vehicle.bga.state = AutoDriveBGA.STATE_IDLE
        AutoDrive:stopAD(vehicle, true)
    end
end

function AutoDriveBGA:driveInDirection(vehicle, dt, steeringAngleLimit, acceleration, slowAcceleration, slowAngleLimit, allowedToDrive, moveForwards, lx, lz, maxSpeed, slowDownFactor)
    if lx ~= nil and lz ~= nil then
        local dot = lz
        local angle = math.deg(math.acos(dot))
        if angle < 0 then
            angle = angle + 180
        end
        local turnLeft = lx > 0.00001
        if not moveForwards then
            turnLeft = not turnLeft
        end
        local targetRotTime = 0
        if turnLeft then
            --rotate to the left
            targetRotTime = vehicle.maxRotTime * math.min(angle / steeringAngleLimit, 1)
        else
            --rotate to the right
            targetRotTime = vehicle.minRotTime * math.min(angle / steeringAngleLimit, 1)
        end

        if math.abs(targetRotTime - vehicle.rotatedTime) >= 0.1 then --and (vehicle.spec_articulatedAxis == nil) then
            maxSpeed = 1
        end

        AIVehicleUtil.driveInDirection(vehicle, dt, steeringAngleLimit, acceleration, slowAcceleration, slowAngleLimit, allowedToDrive, moveForwards, lx, lz, maxSpeed, slowDownFactor)
    end
end
