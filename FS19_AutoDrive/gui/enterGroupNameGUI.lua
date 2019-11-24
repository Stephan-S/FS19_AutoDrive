--
-- AutoDrive Enter Group Name GUI
-- V1.1.0.0
--
-- @author Stephan Schlosser
-- @date 09/06/2019

ADEnterGroupNameGui = {}

local ADEnterGroupNameGui_mt = Class(ADEnterGroupNameGui, ScreenElement)

function ADEnterGroupNameGui:new(target)
    local o = ScreenElement:new(target, ADEnterGroupNameGui_mt)
    o.returnScreenName = ""
    o.textInputElement = nil
    return o
end

function ADEnterGroupNameGui:onCreateTitleElement(element)
    element:setText(g_i18n:getText("gui_ad_enterGroupNameTitle"))
end

function ADEnterGroupNameGui:onCreateTextElement(element)
    element:setText(g_i18n:getText("gui_ad_enterGroupNameText"))
end

function ADEnterGroupNameGui:onCreateInputElement(element)
    self.textInputElement = element
    element.text = ""
end

function ADEnterGroupNameGui:onOpen()
    ADEnterGroupNameGui:superClass().onOpen(self)
    FocusManager:setFocus(self.textInputElement)
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

function ADEnterGroupNameGui:onClose()
    ADEnterGroupNameGui:superClass().onClose(self)
end
