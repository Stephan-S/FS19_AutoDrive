--
-- AutoDrive Enter Target Name GUI
-- V1.1.0.0
--
-- @author Stephan Schlosser
-- @date 08/08/2019

ADEnterTargetNameGui = {}

local ADEnterTargetNameGui_mt = Class(ADEnterTargetNameGui, ScreenElement)

function ADEnterTargetNameGui:new(target)
    local o = ScreenElement:new(target, ADEnterTargetNameGui_mt)
    o.returnScreenName = ""
    o.textInputElement = nil
    o.createButtonElement = nil
    o.buttonsEditElement = nil
    o.buttonsCreateElement = nil
    o.titleElement = nil
    o.editName = nil
    o.editId = nil
    o.edit = false
    return o
end

function ADEnterTargetNameGui:onCreateInputElement(element)
    self.textInputElement = element
    element.text = ""
end

function ADEnterTargetNameGui:onCreateTitleElement(element)
    self.titleElement = element
end

function ADEnterTargetNameGui:onCreateTextElement(element)
    element:setText(g_i18n:getText("gui_ad_enterTargetNameText"))
end

function ADEnterTargetNameGui:onCreateCreateButton(element)
    self.createButtonElement = element
    element:setText(g_i18n:getText("gui_ad_createButtonText"))
end

function ADEnterTargetNameGui:onCreateButtonsCreate(element)
    self.buttonsCreateElement = element
end

function ADEnterTargetNameGui:onCreateButtonsEdit(element)
    self.buttonsEditElement = element
end

function ADEnterTargetNameGui:onOpen()
    ADEnterTargetNameGui:superClass().onOpen(self)
    self.editName = nil
    self.editId = nil
    self.edit = false
    FocusManager:setFocus(self.textInputElement)
    self.textInputElement.blockTime = 0
    self.textInputElement:onFocusActivate()

    -- If editSelectedMapMarker is true, we have to edit the map marker selected on the pull down list otherwise we can go for closest waypoint
    if AutoDrive.editSelectedMapMarker ~= nil and AutoDrive.editSelectedMapMarker == true then
        self.editId = g_currentMission.controlledVehicle.ad.mapMarkerSelected
        self.editName = AutoDrive.mapMarker[self.editId].name
    else
        local closest, _ = AutoDrive:findClosestWayPoint(g_currentMission.controlledVehicle)
        if closest ~= nil and closest ~= -1 and AutoDrive.mapWayPoints[closest] ~= nil then
            local cId = AutoDrive.mapWayPoints[closest].id
            for i, mapMarker in pairs(AutoDrive.mapMarker) do
                -- If we have already a map marker on this waypoint, we edit it otherwise we create a new one
                if mapMarker.id == cId then
                    self.editId = i
                    self.editName = mapMarker.name
                    break
                end
            end
        end
    end

    if self.editId ~= nil and self.editName ~= nil then
        self.edit = true
    end

    if self.edit then
        self.titleElement:setText(g_i18n:getText("gui_ad_enterTargetNameTitle_edit"))
        self.textInputElement:setText(self.editName)
    else
        self.titleElement:setText(g_i18n:getText("gui_ad_enterTargetNameTitle_add"))
        self.textInputElement:setText("")
    end

    self.buttonsCreateElement:setVisible(not self.edit)
    self.buttonsEditElement:setVisible(self.edit)
end

function ADEnterTargetNameGui:onClickCreateButton()
    ADEnterTargetNameGui:superClass().onClickOk(self)
    AutoDrive.createMapMarkerOnClosest(g_currentMission.controlledVehicle, self.textInputElement.text)
    self:onClickBack()
end

function ADEnterTargetNameGui:onClickRenameButton()
    ADEnterTargetNameGui:superClass().onClickOk(self)
    AutoDrive.renameMapMarker(self.textInputElement.text, self.editId)
    self:onClickBack()
end

function ADEnterTargetNameGui:onClickDeleteButton()
    AutoDrive.removeMapMarker(self.editId)
    self:onClickBack()
end

function ADEnterTargetNameGui:onClickResetButton()
    self.textInputElement:setText(self.editName)
end

function ADEnterTargetNameGui:onClickBack()
    ADEnterTargetNameGui:superClass().onClickBack(self)
end

function ADEnterTargetNameGui:onClose()
    ADEnterTargetNameGui:superClass().onClose(self)
end
