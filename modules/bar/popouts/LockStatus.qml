import qs.components
import qs.services
import qs.config
import Quickshell.Io
import QtQuick
import QtQuick.Layouts

// Compositor-agnostic lock status using system LED state
ColumnLayout {
    id: root

    spacing: Appearance.spacing.small

    property bool capsLockOn: false
    property bool numLockOn: false

    // Poll for LED state changes
    Timer {
        interval: 500
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            capsLockCheck.running = true;
            numLockCheck.running = true;
        }
    }

    // System-level capslock detection via LED sysfs
    Process {
        id: capsLockCheck
        command: ["bash", "-c", "cat /sys/class/leds/*capslock*/brightness 2>/dev/null | grep -q '[1-9]' && echo true || echo false"]
        stdout: StdioCollector {
            onStreamFinished: root.capsLockOn = text.trim() === "true"
        }
    }

    // System-level numlock detection via LED sysfs
    Process {
        id: numLockCheck
        command: ["bash", "-c", "cat /sys/class/leds/*numlock*/brightness 2>/dev/null | grep -q '[1-9]' && echo true || echo false"]
        stdout: StdioCollector {
            onStreamFinished: root.numLockOn = text.trim() === "true"
        }
    }

    StyledText {
        text: qsTr("Capslock: %1").arg(root.capsLockOn ? "Enabled" : "Disabled")
    }

    StyledText {
        text: qsTr("Numlock: %1").arg(root.numLockOn ? "Enabled" : "Disabled")
    }
}
