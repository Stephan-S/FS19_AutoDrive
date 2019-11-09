AutoDriveUpdateSettingsEvent = {}
AutoDriveUpdateSettingsEvent_mt = Class(AutoDriveUpdateSettingsEvent, Event)

InitEventClass(AutoDriveUpdateSettingsEvent, "AutoDriveUpdateSettingsEvent")

function AutoDriveUpdateSettingsEvent:emptyNew()
	local self = Event:new(AutoDriveUpdateSettingsEvent_mt)
	self.className = "AutoDriveUpdateSettingsEvent"
	return self
end

function AutoDriveUpdateSettingsEvent:new(vehicle)
	local self = AutoDriveUpdateSettingsEvent:emptyNew()
	self.vehicle = vehicle
	return self
end

function AutoDriveUpdateSettingsEvent:writeStream(streamId, connection)
	-- Writing global confings
	for settingName, setting in pairs(AutoDrive.settings) do
		if setting ~= nil and not setting.isVehicleSpecific then
			streamWriteInt16(streamId, setting.current)
		end
	end

	streamWriteBool(streamId, self.vehicle ~= nil)

	-- Writing vehicle confings
	if self.vehicle ~= nil then
		streamWriteInt32(streamId, NetworkUtil.getObjectId(self.vehicle))
		for settingName, setting in pairs(AutoDrive.settings) do
			if setting ~= nil and setting.isVehicleSpecific then
				streamWriteInt16(streamId, AutoDrive.getSettingState(settingName, self.vehicle))
			end
		end
	end
end

function AutoDriveUpdateSettingsEvent:readStream(streamId, connection)
	-- Reading global confings
	for settingName, setting in pairs(AutoDrive.settings) do
		if setting ~= nil and not setting.isVehicleSpecific then
			setting.current = streamReadInt16(streamId)
		end
	end

	local includesVehicleSpecificSettings = streamReadBool(streamId)
	local vehicle = nil

	if includesVehicleSpecificSettings then
		local vehicle = NetworkUtil.getObject(streamReadInt32(streamId))
		if vehicle ~= nil then
			-- Reading vehicle confings
			for settingName, setting in pairs(AutoDrive.settings) do
				if setting ~= nil and setting.isVehicleSpecific then
					local newSettingsValue = streamReadInt16(streamId)
					vehicle.ad.settings[settingName].current = newSettingsValue
				end
			end
		end
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
