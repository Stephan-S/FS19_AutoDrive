PathFinderCallBack = {};

function PathFinderCallBack:new(pf, cell)
    o = {}
    setmetatable(o, self)
    self.__index = self
    o.pf = pf;
    o.cell = cell;
    return o
end;

function PathFinderCallBack:onFieldDataUpdateFinished(fielddata)
    if self.pf ~= nil then
        AutoDrivePathFinder:onFieldDataUpdateFinished(self.pf, fielddata, self.cell);
    end;
end;    