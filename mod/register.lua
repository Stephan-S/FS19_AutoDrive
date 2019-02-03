--
-- Mod: AutoDrive_Register
--
-- Author: Stephan
-- email: Stephan910@web.de
-- @Date: 02.02.2019
-- @Version: 1.0.0.0 

-- #############################################################################

source(Utils.getFilename("AutoDrive.lua", g_currentModDirectory))
source(Utils.getFilename("AutoDriveHud.lua", g_currentModDirectory))

AutoDrive_Register = {};
AutoDrive_Register.modDirectory = g_currentModDirectory;

local modDesc = loadXMLFile("modDesc", g_currentModDirectory .. "modDesc.xml");
AutoDrive_Register.version = getXMLString(modDesc, "modDesc.version");

if g_specializationManager:getSpecializationByName("AutoDrive") == nil then
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
			typeDef.specializationsByName["AutoDrive"] = AutoDrive
			table.insert(typeDef.specializationNames, "AutoDrive")
			table.insert(typeDef.specializations, AutoDrive)  
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
	  
  end;
  
  function AutoDrive_Register:draw()
	
  end;
  
  addModEventListener(AutoDrive_Register);