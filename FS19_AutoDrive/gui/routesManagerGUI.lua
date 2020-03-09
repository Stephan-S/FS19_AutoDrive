ADRoutesManagerGui = {}
ADRoutesManagerGui.CONTROLS = {"textInputElement", "listItemTemplate", "RoutesManagerList"}

local ADRoutesManagerGui_mt = Class(ADRoutesManagerGui, ScreenElement)

function ADRoutesManagerGui:new(target)
    local o = ScreenElement:new(target, ADRoutesManagerGui_mt)
    o.returnScreenName = ""
    o.routes = {}
    o:registerControls(ADRoutesManagerGui.CONTROLS)
    return o
end

function ADRoutesManagerGui:onCreate()
    self.listItemTemplate:unlinkElement()
    self.listItemTemplate:setVisible(false)
end

function ADRoutesManagerGui:onOpen()
    self:refreshItems()
    ADRoutesManagerGui:superClass().onOpen(self)
end

function ADRoutesManagerGui:refreshItems()
    self.routes = RoutesManager.getRoutes(AutoDrive.loadedMap)
    self.RoutesManagerList:deleteListItems()
    for _, r in pairs(self.routes) do
        local new = self.listItemTemplate:clone(self.RoutesManagerList)
        new:setVisible(true)
        new.elements[1]:setText(r.name)
        new.elements[2]:setText(r.date)
        new:updateAbsolutePosition()
    end
end

function ADRoutesManagerGui:onListSelectionChanged(rowIndex)
end

function ADRoutesManagerGui:onDoubleClick(rowIndex)
    self.textInputElement:setText(self.routes[rowIndex].name)
end

function ADRoutesManagerGui:onClickOk()
    ADRoutesManagerGui:superClass().onClickOk(self)
    local newName = self.textInputElement.text
    if
        table.f_contains(
            self.routes,
            function(v)
                return v.name == newName
            end
        )
     then
        g_gui:showYesNoDialog({text = g_i18n:getText("gui_ad_routeExportWarn_text"), title = g_i18n:getText("gui_ad_routeExportWarn_title"), callback = self.onExportDialogCallback, target = self})
    else
        self:onExportDialogCallback(true)
    end
end

function ADRoutesManagerGui:onExportDialogCallback(yes)
    if yes then
        RoutesManager.export(self.textInputElement.text)
        self:refreshItems()
    end
end

function ADRoutesManagerGui:onClickCancel()
    if #self.routes > 0 then
        RoutesManager.import(self.routes[self.RoutesManagerList:getSelectedElementIndex()].name)
    end
    ADRoutesManagerGui:superClass().onClickCancel(self)
end

function ADRoutesManagerGui:onClickBack()
    ADRoutesManagerGui:superClass().onClickBack(self)
end

function ADRoutesManagerGui:onClickActivate()
    if #self.routes > 0 then
        g_gui:showYesNoDialog({text = g_i18n:getText("gui_ad_routeDeleteWarn_text"):format(self.routes[self.RoutesManagerList:getSelectedElementIndex()].name), title = g_i18n:getText("gui_ad_routeDeleteWarn_title"), callback = self.onDeleteDialogCallback, target = self})
    end
    ADRoutesManagerGui:superClass().onClickActivate(self)
end

function ADRoutesManagerGui:onDeleteDialogCallback(yes)
    if yes then
        RoutesManager.remove(self.routes[self.RoutesManagerList:getSelectedElementIndex()].name)
        self:refreshItems()
    end
end

function ADRoutesManagerGui:onEnterPressed(_, isClick)
    if not isClick then
    --self:onClickOk()
    end
end

function ADRoutesManagerGui:onEscPressed()
    self:onClickBack()
end
