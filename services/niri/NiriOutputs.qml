import QtQuick
import Quickshell
import Quickshell.Io

// Outputs module - handles monitor/output state
Item {
    id: root
    visible: false
    
    required property var core
    
    property var outputs: ({})

    onOutputsChanged: {
        console.log("NiriOutputs: Updated outputs:", Object.keys(outputs));
    }

    Connections {
        target: root.core
        function onInitialized() {
            root.loadInitialData();
        }
        function onNiriEvent(event) {
            if (event.OutputsChanged) {
                root.outputs = event.OutputsChanged;
            }
        }
    }

    function loadInitialData(): void {
        if (!core?.niriAvailable) return;
        initialOutputsQuery.running = true;
    }

    Process {
        id: initialOutputsQuery
        command: ["niri", "msg", "-j", "outputs"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                if (text && text.trim()) {
                    try {
                        root.outputs = JSON.parse(text.trim());
                    } catch (e) {
                        console.warn("NiriOutputs: Failed to parse initial outputs:", e);
                    }
                }
            }
        }
    }
}
