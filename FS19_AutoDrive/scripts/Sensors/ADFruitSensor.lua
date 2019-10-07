ADFruitSensor = ADInheritsFrom( ADSensor )



function ADFruitSensor:new(vehicle, sensorParameters)
    local self = ADFruitSensor:create();
    self:init(vehicle, ADSensor.TYPE_FRUIT, sensorParameters);
    self.fruitType = 0;
    self.foundFruitType = 0;

    if sensorParameters.fruitType ~= nil then
        self.fruitType = fruitType;
    end;
	
    return self;
end;

function ADFruitSensor:onUpdate(dt)  
    local box = self:getBoxShape();
    local corners = self:getCorners(box);
    
    local foundFruit = false;
    if self.fruitType == nil or self.fruitType == 0 then
        foundFruit, foundFruitType = self:checkForFruitInArea(corners);
        --if foundFruit then
           -- self.fruitType = foundFruitType;
        --end;
    else
        foundFruit = self:checkForFruitTypeInArea(self.fruitType, corners);
    end;

    self:setTriggered(foundFruit);
    
    self:onDrawDebug(box);
end;

function ADFruitSensor:checkForFruitInArea(corners)
    for i = 1, #g_fruitTypeManager.fruitTypes do
        if i ~= g_fruitTypeManager.nameToIndex['GRASS'] and i ~= g_fruitTypeManager.nameToIndex['DRYGRASS'] then 
            local fruitTypeToCheck = g_fruitTypeManager.fruitTypes[i].index;
            if self:checkForFruitTypeInArea(fruitTypeToCheck, corners) then
                return true, fruitTypeToCheck;
            end;
        end;
    end;
    return false;
end;

function ADFruitSensor:checkForFruitTypeInArea(fruitType, corners)        
    local fruitValue = 0;
    if fruitType == 9 or fruitType == 22 then
        fruitValue, _, _, _ = FSDensityMapUtil.getFruitArea(fruitType, corners[1].x, corners[1].z, corners[2].x, corners[2].z, corners[3].x, corners[3].z, true, true);
    else
        fruitValue , _, _, _ = FSDensityMapUtil.getFruitArea(fruitType, corners[1].x, corners[1].z, corners[2].x, corners[2].z, corners[3].x, corners[3].z, nil, false);
    end;
    
    return (fruitValue > 50);
end;

function ADFruitSensor:setFruitType(newFruitType)
    self.fruitType = newFruitType;
end;