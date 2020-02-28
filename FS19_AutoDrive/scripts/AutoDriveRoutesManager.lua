AutoDriveRoutesManager = {}
AutoDriveRoutesManager.revision = 1

AutoDriveRoutesManager.routes = {}
AutoDriveRoutesManager.rootFolder = ""
AutoDriveRoutesManager.managerFolder = ""
AutoDriveRoutesManager.routesFolder = ""
AutoDriveRoutesManager.xmlFile = ""
AutoDriveRoutesManager.xml = nil

function AutoDriveRoutesManager.load()
    -- defining and creating needed folders
    AutoDriveRoutesManager.rootFolder = getUserProfileAppPath() .. "autoDrive/"
    createFolder(AutoDriveRoutesManager.rootFolder)
    AutoDriveRoutesManager.managerFolder = AutoDriveRoutesManager.rootFolder .. "routesManager/"
    createFolder(AutoDriveRoutesManager.managerFolder)
    AutoDriveRoutesManager.routesFolder = AutoDriveRoutesManager.managerFolder .. "routes/"
    createFolder(AutoDriveRoutesManager.routesFolder)

    AutoDriveRoutesManager.xmlFile = AutoDriveRoutesManager.managerFolder .. "routes.xml"
    if fileExists(AutoDriveRoutesManager.xmlFile) then
        AutoDriveRoutesManager.xml = loadXMLFile("autoDriveRoutesManager_xml", AutoDriveRoutesManager.xmlFile)
        -- loading routes
        local i = 0
        while true do
            local key = string.format("autoDriveRoutesManager.routes.route(%d)", i)
            if not hasXMLProperty(AutoDriveRoutesManager.xml, key) then
                break
            end
            local name = getXMLString(AutoDriveRoutesManager.xml, key .. "#name")
            local fileName = getXMLString(AutoDriveRoutesManager.xml, key .. "#fileName")
            local map = getXMLString(AutoDriveRoutesManager.xml, key .. "#map")
            local revision = getXMLInt(AutoDriveRoutesManager.xml, key .. "#revision")
            local date = getXMLString(AutoDriveRoutesManager.xml, key .. "#date")
            i = i + 1
            AutoDriveRoutesManager.routes[i] = {name = name, fileName = fileName, map = map, revision = revision, date = date}
        end
    else
        AutoDriveRoutesManager.xml = createXMLFile("autoDriveRoutesManager_xml", AutoDriveRoutesManager.xmlFile, "autoDriveRoutesManager")
        saveXMLFile(AutoDriveRoutesManager.xml)
    end
end

function AutoDriveRoutesManager.import(name)
    local route =
        table.f_find(
        AutoDriveRoutesManager.routes,
        function(v)
            return v.name == name
        end
    )
    if route ~= nil then
        if fileExists(AutoDriveRoutesManager.routesFolder .. route.fileName) then
            local loadXml = loadXMLFile("routeImport_xml", AutoDriveRoutesManager.routesFolder .. route.fileName)
            local mapWayPoints = {}
            local mapMarkers = {}
            local groups = {}
            AutoDrive.readGraphFromXml(loadXml, "routeExport", mapWayPoints, mapMarkers, groups)
            delete(loadXml)
            -- here we will handle MP upload
            AutoDrive.mapWayPoints = mapWayPoints
            AutoDrive.mapMarker = mapMarkers
            AutoDrive.groups = groups
        end
    end
end

function AutoDriveRoutesManager.export(name)
    local fileName = AutoDriveRoutesManager.getFileName()
    if name == nil or name == "" then
        name = fileName
    end
    fileName = fileName .. ".xml"

    local route = nil
    local saveXml = -1
    local mapName = AutoDrive.loadedMap
    local routeIndex =
        table.f_indexOf(
        AutoDriveRoutesManager.routes,
        function(v)
            return v.name == name and v.map == mapName
        end
    )

    -- saving route to xml, if a route with the same name and map already exists, overwrite it
    if routeIndex ~= nil then
        route = AutoDriveRoutesManager.routes[routeIndex]
        route.revision = AutoDriveRoutesManager.revision
        route.date = getDate("%Y/%m/%d %H:%M:%S")
        saveXml = loadXMLFile("routeExport_xml", AutoDriveRoutesManager.routesFolder .. route.fileName)
    else
        route = {name = name, fileName = fileName, map = mapName, revision = AutoDriveRoutesManager.revision, date = getDate("%Y/%m/%d %H:%M:%S")}
        table.insert(AutoDriveRoutesManager.routes, route)
        saveXml = createXMLFile("routeExport_xml", AutoDriveRoutesManager.routesFolder .. fileName, "routeExport")
    end

    AutoDrive.writeGraphToXml(saveXml, "routeExport", AutoDrive.mapWayPoints, AutoDrive.mapMarker, AutoDrive.groups)

    saveXMLFile(saveXml)
    delete(saveXml)

    AutoDriveRoutesManager.saveRoutes()
end

function AutoDriveRoutesManager.remove(name)
    local mapName = AutoDrive.loadedMap
    local routeIndex =
        table.f_indexOf(
        AutoDriveRoutesManager.routes,
        function(v)
            return v.name == name and v.map == mapName
        end
    )

    if routeIndex ~= nil then
        local route = table.remove(AutoDriveRoutesManager.routes, routeIndex)
        getfenv(0).deleteFile(AutoDriveRoutesManager.routesFolder .. route.fileName)
        AutoDriveRoutesManager.saveRoutes()
    end
end

function AutoDriveRoutesManager.getFileName()
    local fileName = string.random(16)
    -- finding a not used file name
    while fileExists(AutoDriveRoutesManager.routesFolder .. fileName .. ".xml") do
        fileName = string.random(16)
    end
    return fileName
end

function AutoDriveRoutesManager.saveRoutes()
    -- updating routes.xml
    removeXMLProperty(AutoDriveRoutesManager.xml, "autoDriveRoutesManager.routes")
    for i, route in pairs(AutoDriveRoutesManager.routes) do
        local key = string.format("autoDriveRoutesManager.routes.route(%d)", i - 1)
        removeXMLProperty(AutoDriveRoutesManager.xml, key)
        setXMLString(AutoDriveRoutesManager.xml, key .. "#name", route.name)
        setXMLString(AutoDriveRoutesManager.xml, key .. "#fileName", route.fileName)
        setXMLString(AutoDriveRoutesManager.xml, key .. "#map", route.map)
        setXMLInt(AutoDriveRoutesManager.xml, key .. "#revision", route.revision)
        setXMLString(AutoDriveRoutesManager.xml, key .. "#date", route.date)
    end
    saveXMLFile(AutoDriveRoutesManager.xml)
end

function AutoDriveRoutesManager.getRoutes(map)
    return table.f_filter(
        AutoDriveRoutesManager.routes,
        function(v)
            return v.map == map
        end
    )
end

function AutoDriveRoutesManager.delete()
    if AutoDriveRoutesManager.xml ~= nil then
        delete(AutoDriveRoutesManager.xml)
    end
end
