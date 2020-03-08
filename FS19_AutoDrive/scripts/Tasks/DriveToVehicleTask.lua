DriveToVehicleTask = ADInheritsFrom(AbstractTask)

DriveToVehicleTask.TARGET_DISTANCE = 15

DriveToVehicleTask.STATE_PATHPLANNING = 1
DriveToVehicleTask.STATE_DRIVING = 2

function DriveToVehicleTask:new(vehicle, targetVehicle)
    local o = DriveToVehicleTask:create()
    o.vehicle = vehicle
    o.targetVehicle = targetVehicle
    o.state = DriveToVehicleTask.STATE_PATHPLANNING
    o.wayPoints = nil
    return o
end

function DriveToVehicleTask:setUp()
    print("Setting up DriveToVehicleTask")
    self.vehicle.ad.pathFinderModule:startPathPlanningToVehicle(self.targetVehicle, DriveToVehicleTask.TARGET_DISTANCE)
end

function DriveToVehicleTask:update(dt)
    if self.state == DriveToVehicleTask.STATE_PATHPLANNING then
        if self.vehicle.ad.pathFinderModule:hasFinished() then
            self.wayPoints = self.vehicle.ad.pathFinderModule:getPath()
            self.vehicle.ad.drivePathModule:setWayPoints(self.wayPoints)
            self.state = DriveToVehicleTask.STATE_DRIVING
        else
            self.vehicle.ad.pathFinderModule:update()
        end
    elseif self.state == DriveToVehicleTask.STATE_DRIVING then
        if self.vehicle.ad.drivePathModule:isTargetReached() then
            self:finished()
        else
            self.vehicle.ad.drivePathModule:update(dt)
        end
    end
end

function DriveToVehicleTask:abort()
end

function DriveToVehicleTask:finished()
    self.vehicle.ad.taskModule:setCurrentTaskFinished()
end
