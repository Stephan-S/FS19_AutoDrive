AutoDriveVehicleData = {}
function AutoDriveVehicleData:new(vehicle)
    local o = {}
    setmetatable(o, self)
    self.__index = self
    o.vehicle = vehicle
    AutoDriveVehicleData.reset(o)
    return o
end

function AutoDriveVehicleData:reset()
    self.WorkToolParkDestination = -1
    self.driverName = g_i18n:getText("UNKNOWN")
    if self.vehicle.getName ~= nil then
        self.driverName = self.vehicle:getName()
    end
end

function AutoDriveVehicleData.prerequisitesPresent(specializations)
    return true
end

function AutoDriveVehicleData.registerEventListeners(vehicleType)
    AutoDrive.debugPrint(nil, AutoDrive.DC_EXTERNALINTERFACEINFO, "[AD] AutoDriveVehicleData.registerEventListeners ")
    for _, n in pairs(
        {
            "onPreLoad",
            "onLoad",
            "onPostLoad",
            "onSelect",
            "saveToXMLFile"
            -- ,"onReadStream"
            -- ,"onWriteStream"
            -- ,"onReadUpdateStream"
            -- ,"onWriteUpdateStream"
        }
    ) do
        SpecializationUtil.registerEventListener(vehicleType, n, AutoDriveVehicleData)
    end
end

function AutoDrive.registerFunctions(vehicleType)
    SpecializationUtil.registerFunction(vehicleType, "getWorkToolParkDestination", AutoDriveVehicleData.getWorkToolParkDestination)
    SpecializationUtil.registerFunction(vehicleType, "setWorkToolParkDestination", AutoDriveVehicleData.setWorkToolParkDestination)
end

function AutoDriveVehicleData:onPreLoad(savegame)
    -- if self.spec_advd == nil then
    -- self.spec_advd = AutoDriveVehicleData
    -- end
end

function AutoDriveVehicleData:onLoad(savegame)
    AutoDrive.debugPrint(self, AutoDrive.DC_EXTERNALINTERFACEINFO, "[AD] AutoDriveVehicleData.onLoad vehicle %s savegame %s", tostring(self:getName()), tostring(savegame))
    if self.advd == nil then
        self.advd = {}
    end
    self.advd = AutoDriveVehicleData:new(self)
    self.advd.dirtyFlag = self:getNextDirtyFlag()
    self.advd.WorkToolParkDestination = -1
end

function AutoDriveVehicleData:onPostLoad(savegame)
    AutoDrive.debugPrint(self, AutoDrive.DC_EXTERNALINTERFACEINFO, "[AD] AutoDriveVehicleData.onPostLoad vehicle %s savegame %s self %s", tostring(self:getName()), tostring(savegame), tostring(self))
    if self.advd == nil then
        return
    end
    -- if self.isServer then
    if savegame ~= nil then
        AutoDrive.debugPrint(self, AutoDrive.DC_EXTERNALINTERFACEINFO, "[AD] AutoDriveVehicleData.onPostLoad self.isServer")
        local xmlFile = savegame.xmlFile
        local key = savegame.key .. ".FS19_AutoDrive.AutoDriveVehicleData"
        self.advd.WorkToolParkDestination = Utils.getNoNil(getXMLInt(xmlFile, key .. "#WorkToolParkDestination"), -1)
    end
    -- end
end

function AutoDriveVehicleData:onSelect()
    local rootAttacherVehicle = self:getRootVehicle()
    if rootAttacherVehicle ~= nil and rootAttacherVehicle ~= self then
        if rootAttacherVehicle.ad ~= nil and rootAttacherVehicle.ad.stateModule ~= nil then
            local actualParkDestination = AutoDrive.getActualParkDestination(rootAttacherVehicle)
            if actualParkDestination >= 1 then
                rootAttacherVehicle.ad.stateModule:setParkDestinationAtJobFinished(actualParkDestination)
            else
                rootAttacherVehicle.ad.stateModule:setParkDestinationAtJobFinished(-1)
            end
        end
    end
end

function AutoDriveVehicleData:saveToXMLFile(xmlFile, key)
    AutoDrive.debugPrint(self, AutoDrive.DC_EXTERNALINTERFACEINFO, "[AD] AutoDriveVehicleData.saveToXMLFile vehicle %s", tostring(self:getName()))
    if self.advd == nil then
        return
    end
    if self.advd.WorkToolParkDestination ~= nil and self.advd.WorkToolParkDestination > 0 then
        AutoDrive.debugPrint(self, AutoDrive.DC_EXTERNALINTERFACEINFO, "[AD] AutoDriveVehicleData.saveToXMLFile WorkToolParkDestination %s", tostring(self.advd.WorkToolParkDestination))
        if self.isServer then
            setXMLInt(xmlFile, key .. "#saved_by_server", 1)
        end
        setXMLInt(xmlFile, key .. "#WorkToolParkDestination", self.advd.WorkToolParkDestination)
    end
end

function AutoDriveVehicleData:onReadStream(streamId, connection) -- Called on client side on join
    if self ~= nil and self.vehicle ~= nil then
        AutoDrive.debugPrint(self, AutoDrive.DC_EXTERNALINTERFACEINFO, "[AD] AutoDriveVehicleData.onReadStream vehicle %s", tostring(self.vehicle:getName()))
    end
    if self.vehicle.advd == nil then
        return
    end
    self.vehicle.advd.WorkToolParkDestination = streamReadUIntN(streamId, 20) - 1
end

function AutoDriveVehicleData:onWriteStream(streamId, connection) -- Called on server side on join
    if self ~= nil and self.vehicle ~= nil then
        AutoDrive.debugPrint(self, AutoDrive.DC_EXTERNALINTERFACEINFO, "[AD] AutoDriveVehicleData.onWriteStream vehicle %s", tostring(self.vehicle:getName()))
    end
    if self.vehicle.advd == nil then
        return
    end
    streamWriteUIntN(streamId, self.vehicle.advd.WorkToolParkDestination + 1, 20)
end

function AutoDriveVehicleData:onReadUpdateStream(streamId, timestamp, connection) -- Called on on update
    if self ~= nil and self.vehicle ~= nil then
        AutoDrive.debugPrint(self, AutoDrive.DC_EXTERNALINTERFACEINFO, "[AD] AutoDriveVehicleData.onReadUpdateStream vehicle %s", tostring(self.vehicle:getName()))
    end
    if self.vehicle.advd == nil then
        return
    end
    if connection:getIsServer() then
        if streamReadBool(streamId) then
            AutoDrive.debugPrint(self, AutoDrive.DC_EXTERNALINTERFACEINFO, "[AD] AutoDriveVehicleData.onReadUpdateStream streamReadBool ")
            self.vehicle.advd.WorkToolParkDestination = streamReadUIntN(streamId, 20) - 1
        end
    end
end

function AutoDriveVehicleData:onWriteUpdateStream(streamId, connection, dirtyMask) -- Called on on update
    if self ~= nil and self.vehicle ~= nil then
        AutoDrive.debugPrint(self, AutoDrive.DC_EXTERNALINTERFACEINFO, "[AD] AutoDriveVehicleData.onWriteUpdateStream vehicle %s", tostring(self.vehicle:getName()))
    end
    if self.vehicle.advd == nil then
        return
    end
    if not connection:getIsServer() then
        if streamWriteBool(streamId, bitAND(dirtyMask, self.advd.dirtyFlag) ~= 0) then
            AutoDrive.debugPrint(self, AutoDrive.DC_EXTERNALINTERFACEINFO, "[AD] AutoDriveVehicleData.onWriteUpdateStream streamReadBool ")
            streamWriteUIntN(streamId, self.vehicle.advd.WorkToolParkDestination + 1, 20)
        end
    end
end

function AutoDriveVehicleData:getWorkToolParkDestination()
    if self ~= nil and self.vehicle ~= nil then
        AutoDrive.debugPrint(self.vehicle, AutoDrive.DC_EXTERNALINTERFACEINFO, "[AD] AutoDriveVehicleData:getWorkToolParkDestination vehicle %s", tostring(self.vehicle:getName()))
    end
    if self.vehicle.advd == nil then
        return -1
    end
    return self.vehicle.advd.WorkToolParkDestination
end

function AutoDriveVehicleData:setWorkToolParkDestination(WorkToolParkDestination)
    if self ~= nil and self.vehicle ~= nil then
        AutoDrive.debugPrint(self.vehicle, AutoDrive.DC_EXTERNALINTERFACEINFO, "[AD] AutoDriveVehicleData:setWorkToolParkDestination vehicle %s WorkToolParkDestination %s", tostring(self.vehicle:getName()), tostring(WorkToolParkDestination))
    end
    if self.vehicle.advd == nil then
        return
    end
    self.vehicle.advd.WorkToolParkDestination = WorkToolParkDestination
    self.vehicle:raiseDirtyFlags(self.vehicle.advd.dirtyFlag)
    -- TODO
    -- if g_client ~= nil then
    -- AutoDriveVehicleDataEvent.sendEvent(self.vehicle, WorkToolParkDestination)
    -- end
end

AutoDriveVehicleDataEvent = {}
AutoDriveVehicleDataEvent_mt = Class(AutoDriveVehicleDataEvent, Event)

InitEventClass(AutoDriveVehicleDataEvent, "AutoDriveVehicleDataEvent")

function AutoDriveVehicleDataEvent:emptyNew()
    local o = Event:new(AutoDriveVehicleDataEvent_mt)
    o.className = "AutoDriveVehicleDataEvent"
    return o
end

function AutoDriveVehicleDataEvent:new(vehicle, WorkToolParkDestination)
    local o = AutoDriveVehicleDataEvent:emptyNew()
    o.vehicle = vehicle
    o.WorkToolParkDestination = WorkToolParkDestination
    return o
end

function AutoDriveVehicleDataEvent:writeStream(streamId, connection)
    AutoDrive.debugPrint(self.vehicle, AutoDrive.DC_EXTERNALINTERFACEINFO, "[AD] AutoDriveVehicleDataEvent:writeStream connection %s", tostring(connection))
    if self.vehicle.advd == nil then
        return
    end
    streamWriteInt32(streamId, NetworkUtil.getObjectId(self.vehicle))
    streamWriteUIntN(streamId, self.vehicle.advd.WorkToolParkDestination + 1, 20)
end

function AutoDriveVehicleDataEvent:readStream(streamId, connection)
    AutoDrive.debugPrint(self.vehicle, AutoDrive.DC_EXTERNALINTERFACEINFO, "[AD] AutoDriveVehicleDataEvent:readStream connection %s", tostring(connection))
    local vehicle = nil
    local WorkToolParkDestination = -1

    vehicle = NetworkUtil.getObject(streamReadInt32(streamId))
    if vehicle ~= nil and vehicle.advd ~= nil then
        WorkToolParkDestination = streamReadUIntN(streamId, 20) - 1
        if WorkToolParkDestination ~= nil then
            vehicle.advd:setWorkToolParkDestination(WorkToolParkDestination)
            -- Server have to broadcast to all clients
            if g_server ~= nil then
                AutoDriveVehicleDataEvent.sendEvent(vehicle, WorkToolParkDestination)
            end
        end
    end
end

function AutoDriveVehicleDataEvent.sendEvent(vehicle, WorkToolParkDestination)
    local event = AutoDriveVehicleDataEvent:new(vehicle, WorkToolParkDestination)
    AutoDrive.debugPrint(vehicle, AutoDrive.DC_EXTERNALINTERFACEINFO, "[AD] AutoDriveVehicleDataEvent:sendEvent WorkToolParkDestination %s", tostring(WorkToolParkDestination))
    if g_server ~= nil then
        AutoDrive.debugPrint(vehicle, AutoDrive.DC_EXTERNALINTERFACEINFO, "[AD] AutoDriveVehicleDataEvent:sendEvent getIsServer ")
        -- Server have to broadcast to all clients and himself
        g_server:broadcastEvent(event)
    else
        AutoDrive.debugPrint(vehicle, AutoDrive.DC_EXTERNALINTERFACEINFO, "[AD] AutoDriveVehicleDataEvent:sendEvent else getIsServer ")
        -- Client have to send to server
        g_client:getServerConnection():sendEvent(event)
    end
end
