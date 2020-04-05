ClearCropTask = ADInheritsFrom(AbstractTask)

ClearCropTask.TARGET_DISTANCE_SIDE = 10
ClearCropTask.TARGET_DISTANCE_FRONT_STEP = 10

function ClearCropTask:new(vehicle, combine)
    local o = ClearCropTask:create()
    o.vehicle = vehicle
    if combine ~= nil then
        o.combine = combine
    end
    return o
end

function ClearCropTask:setUp()
    AutoDrive.debugPrint(self.vehicle, AutoDrive.DC_COMBINEINFO, "Setting up ClearCropTask")
    local pipeSide = 1
    if combine ~= nil then
        pipeSide = AutoDrive.getPipeSide(self.combine)
    end
    self.wayPoints = {}
    table.insert(self.wayPoints, AutoDrive.createWayPointRelativeToVehicle(self.vehicle, (-ClearCropTask.TARGET_DISTANCE_SIDE / 2) * pipeSide, ClearCropTask.TARGET_DISTANCE_FRONT_STEP * 0.5))
    table.insert(self.wayPoints, AutoDrive.createWayPointRelativeToVehicle(self.vehicle, -ClearCropTask.TARGET_DISTANCE_SIDE * pipeSide, ClearCropTask.TARGET_DISTANCE_FRONT_STEP * 1))
    table.insert(self.wayPoints, AutoDrive.createWayPointRelativeToVehicle(self.vehicle, -ClearCropTask.TARGET_DISTANCE_SIDE * pipeSide, ClearCropTask.TARGET_DISTANCE_FRONT_STEP * 2))
    table.insert(self.wayPoints, AutoDrive.createWayPointRelativeToVehicle(self.vehicle, -ClearCropTask.TARGET_DISTANCE_SIDE * pipeSide, ClearCropTask.TARGET_DISTANCE_FRONT_STEP * 3))
    table.insert(self.wayPoints, AutoDrive.createWayPointRelativeToVehicle(self.vehicle, -ClearCropTask.TARGET_DISTANCE_SIDE * pipeSide, ClearCropTask.TARGET_DISTANCE_FRONT_STEP * 4))

    self.vehicle.ad.drivePathModule:setWayPoints(self.wayPoints)
end

function ClearCropTask:update(dt)
    -- Check if the driver and trailers have left the crop yet
    if not AutoDrive.isVehicleOrTrailerInCrop(self.vehicle) then
        self:finished()
    else
        if self.vehicle.ad.drivePathModule:isTargetReached() then
            self:finished()
        else
            self.vehicle.ad.drivePathModule:update(dt)
        end
    end
end

function ClearCropTask:abort()
end

function ClearCropTask:finished()
    AutoDrive.debugPrint(self.vehicle, AutoDrive.DC_COMBINEINFO, "ClearCropTask:finished()")
    self.vehicle.ad.taskModule:setCurrentTaskFinished()
end

function ClearCropTask:getInfoText()
    return g_i18n:getText("AD_task_clearcrop")
end

function ClearCropTask:getI18nInfo()
    return "$l10n_AD_task_clearcrop;"
end
