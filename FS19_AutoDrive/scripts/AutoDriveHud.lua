AutoDriveHud = {}
AutoDrive.FONT_SCALE = 0.0115;
AutoDrive.PULLDOWN_ITEM_COUNT = 20;
AutoDrive.ItemFilterList = {
	34, --Air
	11, -- Cotton
	77, 78, 79, 80, --Chicken
	61, 62, 63, 64, 65, 66, 67, 68, -- Cows
	14, --Eggs
	--28, --29, --multiple grass
	53, 54, 55, 56, 57, 58, 59, 60, --Horses
	25, --Oilseed Radish
	73, 74, 75, 76, --Pigs
	35, 36, 37, 38, 39, --Round bale
	69, 70, 71, 72, --Sheep
	40, 41, 42, --Square bale
	49, --Tarp?
	22, --Tree sapling
	1, --Unknown
	52, --weed
	15 --wool
};

function AutoDriveHud:new()
    o = {}
    setmetatable(o, self)
    self.__index = self
    return o
end;

function AutoDriveHud:loadHud()	
	if AutoDrive.HudX == nil or AutoDrive.HudY == nil then
		local uiScale = g_gameSettings:getValue("uiScale")
		if AutoDrive:getSetting("guiScale") ~= 0 then
			uiScale = AutoDrive:getSetting("guiScale");
		end;
		local numButtons = 9
		local numButtonRows = 2
		local buttonSize = 32
		local iconSize = 32
		local gapSize = 3
		
		self.width,        self.height        = getNormalizedScreenValues((numButtons * (gapSize+buttonSize) + gapSize)*uiScale, ((numButtonRows * (gapSize+buttonSize)) + (2 * (gapSize+iconSize)) + 30)*uiScale)	
		self.gapWidth, 		self.gapHeight	  = getNormalizedScreenValues(uiScale * gapSize, uiScale * gapSize);
		self.posX   = 1 - self.width - self.gapWidth;
		self.posY   = 0.285926;
		AutoDrive.HudX = self.posX;
		AutoDrive.HudY = self.posY;
	else
		self.posX = AutoDrive.HudX;
		self.posY = AutoDrive.HudY;
	end;
	AutoDriveHud:createHudAt(self.posX, self.posY);
	self.isMoving = false;	
end;

function AutoDriveHud:createHudAt(hudX, hudY)
	local uiScale = g_gameSettings:getValue("uiScale")
	if AutoDrive:getSetting("guiScale") ~= 0 then
		uiScale = AutoDrive:getSetting("guiScale");
	end;
	local numButtons = 9
	local numButtonRows = 2
	local buttonSize = 32
	local iconSize = 32
	local gapSize = 3	
	local listItemSize = 20
	
	self.headerHeight = 0.016 * uiScale;
	
	self.borderX,      	self.borderY       = getNormalizedScreenValues(uiScale * gapSize,    uiScale * gapSize)
	self.buttonWidth,  	self.buttonHeight  = getNormalizedScreenValues(uiScale * buttonSize, uiScale * buttonSize)
	self.width,        	self.height        = getNormalizedScreenValues((numButtons * (gapSize+buttonSize) + gapSize)*uiScale, ((numButtonRows * (gapSize+buttonSize)) + (2 * (gapSize+iconSize)) + gapSize)*uiScale + self.headerHeight)	
	self.gapWidth, 		self.gapHeight	  = getNormalizedScreenValues(uiScale * gapSize, uiScale * gapSize);
	self.iconWidth, 	self.iconHeight	  = getNormalizedScreenValues(uiScale * iconSize, uiScale * iconSize);
	self.listItemWidth, self.listItemHeight	  = getNormalizedScreenValues(uiScale * listItemSize, uiScale * listItemSize);
	self.posX   = hudX;
	self.posY   = hudY;

	AutoDrive.HudX = self.posX;
	AutoDrive.HudY = self.posY;
	AutoDrive.HudChanged = true;

	self.hudElements = {};
	
	self.Speed = "50";
	self.Target = "Not Ready"
	self.showHud = false;
	if AutoDrive.mapMarker[1] ~= nil then
		self.Target = AutoDrive.mapMarker[1].name;
	end;	
	
	self.Background = {};
	self.Buttons = {};
	self.buttonCounter = 0;
	self.rows = 1;	
	self.rowCurrent = 1;
	self.cols = 9;
	self.colCurrent = 1;
	
	self.row3 = self.posY + 3 * self.borderY + 2 * self.buttonHeight;
	self.row4 = self.posY + 4 * self.borderY + 3 * self.buttonHeight;
	self.rowHeader = self.posY + 5 * self.borderY + 4 * self.buttonHeight;

	table.insert(self.hudElements, ADHudIcon:new(self.posX, self.posY, self.width, self.height, AutoDrive.directory .. "textures/Background.dds", 0, "background"));

	self.Background.pullDownBG = {};
	self.Background.pullDownBG.img = AutoDrive.directory .. "textures/Background.dds";
	self.Background.pullDownBG.ov = Overlay:new(AutoDrive.directory .. "textures/Background.dds", self.posX, self.posY , self.width, self.height);
	self.Background.pullDownBG.posX = self.posX;
	self.Background.pullDownBG.posY = self.posY;
	self.Background.pullDownBG.width = self.width;
	self.Background.pullDownBG.height = self.height;
	
	table.insert(self.hudElements, ADHudIcon:new(self.posX, self.rowHeader,
		self.width, self.headerHeight, AutoDrive.directory .. "textures/Header.dds", 1, "header"));

	local closeHeight = self.headerHeight; --0.0177 * uiScale;
	local closeWidth = closeHeight * (g_screenHeight / g_screenWidth);
	local posX = self.posX + self.width - (closeWidth*1.1);
	local posY = self.rowHeader;
	table.insert(self.hudElements, ADHudButton:new(posX, posY, closeWidth, closeHeight, "input_toggleHud", nil, "", 1, true));

	table.insert(self.hudElements, ADHudIcon:new(self.posX, self.row4,
		self.iconWidth, self.iconHeight, AutoDrive.directory .. "textures/destination.dds", 1, "destinationOverlay"));
		
	table.insert(self.hudElements, ADPullDownList:new(self.posX + 2*self.gapWidth + self.buttonWidth,
		self.row4,
		self.iconWidth * 5 + self.gapWidth*4, self.listItemHeight, ADPullDownList.TYPE_TARGET ,1));

	local speedX = self.posX + self.cols * self.borderX + (self.cols - 1) * self.buttonWidth;
	table.insert(self.hudElements, ADHudSpeedmeter:new(speedX, self.row4, self.buttonWidth, self.buttonHeight));

	table.insert(self.hudElements, ADHudIcon:new(self.posX + self.gapWidth,
		self.row3,
		self.iconWidth, self.iconHeight, AutoDrive.directory .. "textures/tipper_overlay.dds", 1, "unloadOverlay"));
		
	table.insert(self.hudElements, ADPullDownList:new(self.posX + 2*self.gapWidth + self.buttonWidth,
		self.row3,
		self.iconWidth * 5 + self.gapWidth*4, self.listItemHeight, ADPullDownList.TYPE_UNLOAD ,1));

	table.insert(self.hudElements, ADPullDownList:new(self.posX + 2*self.gapWidth + self.buttonWidth + self.iconWidth * 5 + self.gapWidth*5,
		self.row3,
		self.iconWidth * 3 + self.gapWidth*2, self.listItemHeight, ADPullDownList.TYPE_FILLTYPE ,1));

	self:AddButton("input_start_stop", nil, "input_ADEnDisable", 1, true);
	self:AddButton("input_previousTarget", nil, "input_ADSelectPreviousTarget", 1, true);
	self:AddButton("input_nextTarget", nil,"input_ADSelectTarget", 1, true);	
	self:AddButton("input_record", nil, "input_ADRecord", 1, true);
	self:AddButton("input_silomode", "input_previousMode","input_ADSilomode", 1, true);
	self:AddButton("input_decreaseSpeed", nil,"input_AD_Speed_down", 1, true);
	self:AddButton("input_increaseSpeed", nil,"input_AD_Speed_up", 1, true);
	self:AddButton("input_continue", nil,"input_AD_continue", 1, true);
	self:AddButton("input_debug", nil, "input_ADActivateDebug", 1, true);

	self:AddButton("input_recalculate", nil, "input_ADDebugForceUpdate", 1, false);
	self:AddButton("input_parkVehicle", "input_setParkDestination", "input_ADParkVehicle", 1, true);
	self:AddButton("input_incLoopCounter", "input_decLoopCounter", "input_ADIncLoopCounter", 1, true);
	self:AddButton("input_showNeighbor", nil, "input_ADDebugSelectNeighbor", 1, false);
	self:AddButton("input_nextNeighbor", "input_previousNeighbor", "input_ADDebugChangeNeighbor", 1, false);
	self:AddButton("input_toggleConnection", nil, "input_ADDebugCreateConnection", 1, false);
	self:AddButton("input_createMapMarker", "input_renameMapMarker", "input_ADDebugCreateMapMarker", 1, false);
	self:AddButton("input_removeWaypoint", "input_removeDestination", "input_ADDebugDeleteWayPoint", 1, false);
	self:AddButton("input_exportRoutes", nil, "input_AD_export_routes", 1, false);
end;

function AutoDriveHud:AddButton(primaryAction, secondaryAction, toolTip, state, visible)	
	self.buttonCounter = self.buttonCounter + 1;	
	self.colCurrent = self.buttonCounter % self.cols;
	if self.colCurrent == 0 then
		self.colCurrent = self.cols;
	end;
	self.rowCurrent = math.ceil(self.buttonCounter / self.cols);
	
	local posX = self.posX + self.colCurrent * self.borderX + (self.colCurrent - 1) * self.buttonWidth;
	local posY = self.posY + (self.rowCurrent) * self.borderY + (self.rowCurrent-1) * self.buttonHeight;
	local tooltip = string.sub(g_i18n:getText(toolTip),4,string.len(g_i18n:getText(toolTip)));
	table.insert(self.hudElements, ADHudButton:new(posX, posY, self.buttonWidth, self.buttonHeight, primaryAction, secondaryAction, toolTip, state, visible));
end;

function AutoDriveHud:drawHud(vehicle)	
	if vehicle == g_currentMission.controlledVehicle then		
		local uiScale = g_gameSettings:getValue("uiScale")	
		if AutoDrive:getSetting("guiScale") ~= 0 then
			uiScale = AutoDrive:getSetting("guiScale");
		end;

		if self.lastUIScale == nil then
			self.lastUIScale = uiScale;
		end;

		if self.lastUIScale ~= uiScale then
			self:createHudAt(self.posX, self.posY);
		end;
		self.lastUIScale = uiScale;
		
		local ovWidth = self.Background.width;
		local ovHeight = self.Background.height;
			
		local layer = 0;
		while layer <= 10 do
			for id, element in pairs(self.hudElements) do
				if element.layer == layer then
					element:onDraw(vehicle);
				end;
			end;
			layer = layer + 1;
		end;		

		
		local adFontSize = 0.009 * uiScale;		
		local textHeight = getTextHeight(adFontSize, "text");
		local adPosX = self.posX + self.borderX;
		local adPosY = self.rowHeader + (self.headerHeight - textHeight)/2;

		setTextBold(false);
		setTextColor(1,1,1,1);
		setTextAlignment(RenderText.ALIGN_LEFT);
		local textToShow = "AutoDrive";
		textToShow = textToShow .. " - " .. AutoDriveHud:getModeName(vehicle);

		if vehicle.ad.isActive == true and vehicle.ad.isPaused == false and vehicle.spec_motorized ~= nil and not AutoDrive:isOnField(vehicle) and vehicle.ad.mode ~= AutoDrive.MODE_BGA then
			local remainingTime = AutoDrive:getDriveTimeForWaypoints(vehicle.ad.wayPoints, vehicle.ad.currentWayPoint, math.min((vehicle.spec_motorized.motor.maxForwardSpeed * 3.6), vehicle.ad.targetSpeed));
			local remainingMinutes = math.floor(remainingTime / 60);
			local remainingSeconds = remainingTime % 60;
			if remainingTime ~= 0 then
				if remainingMinutes > 0 then
					textToShow = textToShow .. " - " .. string.format("%.0f", remainingMinutes) .. ":" .. string.format("%02d", math.floor(remainingSeconds) );
				elseif remainingSeconds ~= 0 then
					textToShow = textToShow .. " - " .. string.format("%2.0f", remainingSeconds) .. "s";
				end;
			end;
		end;                

		if vehicle.ad.sToolTip ~= "" and vehicle.ad.nToolTipWait <= 0 then
			textToShow = textToShow .. " - " .. string.sub(g_i18n:getText(vehicle.ad.sToolTip),4,string.len(g_i18n:getText(vehicle.ad.sToolTip)));
		end;
		
		if vehicle.ad.mode == AutoDrive.MODE_UNLOAD then
			local combineText = AutoDrive:combineStateToDescription(vehicle)
			if combineText ~= nil then
				textToShow = textToShow .. " - " .. combineText;
			end;
		elseif vehicle.ad.mode == AutoDrive.MODE_BGA then
			local bgaText = AutoDriveBGA:stateToText(vehicle)
			if bgaText ~= nil then
				textToShow = textToShow .. " - " .. bgaText;
			end;
		end;
		
		if AutoDrive.pullDownListExpanded == 0 then
			renderText(adPosX, adPosY, adFontSize, textToShow);
		end;
		
	end;	
end;

function AutoDriveHud:toggleHud(vehicle)
    if self.showHud == false then
		self.showHud = true;		
		vehicle.ad.showingHud = true;
    else
		self.showHud = false;
		vehicle.ad.showingHud = false;
		g_inputBinding:setShowMouseCursor(false);
	end;
	
	AutoDrive.showingHud = self.showHud;
end;

function AutoDriveHud:mouseEvent(vehicle, posX, posY, isDown, isUp, button)
	local mouseActiveForAutoDrive = (g_gui.currentGui == nil) and (g_inputBinding:getShowMouseCursor() == true);
	if mouseActiveForAutoDrive then
		local mouseEventHandled = false;		
        AutoDrive.mouseWheelActive = false;
		local layer = 10;
		while layer >= 0 and (not mouseEventHandled) do
			for id, element in pairs(self.hudElements) do
				if element.layer == layer then
					mouseEventHandled = mouseEventHandled or element:mouseEvent(vehicle, posX, posY, isDown, isUp, button, layer);
				end;
				if mouseEventHandled then
					break;
				end;
			end;
			layer = layer - 1;
		end;
		
		if self.isMoving then
			if button == 1 and isUp then
				self:stopMovingHud();
			else
				self:moveHud(posX, posY);
			end;
		end;
	end;

	AutoDrive.mouseWheelActive = AutoDrive.mouseWheelActive or (AutoDrive.pullDownListExpanded ~= 0);
end;

function AutoDriveHud:startMovingHud(mouseX, mouseY)
	self.isMoving = true;
	self.lastMousePosX = mouseX;
	self.lastMousePosY = mouseY;
end;

function AutoDriveHud:moveHud(posX, posY)
	if self.isMoving then
		local diffX = posX - self.lastMousePosX;
		local diffY = posY - self.lastMousePosY;
		self:createHudAt(self.posX+diffX, self.posY+diffY);
		self.lastMousePosX = posX;
		self.lastMousePosY = posY;
	end;
end;

function AutoDriveHud:stopMovingHud()
	self.isMoving = false;
end;

function AutoDriveHud:getModeName(vehicle)
	if vehicle.ad.mode == AutoDrive.MODE_DRIVETO then
		return g_i18n:getText("AD_MODE_DRIVETO");
	elseif vehicle.ad.mode == AutoDrive.MODE_DELIVERTO then
		return g_i18n:getText("AD_MODE_DELIVERTO");
	elseif vehicle.ad.mode == AutoDrive.MODE_PICKUPANDDELIVER then
		return g_i18n:getText("AD_MODE_PICKUPANDDELIVER");
	elseif vehicle.ad.mode == AutoDrive.MODE_UNLOAD then
		return g_i18n:getText("AD_MODE_UNLOAD");
	elseif vehicle.ad.mode == AutoDrive.MODE_LOAD then
		return g_i18n:getText("AD_MODE_LOAD");
	elseif vehicle.ad.mode == AutoDrive.MODE_BGA then
		return g_i18n:getText("AD_MODE_BGA");
	end;

	return "";
end;

function AutoDriveHud:has_value (tab, val)
	for index, value in ipairs(tab) do
		if value == val then
			return true
		end
	end

	return false
end

function AutoDriveHud:closeAllPullDownLists(vehicle)
	if AutoDrive.pullDownListExpanded > 0 then
		for _, hudElement in pairs(self.hudElements) do
			if hudElement.collapse ~= nil and hudElement.state ~= nil and hudElement.state == ADPullDownList.STATE_EXPANDED then
				hudElement:collapse(vehicle);
			end;
		end;
	end;
end;