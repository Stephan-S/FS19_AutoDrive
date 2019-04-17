AutoDrive.LineDraw = {};
AutoDrive.LineDraw.initLines = 20;
AutoDrive.LineDraw.initColorR = 1;
AutoDrive.LineDraw.initColorG = 0;
AutoDrive.LineDraw.initColorB = 1;
AutoDrive.LineDraw.initColorA = 1;

AutoDrive.LineDraw.lines = {};
AutoDrive.LineDraw.jobs = {};
AutoDrive.LineDraw.jobCounter = 0;
AutoDrive.LineDraw.lineCounter = 0;
AutoDrive.LineDraw.needsResetting = true;

function AutoDrive:initLineDrawing()
    for i=1, AutoDrive.LineDraw.initLines, 1 do
        AutoDrive.LineDraw.lines[i] = AutoDrive:createLineObject();
    end;
end;

function AutoDrive:drawJobs()
    if AutoDrive.LineDraw.jobCounter == 0 then
        if AutoDrive.LineDraw.needsResetting == false then
            return;
        else
            AutoDrive.LineDraw.needsResetting = false;
        end;
    else
        AutoDrive.LineDraw.needsResetting = true;
    end;

    for i=1,AutoDrive.LineDraw.jobCounter,1 do
        local job = AutoDrive.LineDraw.jobs[i];
        if AutoDrive.LineDraw.lines[i] ~= nil then
            AutoDrive:parameterizeLine(AutoDrive.LineDraw.lines[i], job.startPoint, job.targetPoint, job.color, true);
        end;
    end;

    --Reset visibility of 'idle' lines
    for i=AutoDrive.LineDraw.jobCounter+1, AutoDrive.LineDraw.lineCounter,1 do
        setVisibility(AutoDrive.LineDraw.lines[i], false);
    end;

    AutoDrive.LineDraw.jobCounter = 0;
end;

function AutoDrive:drawLine(startPoint, targetPoint, r, g, b, a)
    if (startPoint == nil or targetPoint == nil) then
        return;
    end;
    local color = AutoDrive:newColor(r, g, b, a);
    AutoDrive.LineDraw.jobCounter = AutoDrive.LineDraw.jobCounter + 1;
    while AutoDrive.LineDraw.jobCounter > AutoDrive.LineDraw.lineCounter do
        AutoDrive.LineDraw.lines[AutoDrive.LineDraw.lineCounter+1] = AutoDrive:createLineObject();
    end;
    local job = {};
    job["startPoint"] = startPoint;
    job["targetPoint"] = targetPoint;
    job["color"] = color;
    AutoDrive.LineDraw.jobs[AutoDrive.LineDraw.jobCounter] = job;
end;

function AutoDrive:createLineObject()
    local i3dNode =  g_i3DManager:loadSharedI3DFile( AutoDrive.directory .. 'lineDrawing/' .. "Line" .. '.i3d');
    local itemNode = getChildAt(i3dNode, 0);
    link(getRootNode(), itemNode);
    setRigidBodyType(itemNode, 'NoRigidBody');
    setTranslation(itemNode, 0, 0, 0);
    setVisibility(itemNode, false);
    delete(i3dNode);
    AutoDrive.LineDraw.lineCounter = AutoDrive.LineDraw.lineCounter + 1;
    return itemNode;
end;

function AutoDrive:parameterizeLine(line, startPoint, targetPoint, color, visible)
    setTranslation(line, startPoint.x, startPoint.y + AutoDrive.drawHeight, startPoint.z);
    
    setVisibility(line, visible);

    --- Get the direction to the end point
    local dirX, _, dirZ, distToNextPoint = AutoDrive:getWorldDirection(startPoint.x, startPoint.y, startPoint.z, targetPoint.x, targetPoint.y, targetPoint.z);
    --- Get Y rotation
    local rotY = MathUtil.getYRotationFromDirection(dirX, dirZ);
    --- Get X rotation
    local dy = (targetPoint.y) - (startPoint.y);
    local dist2D = MathUtil.vector2Length(targetPoint.x - startPoint.x, targetPoint.z - startPoint.z);
    local rotX = -MathUtil.getYRotationFromDirection(dy, dist2D);

    --- Set the direction of the line
    setRotation(line, rotX, rotY, 0);
    --- Set the length if the line
    setScale(line, 1, 1, distToNextPoint);

    --- Update line color
    setShaderParameter(line, 'shapeColor', color.r, color.g, color.b, color.a, false);
end;