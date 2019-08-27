AutoDriveUpdateNameEvent = {};
AutoDriveUpdateNameEvent_mt = Class(AutoDriveUpdateNameEvent, Event);

InitEventClass(AutoDriveUpdateNameEvent, "AutoDriveUpdateNameEvent");

function AutoDriveUpdateNameEvent:emptyNew()
	local self = Event:new(AutoDriveUpdateNameEvent_mt);
	self.className="AutoDriveUpdateNameEvent";
	return self;
end;

function AutoDriveUpdateNameEvent:new(vehicle)
    local self = AutoDriveUpdateNameEvent:emptyNew()   
    
	self.vehicle = vehicle;		
	
	self.name = vehicle.ad.driverName;	

	return self;
end;

function AutoDriveUpdateNameEvent:writeStream(streamId, connection)
	if AutoDrive == nil then
		return;
    end;
    streamWriteInt32(streamId, NetworkUtil.getObjectId(self.vehicle));
    
    streamWriteStringOrEmpty(streamId, self.name);   		
end;

function AutoDriveUpdateNameEvent:readStream(streamId, connection)
	if AutoDrive == nil then
		return;
    end;
	local id = streamReadInt32(streamId);
	local vehicle = NetworkUtil.getObject(id);
    local name = streamReadStringOrEmpty(streamId);
	
	if name ~= nil and name :len() > 1 and vehicle ~= nil and vehicle.ad ~= nil then
		vehicle.ad.driverName = name;

		if g_server ~= nil then	
			g_server:broadcastEvent(AutoDriveUpdateNameEvent:new(vehicle), nil, nil, vehicle);
		end;
	end;
end;

function AutoDriveUpdateNameEvent:sendEvent(vehicle)
    if g_server ~= nil then	
		g_server:broadcastEvent(AutoDriveUpdateNameEvent:new(vehicle), nil, nil, vehicle);
	else
		g_client:getServerConnection():sendEvent(AutoDriveUpdateNameEvent:new(vehicle));
	end;
end;