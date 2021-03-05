LoadMode = ADInheritsFrom(AbstractMode)

LoadMode.STATE_INIT = 1
LoadMode.STATE_TO_TARGET = 2
LoadMode.STATE_LOAD = 3
LoadMode.STATE_EXIT_FIELD = 4
LoadMode.STATE_FINISHED = 5

function LoadMode:new(vehicle)
    local o = LoadMode:create()
    o.vehicle = vehicle
    LoadMode.reset(o)
    return o
end

function LoadMode:reset()
    self.state = LoadMode.STATE_INIT
    self.activeTask = nil
end

function LoadMode:start()
	AutoDrive.debugPrint(self.vehicle, AutoDrive.DC_PATHINFO, "[AD] LoadMode:start start self.state %s", tostring(self.state))
    if not self.vehicle.ad.stateModule:isActive() then
        self.vehicle:startAutoDrive()
    end

    if self.vehicle.ad.stateModule:getFirstMarker() == nil or self.vehicle.ad.stateModule:getSecondMarker() == nil then
        return
    end

    self.activeTask = self:getNextTask()
    if self.activeTask ~= nil then
        self.vehicle.ad.taskModule:addTask(self.activeTask)
    end

end

function LoadMode:monitorTasks(dt)
end

function LoadMode:handleFinishedTask()
    self.vehicle.ad.trailerModule:reset()
    self.activeTask = self:getNextTask()
    if self.activeTask ~= nil then
        self.vehicle.ad.taskModule:addTask(self.activeTask)
    end
end

function LoadMode:stop()
end

function LoadMode:getNextTask()
	AutoDrive.debugPrint(self.vehicle, AutoDrive.DC_PATHINFO, "[AD] LoadMode:getNextTask start self.state %s", tostring(self.state))
    local nextTask

	local x, y, z = getWorldTranslation(self.vehicle.components[1].node)
	local point = nil
	local distanceToStart = 0
	if self.vehicle.ad ~= nil and ADGraphManager.getWayPointById ~= nil and self.vehicle.ad.stateModule ~= nil and self.vehicle.ad.stateModule.getFirstMarker ~= nil and self.vehicle.ad.stateModule:getFirstMarker() ~= nil and self.vehicle.ad.stateModule:getFirstMarker() ~= 0 and self.vehicle.ad.stateModule:getFirstMarker().id ~= nil then
		point = ADGraphManager:getWayPointById(self.vehicle.ad.stateModule:getFirstMarker().id)
		if point ~= nil then
			distanceToStart = MathUtil.vector2Length(x - point.x, z - point.z)
		end
	end

    local trailers, _ = AutoDrive.getTrailersOf(self.vehicle, false)
    local fillLevel, leftCapacity = AutoDrive.getFillLevelAndCapacityOfAll(trailers)
    local maxCapacity = fillLevel + leftCapacity
    local filledToUnload = (leftCapacity <= (maxCapacity * (1 - AutoDrive.getSetting("unloadFillLevel", self.vehicle) + 0.001)))

	if self.state == LoadMode.STATE_INIT then
		AutoDrive.debugPrint(self.vehicle, AutoDrive.DC_PATHINFO, "[AD] LoadMode:getNextTask STATE_INIT self.state %s distanceToStart %s", tostring(self.state), tostring(distanceToStart))
		if AutoDrive.checkIsOnField(x, y, z)  and distanceToStart > 30 then
			-- is activated on a field - use ExitFieldTask to leave field according to setting
			AutoDrive.debugPrint(self.vehicle, AutoDrive.DC_PATHINFO, "[AD] LoadMode:getNextTask set STATE_EXIT_FIELD")
			self.state = LoadMode.STATE_EXIT_FIELD
		elseif filledToUnload then	-- fill level above setting unload level
			AutoDrive.debugPrint(self.vehicle, AutoDrive.DC_PATHINFO, "[AD] LoadMode:getNextTask set STATE_LOAD")
			self.state = LoadMode.STATE_LOAD
		else
			-- fill capacity left - go to pickup
			AutoDrive.debugPrint(self.vehicle, AutoDrive.DC_PATHINFO, "[AD] LoadMode:getNextTask set STATE_TO_TARGET")
			self.state = LoadMode.STATE_TO_TARGET
		end
		AutoDrive.debugPrint(self.vehicle, AutoDrive.DC_PATHINFO, "[AD] LoadMode:getNextTask STATE_INIT end self.state %s", tostring(self.state))
	end

	if self.state == LoadMode.STATE_TO_TARGET then
		-- STATE_TO_TARGET - drive to load destination
		AutoDrive.debugPrint(self.vehicle, AutoDrive.DC_PATHINFO, "[AD] LoadMode:getNextTask STATE_TO_TARGET LoadAtDestinationTask...")
		nextTask = LoadAtDestinationTask:new(self.vehicle, self.vehicle.ad.stateModule:getSecondMarker().id)
		self.state = LoadMode.STATE_LOAD
    elseif self.state == LoadMode.STATE_LOAD then
		-- STATE_LOAD - drive to field
		AutoDrive.debugPrint(self.vehicle, AutoDrive.DC_PATHINFO, "[AD] LoadMode:getNextTask STATE_LOAD DriveToDestinationTask...")
        nextTask = DriveToDestinationTask:new(self.vehicle, self.vehicle.ad.stateModule:getFirstMarker().id)
        self.state = LoadMode.STATE_FINISHED
    elseif self.state == self.STATE_EXIT_FIELD then
		-- is activated on a field - use ExitFieldTask to leave field according to setting
		AutoDrive.debugPrint(self.vehicle, AutoDrive.DC_PATHINFO, "[AD] LoadMode:getNextTask STATE_EXIT_FIELD ExitFieldTask...")
		nextTask = ExitFieldTask:new(self.vehicle)
		if filledToUnload then	-- fill level above setting unload level
			AutoDrive.debugPrint(self.vehicle, AutoDrive.DC_PATHINFO, "[AD] LoadMode:getNextTask set STATE_LOAD")
			self.state = LoadMode.STATE_LOAD
		else
			-- fill capacity left - go to pickup
			AutoDrive.debugPrint(self.vehicle, AutoDrive.DC_PATHINFO, "[AD] LoadMode:getNextTask set STATE_TO_TARGET")
			self.state = LoadMode.STATE_TO_TARGET
		end
	else
		-- self.state == LoadMode.STATE_FINISHED then
		AutoDrive.debugPrint(self.vehicle, AutoDrive.DC_PATHINFO, "[AD] LoadMode:getNextTask STATE_FINISHED StopAndDisableADTask...")
		nextTask = StopAndDisableADTask:new(self.vehicle, ADTaskModule.DONT_PROPAGATE)
    end
    return nextTask
end

function LoadMode:shouldLoadOnTrigger()
    return (self.state == LoadMode.STATE_LOAD)
end
