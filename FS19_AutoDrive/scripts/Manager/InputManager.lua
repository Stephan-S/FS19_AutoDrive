ADInputManager = {}

ADInputManager.actionsToInputs = {
    ADSilomode = "input_silomode",
    ADRecord = "input_record",
    ADRecord_Dual = "input_record_dual",
    ADEnDisable = "input_start_stop",
    ADSelectTarget = "input_nextTarget",
    ADSelectPreviousTarget = "input_previousTarget",
    ADSelectTargetUnload = "input_nextTarget_Unload",
    ADSelectPreviousTargetUnload = "input_previousTarget_Unload",
    ADActivateDebug = "input_debug",
    ADDebugSelectNeighbor = "input_showNeighbor",
    ADDebugCreateConnection = "input_toggleConnection",
    ADDebugChangeNeighbor = "input_nextNeighbor",
    ADDebugCreateMapMarker = "input_createMapMarker",
    ADRenameMapMarker = "input_editMapMarker",
    ADDebugDeleteDestination = "input_removeMapMarker",
    ADNameDriver = "input_nameDriver",
    AD_Speed_up = "input_increaseSpeed",
    AD_Speed_down = "input_decreaseSpeed",
    ADToggleHud = "input_toggleHud",
    ADToggleMouse = "input_toggleMouse",
    ADDebugDeleteWayPoint = "input_removeWaypoint",
    AD_routes_manager = "input_routesManager",
    ADSelectNextFillType = "input_nextFillType",
    ADSelectPreviousFillType = "input_previousFillType",
    ADOpenGUI = "input_openGUI",
    ADCallDriver = "input_callDriver",
    ADGoToVehicle = "input_goToVehicle",
    ADIncLoopCounter = "input_incLoopCounter",
    ADSwapTargets = "input_swapTargets"
}

ADInputManager.inputsToIds = {
    input_start_stop = 1,
    input_incLoopCounter = 2,
    input_decLoopCounter = 3,
    input_setParkDestination = 4,
    input_silomode = 5,
    input_previousMode = 6,
    input_record = 7,
    input_record_dual = 8,
    input_debug = 9,
    input_displayMapPoints = 10,
    input_increaseSpeed = 11,
    input_decreaseSpeed = 12,
    input_nextTarget_Unload = 13,
    input_previousTarget_Unload = 14,
    input_nextFillType = 15,
    input_previousFillType = 16,
    input_continue = 17,
    input_callDriver = 18,
    input_parkVehicle = 19,
    input_swapTargets = 20,
    input_nextTarget = 21,
    input_previousTarget = 22
}

ADInputManager.idsToInputs = {}

function ADInputManager:load()
    for k, v in pairs(self.inputsToIds) do
        self.idsToInputs[v] = k
    end
end

function ADInputManager.onActionCall(vehicle, actionName)
    local input = ADInputManager.actionsToInputs[actionName]
    if type(input) ~= "string" or input == "" then
        g_logManager:devError("[AutoDrive] Action '%s' = '%s'", actionName, input)
        return
    end

    ADInputManager:onInputCall(vehicle, input)
end

function ADInputManager:onInputCall(vehicle, input)
    local func = self[input]
    if type(func) ~= "function" then
        g_logManager:devError("[AutoDrive] Input '%s' = '%s'", input, func)
        return
    end

    func(ADInputManager, vehicle)
end

-- Sender only events

function ADInputManager:input_editMapMarker(vehicle)
    if vehicle.ad.stateModule:isEditorModeEnabled() then
        -- This can be triggered both from 'Edit Target' keyboard shortcut and right click on 'Create Target' hud button
        if ADGraphManager:getWayPointById(1) == nil or vehicle.ad.stateModule:getFirstMarker() == nil then
            return
        end
        AutoDrive.editSelectedMapMarker = true
        AutoDrive.onOpenEnterTargetName()
    end
end

function ADInputManager:input_removeWaypoint(vehicle)
    if vehicle.ad.stateModule:isEditorModeEnabled() then
        local closestWayPoint, _ = ADGraphManager:findClosestWayPoint(vehicle)
        if ADGraphManager:getWayPointById(closestWayPoint) ~= nil then
            -- This can be triggered both from 'Remove Waypoint' keyboard shortcut and left click on 'Remove Waypoint' hud button
            ADGraphManager:removeWayPoint(closestWayPoint)
        end
    end
end

function ADInputManager:input_removeMapMarker(vehicle)
    if vehicle.ad.stateModule:isEditorModeEnabled() then
        local closestWayPoint, _ = ADGraphManager:findClosestWayPoint(vehicle)
        if ADGraphManager:getWayPointById(closestWayPoint) ~= nil then
            -- This can be triggered both from 'Remove Target' keyboard shortcut and right click on 'Remove Waypoint' hud button
            ADGraphManager:removeMapMarkerByWayPoint(closestWayPoint)
        end
    end
end

function ADInputManager:input_createMapMarker(vehicle)
    if vehicle.ad.stateModule:isEditorModeEnabled() then
        local closestWayPoint, _ = ADGraphManager:findClosestWayPoint(vehicle)
        if ADGraphManager:getWayPointById(closestWayPoint) ~= nil then
            -- This can be triggered both from 'Create Target' keyboard shortcut and left click on 'Create Target' hud button
            AutoDrive.editSelectedMapMarker = false
            AutoDrive.onOpenEnterTargetName()
        end
    end
end

function ADInputManager:input_toggleConnection(vehicle)
    if vehicle.ad.stateModule:isEditorModeEnabled() then
        local closestWayPoint, _ = ADGraphManager:findClosestWayPoint(vehicle)
        if ADGraphManager:getWayPointById(closestWayPoint) ~= nil then
            if vehicle.ad.stateModule:getSelectedNeighbourPoint() ~= nil then
                ADGraphManager:toggleConnectionBetween(ADGraphManager:getWayPointById(closestWayPoint), vehicle.ad.stateModule:getSelectedNeighbourPoint())
            end
        end
    end
end

function ADInputManager:input_toggleConnectionInverted(vehicle)
    if vehicle.ad.stateModule:isEditorModeEnabled() then
        local closestWayPoint, _ = ADGraphManager:findClosestWayPoint(vehicle)
        if ADGraphManager:getWayPointById(closestWayPoint) ~= nil then
            if vehicle.ad.stateModule:getSelectedNeighbourPoint() ~= nil then
                ADGraphManager:toggleConnectionBetween(vehicle.ad.stateModule:getSelectedNeighbourPoint(), ADGraphManager:getWayPointById(closestWayPoint))
            end
        end
    end
end

function ADInputManager:input_nameDriver()
    AutoDrive.onOpenEnterDriverName()
end

function ADInputManager:input_setDestinationFilter()
    AutoDrive.onOpenEnterDestinationFilter()
end

function ADInputManager:input_openGUI()
    AutoDrive.onOpenSettings()
end

function ADInputManager:input_toggleHud(vehicle)
    AutoDrive.Hud:toggleHud(vehicle)
end

function ADInputManager:input_toggleMouse()
    g_inputBinding:setShowMouseCursor(not g_inputBinding:getShowMouseCursor())
end

function ADInputManager:input_routesManager()
    AutoDrive.onOpenRoutesManager()
end

function ADInputManager:input_goToVehicle()
    if MessagesManager.lastNotificationVehicle ~= nil then
        g_currentMission:requestToEnterVehicle(MessagesManager.lastNotificationVehicle)
    end
end

function ADInputManager:input_showNeighbor(vehicle)
    vehicle.ad.stateModule:togglePointToNeighbor()
end

function ADInputManager:input_nextNeighbor(vehicle)
    vehicle.ad.stateModule:changeNeighborPoint(1)
end

function ADInputManager:input_previousNeighbor(vehicle)
    vehicle.ad.stateModule:changeNeighborPoint(-1)
end

-- Sender and server events

function ADInputManager:input_start_stop(vehicle)
    if g_server ~= nil then
        if ADGraphManager:getWayPointById(1) == nil or vehicle.ad.stateModule:getFirstMarker() == nil then
            return
        end
        if vehicle.ad.stateModule:isActive() then
            vehicle.ad.isStoppingWithError = true
            AutoDrive.disableAutoDriveFunctions(vehicle)
        else
            vehicle.ad.stateModule:getCurrentMode():start()
        end
    end
end

function ADInputManager:input_incLoopCounter(vehicle)
    if g_server ~= nil then
        vehicle.ad.stateModule:increaseLoopCounter()
    end
end

function ADInputManager:input_decLoopCounter(vehicle)
    if g_server ~= nil then
        vehicle.ad.stateModule:decreaseLoopCounter()
    end
end

function ADInputManager:input_setParkDestination(vehicle)
    if g_server ~= nil then
        if vehicle.ad.stateModule:getFirstMarker() ~= nil then
            vehicle.ad.parkDestination = vehicle.ad.stateModule:getFirstMarkerId()
            AutoDriveMessageEvent.sendMessage(vehicle, MessagesManager.messageTypes.INFO, "$l10n_AD_parkVehicle_selected;%s", 5000, vehicle.ad.stateModule:getFirstMarker().name)
        end
    end
end

function ADInputManager:input_silomode(vehicle)
    if g_server ~= nil then
        vehicle.ad.stateModule:nextMode()
    end
end

function ADInputManager:input_previousMode(vehicle)
    if g_server ~= nil then
        vehicle.ad.stateModule:previousMode()
    end
end

function ADInputManager:input_record(vehicle)
    if g_server ~= nil then
        if not vehicle.ad.stateModule:isEditorModeEnabled() then
            return
        end
        AutoDrive:inputRecord(vehicle, false)
    end
end

function ADInputManager:input_record_dual(vehicle)
    if g_server ~= nil then
        if not vehicle.ad.stateModule:isEditorModeEnabled() then
            return
        end
        AutoDrive:inputRecord(vehicle, true)
    end
end

function ADInputManager:input_debug(vehicle)
    if g_server ~= nil then
        vehicle.ad.stateModule:cycleEditMode()
    end
end

function ADInputManager:input_displayMapPoints(vehicle)
    if g_server ~= nil then
        vehicle.ad.stateModule:cycleEditorShowMode()
    end
end

function ADInputManager:input_increaseSpeed(vehicle)
    if g_server ~= nil then
        vehicle.ad.stateModule:increaseSpeedLimit()
    end
end

function ADInputManager:input_decreaseSpeed(vehicle)
    if g_server ~= nil then
        vehicle.ad.stateModule:decreaseSpeedLimit()
    end
end

function ADInputManager:input_decreaseSpeed(vehicle)
    if g_server ~= nil then
        vehicle.ad.stateModule:decreaseSpeedLimit()
    end
end

function ADInputManager:input_nextTarget(vehicle)
    if g_server ~= nil then
        if ADGraphManager:getMapMarkerById(1) ~= nil and ADGraphManager:getWayPointById(1) ~= nil then
            local destinations = AutoDrive:getSortedDestinations()
            local currentIndex = AutoDrive:getElementWithIdInList(destinations, vehicle.ad.stateModule:getFirstMarkerId())

            local nextDestination = next(destinations, currentIndex)
            if nextDestination == nil then
                nextDestination = next(destinations, nil)
            end

            vehicle.ad.stateModule:setFirstMarker(destinations[nextDestination].id)
        end
    end
end

function ADInputManager:input_previousTarget(vehicle)
    if g_server ~= nil then
        if ADGraphManager:getMapMarkerById(1) ~= nil and ADGraphManager:getWayPointById(1) ~= nil then
            local destinations = AutoDrive:getSortedDestinations()
            local currentIndex = AutoDrive:getElementWithIdInList(destinations, vehicle.ad.stateModule:getFirstMarkerId())

            local previousIndex = 1
            if currentIndex > 1 then
                previousIndex = currentIndex - 1
            else
                previousIndex = #destinations
            end

            vehicle.ad.stateModule:setFirstMarker(destinations[previousIndex].id)
        end
    end
end

function ADInputManager:input_nextTarget_Unload(vehicle)
    if g_server ~= nil then
        if ADGraphManager:getMapMarkerById(1) ~= nil and ADGraphManager:getWayPointById(1) ~= nil then
            local destinations = AutoDrive:getSortedDestinations()
            local currentIndex = AutoDrive:getElementWithIdInList(destinations, vehicle.ad.stateModule:getSecondMarkerId())

            local nextDestination = next(destinations, currentIndex)
            if nextDestination == nil then
                nextDestination = next(destinations, nil)
            end

            vehicle.ad.stateModule:setSecondMarker(destinations[nextDestination].id)
        end
    end
end

function ADInputManager:input_previousTarget_Unload(vehicle)
    if g_server ~= nil then
        if ADGraphManager:getMapMarkerById(1) ~= nil and ADGraphManager:getWayPointById(1) ~= nil then
            local destinations = AutoDrive:getSortedDestinations()
            local currentIndex = AutoDrive:getElementWithIdInList(destinations, vehicle.ad.stateModule:getSecondMarkerId())

            local previousIndex = 1
            if currentIndex > 1 then
                previousIndex = currentIndex - 1
            else
                previousIndex = #destinations
            end

            vehicle.ad.stateModule:setSecondMarker(destinations[previousIndex].id)
        end
    end
end

function ADInputManager:input_nextFillType(vehicle)
    if g_server ~= nil then
        vehicle.ad.stateModule:nextFillType()
    end
end

function ADInputManager:input_previousFillType(vehicle)
    if g_server ~= nil then
        vehicle.ad.stateModule:previousFillType()
    end
end

function ADInputManager:input_continue(vehicle)
    if g_server ~= nil then
        vehicle.ad.stateModule:getCurrentMode():continue()
    end
end

function ADInputManager:input_callDriver(vehicle)
    if g_server ~= nil then
        -- TODO: should we also/only check if the current "vehicle" is registered in the HarvestManager ?
        if vehicle.spec_pipe ~= nil and vehicle.spec_enterable ~= nil then
            AutoDrive:callDriverToCombine(vehicle)
        end
    end
end

function ADInputManager:input_parkVehicle(vehicle)
    if g_server ~= nil then
        if vehicle.ad.parkDestination ~= nil and vehicle.ad.parkDestination >= 1 and ADGraphManager:getMapMarkerById(vehicle.ad.parkDestination) ~= nil then
            vehicle.ad.stateModule:setFirstMarker(vehicle.ad.parkDestination)
            if vehicle.ad.stateModule:isActive() then
                self:input_start_stop(vehicle) --disable if already active
            end
            vehicle.ad.stateModule:setMode(AutoDrive.MODE_DRIVETO)
            self:input_start_stop(vehicle)
            vehicle.ad.onRouteToPark = true
        else
            AutoDriveMessageEvent.sendMessage(vehicle, MessagesManager.messageTypes.ERROR, "$l10n_AD_parkVehicle_noPosSet;", 3000)
        end
    end
end

function ADInputManager:input_swapTargets(vehicle)
    if g_server ~= nil then
        vehicle.ad.stateModule:setFirstMarker(vehicle.ad.stateModule:getSecondMarkerId())
        vehicle.ad.stateModule:setSecondMarker(vehicle.ad.stateModule:getFirstMarkerId())
    end
end

-- TODO: move functions below to a proper file

function AutoDrive:inputRecord(vehicle, dual)
    if not vehicle.ad.stateModule:isInCreationMode() then
        if dual then
            --print("AutoDrive:inputRecord - start recording dual")
            vehicle.ad.stateModule:startDualCreationMode()
        else
            --print("AutoDrive:inputRecord - start recording normal")
            vehicle.ad.stateModule:startNormalCreationMode()
        end
        AutoDrive.disableAutoDriveFunctions(vehicle)
    else
        --print("AutoDrive:inputRecord - disable recording")
        vehicle.ad.stateModule:disableCreationMode()

        if AutoDrive.getSetting("autoConnectEnd") then
            if vehicle.ad.lastCreatedWp ~= nil then
                local targetID = ADGraphManager:findMatchingWayPointForVehicle(vehicle)
                if targetID ~= nil then
                    local targetNode = ADGraphManager:getWayPointById(targetID)
                    if targetNode ~= nil then
                        targetNode.incoming[#targetNode.incoming + 1] = vehicle.ad.lastCreatedWp.id
                        vehicle.ad.lastCreatedWp.out[#vehicle.ad.lastCreatedWp.out + 1] = targetNode.id
                        if dual == true then
                            targetNode.out[#targetNode.out + 1] = vehicle.ad.lastCreatedWp.id
                            vehicle.ad.lastCreatedWp.incoming[#vehicle.ad.lastCreatedWp.incoming + 1] = targetNode.id
                        end

                        AutoDriveCourseEditEvent:sendEvent(targetNode)
                    end
                end
            end
        end

        vehicle.ad.lastCreatedWp = nil
        vehicle.ad.secondLastCreatedWp = nil
    end
end

function AutoDrive:getElementWithIdInList(destinations, id)
    local currentIndex = 1
    for index, destination in ipairs(destinations) do
        if destination.id == id then
            currentIndex = index
        end
    end
    return currentIndex
end

function AutoDrive:getSortedDestinations()
    local destinations = AutoDrive:createCopyOfDestinations()

    local sort_func = function(a, b)
        a = tostring(a.name):lower()
        b = tostring(b.name):lower()
        local patt = "^(.-)%s*(%d+)$"
        local _, _, col1, num1 = a:find(patt)
        local _, _, col2, num2 = b:find(patt)
        if (col1 and col2) and col1 == col2 then
            return tonumber(num1) < tonumber(num2)
        end
        return a < b
    end

    table.sort(destinations, sort_func)

    return destinations
end

function AutoDrive:createCopyOfDestinations()
    local destinations = {}

    for destinationIndex, destination in pairs(ADGraphManager:getMapMarker()) do
        table.insert(destinations, {id = destinationIndex, name = destination.name})
    end

    return destinations
end
