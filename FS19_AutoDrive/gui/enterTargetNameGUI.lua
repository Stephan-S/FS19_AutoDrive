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

    local closest = AutoDrive:findClosestWayPoint(g_currentMission.controlledVehicle)
    if closest ~= nil and closest ~= -1 and AutoDrive.mapWayPoints[closest] ~= nil then
        local cId = AutoDrive.mapWayPoints[closest].id
        for i, mapMarker in pairs(AutoDrive.mapMarker) do
            if mapMarker.id == cId then
                self.editId = i
                self.editName = mapMarker.name
                break
            end
        end
    end

    if AutoDrive.renameCurrentMapMarker ~= nil and AutoDrive.renameCurrentMapMarker == true then
        self.editId = g_currentMission.controlledVehicle.ad.mapMarkerSelected
        self.editName = AutoDrive.mapMarker[self.editId].name
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
    local enteredName = self.textInputElement.text

    if enteredName:len() > 1 then
        local closest = AutoDrive:findClosestWayPoint(g_currentMission.controlledVehicle)
        if closest ~= nil and closest ~= -1 and AutoDrive.mapWayPoints[closest] ~= nil then
            AutoDrive.mapMarkerCounter = AutoDrive.mapMarkerCounter + 1
            local node = createTransformGroup(enteredName)
            setTranslation(node, AutoDrive.mapWayPoints[closest].x, AutoDrive.mapWayPoints[closest].y + 4, AutoDrive.mapWayPoints[closest].z)

            AutoDrive.mapMarker[AutoDrive.mapMarkerCounter] = {id = closest, name = enteredName, node = node, group = "All"}
            AutoDrive:MarkChanged()

            if g_server ~= nil then
                AutoDrive:broadCastUpdateToClients()
            else
                AutoDriveCreateMapMarkerEvent:sendEvent(g_currentMission.controlledVehicle, closest, enteredName)
            end
        end
        AutoDrive.Hud.lastUIScale = 0
    end

    self:onClickBack()
end

function adEnterTargetNameGui:onClickRenameButton()
    adEnterTargetNameGui:superClass().onClickOk(self)
    local enteredName = self.textInputElement.text

    if enteredName:len() > 1 then
        AutoDrive.mapMarker[self.editId].name = enteredName
        for _, mapPoint in pairs(AutoDrive.mapWayPoints) do
            mapPoint.marker[enteredName] = mapPoint.marker[self.editName]
        end
        g_currentMission.controlledVehicle.ad.nameOfSelectedTarget = enteredName
        AutoDrive.Hud.lastUIScale = 0
    end

    self:onClickBack()
end

function adEnterTargetNameGui:onClickDeleteButton()
    AutoDrive:removeMapMarker(AutoDrive.mapMarker[self.editId])
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
