AutoDriveUpdateSettingsEvent = {};
AutoDriveUpdateSettingsEvent_mt = Class(AutoDriveUpdateSettingsEvent, Event);

InitEventClass(AutoDriveUpdateSettingsEvent, "AutoDriveUpdateSettingsEvent");

function AutoDriveUpdateSettingsEvent:emptyNew()
	local self = Event:new(AutoDriveUpdateSettingsEvent_mt);
	self.className="AutoDriveUpdateSettingsEvent";
	return self;
end;

function AutoDriveUpdateSettingsEvent:new(vehicle)
	local self = AutoDriveUpdateSettingsEvent:emptyNew()
	self.vehicle = vehicle;
	return self;
end;

function AutoDriveUpdateSettingsEvent:writeStream(streamId, connection)
	if AutoDrive == nil then
		return;
	end;

	streamWriteInt32(streamId, NetworkUtil.getObjectId(self.vehicle));

	for settingName, setting in pairs(AutoDrive.settings) do
		streamWriteInt16(streamId, setting.current);
	end;

	for settingName, setting in pairs(AutoDrive.settings) do
		if setting ~= nil and setting.isVehicleSpecific then
			streamWriteInt16(streamId, AutoDrive:getSetting(settingname, self.vehicle));
		end;
	end;
end;

function AutoDriveUpdateSettingsEvent:readStream(streamId, connection)
	if AutoDrive == nil then
		return;
	end;

	local id = streamReadInt32(streamId);
	local vehicle = NetworkUtil.getObject(id);

	for settingName, setting in pairs(AutoDrive.settings) do
		setting.current = streamReadInt16(streamId);
	end;

	for settingName, setting in pairs(AutoDrive.settings) do
		 if setting ~= nil and setting.isVehicleSpecific then
			local newSettingsValue = streamReadInt16(streamId);
			vehicle.ad.settings[settingName].current = newSettingsValue;
		end;
	end;
	
	if g_server ~= nil then
		g_server:broadcastEvent(AutoDriveUpdateSettingsEvent:new(vehicle), nil, nil, nil);
	end;
end;

function AutoDriveUpdateSettingsEvent:sendEvent(vehicle)
	if g_server == nil then
		g_client:getServerConnection():sendEvent(AutoDriveUpdateSettingsEvent:new(vehicle));
	end;
end;
