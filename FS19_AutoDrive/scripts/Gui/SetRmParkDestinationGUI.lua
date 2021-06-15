--
-- AutoDrive Enter Driver Name GUI
-- V1.1.0.0
--
-- @author Stephan Schlosser
-- @date 09/06/2019

ADSetRmParkDestinationGui = {}
ADSetRmParkDestinationGui.CONTROLS = {"SelectedWorktoolText", "CurrentParkDestinationText", "Button_ok", "Button_cancel"}
selectedWorkTool = nil
vehicle = nil
firstMarkerID = nil

local ADSetRmParkDestinationGui_mt = Class(ADSetRmParkDestinationGui, ScreenElement)

function ADSetRmParkDestinationGui:new(target)
	local o = ScreenElement:new(target, ADSetRmParkDestinationGui_mt)
	o.returnScreenName = ""
	o.textInputElement = nil
	o:registerControls(ADSetRmParkDestinationGui.CONTROLS)
	return o
end

function ADSetRmParkDestinationGui:onOpen()
	ADSetRmParkDestinationGui:superClass().onOpen(self)
	self.CurrentParkDestinationText.blockTime = 0
	self.CurrentParkDestinationText:onFocusActivate()
	self.SelectedWorktoolText.blockTime = 0
	self.SelectedWorktoolText:onFocusActivate()
	local actualParkDestination = -1

	vehicle = g_currentMission.controlledVehicle

	if vehicle ~= nil and vehicle.ad ~= nil and vehicle.ad.stateModule ~= nil and vehicle.ad.stateModule:getFirstMarker() ~= nil then
		firstMarkerID = vehicle.ad.stateModule:getFirstMarkerId()
		if firstMarkerID > 0 then
			local mapMarker = ADGraphManager:getMapMarkerById(firstMarkerID)
			-- do not allow to set debug marker as park destination
			if mapMarker ~= nil and mapMarker.isADDebug ~= true then
				self.Button_ok:setText(g_i18n:getText("button_set") .. " " .. mapMarker.name)
				selectedWorkTool = AutoDrive.getSelectedWorkTool(vehicle)

				if selectedWorkTool == nil then
					-- no attachment selected, so use the vehicle itself
					selectedWorkTool = vehicle
				end

				if selectedWorkTool ~= nil then
					self.Button_ok:setDisabled(false)
					self.SelectedWorktoolText:setText(selectedWorkTool:getFullName())
					if selectedWorkTool.advd.parkDestination ~= -1 then
						self.CurrentParkDestinationText:setText(g_i18n:getText("gui_ad_currentParkDestinationText") .. ADGraphManager:getMapMarkerById(selectedWorkTool.advd.parkDestination).name)
						self.Button_cancel:setDisabled(false)
					else
						self.CurrentParkDestinationText:setText(g_i18n:getText("gui_ad_noCurrentParkDestinationText"))
						self.Button_cancel:setDisabled(true)
					end
				end
			else
				self.SelectedWorktoolText:setText(g_i18n:getText("gui_ad_targetEmpty"))
				self.CurrentParkDestinationText:setText("")
				self.Button_ok:setDisabled(true)
				self.Button_cancel:setDisabled(true)
			end
		else
			self.SelectedWorktoolText:setText(g_i18n:getText("gui_ad_targetEmpty"))
			self.CurrentParkDestinationText:setText("")
			self.Button_ok:setDisabled(true)
			self.Button_cancel:setDisabled(true)
		end
	else
		self.SelectedWorktoolText:setText(g_i18n:getText("gui_ad_targetEmpty"))
		self.CurrentParkDestinationText:setText("")
		self.Button_ok:setDisabled(true)
		self.Button_cancel:setDisabled(true)
	end
end

-- set destination
function ADSetRmParkDestinationGui:onClickOk()
	ADSetRmParkDestinationGui:superClass().onClickOk(self)
	if g_currentMission.controlledVehicle ~= nil then
		if vehicle.advd ~= nil then
			vehicle.advd:setParkDestination(selectedWorkTool, firstMarkerID)
		end
	end
	self:onClickBack()
end

--  rm destination
function ADSetRmParkDestinationGui:onClickCancel()
	if g_currentMission.controlledVehicle ~= nil and g_currentMission.controlledVehicle.ad ~= nil then
		if vehicle.advd ~= nil then
			vehicle.advd:setParkDestination(selectedWorkTool, -1)
		end
	end
	self:onClickBack()
end

function ADSetRmParkDestinationGui:onClickBack()
	ADSetRmParkDestinationGui:superClass().onClickBack(self)
end

function ADSetRmParkDestinationGui:onEnterPressed(_, isClick)
	if not isClick then
		self:onClickOk()
	end
end

function ADSetRmParkDestinationGui:onEscPressed()
	self:onClickBack()
end
