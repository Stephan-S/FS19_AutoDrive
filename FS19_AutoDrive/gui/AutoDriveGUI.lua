function AutoDrive:loadGUI()
	--g_gui:loadProfiles(AutoDrive.directory .. "gui/guiProfiles.xml")
	AutoDrive.gui = {}
	AutoDrive.gui["adEnterDriverNameGui"] = adEnterDriverNameGui:new()
	g_gui:loadGui(AutoDrive.directory .. "gui/enterDriverNameGUI.xml", "adEnterDriverNameGui", AutoDrive.gui.adEnterDriverNameGui)
	AutoDrive.gui["adEnterTargetNameGui"] = adEnterTargetNameGui:new()
	g_gui:loadGui(AutoDrive.directory .. "gui/enterTargetNameGUI.xml", "adEnterTargetNameGui", AutoDrive.gui.adEnterTargetNameGui)
	AutoDrive.gui["adEnterGroupNameGui"] = adEnterGroupNameGui:new()
	g_gui:loadGui(AutoDrive.directory .. "gui/enterGroupNameGUI.xml", "adEnterGroupNameGui", AutoDrive.gui.adEnterGroupNameGui)

	AutoDrive.gui["adSettingsPage"] = adSettingsPage:new()
	AutoDrive.gui["adVehicleSettingsPage"] = adVehicleSettingsPage:new()
	AutoDrive.gui["adCombineUnloadSettingsPage"] = adVehicleSettingsPage:new()
	AutoDrive.gui["adSettings"] = adSettings:new()

	g_gui:loadGui(AutoDrive.directory .. "gui/settingsPage.xml", "autoDriveSettingsFrame", AutoDrive.gui.adSettingsPage, true)
	g_gui:loadGui(AutoDrive.directory .. "gui/vehicleSettingsPage.xml", "autoDriveVehicleSettingsFrame", AutoDrive.gui.adVehicleSettingsPage, true)
	g_gui:loadGui(AutoDrive.directory .. "gui/combineUnloadSettingsPage.xml", "autoDriveCombineUnloadSettingsFrame", AutoDrive.gui.adCombineUnloadSettingsPage, true)
	g_gui:loadGui(AutoDrive.directory .. "gui/settings.xml", "adSettings", AutoDrive.gui.adSettings)
end

function AutoDrive:onOpenSettings()
	if AutoDrive.gui.adSettings.isOpen then
		AutoDrive.gui.adSettings:onClickBack()
	elseif g_gui.currentGui == nil then
		g_gui:showGui("adSettings")
	end
end

function AutoDrive:onOpenEnterDriverName()
	if g_dedicatedServerInfo ~= nil then
		return
	end

	if AutoDrive.gui.adEnterDriverNameGui.isOpen then
		AutoDrive.gui.adEnterDriverNameGui:onClickBack()
	elseif g_gui.currentGui == nil then
		--AutoDrive.delayedCallBacks.openEnterDriverNameGUI:call(200)
		g_gui:showGui("adEnterDriverNameGui")
	end
end

function AutoDrive:onOpenEnterTargetName()
	if g_dedicatedServerInfo ~= nil then
		return
	end

	if AutoDrive.gui.adEnterTargetNameGui.isOpen then
		--AutoDrive.gui.adEnterTargetNameGui:onClickBack()
	elseif g_gui.currentGui == nil then
		--AutoDrive.delayedCallBacks.openEnterTargetNameGUI:call(200)
		g_gui:showGui("adEnterTargetNameGui")
	end
end

function AutoDrive:onOpenEnterGroupName()
	if g_dedicatedServerInfo ~= nil then
		return
	end

	if AutoDrive.gui.adEnterGroupNameGui.isOpen then
		AutoDrive.gui.adEnterGroupNameGui:onClickBack()
	elseif g_gui.currentGui == nil then
		--AutoDrive.delayedCallBacks.openEnterGroupNameGUI:call(200)
		g_gui:showGui("adEnterGroupNameGui")
	end
end
