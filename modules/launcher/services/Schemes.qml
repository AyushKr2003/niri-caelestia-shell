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

    // Convert snake_case to camelCase
    function snakeToCamel(str: string): string {
        return str.replace(/_([a-z])/g, (match, letter) => letter.toUpperCase());
    }

    // Transform matugen output to expected format
    function transformMatugenOutput(data: var, mode: string): var {
        const colours = {};
        const matugenColors = data.colors;

        for (const [name, values] of Object.entries(matugenColors)) {
            const camelName = snakeToCamel(name);
            // Get the color for the specified mode, strip the # prefix
            const hexColor = values[mode] || values["default"];
            if (hexColor) {
                colours[camelName] = hexColor.replace("#", "");
            }
        }

        // Add palette key colors from palettes if available
        if (data.palettes) {
            const palettes = data.palettes;
            if (palettes.primary) colours["primary_paletteKeyColor"] = (palettes.primary["40"] || "").replace("#", "");
            if (palettes.secondary) colours["secondary_paletteKeyColor"] = (palettes.secondary["40"] || "").replace("#", "");
            if (palettes.tertiary) colours["tertiary_paletteKeyColor"] = (palettes.tertiary["40"] || "").replace("#", "");
            if (palettes.neutral) colours["neutral_paletteKeyColor"] = (palettes.neutral["40"] || "").replace("#", "");
            if (palettes.neutral_variant) colours["neutral_variant_paletteKeyColor"] = (palettes.neutral_variant["40"] || "").replace("#", "");
        }

        // Add success colors (not in matugen)
        if (mode === "light") {
            colours["success"] = "4F6354";
            colours["onSuccess"] = "FFFFFF";
            colours["successContainer"] = "D1E8D5";
            colours["onSuccessContainer"] = "0C1F13";
        } else {
            colours["success"] = "B5CCBA";
            colours["onSuccess"] = "213528";
            colours["successContainer"] = "374B3E";
            colours["onSuccessContainer"] = "D1E9D6";
        }

        return colours;
    }

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

            // Use matugen for color generation from wallpaper
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

    // Process for generating dynamic scheme from wallpaper using matugen
    Process {
        id: dynamicSchemeGenerator

        property string wallpaper
        property string variant
        property string mode
        property string outputBuffer: ""

        running: false

        function run(): void {
            outputBuffer = "";
            // Convert variant name to matugen type (e.g., "tonalspot" -> "scheme-tonal-spot")
            let matugenType = "scheme-tonal-spot";
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
            if (variantMap[variant]) {
                matugenType = variantMap[variant];
            }

            command = ["matugen", "image", wallpaper, "--dry-run", "--json", "hex", "--mode", mode, "--type", matugenType];
            console.log("Running matugen:", JSON.stringify(command));
            running = true;
        }

        stdout: SplitParser {
            onRead: data => {
                // Accumulate output since JSON may span multiple lines
                dynamicSchemeGenerator.outputBuffer += data;
            }
        }

        onExited: (exitCode, exitStatus) => {
            if (exitCode !== 0) {
                console.error("Matugen exited with code:", exitCode);
                return;
            }

            console.log("Matugen output length:", outputBuffer.length);
            try {
                const matugenData = JSON.parse(outputBuffer);
                const colours = root.transformMatugenOutput(matugenData, mode);
                console.log("Transformed colours, keys:", Object.keys(colours).length);

                const stateData = {
                    name: "dynamic",
                    flavour: "default",
                    mode: mode,
                    variant: variant,
                    colours: colours
                };

                schemeStateWriter.write(JSON.stringify(stateData, null, 2));
                root.currentScheme = "dynamic default";
                Colours.load(JSON.stringify(stateData), false);
            } catch (e) {
                console.error("Failed to parse matugen output:", e);
            }
        }

        stderr: SplitParser {
            onRead: data => console.error("Matugen error:", data)
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
