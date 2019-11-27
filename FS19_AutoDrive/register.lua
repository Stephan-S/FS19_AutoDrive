--
-- Mod: AutoDrive
--
-- Author: Stephan
-- Email: Stephan910@web.de
-- Date: 02.02.2019
-- Version: 1.0.0.0

-- #############################################################################

source(Utils.getFilename("scripts/AutoDrive.lua", g_currentModDirectory))
source(Utils.getFilename("scripts/AutoDriveSpecialization.lua", g_currentModDirectory))
source(Utils.getFilename("scripts/AutoDriveDelayedCallBacks.lua", g_currentModDirectory))
source(Utils.getFilename("scripts/AutoDriveTON.lua", g_currentModDirectory))
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
source(Utils.getFilename("scripts/Events/AutoDriveUserDataEvent.lua", g_currentModDirectory))
source(Utils.getFilename("scripts/Events/AutoDriveDeleteWayPointEvent.lua", g_currentModDirectory))
source(Utils.getFilename("scripts/Events/AutoDriveRequestWayPointEvent.lua", g_currentModDirectory))
source(Utils.getFilename("scripts/Events/AutoDriveAcknowledgeCourseUpdateEvent.lua", g_currentModDirectory))
source(Utils.getFilename("scripts/Events/AutoDriveUpdateSettingsEvent.lua", g_currentModDirectory))
source(Utils.getFilename("scripts/Events/AutoDriveRenameDriverEvent.lua", g_currentModDirectory))
source(Utils.getFilename("scripts/Events/AutoDriveUserConnectedEvent.lua", g_currentModDirectory))
source(Utils.getFilename("scripts/Events/AutoDriveExperimentalFeaturesEvent.lua", g_currentModDirectory))

AutoDriveRegister = {}
AutoDriveRegister.version = g_modManager:getModByName(g_currentModName).version

if g_specializationManager:getSpecializationByName("AutoDrive") == nil then
	g_specializationManager:addSpecialization("AutoDrive", "AutoDrive", Utils.getFilename("scripts/AutoDrive.lua", g_currentModDirectory), nil)

	if AutoDrive == nil then
		g_logManager:error("[AutoDrive] Unable to add specialization 'AutoDrive'")
		return
	end

	local ADSpecName = g_currentModName .. ".AutoDrive"

	for vehicleType, typeDef in pairs(g_vehicleTypeManager.vehicleTypes) do
		if typeDef ~= nil and vehicleType ~= "locomotive" then
			if AutoDrive.prerequisitesPresent(typeDef.specializations) then
				g_logManager:info('[AutoDrive] Attached to vehicleType "%s"', vehicleType)
				if typeDef.specializationsByName["AutoDrive"] == nil then
					g_vehicleTypeManager:addSpecialization(vehicleType, ADSpecName)
					typeDef.hasADSpec = true
				end
			end
		end
	end
end

-- We need this for network debug functions
EventIds.eventIdToName = {}

for eName, eId in pairs(EventIds) do
	if string.sub(eName, 1, 6) == "EVENT_" then
		EventIds.eventIdToName[eId] = eName
	end
end

function AutoDriveRegister:loadMap(name)
	g_logManager:info("[AutoDrive] Loaded mod version %s (by Stephan)", self.version)
end

function AutoDriveRegister:deleteMap()
end

function AutoDriveRegister:keyEvent(unicode, sym, modifier, isDown)
end

function AutoDriveRegister:mouseEvent(posX, posY, isDown, isUp, button)
end

function AutoDriveRegister:update(dt)
end

function AutoDriveRegister:draw()
end

--Knowledge to register translations in l10n space and to use the helpLineManager taken from the Seasons mod (Thank you!)
function AutoDriveRegister.onMissionWillLoad(i18n)
	AutoDriveRegister.addModTranslations(i18n)
end

function AutoDriveValidateVehicleTypes(vehicleTypeManager)
	AutoDriveRegister.onMissionWillLoad(g_i18n)
end

---Copy our translations to global space.
function AutoDriveRegister.addModTranslations(i18n)
	-- We can copy all our translations to the global table because we prefix everything with ad_ or have unique names with 'AD' in it.
	-- The mod-based l10n lookup only really works for vehicles, not UI and script mods.
	local global = getfenv(0).g_i18n.texts

	for key, text in pairs(i18n.texts) do
		global[key] = text
	end
end

function AutoDriveLoadedMission(mission, superFunc, node)
	superFunc(mission, node)

	if mission.cancelLoading then
		return
	end

	g_deferredLoadingManager:addTask(
		function()
			AutoDriveOnMissionLoaded(mission)
		end
	)
end

function AutoDriveOnMissionLoaded(mission)
	--print("On mission loaded called for AutoDrive")
	g_helpLineManager:loadFromXML(Utils.getFilename("helpLine.xml", AutoDrive.directory))
end

Mission00.loadMission00Finished = Utils.overwrittenFunction(Mission00.loadMission00Finished, AutoDriveLoadedMission)
VehicleTypeManager.validateVehicleTypes = Utils.prependedFunction(VehicleTypeManager.validateVehicleTypes, AutoDriveValidateVehicleTypes)

addModEventListener(AutoDriveRegister)
