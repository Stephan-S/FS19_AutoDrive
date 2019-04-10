FieldDataCallback = {};

function FieldDataCallback:new(driver, x, z)
    o = {}
    setmetatable(o, self)
    self.__index = self
    o.driver = driver;
    o.x = x;
    o.z = z;
    return o
end;

function FieldDataCallback:onFieldDataUpdateFinished(fielddata)
    if self.driver ~= nil then
        AutoDrive:onFieldDataUpdateFinished(self.driver, fielddata, self.x, self.z);
    end;
end;    