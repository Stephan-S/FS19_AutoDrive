InputManager = {}

InputManager.actionToInput = {
    ADSilomode = "input_silomode",
    ADRecord = "input_record",
    ADRecord_Dual = "input_record_dual",
    ADEnDisable = "input_start_stop",
    ADSelectTarget = "input_silomode",
    ADSelectPreviousTarget = "input_previousTarget",
    ADSelectTargetUnload = "input_nextTarget_Unload",
    ADSelectPreviousTargetUnload = "input_previousTarget_Unload",
    ADSelectTargetMouseWheel = "input_nextTarget",
    ADSelectPreviousTargetMouseWheel = "input_previousTarget",
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

function InputManager.onActionCall(vehicle, actionName)
    local input = InputManager.actionToInput[actionName]
    if type(input) ~= "string" or input == "" then
        g_logManager:devError("[AutoDrive] Action '%s' = '%s'", actionName, input)
        return
    end

    if actionName == "ADSelectTargetMouseWheel" or actionName == "ADSelectPreviousTargetMouseWheel" then
        if g_inputBinding:getShowMouseCursor() then
            InputManager:onInputCall(vehicle, input)
        end
        return
    end

    InputManager:onInputCall(vehicle, input)
end

function InputManager:onInputCall(vehicle, input)
    local func = self[input]
    if type(func) ~= "function" then
        g_logManager:devError("[AutoDrive] Input '%s' = '%s'", input, func)
        return
    end

    func(InputManager, vehicle)
end

function InputManager:input_debug(vehicle)
    if g_server ~= nil then
        vehicle.ad.stateModule:cycleEditMode()
    end
end
