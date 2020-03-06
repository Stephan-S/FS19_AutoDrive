--
-- FlaggedTable utility for AutoDrive
--
-- @author TyKonKet
-- @date  06/03/20

FlaggedTable = {}
FlaggedTable_mt = Class(FlaggedTable)

function FlaggedTable:new()
    local q = {}
    setmetatable(q, FlaggedTable_mt)
    q.items = {}
    q.itemsCount = 0
    return q
end

function FlaggedTable:Add(key, value)
    if self.items[key] ~= nil then
        print("porcoddio ecco perchè " .. key)
    end
    self.items[key] = {value = value, flag = false}
    self.itemsCount = self.itemsCount + 1
end

function FlaggedTable:Flag(key)
    self.items[key].flag = true
end

function FlaggedTable:Unflag(key)
    self.items[key].flag = false
end

function FlaggedTable:ResetFlags()
    for _, item in pairs(self.items) do
        item.flag = false
    end
end

function FlaggedTable:RemoveFlagged()
    local r = {}
    for k, item in pairs(self.items) do
        if item.flag == true then
            table.insert(r, item.value)
            self.items[k] = nil
            self.itemsCount = self.itemsCount - 1
        end
    end
    return r
end

function FlaggedTable:RemoveUnflagged()
    local r = {}
    for k, item in pairs(self.items) do
        if item.flag == false then
            table.insert(r, item.value)
            self.items[k] = nil
            self.itemsCount = self.itemsCount - 1
        end
    end
    return r
end

function FlaggedTable:Count()
    return self.itemsCount
end

function FlaggedTable:Contains(key)
    return self.items[key] ~= nil
end
