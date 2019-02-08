
function AutoDrive:getCurrentFillType(vehicle)
    local trailer = nil;
    if vehicle.attachedImplements ~= nil then
        for _, implement in pairs(vehicle.attachedImplements) do
            if implement.object ~= nil then
                if implement.object.typeDesc == g_i18n:getText("typeDesc_tipper") then
                    trailer = implement.object;
                end;
            end;
        end;
    end;

    if vehicle.bUnloadAtTrigger == true and trailer ~= nil then
        local fillTable = trailer:getCurrentFillTypes();
        if fillTable[1] ~= nil then
            return fillTable[1];
        end;
    end;
end;