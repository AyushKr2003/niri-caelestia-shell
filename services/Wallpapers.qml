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
