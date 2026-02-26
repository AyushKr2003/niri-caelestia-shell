pragma Singleton

import qs.utils
import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: root

    property alias appearance: adapter.appearance
    property alias general: adapter.general
    property alias background: adapter.background
    property alias bar: adapter.bar
    property alias border: adapter.border
    property alias dashboard: adapter.dashboard
    property alias controlCenter: adapter.controlCenter
    property alias launcher: adapter.launcher
    property alias notifs: adapter.notifs
    property alias osd: adapter.osd
    property alias session: adapter.session
    property alias winfo: adapter.winfo
    property alias lock: adapter.lock
    property alias utilities: adapter.utilities
    property alias services: adapter.services
    property alias paths: adapter.paths

    // Track whether this is the initial load or a reload
    property bool initialLoadComplete: false
    
    // Timer to measure config load time
    property var loadStartTime: null

    property bool recentlySaved: false

    signal configSaved()
    signal configLoaded(int elapsed)
    signal configError(string message)

    function save(): void {
        saveTimer.restart();
        recentlySaved = true;
        recentSaveCooldown.restart();
    }

    Timer {
        id: saveTimer
        interval: 500
        onTriggered: {
            try {
                configFile.watchChanges = false;
                configFile.setText(JSON.stringify(JSON.parse(configFile.text()), null, 2));
                configFile.watchChanges = true;
                root.configSaved();
            } catch (e) {
                configFile.watchChanges = true;
                console.error("Config: Failed to save:", e.message);
                root.configError(e.message);
            }
        }
    }

    Timer {
        id: recentSaveCooldown
        interval: 2000
        onTriggered: root.recentlySaved = false
    }



    FileView {
        id: configFile
        
        path: `${Paths.config}/shell.json`
        watchChanges: true
        
        onFileChanged: {
            root.loadStartTime = Date.now();
            reload();
        }
        
        onLoaded: {
            try {
                // Try to parse JSON to validate it
                JSON.parse(text());
                
                // Calculate load time
                const loadTime = root.loadStartTime ? Date.now() - root.loadStartTime : 0;
                
                // Emit signal for toast handling (avoids circular qs.services import)
                if (root.initialLoadComplete)
                    root.configLoaded(loadTime);
                
                root.initialLoadComplete = true;
                root.loadStartTime = null;
                
            } catch (e) {
                console.error("Config: Failed to parse config:", e.message);
                root.configError(e.message);
            }
        }
        
        onLoadFailed: err => {
            if (err !== FileViewError.FileNotFound) {
                console.error("Config: Failed to read config file:", err);
                root.configError(`Failed to read: ${FileViewError[err] || err}`);
            }
        }

        JsonAdapter {
            id: adapter

            property AppearanceConfig appearance: AppearanceConfig {}
            property GeneralConfig general: GeneralConfig {}
            property BackgroundConfig background: BackgroundConfig {}
            property BarConfig bar: BarConfig {}
            property BorderConfig border: BorderConfig {}
            property DashboardConfig dashboard: DashboardConfig {}
            property ControlCenterConfig controlCenter: ControlCenterConfig {}
            property LauncherConfig launcher: LauncherConfig {}
            property NotifsConfig notifs: NotifsConfig {}
            property OsdConfig osd: OsdConfig {}
            property SessionConfig session: SessionConfig {}
            property WInfoConfig winfo: WInfoConfig {}
            property LockConfig lock: LockConfig {}
            property UtilitiesConfig utilities: UtilitiesConfig {}
            property ServiceConfig services: ServiceConfig {}
            property UserPaths paths: UserPaths {}
        }
    }
}
