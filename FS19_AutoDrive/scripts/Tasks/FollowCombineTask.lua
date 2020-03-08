--abort condition
if self.distanceToChasePos < 25 and AutoDrive:getAngleToChasePos(vehicle, vehicle.ccInfos.chasePos) < 40 and vehicle.ccInfos.angleToCombineHeading < 90 then 