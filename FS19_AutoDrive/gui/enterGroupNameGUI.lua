--
-- AutoDrive Enter Group Name GUI
-- V1.1.0.0
--
-- @author Stephan Schlosser
-- @date 09/06/2019

ADEnterGroupNameGui = {}
ADEnterGroupNameGui.CONTROLS = {"textInputElement"}

local ADEnterGroupNameGui_mt = Class(ADEnterGroupNameGui, ScreenElement)

function ADEnterGroupNameGui:new(target)
    local o = ScreenElement:new(target, ADEnterGroupNameGui_mt)
    o.returnScreenName = ""
    o.textInputElement = nil
    o:registerControls(ADEnterGroupNameGui.CONTROLS)
    return o
end

function ADEnterGroupNameGui:onOpen()
    ADEnterGroupNameGui:superClass().onOpen(self)
    self.textInputElement.blockTime = 0
    self.textInputElement:onFocusActivate()
    self.textInputElement:setText("")
end

function ADEnterGroupNameGui:onClickOk()
    ADEnterGroupNameGui:superClass().onClickOk(self)
    AutoDrive.addGroup(self.textInputElement.text)
    self:onClickBack()
end

function ADEnterGroupNameGui:onClickBack()
    ADEnterGroupNameGui:superClass().onClickBack(self)
end
