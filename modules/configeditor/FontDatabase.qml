pragma Singleton

import qs.config
import Quickshell
import Quickshell.Io
import QtQuick

// Font database for the font picker
Singleton {
    id: root

    property var fontList: []
    property bool loaded: false

    Component.onCompleted: loadFonts()

    Process {
        id: fontProcess
        command: ["fc-list", ":", "family"]
        
        stdout: SplitParser {
            onRead: line => {
                // Handle fonts with multiple names (e.g., "DejaVu Sans,DejaVu Sans Light")
                const fontName = line.split(",")[0].trim();
                if (fontName && !root.fontList.includes(fontName)) {
                    root.fontList.push(fontName);
                }
            }
        }

        onExited: (code, status) => {
            // Sort alphabetically and remove duplicates
            root.fontList = Array.from(new Set(root.fontList)).sort((a, b) => 
                a.toLowerCase().localeCompare(b.toLowerCase())
            );
            root.loaded = true;
            console.log(`FontDatabase: Loaded ${root.fontList.length} fonts`);
        }
    }

    function loadFonts(): void {
        fontProcess.running = true;
    }

    function searchFonts(query: string): var {
        if (!query || query.trim() === "") {
            return fontList.slice(0, 30); // Return first 30 when no search
        }
        const lowerQuery = query.toLowerCase();
        return fontList.filter(font => font.toLowerCase().includes(lowerQuery)).slice(0, 30);
    }

    // Common/recommended fonts for shell UI
    readonly property var recommendedFonts: [
        "Rubik",
        "Inter",
        "Roboto",
        "Noto Sans",
        "Source Sans Pro",
        "Ubuntu",
        "Cantarell",
        "Fira Sans",
        "JetBrains Mono",
        "JetBrains Mono Nerd Font",
        "CaskaydiaCove NF",
        "CaskaydiaCove Nerd Font",
        "Fira Code",
        "Source Code Pro",
        "Hack",
        "Material Symbols Rounded",
        "Material Symbols Outlined"
    ]
}
