pragma Singleton
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Io
import qs.services
import Caelestia.Services

Singleton {
    id: root
    property int refCount: 0
    property int updateInterval: refCount > 0 ? 2000 : 30000
    property int maxProcesses: 100
    property bool isUpdating: false

    property var processes: []
    property string sortBy: "cpu"
    property bool sortDescending: true

    property real cpuUsage: 0
    property real totalCpuUsage: 0
    property int cpuCores: 1
    property int cpuCount: 1
    property string cpuModel: ""
    property real cpuFrequency: 0
    property real cpuTemperature: 0
    property var perCoreCpuUsage: []
    property var perCoreCpuUsagePrev: []

    property var lastCpuStats: null
    property var lastPerCoreStats: null

    property real memoryUsage: 0
    property real totalMemoryMB: 0
    property real usedMemoryMB: 0
    property real freeMemoryMB: 0
    property real availableMemoryMB: 0
    property int totalMemoryKB: 0
    property int usedMemoryKB: 0
    property int totalSwapKB: 0
    property int usedSwapKB: 0

    property real networkRxRate: 0
    property real networkTxRate: 0
    property var lastNetworkStats: null

    property real diskReadRate: 0
    property real diskWriteRate: 0
    property var lastDiskStats: null
    property var diskMounts: []

    property int historySize: 60
    property var cpuHistory: []
    property var memoryHistory: []
    property var networkHistory: ({
            "rx": [],
            "tx": []
        })
    property var diskHistory: ({
            "read": [],
            "write": []
        })

    property string kernelVersion: ""
    property string distribution: ""
    property string hostname: ""
    property string architecture: ""
    property string loadAverage: ""
    property int processCount: 0
    property int threadCount: 0
    property string bootTime: ""
    property string motherboard: ""
    property string biosVersion: ""

    // GPU Monitoring Properties

    property var gpus: [] // Array of GPU objects: {vendor, name, usage, temperature, memoryUsed, memoryTotal, card, busId}
    property var _gpuDetectCallback: null
    property var _cachedGpuList: null

    property string gpuDetectScript: "
for card in /sys/class/drm/card[0-9]*; do
    [ -d \"$card/device\" ] || continue
    case \"$card\" in
        *-*) continue ;;
    esac
    driver=\$(cat \"$card/device/uevent\" 2>/dev/null | grep ^DRIVER= | cut -d= -f2)
    vendor=\$(cat \"$card/device/vendor\" 2>/dev/null)
    device=\$(cat \"$card/device/device\" 2>/dev/null)
    name=\$(cat \"$card/device/uevent\" 2>/dev/null | grep ^DRIVER= | cut -d= -f2)
    busid=\$(basename \"$card\")
    pciid=\$(basename \$(readlink -f \"$card/device\") 2>/dev/null)
    if [ \"\$driver\" = \"nvidia\" ]; then
        type=\"NVIDIA\"
    elif [ -f \"$card/device/gpu_busy_percent\" ]; then
        type=\"GENERIC\"
    else
        type=\"UNKNOWN\"
    fi
    echo \"\$busid|\$type|\$vendor|\$device|\$name|\$pciid\"
done | awk -F'|' '!seen[\$6]++ {print \$0}'
"

    Process {
        id: gpuDetectProcess
        property var _callback: null
        command: ["sh", "-c", root.gpuDetectScript]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                if (typeof gpuDetectProcess._callback === "function") {
                    gpuDetectProcess._callback(text);
                }
            }
        }
    }

    Process {
        id: nvidiaStatsProcess
        property var _callback: null
        command: []
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                if (typeof nvidiaStatsProcess._callback === "function") {
                    nvidiaStatsProcess._callback(text);
                }
            }
        }
    }

    // Helper: Find first matching file for a glob pattern (for hwmon)
    function findFirstMatchingFile(pattern) {
        try {
            let files = Quickshell.ls(pattern);
            if (files && files.length > 0)
                return files[0];
        } catch (e) {}
        return "";
    }

    function detectGpus(callback) {
        if (_cachedGpuList !== null) {
            callback(_cachedGpuList);
            return;
        }
        gpuDetectProcess._callback = function (output) {
            let lines = output.trim().split("\n");
            let detected = [];
            for (let line of lines) {
                let [card, type, vendor, device, name, pciid] = line.split("|");
                detected.push({
                    card,
                    type,
                    vendor,
                    device,
                    name,
                    pciid
                });
            }
            root._cachedGpuList = detected;
            callback(detected);
        };
        gpuDetectProcess.running = true;
    }

    function invalidateGpuCache() {
        _cachedGpuList = null;
    }

    function updateGpuStats() {
        detectGpus(function (gpuList) {
            let pending = gpuList.length;
            let results = [];
            if (pending === 0) {
                gpus = [];
                return;
            }
            for (let i = 0; i < gpuList.length; i++) {
                let gpu = gpuList[i];
                if (gpu.type === "NVIDIA") {
                    nvidiaStatsProcess._callback = function (text) {
                        let parts = text.trim().split(",");
                        if (parts.length >= 5) {
                            results.push({
                                vendor: "NVIDIA",
                                name: parts[2].trim(),
                                usage: parseFloat(parts[0]),
                                temperature: parseInt(parts[1], 10),
                                memoryUsed: parseInt(parts[3], 10),
                                memoryTotal: parseInt(parts[4], 10),
                                card: gpu.card
                            });
                        } else {
                            results.push({
                                vendor: "NVIDIA",
                                name: "NVIDIA GPU",
                                usage: null,
                                temperature: null,
                                memoryUsed: null,
                                memoryTotal: null,
                                card: gpu.card
                            });
                        }
                        pending--;
                        if (pending === 0) {
                            gpus = results;
                        }
                    };
                    nvidiaStatsProcess.command = ["nvidia-smi", "--query-gpu=utilization.gpu,temperature.gpu,name,memory.used,memory.total", "--format=csv,noheader,nounits", "-i", String(i)];
                    nvidiaStatsProcess.running = true;
                    // } else if ((gpu.type === "GENERIC" || gpu.type === "UNKNOWN") && gpu.vendor && gpu.vendor.replace(/^0x/i, "").toLowerCase() === "8086") {
                    //     // Intel GPU detected, use intel_gpu_top
                    //     console.log("INTEL DETECTED:", JSON.stringify(gpu));
                    //     intelGpuTopProcess._callback = function (text) {
                    //         console.log("[intelGpuTopProcess._callback] called. Text:", text && text.length ? text.slice(0, 200) : "<empty>");
                    //         let parsed = parseIntelGpuTop(text);
                    //         if (parsed.length > 0) {
                    //             parsed[0].card = gpu.card;
                    //             parsed[0].busId = gpu.pciid || null;
                    //             results.push(parsed[0]);
                    //         }
                    //         pending--;
                    //         if (pending === 0) {
                    //             gpus = results;
                    //         }
                    //     };
                    //     console.log("Starting intel_gpu_top process...");
                    //     intelGpuTopProcess.running = true;
                    //     intelGpuTopKillTimer.start();
                } else if (gpu.type === "GENERIC") {
                    let usage = null;
                    let temp = null;
                    try {
                        usage = parseInt(Quickshell.readFile("/sys/class/drm/" + gpu.card + "/device/gpu_busy_percent").trim(), 10);
                    } catch (e) {}
                    let hwmonGlob = "/sys/class/drm/" + gpu.card + "/device/hwmon/hwmon*/temp1_input";
                    let tempPath = findFirstMatchingFile(hwmonGlob);
                    try {
                        if (tempPath)
                            temp = parseInt(Quickshell.readFile(tempPath).trim(), 10) / 1000;
                    } catch (e) {}
                    results.push({
                        vendor: "GENERIC",
                        name: gpu.name || "Generic GPU",
                        usage: usage,
                        temperature: temp,
                        memoryUsed: null,
                        memoryTotal: null,
                        card: gpu.card
                    });
                    pending--;
                    if (pending === 0) {
                        gpus = results;
                    }
                } else {
                    results.push({
                        vendor: "UNKNOWN",
                        name: gpu.name || "Unknown GPU",
                        usage: null,
                        temperature: null,
                        memoryUsed: null,
                        memoryTotal: null,
                        card: gpu.card
                    });
                    pending--;
                    if (pending === 0) {
                        gpus = results;
                    }
                }
            }
        });
    }

    // END GPU STUFF

    function addRef() {
        refCount++;
        if (refCount === 1) {
            updateAllStats();
        }
    }

    function removeRef() {
        refCount = Math.max(0, refCount - 1);
    }

    function updateAllStats() {
        if (refCount > 0) {
            isUpdating = true;
            SysMonitor.updateAll();
            updateGpuStats();
            // trigger history pushes
            addToHistory(cpuHistory, cpuUsage);
            addToHistory(memoryHistory, memoryUsage);
            isUpdating = false;
        }
    }

    function setSortBy(newSortBy) {
        if (newSortBy !== sortBy) {
            sortBy = newSortBy;
            SysMonitor.sortBy = newSortBy;
            sortProcessesInPlace();
        }
    }

    function toggleSortOrder() {
        sortDescending = !sortDescending;
        sortProcessesInPlace();
    }

    function sortProcessesInPlace() {
        if (processes.length === 0)
            return;

        const sortedProcesses = [...processes];

        sortedProcesses.sort((a, b) => {
            let aVal, bVal;

            switch (sortBy) {
            case "cpu":
                aVal = parseFloat(a.cpu) || 0;
                bVal = parseFloat(b.cpu) || 0;
                break;
            case "memory":
                aVal = parseFloat(a.memoryPercent) || 0;
                bVal = parseFloat(b.memoryPercent) || 0;
                break;
            case "name":
                aVal = a.command || "";
                bVal = b.command || "";
                break;
            case "pid":
                aVal = parseInt(a.pid) || 0;
                bVal = parseInt(b.pid) || 0;
                break;
            default:
                aVal = parseFloat(a.cpu) || 0;
                bVal = parseFloat(b.cpu) || 0;
            }

            if (typeof aVal === "string") {
                return sortDescending ? bVal.localeCompare(aVal) : aVal.localeCompare(bVal);
            } else {
                return sortDescending ? bVal - aVal : aVal - bVal;
            }
        });

        processes = sortedProcesses;
    }

    function killProcess(pid) {
        if (pid > 0) {
            Quickshell.execDetached("kill", [pid.toString()]);
        }
    }

    function addToHistory(array, value) {
        array.push(value);
        if (array.length > historySize)
            array.shift();
    }

    function calculateCpuUsage(currentStats, lastStats) {
        if (!lastStats || !currentStats || currentStats.length < 4) {
            return 0;
        }

        const currentTotal = currentStats.reduce((sum, val) => sum + val, 0);
        const lastTotal = lastStats.reduce((sum, val) => sum + val, 0);

        const totalDiff = currentTotal - lastTotal;
        if (totalDiff <= 0)
            return 0;

        const currentIdle = currentStats[3];
        const lastIdle = lastStats[3];
        const idleDiff = currentIdle - lastIdle;

        const usedDiff = totalDiff - idleDiff;
        return Math.max(0, Math.min(100, (usedDiff / totalDiff) * 100));
    }

    Connections {
        target: SysMonitor
        
        function onMemoryChanged() {
            let m = SysMonitor.memory;
            totalMemoryKB = m.total || 0;
            const free = m.free || 0;
            const buf = m.buffers || 0;
            const cached = m.cached || 0;
            usedMemoryKB = totalMemoryKB - free - buf - cached;
            totalSwapKB = m.swaptotal || 0;
            usedSwapKB = (m.swaptotal || 0) - (m.swapfree || 0);
            totalMemoryMB = totalMemoryKB / 1024;
            usedMemoryMB = usedMemoryKB / 1024;
            freeMemoryMB = (totalMemoryKB - usedMemoryKB) / 1024;
            availableMemoryMB = m.available ? m.available / 1024 : (free + buf + cached) / 1024;
            memoryUsage = totalMemoryKB > 0 ? (usedMemoryKB / totalMemoryKB) * 100 : 0;
        }
        
        function onCpuChanged() {
            let data = SysMonitor.cpu;
            cpuCores = data.count || 1;
            cpuCount = data.count || 1;
            cpuModel = data.model || "";
            cpuFrequency = data.frequency || 0;
            cpuTemperature = data.temperature || 0;

            if (data.total && data.total.length >= 8) {
                // Ensure data.total and lastCpuStats are arrays
                const usage = calculateCpuUsage(Array.from(data.total), lastCpuStats ? Array.from(lastCpuStats) : null);
                cpuUsage = usage;
                totalCpuUsage = usage;
                lastCpuStats = Array.from(data.total);
            }

            if (data.cores) {
                const coreUsages = [];
                for (let i = 0; i < data.cores.length; i++) {
                    const currentCoreStats = data.cores[i];
                    if (currentCoreStats && currentCoreStats.length >= 8) {
                        let lastCoreStats = lastPerCoreStats && lastPerCoreStats[i] ? lastPerCoreStats[i] : null;
                        coreUsages.push(calculateCpuUsage(Array.from(currentCoreStats), lastCoreStats ? Array.from(lastCoreStats) : null));
                    }
                }
                if (JSON.stringify(perCoreCpuUsage) !== JSON.stringify(coreUsages)) {
                    perCoreCpuUsagePrev = [...perCoreCpuUsage];
                    perCoreCpuUsage = coreUsages;
                }
                lastPerCoreStats = data.cores.map(core => Array.from(core));
            }
        }
        
        function onNetworkChanged() {
            let n = SysMonitor.network;
            let totalRx = 0, totalTx = 0;
            for(let iface of n) { totalRx += iface.rx; totalTx += iface.tx; }
            if (lastNetworkStats) {
                const timeDiff = updateInterval / 1000;
                networkRxRate = Math.max(0, (totalRx - lastNetworkStats.rx) / timeDiff);
                networkTxRate = Math.max(0, (totalTx - lastNetworkStats.tx) / timeDiff);
                addToHistory(networkHistory.rx, networkRxRate / 1024);
                addToHistory(networkHistory.tx, networkTxRate / 1024);
            }
            lastNetworkStats = { "rx": totalRx, "tx": totalTx };
        }
        
        function onDiskChanged() {
            let n = SysMonitor.disk;
            let totalRead = 0, totalWrite = 0;
            for(let d of n) { totalRead += d.read * 512; totalWrite += d.write * 512; }
            if (lastDiskStats) {
                const timeDiff = updateInterval / 1000;
                diskReadRate = Math.max(0, (totalRead - lastDiskStats.read) / timeDiff);
                diskWriteRate = Math.max(0, (totalWrite - lastDiskStats.write) / timeDiff);
                addToHistory(diskHistory.read, diskReadRate / (1024 * 1024));
                addToHistory(diskHistory.write, diskWriteRate / (1024 * 1024));
            }
            lastDiskStats = { "read": totalRead, "write": totalWrite };
        }
        
        function onProcessesChanged() {
            processes = SysMonitor.processes;
            sortProcessesInPlace();
        }
        
        function onSystemChanged() {
            let s = SysMonitor.system;
            kernelVersion = s.kernel || "";
            distribution = s.distro || "";
            hostname = s.hostname || "";
            architecture = s.arch || "";
            loadAverage = s.loadavg || "";
            processCount = s.processes || 0;
            threadCount = s.threads || 0;
            bootTime = s.boottime || "";
            motherboard = s.motherboard || "";
            biosVersion = s.bios || "";
        }
        
        function onDiskmountsChanged() {
            diskMounts = SysMonitor.diskmounts;
        }
    }

    function debug() {
        SysMonitorService.addRef();
        SysMonitorService.updateAllStats();
        console.log("GPUS:", JSON.stringify(SysMonitorService.gpus));
    }

    // Component.onCompleted: {
    // Qt.callLater(debug)
    // }

}
