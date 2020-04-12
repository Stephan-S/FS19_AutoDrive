ADMultipleTargetsManager = {}

function ADMultipleTargetsManager:load()
    self.groups = {}
    for groupName, _ in pairs(ADGraphManager:getGroups()) do
        self.groups[groupName] = {}
        self.groups[groupName].lastTarget = nil
        self.groups[groupName].lastVehicle = nil
    end
end

function ADMultipleTargetsManager:getNextTarget(driver, forcedSkip)
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

                    AutoDrive.Hud.lastUIScale = 0
                end
            end
        end
    end

    if self.groups[groupName].lastVehicle == nil then
        self.groups[groupName].lastVehicle = driver
        self.groups[groupName].lastTarget = target
    end

    return target
end