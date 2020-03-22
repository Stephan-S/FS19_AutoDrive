ADRoutesManager = {}

ADRoutesManager.routes = {}
ADRoutesManager.rootFolder = ""
ADRoutesManager.managerFolder = ""
ADRoutesManager.routesFolder = ""
ADRoutesManager.xmlFile = ""
ADRoutesManager.xml = nil

function ADRoutesManager.load()
    -- defining and creating needed folders
    ADRoutesManager.rootFolder = getUserProfileAppPath() .. "autoDrive/"
    createFolder(ADRoutesManager.rootFolder)
    ADRoutesManager.managerFolder = ADRoutesManager.rootFolder .. "routesManager/"
    createFolder(ADRoutesManager.managerFolder)
    ADRoutesManager.routesFolder = ADRoutesManager.managerFolder .. "routes/"
    createFolder(ADRoutesManager.routesFolder)

    ADRoutesManager.loadRoutesFromXML()
end

function ADRoutesManager.loadRoutesFromXML()
    ADRoutesManager.routes = {}
    ADRoutesManager.xmlFile = ADRoutesManager.managerFolder .. "routes.xml"
    if fileExists(ADRoutesManager.xmlFile) then
        ADRoutesManager.xml = loadXMLFile("RoutesManager_xml", ADRoutesManager.xmlFile)
        -- loading routes
        local i = 0
        while true do
            local key = string.format("autoDriveRoutesManager.routes.route(%d)", i)
            if not hasXMLProperty(ADRoutesManager.xml, key) then
                break
            end
            local name = getXMLString(ADRoutesManager.xml, key .. "#name")
            local fileName = getXMLString(ADRoutesManager.xml, key .. "#fileName")
            local map = getXMLString(ADRoutesManager.xml, key .. "#map")
            local revision = getXMLInt(ADRoutesManager.xml, key .. "#revision")
            local date = getXMLString(ADRoutesManager.xml, key .. "#date")
            i = i + 1
            ADRoutesManager.routes[i] = {name = name, fileName = fileName, map = map, revision = revision, date = date}
        end
    else
        ADRoutesManager.xml = createXMLFile("RoutesManager_xml", ADRoutesManager.xmlFile, "autoDriveRoutesManager")
        saveXMLFile(ADRoutesManager.xml)
    end
end

function ADRoutesManager.import(name)
    local route =
        table.f_find(
        ADRoutesManager.routes,
        function(v)
            return v.name == name
        end
    )
    if route ~= nil then
        if fileExists(ADRoutesManager.routesFolder .. route.fileName) then
            local loadXml = loadXMLFile("routeImport_xml", ADRoutesManager.routesFolder .. route.fileName)
            local wayPoints = {}
            local mapMarkers = {}
            local groups = {}
            AutoDrive.readGraphFromXml(loadXml, "routeExport", wayPoints, mapMarkers, groups)
            delete(loadXml)
            -- here we will handle MP upload
            ADGraphManager:setWayPoints(wayPoints)
            ADGraphManager:setMapMarkers(mapMarkers)
            ADGraphManager:setGroups(groups)
        end
    end
end

function ADRoutesManager.export(name)
    local fileName = ADRoutesManager.getFileName()
    if name == nil or name == "" then
        name = fileName
    end
    fileName = fileName .. ".xml"

    local route = nil
    local saveXml = -1
    local mapName = AutoDrive.loadedMap
    local routeIndex =
        table.f_indexOf(
        ADRoutesManager.routes,
        function(v)
            return v.name == name and v.map == mapName
        end
    )

    -- saving route to xml, if a route with the same name and map already exists, overwrite it
    if routeIndex ~= nil then
        route = ADRoutesManager.routes[routeIndex]
        route.revision = route.revision + 1
        route.date = getDate("%Y/%m/%d %H:%M:%S")
        saveXml = loadXMLFile("routeExport_xml", ADRoutesManager.routesFolder .. route.fileName)
    else
        route = {name = name, fileName = fileName, map = mapName, revision = 1, date = getDate("%Y/%m/%d %H:%M:%S")}
        table.insert(ADRoutesManager.routes, route)
        saveXml = createXMLFile("routeExport_xml", ADRoutesManager.routesFolder .. fileName, "routeExport")
    end

    AutoDrive.writeGraphToXml(saveXml, "routeExport", ADGraphManager:getWayPoints(), ADGraphManager:getMapMarkers(), ADGraphManager:getGroups())

    saveXMLFile(saveXml)
    delete(saveXml)

    ADRoutesManager.saveRoutes()
end

function ADRoutesManager.remove(name)
    local mapName = AutoDrive.loadedMap
    local routeIndex =
        table.f_indexOf(
        ADRoutesManager.routes,
        function(v)
            return v.name == name and v.map == mapName
        end
    )

    if routeIndex ~= nil then
        local route = table.remove(ADRoutesManager.routes, routeIndex)
        getfenv(0).deleteFile(ADRoutesManager.routesFolder .. route.fileName)
        ADRoutesManager.saveRoutes()
    end
end

function ADRoutesManager.getFileName()
    local fileName = string.random(16)
    -- finding a not used file name
    while fileExists(ADRoutesManager.routesFolder .. fileName .. ".xml") do
        fileName = string.random(16)
    end
    return fileName
end

function ADRoutesManager.saveRoutes()
    -- updating routes.xml
    removeXMLProperty(ADRoutesManager.xml, "autoDriveRoutesManager.routes")
    for i, route in pairs(ADRoutesManager.routes) do
        local key = string.format("autoDriveRoutesManager.routes.route(%d)", i - 1)
        removeXMLProperty(ADRoutesManager.xml, key)
        setXMLString(ADRoutesManager.xml, key .. "#name", route.name)
        setXMLString(ADRoutesManager.xml, key .. "#fileName", route.fileName)
        setXMLString(ADRoutesManager.xml, key .. "#map", route.map)
        setXMLInt(ADRoutesManager.xml, key .. "#revision", route.revision)
        setXMLString(ADRoutesManager.xml, key .. "#date", route.date)
    end
    saveXMLFile(ADRoutesManager.xml)
end

function ADRoutesManager.getRoutes(map)
    return table.f_filter(
        ADRoutesManager.routes,
        function(v)
            return v.map == map
        end
    )
end

function ADRoutesManager.delete()
    if ADRoutesManager.xml ~= nil then
        delete(ADRoutesManager.xml)
    end
end
