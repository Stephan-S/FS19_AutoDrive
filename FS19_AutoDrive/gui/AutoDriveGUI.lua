function AutoDrive:loadGUI()
	--g_gui:loadProfiles(AutoDrive.directory .. "gui/guiProfiles.xml")
	AutoDrive.gui = {}
	AutoDrive.gui["ADEnterDriverNameGui"] = ADEnterDriverNameGui:new()
	g_gui:loadGui(AutoDrive.directory .. "gui/enterDriverNameGUI.xml", "ADEnterDriverNameGui", AutoDrive.gui.ADEnterDriverNameGui)
	AutoDrive.gui["ADEnterTargetNameGui"] = ADEnterTargetNameGui:new()
	g_gui:loadGui(AutoDrive.directory .. "gui/enterTargetNameGUI.xml", "ADEnterTargetNameGui", AutoDrive.gui.ADEnterTargetNameGui)
	AutoDrive.gui["ADEnterGroupNameGui"] = ADEnterGroupNameGui:new()
	g_gui:loadGui(AutoDrive.directory .. "gui/enterGroupNameGUI.xml", "ADEnterGroupNameGui", AutoDrive.gui.ADEnterGroupNameGui)
	AutoDrive.gui["ADEnterDestinationFilterGui"] = ADEnterDestinationFilterGui:new()
	g_gui:loadGui(AutoDrive.directory .. "gui/enterDestinationFilterGUI.xml", "ADEnterDestinationFilterGui", AutoDrive.gui.ADEnterDestinationFilterGui)

	AutoDrive.gui["ADSettingsPage"] = ADSettingsPage:new()
	AutoDrive.gui["ADVehicleSettingsPage"] = ADVehicleSettingsPage:new()
	AutoDrive.gui["ADCombineUnloadSettingsPage"] = ADVehicleSettingsPage:new()
	AutoDrive.gui["ADSettings"] = ADSettings:new()

	g_gui:loadGui(AutoDrive.directory .. "gui/settingsPage.xml", "autoDriveSettingsFrame", AutoDrive.gui.ADSettingsPage, true)
	g_gui:loadGui(AutoDrive.directory .. "gui/vehicleSettingsPage.xml", "autoDriveVehicleSettingsFrame", AutoDrive.gui.ADVehicleSettingsPage, true)
	g_gui:loadGui(AutoDrive.directory .. "gui/combineUnloadSettingsPage.xml", "autoDriveCombineUnloadSettingsFrame", AutoDrive.gui.ADCombineUnloadSettingsPage, true)
	g_gui:loadGui(AutoDrive.directory .. "gui/settings.xml", "ADSettings", AutoDrive.gui.ADSettings)
end

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
