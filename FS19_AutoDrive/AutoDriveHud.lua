AutoDriveHud = {}

function AutoDriveHud:new()
    o = {}
    setmetatable(o, self)
    self.__index = self
    return o
end;

function AutoDriveHud:loadHud()	
	if AutoDrive.HudX == nil or AutoDrive.HudY == nil then
		local uiScale = g_gameSettings:getValue("uiScale")
		local numButtons = 9
		local numButtonRows = 2
		local buttonSize = 32
		local iconSize = 32
		local gapSize = 3
		
		self.width,        self.height        = getNormalizedScreenValues((numButtons * (gapSize+buttonSize) + gapSize)*uiScale, ((numButtonRows * (gapSize+buttonSize)) + (2 * (gapSize+iconSize)) + 30)*uiScale)	
		self.gapWidth, 		self.gapHeight	  = getNormalizedScreenValues(uiScale * gapSize, uiScale * gapSize);
		self.posX   = 1 - self.width - self.gapWidth;
		self.posY   = 0.235;
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
	local numButtons = 9
	local numButtonRows = 2
	local buttonSize = 32
	local iconSize = 32
	local gapSize = 3
	
	self.borderX,      self.borderY       = getNormalizedScreenValues(uiScale * gapSize,    uiScale * gapSize)
	self.buttonWidth,  self.buttonHeight  = getNormalizedScreenValues(uiScale * buttonSize, uiScale * buttonSize)
	self.width,        self.height        = getNormalizedScreenValues((numButtons * (gapSize+buttonSize) + gapSize)*uiScale, ((numButtonRows * (gapSize+buttonSize)) + (2 * (gapSize+iconSize)) + 30)*uiScale)	
	self.gapWidth, 		self.gapHeight	  = getNormalizedScreenValues(uiScale * gapSize, uiScale * gapSize);
	self.iconWidth, 		self.iconHeight	  = getNormalizedScreenValues(uiScale * iconSize, uiScale * iconSize);
	self.posX   = hudX;
	self.posY   = hudY;

	AutoDrive.HudX = self.posX;
	AutoDrive.HudY = self.posY;
	AutoDrive.HudChanged = true;
	
	self.Speed = "60";
	self.Target = "Not Ready"
	self.showHud = true;
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
	
	self.Background.img = AutoDrive.directory .. "img/Background.dds";
	self.Background.ov = Overlay:new(AutoDrive.directory .. "img/Background.dds", self.posX, self.posY , self.width, self.height);
	self.Background.posX = self.posX;
	self.Background.posY = self.posY;
	self.Background.width = self.width;
	self.Background.height = self.height;

	self.Background.Header = {};
	self.Background.Header.img = AutoDrive.directory .. "img/Header.dds";
	self.Background.Header.width = self.width;
	self.Background.Header.height = 0.009 * (g_screenWidth / g_screenHeight);
	self.Background.Header.posX = self.posX;
	self.Background.Header.posY = self.posY + self.height - self.Background.Header.height;
	self.Background.Header.ov = Overlay:new(self.Background.Header.img, self.Background.Header.posX, self.Background.Header.posY , self.Background.Header.width, self.Background.Header.height);
	
	self.Background.close_small = {};
	self.Background.close_small.img = AutoDrive.directory .. "img/close_small.dds";
	self.Background.close_small.width = 0.01;
	self.Background.close_small.height = self.Background.close_small.width * (g_screenWidth / g_screenHeight);
	self.Background.close_small.posX = self.posX + self.width - 0.0101;
	self.Background.close_small.posY = self.posY + self.height - 0.0101* (g_screenWidth / g_screenHeight);
	self.Background.close_small.ov = Overlay:new(self.Background.close_small.img, self.Background.close_small.posX, self.Background.close_small.posY , self.Background.close_small.width, self.Background.close_small.height);

	self.Background.destination = {};
	self.Background.destination.img = AutoDrive.directory .. "img/destination.dds";
	self.Background.destination.width = self.iconWidth * 1.2; --0.018;
	self.Background.destination.height = self.iconHeight * 1.2; --self.Background.destination.width * (g_screenWidth / g_screenHeight);
	self.Background.destination.posX = self.posX;
	self.Background.destination.posY = self.posY + self.height - self.Background.Header.height - self.Background.destination.height - self.gapHeight; -- - 0.001;
	self.Background.destination.ov = Overlay:new(self.Background.destination.img, self.Background.destination.posX, self.Background.destination.posY , self.Background.destination.width, self.Background.destination.height);

	self.Background.speedmeter = {};
	self.Background.speedmeter.img = AutoDrive.directory .. "img/speedmeter.dds";
	self.Background.speedmeter.width = self.iconWidth * 1.2; --0.019;
	self.Background.speedmeter.height = self.iconHeight * 1.2; --self.Background.speedmeter.width * (g_screenWidth / g_screenHeight);
	self.Background.speedmeter.posX = self.posX + self.width - 0.03;
	self.Background.speedmeter.posY = self.posY + self.height - self.Background.Header.height - self.Background.speedmeter.height - self.gapHeight; -- + 0.001;
	self.Background.speedmeter.ov = Overlay:new(self.Background.speedmeter.img, self.Background.speedmeter.posX, self.Background.speedmeter.posY , self.Background.speedmeter.width, self.Background.speedmeter.height);
	
	self.Background.divider = {};
	self.Background.divider.img = AutoDrive.directory .. "img/divider.dds";
	self.Background.divider.width = self.width;
	self.Background.divider.height = 0.001
	self.Background.divider.posX = self.posX;
	self.Background.divider.posY = self.posY + self.height - self.Background.Header.height - self.Background.speedmeter.height - self.gapHeight;
	self.Background.divider.ov = Overlay:new(self.Background.divider.img, self.Background.divider.posX, self.Background.divider.posY , self.Background.divider.width, self.Background.divider.height);

	self.Background.unloadOverlay = {};
	self.Background.unloadOverlay.width = self.iconWidth;
	self.Background.unloadOverlay.height = self.iconHeight; --self.Background.unloadOverlay.width * (g_screenWidth / g_screenHeight);
	self.Background.unloadOverlay.posX = self.posX + self.gapWidth;
	self.Background.unloadOverlay.posY = self.posY + self.height - self.Background.Header.height - self.Background.speedmeter.height - self.gapHeight*2 - self.Background.unloadOverlay.height;
	self.Background.unloadOverlay.img = AutoDrive.directory .. "img/tipper_overlay.dds";
	self.Background.unloadOverlay.ov = Overlay:new(self.Background.unloadOverlay.img, self.Background.unloadOverlay.posX, self.Background.unloadOverlay.posY , self.Background.unloadOverlay.width, self.Background.unloadOverlay.height);
	
	self:AddButton("input_start_stop", "on.dds", "off.dds", "input_ADEnDisable", false, true);
	self:AddButton("input_previousTarget", "previousTarget.dds", "previousTarget.dds", "input_ADSelectPreviousTarget", true, true);
	self:AddButton("input_nextTarget", "nextTarget.dds", "nextTarget.dds","input_ADSelectTarget", true, true);
	self:AddButton("input_record", "record_on.dds", "record_off.dds","input_ADRecord", false, true);
	self:AddButton("input_silomode", "silomode_on.dds", "silomode_off.dds","input_ADSilomode", false, true);
	self:AddButton("input_decreaseSpeed", "decreaseSpeed.dds", "decreaseSpeed.dds","input_AD_Speed_down", true, true);
	self:AddButton("input_increaseSpeed", "increaseSpeed.dds", "increaseSpeed.dds","input_AD_Speed_up", true, true);
	self:AddButton("input_continue", "continue.dds", "continue.dds","input_AD_continue", true, true);
	self:AddButton("input_debug", "debug_on.dds", "debug_off.dds","input_ADActivateDebug", false, true);

	self:AddButton("input_recalculate", "recalculate.dds", "recalculate_on.dds","input_ADDebugForceUpdate", true, false);
	self:AddButton("input_previousTarget_Unload", "previousTarget_Unload.dds", "previousTarget_Unload.dds", "input_ADSelectTargetUnload", true, true);
	self:AddButton("input_nextTarget_Unload", "nextTarget_Unload.dds", "nextTarget_Unload.dds","input_ADSelectPreviousTargetUnload", true, true);
	self:AddButton("input_showNeighbor", "showNeighbor_on.dds", "showNeighbor_off.dds","input_ADDebugSelectNeighbor", false, false);
	self:AddButton("input_nextNeighbor", "nextNeighbor.dds", "nextNeighbor.dds","input_ADDebugChangeNeighbor", true, false);
	self:AddButton("input_toggleConnection", "toggleConnection.dds", "toggleConnection.dds","input_ADDebugCreateConnection", true, false);
	self:AddButton("input_createMapMarker", "createMapMarker.dds", "createMapMarker.dds","input_ADDebugCreateMapMarker", true, false);
	self:AddButton("input_removeWaypoint", "deleteWaypoint.dds", "deleteWaypoint.dds","input_ADDebugDeleteWayPoint", true, false);
	self:AddButton("input_exportRoutes", "save_symbol.dds", "save_symbol.dds","input_AD_export_routes", true, false);
end;

function AutoDriveHud:AddButton(name, img, img2, toolTip, on, visible)	
	self.buttonCounter = self.buttonCounter + 1;	
	self.colCurrent = self.buttonCounter % self.cols;
	if self.colCurrent == 0 then
		self.colCurrent = self.cols;
	end;
	self.rowCurrent = math.ceil(self.buttonCounter / self.cols);	
	self.Buttons[self.buttonCounter] = {};
	
	self.Buttons[self.buttonCounter].posX = self.posX + self.colCurrent * self.borderX + (self.colCurrent - 1) * self.buttonWidth; -- + self.borderX  ;
	self.Buttons[self.buttonCounter].posY = self.posY + (self.rowCurrent) * self.borderY + (self.rowCurrent-1) * self.buttonHeight;
	self.Buttons[self.buttonCounter].width = self.buttonWidth;
	self.Buttons[self.buttonCounter].height = self.buttonHeight;
	self.Buttons[self.buttonCounter].name = name;
	self.Buttons[self.buttonCounter].img_on = AutoDrive.directory .. "img/" .. img;
	self.Buttons[self.buttonCounter].isVisible = visible;
	self.Buttons[self.buttonCounter].toolTip = string.sub(g_i18n:getText(toolTip),4,string.len(g_i18n:getText(toolTip)))
	
	if img2 ~= nil then
		self.Buttons[self.buttonCounter].img_off = AutoDrive.directory .. "img/" .. img2;
	else
		self.Buttons[self.buttonCounter].img_off = nil;
	end;

	if name == "input_silomode" then
		self.Buttons[self.buttonCounter].img_3 =  AutoDrive.directory .. "img/" .. "unload.dds";
	end;
	if name == "input_record" then
		self.Buttons[self.buttonCounter].img_dual = AutoDrive.directory .. "img/" .. "record_dual.dds";
	end;
	
	if on then
		self.Buttons[self.buttonCounter].img_active = self.Buttons[self.buttonCounter].img_on;
	else
		self.Buttons[self.buttonCounter].img_active = self.Buttons[self.buttonCounter].img_off;
	end;
	
	self.Buttons[self.buttonCounter].ov = Overlay:new(self.Buttons[self.buttonCounter].img_active,self.Buttons[self.buttonCounter].posX ,self.Buttons[self.buttonCounter].posY , self.buttonWidth, self.buttonHeight);
	

end;

function AutoDriveHud:updateButtons(vehicle)
	for _,button in pairs(self.Buttons) do
		if button.name == "input_silomode" then
			local buttonImg = "";
			
			if vehicle.ad.mode == AutoDrive.MODE_PICKUPANDDELIVER or vehicle.ad.mode == AutoDrive.MODE_DELIVERTO then 
				button.img_active = button.img_3;
			else
				button.img_active = button.img_off;
			end;
			
			button.ov = Overlay:new(button.img_active,button.posX ,button.posY , self.buttonWidth, self.buttonHeight);					
		end;
	
		if button.name == "input_record" then
			local buttonImg = "";
			if vehicle.ad.creationMode == true then
				button.img_active = button.img_on;
				if vehicle.ad.creationModeDual == true then
					button.img_active = button.img_dual;
				end;
			else
				button.img_active = button.img_off;
			end;
			button.ov = Overlay:new(button.img_active,button.posX ,button.posY , self.buttonWidth, self.buttonHeight);
		end;
		
		if button.name == "input_start_stop" then
			local buttonImg = "";
			if vehicle.ad.isActive == true then
				button.img_active = button.img_on;						
			else
				button.img_active = button.img_off;
			end;
			button.ov = Overlay:new(button.img_active,button.posX ,button.posY , self.buttonWidth, self.buttonHeight);
		end;		
		
		if button.name == "input_debug" then
			local buttonImg = "";
			if vehicle.ad.createMapPoints == true then
				button.img_active = button.img_on;						
			else
				button.img_active = button.img_off;
			end;
			button.ov = Overlay:new(button.img_active,button.posX ,button.posY , self.buttonWidth, self.buttonHeight);
		end;	
				
		if button.name == "input_showNeighbor" then


			if vehicle.ad.createMapPoints == true then
				button.isVisible = true
			else
				button.isVisible = false;
			end;

			local buttonImg = "";
			if vehicle.ad.showSelectedDebugPoint == true then
				button.img_active = button.img_on;						
			else
				button.img_active = button.img_off;
			end;
			button.ov = Overlay:new(button.img_active,button.posX ,button.posY , self.buttonWidth, self.buttonHeight);
		end;

		if button.name == "input_toggleConnection" then
			if vehicle.ad.createMapPoints == true then
				button.isVisible = true
			else
				button.isVisible = false;
			end;
		end;

		if button.name == "input_nextNeighbor" then
			if vehicle.ad.createMapPoints == true then
				button.isVisible = true
			else
				button.isVisible = false;
			end;
		end;

		if button.name == "input_createMapMarker" then
			if vehicle.ad.createMapPoints == true then
				button.isVisible = true
			else
				button.isVisible = false;
			end;
		end;

		if button.name == "input_exportRoutes" then
			if vehicle.ad.createMapPoints == true then
				button.isVisible = true
			else
				button.isVisible = false;
			end;
		end;
		
		if button.name == "input_recalculate" then
			local buttonImg = "";
			if AutoDrive:GetChanged() == true then
				button.isVisible = true;
			else
				button.isVisible = false;
			end;

			if AutoDrive.Recalculation ~= nil then
				if  AutoDrive.Recalculation.continue == true then
					button.img_active = button.img_off;
				else
					button.img_active = button.img_on;
				end;
			else
				button.img_active = button.img_on;
			end;

			button.ov = Overlay:new(button.img_active,button.posX ,button.posY , self.buttonWidth, self.buttonHeight);
		end;
		
		if button.name == "input_removeWaypoint" then
			local buttonImg = "";
			if vehicle.ad.createMapPoints == true then
				button.isVisible = true
				button.img_active = button.img_on;
			else
				button.isVisible = false;
				button.img_active = button.img_off;
			end;

			button.ov = Overlay:new(button.img_active,button.posX ,button.posY , self.buttonWidth, self.buttonHeight);
		end;
	end;

end;

function AutoDriveHud:updateSingleButton(buttonName, stateOn)
    for _,button in pairs(self.Buttons) do
        if button.name == buttonName then
            local buttonImg = "";
            if stateOn == true then
                button.img_active = button.img_on;
            else
                button.img_active = button.img_off;
            end;
            button.ov = Overlay:new(button.img_active,button.posX ,button.posY , self.buttonWidth, self.buttonHeight);
        end;
    end;
end;

function AutoDriveHud:drawHud(vehicle)	
	if vehicle == g_currentMission.controlledVehicle then		
        self:updateButtons(vehicle);
        
		local ovWidth = self.Background.width;
		local ovHeight = self.Background.height;

		if vehicle.ad.enteringMapMarker == true then
			ovHeight = ovHeight + 0.07;
		end;
		
		local buttonCounter = 0;
		for _,button in pairs(self.Buttons) do
			buttonCounter = buttonCounter + 1;
			if button.isVisible then
				self.rowCurrent = math.ceil(buttonCounter / self.cols);
			end;
		end;
		ovHeight = ovHeight + (self.rowCurrent-2) * 0.05;
		
		self.Background.Header.posY = self.posY + ovHeight - self.Background.Header.height;
		self.Background.Header.ov = Overlay:new(self.Background.Header.img, self.Background.Header.posX, self.Background.Header.posY , self.Background.Header.width, self.Background.Header.height);
		self.Background.close_small.posY = self.posY + ovHeight - 0.0101* (g_screenWidth / g_screenHeight);
		self.Background.close_small.ov = Overlay:new(self.Background.close_small.img, self.Background.close_small.posX, self.Background.close_small.posY , self.Background.close_small.width, self.Background.close_small.height);
		self.Background.ov = Overlay:new(AutoDrive.directory .. "img/Background.dds", self.posX, self.posY , self.width, ovHeight);
		self.Background.ov:render();
		self.Background.destination.ov:render();
		self.Background.Header.ov:render();
		self.Background.speedmeter.ov:render();
		self.Background.divider.ov:render();
		self.Background.close_small.ov:render();
		self.Background.unloadOverlay.ov:render();		
		
		for _,button in pairs(self.Buttons) do
			if button.isVisible then
				button.ov:render();
			end;
		end;

		local adFontSize = 0.009;
		local adPosX = self.posX + self.borderX;
		local adPosY = self.posY + ovHeight - adFontSize - 0.002;

		setTextColor(1,1,1,1);
		setTextAlignment(RenderText.ALIGN_LEFT);
		local textToShow = "AutoDrive";
		textToShow = textToShow .. " - " .. AutoDriveHud:getModeName(vehicle);
		if vehicle.ad.sToolTip ~= "" and vehicle.ad.nToolTipWait <= 0 then
			--setTextAlignment(RenderText.ALIGN_LEFT);
			--local posX = adPosX + 0.025;
			--renderText(posX, adPosY, adFontSize," - " .. vehicle.ad.sToolTip);
			textToShow = textToShow .. " - " .. vehicle.ad.sToolTip;
		end;
		renderText(adPosX, adPosY, adFontSize, textToShow);
		
		if vehicle.ad.nameOfSelectedTarget ~= nil then
			local adFontSize = 0.013;
			local adPosX = self.posX + self.Background.destination.width;
			--local adPosY = self.posY + (0.0225 * (g_screenWidth / g_screenHeight)) + (self.borderY + self.buttonHeight) * self.rowCurrent;
			local adPosY = self.Background.destination.posY + (self.Background.destination.height/2) - (adFontSize/2);

			if vehicle.ad.choosingDestination == true then
				if vehicle.ad.chosenDestination ~= "" then
					setTextColor(1,1,1,1);
					setTextAlignment(RenderText.ALIGN_LEFT);
					renderText(adPosX, adPosY, adFontSize, vehicle.ad.nameOfSelectedTarget);
				end;
				if vehicle.ad.enteredChosenDestination ~= "" then
					setTextColor(1,0,0,1);
					setTextAlignment(RenderText.ALIGN_LEFT);
					renderText(adPosX, adPosY, adFontSize,  vehicle.ad.enteredChosenDestination);
				end;
			else
				setTextColor(1,1,1,1);
				setTextAlignment(RenderText.ALIGN_LEFT);
				renderText(adPosX, adPosY, adFontSize, vehicle.ad.nameOfSelectedTarget);
			end;
			setTextColor(1,1,1,1);
			setTextAlignment(RenderText.ALIGN_LEFT);
			local posX = self.posX - 0.012 + self.width
			renderText(posX, adPosY, adFontSize, "" .. vehicle.ad.targetSpeed);
		end;

		if vehicle.ad.enteringMapMarker == true then
			local adFontSize = 0.012;
			local adPosX = self.posX + self.borderX;
			local adPosY = self.posY + 0.085 + (self.borderY + self.buttonHeight) * self.rowCurrent;
			setTextColor(1,1,1,1);
			setTextAlignment(RenderText.ALIGN_LEFT);
			local posY = adPosY + (0.01125 * (g_screenWidth / g_screenHeight));
			renderText(adPosX, posY, adFontSize, g_i18n:getText("AD_new_marker_helptext"));
			renderText(adPosX, adPosY, adFontSize, g_i18n:getText("AD_new_marker") .. " " .. vehicle.ad.enteredMapMarkerString);
		end;

		if vehicle.ad.mode == AutoDrive.MODE_PICKUPANDDELIVER then
			local adFontSize = 0.013;
			local adPosX = self.posX + self.Background.destination.width;
			local adPosY = self.Background.unloadOverlay.posY + (self.Background.unloadOverlay.height/2) - (adFontSize/2); --self.posY + 0.008 + (self.borderY + self.buttonHeight) * self.rowCurrent;
			setTextColor(1,1,1,1);

			self.Background.unloadOverlay.ov:render();
			setTextAlignment(RenderText.ALIGN_LEFT);
			renderText(adPosX, adPosY, adFontSize, vehicle.ad.nameOfSelectedTarget_Unload .. " - " .. g_fillTypeManager:getFillTypeByIndex(vehicle.ad.unloadFillTypeIndex).title);
		end;		
	end;	
end;

function AutoDriveHud:drawMinimalHud(vehicle)	
	if vehicle == g_currentMission.controlledVehicle then								
		if vehicle.ad.nameOfSelectedTarget ~= nil then
			if vehicle.ad.lastPrintedTarget == nil then
				vehicle.ad.lastPrintedTarget = vehicle.ad.nameOfSelectedTarget;
			end;
			if vehicle.ad.lastPrintedTarget ~= vehicle.ad.nameOfSelectedTarget then
				vehicle.ad.destinationPrintTimer = 4000;
				vehicle.ad.lastPrintedTarget = vehicle.ad.nameOfSelectedTarget;
			end;

			local adFontSize = 0.013;
			local adPosX = self.posX + self.Background.destination.width;
			local adPosY = self.Background.destination.posY + (self.Background.destination.height/2) - (adFontSize/2);

			if vehicle.ad.destinationPrintTimer > 0 or vehicle.ad.isActive then
				if vehicle.ad.isActive then
					setTextColor(0,1,0,1);
				else
					setTextColor(1,1,1,1);
				end;
				setTextAlignment(RenderText.ALIGN_LEFT);
				renderText(adPosX, adPosY, adFontSize, vehicle.ad.nameOfSelectedTarget);
			end;
		end;
	end;
end;

function AutoDriveHud:toggleHud(vehicle)
    if self.showHud == false then
		self.showHud = true;		
		vehicle.ad.showingHud = true;
    else
		if AutoDrive.showMouse then
			AutoDrive.Hud:toggleMouse(vehicle);
		end;
		self.showHud = false;
		vehicle.ad.showingHud = false;
    end;
end;

function AutoDriveHud:toggleMouse(vehicle)
    if self.showHud == true then
        if AutoDrive.showMouse == false then
			AutoDrive.showMouse = true;		
			vehicle.ad.showingMouse = true;			            
            g_inputBinding:setShowMouseCursor(true);
            vehicle.ad.camerasBackup = {};
            if vehicle.spec_enterable ~= nil then
                if vehicle.spec_enterable.cameras ~= nil then
                    for camIndex, camera in pairs(vehicle.spec_enterable.cameras) do
                        camera.allowTranslation = false;
                        camera.isRotatable = false;
                    end;
                end;
            end;
        else
            g_inputBinding:setShowMouseCursor(false);
            AutoDrive.showMouse = false;	
			vehicle.ad.showingMouse = false;				            
            if vehicle.spec_enterable ~= nil then
                if vehicle.spec_enterable.cameras ~= nil then
                    for camIndex, camera in pairs(vehicle.spec_enterable.cameras) do
                        camera.allowTranslation = true;
                        camera.isRotatable = true;
                    end;
                end;
            end;
        end;
    end;
end;

function AutoDriveHud:mouseEvent(vehicle, posX, posY, isDown, isUp, button)
	if AutoDrive.showMouse then
        local buttonHovered = false;
        for _,button in pairs(self.Buttons) do
			if posX > button.posX and posX < (button.posX + button.width) and posY > button.posY and posY < (button.posY + button.height) and button.isVisible then
                --print("Clicked button " .. button.name);
                if vehicle.ad.sToolTip ~= button.toolTip then
                    vehicle.ad.sToolTip = button.toolTip;
                    vehicle.ad.nToolTipTimer = 6000;
                    vehicle.ad.nToolTipWait = 300;
                end;
                buttonHovered = true;
            end;
        end;

        if not buttonHovered then
            vehicle.ad.sToolTip = "";
		end;
		
		if self.isMoving then
			if button == 1 and isUp then
				self:stopMovingHud();
			else
				self:moveHud(posX, posY);
			end;
		end;		
	end;
		
    if AutoDrive.showMouse and button == 1 and isDown then        
        for _,button in pairs(self.Buttons) do            
            if posX > button.posX and posX < (button.posX + button.width) and posY > button.posY and posY < (button.posY + button.height) and button.isVisible then
                AutoDrive:InputHandling(vehicle, button.name);
            end;            
        end;

        local adPosX = self.posX + self.Background.destination.width;
        local adPosY = self.posY + 0.04 + (self.borderY + self.buttonHeight) * self.rowCurrent;
        local height = 0.015;
        local width = 0.05;
        if posX > (adPosX) and posX < (adPosX + width) and posY > (adPosY) and posY < (adPosY + height) then
            if vehicle.ad.choosingDestination == false then
                vehicle.ad.choosingDestination = true
                g_currentMission.isPlayerFrozen = true;
				vehicle.isBroken = true;
				--print("Entering destination - player frozen and vehicle broken")
				g_inputBinding:setContext("AutoDrive.Input_Destination", true, false);
            else
                vehicle.ad.choosingDestination = false;
                g_currentMission.isPlayerFrozen = false;
				vehicle.isBroken = false;
				g_inputBinding:revertContext(true);
            end;
		end;
		
		if posX > (self.Background.Header.posX) and posX < (self.Background.Header.posX + self.Background.Header.width) and posY > (self.Background.Header.posY) and posY < (self.Background.Header.posY + self.Background.Header.height) then
			if posX > (self.Background.close_small.posX) and posX < (self.Background.close_small.posX + self.Background.close_small.width) and posY > (self.Background.close_small.posY) and posY < (self.Background.close_small.posY + self.Background.close_small.height) then
				AutoDrive.Hud:toggleHud(vehicle);
			else
				self:startMovingHud(posX, posY);				
			end;
		end;
		
		if posX > (self.Background.unloadOverlay.posX) and posX < (self.Background.unloadOverlay.posX + self.Background.Header.width) and posY > (self.Background.unloadOverlay.posY) and posY < (self.Background.Header.posY + self.Background.Header.height) then
			AutoDrive:InputHandling(vehicle, "input_nextFillType");
        end;
	end;
	
	if AutoDrive.showMouse and button == 3 and isDown then   
		if posX > (self.Background.unloadOverlay.posX) and posX < (self.Background.unloadOverlay.posX + self.Background.Header.width) and posY > (self.Background.unloadOverlay.posY) and posY < (self.Background.Header.posY + self.Background.Header.height) then
			AutoDrive:InputHandling(vehicle, "input_previousFillType");
        end;
	end;
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
	end;

	return "";
end;