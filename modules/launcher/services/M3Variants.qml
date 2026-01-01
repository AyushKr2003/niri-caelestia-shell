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

    // Path to store current scheme state
    readonly property string schemeStatePath: `${Paths.state}/scheme.json`

    function transformSearch(search: string): string {
        return search.slice(`${Config.launcher.actionPrefix}variant `.length);
    }

    // Set the variant and save to state file
    function setVariant(variantName: string): void {
        schemeStateFile.setVariant(variantName);
    }

    // Load current scheme state from state file
    FileView {
        id: schemeStateFile

        path: root.schemeStatePath

        // Helper to update the variant while preserving other state
        function setVariant(variantName: string): void {
            try {
                const currentState = JSON.parse(text());
                currentState.variant = variantName;

                // Save updated state
                const jsonContent = JSON.stringify(currentState, null, 2);
                const escapedJson = jsonContent.replace(/'/g, "'\\''");
                schemeStateWriter.command = ["sh", "-c", `mkdir -p '${Paths.state}' && printf '%s' '${escapedJson}' > '${Paths.state}/scheme.json'`];
                schemeStateWriter.running = true;

                // Update the Schemes service current variant
                Schemes.currentVariant = variantName;
            } catch (e) {
                console.error("Failed to set variant:", e);
            }
        }
    }

    Process {
        id: schemeStateWriter

        running: false
    }

    list: [
        Variant {
            variant: "vibrant"
            icon: "sentiment_very_dissatisfied"
            name: qsTr("Vibrant")
            description: qsTr("A high chroma palette. The primary palette's chroma is at maximum.")
        },
        Variant {
            variant: "tonalspot"
            icon: "android"
            name: qsTr("Tonal Spot")
            description: qsTr("Default for Material theme colours. A pastel palette with a low chroma.")
        },
        Variant {
            variant: "expressive"
            icon: "compare_arrows"
            name: qsTr("Expressive")
            description: qsTr("A medium chroma palette. The primary palette's hue is different from the seed colour, for variety.")
        },
        Variant {
            variant: "fidelity"
            icon: "compare"
            name: qsTr("Fidelity")
            description: qsTr("Matches the seed colour, even if the seed colour is very bright (high chroma).")
        },
        Variant {
            variant: "content"
            icon: "sentiment_calm"
            name: qsTr("Content")
            description: qsTr("Almost identical to fidelity.")
        },
        Variant {
            variant: "fruitsalad"
            icon: "nutrition"
            name: qsTr("Fruit Salad")
            description: qsTr("A playful theme - the seed colour's hue does not appear in the theme.")
        },
        Variant {
            variant: "rainbow"
            icon: "looks"
            name: qsTr("Rainbow")
            description: qsTr("A playful theme - the seed colour's hue does not appear in the theme.")
        },
        Variant {
            variant: "neutral"
            icon: "contrast"
            name: qsTr("Neutral")
            description: qsTr("Close to grayscale, a hint of chroma.")
        },
        Variant {
            variant: "monochrome"
            icon: "filter_b_and_w"
            name: qsTr("Monochrome")
            description: qsTr("All colours are grayscale, no chroma.")
        }
    ]
    useFuzzy: Config.launcher.useFuzzy.variants

    component Variant: QtObject {
        required property string variant
        required property string icon
        required property string name
        required property string description

        function onClicked(list: AppList): void {
            list.visibilities.launcher = false;
            root.setVariant(variant);
        }
    }
}
