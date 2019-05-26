AutoDriveUpdateDestinationsEvent = {};
AutoDriveUpdateDestinationsEvent_mt = Class(AutoDriveUpdateDestinationsEvent, Event);

InitEventClass(AutoDriveUpdateDestinationsEvent, "AutoDriveUpdateDestinationsEvent");

function AutoDriveUpdateDestinationsEvent:emptyNew()
	local self = Event:new(AutoDriveUpdateDestinationsEvent_mt);
	self.className="AutoDriveUpdateDestinationsEvent";
	return self;
end;

function AutoDriveUpdateDestinationsEvent:new(vehicle)
    local self = AutoDriveUpdateDestinationsEvent:emptyNew()   
    
	self.vehicle = vehicle;		
	
	self.targetSelected = vehicle.ad.targetSelected;	
	self.mapMarkerSelected = vehicle.ad.mapMarkerSelected;
	self.nameOfSelectedTarget = vehicle.ad.nameOfSelectedTarget;
			
	self.targetSelected_Unload = vehicle.ad.targetSelected_Unload;
	self.mapMarkerSelected_Unload = vehicle.ad.mapMarkerSelected_Unload;
	self.nameOfSelectedTarget_Unload = vehicle.ad.nameOfSelectedTarget_Unload;

	self.unloadFillTypeIndex = vehicle.ad.unloadFillTypeIndex;

	return self;
end;

function AutoDriveUpdateDestinationsEvent:writeStream(streamId, connection)
	if AutoDrive == nil then
		return;
    end;
    streamWriteInt32(streamId, NetworkUtil.getObjectId(self.vehicle));
    
    streamWriteInt16(streamId, self.targetSelected);
	streamWriteInt16(streamId, self.mapMarkerSelected);
    streamWriteStringOrEmpty(streamId, self.nameOfSelectedTarget);
    
    streamWriteInt16(streamId, self.targetSelected_Unload);
	streamWriteInt16(streamId, self.mapMarkerSelected_Unload);
	streamWriteStringOrEmpty(streamId, self.nameOfSelectedTarget_Unload)    	

	streamWriteInt8(streamId, self.unloadFillTypeIndex);	
end;

function AutoDriveUpdateDestinationsEvent:readStream(streamId, connection)
	if AutoDrive == nil then
		return;
    end;

    local id = streamReadInt32(streamId);
	local vehicle = NetworkUtil.getObject(id);
    
	local targetSelected = streamReadInt16(streamId);
	local mapMarkerSelected = streamReadInt16(streamId);
    local nameOfSelectedTarget = streamReadStringOrEmpty(streamId);
    
    local targetSelected_Unload = streamReadInt16(streamId);
	local mapMarkerSelected_Unload = streamReadInt16(streamId);
	local nameOfSelectedTarget_Unload = streamReadStringOrEmpty(streamId);
	
	local unloadFillTypeIndex = streamReadInt8(streamId);
    
    vehicle.ad.targetSelected = targetSelected;	
	vehicle.ad.mapMarkerSelected = mapMarkerSelected;
    vehicle.ad.nameOfSelectedTarget = nameOfSelectedTarget;
    
    vehicle.ad.targetSelected_Unload = targetSelected_Unload;
    vehicle.ad.mapMarkerSelected_Unload = mapMarkerSelected_Unload;
	vehicle.ad.nameOfSelectedTarget_Unload = nameOfSelectedTarget_Unload;	
	
	vehicle.ad.unloadFillTypeIndex = unloadFillTypeIndex;	
    
    if g_server ~= nil then	
		g_server:broadcastEvent(AutoDriveUpdateDestinationsEvent:new(vehicle), nil, nil, vehicle);
	end;
end;

function AutoDriveUpdateDestinationsEvent:sendEvent(vehicle)
    if g_server ~= nil then	
		g_server:broadcastEvent(AutoDriveUpdateDestinationsEvent:new(vehicle), nil, nil, vehicle);
	else
		g_client:getServerConnection():sendEvent(AutoDriveUpdateDestinationsEvent:new(vehicle));
	end;
end;