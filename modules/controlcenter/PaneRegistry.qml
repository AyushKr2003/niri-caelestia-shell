pragma Singleton

import QtQuick

QtObject {
    id: root

    readonly property list<QtObject> panes: [
        // --- Connectivity ---
        QtObject {
            readonly property string id: "network"
            readonly property string label: "network"
            readonly property string icon: "router"
            readonly property string component: "network/NetworkingPane.qml"
            readonly property string category: "connectivity"
        },
        QtObject {
            readonly property string id: "bluetooth"
            readonly property string label: "bluetooth"
            readonly property string icon: "settings_bluetooth"
            readonly property string component: "bluetooth/BtPane.qml"
            readonly property string category: "connectivity"
        },
        // --- Sound ---
        QtObject {
            readonly property string id: "audio"
            readonly property string label: "audio"
            readonly property string icon: "volume_up"
            readonly property string component: "audio/AudioPane.qml"
            readonly property string category: "sound"
        },
        // --- Appearance ---
        QtObject {
            readonly property string id: "appearance"
            readonly property string label: "appearance"
            readonly property string icon: "palette"
            readonly property string component: "appearance/AppearancePane.qml"
            readonly property string category: "appearance"
        },
        QtObject {
            readonly property string id: "taskbar"
            readonly property string label: "taskbar"
            readonly property string icon: "task_alt"
            readonly property string component: "taskbar/TaskbarPane.qml"
            readonly property string category: "appearance"
        },
        QtObject {
            readonly property string id: "dashboard"
            readonly property string label: "dashboard"
            readonly property string icon: "dashboard"
            readonly property string component: "dashboard/DashboardPane.qml"
            readonly property string category: "appearance"
        },
        // --- Apps ---
        QtObject {
            readonly property string id: "launcher"
            readonly property string label: "launcher"
            readonly property string icon: "apps"
            readonly property string component: "launcher/LauncherPane.qml"
            readonly property string category: "apps"
        },
        // --- Notifications ---
        QtObject {
            readonly property string id: "notifications"
            readonly property string label: "notifications"
            readonly property string icon: "notifications"
            readonly property string component: "notifications/NotificationsPane.qml"
            readonly property string category: "alerts"
        },
        QtObject {
            readonly property string id: "osd"
            readonly property string label: "OSD"
            readonly property string icon: "tune"
            readonly property string component: "osd/OsdPane.qml"
            readonly property string category: "alerts"
        },
        // --- Security ---
        QtObject {
            readonly property string id: "lock"
            readonly property string label: "lock screen"
            readonly property string icon: "lock"
            readonly property string component: "lock/LockPane.qml"
            readonly property string category: "security"
        },
        QtObject {
            readonly property string id: "session"
            readonly property string label: "session"
            readonly property string icon: "power_settings_new"
            readonly property string component: "session/SessionPane.qml"
            readonly property string category: "security"
        },
        // --- Extra ---
        QtObject {
            readonly property string id: "extra"
            readonly property string label: "extra"
            readonly property string icon: "more_horiz"
            readonly property string component: "extra/ExtraPane.qml"
            readonly property string category: "extra"
        }
    ]

    // Category definitions with display order
    readonly property var categories: [
        { id: "connectivity", label: "Connectivity" },
        { id: "sound", label: "Sound" },
        { id: "appearance", label: "Appearance" },
        { id: "apps", label: "Apps" },
        { id: "alerts", label: "Notifications" },
        { id: "security", label: "System" },
        { id: "extra", label: "Extra" }
    ]

    // Returns the category label for the pane at given index
    function getCategoryForIndex(index: int): string {
        if (index < 0 || index >= panes.length) return "";
        return panes[index].category;
    }

    // Returns whether this index is the first item of its category
    function isFirstInCategory(index: int): bool {
        if (index === 0) return true;
        return panes[index].category !== panes[index - 1].category;
    }

    // Returns the display label for the category of the pane at given index
    function getCategoryLabel(index: int): string {
        const cat = panes[index].category;
        for (let i = 0; i < categories.length; i++) {
            if (categories[i].id === cat) return categories[i].label;
        }
        return "";
    }

    readonly property int count: panes.length

    readonly property var labels: {
        const result = [];
        for (let i = 0; i < panes.length; i++) {
            result.push(panes[i].label);
        }
        return result;
    }

    function getByIndex(index: int): var {
        if (index >= 0 && index < panes.length) {
            return panes[index];
        }
        return panes[0];
    }

    function getIndexByLabel(label: string): int {
        for (let i = 0; i < panes.length; i++) {
            if (panes[i].label === label) {
                return i;
            }
        }
        return -1;
    }

    function getByLabel(label: string): var {
        const index = getIndexByLabel(label);
        return getByIndex(index);
    }

    function getById(id: string): var {
        for (let i = 0; i < panes.length; i++) {
            if (panes[i].id === id) {
                return panes[i];
            }
        }
        return panes[0];
    }
}
