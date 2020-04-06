AutoDrive.CHASEPOS_LEFT = 1
AutoDrive.CHASEPOS_RIGHT = -1
AutoDrive.CHASEPOS_REAR = 3

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
    local count = 0
    local pipeRoot = AutoDrive.getDischargeNode(combine)
    local parentStack = Buffer:new()
    local combineNode = combine.components[1].node
    --AutoDrive.debugPrint(combine, AutoDrive.DC_COMBINEINFO, "AutoDrive.getPipeRoot - Combine Node " .. combineNode .. " " .. self:getNodeName(combineNode))
    
    while (pipeRoot ~= combineNode) and (count < 100) and (pipeRoot ~= nil) do
        parentStack:Insert(pipeRoot)
        pipeRoot = getParent(pipeRoot)
        if pipeRoot == 0 or pipeRoot == nil then
            -- Something unexpected happened, like the discharge node not belonging to self.combine.
            -- This can happen with harvesters with multiple components
            -- KNOWN ISSUE: The Panther 2 beet harvester triggers this condition
            return combineNode
        end
        count = count + 1
    end

    local translationMagnitude = 0
    -- Pop the first thing off the stack. This should refer to a large chunk of the harvester and it useless
    -- for our purposes.
    --parentStack:Get()
    pipeRoot = parentStack:Get()
    local pipeRootX, pipeRootY, pipeRootZ = getTranslation(pipeRoot)
    local pipeRootWorldX, pipeRootWorldY, pipeRootWorldZ = getWorldTranslation(pipeRoot)
    local heightUnderRoot = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, pipeRootWorldX, pipeRootWorldY, pipeRootWorldZ)
    local pipeRootAgl = pipeRootWorldY - heightUnderRoot
    --AutoDrive.debugPrint(combine, AutoDrive.DC_COMBINEINFO, "AutoDrive.getPipeTranslationRoot - Search Stack " .. pipeRoot .. " " .. self:getNodeName(pipeRoot))
    --AutoDrive.debugPrint(combine, AutoDrive.DC_COMBINEINFO, "AutoDrive.getPipeTranslationRoot - Search Stack " .. translationMagnitude .. " " .. pipeRootAgl .. " " .. " " .. AutoDrive.sign(pipeRootX))
    while ((translationMagnitude < 0.01) or 
            (not combine:getIsBufferCombine() and AutoDrive.sign(pipeRootX) ~= AutoDrive.getPipeSide(combine)) or
            (pipeRootY < 0) and -- This may be a poor assumption. Depends on where the "moving parts" node is translated to, and it's inconsistent.
            parentStack:Count() > 0) do
        pipeRoot = parentStack:Get()
        pipeRootX, pipeRootY, pipeRootZ = getTranslation(pipeRoot)
        pipeRootWorldX, pipeRootWorldY, pipeRootWorldZ = getWorldTranslation(pipeRoot)
        heightUnderRoot = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, pipeRootWorldX, pipeRootWorldY, pipeRootWorldZ)
        pipeRootAgl = pipeRootWorldY - heightUnderRoot
        
        translationMagnitude = MathUtil.vector3Length(pipeRootX, pipeRootY, pipeRootZ)
        --AutoDrive.debugPrint(self.combine, AutoDrive.DC_COMBINEINFO, "AutoDrive.getPipeTranslationRoot - Search Stack " .. pipeRoot .. " " .. self:getNodeName(pipeRoot))
        --AutoDrive.debugPrint(self.combine, AutoDrive.DC_COMBINEINFO, "AutoDrive.getPipeTranslationRoot - Search Stack " .. translationMagnitude .. " " .. pipeRootAgl .. " " .. " " .. AutoDrive.sign(pipeRootX))
    end

    return pipeRoot
end

function AutoDrive.getPipeRootOffset(combine)
    local combineNode = combine.components[1].node
    local pipeRoot = AutoDrive.getPipeRoot(combine)
    local pipeRootX, pipeRootY, pipeRootZ = getWorldTranslation(pipeRoot)
    local diffX, diffY, diffZ = worldToLocal(combineNode, pipeRootX, pipeRootY, pipeRootZ)
    AutoDrive.debugPrint(combine, AutoDrive.DC_COMBINEINFO, "AutoDrive.getPipeRootZOffset - " .. diffZ )
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
    local pipeRootX, _ , pipeRootZ = getWorldTranslation(AutoDrive.getPipeRoot(combine))
    local dischargeX, dischargeY, dischargeZ = getWorldTranslation(AutoDrive.getDischargeNode(combine))
    local length = MathUtil.vector3Length(pipeRootX - dischargeX, 
                                          0, 
                                          pipeRootZ - dischargeZ)
    AutoDrive.debugPrint(combine, AutoDrive.DC_COMBINEINFO, "AutoDrive.getPipeLength - " .. length)
    return length
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