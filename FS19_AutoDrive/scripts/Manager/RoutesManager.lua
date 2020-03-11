RoutesManager = {}
RoutesManager.revision = 1

RoutesManager.routes = {}
RoutesManager.rootFolder = ""
RoutesManager.managerFolder = ""
RoutesManager.routesFolder = ""
RoutesManager.xmlFile = ""
RoutesManager.xml = nil

function RoutesManager.load()
    -- defining and creating needed folders
    RoutesManager.rootFolder = getUserProfileAppPath() .. "autoDrive/"
    createFolder(RoutesManager.rootFolder)
    RoutesManager.managerFolder = RoutesManager.rootFolder .. "routesManager/"
    createFolder(RoutesManager.managerFolder)
    RoutesManager.routesFolder = RoutesManager.managerFolder .. "routes/"
    createFolder(RoutesManager.routesFolder)

    RoutesManager.xmlFile = RoutesManager.managerFolder .. "routes.xml"
    if fileExists(RoutesManager.xmlFile) then
        RoutesManager.xml = loadXMLFile("RoutesManager_xml", RoutesManager.xmlFile)
        -- loading routes
        local i = 0
        while true do
            local key = string.format("RoutesManager.routes.route(%d)", i)
            if not hasXMLProperty(RoutesManager.xml, key) then
                break
            end
            local name = getXMLString(RoutesManager.xml, key .. "#name")
            local fileName = getXMLString(RoutesManager.xml, key .. "#fileName")
            local map = getXMLString(RoutesManager.xml, key .. "#map")
            local revision = getXMLInt(RoutesManager.xml, key .. "#revision")
            local date = getXMLString(RoutesManager.xml, key .. "#date")
            i = i + 1
            RoutesManager.routes[i] = {name = name, fileName = fileName, map = map, revision = revision, date = date}
        end
    else
        RoutesManager.xml = createXMLFile("RoutesManager_xml", RoutesManager.xmlFile, "RoutesManager")
        saveXMLFile(RoutesManager.xml)
    end
end

function RoutesManager.import(name)
    local route =
        table.f_find(
        RoutesManager.routes,
        function(v)
            return v.name == name
        end
    )
    if route ~= nil then
        if fileExists(RoutesManager.routesFolder .. route.fileName) then
            local loadXml = loadXMLFile("routeImport_xml", RoutesManager.routesFolder .. route.fileName)
            local wayPoints = {}
            local mapMarkers = {}
            local groups = {}
            AutoDrive.readGraphFromXml(loadXml, "routeExport", wayPoints, mapMarkers, groups)
            delete(loadXml)
            -- here we will handle MP upload
            ADGraphManger:setWayPoints(wayPoints)
            ADGraphManager:setMapMarkers(mapMarkers)
            AutoDrive.groups = groups
        end
    end
end

function RoutesManager.export(name)
    local fileName = RoutesManager.getFileName()
    if name == nil or name == "" then
        name = fileName
    end
    fileName = fileName .. ".xml"

    local route = nil
    local saveXml = -1
    local mapName = AutoDrive.loadedMap
    local routeIndex =
        table.f_indexOf(
        RoutesManager.routes,
        function(v)
            return v.name == name and v.map == mapName
        end
    )

    -- saving route to xml, if a route with the same name and map already exists, overwrite it
    if routeIndex ~= nil then
        route = RoutesManager.routes[routeIndex]
        route.revision = RoutesManager.revision
        route.date = getDate("%Y/%m/%d %H:%M:%S")
        saveXml = loadXMLFile("routeExport_xml", RoutesManager.routesFolder .. route.fileName)
    else
        route = {name = name, fileName = fileName, map = mapName, revision = RoutesManager.revision, date = getDate("%Y/%m/%d %H:%M:%S")}
        table.insert(RoutesManager.routes, route)
        saveXml = createXMLFile("routeExport_xml", RoutesManager.routesFolder .. fileName, "routeExport")
    end

    AutoDrive.writeGraphToXml(saveXml, "routeExport", ADGraphManager:getWayPoints(), ADGraphManager:getMapMarker(), AutoDrive.groups)

    saveXMLFile(saveXml)
    delete(saveXml)

    RoutesManager.saveRoutes()
end

function RoutesManager.remove(name)
    local mapName = AutoDrive.loadedMap
    local routeIndex =
        table.f_indexOf(
        RoutesManager.routes,
        function(v)
            return v.name == name and v.map == mapName
        end
    )

    if routeIndex ~= nil then
        local route = table.remove(RoutesManager.routes, routeIndex)
        getfenv(0).deleteFile(RoutesManager.routesFolder .. route.fileName)
        RoutesManager.saveRoutes()
    end
end

function RoutesManager.getFileName()
    local fileName = string.random(16)
    -- finding a not used file name
    while fileExists(RoutesManager.routesFolder .. fileName .. ".xml") do
        fileName = string.random(16)
    end
    return fileName
end

function RoutesManager.saveRoutes()
    -- updating routes.xml
    removeXMLProperty(RoutesManager.xml, "RoutesManager.routes")
    for i, route in pairs(RoutesManager.routes) do
        local key = string.format("RoutesManager.routes.route(%d)", i - 1)
        removeXMLProperty(RoutesManager.xml, key)
        setXMLString(RoutesManager.xml, key .. "#name", route.name)
        setXMLString(RoutesManager.xml, key .. "#fileName", route.fileName)
        setXMLString(RoutesManager.xml, key .. "#map", route.map)
        setXMLInt(RoutesManager.xml, key .. "#revision", route.revision)
        setXMLString(RoutesManager.xml, key .. "#date", route.date)
    end
    saveXMLFile(RoutesManager.xml)
end

function RoutesManager.getRoutes(map)
    return table.f_filter(
        RoutesManager.routes,
        function(v)
            return v.map == map
        end
    )
end

function RoutesManager.delete()
    if RoutesManager.xml ~= nil then
        delete(RoutesManager.xml)
    end
end
