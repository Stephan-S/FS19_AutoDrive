AutoDriveHud = {}

function AutoDriveHud:new()
    o = {}
    setmetatable(o, self)
    self.__index = self
    return o
end;

function AutoDriveHud:loadHud()		
	self.Speed = "40";
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
	
	
	self.posX = 0.80468750145519;
	self.posY = 0.207;
	self.width = 0.176;
	self.height = 0.13  + 0.015;
	self.borderX = 0.004;
	self.borderY = self.borderX * (g_screenWidth / g_screenHeight);
	
	self.buttonWidth = 0.015;
	self.buttonHeight = self.buttonWidth * (g_screenWidth / g_screenHeight);
	
	self.Background.img = AutoDrive.directory .. "img/Background.dds";
	self.Background.ov = Overlay:new(AutoDrive.directory .. "img/Background.dds", self.posX, self.posY , self.width, self.height);
	self.Background.posX = self.posX;
	self.Background.posY = self.posY;
	self.Background.width = self.width;
	self.Background.height = self.height;

	self.Background.unloadOverlay = {};
	self.Background.unloadOverlay.posX = self.posX + 0.0025;
	self.Background.unloadOverlay.posY = self.posY + self.height - 0.074;
	self.Background.unloadOverlay.width = 0.015;
	self.Background.unloadOverlay.height = self.Background.unloadOverlay.width * (g_screenWidth / g_screenHeight);
	self.Background.unloadOverlay.img = AutoDrive.directory .. "img/tipper_overlay.dds";
	self.Background.unloadOverlay.ov = Overlay:new(self.Background.unloadOverlay.img, self.Background.unloadOverlay.posX, self.Background.unloadOverlay.posY , self.Background.unloadOverlay.width, self.Background.unloadOverlay.height);

	self.Background.Header = {};
	self.Background.Header.img = AutoDrive.directory .. "img/Header.dds";
	self.Background.Header.width = self.width;
	self.Background.Header.height = 0.016;
	self.Background.Header.posX = self.posX;
	self.Background.Header.posY = self.posY + self.height - self.Background.Header.height;
	self.Background.Header.ov = Overlay:new(self.Background.Header.img, self.Background.Header.posX, self.Background.Header.posY , self.Background.Header.width, self.Background.Header.height);

	self.Background.destination = {};
	self.Background.destination.img = AutoDrive.directory .. "img/destination.dds";
	self.Background.destination.width = 0.018;
	self.Background.destination.height = self.Background.destination.width * (g_screenWidth / g_screenHeight);
	self.Background.destination.posX = self.posX;
	self.Background.destination.posY = self.posY + self.height - self.Background.Header.height - self.Background.destination.height - 0.001;
	self.Background.destination.ov = Overlay:new(self.Background.destination.img, self.Background.destination.posX, self.Background.destination.posY , self.Background.destination.width, self.Background.destination.height);

	self.Background.speedmeter = {};
	self.Background.speedmeter.img = AutoDrive.directory .. "img/speedmeter.dds";
	self.Background.speedmeter.width = 0.019;
	self.Background.speedmeter.height = self.Background.speedmeter.width * (g_screenWidth / g_screenHeight);
	self.Background.speedmeter.posX = self.posX + self.width - 0.04;
	self.Background.speedmeter.posY = self.posY + self.height - self.Background.Header.height - self.Background.speedmeter.height + 0.001;
	self.Background.speedmeter.ov = Overlay:new(self.Background.speedmeter.img, self.Background.speedmeter.posX, self.Background.speedmeter.posY , self.Background.speedmeter.width, self.Background.speedmeter.height);

	self.Background.close_small = {};
	self.Background.close_small.img = AutoDrive.directory .. "img/close_small.dds";
	self.Background.close_small.width = 0.01;
	self.Background.close_small.height = self.Background.close_small.width * (g_screenWidth / g_screenHeight);
	self.Background.close_small.posX = self.posX + self.width - 0.0101;
	self.Background.close_small.posY = self.posY + self.height - 0.0101* (g_screenWidth / g_screenHeight);
	self.Background.close_small.ov = Overlay:new(self.Background.close_small.img, self.Background.close_small.posX, self.Background.close_small.posY , self.Background.close_small.width, self.Background.close_small.height);

	self.Background.divider = {};
	self.Background.divider.img = AutoDrive.directory .. "img/divider.dds";
	self.Background.divider.width = self.width;
	self.Background.divider.height = 0.001
	self.Background.divider.posX = self.posX;
	self.Background.divider.posY = self.posY + self.Background.height - 0.045;
	self.Background.divider.ov = Overlay:new(self.Background.divider.img, self.Background.divider.posX, self.Background.divider.posY , self.Background.divider.width, self.Background.divider.height);

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
			if vehicle.bReverseTrack == true then
				button.img_active = button.img_on;						
			else
				if vehicle.bUnloadAtTrigger == true then
					button.img_active = button.img_3;
				else
					button.img_active = button.img_off;
				end;
			end;
			
			button.ov = Overlay:new(button.img_active,button.posX ,button.posY , self.buttonWidth, self.buttonHeight);					
		end;
	
		if button.name == "input_record" then
			local buttonImg = "";
			if vehicle.bcreateMode == true then
				button.img_active = button.img_on;
				if vehicle.bcreateModeDual == true then
					button.img_active = button.img_dual;
				end;
			else
				button.img_active = button.img_off;
			end;
			button.ov = Overlay:new(button.img_active,button.posX ,button.posY , self.buttonWidth, self.buttonHeight);
		end;
		
		if button.name == "input_start_stop" then
			local buttonImg = "";
			if vehicle.bActive == true then
				button.img_active = button.img_on;						
			else
				button.img_active = button.img_off;
			end;
			button.ov = Overlay:new(button.img_active,button.posX ,button.posY , self.buttonWidth, self.buttonHeight);
		end;		
		
		if button.name == "input_debug" then
			local buttonImg = "";
			if vehicle.bCreateMapPoints == true then
				button.img_active = button.img_on;						
			else
				button.img_active = button.img_off;
			end;
			button.ov = Overlay:new(button.img_active,button.posX ,button.posY , self.buttonWidth, self.buttonHeight);
		end;	
				
		if button.name == "input_showNeighbor" then


			if vehicle.bCreateMapPoints == true then
				button.isVisible = true
			else
				button.isVisible = false;
			end;

			local buttonImg = "";
			if vehicle.bShowSelectedDebugPoint == true then
				button.img_active = button.img_on;						
			else
				button.img_active = button.img_off;
			end;
			button.ov = Overlay:new(button.img_active,button.posX ,button.posY , self.buttonWidth, self.buttonHeight);
		end;

		if button.name == "input_toggleConnection" then
			if vehicle.bCreateMapPoints == true then
				button.isVisible = true
			else
				button.isVisible = false;
			end;
		end;

		if button.name == "input_nextNeighbor" then
			if vehicle.bCreateMapPoints == true then
				button.isVisible = true
			else
				button.isVisible = false;
			end;
		end;

		if button.name == "input_createMapMarker" then
			if vehicle.bCreateMapPoints == true then
				button.isVisible = true
			else
				button.isVisible = false;
			end;
		end;

		if button.name == "input_exportRoutes" then
			if vehicle.bCreateMapPoints == true then
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
			if vehicle.bCreateMapPoints == true then
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

		if vehicle.bEnteringMapMarker == true then
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

		if true then
			local adFontSize = 0.009;
			local adPosX = self.posX + self.borderX;
			local adPosY = self.posY + ovHeight - adFontSize - 0.002;

			setTextColor(1,1,1,1);
			renderText(adPosX, adPosY, adFontSize,"AutoDrive");
			if vehicle.ad.sToolTip ~= "" and vehicle.ad.nToolTipWait <= 0 then
				renderText(adPosX + 0.03, adPosY, adFontSize," - " .. vehicle.ad.sToolTip);
			end;
		end;
		
		if vehicle.sTargetSelected ~= nil then
			local adFontSize = 0.013;
			local adPosX = self.posX + self.Background.destination.width;
			local adPosY = self.posY + 0.04 + (self.borderY + self.buttonHeight) * self.rowCurrent;

			if vehicle.bChoosingDestination == true then
				if vehicle.sChosenDestination ~= "" then
					setTextColor(1,1,1,1);
					renderText(adPosX, adPosY, adFontSize, vehicle.sTargetSelected);
				end;
				if vehicle.sEnteredChosenDestination ~= "" then
					setTextColor(1,0,0,1);
					renderText(adPosX, adPosY, adFontSize,  vehicle.sEnteredChosenDestination);
				end;
			else
				setTextColor(1,1,1,1);
				renderText(adPosX, adPosY, adFontSize, vehicle.sTargetSelected);
			end;
			setTextColor(1,1,1,1);
			renderText(self.posX - 0.012 + self.width, adPosY, adFontSize, "" .. vehicle.nSpeed);
		end;

		if vehicle.bEnteringMapMarker == true then
			local adFontSize = 0.012;
			local adPosX = self.posX + self.borderX;
			local adPosY = self.posY + 0.085 + (self.borderY + self.buttonHeight) * self.rowCurrent;
			setTextColor(1,1,1,1);
			renderText(adPosX, adPosY + 0.02, adFontSize, g_i18n:getText("AD_new_marker_helptext"));
			renderText(adPosX, adPosY, adFontSize, g_i18n:getText("AD_new_marker") .. " " .. vehicle.sEnteredMapMarkerString);
		end;

		if vehicle.bUnloadAtTrigger == true then
			local adFontSize = 0.013;
			local adPosX = self.posX + self.Background.destination.width;
			local adPosY = self.posY + 0.008 + (self.borderY + self.buttonHeight) * self.rowCurrent;
			setTextColor(1,1,1,1);

			self.Background.unloadOverlay.ov:render();
			renderText(adPosX, adPosY, adFontSize, vehicle.sTargetSelected_Unload);
		end;		
	end;	
end;

function AutoDriveHud:toggleHud()
    if self.showHud == false then
        self.showHud = true;
    else
        self.showHud = false;
        if AutoDrive.showMouse == false then
            AutoDrive.showMouse = true;
            g_inputBinding:setShowMouseCursor(true);
        else
            g_inputBinding:setShowMouseCursor(false);
            AutoDrive.showMouse = false;
        end;
    end;
end;

function AutoDriveHud:toggleMouse()
    if self.showHud == true then
        if AutoDrive.showMouse == false then
            AutoDrive.showMouse = true;					
            g_currentMission.isPlayerFrozen = true;
            
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
            g_currentMission.isPlayerFrozen = false;
            
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
	end;
		
    if AutoDrive.showMouse and button == 1 and isDown then        
        for _,button in pairs(self.Buttons) do            
            if posX > button.posX and posX < (button.posX + button.width) and posY > button.posY and posY < (button.posY + button.height) and button.isVisible then
                AutoDrive:InputHandling(vehicle, button.name);
            end;            
        end;

        if posX > (self.Background.close_small.posX) and posX < (self.Background.close_small.posX + self.Background.close_small.width) and posY > (self.Background.close_small.posY) and posY < (self.Background.close_small.posY + self.Background.close_small.height) then
            if self.showHud == false then
                self.showHud = true;
            else
                self.showHud = false;
                if AutoDrive.showMouse == false then
                    AutoDrive.showMouse = true;
                    g_inputBinding:setShowMouseCursor(true);
                else
                    g_inputBinding:setShowMouseCursor(false);
                    AutoDrive.showMouse = false;
                end;
            end;
        end;

        local adPosX = self.posX + self.Background.destination.width;
        local adPosY = self.posY + 0.04 + (self.borderY + self.buttonHeight) * self.rowCurrent;
        local height = 0.015;
        local width = 0.05;
        if posX > (adPosX) and posX < (adPosX + width) and posY > (adPosY) and posY < (adPosY + height) then
            if vehicle.bChoosingDestination == false then
                vehicle.bChoosingDestination = true
                vehicle.isBroken = false;
                g_currentMission.isPlayerFrozen = true;
                vehicle.isBroken = true;
            else
                vehicle.bChoosingDestination = false;
                g_currentMission.isPlayerFrozen = false;
                vehicle.isBroken = false;
            end;
        end;


    end;
end;	