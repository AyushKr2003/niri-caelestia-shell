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
