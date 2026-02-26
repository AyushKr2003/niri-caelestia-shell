import QtQuick
import Quickshell
import Quickshell.Io

// Keyboard module - handles keyboard layout state
Item {
    id: root
    visible: false
    
    required property var core
    
    property var kbLayoutsArray: []
    property int kbLayoutIndex: 0
    property string kbLayouts: "?"
    property string defaultKbLayout: kbLayoutsArray[0] || "?"
    property bool capsLock: false
    property bool numLock: false
    property bool _lockKeysInitialized: false

    // Poll system LED state for caps/num lock
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

    Process {
        id: capsLockCheck
        command: ["bash", "-c", "cat /sys/class/leds/*capslock*/brightness 2>/dev/null | grep -q '[1-9]' && echo true || echo false"]
        stdout: StdioCollector {
            onStreamFinished: root.capsLock = text.trim() === "true"
        }
    }

    Process {
        id: numLockCheck
        command: ["bash", "-c", "cat /sys/class/leds/*numlock*/brightness 2>/dev/null | grep -q '[1-9]' && echo true || echo false"]
        stdout: StdioCollector {
            onStreamFinished: root.numLock = text.trim() === "true"
        }
    }

    Timer {
        interval: 1500
        running: true
        onTriggered: root._lockKeysInitialized = true
    }
    
    readonly property string kbLayout: {
        if (kbLayoutsArray.length > 0 && kbLayoutIndex >= 0 && kbLayoutIndex < kbLayoutsArray.length) {
            return kbLayoutsArray[kbLayoutIndex].slice(0, 2).toLowerCase();
        }
        return "?";
    }

    Connections {
        target: root.core
        function onNiriEvent(event) {
            if (event.KeyboardLayoutsChanged) {
                root.handleKeyboardLayoutsChanged(event.KeyboardLayoutsChanged);
            }
        }
    }

    function handleKeyboardLayoutsChanged(data): void {
        if (data?.keyboard_layouts?.names?.length > 0) {
            kbLayoutsArray = data.keyboard_layouts.names;
            kbLayouts = data.keyboard_layouts.names.join(",");
            const idx = data.keyboard_layouts.current_idx;
            if (idx >= 0 && idx < data.keyboard_layouts.names.length) {
                kbLayoutIndex = idx;
            } else {
                kbLayoutIndex = 0;
            }
        } else {
            kbLayoutsArray = [];
            kbLayouts = "?";
            kbLayoutIndex = 0;
        }
    }
}
