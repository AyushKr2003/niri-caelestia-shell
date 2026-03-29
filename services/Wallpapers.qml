pragma Singleton

import qs.config
import qs.utils
import Caelestia
import Caelestia.Models
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

    property string _pendingWallpaper: ""
    
    signal frameReady(string path)

    function setWallpaper(path: string): void {
        if (isPathVideo(path)) {
            const framePath = getColorSource(path);
            // Check if frame already exists to avoid re-extraction
            if (CUtils.exists(framePath)) {
                console.log("Video frame already exists, applying immediately");
                applyWallpaper(path);
            } else {
                console.log("Extracting frame for video wallpaper:", path);
                _pendingWallpaper = path;
                
                // Use bash to ensure directory exists before ffmpeg runs, with software fallback
                extractFrameProcess.command = [
                    "bash", "-c", 
                    "mkdir -p \"$(dirname \"$2\")\" && (ffmpeg -y -ss 0 -hwaccel auto -loglevel error -i \"$1\" -an -vframes 1 -update 1 \"$2\" || ffmpeg -y -ss 0 -hwaccel none -loglevel error -i \"$1\" -an -vframes 1 -update 1 \"$2\")",
                    "--", path, framePath
                ];
                console.log("Running extraction command:", JSON.stringify(extractFrameProcess.command));
                extractFrameProcess.running = true;
            }
        } else {
            applyWallpaper(path);
        }
    }

    function applyWallpaper(path: string): void {
        actualCurrent = path;
        // Ensure state directory exists, then save
        ensureStateDir.running = true;
        
        // Small delay to ensure filesystem sync before color generation starts
        Qt.callLater(() => {
            runColorGeneration(path);
        });
    }

    // Dedicated process for sequential frame extraction
    Process {
        id: extractFrameProcess

        onExited: (exitCode) => {
            if (exitCode === 0) {
                console.log("Frame extraction successful, applying wallpaper");
                const path = root._pendingWallpaper;
                root.frameReady(path);
                root.applyWallpaper(path);
            } else {
                console.error("Frame extraction failed with code:", exitCode);
                // Fallback: apply anyway, though colors might fail
                root.applyWallpaper(root._pendingWallpaper);
            }
            root._pendingWallpaper = "";
        }

        stderr: SplitParser {
            onRead: data => {
                // Keep stderr for real errors but hide the verbose info
                if (data.includes("Error") || data.includes("failed"))
                    console.warn("Extraction error:", data);
            }
        }
    }

    function isPathVideo(path: string): bool {
        if (!path) return false;
        const p = path.toString().toLowerCase();
        return p.endsWith(".mp4") || p.endsWith(".mkv") || p.endsWith(".webm") ||
               p.endsWith(".mov") || p.endsWith(".avi") || p.endsWith(".m4v");
    }

    function getColorSource(path: string): string {
        if (!isPathVideo(path)) return path;
        const hash = Qt.md5(path.toString());
        return `${Paths.state}/generated/video_frames/${hash}.png`;
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
                matugenProcess.command = ["matugen", "image", imagePath, "--source-color-index", "0"];
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
        if (!actualCurrent && Config.paths.wallpaper) {
            const path = Paths.absolutePath(Config.paths.wallpaper);
            console.log("Loading initial wallpaper from config:", path);
            setWallpaper(path);
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
            if (exitCode !== 0) {
                console.warn("Color generation exited with code:", exitCode);
            }
        }

        stdout: SplitParser {
            onRead: data => {
                if (data.trim() !== "")
                    console.log("Color gen:", data.trim());
            }
        }

        stderr: SplitParser {
            onRead: data => {
                // Suppress successful theme update messages that are sent to stderr
                if (!data.includes("theme updated") && !data.includes("SVG colors"))
                    console.warn("Color gen error:", data);
            }
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
                console.log("Loading initial wallpaper from state:", loadedPath);
                root.setWallpaper(loadedPath);
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
        filter: FileSystemModel.ImagesAndVideos
    }
}
