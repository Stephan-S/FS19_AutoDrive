CombineUnloaderMode = ADInheritsFrom(AbstractMode)



function CombineUnloaderMode:getExcludedVehiclesForCollisionCheck()
    local excludedVehicles = {}
    if self.assignedCombine ~= nil and self:ignoreCombineCollision() then
        table.insert(excludedVehicles, self.assignedCombine)
    end
    
    return excludedVehicles
end

function CombineUnloaderMode:ignoreCombineCollision()
    if (self.combineState == AutoDrive.DRIVE_TO_COMBINE or self.combineState == AutoDrive.PREDRIVE_COMBINE or self.combineState == AutoDrive.CHASE_COMBINE) then
		return true
	end
    
    return false
end