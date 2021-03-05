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
    AD_FieldSpeed_up = "input_increaseFieldSpeed",
    AD_FieldSpeed_down = "input_decreaseFieldSpeed",
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
    ADSwapTargets = "input_swapTargets",
    AD_open_notification_history = "input_openNotificationHistory",
    AD_continue = "input_continue",
    ADParkVehicle = "input_parkVehicle",
    AD_devAction = "input_devAction"
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
    input_increaseFieldSpeed = 13,
    input_decreaseFieldSpeed = 14,
    input_nextTarget_Unload = 15,
    input_previousTarget_Unload = 16,
    input_nextFillType = 17,
    input_previousFillType = 18,
    input_continue = 19,
    input_callDriver = 20,
    input_parkVehicle = 21,
    input_swapTargets = 22,
    input_nextTarget = 23,
    input_previousTarget = 24,
    input_startCp = 25,
    input_toggleCP_AIVE = 26
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

function ADInputManager:onInputCall(vehicle, input, sendEvent)
    local func = self[input]
    if type(func) ~= "function" then
        g_logManager:devError("[AutoDrive] Input '%s' = '%s'", input, type(func))
        return
    end

    if sendEvent == nil or sendEvent == true then
        local inputId = self.inputsToIds[input]
        if inputId ~= nil then
            AutoDriveInputEventEvent.sendEvent(vehicle, inputId)
            return
        end
    end

    func(ADInputManager, vehicle)
end

-- Sender only events

function ADInputManager:input_openNotificationHistory(vehicle)
    AutoDrive.onOpenNotificationsHistory()
end

function ADInputManager:input_editMapMarker(vehicle)
    if AutoDrive.isEditorModeEnabled() then
        -- This can be triggered both from 'Edit Target' keyboard shortcut and right click on 'Create Target' hud button
        if ADGraphManager:getWayPointById(1) == nil or vehicle.ad.stateModule:getFirstMarker() == nil then
            return
        end
        AutoDrive.editSelectedMapMarker = true
        AutoDrive.onOpenEnterTargetName()
    end
end

function ADInputManager:input_removeWaypoint(vehicle)
    if AutoDrive.isEditorModeEnabled() then
        local closestWayPoint, _ = vehicle:getClosestWayPoint()
        if ADGraphManager:getWayPointById(closestWayPoint) ~= nil then
            -- This can be triggered both from 'Remove Waypoint' keyboard shortcut and left click on 'Remove Waypoint' hud button
            ADGraphManager:removeWayPoint(closestWayPoint)
        end
    end
end

function ADInputManager:input_removeMapMarker(vehicle)
    if AutoDrive.isEditorModeEnabled() then
        local closestWayPoint, _ = vehicle:getClosestWayPoint()
        if ADGraphManager:getWayPointById(closestWayPoint) ~= nil then
            -- This can be triggered both from 'Remove Target' keyboard shortcut and right click on 'Remove Waypoint' hud button
            ADGraphManager:removeMapMarkerByWayPoint(closestWayPoint)
        end
    end
end

function ADInputManager:input_createMapMarker(vehicle)
    if AutoDrive.isEditorModeEnabled() then
        local closestWayPoint, _ = vehicle:getClosestWayPoint()
        if ADGraphManager:getWayPointById(closestWayPoint) ~= nil then
            -- This can be triggered both from 'Create Target' keyboard shortcut and left click on 'Create Target' hud button
            AutoDrive.editSelectedMapMarker = false
            AutoDrive.onOpenEnterTargetName()
        end
    end
end

function ADInputManager:input_toggleConnection(vehicle)
    if AutoDrive.isEditorModeEnabled() then
        local closestWayPoint, _ = vehicle:getClosestWayPoint()
        if ADGraphManager:getWayPointById(closestWayPoint) ~= nil then
            if vehicle.ad.stateModule:getSelectedNeighbourPoint() ~= nil then
                ADGraphManager:toggleConnectionBetween(ADGraphManager:getWayPointById(closestWayPoint), vehicle.ad.stateModule:getSelectedNeighbourPoint(), false)
            end
        end
    end
end

function ADInputManager:input_toggleConnectionInverted(vehicle)
    if AutoDrive.isEditorModeEnabled() then
        local closestWayPoint, _ = vehicle:getClosestWayPoint()
        if ADGraphManager:getWayPointById(closestWayPoint) ~= nil then
            if vehicle.ad.stateModule:getSelectedNeighbourPoint() ~= nil then
                ADGraphManager:toggleConnectionBetween(vehicle.ad.stateModule:getSelectedNeighbourPoint(), ADGraphManager:getWayPointById(closestWayPoint), false)
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
    if (AutoDrive.experimentalFeatures.enableRoutesManagerOnDediServer == true and g_dedicatedServerInfo ~= nil) or g_dedicatedServerInfo == nil then
        AutoDrive.onOpenRoutesManager()
    end
end

function ADInputManager:input_goToVehicle()
    ADMessagesManager:goToVehicle()
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
    if ADGraphManager:getWayPointById(1) == nil or vehicle.ad.stateModule:getFirstMarker() == nil then
        return
    end
    if vehicle.ad.stateModule:isActive() then
        vehicle.ad.isStoppingWithError = true
        vehicle:stopAutoDrive()
    else
        vehicle.ad.stateModule:getCurrentMode():start()
    end
end

function ADInputManager:input_incLoopCounter(vehicle)
    vehicle.ad.stateModule:increaseLoopCounter()
end

function ADInputManager:input_decLoopCounter(vehicle)
    vehicle.ad.stateModule:decreaseLoopCounter()
end

function ADInputManager:input_setParkDestination(vehicle)
    if vehicle.ad.stateModule:getFirstMarker() ~= nil then
        -- g_logManager:info("[AD] ADInputManager:input_setParkDestination vehicle %s vehicle:getIsSelected() %s", tostring(vehicle), tostring(vehicle:getIsSelected()))

        local SelectedWorkTool = nil
        if vehicle ~= nil and vehicle.getAttachedImplements and #vehicle:getAttachedImplements() > 0 and g_dedicatedServerInfo == nil then
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
        end
        if SelectedWorkTool ~= nil and SelectedWorkTool ~= vehicle and SelectedWorkTool.advd ~= nil and SelectedWorkTool.advd.setWorkToolParkDestination ~= nil then
            if AutoDrive.isInExtendedEditorMode() and AutoDrive.leftCTRLmodifierKeyPressed and not AutoDrive.leftALTmodifierKeyPressed then
                -- assign park destination
                SelectedWorkTool.advd:setWorkToolParkDestination(vehicle.ad.stateModule:getFirstMarkerId())
                AutoDriveMessageEvent.sendMessage(vehicle, ADMessagesManager.messageTypes.INFO, "$l10n_AD_parkVehicle_selected;%s", 5000, vehicle.ad.stateModule:getFirstMarker().name)
            elseif AutoDrive.isInExtendedEditorMode() and not AutoDrive.leftCTRLmodifierKeyPressed and AutoDrive.leftALTmodifierKeyPressed then
                -- delete park destination
                SelectedWorkTool.advd:setWorkToolParkDestination(-1)
                AutoDriveMessageEvent.sendMessage(vehicle, ADMessagesManager.messageTypes.INFO, "$l10n_AD_parkVehicle_deleted;%s", 5000, vehicle.ad.stateModule:getFirstMarker().name)
            end
        else
            if vehicle ~= nil and vehicle.ad ~= nil and vehicle.ad.stateModule ~= nil and vehicle.ad.stateModule.setParkDestination ~= nil then
                if AutoDrive.isInExtendedEditorMode() and AutoDrive.leftCTRLmodifierKeyPressed and not AutoDrive.leftALTmodifierKeyPressed then
                    -- assign park destination
                    vehicle.ad.stateModule:setParkDestination(vehicle.ad.stateModule:getFirstMarkerId())
                    AutoDriveMessageEvent.sendMessage(vehicle, ADMessagesManager.messageTypes.INFO, "$l10n_AD_parkVehicle_selected;%s", 5000, vehicle.ad.stateModule:getFirstMarker().name)
                elseif AutoDrive.isInExtendedEditorMode() and not AutoDrive.leftCTRLmodifierKeyPressed and AutoDrive.leftALTmodifierKeyPressed then
                    -- delete park destination
                    vehicle.ad.stateModule:setParkDestination(-1)
                    AutoDriveMessageEvent.sendMessage(vehicle, ADMessagesManager.messageTypes.INFO, "$l10n_AD_parkVehicle_deleted;%s", 5000, vehicle.ad.stateModule:getFirstMarker().name)
                end
            end
        end
    end
end

function ADInputManager:input_silomode(vehicle)
    vehicle.ad.stateModule:nextMode()
end

function ADInputManager:input_previousMode(vehicle)
    vehicle.ad.stateModule:previousMode()
end

function ADInputManager:input_record(vehicle)
    if not vehicle.ad.stateModule:isInCreationMode() and not vehicle.ad.stateModule:isInDualCreationMode() then
        vehicle.ad.stateModule:startNormalCreationMode()
    else
        vehicle.ad.stateModule:disableCreationMode()
    end
end

function ADInputManager:input_record_dual(vehicle)
    if not vehicle.ad.stateModule:isInCreationMode() and not vehicle.ad.stateModule:isInDualCreationMode() then
        vehicle.ad.stateModule:startDualCreationMode()
    else
        vehicle.ad.stateModule:disableCreationMode()
    end
end

function ADInputManager:input_debug(vehicle)
    AutoDrive.cycleEditMode()
end

function ADInputManager:input_displayMapPoints(vehicle)
    AutoDrive.cycleEditorShowMode()
end

function ADInputManager:input_increaseSpeed(vehicle)
    vehicle.ad.stateModule:increaseSpeedLimit()
end

function ADInputManager:input_decreaseSpeed(vehicle)
    vehicle.ad.stateModule:decreaseSpeedLimit()
end

function ADInputManager:input_increaseFieldSpeed(vehicle)
    vehicle.ad.stateModule:increaseFieldSpeedLimit()
end

function ADInputManager:input_decreaseFieldSpeed(vehicle)
    vehicle.ad.stateModule:decreaseFieldSpeedLimit()
end

function ADInputManager:input_nextTarget(vehicle)
    if ADGraphManager:getMapMarkerById(1) ~= nil and ADGraphManager:getWayPointById(1) ~= nil then
        local currentTarget = vehicle.ad.stateModule:getFirstMarkerId()
        if currentTarget < #ADGraphManager:getMapMarkers() then
            currentTarget = currentTarget + 1
        else
            currentTarget = 1
        end
        vehicle.ad.stateModule:setFirstMarker(currentTarget)
        vehicle.ad.stateModule:removeCPCallback()
    end
end

function ADInputManager:input_previousTarget(vehicle)
    if ADGraphManager:getMapMarkerById(1) ~= nil and ADGraphManager:getWayPointById(1) ~= nil then
        local currentTarget = vehicle.ad.stateModule:getFirstMarkerId()
        if currentTarget > 1 then
            currentTarget = currentTarget - 1
        else
            currentTarget = #ADGraphManager:getMapMarkers()
        end
        vehicle.ad.stateModule:setFirstMarker(currentTarget)
        vehicle.ad.stateModule:removeCPCallback()
    end
end

function ADInputManager:input_nextTarget_Unload(vehicle)
    if ADGraphManager:getMapMarkerById(1) ~= nil and ADGraphManager:getWayPointById(1) ~= nil then
        local currentTarget = vehicle.ad.stateModule:getSecondMarkerId()
        if currentTarget < #ADGraphManager:getMapMarkers() then
            currentTarget = currentTarget + 1
        else
            currentTarget = 1
        end
        vehicle.ad.stateModule:setSecondMarker(currentTarget)
    end
end

function ADInputManager:input_previousTarget_Unload(vehicle)
    if ADGraphManager:getMapMarkerById(1) ~= nil and ADGraphManager:getWayPointById(1) ~= nil then
        local currentTarget = vehicle.ad.stateModule:getSecondMarkerId()
        if currentTarget > 1 then
            currentTarget = currentTarget - 1
        else
            currentTarget = #ADGraphManager:getMapMarkers()
        end
        vehicle.ad.stateModule:setSecondMarker(currentTarget)
    end
end

function ADInputManager:input_nextFillType(vehicle)
    vehicle.ad.stateModule:nextFillType()
end

function ADInputManager:input_previousFillType(vehicle)
    vehicle.ad.stateModule:previousFillType()
end

function ADInputManager:input_continue(vehicle)
    vehicle.ad.stateModule:getCurrentMode():continue()
end

function ADInputManager:input_callDriver(vehicle)
    if vehicle.spec_pipe ~= nil and vehicle.spec_enterable ~= nil then
        ADHarvestManager:assignUnloaderToHarvester(vehicle)
    elseif vehicle.ad.isCombine and vehicle.ad.attachableCombine ~= nil then
        ADHarvestManager:assignUnloaderToHarvester(vehicle.ad.attachableCombine)
    end
end

function ADInputManager:input_parkVehicle(vehicle)
    local actualParkDestination = AutoDrive.getActualParkDestination(vehicle)

    if actualParkDestination >= 1 then
        vehicle.ad.stateModule:setFirstMarker(actualParkDestination)
        vehicle.ad.stateModule:removeCPCallback()
        if vehicle.ad.stateModule:isActive() then
            self:input_start_stop(vehicle) --disable if already active
        end
        vehicle.ad.stateModule:setMode(AutoDrive.MODE_DRIVETO)
        self:input_start_stop(vehicle)
        vehicle.ad.onRouteToPark = true
    else
        vehicle.ad.onRouteToPark = false
        AutoDriveMessageEvent.sendMessage(vehicle, ADMessagesManager.messageTypes.ERROR, "$l10n_AD_parkVehicle_noPosSet;", 5000)
    end
end

function ADInputManager:input_swapTargets(vehicle)
    local currentFirstMarker = vehicle.ad.stateModule:getFirstMarkerId()
    vehicle.ad.stateModule:setFirstMarker(vehicle.ad.stateModule:getSecondMarkerId())
    vehicle.ad.stateModule:setSecondMarker(currentFirstMarker)
    vehicle.ad.stateModule:removeCPCallback()
end

function ADInputManager:input_startCp(vehicle) -- enable / disable CP or AIVE
    if g_courseplay ~= nil or vehicle.acParameters ~= nil then
        vehicle.ad.stateModule:toggleStartCP_AIVE()
    end
end

function ADInputManager:input_toggleCP_AIVE(vehicle) -- select CP or AIVE
    if g_courseplay ~= nil and vehicle.acParameters ~= nil then
        vehicle.ad.stateModule:toggleUseCP_AIVE()
        vehicle.ad.stateModule:setStartCP_AIVE(false) -- disable if changed between CP and AIVE
    end
end

function ADInputManager:input_devAction(vehicle)
    if AutoDrive.devAction ~= nil then
        AutoDrive.devAction(vehicle)
    end
end
