AutoDriveRequestWayPointEvent = {};
AutoDriveRequestWayPointEvent_mt = Class(AutoDriveRequestWayPointEvent, Event);

InitEventClass(AutoDriveRequestWayPointEvent, "AutoDriveRequestWayPointEvent");

function AutoDriveRequestWayPointEvent:emptyNew()
	local self = Event:new(AutoDriveRequestWayPointEvent_mt);
	self.className="AutoDriveRequestWayPointEvent";
	return self;
end;

function AutoDriveRequestWayPointEvent:new(vehicle)
	local self = AutoDriveRequestWayPointEvent:emptyNew()
	self.vehicle = vehicle;
	--print("event new")
	return self;
end;

function AutoDriveRequestWayPointEvent:writeStream(streamId, connection)
	if AutoDrive == nil then
		return;
	end;
	if g_server == nil then
		print("Requesting waypoints");
		streamWriteInt32(streamId, NetworkUtil.getObjectId(self.vehicle));
	end;
	--print("event writeStream")
end;

function AutoDriveRequestWayPointEvent:readStream(streamId, connection)
	--print("Received Event");
	if AutoDrive == nil then
		return;
	end;

	if g_server ~= nil then
		print("Receiving request for broadcasting waypoints");
		local id = streamReadInt32(streamId);
		local vehicle = NetworkUtil.getObject(id);
		AutoDrive.requestedWaypoints = true;
		AutoDrive.requestedWaypointCount = 1;
	end;
end;

function AutoDriveRequestWayPointEvent:sendEvent(vehicle)
	if g_server ~= nil then
		--g_server:broadcastEvent(AutoDriveRequestWayPointEvent:new(vehicle), nil, nil, nil);
		--print("broadcasting")
	else
		g_client:getServerConnection():sendEvent(AutoDriveRequestWayPointEvent:new(vehicle));
		--print("sending event to server...")
	end;
end;
