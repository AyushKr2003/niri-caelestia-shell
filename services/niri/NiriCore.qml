import QtQuick
import Quickshell
import Quickshell.Io

// Core module - handles IPC, availability, and event stream
Item {
    id: root
    visible: false
    
    property bool niriAvailable: false
    signal niriEvent(var event)
    signal initialized()

    Process {
        id: niriCheck
        command: ["which", "niri"]
        onExited: exitCode => {
            root.niriAvailable = exitCode === 0;
            if (root.niriAvailable) {
                console.log("NiriCore: niri found, starting event stream");
                eventStreamProcess.running = true;
                root.initialized();
            } else {
                console.log("NiriCore: niri not found, features disabled");
            }
        }
    }

    function checkAvailability(): void {
        niriCheck.running = true;
    }

    Process {
        id: eventStreamProcess
        command: ["niri", "msg", "-j", "event-stream"]
        running: false
        stdout: SplitParser {
            onRead: data => {
                try {
                    const event = JSON.parse(data.trim());
                    root.niriEvent(event);
                } catch (e) {
                    console.warn("NiriCore: Failed to parse event:", data, e);
                }
            }
        }
        onExited: exitCode => {
            if (exitCode !== 0 && root.niriAvailable) {
                console.warn("NiriCore: Event stream exited with code", exitCode, ", restarting...");
                eventStreamProcess.running = true;
            }
        }
    }

    function action(actionName: string, args: list<string>): bool {
        if (!niriAvailable) return false;
        let cmd = ["niri", "msg", "action", actionName];
        if (args && args.length > 0) {
            cmd = cmd.concat(args);
        }
        Quickshell.execDetached(cmd);
        return true;
    }
}
