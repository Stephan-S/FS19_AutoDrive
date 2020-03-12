function AutoDrive:onActionCall(actionName, keyStatus, arg4, arg5, arg6)
	--g_logManager:devInfo("AutoDrive onActionCall " .. actionName);

	if actionName == "ADSilomode" then
		--g_logManager:devInfo("sending event to InputHandling");
		AutoDrive:InputHandling(self, "input_silomode")
	end
	if actionName == "ADRecord" then
		AutoDrive:InputHandling(self, "input_record")
	end

	if actionName == "ADRecord_Dual" then
		AutoDrive:InputHandling(self, "input_record_dual")
	end

	if actionName == "ADEnDisable" then
		AutoDrive:InputHandling(self, "input_start_stop")
	end

	if actionName == "ADSelectTarget" then
		AutoDrive:InputHandling(self, "input_nextTarget")
	end

	if actionName == "ADSelectPreviousTarget" then
		AutoDrive:InputHandling(self, "input_previousTarget")
	end

	if actionName == "ADSelectTargetUnload" then
		AutoDrive:InputHandling(self, "input_nextTarget_Unload")
	end

	if actionName == "ADSelectPreviousTargetUnload" then
		AutoDrive:InputHandling(self, "input_previousTarget_Unload")
	end

	if actionName == "ADSelectTargetMouseWheel" and g_inputBinding:getShowMouseCursor() then
		AutoDrive:InputHandling(self, "input_nextTarget")
	end

	if actionName == "ADSelectPreviousTargetMouseWheel" and g_inputBinding:getShowMouseCursor() then
		AutoDrive:InputHandling(self, "input_previousTarget")
	end

	if actionName == "ADActivateDebug" then
		AutoDrive:InputHandling(self, "input_debug")
	end
	if actionName == "ADDebugSelectNeighbor" then
		AutoDrive:InputHandling(self, "input_showNeighbor")
	end
	if actionName == "ADDebugCreateConnection" then
		AutoDrive.InputHandlingSenderOnly(self, "input_toggleConnection")
	end
	if actionName == "ADDebugChangeNeighbor" then
		AutoDrive:InputHandling(self, "input_nextNeighbor")
	end
	if actionName == "ADDebugCreateMapMarker" then
		AutoDrive.InputHandlingSenderOnly(self, "input_createMapMarker")
	end
	if actionName == "ADRenameMapMarker" then
		AutoDrive.InputHandlingSenderOnly(self, "input_editMapMarker")
	end
	if actionName == "ADDebugDeleteDestination" then
		AutoDrive.InputHandlingSenderOnly(self, "input_removeMapMarker")
	end
	if actionName == "ADNameDriver" then
		AutoDrive.InputHandlingSenderOnly(self, "input_nameDriver")
	end
	if actionName == "AD_Speed_up" then
		AutoDrive:InputHandling(self, "input_increaseSpeed")
	end

	if actionName == "AD_Speed_down" then
		AutoDrive:InputHandling(self, "input_decreaseSpeed")
	end

	if actionName == "ADToggleHud" then
		AutoDrive.InputHandlingSenderOnly(self, "input_toggleHud")
	end

	if actionName == "ADToggleMouse" then
		AutoDrive.InputHandlingSenderOnly(self, "input_toggleMouse")
	end

	if actionName == "ADDebugDeleteWayPoint" then
		AutoDrive.InputHandlingSenderOnly(self, "input_removeWaypoint")
	end
	if actionName == "AD_routes_manager" then
		AutoDrive.InputHandlingSenderOnly(self, "input_routesManager")
	end
	if actionName == "ADSelectNextFillType" then
		AutoDrive:InputHandling(self, "input_nextFillType")
	end
	if actionName == "ADSelectPreviousFillType" then
		AutoDrive:InputHandling(self, "input_previousFillType")
	end
	if actionName == "ADOpenGUI" then
		AutoDrive.InputHandlingSenderOnly(self, "input_openGUI")
	end
	if actionName == "ADCallDriver" then
		AutoDrive:InputHandling(self, "input_callDriver")
	end
	if actionName == "ADGoToVehicle" then
		AutoDrive.InputHandlingSenderOnly(self, "input_goToVehicle")
	end
	if actionName == "ADIncLoopCounter" then
		AutoDrive:InputHandling(self, "input_incLoopCounter")
	end
	if actionName == "ADSwapTargets" then
		AutoDrive:InputHandling(self, "input_swapTargets")
	end
end

function AutoDrive:InputHandling(vehicle, input)
	--g_logManager:devInfo("AutoDrive InputHandling.." .. input);
	vehicle.ad.currentInput = input
	if vehicle.ad.currentInput == nil then
		return
	end

	AutoDrive:InputHandlingClientAndServer(vehicle, input)

	if g_server == nil then
		if vehicle.ad.currentInput ~= nil then
			AutoDriveUpdateEvent:sendEvent(vehicle)
		end
		return
	end

	-- Why is this called 'ServerOnly' if it's called even on clients?
	AutoDrive:InputHandlingServerOnly(vehicle, input)

	vehicle.ad.currentInput = ""
end

-- This new kind of handling should prevent unwanted behaviours such as GUI shown on player who hosts the game on non-dedicated games
-- Now the MP sync is delegated to dedicated events
function AutoDrive.InputHandlingSenderOnly(vehicle, input)
	if vehicle ~= nil and vehicle.ad ~= nil then
		if vehicle.ad.stateModule:isEditorModeEnabled() then
			local closestWayPoint, _ = ADGraphManager:findClosestWayPoint(vehicle)

			-- This can be triggered both from 'Edit Target' keyboard shortcut and right click on 'Create Target' hud button
			if input == "input_editMapMarker" then
				if ADGraphManager:getWayPointById(1) == nil or vehicle.ad.stateModule:getFirstMarker() == nil then
					return
				end
				AutoDrive.editSelectedMapMarker = true
				AutoDrive.onOpenEnterTargetName()
			end

			if ADGraphManager:getWayPointById(closestWayPoint) ~= nil then
				-- This can be triggered both from 'Remove Waypoint' keyboard shortcut and left click on 'Remove Waypoint' hud button
				if input == "input_removeWaypoint" then
					ADGraphManager:removeWayPoint(closestWayPoint)
				end

				-- This can be triggered both from 'Remove Target' keyboard shortcut and right click on 'Remove Waypoint' hud button
				if input == "input_removeMapMarker" then
					ADGraphManager:removeMapMarkerByWayPoint(closestWayPoint)
				end

				-- This can be triggered both from 'Create Target' keyboard shortcut and left click on 'Create Target' hud button
				if input == "input_createMapMarker" then
					AutoDrive.editSelectedMapMarker = false
					AutoDrive.onOpenEnterTargetName()
				end

				if vehicle.ad.stateModule:getSelectedNeighbourPoint() ~= nil then
					if input == "input_toggleConnection" then
						ADGraphManager:toggleConnectionBetween(ADGraphManager:getWayPointById(closestWayPoint), vehicle.ad.stateModule:getSelectedNeighbourPoint())
					end

					if input == "input_toggleConnectionInverted" then
						ADGraphManager:toggleConnectionBetween(vehicle.ad.stateModule:getSelectedNeighbourPoint(), ADGraphManager:getWayPointById(closestWayPoint))
					end
				end
			end
		end

		if input == "input_nameDriver" then
			AutoDrive.onOpenEnterDriverName()
		end

		if input == "input_setDestinationFilter" then
			AutoDrive.onOpenEnterDestinationFilter()
		end

		if input == "input_openGUI" and vehicle == g_currentMission.controlledVehicle then
			AutoDrive.onOpenSettings()
		end

		if input == "input_toggleHud" and vehicle == g_currentMission.controlledVehicle then
			AutoDrive.Hud:toggleHud(vehicle)
		end

		if input == "input_toggleMouse" and vehicle == g_currentMission.controlledVehicle then
			g_inputBinding:setShowMouseCursor(not g_inputBinding:getShowMouseCursor())
		end

		if input == "input_routesManager" then
			AutoDrive.onOpenRoutesManager()
		end

		if input == "input_goToVehicle" then
			if MessagesManager.lastNotificationVehicle ~= nil then
				g_currentMission:requestToEnterVehicle(MessagesManager.lastNotificationVehicle)
			end
		end
	end
end

function AutoDrive:InputHandlingClientAndServer(vehicle, input)
	if input == "input_start_stop" then
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

	if input == "input_incLoopCounter" then
		vehicle.ad.stateModule:increaseLoopCounter()
	end

	if input == "input_decLoopCounter" then
		vehicle.ad.stateModule:decreaseLoopCounter()
	end

	if input == "input_setParkDestination" then
		if vehicle.ad.stateModule:getFirstMarker() ~= nil then
			vehicle.ad.parkDestination = vehicle.ad.stateModule:getFirstMarkerId()
			if g_server ~= nil then
				AutoDriveMessageEvent.sendMessage(vehicle, MessagesManager.messageTypes.INFO, "$l10n_AD_parkVehicle_selected;%s", 5000, vehicle.ad.stateModule:getFirstMarker().name)
			end
		end
	end
end

function AutoDrive:InputHandlingServerOnly(vehicle, input)
	if input == "input_silomode" then
		vehicle.ad.stateModule:nextMode()
	end

	if input == "input_previousMode" then
		vehicle.ad.stateModule:previousMode()
	end

	if input == "input_record" then
		if not vehicle.ad.stateModule:isEditorModeEnabled() or AutoDrive.requestedWaypoints == true then
			return
		end
		AutoDrive:inputRecord(vehicle, false)
	end

	if input == "input_record_dual" then
		if not vehicle.ad.stateModule:isEditorModeEnabled() or AutoDrive.requestedWaypoints == true then
			return
		end
		AutoDrive:inputRecord(vehicle, true)
	end

	if input == "input_nextTarget" then
		AutoDrive:inputNextTarget(vehicle)
	end

	if input == "input_previousTarget" then
		AutoDrive:inputPreviousTarget(vehicle)
	end

	if input == "input_debug" then
		vehicle.ad.stateModule:cycleEditMode()
	end

	if input == "input_displayMapPoints" then
		vehicle.ad.stateModule:cycleEditorShowMode()
	end

	if input == "input_showNeighbor" then
		AutoDrive:inputShowNeighbors(vehicle)
	end

	if input == "input_nextNeighbor" then
		if AutoDrive.requestedWaypoints == true then
			return
		end
		AutoDrive:nextSelectedDebugPoint(vehicle, 1)
	end

	if input == "input_previousNeighbor" then
		if AutoDrive.requestedWaypoints == true then
			return
		end
		AutoDrive:nextSelectedDebugPoint(vehicle, -1)
	end

	if input == "input_increaseSpeed" then
		vehicle.ad.stateModule:increaseSpeedLimit()
	end

	if input == "input_decreaseSpeed" then
		vehicle.ad.stateModule:decreaseSpeedLimit()
	end

	if input == "input_nextTarget_Unload" then
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

	if input == "input_previousTarget_Unload" then
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

	if input == "input_nextFillType" then
		vehicle.ad.stateModule:nextFillType()
	end

	if input == "input_previousFillType" then
		vehicle.ad.stateModule:previousFillType()
	end

	if input == "input_continue" then
		vehicle.ad.stateModule:getCurrentMode():continue()
	end

	if input == "input_callDriver" then
		if vehicle.spec_pipe ~= nil and vehicle.spec_enterable ~= nil then
			--if vehicle.typeName == "combineDrivable" or vehicle.typeName == "combineCutterFruitPreparer" or vehicle.typeName == "pdlc_claasPack.combineDrivableCrawlers" then
			AutoDrive:callDriverToCombine(vehicle)
		end
	end

	if input == "input_parkVehicle" then
		if vehicle.ad.parkDestination ~= nil and vehicle.ad.parkDestination >= 1 and ADGraphManager:getMapMarkerById(vehicle.ad.parkDestination) ~= nil then
			vehicle.ad.stateModule:setFirstMarker(vehicle.ad.parkDestination)
			if vehicle.ad.stateModule:isActive() then
				AutoDrive:InputHandling(vehicle, "input_start_stop") --disable if already active
			end
			vehicle.ad.stateModule:setMode(AutoDrive.DRIVE_TO)
			AutoDrive:InputHandling(vehicle, "input_start_stop")
			vehicle.ad.onRouteToPark = true
		else
			AutoDriveMessageEvent.sendMessage(vehicle, MessagesManager.messageTypes.ERROR, "$l10n_AD_parkVehicle_noPosSet;", 3000)
		end
	end

	if input == "input_swapTargets" then
		AutoDrive:inputSwapTargets(vehicle)
	end
end

function AutoDrive:inputRecord(vehicle, dual)
	if not vehicle.ad.stateModule:isInCreationMode() then
		vehicle.ad.stateModule:startNormalCreationMode()
		AutoDrive.disableAutoDriveFunctions(vehicle)
	else
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

function AutoDrive:inputNextTarget(vehicle)
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

function AutoDrive:inputPreviousTarget(vehicle)
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

function AutoDrive:nextSelectedDebugPoint(vehicle, increase)
	vehicle.ad.stateModule:changeNeighborPoint(increase)
end

function AutoDrive:inputShowNeighbors(vehicle)
	vehicle.ad.stateModule:togglePointToNeighbor()
end

function AutoDrive:inputSwapTargets(vehicle)
	local currentFirstMarkerId = vehicle.ad.stateModule:getFirstMarkerId()
	vehicle.ad.stateModule:setFirstMarker(vehicle.ad.stateModule:getSecondMarkerId())	
	vehicle.ad.stateModule:setSecondMarker(currentFirstMarkerId)
end
