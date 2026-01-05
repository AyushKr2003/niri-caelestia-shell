pragma Singleton

import qs.config
import qs.utils
import Caelestia
import Quickshell
import Quickshell.Io
import QtQuick

Searcher {
    id: root

    readonly property string stateDir: `${Paths.state}/wallpaper`
    readonly property string currentNamePath: `${stateDir}/path.txt`

    property bool showPreview: false
    readonly property string current: showPreview ? previewPath : actualCurrent
    property string previewPath
    property string actualCurrent
    property bool previewColourLock
    property bool initialized: false

    function setWallpaper(path: string): void {
        actualCurrent = path;
        // Save to state file directly
        saveWallpaperPath.running = true;
        // Run color generation from wallpaper
        runColorGeneration(path);
    }

    function runColorGeneration(imagePath: string): void {
        if (!imagePath) return;
        try {
            // Use switchwall.sh for full color generation (matugen + terminal + GTK/KDE)
            const scriptPath = Qt.resolvedUrl("../scripts/colors/switchwall.sh").toString().replace("file://", "");
            const mode = Colours.light ? "light" : "dark";
            colorGenProcess.command = ["bash", scriptPath, "--mode", mode, imagePath];
            colorGenProcess.running = true;
        } catch (e) {
            console.warn("Failed to run color generation:", e);
            // Fallback to just matugen
            try {
                matugenProcess.command = ["matugen", "image", imagePath];
                matugenProcess.running = true;
            } catch (e2) {
                console.warn("Failed to run matugen:", e2);
            }
        }
    }

    function preview(path: string): void {
        previewPath = path;
        showPreview = true;
    }

    function stopPreview(): void {
        showPreview = false;
        if (!previewColourLock)
            Colours.showPreview = false;
    }

    function loadFromConfig(): void {
        console.log("loadFromConfig called");
        console.log("Config.paths.wallpaper:", Config.paths.wallpaper);
        console.log("actualCurrent before:", actualCurrent);
        if (!actualCurrent && Config.paths.wallpaper) {
            actualCurrent = Paths.absolutePath(Config.paths.wallpaper);
            console.log("actualCurrent after:", actualCurrent);
        }
    }

    list: wallpapers.entries
    useFuzzy: Config.launcher.useFuzzy.wallpapers
    extraOpts: useFuzzy ? ({}) : ({
            forward: false
        })

    // Delayed load to ensure config is ready
    Timer {
        interval: 100
        running: true
        onTriggered: root.loadFromConfig()
    }

    IpcHandler {
        target: "wallpaper"

        function get(): string {
            return root.actualCurrent;
        }

        function set(path: string): void {
            root.setWallpaper(path);
        }

        function list(): string {
            return root.list.map(w => w.path).join("\n");
        }
    }

    // Create state directory and save wallpaper path
    Process {
        id: saveWallpaperPath

        command: ["sh", "-c", `mkdir -p '${root.stateDir}' && printf '%s' '${root.actualCurrent}' > '${root.currentNamePath}'`]
    }

    // Run matugen for color generation
    Process {
        id: matugenProcess

        onExited: (exitCode, exitStatus) => {
            if (exitCode === 0) {
                console.log("Matugen completed successfully");
            } else {
                console.warn("Matugen exited with code:", exitCode);
            }
        }

        stderr: SplitParser {
            onRead: data => console.warn("Matugen error:", data)
        }
    }

    // Run full color generation (switchwall.sh)
    Process {
        id: colorGenProcess

        onExited: (exitCode, exitStatus) => {
            if (exitCode === 0) {
                console.log("Color generation completed successfully");
            } else {
                console.warn("Color generation exited with code:", exitCode);
            }
        }

        stdout: SplitParser {
            onRead: data => console.log("Color gen:", data)
        }

        stderr: SplitParser {
            onRead: data => console.warn("Color gen error:", data)
        }
    }

    FileView {
        id: stateFile
        path: root.currentNamePath
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            const loadedPath = text().trim();
            if (loadedPath) {
                root.actualCurrent = loadedPath;
            } else {
                root.loadFromConfig();
            }
            root.previewColourLock = false;
            root.initialized = true;
        }
    }

    FileSystemModel {
        id: wallpapers

        recursive: true
        path: Paths.wallsdir
        filter: FileSystemModel.Images
    }
}
