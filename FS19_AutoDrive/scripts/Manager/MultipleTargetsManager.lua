ADMultipleTargetsManager = {}

function ADMultipleTargetsManager:load()
    self.groups = {}
    for groupName, _ in pairs(ADGraphManager:getGroups()) do
        self.groups[groupName] = {}
        self.groups[groupName].lastTarget = nil
        self.groups[groupName].lastVehicle = nil
    end
    self.pickups = {}
    for groupName, _ in pairs(ADGraphManager:getGroups()) do
        self.pickups[groupName] = {}
        self.pickups[groupName].lastTarget = nil
        self.pickups[groupName].lastVehicle = nil
    end
end

function ADMultipleTargetsManager:getNextTarget(driver, forcedSkip)
    -- AutoDrive.debugPrint(driver, AutoDrive.DC_PATHINFO, "[AD] ADMultipleTargetsManager:getNextTarget driver.ad.stateModule:getSecondMarker()", tostring(driver.ad.stateModule:getSecondMarker()))
    local target = driver.ad.stateModule:getSecondMarker().markerIndex
    local groupName = driver.ad.stateModule:getSecondMarker().group

    if self.groups[groupName] == nil then
        self.groups[groupName] = {}
        self.groups[groupName].lastTarget = nil
        self.groups[groupName].lastVehicle = nil
    end

    if self.groups[groupName].lastVehicle == nil or (driver ~= self.groups[groupName].lastVehicle or forcedSkip) then
        if groupName ~= "All" then
            if self.groups[groupName] ~= nil then
                if self.groups[groupName].lastTarget == nil then
                    self.groups[groupName].lastTarget = driver.ad.stateModule:getSecondMarker().markerIndex
                else
                    local nextMarkerInGroup = nil
                    local markerSeen = false
                    local firstMarkerInGroup = nil
                    for _, marker in ipairs(ADGraphManager:getMapMarkersInGroup(groupName)) do
                        if marker.group == groupName then
                            if firstMarkerInGroup == nil then
                                firstMarkerInGroup = marker.markerIndex
                            end

                            if markerSeen and nextMarkerInGroup == nil then
                                nextMarkerInGroup = marker.markerIndex
                            end

                            if marker.markerIndex == self.groups[groupName].lastTarget then
                                markerSeen = true
                            end
                        end
                    end

                    if nextMarkerInGroup ~= nil then
                        target = nextMarkerInGroup
                    elseif firstMarkerInGroup ~= nil then
                        target = firstMarkerInGroup
                    end
                    self.groups[groupName].lastTarget = target
                    self.groups[groupName].lastVehicle = driver
                end
                AutoDrive.Hud.lastUIScale = 0
            end
        end
    end

    if self.groups[groupName].lastVehicle == nil then
        self.groups[groupName].lastVehicle = driver
        self.groups[groupName].lastTarget = target
    end
    -- AutoDrive.debugPrint(driver, AutoDrive.DC_PATHINFO, "[AD] ADMultipleTargetsManager:getNextTarget end target %s", tostring(ADGraphManager:getMapMarkerById(target).name))

    return target
end

function ADMultipleTargetsManager:getNextPickup(driver, forcedSkip)
    -- AutoDrive.debugPrint(driver, AutoDrive.DC_PATHINFO, "[AD] ADMultipleTargetsManager:getNextPickup driver.ad.stateModule:getFirstMarkerName()", tostring(driver.ad.stateModule:getFirstMarkerName()))
    local target = driver.ad.stateModule:getFirstMarker().markerIndex
    local groupName = driver.ad.stateModule:getFirstMarker().group
    if self.pickups[groupName] == nil then
        self.pickups[groupName] = {}
        self.pickups[groupName].lastTarget = nil
        self.pickups[groupName].lastVehicle = nil
    end

    if self.pickups[groupName].lastVehicle == nil or (driver ~= self.pickups[groupName].lastVehicle or forcedSkip) then
        if groupName ~= "All" then
            if self.pickups[groupName] ~= nil then
                if self.pickups[groupName].lastTarget == nil then
                    self.pickups[groupName].lastTarget = driver.ad.stateModule:getFirstMarker().markerIndex
                else
                    local nextMarkerInGroup = nil
                    local markerSeen = false
                    local firstMarkerInGroup = nil
                    for _, marker in ipairs(ADGraphManager:getMapMarkersInGroup(groupName)) do
                        if marker.group == groupName then
                            if firstMarkerInGroup == nil then
                                firstMarkerInGroup = marker.markerIndex
                            end

                            if markerSeen and nextMarkerInGroup == nil then
                                nextMarkerInGroup = marker.markerIndex
                            end

                            if marker.markerIndex == self.pickups[groupName].lastTarget then
                                markerSeen = true
                            end
                        end
                    end

                    if nextMarkerInGroup ~= nil then
                        target = nextMarkerInGroup
                    elseif firstMarkerInGroup ~= nil then
                        target = firstMarkerInGroup
                    end
                    self.pickups[groupName].lastTarget = target
                    self.pickups[groupName].lastVehicle = driver
                end
                AutoDrive.Hud.lastUIScale = 0
            end
        end
    end

    if self.pickups[groupName].lastVehicle == nil then
        self.pickups[groupName].lastVehicle = driver
        self.pickups[groupName].lastTarget = target
    end
    -- AutoDrive.debugPrint(driver, AutoDrive.DC_PATHINFO, "[AD] ADMultipleTargetsManager:getNextPickup end target %s", tostring(ADGraphManager:getMapMarkerById(target).name))

    return target
end

