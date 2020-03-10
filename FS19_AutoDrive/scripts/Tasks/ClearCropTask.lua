if vehicle.ad.fieldParkLocations == nil then
    vehicle.ad.fieldParkLocations = {}
    vehicle.ad.fieldParkLocations[1] = {}
    vehicle.ad.fieldParkLocations[1].x, vehicle.ad.fieldParkLocations[1].y, vehicle.ad.fieldParkLocations[1].z = localToWorld(vehicle.components[1].node, -10, 0, 10)
    vehicle.ad.fieldParkLocations[2] = {}
    vehicle.ad.fieldParkLocations[2].x, vehicle.ad.fieldParkLocations[2].y, vehicle.ad.fieldParkLocations[2].z = localToWorld(vehicle.components[1].node, -10, 0, 20)
    vehicle.ad.fieldParkLocations[3] = {}
    vehicle.ad.fieldParkLocations[3].x, vehicle.ad.fieldParkLocations[3].y, vehicle.ad.fieldParkLocations[3].z = localToWorld(vehicle.components[1].node, -10, 0, 30)
    vehicle.ad.fieldParkLocationStep = 1
else
    if not vehicle.ad.sensors.frontSensor:pollInfo() then
        local x, _, z = getWorldTranslation(vehicle.components[1].node)
        local distanceToParkSpot = MathUtil.vector2Length(vehicle.ad.fieldParkLocations[vehicle.ad.fieldParkLocationStep].x - x, vehicle.ad.fieldParkLocations[vehicle.ad.fieldParkLocationStep].z - z)
        
        if distanceToParkSpot < 2 then
            vehicle.ad.fieldParkLocationStep = vehicle.ad.fieldParkLocationStep + 1
            if vehicle.ad.fieldParkLocationStep > 3 then
                --wait in field
                AutoDrive.waitingUnloadDrivers[vehicle] = vehicle
                vehicle.ad.combineState = AutoDrive.WAIT_FOR_COMBINE
                --vehicle.ad.initialized = false;
                vehicle.ad.wayPoints = {}
                vehicle.ad.isPaused = true
                if vehicle.ad.currentCombine ~= nil then
                    vehicle.ad.currentCombine.ad.currentDriver = nil
                    vehicle.ad.currentCombine.ad.preCalledDriver = false
                    vehicle.ad.currentCombine.ad.driverOnTheWay = false
                    vehicle.ad.currentCombine = nil
                end
            end
        else         
            drivingEnabled = true                           
            local lx, lz = AIVehicleUtil.getDriveDirection(vehicle.components[1].node, vehicle.ad.fieldParkLocations[vehicle.ad.fieldParkLocationStep].x, vehicle.ad.fieldParkLocations[vehicle.ad.fieldParkLocationStep].y, vehicle.ad.fieldParkLocations[vehicle.ad.fieldParkLocationStep].z)
            AIVehicleUtil.driveInDirection(vehicle, dt, 30, 1, 0.2, 20, true, true, lx, lz, 10, 1)
        end
    end
end


ClearCropTask = ADInheritsFrom(AbstractTask)

ClearCropTask.TARGET_DISTANCE_SIDE = 12
ClearCropTask.TARGET_DISTANCE_FRONT_STEP = 10

function ClearCropTask:new(vehicle)
    local o = ClearCropTask:create()
    o.vehicle = vehicle
    return o
end

function ClearCropTask:setUp()
    AutoDrive.debugPrint(vehicle, AutoDrive.DC_COMBINEINFO, "Setting up ClearCropTask")
    self.wayPoints = {}
    table.insert(self.wayPoints, AutoDrive.createWayPointRelativeToVehicle(self.vehicle, -ClearCropTask.TARGET_DISTANCE_SIDE, ClearCropTask.TARGET_DISTANCE_FRONT_STEP * 1))
    table.insert(self.wayPoints, AutoDrive.createWayPointRelativeToVehicle(self.vehicle, -ClearCropTask.TARGET_DISTANCE_SIDE, ClearCropTask.TARGET_DISTANCE_FRONT_STEP * 2))
    table.insert(self.wayPoints, AutoDrive.createWayPointRelativeToVehicle(self.vehicle, -ClearCropTask.TARGET_DISTANCE_SIDE, ClearCropTask.TARGET_DISTANCE_FRONT_STEP * 3))
    self.vehicle.ad.drivePathModule:setWayPoints(self.wayPoints)
end

function ClearCropTask:update(dt)    
    -- Check if the driver and trailers have left the crop yet
    if AutoDrive.isVehicleOrTrailerInCrop(self.vehicle) then
        self:finished()
    else
        self.vehicle.ad.drivePathModule:update(dt)
    end
end

function ClearCropTask:abort()
end

function ClearCropTask:finished()
    AutoDrive.debugPrint(vehicle, AutoDrive.DC_COMBINEINFO, "ClearCropTask:finished()")
    self.vehicle.ad.taskModule:setCurrentTaskFinished()
end