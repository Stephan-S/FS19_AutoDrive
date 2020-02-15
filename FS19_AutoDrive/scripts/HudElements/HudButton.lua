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
        if vehicle.ad.mode == AutoDrive.MODE_DELIVERTO then
            newState = 2
        elseif vehicle.ad.mode == AutoDrive.MODE_PICKUPANDDELIVER then
            newState = 3
        elseif vehicle.ad.mode == AutoDrive.MODE_UNLOAD then
            newState = 5
        elseif vehicle.ad.mode == AutoDrive.MODE_LOAD then
            newState = 4
        elseif vehicle.ad.mode == AutoDrive.MODE_BGA then
            newState = 6
        else
            newState = 1
        end
    end

    if self.primaryAction == "input_record" then
        if vehicle.ad.creationMode == true then
            newState = 2
            if vehicle.ad.creationModeDual == true then
                newState = 3
            end
        else
            newState = 1
        end
        if vehicle.ad.createMapPoints == true then
            self.isVisible = true
        else
            self.isVisible = false
        end
    end

    if self.primaryAction == "input_start_stop" then
        if vehicle.ad.isActive == true then
            newState = 2
        else
            newState = 1
        end
    end

    if self.primaryAction == "input_debug" then
        if vehicle.ad.createMapPoints == true then
            newState = 2
        else
            newState = 1
        end
    end

    if self.primaryAction == "input_showNeighbor" then
        if vehicle.ad.createMapPoints == true then
            self.isVisible = true
        else
            self.isVisible = false
        end

        if vehicle.ad.showSelectedDebugPoint == true then
            newState = 2
        else
            newState = 1
        end
    end

    if self.primaryAction == "input_toggleConnection" then
        if vehicle.ad.createMapPoints == true then
            self.isVisible = true
        else
            self.isVisible = false
        end
    end

    if self.primaryAction == "input_nextNeighbor" then
        if vehicle.ad.createMapPoints == true then
            self.isVisible = true
        else
            self.isVisible = false
        end
    end

    if self.primaryAction == "input_createMapMarker" then
        if vehicle.ad.createMapPoints == true then
            self.isVisible = true
        else
            self.isVisible = false
        end
    end

    if self.primaryAction == "input_exportRoutes" then
        if vehicle.ad.createMapPoints == true then
            self.isVisible = true
        else
            self.isVisible = false
        end
    end

    if self.primaryAction == "input_removeWaypoint" then
        if vehicle.ad.createMapPoints == true then
            self.isVisible = true
        else
            self.isVisible = false
        end
    end

    if self.primaryAction == "input_incLoopCounter" then
        newState = math.max(0, vehicle.ad.loopCounterSelected - vehicle.ad.loopCounterCurrent) + 1
        if vehicle.ad.isActive and vehicle.ad.mode == AutoDrive.MODE_PICKUPANDDELIVER then
            if newState > 1 then
                newState = newState + 9
            end
        end
    end

    if self.primaryAction == "input_parkVehicle" then
        if vehicle.ad.parkDestination == nil or vehicle.ad.parkDestination <= 1 then
            newState = 2
        else
            newState = 1
        end
    end

    return newState
end

function ADHudButton:act(vehicle, posX, posY, isDown, isUp, button)
    if self.isVisible then
        vehicle.ad.sToolTip = self.toolTip
        vehicle.ad.nToolTipWait = 5

        if button == 1 and isUp then
            AutoDrive:InputHandling(vehicle, self.primaryAction)
            AutoDrive:InputHandlingSenderOnly(vehicle, self.primaryAction)
            return true
        elseif (button == 3 or button == 2) and isUp then
            AutoDrive:InputHandling(vehicle, self.secondaryAction)
            AutoDrive:InputHandlingSenderOnly(vehicle, self.secondaryAction)
            return true
        end
    end

    return false
end
