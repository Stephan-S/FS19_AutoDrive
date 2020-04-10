AutoDrive.CHASEPOS_LEFT = 1
AutoDrive.CHASEPOS_RIGHT = -1
AutoDrive.CHASEPOS_REAR = 3
AutoDrive.CHASEPOS_FRONT = 4

function AutoDrive.getNodeName(node)
    if node == nil then
        return "nil"
    else
        return getName(node)
    end
end

function AutoDrive.getDischargeNode(combine)
    local dischargeNode = nil
    for _, dischargeNodeIter in pairs(combine.spec_dischargeable.dischargeNodes) do
        dischargeNode = dischargeNodeIter
    end
    if combine.getPipeDischargeNodeIndex ~= nil then
        dischargeNode = combine.spec_dischargeable.dischargeNodes[combine:getPipeDischargeNodeIndex()]
    end
    return dischargeNode.node
end

function AutoDrive.getPipeRoot(combine)
    local pipeRoot = AutoDrive.getDischargeNode(combine)
    local parentStack = Buffer:new()
    local combineNode = combine.components[1].node

    repeat
        parentStack:Insert(pipeRoot)
        pipeRoot = getParent(pipeRoot)
    until ((pipeRoot == combineNode) or (pipeRoot == 0) or (pipeRoot == nil) or parentStack:Count() == 100)

    local translationMagnitude = 0
    local pipeRootX, pipeRootY, pipeRootZ
    local pipeRootWorldX, pipeRootWorldY, pipeRootWorldZ
    local heightUnderRoot, pipeRootAgl
    local lastPipeRoot = pipeRoot

    repeat
        pipeRoot = parentStack:Get()
        if pipeRoot ~= nil and pipeRoot ~= 0 then
            pipeRootX, pipeRootY, pipeRootZ = getTranslation(pipeRoot)
            pipeRootWorldX, pipeRootWorldY, pipeRootWorldZ = getWorldTranslation(pipeRoot)
            heightUnderRoot = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, pipeRootWorldX, pipeRootWorldY, pipeRootWorldZ)
            pipeRootAgl = pipeRootWorldY - heightUnderRoot
            translationMagnitude = MathUtil.vector3Length(pipeRootX, pipeRootY, pipeRootZ)
        end
    until ((translationMagnitude > 0.01 and translationMagnitude < 100) and
           (combine:getIsBufferCombine() or AutoDrive.sign(pipeRootX) == AutoDrive.getPipeSide(combine)) and
           (pipeRootY > 0) or
           parentStack:Count() == 0
          )
          
    if pipeRoot == nil or pipeRoot == 0 then
        pipeRoot = combine.components[1].node
    end

    return pipeRoot
end

function AutoDrive.getPipeRootOffset(combine)
    local combineNode = combine.components[1].node
    local pipeRoot = AutoDrive.getPipeRoot(combine)
    local pipeRootX, pipeRootY, pipeRootZ = getWorldTranslation(pipeRoot)
    local diffX, diffY, diffZ = worldToLocal(combineNode, pipeRootX, pipeRootY, pipeRootZ)
    --AutoDrive.debugPrint(combine, AutoDrive.DC_COMBINEINFO, "AutoDrive.getPipeRootZOffset - " .. diffZ )
    return worldToLocal(combineNode, pipeRootX, pipeRootY, pipeRootZ)
end

function AutoDrive.getPipeSide(combine)
    local combineNode = combine.components[1].node
    local dischargeNode = AutoDrive.getDischargeNode(combine)
    local dischargeX, dichargeY, dischargeZ = getWorldTranslation(dischargeNode)
    local diffX, _, _ = worldToLocal(combineNode, dischargeX, dichargeY, dischargeZ)
    return AutoDrive.sign(diffX)
end

function AutoDrive.getPipeLength(combine)
    if combine.ad ~= nil and combine.ad.storedPipeLength ~= nil then
        return combine.ad.storedPipeLength
    end

    local pipeRootX, _ , pipeRootZ = getWorldTranslation(AutoDrive.getPipeRoot(combine))
    local dischargeX, dischargeY, dischargeZ = getWorldTranslation(AutoDrive.getDischargeNode(combine))
    local length = MathUtil.vector3Length(pipeRootX - dischargeX,
                                        0, 
                                        pipeRootZ - dischargeZ)
    --AutoDrive.debugPrint(combine, AutoDrive.DC_COMBINEINFO, "AutoDrive.getPipeLength - " .. length)
    if AutoDrive.isPipeOut(combine) and not combine:getIsBufferCombine() then
        local combineNode = combine.components[1].node
        local dischargeX, dichargeY, dischargeZ = getWorldTranslation(AutoDrive.getDischargeNode(combine))
        diffX, _, _ = worldToLocal(combineNode, dischargeX, dichargeY, dischargeZ)
        length = math.abs(diffX) - combine.sizeWidth /2

        -- Store pipe length for 'normal' harvesters
        if not combine:getIsBufferCombine() and (not combine.typeName == "combineCutterFruitPreparer") then
            if combine.ad ~= nil then
                combine.ad.storedPipeLength = length
            end
        end
    end

    return length
end

function AutoDrive.isPipeOut(combine)
    local spec = combine.spec_pipe
    if spec.currentState == spec.targetState and (spec.currentState == 2 or combine.typeName == "combineCutterFruitPreparer") then
        return true
    else
        return false
    end
end

function AutoDrive.isSugarcaneHarvester(combine)
    local isSugarCaneHarvester = true
    if combine.getAttachedImplements ~= nil then
        for _, implement in pairs(combine:getAttachedImplements()) do
            if implement ~= nil and implement ~= combine and (implement.object == nil or implement.object ~= combine) then
                isSugarCaneHarvester = false
            end
        end
    end
    return isSugarCaneHarvester
end

function AutoDrive.getFrontToolWidth(vehicle)
    local widthOfFrontTool = 0

    if vehicle.getAttachedImplements ~= nil then
        for _, impl in pairs(vehicle:getAttachedImplements()) do
            local tool = impl.object
            if tool ~= nil and tool.sizeWidth ~= nil then
                --Check if tool is in front of vehicle
                local toolX, toolY, toolZ = getWorldTranslation(tool.components[1].node)
                local _, _, offsetZ =  worldToLocal(vehicle.components[1].node, toolX, toolY, toolZ)
                if offsetZ > 0 then
                    widthOfFrontTool = math.abs(tool.sizeWidth)
                end
            end
        end
    end

    return widthOfFrontTool
end

function AutoDrive.getFrontToolLength(vehicle)
    local lengthOfFrontTool = 0

    if vehicle.getAttachedImplements ~= nil then
        for _, impl in pairs(vehicle:getAttachedImplements()) do
            local tool = impl.object
            if tool ~= nil and tool.sizeWidth ~= nil then
                --Check if tool is in front of vehicle
                local toolX, toolY, toolZ = getWorldTranslation(tool.components[1].node)
                local _, _, offsetZ =  worldToLocal(vehicle.components[1].node, toolX, toolY, toolZ)
                if offsetZ > 0 then
                    lengthOfFrontTool = math.abs(tool.sizeLength)
                end
            end
        end
    end

    return lengthOfFrontTool
end
