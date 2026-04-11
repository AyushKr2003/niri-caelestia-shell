pragma Singleton

import qs.config
import Quickshell
import Quickshell.Io
import QtQuick
import Caelestia.Services

Singleton {
    id: root

    // CPU properties
    property string cpuName: cleanCpuName(SysMonitor.cpu.model || "")
    property real cpuPerc
    property real cpuTemp: SysMonitor.cpu.temperature || 0

    // GPU properties
    readonly property string gpuType: Config.services.gpuType.toUpperCase() || SysMonitor.gpu.type || "NONE"
    property string gpuName: cleanGpuName(SysMonitor.gpu.name || "")
    property real gpuPerc: SysMonitor.gpu.utilization || 0
    property real gpuTemp: SysMonitor.gpu.temperature || 0

    // Memory properties
    property real memUsed
    property real memTotal
    readonly property real memPerc: memTotal > 0 ? memUsed / memTotal : 0

    // Storage properties (aggregated)
    readonly property real storagePerc: {
        let totalUsed = 0;
        let totalSize = 0;
        for (const disk of disks) {
            totalUsed += disk.used;
            totalSize += disk.total;
        }
        return totalSize > 0 ? totalUsed / totalSize : 0;
    }

    // Individual disks: Array of { mount, used, total, free, perc }
    property var disks: []

    property real lastCpuIdle
    property real lastCpuTotal

    property int refCount

    function cleanCpuName(name: string): string {
        if (!name) return "";
        let cleaned = name.replace(/\(R\)/gi, "").replace(/\(TM\)/gi, "").replace(/CPU/gi, "").replace(/\d+th Gen /gi, "").replace(/\d+nd Gen /gi, "").replace(/\d+rd Gen /gi, "").replace(/\d+st Gen /gi, "").replace(/Core /gi, "").replace(/Processor/gi, "").replace(/\s+/g, " ").trim();

        if (cleaned.length > 25) {
            cleaned = cleaned.substring(0, 22) + "...";
        }
        return cleaned;
    }

    function cleanGpuName(name: string): string {
        if (!name) return "";
        let cleaned = name.replace(/NVIDIA GeForce /gi, "")
                          .replace(/NVIDIA /gi, "")
                          .replace(/AMD Radeon /gi, "")
                          .replace(/AMD /gi, "")
                          .replace(/Intel\(R\) /gi, "")
                          .replace(/Intel /gi, "")
                          .replace(/\(R\)/gi, "")
                          .replace(/\(TM\)/gi, "")
                          .replace(/Graphics/gi, "")
                          .replace(/ Laptop GPU/gi, "")
                          .replace(/ Mobile/gi, "")
                          .replace(/ Desktop/gi, "")
                          .replace(/\s+/g, " ")
                          .trim();

        if (cleaned.length > 25) {
            cleaned = cleaned.substring(0, 22) + "...";
        }
        return cleaned;
    }

    function formatKib(kib: real): var {
        const mib = 1024;
        const gib = 1024 ** 2;
        const tib = 1024 ** 3;

        if (kib >= tib)
            return {
                value: kib / tib,
                unit: "TiB"
            };
        if (kib >= gib)
            return {
                value: kib / gib,
                unit: "GiB"
            };
        if (kib >= mib)
            return {
                value: kib / mib,
                unit: "MiB"
            };
        return {
            value: kib,
            unit: "KiB"
        };
    }

    Timer {
        running: root.refCount > 0
        interval: Config.dashboard.resourceUpdateInterval
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            SysMonitor.updateAll();
        }
    }
    
    Connections {
        target: SysMonitor
        
        function onCpuChanged() {
            let data = SysMonitor.cpu;
            root.cpuName = root.cleanCpuName(data.model || "");
            root.cpuTemp = data.temperature || 0;
            
            if (data.total && data.total.length >= 8) {
                const totalArray = Array.from(data.total);
                const total = totalArray.reduce((a, b) => a + b, 0);
                const idle = totalArray[3] + (totalArray[4] || 0);

                const totalDiff = total - root.lastCpuTotal;
                const idleDiff = idle - root.lastCpuIdle;
                root.cpuPerc = totalDiff > 0 ? (1 - idleDiff / totalDiff) : 0;

                root.lastCpuTotal = total;
                root.lastCpuIdle = idle;
            }
        }
        
        function onMemoryChanged() {
            let m = SysMonitor.memory;
            root.memTotal = m.total || 1;
            const free = m.free || 0;
            const buf = m.buffers || 0;
            const cached = m.cached || 0;
            root.memUsed = (root.memTotal - (m.available || (free + buf + cached)));
        }
        
        function onDiskmountsChanged() {
            let mounts = SysMonitor.diskmounts;
            let diskList = [];
            for (let mount of mounts) {
                if (mount.fstype !== "tmpfs" && mount.fstype !== "devtmpfs") {
                    // C++ provides size in GB. We format disks in KiB, so GB * 1024 * 1024.
                    diskList.push({
                        mount: mount.device,
                        used: mount.used * 1024 * 1024,
                        total: mount.size * 1024 * 1024,
                        free: mount.avail * 1024 * 1024,
                        perc: mount.percent / 100.0
                    });
                }
            }
            root.disks = diskList;
        }
    }

}
