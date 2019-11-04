--
-- AutoDrive Enter Target Name GUI
-- V1.1.0.0
--
-- @author Stephan Schlosser
-- @date 08/08/2019

adEnterTargetNameGui = {}

local adEnterTargetNameGui_mt = Class(adEnterTargetNameGui, ScreenElement)

function adEnterTargetNameGui:new(target, custom_mt)
    local self = ScreenElement:new(target, adEnterTargetNameGui_mt)
    self.returnScreenName = ""
    self.textInputElement = nil
    self.createButtonElement = nil
    self.buttonsEditElement = nil
    self.buttonsCreateElement = nil
    self.titleElement = nil
    self.editName = nil
    self.editId = nil
    self.edit = false
    return self
end

function adEnterTargetNameGui:onCreateInputElement(element)
    self.textInputElement = element
    element.text = ""
end

function adEnterTargetNameGui:onCreateTitleElement(element)
    self.titleElement = element
end

function adEnterTargetNameGui:onCreateTextElement(element)
    element:setText(g_i18n:getText("gui_ad_enterTargetNameText"))
end

function adEnterTargetNameGui:onCreateCreateButton(element)
    self.createButtonElement = element
    element:setText(g_i18n:getText("gui_ad_createButtonText"))
end

function adEnterTargetNameGui:onCreateButtonsCreate(element)
    self.buttonsCreateElement = element
end

function adEnterTargetNameGui:onCreateButtonsEdit(element)
    self.buttonsEditElement = element
end

function adEnterTargetNameGui:onOpen()
    adEnterTargetNameGui:superClass().onOpen(self)
    self.editName = nil
    self.editId = nil
    self.edit = false
    FocusManager:setFocus(self.textInputElement)
    self.textInputElement.blockTime = 0
    self.textInputElement:onFocusActivate()

    -- If renameCurrentMapMarker is true, we have to rename the map marker selected on the pull down list otherwise we can go for closest waypoint
    if AutoDrive.renameCurrentMapMarker ~= nil and AutoDrive.renameCurrentMapMarker == true then
        self.editId = g_currentMission.controlledVehicle.ad.mapMarkerSelected
        self.editName = AutoDrive.mapMarker[self.editId].name
    else
        local closest = AutoDrive:findClosestWayPoint(g_currentMission.controlledVehicle)
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

function adEnterTargetNameGui:onClickCreateButton()
    adEnterTargetNameGui:superClass().onClickOk(self)
    AutoDrive.createMapMarkerOnClosest(g_currentMission.controlledVehicle, self.textInputElement.text)
    self:onClickBack()
end

function adEnterTargetNameGui:onClickRenameButton()
    adEnterTargetNameGui:superClass().onClickOk(self)
    AutoDrive.renameMapMarker(self.textInputElement.text, self.editName, self.editId)
    self:onClickBack()
end

function adEnterTargetNameGui:onClickDeleteButton()
    AutoDrive.removeMapMarker(self.editId)
    self:onClickBack()
end

function adEnterTargetNameGui:onClickResetButton()
    self.textInputElement:setText(self.editName)
end

function adEnterTargetNameGui:onClickBack()
    adEnterTargetNameGui:superClass().onClickBack(self)
end

function adEnterTargetNameGui:onClose()
    adEnterTargetNameGui:superClass().onClose(self)
end
