function AutoDrive.getDriverRadius(vehicle)
    local minTurnRadius = AIVehicleUtil.getAttachedImplementsMaxTurnRadius(vehicle)
    if AIVehicleUtil.getAttachedImplementsMaxTurnRadius(vehicle) <= 5 then
        minTurnRadius = PathFinderModule.PP_CELL_X
    end

    local maxToolRadius = 0
    for _, implement in pairs(vehicle:getAttachedAIImplements()) do
        maxToolRadius = math.max(maxToolRadius, AIVehicleUtil.getMaxToolRadius(implement))
    end

    minTurnRadius = math.max(minTurnRadius, maxToolRadius)

    return minTurnRadius
end

function AutoDrive.boundingBoxFromCorners(cornerX, cornerZ, corner2X, corner2Z, corner3X, corner3Z, corner4X, corner4Z)
    local boundingBox = {}
    boundingBox[1] = {
        x = cornerX,
        y = 0,
        z = cornerZ
    }
    boundingBox[2] = {
        x = corner2X,
        y = 0,
        z = corner2Z
    }
    boundingBox[3] = {
        x = corner3X,
        y = 0,
        z = corner3Z
    }
    boundingBox[4] = {
        x = corner4X,
        y = 0,
        z = corner4Z
    }

    return boundingBox
end

AutoDrive.implementsAllowedForReverseDriving = {
"trailer", 
"trailerlow",
"semitrailer",
"implement"
}


function AutoDrive.isImplementAllowedForReverseDriving(implement)
-- return true for implements allowed move reverse
    local ret = false

    if implement ~= nil and implement.object ~= nil and implement.object.spec_attachable ~= nil and implement.object.spec_attachable.attacherJoint ~= nil and implement.object.spec_attachable.attacherJoint.jointType ~= nil then
        -- g_logManager:info("[AD] isImplementAllowedForReverseDriving implement.object.spec_attachable.attacherJoint.jointType %s ", tostring(implement.object.spec_attachable.attacherJoint.jointType))
        for i, name in ipairs(AutoDrive.implementsAllowedForReverseDriving) do
            local key = "JOINTTYPE_"..string.upper(name)
            
            if AttacherJoints[key] ~= nil and AttacherJoints[key] == implement.object.spec_attachable.attacherJoint.jointType then
                -- g_logManager:info("[AD] isImplementAllowedForReverseDriving implement allowed %s ", tostring(key))
                return true
            end
        end
    end
    return ret
end

