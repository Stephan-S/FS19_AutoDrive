ADHudSpeedmeter = ADInheritsFrom(ADGenericHudElement)

function ADHudSpeedmeter:new(posX, posY, width, height)
    local o = ADHudSpeedmeter:create()
    o:init(posX, posY, width, height)
    o.primaryAction = "input_increaseSpeed"
    o.secondaryAction = "input_decreaseSpeed"

    o.layer = 5

    o.image = AutoDrive.directory .. "textures/speedmeter.dds"

    o.ov = Overlay:new(o.image, o.position.x, o.position.y, o.size.width, o.size.height)

    return o
end

function ADHudSpeedmeter:onDraw(vehicle, uiScale)
    self.ov:render()

    if AutoDrive.pullDownListExpanded == 0 or AutoDrive.Hud.targetPullDownList.direction == ADPullDownList.EXPANDED_UP then
        local adFontSize = AutoDrive.FONT_SCALE * uiScale
        setTextColor(1, 1, 1, 1)
        setTextAlignment(RenderText.ALIGN_CENTER)
        local text = string.format("%1d", g_i18n:getSpeed(vehicle.ad.stateModule:getSpeedLimit()))
        local posX = self.position.x + (self.size.width / 2)
        local posY = self.position.y + AutoDrive.Hud.gapHeight
        renderText(posX, posY, adFontSize, text)
    end
end

function ADHudSpeedmeter:act(vehicle, posX, posY, isDown, isUp, button)
    if button == 1 and isUp then
        AutoDrive:InputHandling(vehicle, self.primaryAction)
        return true
    elseif (button == 3 or button == 2) and isUp then
        AutoDrive:InputHandling(vehicle, self.secondaryAction)
        return true
    elseif button == 4 and isUp then
        AutoDrive:InputHandling(vehicle, self.primaryAction)
        AutoDrive.mouseWheelActive = true
        return true
    elseif button == 5 and isUp then
        AutoDrive:InputHandling(vehicle, self.secondaryAction)
        AutoDrive.mouseWheelActive = true
        return true
    elseif button == 4 and isUp then
        AutoDrive.mouseWheelActive = true
    elseif button == 5 and isUp then
        AutoDrive.mouseWheelActive = true
    end
    return false
end
