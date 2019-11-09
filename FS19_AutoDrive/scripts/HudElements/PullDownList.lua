ADPullDownList = ADInheritsFrom(ADGenericHudElement)

ADPullDownList.STATE_COLLAPSED = 0
ADPullDownList.STATE_EXPANDED = 1

ADPullDownList.TYPE_TARGET = 1
ADPullDownList.TYPE_UNLOAD = 2
ADPullDownList.TYPE_FILLTYPE = 3

ADPullDownList.EXPANDED_DOWN = -1
ADPullDownList.EXPANDED_UP = 1

ADPullDownList.MAX_SHOWN = 25

function ADPullDownList:new(posX, posY, width, height, type, selected)
    local self = ADPullDownList:create()
    self:init(posX, posY, width, height)
    self.selected = selected
    self.type = type
    self.size.height = AutoDrive.Hud.buttonHeight

    AutoDrive.pullDownListExpanded = 0

    self.rightIconPos = {x = self.position.x + self.size.width - AutoDrive.Hud.buttonWidth / 2 - AutoDrive.Hud.gapWidth, y = self.position.y + (self.size.height - AutoDrive.Hud.buttonHeight / 2) / 2}
    self.rightIconPos2 = {x = self.position.x + self.size.width - (AutoDrive.Hud.buttonWidth / 2) * 2 - AutoDrive.Hud.gapWidth * 3, y = self.position.y + (self.size.height - AutoDrive.Hud.buttonHeight / 2) / 2}
    self.rightIconPos3 = {x = self.position.x + self.size.width - (AutoDrive.Hud.buttonWidth / 2) * 3 - AutoDrive.Hud.gapWidth * 5, y = self.position.y + (self.size.height - AutoDrive.Hud.buttonHeight / 2) / 2}

    self.iconSize = {width = AutoDrive.Hud.buttonWidth / 2, height = AutoDrive.Hud.buttonHeight / 2}
    self.rowSize = {width = AutoDrive.Hud.buttonWidth / 2, height = AutoDrive.Hud.listItemHeight / 2}

    self.layer = 6

    self.imageBG = AutoDrive.directory .. "textures/4xlongBorderFilled.dds"
    self.imageBGTop = AutoDrive.directory .. "textures/4xlongBorderTopFilled.dds"
    self.imageBGBottom = AutoDrive.directory .. "textures/4xlongBorderBottomFilled.dds"
    self.imageBGStretch = AutoDrive.directory .. "textures/4xlongBorderStretchFilled.dds"
    self.imageExpand = AutoDrive.directory .. "textures/arrowExpand.dds"
    self.imageCollapse = AutoDrive.directory .. "textures/arrowCollapse.dds"
    self.imageUp = AutoDrive.directory .. "textures/arrowUp.dds"
    self.imageDown = AutoDrive.directory .. "textures/arrowDown.dds"
    self.imagePlus = AutoDrive.directory .. "textures/plusSign.dds"
    self.imageMinus = AutoDrive.directory .. "textures/minusSign.dds"
    self.imageRight = AutoDrive.directory .. "textures/arrowRight.dds"

    self.ovBG = Overlay:new(self.imageBG, self.position.x, self.position.y, self.size.width, self.size.height)
    self.ovExpand = Overlay:new(self.imageExpand, self.rightIconPos.x, self.rightIconPos.y, self.iconSize.width, self.iconSize.height)

    self.state = ADPullDownList.STATE_COLLAPSED
    self.isVisible = true

    self:createSelection()

    self.expandedSize = {width = self.size.width, height = self.rowSize.height * ADPullDownList.MAX_SHOWN + self.size.height / 2}
    if self.position.y >= 0.5 then
        self.direction = ADPullDownList.EXPANDED_DOWN
    else
        self.direction = ADPullDownList.EXPANDED_UP
    end

    return self
end

function ADPullDownList:onDraw(vehicle)
    if not (self.type ~= ADPullDownList.TYPE_FILLTYPE or vehicle.ad.mode == AutoDrive.MODE_LOAD or vehicle.ad.mode == AutoDrive.MODE_PICKUPANDDELIVER) then
        return
    end
    self:updateState(vehicle)
    if self.isVisible == false then
        return
    end
    local uiScale = g_gameSettings:getValue("uiScale")
    if AutoDrive.getSetting("guiScale") ~= 0 then
        uiScale = AutoDrive.getSetting("guiScale")
    end
    local adFontSize = AutoDrive.FONT_SCALE * uiScale
    setTextColor(1, 1, 1, 1)
    setTextBold(false)
    setTextAlignment(RenderText.ALIGN_LEFT)

    if self.state == ADPullDownList.STATE_COLLAPSED then
        self.ovBG:render()
        self.ovExpand:render()

        local text = self.text
        local textWidth = getTextWidth(adFontSize, text)
        while textWidth > (self.size.width - 3 * AutoDrive.Hud.gapWidth - self.iconSize.width) do
            text = string.sub(text, 1, string.len(text) - 1)
            textWidth = getTextWidth(adFontSize, text)
        end
        local textHeight = getTextHeight(adFontSize, text)

        local posX = self.position.x + AutoDrive.Hud.gapWidth
        local posY = self.position.y + (self.size.height - textHeight) / 2
        if vehicle.ad.isActive then
            local targetToCheck = "nil"
            if self.type == ADPullDownList.TYPE_TARGET then
                targetToCheck = vehicle.ad.nameOfSelectedTarget
            elseif self.type == ADPullDownList.TYPE_UNLOAD then
                targetToCheck = vehicle.ad.nameOfSelectedTarget_Unload
            end
            local actualTarget = ""

            for markerIndex, mapMarker in pairs(AutoDrive.mapMarker) do
                if vehicle.ad.wayPoints ~= nil and vehicle.ad.wayPoints[AutoDrive.tableLength(vehicle.ad.wayPoints)] ~= nil then
                    if mapMarker.id == vehicle.ad.wayPoints[AutoDrive.tableLength(vehicle.ad.wayPoints)].id then
                        actualTarget = mapMarker.name
                    end
                end
            end

            if actualTarget == targetToCheck then
                setTextColor(0, 1, 0, 1)
            end
        end

        if not (AutoDrive.pullDownListExpanded > self.type and self.direction == ADPullDownList.EXPANDED_UP) and not (AutoDrive.pullDownListExpanded < self.type and self.direction == ADPullDownList.EXPANDED_DOWN and (AutoDrive.pullDownListExpanded ~= 0)) then
            renderText(posX, posY, adFontSize, text)
        end
    else
        self.ovTop:render()
        self.ovStretch:render()
        self.ovBottom:render()
        --AutoDrive.pullDownListExpanded = self.type;

        for i = 1, ADPullDownList.MAX_SHOWN, 1 do
            local listEntry = self:getListElementByDisplayIndex(vehicle, i)
            if listEntry ~= nil then
                local text = listEntry.displayName
                if text == "All" and listEntry.isFolder then
                    text = g_i18n:getText("gui_ad_default")
                end
                if listEntry.isFolder == false and self.type ~= ADPullDownList.TYPE_FILLTYPE and AutoDrive.getSetting("useFolders") then
                    text = "   " .. text
                end
                local textTargetWidth = math.abs(self.rightIconPos2.x - self.position.x) - AutoDrive.Hud.gapWidth
                if self.type == ADPullDownList.TYPE_FILLTYPE then
                    textTargetWidth = math.abs(self.rightIconPos.x - self.position.x) + AutoDrive.Hud.gapWidth
                end
                if listEntry.isFolder then
                    textTargetWidth = math.abs(self.rightIconPos3.x - self.position.x) - AutoDrive.Hud.gapWidth
                else
                    textTargetWidth = math.abs(self.rightIconPos.x - self.position.x) + AutoDrive.Hud.gapWidth
                end
                text = self:shortenTextToWidth(text, textTargetWidth)

                local textPosition = self:getTextPositionByDisplayIndex(i)

                if listEntry.isFolder then
                    if vehicle.ad.groups[listEntry.displayName] then
                        listEntry.ovCollapse = Overlay:new(self.imageCollapse, self.rightIconPos.x, textPosition.y, self.iconSize.width, self.iconSize.height)
                        listEntry.ovCollapse:render()
                    else
                        listEntry.ovExpand = Overlay:new(self.imageExpand, self.rightIconPos.x, textPosition.y, self.iconSize.width, self.iconSize.height)
                        listEntry.ovExpand:render()
                    end

                    if vehicle.ad.createMapPoints == true then
                        listEntry.ovAddHere = Overlay:new(self.imageRight, self.rightIconPos2.x, textPosition.y, self.iconSize.width, self.iconSize.height)
                        listEntry.ovAddHere:render()

                        if (listEntry.displayName ~= "All") then
                            if self:getItemCountForGroup(listEntry.displayName) <= 0 then
                                listEntry.ovMinus = Overlay:new(self.imageMinus, self.rightIconPos3.x, textPosition.y, self.iconSize.width, self.iconSize.height)
                                listEntry.ovMinus:render()
                            end
                        else
                            listEntry.ovPlus = Overlay:new(self.imagePlus, self.rightIconPos3.x, textPosition.y, self.iconSize.width, self.iconSize.height)
                            listEntry.ovPlus:render()
                        end
                    end
                --else
                --if self.type ~= ADPullDownList.TYPE_FILLTYPE and AutoDrive.getSetting("useFolders") then
                --listEntry.ovUp = Overlay:new(self.imageUp, self.rightIconPos2.x, textPosition.y, self.iconSize.width, self.iconSize.height);
                --listEntry.ovUp:render();
                --listEntry.ovDown = Overlay:new(self.imageDown, self.rightIconPos.x, textPosition.y, self.iconSize.width, self.iconSize.height);
                --listEntry.ovDown:render();
                --end;
                end

                setTextBold(false)
                if self.hovered == self.selected + (i - 1) and listEntry.isFolder == false then
                    setTextColor(0, 1, 0, 1)
                else
                    if listEntry.isFolder == false then
                        setTextColor(1, 1, 1, 1)
                    else
                        setTextBold(true)
                        setTextColor(0.0, 0.569, 0.835, 1)
                    end
                end
                renderText(textPosition.x, textPosition.y, adFontSize, text)
            else
                if i == 1 then
                    i = i - 1
                    self.selected = 1
                    self.hovered = 1
                end
            end
        end
    end
end

function ADPullDownList:shortenTextToWidth(textInput, width)
    local text = textInput
    if textInput == nil then
        return ""
    end

    local uiScale = g_gameSettings:getValue("uiScale")
    if AutoDrive.getSetting("guiScale") ~= 0 then
        uiScale = AutoDrive.getSetting("guiScale")
    end
    local adFontSize = AutoDrive.FONT_SCALE * uiScale

    local textWidth = getTextWidth(adFontSize, text)
    while textWidth > width do
        text = string.sub(text, 1, string.len(text) - 1)
        textWidth = getTextWidth(adFontSize, text)
    end

    return text
end

function ADPullDownList:getListElementByDisplayIndex(vehicle, index)
    return self:getListElementByIndex(vehicle, (index - 1) + self.selected)
end

function ADPullDownList:getListElementByIndex(vehicle, index)
    local counter = 1
    if self.type ~= ADPullDownList.TYPE_FILLTYPE then
        for groupID, entries in pairs(self.options) do
            if AutoDrive.getSetting("useFolders") then
                if counter == index then
                    return {displayName = self:groupIDToGroupName(self.fakeGroupIDs[groupID]), returnValue = self:groupIDToGroupName(self.fakeGroupIDs[groupID]), isFolder = true}
                end
                counter = counter + 1
            end
            if vehicle.ad.groups[self:groupIDToGroupName(self.fakeGroupIDs[groupID])] == true or (not AutoDrive.getSetting("useFolders")) then
                for id, entry in pairs(entries) do
                    if counter == index then
                        return {displayName = entry.displayName, returnValue = entry.returnValue, isFolder = false}
                    end
                    counter = counter + 1
                end
            end
        end
    else
        local entry = self.options[1][index]
        if entry ~= nil then
            return {displayName = entry.displayName, returnValue = entry.returnValue, isFolder = false}
        end
    end
    return nil
end

function ADPullDownList:getBoxPositionByDisplayIndex(index)
    local posX = self.position.x + AutoDrive.Hud.gapWidth
    local posY = self.position.y + AutoDrive.Hud.listItemHeight * (index - 1) * -1
    if self.direction == ADPullDownList.EXPANDED_UP then
        posY = posY + self.expandedSize.height - self.size.height
    end
    return {x = posX, y = posY, width = self.expandedSize.width, height = self.size.height}
end

function ADPullDownList:getTextPositionByDisplayIndex(index)
    local boxPos = self:getBoxPositionByDisplayIndex(index)

    local uiScale = g_gameSettings:getValue("uiScale")
    if AutoDrive.getSetting("guiScale") ~= 0 then
        uiScale = AutoDrive.getSetting("guiScale")
    end
    local adFontSize = AutoDrive.FONT_SCALE * uiScale
    local textHeight = getTextHeight(adFontSize, "text")

    boxPos.y = boxPos.y + (self.size.height - textHeight) / 2
    return boxPos
end

function ADPullDownList:getElementAt(vehicle, posX, posY)
    for i = 1, ADPullDownList.MAX_SHOWN, 1 do
        local listEntry = self:getListElementByDisplayIndex(vehicle, i)
        if listEntry ~= nil then
            local boxPos = self:getTextPositionByDisplayIndex(i)

            if posX >= boxPos.x and posX <= (boxPos.x + boxPos.width) and posY >= boxPos.y and posY <= (boxPos.y + boxPos.height) then
                local hitIcon = 0
                if posX >= self.rightIconPos.x then
                    hitIcon = 1
                elseif posX >= self.rightIconPos2.x then
                    hitIcon = 2
                elseif posX >= self.rightIconPos3.x and listEntry.isFolder then
                    hitIcon = 3
                end

                return listEntry, i, hitIcon
            end
        end
    end
    return nil
end

function ADPullDownList:updateState(vehicle)
    local newState, newSelection = self:getNewState(vehicle)
    if newState ~= self.state or newSelection ~= self.selected then
        self.ov = Overlay:new(self.images[newState], self.position.x, self.position.y, self.size.width, self.size.height)
    end
    self.state = newState
    self.selected = newSelection
    self:updateVisibility(vehicle)
end

function ADPullDownList:updateVisibility(vehicle)
    local newVisibility = self.isVisible
    if self.type == ADPullDownList.TYPE_UNLOAD then
        if (vehicle.ad.mode == AutoDrive.MODE_PICKUPANDDELIVER or vehicle.ad.mode == AutoDrive.MODE_UNLOAD or vehicle.ad.mode == AutoDrive.MODE_LOAD) then
            newVisibility = true
        else
            newVisibility = false
        end
    end
    if self.type == ADPullDownList.TYPE_TARGET then
        if vehicle.ad.mode == AutoDrive.MODE_BGA then
            newVisibility = false
        else
            newVisibility = true
        end
    end

    self.isVisible = newVisibility
end

function ADPullDownList:createSelection()
    self.fakeGroupIDs = {}
    self.fakeGroupIDs[1] = 1
    if self.type == ADPullDownList.TYPE_TARGET then
        self:createSelection_Target()
    elseif self.type == ADPullDownList.TYPE_UNLOAD then
        self:createSelection_Target()
    elseif self.type == ADPullDownList.TYPE_FILLTYPE then
        self:createSelection_FillType()
    end

    self:sortCurrentItems()
end

function ADPullDownList:createSelection_Target()
    self.options = {}
    if AutoDrive.getSetting("useFolders") then
        self:sortGroups()
    else
        self.options[1] = {}
    end

    if #self.options == 0 then
        self.options[1] = {}
    end

    for markerID, marker in pairs(AutoDrive.mapMarker) do
        if AutoDrive.getSetting("useFolders") then
            table.insert(self.options[self.groups[marker.group]], {displayName = marker.name, returnValue = markerID})
        else
            table.insert(self.options[1], {displayName = marker.name, returnValue = markerID})
        end
    end
end

function ADPullDownList:sortGroups()
    self.options = {}

    local sort_func = function(a, b)
        a = tostring(a):lower()
        b = tostring(b):lower()
        local patt = "^(.-)%s*(%d+)$"
        local _, _, col1, num1 = a:find(patt)
        local _, _, col2, num2 = b:find(patt)
        if (col1 and col2) and col1 == col2 then
            return tonumber(num1) < tonumber(num2)
        end
        return a < b
    end

    local inverseTable = {}
    for groupName, groupID in pairs(AutoDrive.groups) do
        inverseTable[groupID] = groupName
    end

    table.sort(inverseTable, sort_func)

    self.options[1] = {}
    self.groups = {}
    self.groups["All"] = 1
    self.fakeGroupIDs = {}
    self.fakeGroupIDs[1] = 1

    local i = 2
    for groupID, groupName in pairs(inverseTable) do
        if groupName ~= "All" then
            self.options[i] = {}
            self.groups[groupName] = i
            self.fakeGroupIDs[i] = AutoDrive.groups[groupName]
            i = i + 1
        end
    end
end

function ADPullDownList:createSelection_FillType()
    self.options = {}
    self.options[1] = {}
    local fillTypeIndex = 1
    local itemListIndex = 1
    local lastIndexReached = false
    while not lastIndexReached do
        if g_fillTypeManager:getFillTypeByIndex(fillTypeIndex) ~= nil then
            if not AutoDriveHud:has_value(AutoDrive.ItemFilterList, fillTypeIndex) then
                self.options[1][itemListIndex] = {displayName = g_fillTypeManager:getFillTypeByIndex(fillTypeIndex).title, returnValue = fillTypeIndex}
                itemListIndex = itemListIndex + 1
            end
        else
            lastIndexReached = true
        end
        fillTypeIndex = fillTypeIndex + 1
    end
end

function ADPullDownList:getNewState(vehicle)
    local newState = self.state
    local newSelection = self.selected
    if self.type == ADPullDownList.TYPE_TARGET then
        self:getNewState_Target(vehicle)
    elseif self.type == ADPullDownList.TYPE_UNLOAD then
        self:getNewState_Unload(vehicle)
    elseif self.type == ADPullDownList.TYPE_FILLTYPE then
        self:getNewState_FillType(vehicle)
    end

    return newState, newSelection
end

function ADPullDownList:getNewState_Target(vehicle)
    local newState = self.state
    local newSelection = self.selected
    if self.state == ADPullDownList.STATE_COLLAPSED then
        local markerSelected = vehicle.ad.mapMarkerSelected
        if markerSelected ~= nil and markerSelected >= 1 and AutoDrive.mapMarker[markerSelected] ~= nil then
            self.text = AutoDrive.mapMarker[markerSelected].name
        else
            self.text = ""
        end
    end
    return newState, newSelection
end

function ADPullDownList:getNewState_Unload(vehicle)
    local newState = self.state
    local newSelection = self.selected
    if self.state == ADPullDownList.STATE_COLLAPSED then
        local markerSelected = vehicle.ad.mapMarkerSelected_Unload
        if markerSelected ~= nil and markerSelected >= 1 and AutoDrive.mapMarker[markerSelected] ~= nil then
            self.text = AutoDrive.mapMarker[markerSelected].name
        else
            self.text = ""
        end
    end
    return newState, newSelection
end

function ADPullDownList:getNewState_FillType(vehicle)
    local newState = self.state
    local newSelection = self.selected
    if self.state == ADPullDownList.STATE_COLLAPSED then
        self.text = g_fillTypeManager:getFillTypeByIndex(vehicle.ad.unloadFillTypeIndex).title
    end
    return newState, newSelection
end

function ADPullDownList:hit(posX, posY, layer)
    if self.state == ADPullDownList.STATE_EXPANDED then
        if self.direction == ADPullDownList.EXPANDED_DOWN then
            return layer <= self.layer and posX >= self.position.x and posX <= (self.position.x + self.expandedSize.width) and posY >= (self.position.y - self.expandedSize.height + self.size.height) and posY <= (self.position.y + self.size.height)
        else
            return layer <= self.layer and posX >= self.position.x and posX <= (self.position.x + self.expandedSize.width) and posY >= (self.position.y) and posY <= (self.position.y + self.expandedSize.height)
        end
    end
    return layer <= self.layer and posX >= self.position.x and posX <= (self.position.x + self.size.width) and posY >= self.position.y and posY <= (self.position.y + self.size.height)
end

function ADPullDownList:act(vehicle, posX, posY, isDown, isUp, button)
    if self.type ~= ADPullDownList.TYPE_FILLTYPE or vehicle.ad.mode == AutoDrive.MODE_LOAD or vehicle.ad.mode == AutoDrive.MODE_PICKUPANDDELIVER then
        local hitElement, hitIndex, hitIcon = self:getElementAt(vehicle, posX, posY)
        if button == 1 and isUp then
            if self.state == ADPullDownList.STATE_COLLAPSED and AutoDrive.pullDownListExpanded <= 0 then
                self:expand(vehicle)
            elseif self.state == ADPullDownList.STATE_EXPANDED then
                if hitIcon == nil or hitIcon == 0 then
                    self:collapse(vehicle, true)
                elseif hitIcon ~= nil and hitIcon == 1 then
                    if hitElement.isFolder then
                        vehicle.ad.groups[hitElement.returnValue] = not vehicle.ad.groups[hitElement.returnValue]
                    --else
                    --self:moveSelectedElementDown(vehicle, hitElement);
                    end
                elseif hitIcon ~= nil and hitIcon == 2 and vehicle.ad.createMapPoints == true then
                    if hitElement.isFolder then
                        self:moveCurrentElementToFolder(vehicle, hitElement)
                    --else
                    --self:moveSelectedElementUp(vehicle, hitElement);
                    end
                elseif hitIcon ~= nil and hitIcon == 3 and vehicle.ad.createMapPoints == true then
                    if hitElement.isFolder then
                        if (hitElement.displayName ~= "All") then
                            if self:getItemCountForGroup(hitElement.displayName) <= 0 then
                                AutoDrive.pullDownListExpanded = 0
                                AutoDrive.removeGroup(hitElement.returnValue)
                            end
                        else
                            self:collapse(vehicle, true)
                            AutoDrive:onOpenEnterGroupName()
                        end
                    end
                end
            end
            return true
        elseif button == 4 and isUp then
            local oldSelected = self.selected
            self.selected = math.max(1, self.selected - 1)
            if oldSelected ~= self.selected then
                self.hovered = math.max(1, self.hovered - 1)
            end
            if self.hovered > (self.selected + ADPullDownList.MAX_SHOWN - 1) then
                self.hovered = self.selected + ADPullDownList.MAX_SHOWN - 1
            end
            AutoDrive.mouseWheelActive = true
            return true
        elseif button == 5 and isUp then
            local oldSelected = self.selected
            if self:getListElementByIndex(vehicle, self.selected + 1) ~= nil then
                self.selected = self.selected + 1
                if self:getListElementByIndex(vehicle, self.hovered + 1) ~= nil then
                    self.hovered = self.hovered + 1
                end
            end
            AutoDrive.mouseWheelActive = true
            return true
        elseif isDown == false and isUp == false then
            if hitIndex ~= nil then
                self.hovered = self.selected + (hitIndex - 1)
            end
        end
    end
    return false
end

function ADPullDownList:expand(vehicle)
    if self.state == ADPullDownList.STATE_COLLAPSED then
        self.layer = self.layer + 1
    end
    self.state = ADPullDownList.STATE_EXPANDED

    AutoDrive.pullDownListExpanded = self.type

    --possibly adjust height to number of elements (visible)
    self.expandedSize.height = math.min(self:getItemCount(), ADPullDownList.MAX_SHOWN) * AutoDrive.Hud.listItemHeight + self.size.height / 2

    if self.direction == ADPullDownList.EXPANDED_UP then
        self.ovTop = Overlay:new(self.imageBGTop, self.position.x, self.position.y + self.expandedSize.height - self.size.height / 2, self.size.width, self.size.height / 2)
        self.ovStretch = Overlay:new(self.imageBGStretch, self.position.x, self.position.y + (self.size.height / 2), self.size.width, self.expandedSize.height - self.size.height)
        self.ovBottom = Overlay:new(self.imageBGBottom, self.position.x, self.position.y, self.size.width, self.size.height / 2)
    else
        self.ovTop = Overlay:new(self.imageBGTop, self.position.x, self.position.y + self.size.height / 2, self.size.width, self.size.height / 2)
        self.ovStretch = Overlay:new(self.imageBGStretch, self.position.x, self.position.y + (self.size.height / 2) * 3 - self.expandedSize.height, self.size.width, self.expandedSize.height - self.size.height)
        self.ovBottom = Overlay:new(self.imageBGBottom, self.position.x, self.position.y - self.expandedSize.height + self.size.height, self.size.width, self.size.height / 2)
    end

    self:setSelected(vehicle)
end

function ADPullDownList:collapse(vehicle, setItem)
    if self.state == ADPullDownList.STATE_EXPANDED then
        self.layer = self.layer - 1
    end
    self.state = ADPullDownList.STATE_COLLAPSED
    AutoDrive.pullDownListExpanded = 0

    if self.hovered ~= nil and setItem ~= nil and setItem == true then
        local selectedEntry = self:getListElementByIndex(vehicle, self.hovered)
        if selectedEntry ~= nil and selectedEntry.returnValue ~= nil and selectedEntry.isFolder == false then
            if self.type == ADPullDownList.TYPE_TARGET then
                if AutoDrive.mapMarker[selectedEntry.returnValue] ~= nil then
                    vehicle.ad.mapMarkerSelected = selectedEntry.returnValue
                    vehicle.ad.targetSelected = AutoDrive.mapMarker[vehicle.ad.mapMarkerSelected].id
                    vehicle.ad.nameOfSelectedTarget = AutoDrive.mapMarker[vehicle.ad.mapMarkerSelected].name
                end
            elseif self.type == ADPullDownList.TYPE_UNLOAD then
                if AutoDrive.mapMarker[selectedEntry.returnValue] ~= nil then
                    vehicle.ad.mapMarkerSelected_Unload = selectedEntry.returnValue
                    vehicle.ad.targetSelected_Unload = AutoDrive.mapMarker[vehicle.ad.mapMarkerSelected_Unload].id
                    vehicle.ad.nameOfSelectedTarget_Unload = AutoDrive.mapMarker[vehicle.ad.mapMarkerSelected_Unload].name
                end
            elseif self.type == ADPullDownList.TYPE_FILLTYPE then
                vehicle.ad.unloadFillTypeIndex = selectedEntry.returnValue
            end

            AutoDriveUpdateDestinationsEvent:sendEvent(vehicle)
        end
    end
    AutoDrive.Hud.lastUIScale = 0
end

function ADPullDownList:setSelected(vehicle)
    self.selected = 1
    self.hovered = 1
    if self.type == ADPullDownList.TYPE_TARGET then
        local index = 1
        for groupID, entries in pairs(self.options) do
            if AutoDrive.getSetting("useFolders") then
                index = index + 1
            end
            for _, entry in pairs(entries) do
                if entry.returnValue == vehicle.ad.mapMarkerSelected then
                    self.selected = index
                    self.hovered = self.selected
                    if not vehicle.ad.groups[self:groupIDToGroupName(self.fakeGroupIDs[groupID])] then
                        vehicle.ad.groups[self:groupIDToGroupName(self.fakeGroupIDs[groupID])] = true
                    end
                    break
                end
                index = index + 1
            end
            if self.selected ~= 1 then
                break
            end
        end
    elseif self.type == ADPullDownList.TYPE_UNLOAD then
        local index = 1
        for groupID, entries in pairs(self.options) do
            if AutoDrive.getSetting("useFolders") then
                index = index + 1
            end
            for _, entry in pairs(entries) do
                if entry.returnValue == vehicle.ad.mapMarkerSelected_Unload then
                    self.selected = index
                    self.hovered = self.selected
                    if not vehicle.ad.groups[self:groupIDToGroupName(self.fakeGroupIDs[groupID])] then
                        vehicle.ad.groups[self:groupIDToGroupName(self.fakeGroupIDs[groupID])] = true
                    end
                    break
                end
                index = index + 1
            end

            if self.selected ~= 1 then
                break
            end
        end
    elseif self.type == ADPullDownList.TYPE_FILLTYPE then
        local index = 1
        for groupID, entries in pairs(self.options) do
            --index = index + 1;
            for _, entry in pairs(entries) do
                if entry.returnValue == vehicle.ad.unloadFillTypeIndex then
                    self.selected = index
                    self.hovered = self.selected
                    break
                end
                index = index + 1
            end
            if self.selected ~= 1 then
                break
            end
        end
    end

    local reachedTop = false
    local numberOfElementsVisible = math.min(self:getItemCount(), ADPullDownList.MAX_SHOWN);
    while (not reachedTop) do
        if self:getListElementByIndex(vehicle, self.selected - 1) ~= nil and (self.hovered < (self.selected + numberOfElementsVisible - 1)) then
            self.selected = self.selected - 1
        else
            reachedTop = true
        end
    end
end

function ADPullDownList:groupIDToGroupName(id)
    for groupName, groupId in pairs(AutoDrive.groups) do
        if groupId == id then
            return groupName
        end
    end
    return nil
end

function ADPullDownList:sortCurrentItems()
    local sort_func = function(a, b)
        a = tostring(a.displayName):lower()
        b = tostring(b.displayName):lower()
        local patt = "^(.-)%s*(%d+)$"
        local _, _, col1, num1 = a:find(patt)
        local _, _, col2, num2 = b:find(patt)
        if (col1 and col2) and col1 == col2 then
            return tonumber(num1) < tonumber(num2)
        end
        return a < b
    end

    for id, list in pairs(self.options) do
        table.sort(self.options[id], sort_func)
    end
end

function ADPullDownList:getItemCount()
    local count = #self.options
    if AutoDrive.getSetting("useFolders") == false or self.type == ADPullDownList.TYPE_FILLTYPE then
        count = 0
    end
    for _, list in pairs(self.options) do
        count = count + #list
    end
    return count
end

function ADPullDownList:getItemCountForGroup(groupName)
    local groupID = self.groups[groupName]
    if groupID ~= nil and self.options[groupID] ~= nil then
        return #self.options[groupID]
    end
    return 0
end

function ADPullDownList:moveCurrentElementToFolder(vehicle, hitElement)
    local mapMarkerID = vehicle.ad.mapMarkerSelected
    local mapMarkerName = vehicle.ad.nameOfSelectedTarget
    local targetGroupName = hitElement.returnValue

    if self.type == ADPullDownList.TYPE_UNLOAD then        
        mapMarkerID = vehicle.ad.mapMarkerSelected_Unload;
        mapMarkerName = vehicle.ad.nameOfSelectedTarget_Unload;
    end;

    for groupID, entries in pairs(self.options) do
        for i, entry in pairs(entries) do
            if entry.returnValue == mapMarkerID then
                table.remove(entries, i)
            end
        end
    end

    table.insert(self.options[self.groups[targetGroupName]], {displayName = mapMarkerName, returnValue = mapMarkerID})

    AutoDrive.changeMapMarkerGroup(targetGroupName, mapMarkerID)

    self:sortCurrentItems()
end
