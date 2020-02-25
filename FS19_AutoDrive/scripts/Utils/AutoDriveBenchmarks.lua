AutoDriveBenchmarks = {}
AutoDriveBenchmarks.enabled = false

--########################################################################################################
--###################################  AutoDriveBenchmark ( Localize )  ##################################
--########################################################################################################
--#######  'Localized'     ---> mean: 19.2  -- variance: 2.5  -- min: 18 -- max: 23 -- time: +0%   #######
--#######  'Not Localized' ---> mean: 36.02 -- variance: 11.5 -- min: 34 -- max: 57 -- time: +88%  #######
--########################################################################################################
function AutoDriveBenchmarks.Localize()
    local localized = function()
        local mmin = math.min
        local mmax = math.max
        for i = 1, 500000 do
            local m = mmin(9, 2, 36, 37, 8, 4, 15, 6, 71, 3, 13, 5, 7)
            m = mmax(9, 2, 36, 37, 8, 4, 15, 6, 71, 3, 13, 5, 7)
        end
    end

    local notLocalized = function()
        for i = 1, 500000 do
            local m = math.min(9, 2, 36, 37, 8, 4, 15, 6, 71, 3, 13, 5, 7)
            m = math.max(9, 2, 36, 37, 8, 4, 15, 6, 71, 3, 13, 5, 7)
        end
    end

    AutoDriveBenchmark:Bench("Not Localized", notLocalized)
    AutoDriveBenchmark:Bench("Localized", localized)
end

--##################################################################################################
--##############################  AutoDriveBenchmark ( Unpack Table )  #############################
--##################################################################################################
--#######  'Manual'  ---> mean: 12.58 -- variance: 2.5 -- min: 11 -- max: 16 -- time: +0%    #######
--#######  'Unpack4' ---> mean: 21.98 -- variance: 5.5 -- min: 20 -- max: 31 -- time: +75%   #######
--#######  'Unpack'  ---> mean: 26.2  -- variance: 9.5 -- min: 23 -- max: 42 -- time: +108%  #######
--##################################################################################################
function AutoDriveBenchmarks.UnpackTable()
    local manual = function()
        local a = {10, 82, 4, 25}
        local min = math.min
        for i = 1, 1000000 do
            local x = min(a[1], a[2], a[3], a[4])
        end
    end

    local unpackk = function()
        local a = {10, 82, 4, 25}
        local min = math.min
        local unpack = unpack
        for i = 1, 1000000 do
            local x = min(unpack(a))
        end
    end

    local unpack4 = function()
        local a = {10, 82, 4, 25}
        local min = math.min
        local function u4(a)
            return a[1], a[2], a[3], a[4]
        end
        for i = 1, 1000000 do
            local x = min(u4(a))
        end
    end

    AutoDriveBenchmark:Bench("Unpack4", unpack4)
    AutoDriveBenchmark:Bench("Unpack", unpackk)
    AutoDriveBenchmark:Bench("Manual", manual)
end

--##################################################################################################
--############################  AutoDriveBenchmark ( Functions As Param )  #########################
--##################################################################################################
--#######  'Local'  ---> mean: 16.02 -- variance: 1.5 -- min: 15 -- max: 18  -- time: +0%    #######
--#######  'Lambda' ---> mean: 58.98 -- variance: 46  -- min: 25 -- max: 117 -- time: +268%  #######
--##################################################################################################
function AutoDriveBenchmarks.FunctionsAsParam()
    local lambda = function()
        local func1 = function(a, b, func)
            return func(a + b)
        end

        for i = 1, 1000000 do
            local x =
                func1(
                1,
                2,
                function(a)
                    return a * 2
                end
            )
        end
    end

    local localDef = function()
        local func1 = function(a, b, func)
            return func(a + b)
        end

        local func2 = function(a)
            return a * 2
        end

        for i = 1, 1000000 do
            local x = func1(1, 2, func2)
        end
    end

    AutoDriveBenchmark:Bench("Lambda", lambda)
    AutoDriveBenchmark:Bench("Local", localDef)
end

--#################################################################################################
--##############################  AutoDriveBenchmark ( For Loops )  ###############################
--#################################################################################################
--#######  'Pairs'  ---> mean: 34.1  -- variance: 5.5 -- min: 33 -- max: 44 -- time: +0%    #######
--#######  'For'    ---> mean: 39.32 -- variance: 4.5 -- min: 38 -- max: 47 -- time: +15%   #######
--#######  'IPairs' ---> mean: 91.32 -- variance: 4   -- min: 90 -- max: 98 -- time: +168%  #######
--#################################################################################################
function AutoDriveBenchmarks.ForLoops()
    local pairs_l = function(a)
        local x = 0
        for i = 1, 100000 do
            for k, v in pairs(a) do
                x = v
            end
        end
    end

    local ipairs_l = function(a)
        local x = 0
        for i = 1, 100000 do
            for ii, v in ipairs(a) do
                x = v
            end
        end
    end

    local for_l = function(a)
        local x = 0
        for i = 1, 100000 do
            for ii = 1, #a do
                x = a[ii]
            end
        end
    end

    local benchTable = {}
    for i = 1, 100 do
        benchTable[i] = i * 2
    end

    AutoDriveBenchmark:Bench("Pairs", pairs_l, benchTable)
    AutoDriveBenchmark:Bench("IPairs", ipairs_l, benchTable)
    AutoDriveBenchmark:Bench("For", for_l, benchTable)
end

--#################################################################################################
--##############################  AutoDriveBenchmark ( Table Add Items )  #########################
--#################################################################################################
--#######  'For'    ---> mean: 6.36  -- variance: 0.5 -- min: 6  -- max: 7  -- time: +0%    #######
--#######  'While'  ---> mean: 9.32  -- variance: 1.5 -- min: 8  -- max: 11 -- time: +47%   #######
--#######  'Insert' ---> mean: 56.74 -- variance: 5.5 -- min: 54 -- max: 65 -- time: +792%  #######
--#################################################################################################
function AutoDriveBenchmarks.TableItems()
    local tinsert = function()
        local a = {}
        local tinsert = table.insert
        for i = 1, 1000000 do
            tinsert(a, i)
        end
    end

    local for_l = function()
        local a = {}
        for i = 1, 1000000 do
            a[i] = i
        end
    end

    local while_l = function()
        local a = {}
        local i = 1
        while i <= 1000000 do
            a[i] = i
            i = i + 1
        end
    end

    AutoDriveBenchmark:Bench("Insert", tinsert)
    AutoDriveBenchmark:Bench("For", for_l)
    AutoDriveBenchmark:Bench("While", while_l)
end

--#######################################################################################################
--##################################  AutoDriveBenchmark ( Table Init )  ################################
--#######################################################################################################
--#######  'Method 3' ---> mean: 100.2  -- variance: 25   -- min: 86  -- max: 136 -- time: +0%    #######
--#######  'Method 2' ---> mean: 112.48 -- variance: 27.5 -- min: 96  -- max: 151 -- time: +12%   #######
--#######  'Method 1' ---> mean: 286.38 -- variance: 103  -- min: 265 -- max: 471 -- time: +186%  #######
--#######################################################################################################
function AutoDriveBenchmarks.TableInit()
    local method1 = function()
        for i = 1, 1000000 do
            local a = {}
            a[1] = 1
            a[2] = 2
            a[3] = 3
            a[4] = 4
            a[5] = 5
        end
    end

    local method2 = function()
        for i = 1, 1000000 do
            local a = {true, true, true, true, true}
            a[1] = 1
            a[2] = 2
            a[3] = 3
            a[4] = 4
            a[5] = 5
        end
    end

    local method3 = function()
        for i = 1, 1000000 do
            local a = {1, 2, 3, 4, 5}
        end
    end

    AutoDriveBenchmark:Bench("Method 1", method1)
    AutoDriveBenchmark:Bench("Method 2", method2)
    AutoDriveBenchmark:Bench("Method 3", method3)
end

function AutoDriveBenchmarks.Run()
    if not AutoDriveBenchmarks.enabled then
        return
    end
    -- add here all benchmarks
    AutoDriveBenchmark:BeginBench("Localize")
    AutoDriveBenchmarks.Localize()
    AutoDriveBenchmark:EndBench()

    AutoDriveBenchmark:BeginBench("Unpack Table")
    AutoDriveBenchmarks.UnpackTable()
    AutoDriveBenchmark:EndBench()

    AutoDriveBenchmark:BeginBench("Functions As Param")
    AutoDriveBenchmarks.FunctionsAsParam()
    AutoDriveBenchmark:EndBench()

    AutoDriveBenchmark:BeginBench("For Loops")
    AutoDriveBenchmarks.ForLoops()
    AutoDriveBenchmark:EndBench()

    AutoDriveBenchmark:BeginBench("Table Add Items")
    AutoDriveBenchmarks.TableItems()
    AutoDriveBenchmark:EndBench()

    AutoDriveBenchmark:BeginBench("Table Init")
    AutoDriveBenchmarks.TableInit()
    AutoDriveBenchmark:EndBench()
end
