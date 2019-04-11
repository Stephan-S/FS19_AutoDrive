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

	streamWriteInt16(streamId, AutoDrive.pipeOffsetCurrent);
	streamWriteInt16(streamId, AutoDrive.lookAheadTurnCurrent);
	streamWriteInt16(streamId, AutoDrive.lookAheadBrakingCurrent);
	streamWriteInt16(streamId, AutoDrive.avoidMarkersCurrent);
	streamWriteInt16(streamId, AutoDrive.MAP_MARKER_DETOUR_Current);	
	streamWriteInt16(streamId, AutoDrive.siloEmptyCurrent);	
end;

function AutoDriveUpdateSettingsEvent:readStream(streamId, connection)
	if AutoDrive == nil then
		return;
	end;

	AutoDrive.pipeOffsetCurrent = streamReadInt16(streamId);
	AutoDrive.lookAheadTurnCurrent = streamReadInt16(streamId);
	AutoDrive.lookAheadBrakingCurrent = streamReadInt16(streamId);
	AutoDrive.avoidMarkersCurrent = streamReadInt16(streamId);
	AutoDrive.MAP_MARKER_DETOUR_Current = streamReadInt16(streamId);
	AutoDrive.siloEmptyCurrent = streamReadInt16(streamId);
	
	AutoDrive.PATHFINDER_PIPE_OFFSET = AutoDrive.pipeOffsetValues[AutoDrive.pipeOffsetCurrent];
    AutoDrive.LOOKAHEAD_DISTANCE_TURNING = AutoDrive.lookAheadTurnValues[AutoDrive.lookAheadTurnCurrent];
    AutoDrive.LOOKAHEAD_DISTANCE_BRAKING = AutoDrive.lookAheadBrakingValues[AutoDrive.lookAheadBrakingCurrent];
    AutoDrive.avoidMarkers = AutoDrive.avoidMarkersValues[AutoDrive.avoidMarkersCurrent];
	AutoDrive.MAP_MARKER_DETOUR = AutoDrive.MAP_MARKER_DETOUR_Values[AutoDrive.MAP_MARKER_DETOUR_Current];	
	AutoDrive.continueOnEmptySilo = AutoDrive.siloEmptyValues[AutoDrive.siloEmptyCurrent];
	
	if g_server ~= nil then
		g_server:broadcastEvent(AutoDriveUpdateSettingsEvent:new(), nil, nil, nil);
	end;
end;

function AutoDriveUpdateSettingsEvent:sendEvent()
	if g_server == nil then
		g_client:getServerConnection():sendEvent(AutoDriveUpdateSettingsEvent:new());
	end;
end;
