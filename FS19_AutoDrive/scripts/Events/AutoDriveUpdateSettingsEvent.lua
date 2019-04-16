AutoDriveUpdateSettingsEvent = {};
AutoDriveUpdateSettingsEvent_mt = Class(AutoDriveUpdateSettingsEvent, Event);

InitEventClass(AutoDriveUpdateSettingsEvent, "AutoDriveUpdateSettingsEvent");

function AutoDriveUpdateSettingsEvent:emptyNew()
	local self = Event:new(AutoDriveUpdateSettingsEvent_mt);
	self.className="AutoDriveUpdateSettingsEvent";
	return self;
end;

function AutoDriveUpdateSettingsEvent:new()
	local self = AutoDriveUpdateSettingsEvent:emptyNew()
	return self;
end;

function AutoDriveUpdateSettingsEvent:writeStream(streamId, connection)
	if AutoDrive == nil then
		return;
	end;

	for settingName, setting in pairs(AutoDrive.settings) do
		streamWriteInt16(streamId, setting.current);
	end;
end;

function AutoDriveUpdateSettingsEvent:readStream(streamId, connection)
	if AutoDrive == nil then
		return;
	end;

	for settingName, setting in pairs(AutoDrive.settings) do
		setting.current = streamReadInt16(streamId);
	end;
	
	if g_server ~= nil then
		g_server:broadcastEvent(AutoDriveUpdateSettingsEvent:new(), nil, nil, nil);
	end;
end;

function AutoDriveUpdateSettingsEvent:sendEvent()
	if g_server == nil then
		g_client:getServerConnection():sendEvent(AutoDriveUpdateSettingsEvent:new());
	end;
end;
