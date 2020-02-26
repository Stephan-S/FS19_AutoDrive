AutoDriveBenchmark = {}
AutoDriveBenchmark.currentBenchStarted = false
AutoDriveBenchmark.currentBenchName = ""
AutoDriveBenchmark.currentBenchData = {}
AutoDriveBenchmark.reps = 50

function AutoDriveBenchmark:BeginBench(name)
    if self.currentBenchStarted then
        g_logManager:error("[AutoDriveBenchmark] Can't start benchmark '%s' untill '%s' is still running", name, self.currentBenchName)
        return
    end
    self.currentBenchStarted = true
    self.currentBenchName = name
    self.currentBenchStarted = {}
end

function AutoDriveBenchmark:EndBench()
    if not self.currentBenchStarted then
        g_logManager:error("[AutoDriveBenchmark] There is no benchmark to end")
        return
    end
    print("")
    print("###########################################################################################################")
    print(string.format("####################################  AutoDriveBenchmark ( %s )  ####################################", self.currentBenchName))
    print("###########################################################################################################")
    local means = {}
    for _, values in pairs(self.currentBenchData) do
        values.mean = values.time / self.reps
        values.min = math.min(unpack(values.runs))
        values.max = math.max(unpack(values.runs))
        values.variance = ((values.max - values.mean) + (values.mean - values.min)) / 2
        table.insert(means, values.mean)
    end
    local minMean = math.min(unpack(means))
    for name, values in pairs(self.currentBenchData) do
        local score = (values.mean / minMean - 1) * 100
        print(string.format("#######  '%s' ---> mean: %s -- var: %s -- min: %s -- max: %s -- time: +%.0f%%", name, values.mean, values.variance, values.min, values.max, score))
    end
    print("###########################################################################################################")
    print("")
    self.currentBenchStarted = false
    self.currentBenchData = {}
end

function AutoDriveBenchmark:Bench(name, func, ...)
    if not self.currentBenchStarted then
        g_logManager:error("[AutoDriveBenchmark] There is no benchmark started")
        return
    end
    self.currentBenchData[name] = {runs = {}, time = 0}
    local cbd = self.currentBenchData[name]

    for i = 1, self.reps do
        cbd.runs[i] = netGetTime()
        func(...)
        cbd.runs[i] = netGetTime() - cbd.runs[i]
        cbd.time = cbd.time + cbd.runs[i]
    end
end
