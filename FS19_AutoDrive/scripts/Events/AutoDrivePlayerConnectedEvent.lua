AutoDrivePlayerConnectedEvent = {}
AutoDrivePlayerConnectedEvent_mt = Class(AutoDrivePlayerConnectedEvent, Event)

InitEventClass(AutoDrivePlayerConnectedEvent, "AutoDrivePlayerConnectedEvent")

function AutoDrivePlayerConnectedEvent:emptyNew()
	local self = Event:new(AutoDrivePlayerConnectedEvent_mt)
	self.className = "AutoDrivePlayerConnectedEvent"
	return self
end

function AutoDrivePlayerConnectedEvent:new()
	return AutoDrivePlayerConnectedEvent:emptyNew()
end

function AutoDrivePlayerConnectedEvent:writeStream(streamId, connection)
end

function AutoDrivePlayerConnectedEvent:readStream(streamId, connection)
	self:run(connection)
end

function AutoDrivePlayerConnectedEvent:run(connection)
	if g_server ~= nil then
		connection:sendEvent(AutoDriveUpdateSettingsEvent:new())
		-- Here we can add other sync for newly connected players
	end
end

function AutoDrivePlayerConnectedEvent.sendEvent()
	if g_server == nil then
		g_client:getServerConnection():sendEvent(AutoDrivePlayerConnectedEvent:new())
	end
end
