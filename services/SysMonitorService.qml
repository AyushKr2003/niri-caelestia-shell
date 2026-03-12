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
    property string cpuModel: SysMonitor.cpu.model || ""
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

    property var gpus: []

    function updateGpuStats() {
        if (typeof SysMonitor !== "undefined" && SysMonitor.gpu) {
            let gpu = SysMonitor.gpu;
            gpus = [{
                vendor: gpu.type || "UNKNOWN",
                name: gpu.name || "Unknown GPU",
                usage: gpu.utilization || 0,
                temperature: gpu.temperature || 0,
                memoryUsed: 0,
                memoryTotal: 0,
                card: ""
            }];
        } else {
            gpus = [];
        }
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

    function formatSystemMemory(kb) {
        if (kb >= 1048576) {
            return (kb / 1048576).toFixed(1) + " GiB";
        } else if (kb >= 1024) {
            return (kb / 1024).toFixed(1) + " MiB";
        } else {
            return kb + " KiB";
        }
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
            cpuModel = data.model || "";
            cpuCores = data.count || 1;
            cpuCount = data.count || 1;
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
    }
}
