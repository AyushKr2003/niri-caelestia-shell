pragma Singleton

import qs.services
import Quickshell

Singleton {
    property var screens: new Map()
    property var bars: new Map()

    function load(screen: ShellScreen, visibilities: var): void {
        screens.set(Niri.focusedMonitorName, visibilities);
    }

    function getForActive(): PersistentProperties {
        const targetName = Niri.focusedMonitorName;
        if (!targetName) return null;
        
        // Iterate through entries safely without brittle string parsing
        for (const [key, value] of Object.entries(screens)) {
            // Extract the monitor name from the key more robustly
            // Keys can be in format: "[object Object]" or actual strings
            let monitorName = key;
            
            // If key contains quotes, extract the content between them
            const firstQuote = key.indexOf('"');
            const lastQuote = key.lastIndexOf('"');
            if (firstQuote !== -1 && lastQuote > firstQuote) {
                monitorName = key.slice(firstQuote + 1, lastQuote);
            }
            
            if (monitorName === targetName) {
                return value;
            }
        }
        return null;
    }
}
