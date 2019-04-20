--
-- Mod: AutoDrive_Register
--
-- Author: Stephan
-- email: Stephan910@web.de
-- @Date: 02.02.2019
-- @Version: 1.0.0.0 

-- #############################################################################

source(Utils.getFilename("scripts/AutoDrive.lua", g_currentModDirectory))
source(Utils.getFilename("scripts/AutoDriveHud.lua", g_currentModDirectory))
source(Utils.getFilename("scripts/Events/AutoDriveEventUtil.lua", AutoDrive.directory))
source(Utils.getFilename("scripts/Events/AutoDriveUpdateEvent.lua", AutoDrive.directory))
source(Utils.getFilename("scripts/Events/AutoDriveUpdateDestinationsEvent.lua", AutoDrive.directory))
source(Utils.getFilename("scripts/Events/AutoDriveCourseEditEvent.lua", AutoDrive.directory))
source(Utils.getFilename("scripts/Events/AutoDriveCourseDownloadEvent.lua", AutoDrive.directory))
source(Utils.getFilename("scripts/Events/AutoDriveCreateMapMarkerEvent.lua", AutoDrive.directory))
source(Utils.getFilename("scripts/Events/AutoDriveRequestWayPointEvent.lua", AutoDrive.directory))
source(Utils.getFilename("scripts/Events/AutoDriveAcknowledgeCourseUpdateEvent.lua", AutoDrive.directory))
source(Utils.getFilename("scripts/Events/AutoDriveUpdateSettingsEvent.lua", AutoDrive.directory))



AutoDrive_Register = {};
AutoDrive_Register.modDirectory = g_currentModDirectory;

local modDesc = loadXMLFile("modDesc", g_currentModDirectory .. "modDesc.xml");
AutoDrive_Register.version = getXMLString(modDesc, "modDesc.version");

if g_specializationManager:getSpecializationByName("AutoDrive") == nil then
	g_specializationManager:addSpecialization("AutoDrive", "AutoDrive", Utils.getFilename("scripts/AutoDrive.lua",  g_currentModDirectory), nil)
	
	local ADSpecName = g_currentModName .. ".AutoDrive"
	
	if AutoDrive == nil then 
	  print("ERROR: unable to add specialization 'AutoDrive'")
	else 
	  for i, typeDef in pairs(g_vehicleTypeManager.vehicleTypes) do
			if typeDef ~= nil and i ~= "locomotive" then 
				local isDrivable  = false
				local isEnterable = false
				local hasMotor    = false 
				for name, spec in pairs(typeDef.specializationsByName) do
					if name == "drivable"  then 
						isDrivable = true 
					elseif name == "motorized" then 
						hasMotor = true 
					elseif name == "enterable" then 
						isEnterable = true 
					end 
				end 
				
				if isDrivable and isEnterable and hasMotor then 
					print("INFO: attached specialization 'AutoDrive' to vehicleType '" .. tostring(i) .. "'")
					if typeDef.specializationsByName["AutoDrive"] == nil then
						--typeDef.specializationsByName["AutoDrive"] = AutoDrive
						--table.insert(typeDef.specializationNames, "AutoDrive")
						--table.insert(typeDef.specializations, AutoDrive)  
						g_vehicleTypeManager:addSpecialization(i, ADSpecName)
						typeDef.hasADSpec = true;
					end;
				end 
			end 
	  end   
	end 
end 
  
function AutoDrive_Register:loadMap(name)
	print("--> loaded AutoDrive version " .. self.version .. " (by Stephan) <--");
end;

function AutoDrive_Register:deleteMap()

end;

function AutoDrive_Register:keyEvent(unicode, sym, modifier, isDown)

end;

function AutoDrive_Register:mouseEvent(posX, posY, isDown, isUp, button)

end;

function AutoDrive_Register:update(dt)
	if AutoDrive ~= nil then
		AutoDrive.runThisFrame = false;
	end;
end;

function AutoDrive_Register:draw()

end;

addModEventListener(AutoDrive_Register);