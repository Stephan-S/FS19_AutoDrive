function AutoDrive:loadGUI()
	source(Utils.getFilename("gui/enterDriverNameGUI.lua", AutoDrive.directory))
	source(Utils.getFilename("gui/enterGroupNameGUI.lua", AutoDrive.directory))
	source(Utils.getFilename("gui/enterTargetNameGUI.lua", AutoDrive.directory))
	source(Utils.getFilename("gui/enterDestinationFilterGUI.lua", AutoDrive.directory))
	source(Utils.getFilename("gui/settingsPage.lua", AutoDrive.directory))
	source(Utils.getFilename("gui/debugSettingsPage.lua", AutoDrive.directory))
	source(Utils.getFilename("gui/experimentalFeaturesSettingsPage.lua", AutoDrive.directory))
	source(Utils.getFilename("gui/settings.lua", AutoDrive.directory))

	g_gui:loadProfiles(AutoDrive.directory .. "gui/guiProfiles.xml")
	AutoDrive.gui = {}
	AutoDrive.gui.ADEnterDriverNameGui = ADEnterDriverNameGui:new()
	AutoDrive.gui.ADEnterTargetNameGui = ADEnterTargetNameGui:new()
	AutoDrive.gui.ADEnterGroupNameGui = ADEnterGroupNameGui:new()
	AutoDrive.gui.ADEnterDestinationFilterGui = ADEnterDestinationFilterGui:new()

	g_gui:loadGui(AutoDrive.directory .. "gui/enterDriverNameGUI.xml", "ADEnterDriverNameGui", AutoDrive.gui.ADEnterDriverNameGui)
	g_gui:loadGui(AutoDrive.directory .. "gui/enterTargetNameGUI.xml", "ADEnterTargetNameGui", AutoDrive.gui.ADEnterTargetNameGui)
	g_gui:loadGui(AutoDrive.directory .. "gui/enterGroupNameGUI.xml", "ADEnterGroupNameGui", AutoDrive.gui.ADEnterGroupNameGui)
	g_gui:loadGui(AutoDrive.directory .. "gui/enterDestinationFilterGUI.xml", "ADEnterDestinationFilterGui", AutoDrive.gui.ADEnterDestinationFilterGui)

	AutoDrive.gui.ADSettingsPage = ADSettingsPage:new()
	AutoDrive.gui.ADVehicleSettingsPage = ADSettingsPage:new()
	AutoDrive.gui.ADCombineUnloadSettingsPage = ADSettingsPage:new()
	AutoDrive.gui.ADDebugSettingsPage = ADDebugSettingsPage:new()
	AutoDrive.gui.ADExperimentalFeaturesSettingsPage = ADExperimentalFeaturesSettingsPage:new()
	AutoDrive.gui.ADSettings = ADSettings:new()

	g_gui:loadGui(AutoDrive.directory .. "gui/settingsPage.xml", "ADSettingsFrame", AutoDrive.gui.ADSettingsPage, true)
	g_gui:loadGui(AutoDrive.directory .. "gui/vehicleSettingsPage.xml", "ADVehicleSettingsFrame", AutoDrive.gui.ADVehicleSettingsPage, true)
	g_gui:loadGui(AutoDrive.directory .. "gui/combineUnloadSettingsPage.xml", "ADCombineUnloadSettingsFrame", AutoDrive.gui.ADCombineUnloadSettingsPage, true)
	g_gui:loadGui(AutoDrive.directory .. "gui/debugSettingsPage.xml", "ADDebugSettingsFrame", AutoDrive.gui.ADDebugSettingsPage, true)
	g_gui:loadGui(AutoDrive.directory .. "gui/experimentalFeaturesSettingsPage.xml", "ADExperimentalFeaturesSettingsFrame", AutoDrive.gui.ADExperimentalFeaturesSettingsPage, true)
	g_gui:loadGui(AutoDrive.directory .. "gui/settings.xml", "ADSettings", AutoDrive.gui.ADSettings)
end

function AutoDrive.GuiOverlay_loadOverlay(superFunc, ...)
	local overlay = superFunc(...)
	if overlay == nil then
		return nil
	end

	if overlay.filename == "g_autoDriveDebugUIFilename" then
		overlay.filename = g_autoDriveDebugUIFilename
	elseif overlay.filename == "g_autoDriveUIFilename" then
		overlay.filename = g_autoDriveUIFilename
	end

	return overlay
end
GuiOverlay.loadOverlay = AutoDrive.overwrittenStaticFunction(GuiOverlay.loadOverlay, AutoDrive.GuiOverlay_loadOverlay)

function AutoDrive:onOpenSettings()
	if AutoDrive.gui.ADSettings.isOpen then
		AutoDrive.gui.ADSettings:onClickBack()
	elseif g_gui.currentGui == nil then
		g_gui:showGui("ADSettings")
	end
end

function AutoDrive:onOpenEnterDriverName()
	if not AutoDrive.gui.ADEnterDriverNameGui.isOpen then
		g_gui:showGui("ADEnterDriverNameGui")
	end
end

function AutoDrive:onOpenEnterTargetName()
	if not AutoDrive.gui.ADEnterTargetNameGui.isOpen then
		g_gui:showGui("ADEnterTargetNameGui")
	end
end

function AutoDrive:onOpenEnterGroupName()
	if not AutoDrive.gui.ADEnterGroupNameGui.isOpen then
		g_gui:showGui("ADEnterGroupNameGui")
	end
end

function AutoDrive:onOpenEnterDestinationFilter()
	if not AutoDrive.gui.ADEnterDestinationFilterGui.isOpen then
		g_gui:showGui("ADEnterDestinationFilterGui")
	end
end
