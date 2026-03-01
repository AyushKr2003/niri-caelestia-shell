pragma Singleton

import qs.config
import qs.utils
import qs.modules.launcher.services
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
        // Ensure state directory exists, then save
        ensureStateDir.running = true;
        // Run color generation from wallpaper
        runColorGeneration(path);
    }

    // Convert variant name to matugen type
    function variantToMatugenType(variant) {
        const variantMap = {
            "content": "scheme-content",
            "expressive": "scheme-expressive",
            "fidelity": "scheme-fidelity",
            "fruitsalad": "scheme-fruit-salad",
            "monochrome": "scheme-monochrome",
            "neutral": "scheme-neutral",
            "rainbow": "scheme-rainbow",
            "tonalspot": "scheme-tonal-spot",
            "vibrant": "scheme-vibrant"
        };
        return variantMap[variant] || "scheme-tonal-spot";
    }

    function runColorGeneration(imagePath, variant) {
        variant = variant || "";
        if (!imagePath) return;
        try {
            // Use switchwall.sh for full color generation (matugen + terminal + GTK/KDE)
            const scriptPath = Qt.resolvedUrl("../scripts/colors/switchwall.sh").toString().replace("file://", "");
            const mode = Colours.light ? "light" : "dark";
            const schemeType = variantToMatugenType(variant || Schemes.currentVariant || "tonalspot");
            colorGenProcess.command = ["bash", scriptPath, "--mode", mode, "--type", schemeType, imagePath];
            console.log("Running color generation:", JSON.stringify(colorGenProcess.command));
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

    // Create state directory, then write wallpaper path via FileView
    Process {
        id: ensureStateDir

        command: ["mkdir", "-p", root.stateDir]

        onExited: (exitCode, exitStatus) => {
            if (exitCode === 0) {
                stateFile.watchChanges = false;
                stateFile.setText(root.actualCurrent);
                stateFile.watchChanges = true;
            } else {
                console.warn("Wallpapers: Failed to create state directory:", root.stateDir);
            }
        }
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
