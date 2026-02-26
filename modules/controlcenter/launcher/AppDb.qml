import QtQuick
import Quickshell
import qs.config
import qs.utils

QtObject {
    id: root

    property string path: ""
    property list<string> favouriteApps: []
    property var entries: ({})

    property list<var> apps: []

    function isFavourite(appId: string): bool {
        return favouriteApps.indexOf(appId) !== -1;
    }

    function incrementFrequency(appId: string): void {
        // No-op: frequency tracking requires SQLite (C++ plugin)
    }

    function rebuildApps(): void {
        const entryValues = entries instanceof Array ? entries : Object.values(entries || {});
        const result = [];
        for (let i = 0; i < entryValues.length; i++) {
            const e = entryValues[i];
            result.push({
                entry: e,
                id: e.id,
                name: e.name,
                comment: e.comment || "",
                execString: e.execString || "",
                frequency: 0
            });
        }

        result.sort((a, b) => {
            const aFav = root.isFavourite(a.id);
            const bFav = root.isFavourite(b.id);
            if (aFav !== bFav) return aFav ? -1 : 1;
            return a.name.localeCompare(b.name);
        });

        apps = result;
    }

    onEntriesChanged: rebuildApps()
    onFavouriteAppsChanged: rebuildApps()
    Component.onCompleted: rebuildApps()
}
