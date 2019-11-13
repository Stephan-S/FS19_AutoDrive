AutoDriveUserConnectedEvent = {}
AutoDriveUserConnectedEvent_mt = Class(AutoDriveUserConnectedEvent, Event)

InitEventClass(AutoDriveUserConnectedEvent, "AutoDriveUserConnectedEvent")

function AutoDriveUserConnectedEvent:emptyNew()
	local self = Event:new(AutoDriveUserConnectedEvent_mt)
	self.className = "AutoDriveUserConnectedEvent"
	return self
end

function AutoDriveUserConnectedEvent:new()
	return AutoDriveUserConnectedEvent:emptyNew()
end

function AutoDriveUserConnectedEvent:writeStream(streamId, connection)
end

function AutoDriveUserConnectedEvent:readStream(streamId, connection)
	self:run(connection)
end

function AutoDriveUserConnectedEvent:run(connection)
	if g_server ~= nil then
		connection:sendEvent(AutoDriveUpdateSettingsEvent:new())
		-- Here we can add other sync for newly connected players
		AutoDriveUserDataEvent.sendToClient(connection)
	end
end

function AutoDriveUserConnectedEvent.sendEvent()
	if g_server == nil then
		g_client:getServerConnection():sendEvent(AutoDriveUserConnectedEvent:new())
	end
end
