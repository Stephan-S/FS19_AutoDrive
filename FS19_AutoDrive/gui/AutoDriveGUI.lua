function AutoDrive:loadGUI()
    AutoDrive.gui = {};
    AutoDrive.gui["adSettingsGui"] = adSettingsGui:new();
	g_gui:loadGui(AutoDrive.directory .. "gui/settingsGui.xml", "adSettingsGui", AutoDrive.gui.adSettingsGui);	
end;

function AutoDrive:onOpenSettings()
	if AutoDrive.gui.adSettingsGui.isOpen then
		AutoDrive.gui.adSettingsGui:onClickBack()
	elseif g_gui.currentGui == nil then
		g_gui:showGui("adSettingsGui")
	end;
end;