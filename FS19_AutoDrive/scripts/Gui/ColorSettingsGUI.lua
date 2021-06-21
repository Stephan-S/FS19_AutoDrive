ADColorSettingsGui = {}
ADColorSettingsGui.CONTROLS = {"listItemTemplate", "autoDriveColorList"}
ADColorSettingsGui.debug = false

local ADColorSettingsGui_mt = Class(ADColorSettingsGui, ScreenElement)

function ADColorSettingsGui:new(target)
ADColorSettingsGui.debugMsg("[AD] ADColorSettingsGui:new") -- 1
    local o = ScreenElement:new(target, ADColorSettingsGui_mt)
    o.returnScreenName = ""
    o.colors = {}
    o.rowIndex = 0
    o:registerControls(ADColorSettingsGui.CONTROLS)
    return o
end

function ADColorSettingsGui:onCreate()
ADColorSettingsGui.debugMsg("[AD] ADColorSettingsGui:onCreate") -- 2
    self.listItemTemplate:unlinkElement()
    self.listItemTemplate:setVisible(false)
end

function ADColorSettingsGui:onOpen()
ADColorSettingsGui.debugMsg("[AD] ADColorSettingsGui:onOpen") -- 4
    self:refreshItems()
    ADColorSettingsGui:superClass().onOpen(self)
end

function ADColorSettingsGui:refreshItems()
ADColorSettingsGui.debugMsg("[AD] ADColorSettingsGui:refreshItems")   -- 5
    self.rowIndex = 1
    self.colors = AutoDrive:getColorKeyNames()
    self.autoDriveColorList:deleteListItems()
    for _, n in pairs(self.colors) do
        local new = self.listItemTemplate:clone(self.autoDriveColorList)
        new:setVisible(true)
        new.elements[1]:setText(g_i18n:getText(n))
        new:updateAbsolutePosition()
    end
end

function ADColorSettingsGui:onListSelectionChanged(rowIndex)
ADColorSettingsGui.debugMsg("[AD] ADColorSettingsGui:onListSelectionChanged rowIndex %s", tostring(rowIndex)) -- 3 -> rowIndex==0 !!!
    if rowIndex > 0 then
        self.rowIndex = rowIndex
    end
end

function ADColorSettingsGui:onClickOk()   -- OK
ADColorSettingsGui.debugMsg("[AD] ADColorSettingsGui:onClickOk self.rowIndex %s", tostring(self.rowIndex))
    local controlledVehicle = g_currentMission.controlledVehicle
    if controlledVehicle ~= nil and controlledVehicle.ad ~= nil and controlledVehicle.ad.selectedColorNodeId ~= nil then
        local colorPoint = ADGraphManager:getWayPointById(controlledVehicle.ad.selectedColorNodeId)
        if colorPoint ~= nil and colorPoint.colors ~= nil then
            if self.rowIndex > 0 then
                local colorKeyName = self.colors[self.rowIndex]
                AutoDrive:setColorAssignment(colorKeyName, colorPoint.colors[1], colorPoint.colors[2], colorPoint.colors[3])
                AutoDrive.writeLocalSettingsToXML()
            end
        end
    end
ADColorSettingsGui.debugMsg("[AD] ADColorSettingsGui:onClickOk end")
    ADColorSettingsGui:superClass().onClickBack(self)
end

function ADColorSettingsGui:onClickBack()   -- ESC
ADColorSettingsGui.debugMsg("[AD] ADColorSettingsGui:onClickBack")
    ADColorSettingsGui:superClass().onClickBack(self)
end

function ADColorSettingsGui:onClickReset()
ADColorSettingsGui.debugMsg("[AD] ADColorSettingsGui:onClickReset")
    if self.rowIndex > 0 then
        local colorKeyName = self.colors[self.rowIndex]
        AutoDrive:resetColorAssignment(colorKeyName)
        AutoDrive.writeLocalSettingsToXML()
    end
    ADColorSettingsGui:superClass().onClickBack(self)
end

function ADColorSettingsGui:onEnterPressed(_, isClick)
ADColorSettingsGui.debugMsg("[AD] ADColorSettingsGui:onEnterPressed isClick %s", tostring(isClick))
    if not isClick then
        -- self:onDoubleClick(self.autoDriveColorList:getSelectedElementIndex())
    end
end

function ADColorSettingsGui:onEscPressed()
ADColorSettingsGui.debugMsg("[AD] ADColorSettingsGui:onEscPressed")
    self:onClickBack()
end

function ADColorSettingsGui.debugMsg(...)
    if ADColorSettingsGui.debug == true then
        g_logManager:info(...)
    end
end
