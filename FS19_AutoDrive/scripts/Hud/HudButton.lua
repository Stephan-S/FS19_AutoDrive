ADHudButton = ADInheritsFrom(ADGenericHudElement)

function ADHudButton:new(posX, posY, width, height, primaryAction, secondaryAction, toolTip, state, visible)
    local o = ADHudButton:create()
    o:init(posX, posY, width, height)
    o.primaryAction = primaryAction
    o.secondaryAction = secondaryAction
    o.toolTip = toolTip
    o.state = state
    o.isVisible = visible

    o.layer = 5

    o.images = o:readImages()

    o.ov = Overlay:new(o.images[o.state], o.position.x, o.position.y, o.size.width, o.size.height)

    return o
end

function ADHudButton:readImages()
    local images = {}
    local counter = 1
    while counter <= 19 do
        images[counter] = AutoDrive.directory .. "textures/" .. self.primaryAction .. "_" .. counter .. ".dds"
        counter = counter + 1
    end
    return images
end

function ADHudButton:onDraw(vehicle, uiScale)
    self:updateState(vehicle)
    if self.isVisible then
        self.ov:render()
    end
end

function ADHudButton:updateState(vehicle)
    local newState = self:getNewState(vehicle)
    self.ov:setImage(self.images[newState])
    self.state = newState
end

function ADHudButton:getNewState(vehicle)
    local newState = self.state
    if self.primaryAction == "input_silomode" then
        if vehicle.ad.stateModule:getMode() == AutoDrive.MODE_DELIVERTO then
            newState = 2
        elseif vehicle.ad.stateModule:getMode() == AutoDrive.MODE_PICKUPANDDELIVER then
            newState = 3
        elseif vehicle.ad.stateModule:getMode() == AutoDrive.MODE_UNLOAD then
            newState = 5
        elseif vehicle.ad.stateModule:getMode() == AutoDrive.MODE_LOAD then
            newState = 4
        elseif vehicle.ad.stateModule:getMode() == AutoDrive.MODE_BGA then
            newState = 6
        else
            newState = 1
        end
    end

    if self.primaryAction == "input_record" then
        if vehicle.ad.stateModule:isInCreationMode() then
            newState = 2
            if vehicle.ad.stateModule:isInDualCreationMode() then
                newState = 3
            end
        else
            newState = 1
        end
        self.isVisible = vehicle.ad.stateModule:isEditorModeEnabled()
    end

    if self.primaryAction == "input_start_stop" then
        if vehicle.ad.stateModule:isActive() then
            newState = 2
        else
            newState = 1
        end
    end

    if self.primaryAction == "input_debug" then
        if vehicle.ad.stateModule:isEditorModeEnabled() then
            newState = 2
        else
            newState = 1
        end
    end

    if self.primaryAction == "input_showNeighbor" then
        self.isVisible = vehicle.ad.stateModule:isEditorModeEnabled()

        if vehicle.ad.showSelectedDebugPoint == true then
            newState = 2
        else
            newState = 1
        end
    end

    if self.primaryAction == "input_toggleConnection" then
        self.isVisible = vehicle.ad.stateModule:isEditorModeEnabled()
    end

    if self.primaryAction == "input_nextNeighbor" then
        self.isVisible = vehicle.ad.stateModule:isEditorModeEnabled()
    end

    if self.primaryAction == "input_createMapMarker" then
        self.isVisible = vehicle.ad.stateModule:isEditorModeEnabled()
    end

    if self.primaryAction == "input_routesManager" then
        self.isVisible = vehicle.ad.stateModule:isEditorModeEnabled()
    end

    if self.primaryAction == "input_removeWaypoint" then
        self.isVisible = vehicle.ad.stateModule:isEditorModeEnabled()
    end

    if self.primaryAction == "input_editMapMarker" then
        self.isVisible = vehicle.ad.stateModule:isEditorModeEnabled()
    end

    if self.primaryAction == "input_removeMapMarker" then
        self.isVisible = vehicle.ad.stateModule:isEditorModeEnabled()
    end

    if self.primaryAction == "input_incLoopCounter" then
        newState = math.max(0, vehicle.ad.stateModule:getLoopCounter() - vehicle.ad.modes[AutoDrive.MODE_PICKUPANDDELIVER].loopsDone) + 1
        if vehicle.ad.stateModule:isActive() and vehicle.ad.stateModule:getMode() == AutoDrive.MODE_PICKUPANDDELIVER then
            if newState > 1 then
                newState = newState + 9
            end
        end
    end

    if self.primaryAction == "input_parkVehicle" then

        local hasParkDestination = false
        if vehicle:getIsSelected() then
            hasParkDestination = vehicle.ad.stateModule:hasParkDestination()
        elseif g_dedicatedServerInfo == nil then
            -- TODO: at the moment I found no way to detect if the vehicle or a worktool is selected on dedi server - so deactivate worktool parking on dedi
            if vehicle ~= nil and vehicle.getAttachedImplements and #vehicle:getAttachedImplements() > 0 then

                local SelectedWorkTool = nil
                local allImp = {}
                -- Credits to Tardis from FS17
                local function addAllAttached(obj)
                    for _, imp in pairs(obj:getAttachedImplements()) do
                        addAllAttached(imp.object)
                        table.insert(allImp, imp)
                    end
                end
                    
                addAllAttached(vehicle)

                if allImp ~= nil then
                    for i = 1, #allImp do
                        local imp = allImp[i]
                        if imp ~= nil and imp.object ~= nil and imp.object:getIsSelected() then
                            SelectedWorkTool = imp.object
                            break
                        end
                    end
                end

                if SelectedWorkTool ~= nil and SelectedWorkTool ~= vehicle then
                    if SelectedWorkTool.advd ~= nil and SelectedWorkTool.advd.hasWorkToolParkDestination ~= nil then
                        hasParkDestination = SelectedWorkTool.advd:hasWorkToolParkDestination()
                    end
                end
            end
        end

        if hasParkDestination then
            newState = 1
        else
            newState = 2
        end
    end

    if self.primaryAction == "input_startCp" then
        if (g_courseplay ~= nil or vehicle.acParameters ~= nil) then
            if vehicle.ad.stateModule:getStartCP_AIVE() then
                if vehicle.ad.stateModule:getUseCP_AIVE() then
                    newState = 2
                else
                    newState = 4
                end
            else
                if vehicle.ad.stateModule:getUseCP_AIVE() then
                    newState = 1
                else
                    newState = 3
                end
            end
        end
        self.isVisible = (not vehicle.ad.stateModule:isEditorModeEnabled()) or (AutoDrive.getSetting("wideHUD") and AutoDrive.getSetting("addSettingsToHUD"))
    end

    return newState
end

function ADHudButton:act(vehicle, posX, posY, isDown, isUp, button)
    if self.isVisible then
        vehicle.ad.sToolTip = self.toolTip
        vehicle.ad.nToolTipWait = 5
        vehicle.ad.sToolTipInfo = nil
        vehicle.ad.toolTipIsSetting = false

        if self.primaryAction == "input_parkVehicle" then

            local hasParkDestination = false
            local actualParkDestination = -1

            if vehicle:getIsSelected() then
                hasParkDestination = vehicle.ad.stateModule:hasParkDestination()
                if hasParkDestination then
                    actualParkDestination = vehicle.ad.stateModule:getParkDestination()
                end
            elseif g_dedicatedServerInfo == nil then
                -- TODO: at the moment I found no way to detect if the vehicle or a worktool is selected on dedi server - so deactivate worktool parking on dedi
                if vehicle ~= nil and vehicle.getAttachedImplements and #vehicle:getAttachedImplements() > 0 then

                    local SelectedWorkTool = nil
                    local allImp = {}
                    -- Credits to Tardis from FS17
                    local function addAllAttached(obj)
                        for _, imp in pairs(obj:getAttachedImplements()) do
                            addAllAttached(imp.object)
                            table.insert(allImp, imp)
                        end
                    end
                        
                    addAllAttached(vehicle)

                    if allImp ~= nil then
                        for i = 1, #allImp do
                            local imp = allImp[i]
                            if imp ~= nil and imp.object ~= nil and imp.object:getIsSelected() then
                                SelectedWorkTool = imp.object
                                break
                            end
                        end
                    end

                    if SelectedWorkTool ~= nil and SelectedWorkTool ~= vehicle then
                        if SelectedWorkTool.advd ~= nil and SelectedWorkTool.advd.hasWorkToolParkDestination ~= nil then
                            hasParkDestination = SelectedWorkTool.advd:hasWorkToolParkDestination()
                            if hasParkDestination then
                                actualParkDestination = SelectedWorkTool.advd:getWorkToolParkDestination()
                            end
                        end
                    end
                end
            end

            if hasParkDestination and actualParkDestination >= 1 then
                vehicle.ad.sToolTipInfo = ADGraphManager:getMapMarkerById(actualParkDestination).name
            end

        end
        if button == 1 and isUp then
            ADInputManager:onInputCall(vehicle, self.primaryAction)
            return true
        elseif (button == 3 or button == 2) and isUp then
            ADInputManager:onInputCall(vehicle, self.secondaryAction)
            return true
        end
    end

    return false
end
