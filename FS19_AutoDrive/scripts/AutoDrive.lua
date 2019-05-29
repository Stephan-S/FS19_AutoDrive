AutoDrive = {};
AutoDrive.Version = "1.0.2.4";
AutoDrive.config_changed = false;

AutoDrive.directory = g_currentModDirectory;
AutoDrive.actions   = { {'ADToggleMouse', true, 1}, {'ADToggleHud', true, 1}, {'ADEnDisable', true, 1}, {'ADSelectTarget', false, 0}, {'ADSelectPreviousTarget', false, 0},
						{'ADSelectTargetUnload', false, 0},	{'ADSelectPreviousTargetUnload', false, 0}, {'ADActivateDebug', false, 0}, {'ADDebugShowClosest', false, 0},
						{'ADDebugSelectNeighbor', false, 0}, {'ADDebugChangeNeighbor', false, 0}, {'ADDebugCreateConnection', false, 0}, {'ADDebugCreateMapMarker', false, 0},
						{'ADDebugDeleteWayPoint', false, 0},  {'ADDebugForceUpdate', false, 0}, {'ADDebugDeleteDestination', false, 3},  {'ADSilomode',false, 0}, {'ADOpenGUI', true, 2},
						{'ADCallDriver', false, 3}, {'ADSelectNextFillType', false, 0}, {'ADSelectPreviousFillType', false, 0}, {'ADRecord', false, 0}, 
						{'AD_export_routes', false, 0}, {'AD_import_routes', false, 0}, {'AD_upload_routes', false, 0}, {'ADGoToVehicle', false, 3} }

AutoDrive.drawHeight = 0.3;

AutoDrive.MODE_DRIVETO = 1;
AutoDrive.MODE_PICKUPANDDELIVER = 2;
AutoDrive.MODE_DELIVERTO = 3;
AutoDrive.MODE_UNLOAD = 4;

AutoDrive.WAYPOINTS_PER_PACKET = 25;

function AutoDrive:prerequisitesPresent(specializations)
    return true;
end;

function AutoDrive.registerEventListeners(vehicleType)    
	for _,n in pairs( { "load", "onUpdate", "onRegisterActionEvents", "onDelete", "onDraw", "onLeaveVehicle", "onPostLoad", "saveToXMLFile"} ) do
	  SpecializationUtil.registerEventListener(vehicleType, n, AutoDrive)
	end 
end

function AutoDrive:onRegisterActionEvents(isSelected, isOnActiveVehicle)   
	-- continue on client side only
	if not self.isClient then
		return
	end

	local registerEvents = isOnActiveVehicle;
	if self.ad ~= nil then
		registerEvents = registerEvents or self == g_currentMission.controlledVehicle; -- or self.ad.isActive;
	end;

	-- only in active vehicle
	if registerEvents then
		-- we could have more than one event, so prepare a table to store them  
		if self.ActionEvents == nil then 
		  self.ActionEvents = {}
		else  
		  --self:clearActionEventsTable( self.ActionEvents )
		end 

		-- attach our actions
		local __, eventName
		local toggleButton = false;
		local showF1Help = AutoDrive:getSetting("showHelp");
		for _, action in pairs(AutoDrive.actions) do
			__, eventName = InputBinding.registerActionEvent(g_inputBinding, action[1], self, AutoDrive.onActionCall, toggleButton ,true ,false ,true);
			g_inputBinding:setActionEventTextVisibility(eventName, action[2] and showF1Help);	
			if showF1Help then
				g_inputBinding:setActionEventTextPriority(eventName, action[3])
			end;
		end;
	end
end

function AutoDrive:onDelete()		
end;

function AutoDrive:loadMap(name)	
	source(Utils.getFilename("scripts/AutoDriveFunc.lua", AutoDrive.directory))
	source(Utils.getFilename("scripts/AutoDriveTrailerUtil.lua", AutoDrive.directory))
	source(Utils.getFilename("scripts/AutoDriveXML.lua", AutoDrive.directory))
	source(Utils.getFilename("scripts/AutoDriveInputFunctions.lua", AutoDrive.directory))
	source(Utils.getFilename("scripts/AutoDriveGraphHandling.lua", AutoDrive.directory))
	source(Utils.getFilename("scripts/AutoDriveLineDraw.lua", AutoDrive.directory))
	source(Utils.getFilename("scripts/AutoDriveDriveFuncs.lua", AutoDrive.directory))
	source(Utils.getFilename("scripts/AutoDriveKeyEvents.lua", AutoDrive.directory))
	source(Utils.getFilename("scripts/AutoDriveTrigger.lua", AutoDrive.directory))
	source(Utils.getFilename("scripts/AutoDriveDijkstra.lua", AutoDrive.directory))
	source(Utils.getFilename("scripts/AutoDriveUtilFuncs.lua", AutoDrive.directory))
	source(Utils.getFilename("scripts/AutoDriveMultiplayer.lua", AutoDrive.directory))
	source(Utils.getFilename("scripts/AutoDriveCombineMode.lua", AutoDrive.directory))
	source(Utils.getFilename("scripts/FieldDataCallback.lua", AutoDrive.directory))
	source(Utils.getFilename("scripts/AutoDrivePathFinder.lua", AutoDrive.directory))
	source(Utils.getFilename("scripts/PathFinderCallBack.lua", AutoDrive.directory))
	source(Utils.getFilename("scripts/AutoDriveSettings.lua", AutoDrive.directory))
	source(Utils.getFilename("scripts/AutoDriveExternalInterface.lua", AutoDrive.directory))
	source(Utils.getFilename("gui/settingsGui.lua", AutoDrive.directory))
	source(Utils.getFilename("gui/AutoDriveGUI.lua", AutoDrive.directory))

	if AutoDrive_printedDebug ~= true then
		print("Map title: " .. g_currentMission.missionInfo.map.title);		
		AutoDrive_printedDebug = true;
	end;
	
	AutoDrive.loadedMap = g_currentMission.missionInfo.map.title;
	AutoDrive.loadedMap = string.gsub(AutoDrive.loadedMap, " ", "_");
	AutoDrive.loadedMap = string.gsub(AutoDrive.loadedMap, "%.", "_");
	AutoDrive.loadedMap = string.gsub(AutoDrive.loadedMap, ",", "_");		
	AutoDrive.loadedMap = string.gsub(AutoDrive.loadedMap, ":", "_");	
	AutoDrive.loadedMap = string.gsub(AutoDrive.loadedMap, ";", "_");	
	print("map " .. AutoDrive.loadedMap .. " was loaded");		
		
	AutoDrive.mapWayPoints = {};
	AutoDrive.mapWayPointsCounter = 0;
	AutoDrive.mapMarker = {};
	AutoDrive.mapMarkerCounter = 0;
	AutoDrive.showMouse = false;					
		
	AutoDrive.lastSetSpeed = 50;

	AutoDrive.print = {};
	AutoDrive.print.currentMessage = nil;
	AutoDrive.print.referencedVehicle = nil;
	AutoDrive.print.nextMessage = nil;
	AutoDrive.print.showMessageFor = 12000;
	AutoDrive.print.currentMessageActiveSince = 0;
	AutoDrive.requestedWaypoints = false;
	AutoDrive.requestedWaypointCount = 1;
	AutoDrive.playerSendsMapToServer = false;

	AutoDrive.mouseWheelActive = false;

	AutoDrive:loadStoredXML();

	AutoDrive:initLineDrawing();
	
	AutoDrive.Hud = AutoDriveHud:new();
	AutoDrive.Hud:loadHud();

	AutoDrive:loadGUI();

	-- Save Configuration when saving savegame
	FSBaseMission.saveSavegame = Utils.appendedFunction(FSBaseMission.saveSavegame, AutoDrive.saveSavegame);
	
	LoadTrigger.onActivateObject = Utils.overwrittenFunction(LoadTrigger.onActivateObject,AutoDrive.onActivateObject)
	LoadTrigger.getIsActivatable = Utils.overwrittenFunction(LoadTrigger.getIsActivatable,AutoDrive.getIsActivatable)
	LoadTrigger.onFillTypeSelection = Utils.overwrittenFunction(LoadTrigger.onFillTypeSelection,AutoDrive.onFillTypeSelection)

	VehicleCamera.zoomSmoothly = Utils.overwrittenFunction(VehicleCamera.zoomSmoothly, AutoDrive.zoomSmoothly);
	
	if g_server ~= nil then
		AutoDrive.Server = {};
		AutoDrive.Server.Users = {};
	else
		AutoDrive.highestIndex = 1;
	end;

	AutoDrive.waitingUnloadDrivers = {}
end;

function AutoDrive:saveSavegame()
	if AutoDrive:GetChanged() == true or AutoDrive.HudChanged then
		AutoDrive:saveToXML(AutoDrive.adXml);	
		AutoDrive.config_changed = false;
		AutoDrive.HudChanged = false;
	else
		if AutoDrive.adXml ~= nil then
			saveXMLFile(AutoDrive.adXml);
		end;
	end;
end;

function init(self)
	if self.ad == nil then
		self.ad = {};		
	end;
	 
	self.ad.isActive = false;
	self.ad.isStopping = false;
	self.ad.drivingForward = true;
	self.ad.targetX = 0;
	self.ad.targetZ = 0;
	self.ad.initialized = false;
	self.ad.wayPoints = {};
	self.ad.wayPointsChanged = true;
	self.ad.creationMode = false;
	self.ad.creationModeDual = false;
	self.ad.currentWayPoint = 0;

	if AutoDrive ~= nil then
		local set = false;
		if self.ad.mapMarkerSelected ~= nil then
			if AutoDrive.mapMarker[self.ad.mapMarkerSelected] ~= nil then
				self.ad.targetSelected = AutoDrive.mapMarker[self.ad.mapMarkerSelected].id;
				self.ad.nameOfSelectedTarget = AutoDrive.mapMarker[self.ad.mapMarkerSelected].name;
				set = true;
			end;
		end;
		if not set then
			self.ad.mapMarkerSelected = 1;
			if AutoDrive.mapMarker[1] ~= nil then
				self.ad.targetSelected = AutoDrive.mapMarker[1].id;
				self.ad.nameOfSelectedTarget = AutoDrive.mapMarker[1].name;
			end;
		end;
	end;
	if self.ad.mode == nil then
		self.ad.mode = AutoDrive.MODE_DRIVETO;
	end;
	if self.ad.targetSpeed == nil then
		self.ad.targetSpeed = AutoDrive.lastSetSpeed;
	end;	
	self.ad.createMapPoints = false;
	self.ad.showClosestPoint = true;
	self.ad.selectedDebugPoint = -1;
	self.ad.showSelectedDebugPoint = false;
	self.ad.changeSelectedDebugPoint = false;
	self.ad.iteratedDebugPoints = {};
	self.ad.inDeadLock = false;
	self.ad.timeTillDeadLock = 15000;
	self.ad.inDeadLockRepairCounter = 4;
	
	self.ad.creatingMapMarker = false;
	self.ad.enteringMapMarker = false;
	self.ad.enteredMapMarkerString = "";
		
	self.name = g_i18n:getText("UNKNOWN")
	if self.getName ~= nil then
		self.name = self:getName();
	end;

	self.ad.moduleInitialized = true;
	self.ad.currentInput = "";
	self.ad.lastSpeed = self.ad.targetSpeed;
	self.ad.speedOverride = -1;

	self.ad.isUnloading = false;
	self.ad.isPaused = false;
	self.ad.unloadSwitch = false;
	self.ad.isLoading = false;
	if self.ad.unloadFillTypeIndex == nil then
		self.ad.unloadFillTypeIndex = 2;
	end;
	self.ad.isPausedCauseTraffic = false;
	self.ad.startedLoadingAtTrigger = false;
	self.ad.combineUnloadInFruit = false;
	self.ad.combineUnloadInFruitWaitTimer = AutoDrive.UNLOAD_WAIT_TIMER;	
	self.ad.combineFieldArea = nil;
	self.ad.combineFruitToCheck = nil; 
	self.ad.driverOnTheWay = false;
	self.ad.tryingToCallDriver = false;
	self.ad.stoppedTimer = 5000;

	AutoDrive.Recalculation = {};
	
	if AutoDrive ~= nil then
		local set = false;
		if self.ad.mapMarkerSelected_Unload ~= nil then
			if AutoDrive.mapMarker[self.ad.mapMarkerSelected_Unload] ~= nil then
				self.ad.targetSelected_Unload = AutoDrive.mapMarker[self.ad.mapMarkerSelected_Unload].id;
				self.ad.nameOfSelectedTarget_Unload = AutoDrive.mapMarker[self.ad.mapMarkerSelected_Unload].name;
				set = true;
			end;
		end;
		if not set then
			self.ad.mapMarkerSelected_Unload = 1;
			if AutoDrive.mapMarker[1] ~= nil then
				self.ad.targetSelected_Unload = AutoDrive.mapMarker[1].id;
				self.ad.nameOfSelectedTarget_Unload = AutoDrive.mapMarker[1].name;
			end;
		end;
	end;

	self.ad.nToolTipWait = 300;
	self.ad.nToolTipTimer = 6000;
	self.ad.sToolTip = "";

	self.ad.destinationPrintTimer = 0;
	self.ad.lastPrintedModeTimer = 0;
	
	self.ad.choosingDestination = false;
	self.ad.chosenDestination = "";
	self.ad.enteredChosenDestination = "";

	self.ad.choosingDestinationUnload = false;
	self.ad.chosenDestinationUnload = "";
	self.ad.enteredChosenDestinationUnload = "";

	if AutoDrive.showingHud ~= nil then
		self.ad.showingHud = AutoDrive.showingHud;
	else
		self.ad.showingHud = true;
	end;
	self.ad.showingMouse = false;

	self.ad.requestWayPointTimer = 10000;

	--variables the server sets so that the clients can act upon it:
	self.ad.disableAI = 0;
	self.ad.enableAI = 0;

	self.ad.combineState = AutoDrive.COMBINE_UNINITIALIZED;
	self.ad.currentCombine = nil;
	self.ad.currentDriver = nil;

	if AutoDrive.searchedTriggers ~= true then
		AutoDrive:getAllTriggers();
		AutoDrive.searchedTriggers = true;
	end;	

	if self.spec_autodrive == nil then
		self.spec_autodrive = AutoDrive;
	end;	
	
	self.ad.pullDownList = {};
	self.ad.pullDownList.active = false;
	self.ad.pullDownList.start = false;
	self.ad.pullDownList.destination = false;
	self.ad.pullDownList.fillType = false;
	self.ad.pullDownList.itemList = {};
	self.ad.pullDownList.selectedItem = nil;
	self.ad.pullDownList.posX = 0;
	self.ad.pullDownList.posY = 0;
	self.ad.pullDownList.width = 0;
	self.ad.pullDownList.height = 0;
end;

function AutoDrive:onLeaveVehicle()	
	local storedshowingHud = self.ad.showingHud;
	local storedMouse = self.ad.showingMouse;
	if (AutoDrive.showMouse) then
		AutoDrive.Hud:toggleMouse(self);
	end;
	self.ad.showingHud = storedshowingHud
	self.ad.showingMouse = storedMouse;
end;

function AutoDrive:mouseEvent(posX, posY, isDown, isUp, button)
	local vehicle = g_currentMission.controlledVehicle;

	if vehicle ~= nil and AutoDrive.Hud.showHud == true then
		AutoDrive.Hud:mouseEvent(vehicle, posX, posY, isDown, isUp, button);
	end;
end; 

function AutoDrive:keyEvent(unicode, sym, modifier, isDown) 
	local vehicle = g_currentMission.controlledVehicle

	if vehicle == nil or vehicle.ad == nil then
		return;
	end;
		
	AutoDrive:handleKeyEvents(vehicle, unicode, sym, modifier, isDown);
end; 

function AutoDrive:onUpdate(dt)
	if self.ad == nil or self.ad.moduleInitialized ~= true then
		init(self);
	end;

	if self.ad.currentInput ~= "" and self.isServer then
		AutoDrive:InputHandling(self, self.ad.currentInput);
	end;

	self.ad.closest = nil;
	
	AutoDrive:handleRecalculation(self);	
	AutoDrive:handleRecording(self);
	AutoDrive:handleDriving(self, dt);
	AutoDrive:handleYPositionIntegrityCheck(self);
	AutoDrive:handleClientIntegrity(self);
	AutoDrive:handleMultiplayer(self, dt);
	
	if self.typeName == "combineDrivable" then
		AutoDrive:handleCombineHarvester(self, dt)
	end;

	if self.ad.destinationPrintTimer > 0 then
		self.ad.destinationPrintTimer = self.ad.destinationPrintTimer - dt;
	end;

	if self.ad.lastPrintedModeTimer > 0 then
		self.ad.lastPrintedModeTimer = self.ad.lastPrintedModeTimer - dt;
	end;

	local driverWages = AutoDrive:getSetting("driverWages");
	local spec = self.spec_aiVehicle
  if self.isServer then
    if self:getIsAIActive() then
			local difficultyMultiplier = g_currentMission.missionInfo.buyPriceMultiplier;
			local price = -dt * difficultyMultiplier * (driverWages -1) * spec.pricePerMS
			g_currentMission:addMoney(price, spec.startedFarmId, MoneyType.AI, true)
		end;
	end;

	AutoDrive.runThisFrame = true;
end;

function AutoDrive:onDraw()
	if self.ad.moduleInitialized == false then
		return;
	end;

	if self.ad ~= nil then
		if self.ad.showingHud ~= AutoDrive.Hud.showHud then
			AutoDrive.Hud:toggleHud(self);
		end;
		if self.ad.showingMouse ~= AutoDrive.showMouse then
			AutoDrive.Hud:toggleMouse(self);
		end
	end;
	
	if self.ad.currentWayPoint > 0 and self.ad.wayPoints ~= nil then
		if self.ad.wayPoints[self.ad.currentWayPoint+1] ~= nil then
			AutoDrive:drawLine(self.ad.wayPoints[self.ad.currentWayPoint], self.ad.wayPoints[self.ad.currentWayPoint+1], 1, 1, 1, 1);
		end;
	end;

	if self == g_currentMission.controlledVehicle then
		AutoDrive:onDrawControlledVehicle(self);
	end;
	
	if self.ad.createMapPoints == true and self == g_currentMission.controlledVehicle then
		AutoDrive:onDrawCreationMode(self);
	end;
		
end; 

function AutoDrive:onDrawControlledVehicle(vehicle)
	AutoDrive:drawJobs();

	if AutoDrive.print.currentMessage ~= nil then
		local adFontSize = 0.016;
		local adPosX = 0.5; --0.03;
		local adPosY = 0.14; --0.975;
		setTextColor(1,1,0,1);
		setTextAlignment(RenderText.ALIGN_CENTER);
		renderText(adPosX, adPosY, adFontSize, AutoDrive.print.currentMessage);
	end;

	if AutoDrive.Hud ~= nil then
		if AutoDrive.Hud.showHud == true then
			AutoDrive.Hud:drawHud(vehicle);
		else
			AutoDrive.Hud:drawMinimalHud(vehicle);
		end;
	end;
end;

function AutoDrive:onDrawCreationMode(vehicle)
	local x1,y1,z1 = getWorldTranslation(vehicle.components[1].node);
	for i,point in pairs(AutoDrive.mapWayPoints) do
		local distance = AutoDrive:getDistance(point.x,point.z,x1,z1);
		if distance < 50 then
			if point.out ~= nil then
				for i2,neighbor in pairs(point.out) do
					local testDual = false;
					for _,incoming in pairs(point.incoming) do
						if incoming == neighbor then
							testDual = true;
						end;
					end;
					
					target = AutoDrive.mapWayPoints[neighbor];
					if target ~= nil then
						if testDual == true then
							AutoDrive:drawLine(point, AutoDrive.mapWayPoints[neighbor], 0, 0, 1, 1);
						else
							local deltaX = AutoDrive.mapWayPoints[neighbor].x - point.x
							local deltaY = AutoDrive.mapWayPoints[neighbor].y - point.y
							local deltaZ = AutoDrive.mapWayPoints[neighbor].z - point.z
							AutoDrive:drawLine(point, AutoDrive.mapWayPoints[neighbor], 0, 1, 0, 1);

							local vecX = point.x - AutoDrive.mapWayPoints[neighbor].x;
							local vecZ = point.z - AutoDrive.mapWayPoints[neighbor].z;

							local angleRad = math.atan2(vecZ, vecX);

							angleRad = normalizeAngle(angleRad);

							local arrowLength = 0.3;

							local arrowLeft = normalizeAngle(angleRad + math.rad(-20));
							local arrowRight = normalizeAngle(angleRad + math.rad(20));

							local arrowLeftX = AutoDrive.mapWayPoints[neighbor].x + math.cos(arrowLeft) * arrowLength;
							local arrowLeftZ = AutoDrive.mapWayPoints[neighbor].z + math.sin(arrowLeft) * arrowLength;

							local arrowRightX = AutoDrive.mapWayPoints[neighbor].x + math.cos(arrowRight) * arrowLength;
							local arrowRightZ = AutoDrive.mapWayPoints[neighbor].z + math.sin(arrowRight) * arrowLength;

							local arrowPointLeft = {};
							arrowPointLeft.x = arrowLeftX;
							arrowPointLeft.y = AutoDrive.mapWayPoints[neighbor].y;
							arrowPointLeft.z = arrowLeftZ;

							local arrowPointRight = {};
							arrowPointRight.x = arrowRightX;
							arrowPointRight.y = AutoDrive.mapWayPoints[neighbor].y;
							arrowPointRight.z = arrowRightZ;
							
							AutoDrive:drawLine(arrowPointLeft, AutoDrive.mapWayPoints[neighbor], 0, 1, 0, 1);
							AutoDrive:drawLine(arrowPointRight, AutoDrive.mapWayPoints[neighbor], 0, 1, 0, 1);
						end;
					end;
				end;
			end;
		end;

		if (ADTableLength(point.out) == 0) and (ADTableLength(point.incoming) == 0) then
			local node = createTransformGroup("X");
			setTranslation(node, point.x, point.y + 4 , point.z  );
			DebugUtil.drawDebugNode(node,"X");
		end;

	end;

	for markerID,marker in pairs(AutoDrive.mapMarker) do
		local x1,y1,z1 = getWorldTranslation(vehicle.components[1].node);
		local x2,y2,z2 = getWorldTranslation(marker.node);
		local distance = AutoDrive:getDistance(x2,z2,x1,z1);
		if distance < 50 then
			DebugUtil.drawDebugNode(marker.node,marker.name);
		end;
	end;

	if vehicle.ad.showClosestPoint == true and AutoDrive.mapWayPoints[1] ~= nil then
		local closest = AutoDrive:findClosestWayPoint(vehicle);
		local x1,y1,z1 = getWorldTranslation(vehicle.components[1].node);
		
		if vehicle.ad.showClosestPoint == true then					
			AutoDrive:drawLine(AutoDrive:createVector(x1,y1+4,z1), AutoDrive.mapWayPoints[closest], 1, 0, 0, 1);
		end;
	end;

	if vehicle.ad.showSelectedDebugPoint == true and AutoDrive.mapWayPoints[1] ~= nil then
		local closest = AutoDrive:findClosestWayPoint(vehicle);
		local x1,y1,z1 = getWorldTranslation(vehicle.components[1].node);
		if vehicle.ad.showSelectedDebugPoint == true then
			if vehicle.ad.iteratedDebugPoints[vehicle.ad.selectedDebugPoint] ~= nil then
				AutoDrive:drawLine(AutoDrive:createVector(x1,y1+4,z1), vehicle.ad.iteratedDebugPoints[vehicle.ad.selectedDebugPoint], 1, 1, 0, 1);
			end;
		end;
	end;
end;

function AutoDrive:MarkChanged()
	AutoDrive.config_changed = true;
	AutoDrive.handledRecalculation = false;
end;

function AutoDrive:GetChanged()
	return AutoDrive.config_changed;
end;

function AutoDrive:onPostLoad(savegame)
	if self.isServer then
		if savegame ~= nil then
      local xmlFile = savegame.xmlFile
			local key     = savegame.key ..".FS19_AutoDrive.AutoDrive"
			
			if self.ad == nil then
				self.ad = {};
			end;
			
			local mode = getXMLInt(xmlFile, key.."#mode");
			if mode  ~= nil then
				self.ad.mode = mode;
			end;
			local targetSpeed = getXMLInt(xmlFile, key.."#targetSpeed")
			if targetSpeed ~= nil then
				self.ad.targetSpeed = targetSpeed;
			end;

			self.ad.targetSelected = -1;	
			self.ad.mapMarkerSelected = -1;
			self.ad.nameOfSelectedTarget = "";

  		local mapMarkerSelected = getXMLInt(xmlFile, key.."#mapMarkerSelected");
			if mapMarkerSelected ~= nil then
				self.ad.mapMarkerSelected = mapMarkerSelected;
			end;

			self.ad.targetSelected_Unload = -1;
			self.ad.mapMarkerSelected_Unload = -1;
			self.ad.nameOfSelectedTarget_Unload = "";

			local mapMarkerSelected_Unload = getXMLInt(xmlFile, key.."#mapMarkerSelected_Unload");
			if mapMarkerSelected_Unload ~= nil then
				self.ad.mapMarkerSelected_Unload = mapMarkerSelected_Unload;
			end;      
			local unloadFillTypeIndex = getXMLInt(xmlFile, key.."#unloadFillTypeIndex");
			if unloadFillTypeIndex ~= nil then
				self.ad.unloadFillTypeIndex = unloadFillTypeIndex;
			end;   
    end
	end;
end;

function AutoDrive:saveToXMLFile(xmlFile, key)
	setXMLInt(xmlFile, key.."#mode", 											self.ad.mode)
  setXMLInt(xmlFile, key.."#targetSpeed", 							self.ad.targetSpeed)
  setXMLInt(xmlFile, key.."#mapMarkerSelected",        	self.ad.mapMarkerSelected);
	setXMLInt(xmlFile, key.."#mapMarkerSelected_Unload", 	self.ad.mapMarkerSelected_Unload);
	setXMLInt(xmlFile, key.."#unloadFillTypeIndex", 			self.ad.unloadFillTypeIndex);
end

function AutoDrive.zoomSmoothly(self, superFunc, offset)
	if not AutoDrive.mouseWheelActive then -- don't zoom camera when mouse wheel is used to scroll targets (thanks to sperrgebiet)
		superFunc(self, offset);
	end
end

function normalizeAngle(inputAngle)
	if inputAngle > (2*math.pi) then
			inputAngle = inputAngle - (2*math.pi);	
	else
			if inputAngle < -(2*math.pi) then
				inputAngle = inputAngle + (2*math.pi);
			end;
	end;

	return inputAngle;
end;

function normalizeAngle2(inputAngle)
	if inputAngle > (2*math.pi) then
			inputAngle = inputAngle - (2*math.pi);	
	else
			if inputAngle < 0 then
				inputAngle = inputAngle + (2*math.pi);
			end;
	end;

	return inputAngle;
end;

function normalizeAngleToPlusMinusPI(inputAngle)
	if inputAngle > (math.pi) then
			inputAngle = inputAngle - (2*math.pi);	
	else
			if inputAngle < -(math.pi) then
				inputAngle = inputAngle + (2*math.pi);
			end;
	end;

	return inputAngle;
end;

addModEventListener(AutoDrive);