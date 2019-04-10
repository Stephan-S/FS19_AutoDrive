--
-- AutoDrive GUI
-- V1.0.0.0
--
-- @author Stephan Schlosser
-- @date 08/04/2019

AutoDrive.pipeOffsetValues = { 0, 0.25, 0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0, 2.25, 2.5, 2.75, 3.0, 3.25, 3.5, 3.75, 4.0, 4.25, 4.5, 4.75, 5.0 };
AutoDrive.pipeOffsetTexts = { "0 m", "0.25 m", "0.5 m", "0.75 m", "1.0 m", "1.25 m", "1.5 m", "1.75 m", "2.0 m", "2.25 m", "2.5 m", "2.75 m", "3.0 m", "3.25 m", "3.5 m", "3.75 m", "4.0 m", "4.25 m", "4.5 m", "4.75 m", "5.0 m"};
AutoDrive.pipeOffsetDefault = 4; --0.75m
AutoDrive.pipeOffsetCurrent = 4;
AutoDrive.PATHFINDER_PIPE_OFFSET = AutoDrive.pipeOffsetValues[AutoDrive.pipeOffsetDefault];

AutoDrive.lookAheadTurnValues = { 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15 };
AutoDrive.lookAheadTurnTexts = { "2 m", "3 m", "4 m", "5 m", "6 m", "7 m", "8 m", "9 m", "10 m", "11 m", "12 m", "13 m", "14 m", "15 m"};
AutoDrive.lookAheadTurnDefault = 4; --5m
AutoDrive.lookAheadTurnCurrent = 4;
AutoDrive.LOOKAHEAD_DISTANCE_TURNING = AutoDrive.lookAheadTurnValues[AutoDrive.lookAheadTurnDefault];

AutoDrive.lookAheadBrakingValues = { 5, 7.5, 10, 12.5, 15, 17.5, 20, 25, 30, 35, 40 };
AutoDrive.lookAheadBrakingTexts = { "5m", "7.5m", "10m", "12.5m", "15m", "17.5m", "20m", "25m", "30m", "35m", "40m"};
AutoDrive.lookAheadBrakingDefault = 5; --15m
AutoDrive.lookAheadBrakingCurrent = 5;
AutoDrive.LOOKAHEAD_DISTANCE_BRAKING = AutoDrive.lookAheadBrakingValues[AutoDrive.lookAheadBrakingDefault];

AutoDrive.avoidMarkersValues = { false, true };
AutoDrive.avoidMarkersTexts = { "No", "Yes"};
AutoDrive.avoidMarkersDefault = 0; --No
AutoDrive.avoidMarkersCurrent = 0;
AutoDrive.avoidMarkers = AutoDrive.avoidMarkersValues[AutoDrive.avoidMarkersDefault];

AutoDrive.MAP_MARKER_DETOUR_Values = { 0, 10, 50, 100, 200, 300, 500, 1000, 10000};
AutoDrive.MAP_MARKER_DETOUR_Texts = { "0m", "10m", "50m", "100m", "200m", "500m", "1000m", "10000m"};
AutoDrive.MAP_MARKER_DETOUR_Default = 0; --15m
AutoDrive.MAP_MARKER_DETOUR_Current = 0;
AutoDrive.MAP_MARKER_DETOUR = AutoDrive.MAP_MARKER_DETOUR_Values[AutoDrive.MAP_MARKER_DETOUR_Default];

adSettingsGui = {};

local adSettingsGui_mt = Class(adSettingsGui, ScreenElement);

function adSettingsGui:new(target, custom_mt)
    local self = ScreenElement:new(target, adSettingsGui_mt);
    self.returnScreenName = "";
    return self;	
end;

function adSettingsGui:onOpen()
    adSettingsGui:superClass().onOpen(self);
	FocusManager:setFocus(self.backButton);
	AutoDrive.gui.adSettingsGui:setPipeOffset(AutoDrive.pipeOffsetCurrent);
	AutoDrive.gui.adSettingsGui:setLookAheadTurn(AutoDrive.lookAheadTurnCurrent);
	AutoDrive.gui.adSettingsGui:setLookAheadBraking(AutoDrive.lookAheadBrakingCurrent);
    AutoDrive.gui.adSettingsGui:setAvoidMarkers(AutoDrive.avoidMarkersCurrent)
    AutoDrive.gui.adSettingsGui:setMapMarkerDetour(AutoDrive.MAP_MARKER_DETOUR_Current)
end;

function adSettingsGui:onClose()
    adSettingsGui:superClass().onClose(self);
end;

function adSettingsGui:onClickBack()
    adSettingsGui:superClass().onClickBack(self);
	AutoDrive:guiClosed();
end;

function adSettingsGui:onClickOk()
    adSettingsGui:superClass().onClickOk(self);
    AutoDrive.PATHFINDER_PIPE_OFFSET = AutoDrive.pipeOffsetValues[self.pipeOffset:getState()];
    AutoDrive.pipeOffsetCurrent = self.pipeOffset:getState();
    AutoDrive.LOOKAHEAD_DISTANCE_TURNING = AutoDrive.lookAheadTurnValues[self.lookAheadTurn:getState()];
    AutoDrive.lookAheadTurnCurrent = self.lookAheadTurn:getState();
    AutoDrive.LOOKAHEAD_DISTANCE_BRAKING = AutoDrive.lookAheadBrakingValues[self.lookAheadBraking:getState()];
    AutoDrive.lookAheadBrakingCurrent = self.lookAheadBraking:getState();
    AutoDrive.avoidMarkers = AutoDrive.avoidMarkersValues[self.avoidMarkers:getState()];
    AutoDrive.avoidMarkersCurrent = self.avoidMarkers:getState();
    AutoDrive.MAP_MARKER_DETOUR = AutoDrive.MAP_MARKER_DETOUR_Values[self.mapMarkerDetour:getState()];
    AutoDrive.MAP_MARKER_DETOUR_Current = self.mapMarkerDetour:getState();
    AutoDriveUpdateSettingsEvent:sendEvent();
    self:onClickBack();
end;

function adSettingsGui:onClickResetButton()
    adSettingsGui:setPipeOffset(AutoDrive.pipeOffsetDefault)
    adSettingsGui:setLookAheadTurn(AutoDrive.lookAheadTurnDefault)
    adSettingsGui:setLookAheadBraking(AutoDrive.lookAheadBrakingDefault)
    adSettingsGui:setAvoidMarkers(AutoDrive.avoidMarkersDefault)
    adSettingsGui:setMapMarkerDetour(AutoDrive.MAP_MARKER_DETOUR_Default)
end;

function AutoDrive:guiClosed()
	AutoDrive.gui.adSettingsGui:setPipeOffset(AutoDrive.pipeOffsetCurrent);
	AutoDrive.gui.adSettingsGui:setLookAheadTurn(AutoDrive.lookAheadTurnCurrent);
	AutoDrive.gui.adSettingsGui:setLookAheadBraking(AutoDrive.lookAheadBrakingCurrent);
    AutoDrive.gui.adSettingsGui:setAvoidMarkers(AutoDrive.avoidMarkersCurrent)
    AutoDrive.gui.adSettingsGui:setMapMarkerDetour(AutoDrive.MAP_MARKER_DETOUR_Current)
end;

function adSettingsGui:onIngameMenuHelpTextChanged(element)
end;

function adSettingsGui:onCreateadSettingsGuiHeader(element)
	element.text = g_i18n:getText('gui_ad_Setting');
end;

function adSettingsGui:onCreatePipeOffset(element)
    self.pipeOffset = element;
	element.labelElement.text = g_i18n:getText('gui_ad_pipe_offset');
	element.toolTipText = g_i18n:getText('gui_ad_pipe_offset');
    local pipeOffsets = {};

    for i = 1, #AutoDrive.pipeOffsetTexts, 1 do
        pipeOffsets[i] = AutoDrive.pipeOffsetTexts[i];
    end;
	
    element:setTexts(pipeOffsets);
end;

function adSettingsGui:setPipeOffset(index)
    self.pipeOffset:setState(index, false);
end;

function adSettingsGui:onCreateLookAheadTurn(element)
    self.lookAheadTurn = element;
	element.labelElement.text = g_i18n:getText('gui_ad_lookahead_turning');
	element.toolTipText = g_i18n:getText('gui_ad_lookahead_turning_tooltip');
    local lookAheadTurns = {};

    for i = 1, #AutoDrive.lookAheadTurnTexts, 1 do
        lookAheadTurns[i] = AutoDrive.lookAheadTurnTexts[i];
    end;
	
    element:setTexts(lookAheadTurns);
end;

function adSettingsGui:setLookAheadTurn(index)
    self.lookAheadTurn:setState(index, false);
end;

function adSettingsGui:onCreateLookAheadBraking(element)
    self.lookAheadBraking = element;
	element.labelElement.text = g_i18n:getText('gui_ad_lookahead_braking');
	element.toolTipText = g_i18n:getText('gui_ad_lookahead_braking_tooltip');
    local lookAheadBrakings = {};

    for i = 1, #AutoDrive.lookAheadBrakingTexts, 1 do
        lookAheadBrakings[i] = AutoDrive.lookAheadBrakingTexts[i];
    end;
	
    element:setTexts(lookAheadBrakings);
end;

function adSettingsGui:setLookAheadBraking(index)
    self.lookAheadBraking:setState(index, false);
end;

function adSettingsGui:onCreateAvoidMarkers(element)
    self.avoidMarkers = element;
	element.labelElement.text = g_i18n:getText('gui_ad_avoidMarkers');
	element.toolTipText = g_i18n:getText('gui_ad_avoidMarkers_tooltip');
    local avoidMarkerArray = {};

    for i = 1, #AutoDrive.avoidMarkersTexts, 1 do
        avoidMarkerArray[i] = AutoDrive.avoidMarkersTexts[i];
    end;
	
    element:setTexts(avoidMarkerArray);
end;

function adSettingsGui:setAvoidMarkers(index)
    self.avoidMarkers:setState(index, false);
end;

function adSettingsGui:onCreateMapMarkerDetour(element)
    self.mapMarkerDetour = element;
	element.labelElement.text = g_i18n:getText('gui_ad_mapMarkerDetour');
	element.toolTipText = g_i18n:getText('gui_ad_mapMarkerDetour_tooltip');
    local mapMarkerDetours = {};

    for i = 1, #AutoDrive.MAP_MARKER_DETOUR_Texts, 1 do
        mapMarkerDetours[i] = AutoDrive.MAP_MARKER_DETOUR_Texts[i];
    end;
	
    element:setTexts(mapMarkerDetours);
end;

function adSettingsGui:setMapMarkerDetour(index)
    self.mapMarkerDetour:setState(index, false);
end;