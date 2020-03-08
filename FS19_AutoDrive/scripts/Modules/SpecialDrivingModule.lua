ADSpecialDrivingModule = {}

function ADSpecialDrivingModule:new(vehicle)
    local o = {}
    setmetatable(o, self)
    self.__index = self
    o.vehicle = vehicle
    ADSpecialDrivingModule.reset(o)
    return o
end

function ADSpecialDrivingModule:reset()
    self.shouldStopOrHoldVehicle = false
end

function ADSpecialDrivingModule:stopVehicle(lx, lz)
    self.shouldStopOrHoldVehicle = true
    self.targetLX = lx
    self.targetLZ = lz
end

function ADSpecialDrivingModule:releaseVehicle()
    self.shouldStopOrHoldVehicle = false
    self.motorShouldBeStopped = false
end

function ADSpecialDrivingModule:update(dt)
    if self.shouldStopOrHoldVehicle then
        self:stopAndHoldVehicle(dt)
    end
end

function ADSpecialDrivingModule:isStoppingVehicle()
    return self.shouldStopOrHoldVehicle
end

function ADSpecialDrivingModule:stopAndHoldVehicle(dt)
	local finalSpeed = 0
	local acc = -0.6
	local allowedToDrive = false

	if math.abs(self.vehicle.lastSpeedReal) > 0.002 then
		finalSpeed = 0.01
		allowedToDrive = true
	end

	local x, y, z = getWorldTranslation(self.vehicle.components[1].node)
    
    local lx, lz = self.targetLX, self.targetLZ 
    
    if lx == nil or lz == nil then
        --If no target was provided, aim in front of te vehicle to prevent steering maneuvers
        local rx, _, rz = localDirectionToWorld(self.vehicle.components[1].node, 0, 0, 1)
        x = x + rx
        z = z + rz
    
        lx, lz = AIVehicleUtil.getDriveDirection(self.vehicle.components[1].node, x, y, z)
    end

    AIVehicleUtil.driveInDirection(self.vehicle, dt, 30, acc, 0.2, 20, allowedToDrive, true, lx, lz, finalSpeed, 1)
    
    if self.vehicle.lastSpeedReal < 0.0013 then
        self.motorShouldBeStopped = true
        if self.vehicle.spec_motorized.isMotorStarted and (not g_currentMission.missionInfo.automaticMotorStartEnabled) then
            self.vehicle:stopMotor()
        end
    end
end

function ADSpecialDrivingModule:shouldStopMotor()
    return self.motorShouldBeStopped
end