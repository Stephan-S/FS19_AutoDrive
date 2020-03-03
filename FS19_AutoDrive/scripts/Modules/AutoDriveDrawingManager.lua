AutoDriveDrawingManager = {}
AutoDriveDrawingManager.i3DBaseDir = "drawing/"
AutoDriveDrawingManager.yOffset = 0
AutoDriveDrawingManager.emittivity = 0
AutoDriveDrawingManager.emittivityNextUpdate = 0
AutoDriveDrawingManager.debug = {}

AutoDriveDrawingManager.lines = {}
AutoDriveDrawingManager.lines.fileName = "line.i3d"
AutoDriveDrawingManager.lines.buffer = {}
AutoDriveDrawingManager.lines.tasks = {}
AutoDriveDrawingManager.lines.lastDrawZero = true

AutoDriveDrawingManager.arrows = {}
AutoDriveDrawingManager.arrows.fileName = "arrow.i3d"
AutoDriveDrawingManager.arrows.buffer = {}
AutoDriveDrawingManager.arrows.tasks = {}
AutoDriveDrawingManager.arrows.lastDrawZero = true

AutoDriveDrawingManager.sSphere = {}
AutoDriveDrawingManager.sSphere.fileName = "sphere_small.i3d"
AutoDriveDrawingManager.sSphere.buffer = {}
AutoDriveDrawingManager.sSphere.tasks = {}
AutoDriveDrawingManager.sSphere.lastDrawZero = true

AutoDriveDrawingManager.sphere = {}
AutoDriveDrawingManager.sphere.fileName = "sphere.i3d"
AutoDriveDrawingManager.sphere.buffer = {}
AutoDriveDrawingManager.sphere.tasks = {}
AutoDriveDrawingManager.sphere.lastDrawZero = true

function AutoDriveDrawingManager:load()
    -- preloading and storing in chache I3D files
    self.i3DBaseDir = AutoDrive.directory .. self.i3DBaseDir
    g_i3DManager:fillSharedI3DFileCache(self.lines.fileName, self.i3DBaseDir)
    g_i3DManager:fillSharedI3DFileCache(self.arrows.fileName, self.i3DBaseDir)
    g_i3DManager:fillSharedI3DFileCache(self.sSphere.fileName, self.i3DBaseDir)
    g_i3DManager:fillSharedI3DFileCache(self.sphere.fileName, self.i3DBaseDir)
end

function AutoDriveDrawingManager.initObject(id)
    local itemId = getChildAt(id, 0)
    link(getRootNode(), itemId)
    setRigidBodyType(itemId, "NoRigidBody")
    setTranslation(itemId, 0, 0, 0)
    setVisibility(itemId, false)
    delete(id)
    return itemId
end

function AutoDriveDrawingManager:addLineTask(sx, sy, sz, ex, ey, ez, r, g, b)
    -- storing task
    table.insert(self.lines.tasks, {sx = sx, sy = sy, sz = sz, ex = ex, ey = ey, ez = ez, r = r, g = g, b = b})
end

function AutoDriveDrawingManager:addArrowTask(sx, sy, sz, ex, ey, ez, r, g, b)
    -- storing task
    table.insert(self.arrows.tasks, {sx = sx, sy = sy, sz = sz, ex = ex, ey = ey, ez = ez, r = r, g = g, b = b})
end

function AutoDriveDrawingManager:addSmallSphereTask(x, y, z, r, g, b)
    -- storing task
    table.insert(self.sSphere.tasks, {x = x, y = y, z = z, r = r, g = g, b = b})
end

function AutoDriveDrawingManager:addSphereTask(x, y, z, scale, r, g, b, a)
    scale = scale or 1
    a = a or 0
    -- storing task
    table.insert(self.sphere.tasks, {x = x, y = y, z = z, r = r, g = g, b = b, a = a, scale = scale})
end

function AutoDriveDrawingManager:draw()
    local time = netGetTime()
    local ad = AutoDrive
    self.yOffset = ad.drawHeight + ad.getSetting("lineHeight")

    -- update emittivity only once every 600 frames
    if self.emittivityNextUpdate <= 0 then
        local r, g, b = getLightColor(g_currentMission.environment.sunLightId)
        local light = (r + g + b) / 3
        self.emittivity = 1 - light
        if self.emittivity > 0.9 then
            -- enable glow
            self.emittivity = self.emittivity * 5
        end
        self.emittivityNextUpdate = 600
    else
        self.emittivityNextUpdate = self.emittivityNextUpdate - 1
    end
    self.debug["Emittivity"] = self.emittivity

    local tTime = netGetTime()
    self.debug["LinesTime"] = self:drawObjects(self.lines, self.drawLine, self.initObject)
    self.debug["LinesTime"].Time = netGetTime() - tTime

    tTime = netGetTime()
    self.debug["Arrows"] = self:drawObjects(self.arrows, self.drawArrow, self.initObject)
    self.debug["Arrows"].Time = netGetTime() - tTime

    tTime = netGetTime()
    self.debug["sSphere"] = self:drawObjects(self.sSphere, self.drawSmallSphere, self.initObject)
    self.debug["sSphere"].Time = netGetTime() - tTime

    tTime = netGetTime()
    self.debug["sphere"] = self:drawObjects(self.sphere, self.drawSphere, self.initObject)
    self.debug["sphere"].Time = netGetTime() - tTime

    self.debug["TotalTime"] = netGetTime() - time
    if AutoDrive.getDebugChannelIsSet(AutoDrive.DC_RENDERINFO) then
        AutoDrive.renderTable(0.6, 0.7, 0.012, self.debug, 5)
    end
end

function AutoDriveDrawingManager:drawObjects(obj, dFunc, iFunc)
    local stats = {}
    local dCount = #obj.tasks
    stats["Tasks"] = dCount
    -- this will prevent to run when there is nothing to draw but it also ensure to run one last time to set objects visibility to false
    if dCount > 0 or obj.lastDrawZero == false then
        local bCount = #obj.buffer
        stats["Buffer"] = bCount
        if dCount > bCount then
            -- increasing buffer size
            local baseDir = self.i3DBaseDir
            for i = 1, dCount - bCount do
                local id = g_i3DManager:loadSharedI3DFile(obj.fileName, baseDir)
                obj.buffer[bCount + i] = iFunc(id)
            end
        end
        for _, id in pairs(obj.buffer) do
            local task = table.remove(obj.tasks)
            if task then
                -- call the drawing function for each task
                dFunc(self, id, task)
            else
                -- make invisible the remaining items in the buffer
                setVisibility(id, false)
            end
        end
    end
    obj.lastDrawZero = dCount <= 0
    return stats
end

function AutoDriveDrawingManager:drawLine(id, task)
    local atan2 = math.atan2

    -- Get the direction to the end point
    local dirX, _, dirZ, distToNextPoint = AutoDrive.getWorldDirection(task.sx, task.sy, task.sz, task.ex, task.ey, task.ez)

    -- Get Y rotation
    local rotY = atan2(dirX, dirZ)

    -- Get X rotation
    local dy = task.ey - task.sy
    local dist2D = MathUtil.vector2Length(task.ex - task.sx, task.ez - task.sz)
    local rotX = -atan2(dy, dist2D)

    setTranslation(id, task.sx, task.sy + self.yOffset, task.sz)

    setScale(id, 1, 1, distToNextPoint)

    -- Set the direction of the line
    setRotation(id, rotX, rotY, 0)

    -- Update line color
    setShaderParameter(id, "color", task.r, task.g, task.b, self.emittivity, false)

    -- Update line visibility
    setVisibility(id, true)
end

function AutoDriveDrawingManager:drawArrow(id, task)
    local atan2 = math.atan2

    local x = (task.sx + task.ex) / 2
    local y = (task.sy + task.ey) / 2
    local z = (task.sz + task.ez) / 2

    -- Get the direction to the end point
    local dirX, _, dirZ, _ = AutoDrive.getWorldDirection(task.sx, task.sy, task.sz, task.ex, task.ey, task.ez)

    -- Get Y rotation
    local rotY = atan2(dirX, dirZ)

    -- Get X rotation
    local dy = task.ey - task.sy
    local dist2D = MathUtil.vector2Length(task.ex - task.sx, task.ez - task.sz)
    local rotX = -atan2(dy, dist2D)

    setTranslation(id, x, y + self.yOffset, z)

    -- Set the direction of the arrow
    setRotation(id, rotX, rotY, 0)

    -- Update arrow color
    setShaderParameter(id, "color", task.r, task.g, task.b, self.emittivity, false)

    -- Update arrow visibility
    setVisibility(id, true)
end

function AutoDriveDrawingManager:drawSmallSphere(id, task)
    setTranslation(id, task.x, task.y + self.yOffset, task.z)
    setShaderParameter(id, "color", task.r, task.g, task.b, self.emittivity, false)
    setVisibility(id, true)
end

function AutoDriveDrawingManager:drawSphere(id, task)
    setTranslation(id, task.x, task.y + self.yOffset, task.z)
    setScale(id, task.scale, task.scale, task.scale)
    setShaderParameter(id, "color", task.r, task.g, task.b, self.emittivity + task.a, false)
    setVisibility(id, true)
end
