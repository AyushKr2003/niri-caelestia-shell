pragma Singleton
pragma ComponentBehavior: Bound

import qs.components.misc
import qs.services
import Quickshell
import Quickshell.Io
import QtQuick

// Compositor-agnostic brightness service
// Works with Niri, Hyprland, or any Wayland compositor

Singleton {
    id: root

    property list<var> ddcMonitors: []
    readonly property list<Monitor> monitors: variants.instances
    property bool appleDisplayPresent: false

    function getMonitorForScreen(screen: ShellScreen): var {
        return monitors.find(m => m.modelData === screen);
    }

    // Get the currently focused/active monitor name
    // Uses Niri service if available, falls back to first screen
    function getActiveMonitorName(): string {
        // Try Niri service first
        if (typeof Niri !== "undefined" && Niri.niriAvailable && Niri.focusedMonitorName) {
            return Niri.focusedMonitorName;
        }
        // Fallback: return first screen's name
        if (monitors.length > 0) {
            return monitors[0].modelData.name;
        }
        return "";
    }

    function getMonitor(query: string): var {
        if (query === "active") {
            const activeName = getActiveMonitorName();
            if (activeName) {
                return monitors.find(m => m.modelData.name === activeName);
            }
            // Ultimate fallback: first monitor
            return monitors.length > 0 ? monitors[0] : null;
        }

        if (query.startsWith("model:")) {
            const model = query.slice(6);
            return monitors.find(m => m.modelData.model === model);
        }

        if (query.startsWith("serial:")) {
            const serial = query.slice(7);
            return monitors.find(m => m.modelData.serialNumber === serial);
        }

        if (query.startsWith("name:")) {
            const name = query.slice(5);
            return monitors.find(m => m.modelData.name === name);
        }

        // Direct name match
        return monitors.find(m => m.modelData.name === query);
    }

    function increaseBrightness(): void {
        const monitor = getMonitor("active");
        if (monitor)
            monitor.setBrightness(monitor.brightness + 0.1);
    }

    function decreaseBrightness(): void {
        const monitor = getMonitor("active");
        if (monitor)
            monitor.setBrightness(monitor.brightness - 0.1);
    }

    onMonitorsChanged: {
        ddcMonitors = [];
        ddcProc.running = true;
    }

    Variants {
        id: variants

        model: Quickshell.screens

        Monitor {}
    }

    Process {
        running: true
        command: ["sh", "-c", "asdbctl get"] // To avoid warnings if asdbctl is not installed
        stdout: StdioCollector {
            onStreamFinished: root.appleDisplayPresent = text.trim().length > 0
        }
        onExited: (exitCode) => {
            if (exitCode !== 0) {
                root.appleDisplayPresent = false;
            }
        }
    }

    Process {
        id: ddcProc

        command: ["ddcutil", "detect", "--brief"]
        stdout: StdioCollector {
            onStreamFinished: root.ddcMonitors = text.trim().split("\n\n").filter(d => d.startsWith("Display ")).map(d => ({
                        busNum: d.match(/I2C bus:[ ]*\/dev\/i2c-([0-9]+)/)?.[1] ?? "",
                        connector: d.match(/DRM connector:\s+(.*)/)?.[1]?.replace(/^card\d+-/, "") ?? "" // strip "card1-"
                    })).filter(d => d.busNum && d.connector)
        }
        onExited: (exitCode) => {
            if (exitCode !== 0) {
                console.log("Brightness: ddcutil detect exited with code", exitCode, "(DDC monitors unavailable)");
            }
        }
    }

    // CustomShortcut {
    //     name: "brightnessUp"
    //     description: "Increase brightness"
    //     onPressed: root.increaseBrightness()
    // }
    //
    // CustomShortcut {
    //     name: "brightnessDown"
    //     description: "Decrease brightness"
    //     onPressed: root.decreaseBrightness()
    // }

    IpcHandler {
        target: "brightness"

        function get(): real {
            return getFor("active");
        }

        // Allows searching by active/model/serial/id/name
        function getFor(query: string): real {
            return root.getMonitor(query)?.brightness ?? -1;
        }

        function set(value: string): string {
            return setFor("active", value);
        }

        // Handles brightness value like brightnessctl: 0.1, +0.1, 0.1-, 10%, +10%, 10%-
        function setFor(query: string, value: string): string {
            const monitor = root.getMonitor(query);
            if (!monitor)
                return "Invalid monitor: " + query;

            let targetBrightness;
            if (value.endsWith("%-")) {
                const percent = parseFloat(value.slice(0, -2));
                targetBrightness = monitor.brightness - (percent / 100);
            } else if (value.startsWith("+") && value.endsWith("%")) {
                const percent = parseFloat(value.slice(1, -1));
                targetBrightness = monitor.brightness + (percent / 100);
            } else if (value.endsWith("%")) {
                const percent = parseFloat(value.slice(0, -1));
                targetBrightness = percent / 100;
            } else if (value.startsWith("+")) {
                const increment = parseFloat(value.slice(1));
                targetBrightness = monitor.brightness + increment;
            } else if (value.endsWith("-")) {
                const decrement = parseFloat(value.slice(0, -1));
                targetBrightness = monitor.brightness - decrement;
            } else if (value.includes("%") || value.includes("-") || value.includes("+")) {
                return `Invalid brightness format: ${value}\nExpected: 0.1, +0.1, 0.1-, 10%, +10%, 10%-`;
            } else {
                targetBrightness = parseFloat(value);
            }

            if (isNaN(targetBrightness))
                return `Failed to parse value: ${value}\nExpected: 0.1, +0.1, 0.1-, 10%, +10%, 10%-`;

            monitor.setBrightness(targetBrightness);

            return `Set monitor ${monitor.modelData.name} brightness to ${+monitor.brightness.toFixed(2)}`;
        }
    }

    component Monitor: QtObject {
        id: monitor

        required property ShellScreen modelData
        readonly property bool isDdc: root.ddcMonitors.some(m => m.connector === modelData.name)
        readonly property string busNum: root.ddcMonitors.find(m => m.connector === modelData.name)?.busNum ?? ""
        readonly property bool isAppleDisplay: root.appleDisplayPresent && modelData.model.startsWith("StudioDisplay")
        property real brightness
        property real queuedBrightness: NaN

        readonly property Process initProc: Process {
            stdout: StdioCollector {
                onStreamFinished: {
                    try {
                        if (monitor.isAppleDisplay) {
                            const val = parseInt(text.trim());
                            monitor.brightness = isNaN(val) ? 0.5 : val / 101;
                        } else {
                            const parts = text.split(" ");
                            if (parts.length >= 5) {
                                const cur = parseInt(parts[3]);
                                const max = parseInt(parts[4]);
                                monitor.brightness = (isNaN(cur) || isNaN(max) || max === 0) ? 0.5 : cur / max;
                            } else {
                                monitor.brightness = 0.5;
                            }
                        }
                    } catch (e) {
                        console.warn("Brightness: Failed to parse brightness value:", e);
                        monitor.brightness = 0.5;
                    }
                }
            }
            onExited: (exitCode) => {
                if (exitCode !== 0) {
                    console.log("Brightness: Failed to get brightness for", monitor.modelData?.name ?? "unknown");
                    monitor.brightness = 0.5; // Default fallback
                }
            }
        }

        readonly property Timer timer: Timer {
            interval: 500
            onTriggered: {
                if (!isNaN(monitor.queuedBrightness)) {
                    monitor.setBrightness(monitor.queuedBrightness);
                    monitor.queuedBrightness = NaN;
                }
            }
        }

        function setBrightness(value: real): void {
            value = Math.max(0, Math.min(1, value));
            const rounded = Math.round(value * 100);
            if (Math.round(brightness * 100) === rounded)
                return;

            if (isDdc && timer.running) {
                queuedBrightness = value;
                return;
            }

            brightness = value;

            if (isAppleDisplay)
                Quickshell.execDetached(["asdbctl", "set", rounded]);
            else if (isDdc)
                Quickshell.execDetached(["ddcutil", "-b", busNum, "setvcp", "10", rounded]);
            else
                Quickshell.execDetached(["brightnessctl", "s", `${rounded}%`]);

            if (isDdc)
                timer.restart();
        }

        function initBrightness(): void {
            if (isAppleDisplay)
                initProc.command = ["asdbctl", "get"];
            else if (isDdc)
                initProc.command = ["ddcutil", "-b", busNum, "getvcp", "10", "--brief"];
            else
                initProc.command = ["sh", "-c", "echo a b c $(brightnessctl g) $(brightnessctl m)"];

            initProc.running = true;
        }

        onBusNumChanged: initBrightness()
        Component.onCompleted: initBrightness()
    }
}
