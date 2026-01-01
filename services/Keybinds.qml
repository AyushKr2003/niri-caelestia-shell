pragma Singleton

import qs.utils
import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: root

    readonly property string niriConfig: `${Paths.home}/.config/niri/config.kdl`
    readonly property string scriptsDir: `${Quickshell.shellDir}/modules/keybinds/scripts`
    readonly property string stateDir: `${Paths.state}/keybinds`
    readonly property string cacheFile: `${stateDir}/keybinds.json`

    property var keybinds: []
    property bool loading: false
    property bool initialized: false

    function refresh(): void {
        console.log("Keybinds: Starting refresh");
        loading = true;
        generator.running = true;
    }

    // Create state directory on startup
    Component.onCompleted: {
        createStateDir.running = true;
    }

    Process {
        id: createStateDir
        command: ["sh", "-c", `mkdir -p '${root.stateDir}'`]
        onExited: {
            console.log("Keybinds: State directory created");
            root.refresh();
        }
    }

    // Generate keybinds from niri config
    Process {
        id: generator
        
        command: [
            "sh", "-c",
            `python3 '${root.scriptsDir}/expand.py' | ` +
            `python3 '${root.scriptsDir}/extract_binds.py' | ` +
            `python3 '${root.scriptsDir}/dedupe_binds.py' | ` +
            `python3 '${root.scriptsDir}/pretty_print_binds.py' > '${root.cacheFile}'`
        ]

        onExited: (code, exitStatus) => {
            root.loading = false;
            if (code === 0) {
                console.log("Keybinds: Generation successful");
                cacheFileView.reload();
            } else {
                console.error("Keybinds: Generation failed with code", code);
            }
        }
    }

    // Watch and load the cache file
    FileView {
        id: cacheFileView
        path: root.cacheFile
        watchChanges: true

        onLoaded: {
            try {
                const data = JSON.parse(text());
                root.keybinds = data;
                root.initialized = true;
                console.log(`Keybinds: Loaded ${root.keybinds.length} keybinds`);
            } catch (e) {
                console.error("Keybinds: Failed to parse JSON:", e);
                root.keybinds = [];
            }
        }
    }

    // IPC handler for keybinds management
    IpcHandler {
        target: "keybinds"

        function list(): string {
            return root.keybinds.map(k => `${k.key}: ${k.action}`).join("\n");
        }

        function refresh(): void {
            root.refresh();
        }

        function get(): string {
            return JSON.stringify(root.keybinds);
        }

        function count(): int {
            return root.keybinds.length;
        }
    }
}
