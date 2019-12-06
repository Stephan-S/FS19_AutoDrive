AutoDriveHud = {}
AutoDrive.FONT_SCALE = 0.0115
AutoDrive.PULLDOWN_ITEM_COUNT = 20
AutoDrive.ItemFilterList = {
	34, --Air
	--11, -- Cotton --can be transported with trailers apparently
	77,
	78,
	79,
	80, --Chicken
	61,
	62,
	63,
	64,
	65,
	66,
	67,
	68, -- Cows
	14, --Eggs
	--28, --29, --multiple grass
	53,
	54,
	55,
	56,
	57,
	58,
	59,
	60, --Horses
	25, --Oilseed Radish
	73,
	74,
	75,
	76, --Pigs
	35,
	36,
	37,
	38,
	39, --Round bale
	69,
	70,
	71,
	72, --Sheep
	40,
	41,
	42, --Square bale
	49, --Tarp?
	22, --Tree sapling
	1, --Unknown
	52, --weed
	15 --wool
}

function AutoDriveHud:new()
	local o = {}
	setmetatable(o, self)
	self.__index = self
	return o
end

function AutoDriveHud:loadHud()
	if AutoDrive.HudX == nil or AutoDrive.HudY == nil then
		local uiScale = g_gameSettings:getValue("uiScale")
		if AutoDrive.getSetting("guiScale") ~= 0 then
			uiScale = AutoDrive.getSetting("guiScale")
		end
		local numButtons = 7
		local numButtonRows = 2
		local buttonSize = 32
		local iconSize = 32
		local gapSize = 3

		self.width, self.height = getNormalizedScreenValues((numButtons * (gapSize + buttonSize) + gapSize) * uiScale, ((numButtonRows * (gapSize + buttonSize)) + (3 * (gapSize + iconSize)) + 30) * uiScale)
		self.gapWidth, self.gapHeight = getNormalizedScreenValues(uiScale * gapSize, uiScale * gapSize)
		self.posX = 1 - self.width - self.gapWidth
		self.posY = 0.285926
		AutoDrive.HudX = self.posX
		AutoDrive.HudY = self.posY
	else
		self.posX = AutoDrive.HudX
		self.posY = AutoDrive.HudY
	end
	AutoDriveHud:createHudAt(self.posX, self.posY)
	self.isMoving = false
end

function AutoDriveHud:createHudAt(hudX, hudY)
	local uiScale = g_gameSettings:getValue("uiScale")
	if AutoDrive.getSetting("guiScale") ~= 0 then
		uiScale = AutoDrive.getSetting("guiScale")
	end
	local numButtons = 7
	local numButtonRows = 2
	local buttonSize = 32
	local iconSize = 32
	local gapSize = 3
	local listItemSize = 20

	self.headerHeight = 0.016 * uiScale

	self.borderX, self.borderY = getNormalizedScreenValues(uiScale * gapSize, uiScale * gapSize)
	self.buttonWidth, self.buttonHeight = getNormalizedScreenValues(uiScale * buttonSize, uiScale * buttonSize)
	self.width, self.height = getNormalizedScreenValues((numButtons * (gapSize + buttonSize) + gapSize) * uiScale, ((numButtonRows * (gapSize + buttonSize)) + (3 * (gapSize + iconSize)) + gapSize) * uiScale + self.headerHeight)
	self.gapWidth, self.gapHeight = getNormalizedScreenValues(uiScale * gapSize, uiScale * gapSize)
	self.iconWidth, self.iconHeight = getNormalizedScreenValues(uiScale * iconSize, uiScale * iconSize)
	self.listItemWidth, self.listItemHeight = getNormalizedScreenValues(uiScale * listItemSize, uiScale * listItemSize)
	self.posX = hudX
	self.posY = hudY

	AutoDrive.HudX = self.posX
	AutoDrive.HudY = self.posY
	AutoDrive.HudChanged = true

	self.hudElements = {}

	self.Speed = "50"
	self.Target = "Not Ready"
	self.showHud = false
	if AutoDrive.mapMarker[1] ~= nil then
		self.Target = AutoDrive.mapMarker[1].name
	end

	self.Background = {}
	self.Buttons = {}
	self.buttonCounter = 0
	self.rows = 1
	self.rowCurrent = 1
	self.cols = 7
	self.colCurrent = 1

	self.row2 = self.posY + 3 * self.borderY + 2 * self.buttonHeight
	self.row3 = self.posY + 4 * self.borderY + 3 * self.buttonHeight
	self.row4 = self.posY + 5 * self.borderY + 4 * self.buttonHeight
	self.rowHeader = self.posY + 6 * self.borderY + 5 * self.buttonHeight

	table.insert(self.hudElements, ADHudIcon:new(self.posX, self.posY - 2 * self.gapHeight, self.width, self.height + 5 * self.gapHeight, AutoDrive.directory .. "textures/Background.dds", 0, "background"))

	table.insert(self.hudElements, ADHudIcon:new(self.posX, self.rowHeader, self.width, self.headerHeight, AutoDrive.directory .. "textures/Header.dds", 1, "header"))

	local closeHeight = self.headerHeight --0.0177 * uiScale;
	local closeWidth = closeHeight * (g_screenHeight / g_screenWidth)
	local posX = self.posX + self.width - (closeWidth * 1.1)
	local posY = self.rowHeader
	table.insert(self.hudElements, ADHudButton:new(posX, posY, closeWidth, closeHeight, "input_toggleHud", nil, "", 1, true))

	table.insert(self.hudElements, ADHudIcon:new(self.posX, self.row4, self.iconWidth, self.iconHeight, AutoDrive.directory .. "textures/destination.dds", 1, "destinationOverlay"))

	self.targetPullDownList = ADPullDownList:new(self.posX + 2 * self.gapWidth + self.buttonWidth, self.row4, self.iconWidth * 6 + self.gapWidth * 5, self.listItemHeight, ADPullDownList.TYPE_TARGET, 1)
	table.insert(self.hudElements, self.targetPullDownList)

	table.insert(self.hudElements, ADHudIcon:new(self.posX + self.gapWidth, self.row3, self.iconWidth, self.iconHeight, AutoDrive.directory .. "textures/tipper_overlay.dds", 1, "unloadOverlay"))

	table.insert(self.hudElements, ADPullDownList:new(self.posX + 2 * self.gapWidth + self.buttonWidth, self.row3, self.iconWidth * 6 + self.gapWidth * 5, self.listItemHeight, ADPullDownList.TYPE_UNLOAD, 1))

	table.insert(
		self.hudElements,
		ADPullDownList:new(
			self.posX + 2 * self.gapWidth + self.buttonWidth, --+ self.iconWidth * 5 + self.gapWidth*5
			self.row2,
			self.iconWidth * 6 + self.gapWidth * 5,
			self.listItemHeight,
			ADPullDownList.TYPE_FILLTYPE,
			1
		)
	)

	self:AddButton("input_start_stop", nil, "input_ADEnDisable", 1, true)
	self:AddButton("input_silomode", "input_previousMode", "input_ADSilomode", 1, true)
	self:AddButton("input_continue", nil, "input_AD_continue", 1, true)
	self:AddButton("input_parkVehicle", "input_setParkDestination", "input_ADParkVehicle", 1, true)
	self:AddButton("input_incLoopCounter", "input_decLoopCounter", "input_ADIncLoopCounter", 1, true)
	self.buttonCounter = self.buttonCounter + 1
	self:AddButton("input_debug", "input_displayMapPoints", "input_ADActivateDebug", 1, true)

	self:AddButton("input_recalculate", nil, "input_ADDebugForceUpdate", 1, false)
	self:AddButton("input_record", "input_record_dual", "input_ADRecord", 1, true)
	self:AddButton("input_showNeighbor", nil, "input_ADDebugSelectNeighbor", 1, false)
	self:AddButton("input_nextNeighbor", "input_previousNeighbor", "input_ADDebugChangeNeighbor", 1, false)
	self:AddButton("input_toggleConnection", "input_toggleConnectionInverted", "input_ADDebugCreateConnection", 1, false)
	self:AddButton("input_createMapMarker", "input_editMapMarker", "input_ADDebugCreateMapMarker", 1, false)
	self:AddButton("input_removeWaypoint", "input_removeMapMarker", "input_ADDebugDeleteWayPoint", 1, false)

	local speedX = self.posX + (self.cols - 1) * self.borderX + (self.cols - 2) * self.buttonWidth
	local speedY = self.posY + (1) * self.borderY + (0) * self.buttonHeight
	table.insert(self.hudElements, ADHudSpeedmeter:new(speedX, speedY, self.buttonWidth, self.buttonHeight))
	--self:AddButton("input_continue", nil,"input_AD_continue", 1, true);
	--self:AddButton("input_parkVehicle", "input_setParkDestination", "input_ADParkVehicle", 1, true);
	--self:AddButton("input_incLoopCounter", "input_decLoopCounter", "input_ADIncLoopCounter", 1, true);
	--self:AddButton("input_exportRoutes", nil, "input_AD_export_routes", 1, false);

	--local parkX = self.posX + (self.cols - 1) * self.borderX + (self.cols - 2) * self.buttonWidth;
	--table.insert(self.hudElements, ADHudButton:new(parkX, self.row4, self.buttonWidth, self.buttonHeight, "input_parkVehicle", "input_setParkDestination", "input_ADParkVehicle", 1, true));

	--local incCounterX = self.posX + (self.cols - 2) * self.borderX + (self.cols - 3) * self.buttonWidth;
	--table.insert(self.hudElements, ADHudButton:new(incCounterX, self.row4, self.buttonWidth, self.buttonHeight, "input_incLoopCounter", "input_decLoopCounter", "input_ADIncLoopCounter", 1, true));

	--local continueX = self.posX + (self.cols - 3) * self.borderX + (self.cols - 4) * self.buttonWidth;
	--table.insert(self.hudElements, ADHudButton:new(continueX, self.row4, self.buttonWidth, self.buttonHeight, "input_continue", nil, "input_AD_continue", 1, true));

	-- Refreshing layer sequence must be called, after all elements have been added
	self:refreshHudElementsLayerSequence()
end

function AutoDriveHud:AddButton(primaryAction, secondaryAction, toolTip, state, visible)
	self.buttonCounter = self.buttonCounter + 1
	self.colCurrent = self.buttonCounter % self.cols
	if self.colCurrent == 0 then
		self.colCurrent = self.cols
	end
	self.rowCurrent = math.ceil(self.buttonCounter / self.cols)

	local posX = self.posX + self.colCurrent * self.borderX + (self.colCurrent - 1) * self.buttonWidth
	local posY = self.posY + (self.rowCurrent) * self.borderY + (self.rowCurrent - 1) * self.buttonHeight
	--toolTip = string.sub(g_i18n:getText(toolTip), 4, string.len(g_i18n:getText(toolTip)))
	table.insert(self.hudElements, ADHudButton:new(posX, posY, self.buttonWidth, self.buttonHeight, primaryAction, secondaryAction, toolTip, state, visible))
end

function AutoDriveHud:refreshHudElementsLayerSequence()
	-- Sort the elements by their layer index, for optimizing drawHud and mouseEvent methods
	table.sort(
		self.hudElements,
		function(a, b)
			return a.layer < b.layer
		end
	)
end

function AutoDriveHud:drawHud(vehicle)
	if vehicle == g_currentMission.controlledVehicle then
		local uiScale = g_gameSettings:getValue("uiScale")
		if AutoDrive.getSetting("guiScale") ~= 0 then
			uiScale = AutoDrive.getSetting("guiScale")
		end

		if self.lastUIScale == nil then
			self.lastUIScale = uiScale
		end

		if self.lastUIScale ~= uiScale then
			self:createHudAt(self.posX, self.posY)
		end
		self.lastUIScale = uiScale

		--local ovWidth = self.Background.width
		--local ovHeight = self.Background.height

		for _, element in ipairs(self.hudElements) do -- `ipairs` is important, as we want "index-value pairs", not "key-value pairs". https://stackoverflow.com/a/55109411
			element:onDraw(vehicle, uiScale)
		end
	end
end

function AutoDriveHud:toggleHud(vehicle)
	if self.showHud == false then
		self.showHud = true
		vehicle.ad.showingHud = true
	else
		self.showHud = false
		vehicle.ad.showingHud = false
		g_inputBinding:setShowMouseCursor(false)
	end

	AutoDrive.showingHud = self.showHud
end

function AutoDriveHud:mouseEvent(vehicle, posX, posY, isDown, isUp, button)
	local mouseActiveForAutoDrive = (g_gui.currentGui == nil) and (g_inputBinding:getShowMouseCursor() == true)
	if mouseActiveForAutoDrive then
		local mouseEventHandled = false
		AutoDrive.mouseWheelActive = false
		-- Start with highest layer value (last in array), and then iterate backwards.
		for i = #self.hudElements, 1, -1 do
			local element = self.hudElements[i]
			local layer = element.layer
			mouseEventHandled = element:mouseEvent(vehicle, posX, posY, isDown, isUp, button, layer)
			if mouseEventHandled then
				-- Maybe a PullDownList have been expanded/collapsed, so need to refresh layer sequence
				self:refreshHudElementsLayerSequence()
				break
			end
		end

		if (not mouseEventHandled) and (AutoDrive.pullDownListExpanded > 0) and (button >= 1 and button <= 3 and isUp) then
			AutoDrive.Hud:closeAllPullDownLists(vehicle)
		end

		if self.isMoving then
			if button == 1 and isUp then
				self:stopMovingHud()
			else
				self:moveHud(posX, posY)
			end
		end
	end

	AutoDrive.mouseWheelActive = AutoDrive.mouseWheelActive or (AutoDrive.pullDownListExpanded ~= 0)
end

function AutoDriveHud:startMovingHud(mouseX, mouseY)
	self.isMoving = true
	self.lastMousePosX = mouseX
	self.lastMousePosY = mouseY
end

function AutoDriveHud:moveHud(posX, posY)
	if self.isMoving then
		local diffX = posX - self.lastMousePosX
		local diffY = posY - self.lastMousePosY
		self:createHudAt(self.posX + diffX, self.posY + diffY)
		self.lastMousePosX = posX
		self.lastMousePosY = posY
	end
end

function AutoDriveHud:stopMovingHud()
	self.isMoving = false
	AutoDriveUserDataEvent.sendToServer()
end

function AutoDriveHud:getModeName(vehicle)
	if vehicle.ad.mode == AutoDrive.MODE_DRIVETO then
		return g_i18n:getText("AD_MODE_DRIVETO")
	elseif vehicle.ad.mode == AutoDrive.MODE_DELIVERTO then
		return g_i18n:getText("AD_MODE_DELIVERTO")
	elseif vehicle.ad.mode == AutoDrive.MODE_PICKUPANDDELIVER then
		return g_i18n:getText("AD_MODE_PICKUPANDDELIVER")
	elseif vehicle.ad.mode == AutoDrive.MODE_UNLOAD then
		return g_i18n:getText("AD_MODE_UNLOAD")
	elseif vehicle.ad.mode == AutoDrive.MODE_LOAD then
		return g_i18n:getText("AD_MODE_LOAD")
	elseif vehicle.ad.mode == AutoDrive.MODE_BGA then
		return g_i18n:getText("AD_MODE_BGA")
	end

	return ""
end

function AutoDriveHud:has_value(tab, val)
	for _, value in ipairs(tab) do
		if value == val then
			return true
		end
	end

	return false
end

function AutoDriveHud:closeAllPullDownLists(vehicle)
	for _, hudElement in pairs(self.hudElements) do
		if hudElement.collapse ~= nil and hudElement.state ~= nil and hudElement.state == ADPullDownList.STATE_EXPANDED then
			hudElement:collapse(vehicle, false)
		end
	end
	-- PullDownList(s) have been collapsed, so need to refresh layer sequence
	self:refreshHudElementsLayerSequence()
end

--blatant copy of Courseplay's implementation. So all credit goes to their dev team :-)
function AutoDriveHud:createMapHotspot(vehicle)
	-- Since this function and 'deleteMapHotspot' are called 4 times on clients (maybe we should fix that) we need to ensure tha only one map hotspot is created
	-- The previous solution wasn't working, to be honest I have no idea why...
	if vehicle.ad.isActive and vehicle.ad.mapHotSpotActive == nil then
		--local hotspotX, _, hotspotZ = getWorldTranslation(vehicle.rootNode)
		local _, textSize = getNormalizedScreenValues(0, 6) --Textsize local _, textSize = getNormalizedScreenValues(0, 9)
		local _, textOffsetY = getNormalizedScreenValues(0, 15) --Distance to icon -- local _, textOffsetY = getNormalizedScreenValues(0, 24)
		local width, height = getNormalizedScreenValues(10, 10) --Triggersize -- local width, height = getNormalizedScreenValues(18, 18)
		vehicle.ad.mapHotspot = MapHotspot:new("adDriver", MapHotspot.CATEGORY_AI)
		vehicle.ad.mapHotspot:setSize(width, height)
		vehicle.ad.mapHotspot:setLinkedNode(vehicle.components[1].node)
		vehicle.ad.mapHotspot:setText("AD: " .. vehicle.name)
		if vehicle.ad.driverName ~= nil then
			vehicle.ad.mapHotspot:setText("AD: " .. vehicle.ad.driverName)
		end
		vehicle.ad.mapHotspot:setImage(nil, getNormalizedUVs(MapHotspot.UV.HELPER), {0.052, 0.1248, 0.672, 1})
		vehicle.ad.mapHotspot:setBackgroundImage(nil, getNormalizedUVs(MapHotspot.UV.HELPER))
		vehicle.ad.mapHotspot:setIconScale(0.4) --Iconsize vehicle.ad.mapHotspot:setIconScale(0.7)
		vehicle.ad.mapHotspot:setTextOptions(textSize, nil, textOffsetY, {1, 1, 1, 1}, Overlay.ALIGN_VERTICAL_MIDDLE)
		vehicle.ad.mapHotspot:setColor({0.0, 0.569, 0.835, 1})

		g_currentMission:addMapHotspot(vehicle.ad.mapHotspot)
		vehicle.ad.mapHotSpotActive = true
	end
end

function AutoDriveHud:deleteMapHotspot(vehicle)
	if vehicle ~= nil and vehicle.ad ~= nil and vehicle.ad.mapHotspot then
		g_currentMission:removeMapHotspot(vehicle.ad.mapHotspot)
		vehicle.ad.mapHotspot:delete()
		vehicle.ad.mapHotspot = nil
		vehicle.ad.mapHotSpotActive = nil
	end
end
