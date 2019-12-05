AutoDriveUpdateSettingsEvent = {}
AutoDriveUpdateSettingsEvent_mt = Class(AutoDriveUpdateSettingsEvent, Event)

InitEventClass(AutoDriveUpdateSettingsEvent, "AutoDriveUpdateSettingsEvent")

function AutoDriveUpdateSettingsEvent:emptyNew()
	local o = Event:new(AutoDriveUpdateSettingsEvent_mt)
	o.className = "AutoDriveUpdateSettingsEvent"
	return o
end

function AutoDriveUpdateSettingsEvent:new(vehicle)
	local o = AutoDriveUpdateSettingsEvent:emptyNew()
	o.vehicle = vehicle
	return o
end

function AutoDriveUpdateSettingsEvent:writeStream(streamId, connection)
	-- Writing global confings
	for _, setting in pairs(AutoDrive.settings) do
		if setting ~= nil and not setting.isVehicleSpecific and (setting.isSynchronized == nil or setting.isSynchronized) then
			streamWriteInt16(streamId, setting.current)
		end
	end

	streamWriteBool(streamId, self.vehicle ~= nil)

	-- Writing vehicle confings
	if self.vehicle ~= nil then
		streamWriteInt32(streamId, NetworkUtil.getObjectId(self.vehicle))
		for settingName, setting in pairs(AutoDrive.settings) do
			if setting ~= nil and setting.isVehicleSpecific and (setting.isSynchronized == nil or setting.isSynchronized) then
				streamWriteInt16(streamId, AutoDrive.getSettingState(settingName, self.vehicle))
			end
		end
	end
end

function AutoDriveUpdateSettingsEvent:readStream(streamId, connection)
	-- Reading global confings
	for _, setting in pairs(AutoDrive.settings) do
		if setting ~= nil and not setting.isVehicleSpecific and (setting.isSynchronized == nil or setting.isSynchronized) then
			setting.current = streamReadInt16(streamId)
		end
	end

	local includesVehicleSpecificSettings = streamReadBool(streamId)
	local vehicle = nil

	if includesVehicleSpecificSettings then
		vehicle = NetworkUtil.getObject(streamReadInt32(streamId))
		if vehicle ~= nil then
			-- Reading vehicle confings
			for settingName, setting in pairs(AutoDrive.settings) do
				if setting ~= nil and setting.isVehicleSpecific and (setting.isSynchronized == nil or setting.isSynchronized) then
					local newSettingsValue = streamReadInt16(streamId)
					vehicle.ad.settings[settingName].current = newSettingsValue
					vehicle.ad.settings[settingName].new = newSettingsValue -- Also update 'new' field to prevent a following incoerence state of 'hasChanges()' function on settings pages
				end
			end
		end
	end

	-- If the current user is editing the settings the gui will be closed and then opened to show new settings
	if g_gui.currentGui ~= nil and g_gui.currentGui.name == "ADSettings" then
		g_gui:showGui()
		g_gui:showGui("ADSettings")
	end

	-- Server have to broadcast to all clients
	if g_server ~= nil then
		g_server:broadcastEvent(AutoDriveUpdateSettingsEvent:new(vehicle))
	end
end

function AutoDriveUpdateSettingsEvent.sendEvent(vehicle)
	local event = AutoDriveUpdateSettingsEvent:new(vehicle)
	if g_server ~= nil then
		-- Server have to broadcast to all clients
		g_server:broadcastEvent(event)
	else
		-- Client have to send to server
		g_client:getServerConnection():sendEvent(event)
	end
end
