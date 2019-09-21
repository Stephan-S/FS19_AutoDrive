ADHudIcon = ADInheritsFrom( ADGenericHudElement )

function ADHudIcon:new(posX, posY, width, height, image, layer, name)
    local self = ADHudIcon:create();
    self:init(posX, posY, width, height);
    self.layer = layer;
    self.name = name;
    self.image = image;
    self.isVisible = true;
    
    self.ov = Overlay:new(self.image, self.position.x, self.position.y, self.size.width, self.size.height);
	
    return self;
end;

function ADHudIcon:onDraw(vehicle)
    self:updateVisibility(vehicle);

    self:updateIcon(vehicle);
    
    if self.isVisible then
        self.ov:render();
    end;
end;

function ADHudIcon:updateVisibility(vehicle)
    local newVisibility = self.isVisible;
    if self.name == "unloadOverlay" then
        if (vehicle.ad.mode == AutoDrive.MODE_PICKUPANDDELIVER 
            or vehicle.ad.mode == AutoDrive.MODE_UNLOAD
            or vehicle.ad.mode == AutoDrive.MODE_LOAD) then
                newVisibility = true;
        else
            newVisibility = false;
        end;
    end;

    self.isVisible = newVisibility;
end;

function ADHudIcon:act(vehicle, posX, posY, isDown, isUp, button)
    if self.name == "header" then
        if button == 1 and isDown then
            AutoDrive.Hud:startMovingHud(posX, posY);
            return true;
        end;
    end;
    return false;
end;

function ADHudIcon:updateIcon(vehicle)
    local newIcon = self.image;
    if self.name == "unloadOverlay" then
        if vehicle.ad.mode == AutoDrive.MODE_LOAD then
            newIcon = AutoDrive.directory .. "textures/tipper_load.dds";
        elseif vehicle.ad.mode == AutoDrive.MODE_PICKUPANDDELIVER then
            newIcon = AutoDrive.directory .. "textures/tipper_overlay.dds";
        elseif vehicle.ad.mode == AutoDrive.MODE_UNLOAD then
            newIcon = AutoDrive.directory .. "textures/tipper_overlay.dds";
        else
            newIcon = nil;
        end;
    elseif self.name == "destinationOverlay" then
        if vehicle.ad.mode == AutoDrive.MODE_PICKUPANDDELIVER then
            newIcon = AutoDrive.directory .. "textures/tipper_load.dds";
        elseif vehicle.ad.mode == AutoDrive.MODE_DELIVERTO then
            newIcon = AutoDrive.directory .. "textures/tipper_overlay.dds";
        elseif vehicle.ad.mode ~= AutoDrive.MODE_BGA then
            newIcon = AutoDrive.directory .. "textures/destination.dds";
        else
            newIcon = nil;
        end;
    end;

    if newIcon ~= self.image then
        self.image = newIcon
        self.ov = Overlay:new(self.image, self.position.x, self.position.y, self.size.width, self.size.height);
    end;
end;


