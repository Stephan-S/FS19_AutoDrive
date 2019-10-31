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
    self.renameButtonElement = nil
    --self.deleteButtonElement = nil
    self.titleElement = nil
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

function adEnterTargetNameGui:onCreateRenameButton(element)
    self.renameButtonElement = element
end

--function adEnterTargetNameGui:onCreateDeleteButton(element)
--    self.deleteButtonElement = element
--end

function adEnterTargetNameGui:onOpen()
    adEnterTargetNameGui:superClass().onOpen(self)
    FocusManager:setFocus(self.textInputElement)
    self.textInputElement:onFocusActivate()

    if g_currentMission.controlledVehicle ~= nil and g_currentMission.controlledVehicle.ad ~= nil then
        if AutoDrive.renameCurrentMapMarker ~= nil and AutoDrive.renameCurrentMapMarker == true then
            self.edit = true
        else
            self.edit = false
        end
    end
    if self.edit then
        self.titleElement:setText(g_i18n:getText("gui_ad_enterTargetNameTitle_edit"))
        self.textInputElement:setText(AutoDrive.mapMarker[g_currentMission.controlledVehicle.ad.mapMarkerSelected].name)
    else
        self.titleElement:setText(g_i18n:getText("gui_ad_enterTargetNameTitle_add"))
        self.textInputElement:setText("")
    end
    self.createButtonElement:setDisabled(self.edit)
    self.renameButtonElement:setDisabled(not self.edit)
    --self.deleteButtonElement:setDisabled(not self.edit or true)
end

function adEnterTargetNameGui:onClickCreateButton()
    adEnterTargetNameGui:superClass().onClickOk(self)
    local enteredName = self.textInputElement.text

    if enteredName:len() > 1 then
        if g_currentMission.controlledVehicle ~= nil and g_currentMission.controlledVehicle.ad ~= nil then
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

            AutoDrive:notifyDestinationListeners()
            AutoDrive.Hud.lastUIScale = 0
        end
    end

    self:onClickBack()
end

function adEnterTargetNameGui:onClickRenameButton()
    adEnterTargetNameGui:superClass().onClickOk(self)
    local enteredName = self.textInputElement.text

    if enteredName:len() > 1 then
        if g_currentMission.controlledVehicle ~= nil and g_currentMission.controlledVehicle.ad ~= nil then
            AutoDrive.mapMarker[g_currentMission.controlledVehicle.ad.mapMarkerSelected].name = enteredName
            for _, mapPoint in pairs(AutoDrive.mapWayPoints) do
                mapPoint.marker[enteredName] = mapPoint.marker[g_currentMission.controlledVehicle.ad.nameOfSelectedTarget]
            end
            g_currentMission.controlledVehicle.ad.nameOfSelectedTarget = enteredName

            AutoDrive:notifyDestinationListeners()
            AutoDrive.Hud.lastUIScale = 0
        end
    end

    self:onClickBack()
end

--function adEnterTargetNameGui:onClickDeleteButton()
--end

function adEnterTargetNameGui:onClickBack()
    adEnterTargetNameGui:superClass().onClickBack(self)
end

function adEnterTargetNameGui:onClose()
    adEnterTargetNameGui:superClass().onClose(self)
end
