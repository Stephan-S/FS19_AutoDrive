AutoDriveCreateMapMarkerEvent = {};
AutoDriveCreateMapMarkerEvent_mt = Class(AutoDriveCreateMapMarkerEvent, Event);

InitEventClass(AutoDriveCreateMapMarkerEvent, "AutoDriveCreateMapMarkerEvent");

function AutoDriveCreateMapMarkerEvent:emptyNew()
	local self = Event:new(AutoDriveCreateMapMarkerEvent_mt);
	self.className="AutoDriveCreateMapMarkerEvent";
	return self;
end;

function AutoDriveCreateMapMarkerEvent:new(vehicle, id, name)
    local self = AutoDriveCreateMapMarkerEvent:emptyNew()
    self.vehicle = vehicle;
    self.id = id;
    self.name = name;
	--print("event new")
	return self;
end;

function AutoDriveCreateMapMarkerEvent:writeStream(streamId, connection)

	if g_server == nil then
        print("Sending MapMarkerEvent to server");
        streamWriteInt32(streamId, NetworkUtil.getObjectId(self.vehicle));
	
		streamWriteInt16(streamId, self.id);
		streamWriteStringOrEmpty(streamId, self.name);
	end;
	--print("event writeStream")
end;

function AutoDriveCreateMapMarkerEvent:readStream(streamId, connection)
	--print("Received AutoDriveCreateMapMarkerEvent");

	if g_server ~= nil then
        print("Receiving new map marker");
        local id = streamReadInt32(streamId);
        local vehicle = NetworkUtil.getObject(id);
        
        local nodeId = streamReadInt16(streamId);
        local name = streamReadString(streamId);

        vehicle.ad.enteredMapMarkerString = name;

        AutoDrive:finishCreatingMapMarker(vehicle)
	end;
end;

function AutoDriveCreateMapMarkerEvent:sendEvent(vehicle, id, name)
	--print("Sending AutoDriveCreateMapMarkerEvent");
	if g_server ~= nil then
		--g_server:broadcastEvent(AutoDriveCreateMapMarkerEvent:new(point), nil, nil, nil);
		--print("broadcasting")
	else
		g_client:getServerConnection():sendEvent(AutoDriveCreateMapMarkerEvent:new(vehicle, id, name));
		--print("sending event to server...")
	end;
end;