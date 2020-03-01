AutoDrive.CubeDraw = {}
AutoDrive.CubeDraw.initCubes = 20
AutoDrive.CubeDraw.maxCubes = 1000
AutoDrive.CubeDraw.initColorR = 1
AutoDrive.CubeDraw.initColorG = 0
AutoDrive.CubeDraw.initColorB = 1
AutoDrive.CubeDraw.initColorA = 1

AutoDrive.CubeDraw.cubes = {}
AutoDrive.CubeDraw.jobs = {}
AutoDrive.CubeDraw.jobCounter = 0
AutoDrive.CubeDraw.cubeCounter = 0
AutoDrive.CubeDraw.needsResetting = true

function AutoDrive:initCubeDrawing()
    for i = 1, AutoDrive.CubeDraw.initCubes, 1 do
        AutoDrive.CubeDraw.cubes[i] = AutoDrive:createCubeObject()
    end
end

function AutoDrive:drawCubeJobs()
    if AutoDrive.CubeDraw.jobCounter == 0 then
        if AutoDrive.CubeDraw.needsResetting == false then
            return
        else
            AutoDrive.CubeDraw.needsResetting = false
        end
    else
        AutoDrive.CubeDraw.needsResetting = true
    end

    for i = 1, AutoDrive.CubeDraw.jobCounter, 1 do
        local job = AutoDrive.CubeDraw.jobs[i]
        if AutoDrive.CubeDraw.cubes[i] ~= nil then
            AutoDrive:parameterizeCube(AutoDrive.CubeDraw.cubes[i], job.location, job.color, true)
        end
    end

    --Reset visibility of 'idle' cubes
    for i = AutoDrive.CubeDraw.jobCounter + 1, AutoDrive.CubeDraw.cubeCounter, 1 do
        setVisibility(AutoDrive.CubeDraw.cubes[i], false)
    end

    AutoDrive.CubeDraw.jobCounter = 0
end

function AutoDrive.drawCube(location, r, g, b, a)
    if location == nil then
        return
    end
    local color = {r = r, g = g, b = b, a = a}
    AutoDrive.CubeDraw.jobCounter = AutoDrive.CubeDraw.jobCounter + 1
    while AutoDrive.CubeDraw.jobCounter > AutoDrive.CubeDraw.cubeCounter and AutoDrive.CubeDraw.cubeCounter < AutoDrive.CubeDraw.maxCubes do
        AutoDrive.CubeDraw.cubes[AutoDrive.CubeDraw.cubeCounter + 1] = AutoDrive:createCubeObject()
    end

    local job = {}
    job["location"] = location
    job["color"] = color
    AutoDrive.CubeDraw.jobs[AutoDrive.CubeDraw.jobCounter] = job
end

function AutoDrive:createCubeObject()
    local i3dNode = g_i3DManager:loadSharedI3DFile(AutoDrive.directory .. "lineDrawing/" .. "Cube" .. ".i3d")
    local itemNode = getChildAt(i3dNode, 0)
    link(getRootNode(), itemNode)
    setRigidBodyType(itemNode, "NoRigidBody")
    setTranslation(itemNode, 0, 0, 0)
    setVisibility(itemNode, false)
    delete(i3dNode)
    AutoDrive.CubeDraw.cubeCounter = AutoDrive.CubeDraw.cubeCounter + 1
    return itemNode
end

function AutoDrive:parameterizeCube(cube, location, color, visible)
    setTranslation(cube, location.x, location.y + AutoDrive.drawHeight + AutoDrive.getSetting("lineHeight"), location.z)

    setVisibility(cube, visible)

    --- Get the direction to the end point
    --local dirX, _, dirZ, distToNextPoint = AutoDrive.getWorldDirection(startPoint.x, startPoint.y, startPoint.z, targetPoint.x, targetPoint.y, targetPoint.z)
    --- Get Y rotation
    --local rotY = MathUtil.getYRotationFromDirection(dirX, dirZ)
    --- Get X rotation
    --local dy = (targetPoint.y) - (startPoint.y)
    --local dist2D = MathUtil.vector2Length(targetPoint.x - startPoint.x, targetPoint.z - startPoint.z)
    --local rotX = -MathUtil.getYRotationFromDirection(dy, dist2D)

    --- Set the direction of the cube
    --setRotation(cube, 0, 0, 0)
    --- Set the length of the cube
    setScale(cube, 0.2, 0.2, 0.2)

    --- Update cube color
    setShaderParameter(cube, "shapeColor", color.r / 2, color.g / 2, color.b / 2, color.a, false)
end
