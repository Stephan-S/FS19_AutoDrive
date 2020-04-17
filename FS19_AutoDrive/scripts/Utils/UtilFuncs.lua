string.randomCharset = {
	"0",
	"1",
	"2",
	"3",
	"4",
	"5",
	"6",
	"7",
	"8",
	"9",
	"A",
	"B",
	"C",
	"D",
	"E",
	"F",
	"G",
	"H",
	"I",
	"J",
	"K",
	"L",
	"M",
	"N",
	"O",
	"P",
	"Q",
	"R",
	"S",
	"T",
	"U",
	"V",
	"W",
	"X",
	"Y",
	"Z",
	"a",
	"b",
	"c",
	"d",
	"e",
	"f",
	"g",
	"h",
	"i",
	"j",
	"k",
	"l",
	"m",
	"n",
	"o",
	"p",
	"q",
	"r",
	"s",
	"t",
	"u",
	"v",
	"w",
	"x",
	"y",
	"z"
}

function AutoDrive.streamReadStringOrEmpty(streamId)
	local string = streamReadString(streamId)
	if string == nil or string == "nil" then
		string = ""
	end
	return string
end

function AutoDrive.streamWriteStringOrEmpty(streamId, string)
	if string == nil or string == "" then
		string = "nil"
	end
	streamWriteString(streamId, string)
end

function AutoDrive.boxesIntersect(a, b)
	local polygons = {a, b}
	local minA, maxA, minB, maxB

	for _, polygon in pairs(polygons) do
		-- for each polygon, look at each edge of the polygon, and determine if it separates
		-- the two shapes

		for i1, _ in pairs(polygon) do
			--grab 2 vertices to create an edge
			local i2 = (i1 % 4 + 1)
			local p1 = polygon[i1]
			local p2 = polygon[i2]

			-- find the line perpendicular to this edge
			local normal = {x = p2.z - p1.z, z = p1.x - p2.x}

			minA = nil
			maxA = nil
			-- for each vertex in the first shape, project it onto the line perpendicular to the edge
			-- and keep track of the min and max of these values

			for _, corner in pairs(polygons[1]) do
				local projected = normal.x * corner.x + normal.z * corner.z
				if minA == nil or projected < minA then
					minA = projected
				end
				if maxA == nil or projected > maxA then
					maxA = projected
				end
			end

			--for each vertex in the second shape, project it onto the line perpendicular to the edge
			--and keep track of the min and max of these values
			minB = nil
			maxB = nil
			for _, corner in pairs(polygons[2]) do
				local projected = normal.x * corner.x + normal.z * corner.z
				if minB == nil or projected < minB then
					minB = projected
				end
				if maxB == nil or projected > maxB then
					maxB = projected
				end
			end
			-- if there is no overlap between the projects, the edge we are looking at separates the two
			-- polygons, and we know there is no overlap
			if maxA < minB or maxB < minA then
				--g_logManager:devInfo("polygons don't intersect!");
				return false
			end
		end
	end

	--g_logManager:devInfo("polygons intersect!");
	return true
end

function math.clamp(minValue, value, maxValue)
	if minValue ~= nil and value ~= nil and maxValue ~= nil then
		return math.max(minValue, math.min(maxValue, value))
	end
	return value
end

function table:contains(value)
	for _, v in pairs(self) do
		if v == value then
			return true
		end
	end
	return false
end

function table:f_contains(func)
	for _, v in pairs(self) do
		if func(v) then
			return true
		end
	end
	return false
end

function table:indexOf(value)
	for k, v in pairs(self) do
		if v == value then
			return k
		end
	end
	return nil
end

function table:f_indexOf(func)
	for k, v in pairs(self) do
		if func(v) then
			return k
		end
	end
	return nil
end

function table:f_find(func)
	for _, v in pairs(self) do
		if func(v) then
			return v
		end
	end
	return nil
end

function table:f_filter(func)
	local new = {}
	for _, v in pairs(self) do
		if func(v) then
			table.insert(new, v)
		end
	end
	return new
end

function table:removeValue(value)
	for k, v in pairs(self) do
		if v == value then
			table.remove(self, k)
			return true
		end
	end
	return false
end

function table:f_remove(func)
	for k, v in pairs(self) do
		if func(v) then
			table.remove(self, k)
		end
	end
end

function table:count()
	local c = 0
	if self ~= nil then
		for _ in pairs(self) do
			c = c + 1
		end
	end
	return c
end

function table:f_count(func)
	local c = 0
	if self ~= nil then
		for _, v in pairs(self) do
			if func(v) then
				c = c + 1
			end
		end
	end
	return c
end

function table:concatNil(sep, i, j)
	local res = table.concat(self, sep, i, j)
	if res == "" then
		res = nil
	end
	return res
end

function string:split(sep)
	sep = sep or ":"
	local fields = {}
	local pattern = string.format("([^%s]+)", sep)
	self:gsub(
		pattern,
		function(c)
			fields[#fields + 1] = c
		end
	)
	return fields
end

function string.random(length)
	local res = ""
	for i = 1, length do
		res = res .. string.char(math.random(97, 122))
	end
	return res
end

function string.random(length)
	if not length or length <= 0 then
		return ""
	end
	return string.random(length - 1) .. string.randomCharset[math.random(1, #string.randomCharset)]
end

function AutoDrive.localize(text)
	for m in text:gmatch("$l10n_.-;") do
		local l10n = m:gsub("$l10n_", ""):gsub(";", "")
		text = text:gsub(m, g_i18n:getText(l10n))
	end
	return text
end

function AutoDrive.parsePath(path)
	path = path:gsub("$adDir/", AutoDrive.directory)
	path = path:gsub("$adDir", AutoDrive.directory)
	return path
end

function AutoDrive.boolToString(value)
	if value == true then
		return "true"
	end
	return "false"
end

function AutoDrive.angleBetween(vec1, vec2)
	--local scalarproduct_top = vec1.x * vec2.x + vec1.z * vec2.z;
	--local scalarproduct_down = math.sqrt(vec1.x * vec1.x + vec1.z*vec1.z) * math.sqrt(vec2.x * vec2.x + vec2.z*vec2.z)
	--local scalarproduct = scalarproduct_top / scalarproduct_down;
	local angle = math.atan2(vec2.z, vec2.x) - math.atan2(vec1.z, vec1.x)
	angle = AutoDrive.normalizeAngleToPlusMinusPI(angle)
	return math.deg(angle) --math.acos(angle)
end

function AutoDrive.normalizeAngle(inputAngle)
	if inputAngle > (2 * math.pi) then
		inputAngle = inputAngle - (2 * math.pi)
	else
		if inputAngle < -(2 * math.pi) then
			inputAngle = inputAngle + (2 * math.pi)
		end
	end

	return inputAngle
end

function AutoDrive.normalizeAngle2(inputAngle)
	if inputAngle > (2 * math.pi) then
		inputAngle = inputAngle - (2 * math.pi)
	else
		if inputAngle < 0 then
			inputAngle = inputAngle + (2 * math.pi)
		end
	end

	return inputAngle
end

function AutoDrive.normalizeAngleToPlusMinusPI(inputAngle)
	if inputAngle > (math.pi) then
		inputAngle = inputAngle - (2 * math.pi)
	else
		if inputAngle < -(math.pi) then
			inputAngle = inputAngle + (2 * math.pi)
		end
	end

	return inputAngle
end

function AutoDrive.createVector(x, y, z)
	local t = {x = x, y = y, z = z}
	return t
end

function AutoDrive.round(num)
	local under = math.floor(num)
	local upper = math.ceil(num)
	local underV = -(under - num)
	local upperV = upper - num
	if (upperV > underV) then
		return under
	else
		return upper
	end
end

function AutoDrive.getWorldDirection(fromX, fromY, fromZ, toX, toY, toZ)
	-- NOTE: if only 2D is needed, pass fromY and toY as 0
	local wdx, wdy, wdz = toX - fromX, toY - fromY, toZ - fromZ
	local dist = MathUtil.vector3Length(wdx, wdy, wdz) -- length of vector
	if dist and dist > 0.01 then
		wdx, wdy, wdz = wdx / dist, wdy / dist, wdz / dist -- if not too short: normalize
		return wdx, wdy, wdz, dist
	end
	return 0, 0, 0, 0
end

function AutoDrive.renderTable(posX, posY, textSize, inputTable, maxDepth)
	if inputTable == nil then
		return
	end
	maxDepth = maxDepth or 2
	local function renderTableRecursively(posX, posY, textSize, inputTable, depth, maxDepth, i)
		if depth >= maxDepth then
			return i
		end
		for k, v in pairs(inputTable) do
			local offset = i * textSize * 1.05
			setTextAlignment(RenderText.ALIGN_RIGHT)
			renderText(posX, posY - offset, textSize, tostring(k) .. " :")
			setTextAlignment(RenderText.ALIGN_LEFT)
			if type(v) ~= "table" then
				renderText(posX, posY - offset, textSize, " " .. tostring(v))
			end
			i = i + 1
			if type(v) == "table" then
				i = renderTableRecursively(posX + textSize * 2, posY, textSize, v, depth + 1, maxDepth, i)
			end
		end
		return i
	end
	local i = 0
	setTextColor(1, 1, 1, 1)
	setTextBold(false)
	textSize = getCorrectTextSize(textSize)
	for k, v in pairs(inputTable) do
		local offset = i * textSize * 1.05
		setTextAlignment(RenderText.ALIGN_RIGHT)
		renderText(posX, posY - offset, textSize, tostring(k) .. " :")
		setTextAlignment(RenderText.ALIGN_LEFT)
		if type(v) ~= "table" then
			renderText(posX, posY - offset, textSize, " " .. tostring(v))
		end
		i = i + 1
		if type(v) == "table" then
			i = renderTableRecursively(posX + textSize * 2, posY, textSize, v, 1, maxDepth, i)
		end
	end
end

function AutoDrive.dumpTable(inputTable, name, maxDepth)
	maxDepth = maxDepth or 5
	print(name .. " = {}")
	local function dumpTableRecursively(inputTable, name, depth, maxDepth)
		if depth >= maxDepth then
			return
		end
		for k, v in pairs(inputTable) do
			local newName = string.format("%s.%s", name, k)
			if type(k) == "number" then
				newName = string.format("%s[%s]", name, k)
			end
			if type(v) ~= "table" and type(v) ~= "function" then
				print(string.format("%s = %s", newName, v))
			end
			if type(v) == "table" then
				print(newName .. " = {}")
				dumpTableRecursively(v, newName, depth + 1, maxDepth)
			end
		end
	end
	for k, v in pairs(inputTable) do
		local newName = string.format("%s.%s", name, k)
		if type(k) == "number" then
			newName = string.format("%s[%s]", name, k)
		end
		if type(v) ~= "table" and type(v) ~= "function" then
			print(string.format("%s = %s", newName, v))
		end
		if type(v) == "table" then
			print(newName .. " = {}")
			dumpTableRecursively(v, newName, 1, maxDepth)
		end
	end
end

addConsoleCommand("ADsetDebugChannel", "Set new debug channel", "setDebugChannel", AutoDrive)

function AutoDrive:setDebugChannel(newDebugChannel)
	if newDebugChannel ~= nil then
		newDebugChannel = tonumber(newDebugChannel)
		if newDebugChannel == 0 then
			AutoDrive.currentDebugChannelMask = 0
		else
			if bitAND(AutoDrive.currentDebugChannelMask, newDebugChannel) == newDebugChannel then
				AutoDrive.currentDebugChannelMask = AutoDrive.currentDebugChannelMask - newDebugChannel
			else
				AutoDrive.currentDebugChannelMask = bitOR(AutoDrive.currentDebugChannelMask, newDebugChannel)
			end
		end
	else
		AutoDrive.currentDebugChannelMask = AutoDrive.DC_ALL
	end
	AutoDrive.showNetworkEvents()
end

function AutoDrive.getDebugChannelIsSet(debugChannel)
	return bitAND(AutoDrive.currentDebugChannelMask, debugChannel) > 0
end

function AutoDrive.debugPrint(vehicle, debugChannel, debugText, ...)
	if AutoDrive.getDebugChannelIsSet(debugChannel) then
		local printText = ""
		if vehicle ~= nil then
			if vehicle.ad ~= nil and vehicle.ad.stateModule ~= nil then
				printText = vehicle.ad.stateModule:getName() .. ": "
			else
				printText = vehicle:getName() .. ": "
			end
		end

		g_logManager:info(printText .. debugText, ...)
	end
end

AutoDrive.debug = {}
AutoDrive.debug.connectionSendEventBackup = nil
AutoDrive.debug.serverBroadcastEventBackup = nil
AutoDrive.debug.lastSentEvent = nil
AutoDrive.debug.lastSentEventSize = 0

function AutoDrive.showNetworkEvents()
	if AutoDrive.getDebugChannelIsSet(AutoDrive.DC_NETWORKINFO) then
		-- Activating network debug
		if g_server ~= nil then
			if AutoDrive.debug.serverBroadcastEventBackup == nil then
				AutoDrive.debug.serverBroadcastEventBackup = g_server.broadcastEvent
				g_server.broadcastEvent = Utils.overwrittenFunction(g_server.broadcastEvent, AutoDrive.ServerBroadcastEvent)
			end
		else
			local connection = g_client:getServerConnection()
			if AutoDrive.debug.connectionSendEventBackup == nil then
				AutoDrive.debug.connectionSendEventBackup = connection.sendEvent
				connection.sendEvent = Utils.overwrittenFunction(connection.sendEvent, AutoDrive.ConnectionSendEvent)
			end
		end
	else
		-- Deactivating network debug
		if g_server ~= nil then
			if AutoDrive.debug.serverBroadcastEventBackup ~= nil then
				g_server.broadcastEvent = AutoDrive.debug.serverBroadcastEventBackup
				AutoDrive.debug.serverBroadcastEventBackup = nil
			end
		else
			local connection = g_client:getServerConnection()
			if AutoDrive.debug.connectionSendEventBackup ~= nil then
				connection.sendEvent = AutoDrive.debug.connectionSendEventBackup
				AutoDrive.debug.connectionSendEventBackup = nil
			end
		end
	end
end

function AutoDrive:ServerBroadcastEvent(superFunc, event, sendLocal, ignoreConnection, ghostObject, force)
	local eCopy = {}
	eCopy.event = AutoDrive.tableClone(event)
	eCopy.eventName = eCopy.event.className or EventIds.eventIdToName[event.eventId]
	eCopy.sendLocal = sendLocal or false
	eCopy.ignoreConnection = ignoreConnection or "nil"
	eCopy.force = force or false
	eCopy.clients = table.count(self.clientConnections) - 1
	superFunc(self, event, sendLocal, ignoreConnection, ghostObject, force)
	eCopy.size = AutoDrive.debug.lastSentEventSize
	if eCopy.clients > 0 then
		AutoDrive.debugPrint(nil, AutoDrive.DC_NETWORKINFO, "%s size %s (x%s = %s) Bytes", eCopy.eventName, eCopy.size / eCopy.clients, eCopy.clients, eCopy.size)
	else
		AutoDrive.debugPrint(nil, AutoDrive.DC_NETWORKINFO, "%s", eCopy.eventName)
	end
	AutoDrive.debug.lastSentEvent = eCopy
end

function AutoDrive:ConnectionSendEvent(superFunc, event, deleteEvent, force)
	local eCopy = {}
	eCopy.event = AutoDrive.tableClone(event)
	eCopy.eventName = eCopy.event.className or EventIds.eventIdToName[event.eventId]
	eCopy.deleteEvent = deleteEvent or true
	eCopy.force = force or false
	superFunc(self, event, deleteEvent, force)
	eCopy.size = AutoDrive.debug.lastSentEventSize
	AutoDrive.debugPrint(nil, AutoDrive.DC_NETWORKINFO, "%s size %s Bytes", eCopy.eventName, eCopy.size)
	AutoDrive.debug.lastSentEvent = eCopy
end

function NetworkNode:addPacketSize(packetType, packetSizeInBytes)
	if (AutoDrive.debug.connectionSendEventBackup ~= nil or AutoDrive.debug.serverBroadcastEventBackup ~= nil) and packetType == NetworkNode.PACKET_EVENT then
		AutoDrive.debug.lastSentEventSize = packetSizeInBytes
	end
	if self.showNetworkTraffic then
		self.packetBytes[packetType] = self.packetBytes[packetType] + packetSizeInBytes
	end
end

function AutoDrive.tableClone(org)
	local otype = type(org)
	local copy
	if otype == "table" then
		copy = {}
		for org_key, org_value in pairs(org) do
			copy[org_key] = org_value
		end
	else -- number, string, boolean, etc
		copy = org
	end
	return copy
end

function AutoDrive.overwrittenStaticFunction(oldFunc, newFunc)
	return function(...)
		return newFunc(oldFunc, ...)
	end
end

function AutoDrive.renderColoredTextAtWorldPosition(x, y, z, text, textSize, color)
	local sx, sy, sz = project(x, y, z)
	if sx > -1 and sx < 2 and sy > -1 and sy < 2 and sz <= 1 then
		setTextAlignment(RenderText.ALIGN_CENTER)
		setTextBold(false)
		setTextColor(0.0, 0.0, 0.0, 0.75)
		renderText(sx, sy - 0.0015, textSize, text)
		setTextColor(color.r, color.g, color.b, 1.0)
		renderText(sx, sy, textSize, text)
		setTextAlignment(RenderText.ALIGN_LEFT)
	end
end

function AutoDrive.checkIsOnField(worldX, worldY, worldZ)
	local densityBits = 0

	if worldY == 0 then
		worldY = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, worldX, 1, worldZ)
	end

	local bits = getDensityAtWorldPos(g_currentMission.terrainDetailId, worldX, worldY, worldZ)
	densityBits = bitOR(densityBits, bits)
	if densityBits ~= 0 then
		return true
	end

	return false
end

Sprayer.registerOverwrittenFunctions =
	Utils.appendedFunction(
	Sprayer.registerOverwrittenFunctions,
	function(vehicleType)
		-- Work-around/fix for issue #863 ( thanks to DeckerMMIV )
		-- Having a slurry tank with a spreading unit attached, then avoid having the AI automatically turn these on when FollowMe is active.
		SpecializationUtil.registerOverwrittenFunction(
			vehicleType,
			"getIsAIActive",
			function(self, superFunc)
				local rootVehicle = self:getRootVehicle()
				if nil ~= rootVehicle and rootVehicle.ad ~= nil and rootVehicle.ad.stateModule ~= nil and rootVehicle.ad.stateModule:isActive() and self ~= rootVehicle then
					return false -- "Hackish" work-around, in attempt at convincing Sprayer.LUA to NOT turn on
				end
				return superFunc(self)
			end
		)
	end
)

-- LoadTrigger doesn't allow filling non controlled tools
function AutoDrive:getIsActivatable(superFunc, objectToFill)
	--when the trigger is filling, it uses this function without objectToFill
	if objectToFill ~= nil then
		local vehicle = objectToFill:getRootVehicle()
		if vehicle ~= nil and vehicle.ad ~= nil and vehicle.ad.stateModule:isActive() then
			--if i'm in the vehicle, all is good and I can use the normal function, if not, i have to cheat:
			if g_currentMission.controlledVehicle ~= vehicle then
				local oldControlledVehicle = nil
				if vehicle.ad ~= nil and vehicle.ad.oldControlledVehicle == nil then
					vehicle.ad.oldControlledVehicle = g_currentMission.controlledVehicle
				else
					oldControlledVehicle = g_currentMission.controlledVehicle
				end
				g_currentMission.controlledVehicle = vehicle or objectToFill

				local result = superFunc(self, objectToFill)

				if vehicle.ad ~= nil and vehicle.ad.oldControlledVehicle ~= nil then
					g_currentMission.controlledVehicle = vehicle.ad.oldControlledVehicle
					vehicle.ad.oldControlledVehicle = nil
				else
					if oldControlledVehicle ~= nil then
						g_currentMission.controlledVehicle = oldControlledVehicle
					end
				end
				return result
			end
		end
	end
	return superFunc(self, objectToFill)
end

function AutoDrive:zoomSmoothly(superFunc, offset)
	if not AutoDrive.mouseWheelActive then -- don't zoom camera when mouse wheel is used to scroll targets (thanks to sperrgebiet)
		superFunc(self, offset)
	end
end

function AutoDrive:onActivateObject(superFunc, vehicle)
	if vehicle ~= nil then
		--if i'm in the vehicle, all is good and I can use the normal function, if not, i have to cheat:
		if g_currentMission.controlledVehicle ~= vehicle or g_currentMission.controlledVehicles[vehicle] == nil then
			local oldControlledVehicle = nil
			if vehicle.ad ~= nil and vehicle.ad.oldControlledVehicle == nil then
				vehicle.ad.oldControlledVehicle = g_currentMission.controlledVehicle
			else
				oldControlledVehicle = g_currentMission.controlledVehicle
			end
			g_currentMission.controlledVehicle = vehicle

			superFunc(self, vehicle)

			if vehicle.ad ~= nil and vehicle.ad.oldControlledVehicle ~= nil then
				g_currentMission.controlledVehicle = vehicle.ad.oldControlledVehicle
				vehicle.ad.oldControlledVehicle = nil
			else
				if oldControlledVehicle ~= nil then
					g_currentMission.controlledVehicle = oldControlledVehicle
				end
			end
			return
		end
	end

	superFunc(self, vehicle)
end

function AutoDrive:onFillTypeSelection(superFunc, fillType)
	if fillType ~= nil and fillType ~= FillType.UNKNOWN then
		if self.validFillableObject == nil then
			for _, fillableObject in pairs(self.fillableObjects) do --copied from gdn getIsActivatable to get a valid Fillable Object even without entering vehicle (needed for refuel first time)
				if fillableObject.object:getFillUnitSupportsToolType(fillableObject.fillUnitIndex, ToolType.TRIGGER) then
					self.validFillableObject = fillableObject.object
					self.validFillableFillUnitIndex = fillableObject.fillUnitIndex
				end
			end
		end
		local validFillableObject = self.validFillableObject
		if validFillableObject ~= nil then --and validFillableObject:getRootVehicle() == g_currentMission.controlledVehicle
			local fillUnitIndex = self.validFillableFillUnitIndex
			self:setIsLoading(true, validFillableObject, fillUnitIndex, fillType)
		end
	end
end

AIVehicleUtil.driveInDirection = function(self, dt, steeringAngleLimit, acceleration, slowAcceleration, slowAngleLimit, allowedToDrive, moveForwards, lx, lz, maxSpeed, slowDownFactor)
	if self.getMotorStartTime ~= nil then
		allowedToDrive = allowedToDrive and (self:getMotorStartTime() <= g_currentMission.time)
	end

	if self.ad ~= nil and AutoDrive.experimentalFeatures.smootherDriving then
		if self.ad.stateModule:isActive() and allowedToDrive then
			--slowAngleLimit = 90 -- Set it to high value since we don't need the slow down

			local accFactor = 2 / 1000 -- km h / s converted to km h / ms
			accFactor = accFactor + math.abs((maxSpeed - self.lastSpeedReal * 3600) / 2000) -- Changing accFactor based on missing speed to reach target (useful for sudden braking)
			if self.ad.smootherDriving.lastMaxSpeed < maxSpeed then
				self.ad.smootherDriving.lastMaxSpeed = math.min(self.ad.smootherDriving.lastMaxSpeed + accFactor / 2 * dt, maxSpeed)
			else
				self.ad.smootherDriving.lastMaxSpeed = math.max(self.ad.smootherDriving.lastMaxSpeed - accFactor * dt, maxSpeed)
			end

			if maxSpeed < 1 then
				-- Hard braking, is needed to prevent combine's pipe overstep and crash
				self.ad.smootherDriving.lastMaxSpeed = maxSpeed
			end
			--AutoDrive.renderTable(0.1, 0.9, 0.012, {maxSpeed = maxSpeed, lastMaxSpeed = self.ad.smootherDriving.lastMaxSpeed})
			maxSpeed = self.ad.smootherDriving.lastMaxSpeed
		else
			self.ad.smootherDriving.lastMaxSpeed = 0
		end
	end

	local angle = 0
	if lx ~= nil and lz ~= nil then
		local dot = lz
		angle = math.deg(math.acos(dot))
		if angle < 0 then
			angle = angle + 180
		end
		local turnLeft = lx > 0.00001
		if not moveForwards then
			turnLeft = not turnLeft
		end
		local targetRotTime = 0
		if turnLeft then
			--rotate to the left
			targetRotTime = self.maxRotTime * math.min(angle / steeringAngleLimit, 1)
		else
			--rotate to the right
			targetRotTime = self.minRotTime * math.min(angle / steeringAngleLimit, 1)
		end
		if targetRotTime > self.rotatedTime then
			self.rotatedTime = math.min(self.rotatedTime + dt * self:getAISteeringSpeed(), targetRotTime)
		else
			self.rotatedTime = math.max(self.rotatedTime - dt * self:getAISteeringSpeed(), targetRotTime)
		end
	end
	if self.firstTimeRun then
		local acc = acceleration
		if maxSpeed ~= nil and maxSpeed ~= 0 then
			if math.abs(angle) >= slowAngleLimit then
				maxSpeed = maxSpeed * slowDownFactor
			end
			self.spec_motorized.motor:setSpeedLimit(maxSpeed)
			if self.spec_drivable.cruiseControl.state ~= Drivable.CRUISECONTROL_STATE_ACTIVE then
				self:setCruiseControlState(Drivable.CRUISECONTROL_STATE_ACTIVE)
			end
		else
			if math.abs(angle) >= slowAngleLimit then
				acc = slowAcceleration
			end
		end
		if not allowedToDrive then
			acc = 0
		end
		if not moveForwards then
			acc = -acc
		end
		--FS 17 Version WheelsUtil.updateWheelsPhysics(self, dt, self.lastSpeedReal, acc, not allowedToDrive, self.requiredDriveMode);
		WheelsUtil.updateWheelsPhysics(self, dt, self.lastSpeedReal * self.movingDirection, acc, not allowedToDrive, true)
	end
end

function AIVehicle:onUpdateTick(dt, isActiveForInput, isActiveForInputIgnoreSelection, isSelected)
	local spec = self.spec_aiVehicle

	if self.isClient then
		local actionEvent = spec.actionEvents[InputAction.TOGGLE_AI]
		if actionEvent ~= nil then
			local showAction = false

			if self:getIsActiveForInput(true, true) then
				-- If ai is active we always display the dismiss helper action
				-- But only if the AutoDrive is not active :)
				showAction = self:getCanStartAIVehicle() or (self:getIsAIActive() and (self.ad == nil or not self.ad.stateModule:isActive()))

				if showAction then
					if self:getIsAIActive() then
						g_inputBinding:setActionEventText(actionEvent.actionEventId, g_i18n:getText("action_dismissEmployee"))
					else
						g_inputBinding:setActionEventText(actionEvent.actionEventId, g_i18n:getText("action_hireEmployee"))
					end
				end
			end

			g_inputBinding:setActionEventActive(actionEvent.actionEventId, showAction)
		end
	end
end

function AutoDrive.sign(x)
	if x < 0 then
		return -1
	elseif x > 0 then
		return 1
	else
		return 0
	end
end

function AutoDrive.segmentIntersects(x1, y1, x2, y2, x3, y3, x4, y4)
	local d = (y4 - y3) * (x2 - x1) - (x4 - x3) * (y2 - y1)
	local Ua_n = ((x4 - x3) * (y1 - y3) - (y4 - y3) * (x1 - x3))
	local Ub_n = ((x2 - x1) * (y1 - y3) - (y2 - y1) * (x1 - x3))

	local Ua = Ua_n / d
	local Ub = Ub_n / d

	if d ~= 0 then
		local x = x1 + Ua * (x2 - x1)
		local y = y1 + Ua * (y2 - y1)
		local insideSector = Ua > 0
		local insideSecondSector = d > 0
		return x, y, insideSector, insideSecondSector
	else
		return 0, 0, false, false
	end
end

-- TODO: Maybe we should add a console command that allows to run console commands to server
