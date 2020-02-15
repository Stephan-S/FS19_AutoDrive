AutoDriveCourseEditEvent = {}
AutoDriveCourseEditEvent_mt = Class(AutoDriveCourseEditEvent, Event)

InitEventClass(AutoDriveCourseEditEvent, "AutoDriveCourseEditEvent")

function AutoDriveCourseEditEvent:emptyNew()
	local o = Event:new(AutoDriveCourseEditEvent_mt)
	o.className = "AutoDriveCourseEditEvent"
	return o
end

function AutoDriveCourseEditEvent:new(point)
	local o = AutoDriveCourseEditEvent:emptyNew()
	o.point = point
	return o
end

function AutoDriveCourseEditEvent:writeStream(streamId, connection)
	if g_server ~= nil then
		local incomingTable = {}
		for incomingIndex, incomingID in pairs(self.point.incoming) do
			incomingTable[incomingIndex] = incomingID
		end
		local incomingString = "" .. table.concat(incomingTable, ",")

		local outTable = {}
		for outgoingIndex, outgoingID in pairs(self.point.out) do
			outTable[outgoingIndex] = outgoingID
		end
		local outString = "" .. table.concat(outTable, ",")

		
		streamWriteInt16(streamId, self.point.id)
		streamWriteFloat32(streamId, self.point.x)
		streamWriteFloat32(streamId, self.point.y)
		streamWriteFloat32(streamId, self.point.z)
		AutoDrive.streamWriteStringOrEmpty(streamId, outString)
		AutoDrive.streamWriteStringOrEmpty(streamId, incomingString)
	end
end

function AutoDriveCourseEditEvent:readStream(streamId, connection)
	if g_server == nil then
		local point = {}

		point.id = streamReadInt16(streamId)
		point.x = streamReadFloat32(streamId)
		point.y = streamReadFloat32(streamId)
		point.z = streamReadFloat32(streamId)

		local outTable = StringUtil.splitString(",", AutoDrive.streamReadStringOrEmpty(streamId))
		point["out"] = {}
		for i2, outString in pairs(outTable) do
			point["out"][i2] = tonumber(outString)
		end

		local incomingString = AutoDrive.streamReadStringOrEmpty(streamId)
		local incomingTable = StringUtil.splitString(",", incomingString)
		point["incoming"] = {}
		local incoming_counter = 1
		for _, incomingID in pairs(incomingTable) do
			if incomingID ~= "" then
				point["incoming"][incoming_counter] = tonumber(incomingID)
			end
			incoming_counter = incoming_counter + 1
		end

		AutoDrive.mapWayPoints[point.id] = point
	end
end

function AutoDriveCourseEditEvent:sendEvent(point)
	if g_server ~= nil then
		g_server:broadcastEvent(AutoDriveCourseEditEvent:new(point), nil, nil, nil)
	end
end
