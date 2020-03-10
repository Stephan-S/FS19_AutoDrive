FollowCombineTask = ADInheritsFrom(AbstractTask)

FollowCombineTask.STATE_CHASING = 1
FollowCombineTask.STATE_REVERSING = 2
FollowCombineTask.STATE_WAIT_FOR_TURN = 3

function FollowCombineTask:new(vehicle, combine)
    local o = FollowCombineTask:create()
    o.vehicle = vehicle
    o.combine = combine
    o.state = FollowCombineTask.STATE_CHASING
    o.reverseStartLocation = nil
    return o
end

function FollowCombineTask:setUp()
    AutoDrive.debugPrint(vehicle, AutoDrive.DC_COMBINEINFO, "Setting up FollowCombineTask")
end

function FollowCombineTask:update(dt)
    -- Get Chase pos
    -- Follow chase pos
    -- Detect turn maneuver
        -- reverse a little
        -- wait for turn to be finishd
            -- self:finished()


    -- old condition: if self.distanceToChasePos < 25 and AutoDrive:getAngleToChasePos(vehicle, vehicle.ccInfos.chasePos) < 40 and vehicle.ccInfos.angleToCombineHeading < 90 then 
end

function FollowCombineTask:abort()
end

function FollowCombineTask:finished()
    AutoDrive.debugPrint(vehicle, AutoDrive.DC_COMBINEINFO, "FollowCombineTask:finished()")
    self.vehicle.ad.taskModule:setCurrentTaskFinished()
end
