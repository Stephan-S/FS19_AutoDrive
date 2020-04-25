AutoDriveHudInputEventEvent = {}
AutoDriveHudInputEventEvent.TYPE_FIRST_MARKER = 1
AutoDriveHudInputEventEvent.TYPE_SECOND_MARKER = 2
AutoDriveHudInputEventEvent.TYPE_FILLTYPE = 3

AutoDriveHudInputEventEvent_mt = Class(AutoDriveHudInputEventEvent, Event)

InitEventClass(AutoDriveHudInputEventEvent, "AutoDriveHudInputEventEvent")

function AutoDriveHudInputEventEvent:emptyNew()
    local o = Event:new(AutoDriveHudInputEventEvent_mt)
    o.className = "AutoDriveHudInputEventEvent"
    return o
end

function AutoDriveHudInputEventEvent:new(vehicle, eventType, value)
    local o = AutoDriveHudInputEventEvent:emptyNew()
    o.vehicle = vehicle
    o.eventType = eventType
    o.value = value
    return o
end

function AutoDriveHudInputEventEvent:writeStream(streamId, connection)
    NetworkUtil.writeNodeObjectId(streamId, NetworkUtil.getObjectId(self.vehicle))
    streamWriteUIntN(streamId, self.eventType, 3)
    streamWriteUIntN(streamId, self.value, 16)
end

function AutoDriveHudInputEventEvent:readStream(streamId, connection)
    self.vehicle = NetworkUtil.getObject(NetworkUtil.readNodeObjectId(streamId))
    self.eventType = streamReadUIntN(streamId, 3)
    self.value = streamReadUIntN(streamId, 16)
    self:run(connection)
end

function AutoDriveHudInputEventEvent:run(connection)
    if g_server ~= nil then
        if self.eventType == self.TYPE_FIRST_MARKER then
			local currentFirstMarker = self.vehicle.ad.stateModule:getFirstMarkerId()
			if currentFirstMarker > 0 and currentFirstMarker ~= self.value then
				self.vehicle.ad.stateModule:removeCPCallback()
			end
            self.vehicle.ad.stateModule:setFirstMarker(self.value)
        end

        if self.eventType == self.TYPE_SECOND_MARKER then
            self.vehicle.ad.stateModule:setSecondMarker(self.value)
        end

        if self.eventType == self.TYPE_FILLTYPE then
            self.vehicle.ad.stateModule:setFillType(self.value)
        end
    end
end

function AutoDriveHudInputEventEvent:sendFirstMarkerEvent(vehicle, markerId)
    if g_client ~= nil then
        -- Client have to send to server
        g_client:getServerConnection():sendEvent(AutoDriveHudInputEventEvent:new(vehicle, self.TYPE_FIRST_MARKER, markerId))
    end
end

function AutoDriveHudInputEventEvent:sendSecondMarkerEvent(vehicle, markerId)
    if g_client ~= nil then
        -- Client have to send to server
        g_client:getServerConnection():sendEvent(AutoDriveHudInputEventEvent:new(vehicle, self.TYPE_SECOND_MARKER, markerId))
    end
end

function AutoDriveHudInputEventEvent:sendFillTypeEvent(vehicle, fillTypeId)
    if g_client ~= nil then
        -- Client have to send to server
        g_client:getServerConnection():sendEvent(AutoDriveHudInputEventEvent:new(vehicle, self.TYPE_FILLTYPE, fillTypeId))
    end
end
