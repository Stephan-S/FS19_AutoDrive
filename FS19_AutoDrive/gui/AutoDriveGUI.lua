function AutoDrive:loadGUI()
    AutoDrive.gui = {};
    AutoDrive.gui["adSettingsGui"] = adSettingsGui:new();
	g_gui:loadGui(AutoDrive.directory .. "gui/settingsGui.xml", "adSettingsGui", AutoDrive.gui.adSettingsGui);	
    AutoDrive.gui["adEnterDriverNameGui"] = adEnterDriverNameGui:new();
	g_gui:loadGui(AutoDrive.directory .. "gui/enterDriverNameGUI.xml", "adEnterDriverNameGui", AutoDrive.gui.adEnterDriverNameGui);	
    AutoDrive.gui["adEnterTargetNameGui"] = adEnterTargetNameGui:new();
	g_gui:loadGui(AutoDrive.directory .. "gui/enterTargetNameGUI.xml", "adEnterTargetNameGui", AutoDrive.gui.adEnterTargetNameGui);	
end;

function AutoDrive:onOpenSettings()
	if AutoDrive.gui.adSettingsGui.isOpen then
		AutoDrive.gui.adSettingsGui:onClickBack()
	elseif g_gui.currentGui == nil then
		g_gui:showGui("adSettingsGui")
	end;
end;

function AutoDrive:onOpenEnterDriverName()
	if g_dedicatedServerInfo ~= nil then
		return;	
	end;
	
	if AutoDrive.gui.adEnterDriverNameGui.isOpen then
		AutoDrive.gui.adEnterDriverNameGui:onClickBack()
	elseif g_gui.currentGui == nil then
		g_gui:showGui("adEnterDriverNameGui")
	end;
end;

function AutoDrive:onOpenEnterTargetName()
	if g_dedicatedServerInfo ~= nil then
		return;	
	end;
	
	if AutoDrive.gui.adEnterTargetNameGui.isOpen then
		AutoDrive.gui.adEnterTargetNameGui:onClickBack()
	elseif g_gui.currentGui == nil then
		g_gui:showGui("adEnterTargetNameGui")
	end;
end;