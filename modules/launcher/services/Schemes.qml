pragma Singleton

import qs.modules.launcher
import qs.services
import qs.config
import qs.utils
import Quickshell
import Quickshell.Io
import QtQuick

Searcher {
    id: root

    property string currentScheme
    property string currentVariant

    // Path to the schemes data JSON file (bundled with the shell)
    readonly property string schemesDataPath: Qt.resolvedUrl("scheme.json")
    // Path to store current scheme state
    readonly property string schemeStatePath: `${Paths.state}/scheme.json`
    // Path to the Python script for generating dynamic schemes
    readonly property string generateScriptPath: Qt.resolvedUrl("../../../scripts/generate_scheme.py")

    function transformSearch(search: string): string {
        return search.slice(`${Config.launcher.actionPrefix}scheme `.length);
    }

    function selector(item: var): string {
        return `${item.name} ${item.flavour}`;
    }

    function reload(): void {
        schemeStateFile.reload();
    }

    // Regenerate dynamic scheme from current wallpaper
    function regenerateDynamic(): void {
        if (root.currentScheme.startsWith("dynamic")) {
            setScheme("dynamic", "default");
        }
    }

    // Set a scheme by name and flavour
    function setScheme(name: string, flavour: string): void {
        // Handle dynamic scheme generation
        if (name === "dynamic") {
            const wallpaper = Wallpapers.current;
            console.log("Dynamic scheme: wallpaper =", wallpaper);
            if (!wallpaper) {
                console.warn("Cannot set dynamic scheme: no wallpaper set");
                return;
            }
            const mode = Colours.light ? "light" : "dark";
            const variant = root.currentVariant || "tonalspot";
            console.log("Dynamic scheme: variant =", variant, "mode =", mode);

            // Use Python script with materialyoucolor library
            dynamicSchemeGenerator.wallpaper = wallpaper;
            dynamicSchemeGenerator.variant = variant;
            dynamicSchemeGenerator.mode = mode;
            dynamicSchemeGenerator.run();
            return;
        }

        const schemeData = schemesDataFile.json;
        if (!schemeData || !schemeData[name] || !schemeData[name][flavour]) {
            console.warn(`Scheme not found: ${name} ${flavour}`);
            return;
        }

        const colours = schemeData[name][flavour];
        const mode = Colours.light ? "light" : "dark";

        // Save to state file
        const stateData = {
            name: name,
            flavour: flavour,
            mode: mode,
            variant: root.currentVariant || "tonalspot",
            colours: colours
        };

        schemeStateWriter.write(JSON.stringify(stateData, null, 2));
        root.currentScheme = `${name} ${flavour}`;

        // Load the colours immediately
        Colours.load(JSON.stringify(stateData), false);
    }

    list: schemes.instances
    useFuzzy: Config.launcher.useFuzzy.schemes
    keys: ["name", "flavour"]
    weights: [0.9, 0.1]

    Variants {
        id: schemes

        Scheme {}
    }

    // Load schemes from local JSON file
    FileView {
        id: schemesDataFile

        property var json: null

        path: Qt.resolvedUrl("scheme.json")

        onLoaded: {
            try {
                json = JSON.parse(text());
                const list = Object.entries(json).map(([name, f]) => Object.entries(f).map(([flavour, colours]) => ({
                                name,
                                flavour,
                                colours
                            })));

                const flat = [];
                for (const s of list)
                    for (const f of s)
                        flat.push(f);

                // Add dynamic scheme (single entry with default flavour)
                // Variant is selected separately via M3Variants drawer
                flat.push({
                    name: "dynamic",
                    flavour: "default",
                    colours: {}
                });

                schemes.model = flat.sort((a, b) => (a.name + a.flavour).localeCompare((b.name + b.flavour)));
            } catch (e) {
                console.error("Failed to parse schemes data:", e);
            }
        }
    }

    // Load current scheme state from state file
    FileView {
        id: schemeStateFile

        path: root.schemeStatePath
        watchChanges: true

        onLoaded: {
            try {
                const state = JSON.parse(text());
                root.currentScheme = `${state.name} ${state.flavour}`;
                root.currentVariant = state.variant || "tonalspot";
            } catch (e) {
                // State file doesn't exist or is invalid, use defaults
                root.currentScheme = "catppuccin mocha";
                root.currentVariant = "tonalspot";
            }
        }

        onFileChanged: reload()
    }

    // Process for saving scheme state
    Process {
        id: schemeStateWriter

        running: false

        function write(content: string): void {
            // Ensure directory exists
            const escapedJson = content.replace(/'/g, "'\\''");
            schemeStateWriter.command = ["sh", "-c", `mkdir -p '${Paths.state}' && printf '%s' '${escapedJson}' > '${Paths.state}/scheme.json'`];
            schemeStateWriter.running = true;
        }
    }

    // Process for generating dynamic scheme from wallpaper using Python materialyoucolor
    Process {
        id: dynamicSchemeGenerator

        property string wallpaper
        property string variant
        property string mode

        running: false

        function run(): void {
            const scriptPath = generateScriptPath.toString().replace("file://", "");
            command = ["python3", scriptPath, wallpaper, variant, mode];
            console.log("Running dynamic scheme generator:", JSON.stringify(command));
            running = true;
        }

        stdout: SplitParser {
            onRead: data => {
                console.log("Dynamic scheme generator stdout length:", data.length);
                try {
                    const colours = JSON.parse(data);
                    console.log("Parsed colours, keys:", Object.keys(colours).length);
                    const stateData = {
                        name: "dynamic",
                        flavour: "default",
                        mode: dynamicSchemeGenerator.mode,
                        variant: dynamicSchemeGenerator.variant,
                        colours: colours
                    };

                    schemeStateWriter.write(JSON.stringify(stateData, null, 2));
                    root.currentScheme = "dynamic default";
                    Colours.load(JSON.stringify(stateData), false);
                } catch (e) {
                    console.error("Failed to parse dynamic scheme:", e, data);
                }
            }
        }

        stderr: SplitParser {
            onRead: data => console.error("Dynamic scheme generator error:", data)
        }
    }

    component Scheme: QtObject {
        required property var modelData
        readonly property string name: modelData.name
        readonly property string flavour: modelData.flavour
        readonly property var colours: modelData.colours

        function onClicked(list: AppList): void {
            list.visibilities.launcher = false;
            root.setScheme(name, flavour);
        }
    }
}
