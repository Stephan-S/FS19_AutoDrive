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
	return self;
end;

function AutoDriveCreateMapMarkerEvent:writeStream(streamId, connection)

	if g_server == nil then
        streamWriteInt32(streamId, NetworkUtil.getObjectId(self.vehicle));
	
		streamWriteInt16(streamId, self.id);
		streamWriteStringOrEmpty(streamId, self.name);
	end;
end;

function AutoDriveCreateMapMarkerEvent:readStream(streamId, connection)
	if g_server ~= nil then
        local id = streamReadInt32(streamId);
        local vehicle = NetworkUtil.getObject(id);
        
        local nodeId = streamReadInt16(streamId);
        local name = streamReadString(streamId);

        vehicle.ad.enteredMapMarkerString = name;
		if vehicle.ad.createMapPoints == false or AutoDrive.requestedWaypoints == true then
			return;
		end;
        AutoDrive:finishCreatingMapMarker(vehicle)
	end;
end;

function AutoDriveCreateMapMarkerEvent:sendEvent(vehicle, id, name)
	if g_server == nil then
		g_client:getServerConnection():sendEvent(AutoDriveCreateMapMarkerEvent:new(vehicle, id, name));
	end;
end;