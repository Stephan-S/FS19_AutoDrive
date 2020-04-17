ClearCropTask = ADInheritsFrom(AbstractTask)

ClearCropTask.TARGET_DISTANCE_SIDE = 10
ClearCropTask.TARGET_DISTANCE_FRONT_STEP = 10
ClearCropTask.STATE_CLEARING = 1
ClearCropTask.STATE_REVERSING = 2

function ClearCropTask:new(vehicle, combine)
    local o = ClearCropTask:create()
    o.vehicle = vehicle
    if combine ~= nil then
        o.combine = combine
    end
    o.stuckTimer = AutoDriveTON:new()
    o.state = ClearCropTask.STATE_CLEARING
    o.reverseStartLocation = nil
    return o
end

function ClearCropTask:setUp()
    AutoDrive.debugPrint(self.vehicle, AutoDrive.DC_COMBINEINFO, "Setting up ClearCropTask")
    local pipeSide = 1
    if self.combine ~= nil then
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
    if self.state == ClearCropTask.STATE_CLEARING then
        -- Check if the driver and trailers have left the crop yet
        if not AutoDrive.isVehicleOrTrailerInCrop(self.vehicle, true) then
            self:finished()
        else
            if self.vehicle.ad.drivePathModule:isTargetReached() then
                self:finished()
            elseif self.stuckTimer:done() then
                local x, y, z = getWorldTranslation(self.vehicle.components[1].node)
                self.reverseStartLocation = {x = x, y = y, z = z}
                self.state = ClearCropTask.STATE_REVERSING
            else
                self.stuckTimer:timer(true, 30000, dt)
                self.vehicle.ad.drivePathModule:update(dt)
            end
        end
    elseif self.state == ClearCropTask.STATE_REVERSING then
        local x, y, z = getWorldTranslation(self.vehicle.components[1].node)
        self.stuckTimer:timer(false)
        local distanceToReversStart = MathUtil.vector2Length(x - self.reverseStartLocation.x, z - self.reverseStartLocation.z)
        if not AutoDrive.isVehicleOrTrailerInCrop(self.vehicle, true) then
            self:finished()
        elseif distanceToReversStart > 10 then
            self.state = ClearCropTask.STATE_CLEARING
        else
            self.vehicle.ad.specialDrivingModule:driveReverse(dt, 15, 1)
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
