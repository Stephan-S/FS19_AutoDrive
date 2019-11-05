--
-- Mod: AutoDrive_Register
--
-- Author: Stephan
-- Email: Stephan910@web.de
-- Date: 02.02.2019
-- Version: 1.0.0.0

-- #############################################################################

source(Utils.getFilename("scripts/AutoDrive.lua", g_currentModDirectory))
source(Utils.getFilename("scripts/AutoDriveDelayedCallBack.lua", g_currentModDirectory))
source(Utils.getFilename("scripts/HudElements/GenericHudElement.lua", g_currentModDirectory))
source(Utils.getFilename("scripts/HudElements/HudButton.lua", g_currentModDirectory))
source(Utils.getFilename("scripts/HudElements/HudIcon.lua", g_currentModDirectory))
source(Utils.getFilename("scripts/HudElements/HudSpeedmeter.lua", g_currentModDirectory))
source(Utils.getFilename("scripts/HudElements/PullDownList.lua", g_currentModDirectory))
source(Utils.getFilename("scripts/AutoDriveHud.lua", g_currentModDirectory))
source(Utils.getFilename("scripts/Events/AutoDriveEventUtil.lua", g_currentModDirectory))
source(Utils.getFilename("scripts/Events/AutoDriveUpdateEvent.lua", g_currentModDirectory))
source(Utils.getFilename("scripts/Events/AutoDriveUpdateDestinationsEvent.lua", g_currentModDirectory))
source(Utils.getFilename("scripts/Events/AutoDriveCourseEditEvent.lua", g_currentModDirectory))
source(Utils.getFilename("scripts/Events/AutoDriveCourseDownloadEvent.lua", g_currentModDirectory))
source(Utils.getFilename("scripts/Events/AutoDriveGroupsEvent.lua", g_currentModDirectory))
source(Utils.getFilename("scripts/Events/AutoDriveCreateMapMarkerEvent.lua", g_currentModDirectory))
source(Utils.getFilename("scripts/Events/AutoDriveDeleteMapMarkerEvent.lua", g_currentModDirectory))
source(Utils.getFilename("scripts/Events/AutoDriveRenameMapMarkerEvent.lua", g_currentModDirectory))
source(Utils.getFilename("scripts/Events/AutoDriveChangeMapMarkerGroupEvent.lua", g_currentModDirectory))
source(Utils.getFilename("scripts/Events/AutoDriveDeleteWayPoint.lua", g_currentModDirectory))
source(Utils.getFilename("scripts/Events/AutoDriveRequestWayPointEvent.lua", g_currentModDirectory))
source(Utils.getFilename("scripts/Events/AutoDriveAcknowledgeCourseUpdateEvent.lua", g_currentModDirectory))
source(Utils.getFilename("scripts/Events/AutoDriveUpdateSettingsEvent.lua", g_currentModDirectory))
source(Utils.getFilename("scripts/Events/AutoDriveRenameDriverEvent.lua", g_currentModDirectory))

AutoDrive_Register = {}
AutoDrive_Register.modDirectory = g_currentModDirectory

AutoDrive_Register.version = g_modManager:getModByName(g_currentModName).version

if g_specializationManager:getSpecializationByName("AutoDrive") == nil then
	g_specializationManager:addSpecialization("AutoDrive", "AutoDrive", Utils.getFilename("scripts/AutoDrive.lua", g_currentModDirectory), nil)

	if AutoDrive == nil then
		print("ERROR: Unable to add specialization 'AutoDrive'")
		return
	end

	local ADSpecName = g_currentModName .. ".AutoDrive"

	for i, typeDef in pairs(g_vehicleTypeManager.vehicleTypes) do
		if typeDef ~= nil and i ~= "locomotive" then
			if AutoDrive.prerequisitesPresent(typeDef.specializations) then
				print(string.format("  Attached AutoDrive to vehicleType %s", i))
				if typeDef.specializationsByName["AutoDrive"] == nil then
					g_vehicleTypeManager:addSpecialization(i, ADSpecName)
					typeDef.hasADSpec = true
				end
			end
		end
	end
end

function AutoDrive_Register:loadMap(name)
	print(string.format("--> Loaded AutoDrive v%s (by Stephan) <--", self.version))
end

function AutoDrive_Register:deleteMap()
end

function AutoDrive_Register:keyEvent(unicode, sym, modifier, isDown)
end

function AutoDrive_Register:mouseEvent(posX, posY, isDown, isUp, button)
end

function AutoDrive_Register:update(dt)
	if AutoDrive ~= nil then
		AutoDrive.runThisFrame = false
	end
end

function AutoDrive_Register:draw()
end

addModEventListener(AutoDrive_Register)
