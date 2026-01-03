pragma Singleton

import qs.config
import Quickshell
import Quickshell.Services.UPower
import QtQuick

Singleton {
    id: root

    // Track which warning levels have already been triggered to avoid spam
    property var triggeredWarnings: ({})
    property int lastPercentage: 100

    // Reset warnings when charging starts
    readonly property bool isCharging: !UPower.onBattery

    onIsChargingChanged: {
        if (isCharging) {
            // Reset all warnings when plugged in
            triggeredWarnings = {};
            console.log("BatteryMonitor: Charging started, warnings reset");
        }
    }

    // Monitor battery percentage changes
    Connections {
        target: UPower.displayDevice

        function onPercentageChanged(): void {
            if (!UPower.displayDevice.isLaptopBattery) return;
            if (!Config.general.battery.enableWarnings) return;
            if (root.isCharging) return;

            const percentage = Math.round(UPower.displayDevice.percentage * 100);
            
            // Only check when battery is decreasing
            if (percentage >= root.lastPercentage) {
                root.lastPercentage = percentage;
                return;
            }
            root.lastPercentage = percentage;

            // Check each warning level
            const warnLevels = Config.general.battery.warnLevels;
            for (let i = 0; i < warnLevels.length; i++) {
                const warn = warnLevels[i];
                const warningKey = `level_${warn.level}`;
                
                // Skip if already triggered this session
                if (root.triggeredWarnings[warningKey]) continue;
                
                // Trigger if we just crossed this threshold
                if (percentage <= warn.level) {
                    root.triggeredWarnings[warningKey] = true;
                    sendWarningNotification(warn);
                }
            }

            // Check critical level for system action
            const criticalLevel = Config.general.battery.criticalLevel;
            if (percentage <= criticalLevel && !root.triggeredWarnings["critical_action"]) {
                root.triggeredWarnings["critical_action"] = true;
                handleCriticalBattery();
            }
        }
    }

    function sendWarningNotification(warn: var): void {
        const urgency = warn.critical ? "critical" : "normal";
        const icon = warn.icon || "battery_alert";
        
        console.log(`BatteryMonitor: Sending warning - ${warn.title} at ${warn.level}%`);
        
        const args = [
            "notify-send",
            "-a", "caelestia-shell",
            "-u", urgency,
            "-i", icon,
            warn.title,
            warn.message
        ];
        
        Quickshell.execDetached(args);
    }

    function handleCriticalBattery(): void {
        console.log("BatteryMonitor: Critical battery level reached!");
        
        // Send critical notification
        Quickshell.execDetached([
            "notify-send",
            "-a", "caelestia-shell",
            "-u", "critical",
            "-i", "battery_alert",
            "CRITICAL BATTERY",
            "System will suspend in 30 seconds unless plugged in!"
        ]);

        // Optional: trigger suspend after delay
        // Uncomment the following if you want auto-suspend:
        // suspendTimer.start();
    }

    // Optional timer for auto-suspend on critical battery
    Timer {
        id: suspendTimer
        interval: 30000 // 30 seconds
        onTriggered: {
            if (!root.isCharging && Math.round(UPower.displayDevice.percentage * 100) <= Config.general.battery.criticalLevel) {
                console.log("BatteryMonitor: Auto-suspending due to critical battery");
                Quickshell.execDetached(["systemctl", "suspend"]);
            }
        }
    }

    Component.onCompleted: {
        if (UPower.displayDevice.isLaptopBattery) {
            lastPercentage = Math.round(UPower.displayDevice.percentage * 100);
            console.log(`BatteryMonitor: Initialized with ${lastPercentage}% battery, ${Config.general.battery.warnLevels.length} warning levels configured`);
        } else {
            console.log("BatteryMonitor: No laptop battery detected");
        }
    }
}
