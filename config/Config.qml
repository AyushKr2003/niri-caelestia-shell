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
            } catch (e) {
                configFile.watchChanges = true;
                console.error("Config: Failed to save:", e.message);
            }
        }
    }

    Timer {
        id: recentSaveCooldown
        interval: 2000
        onTriggered: root.recentlySaved = false
    }

    // Send notification helper
    function sendNotification(title: string, body: string, icon: string, urgency: string): void {
        let args = ["notify-send", "-a", "caelestia-shell"];
        if (urgency) args.push("-u", urgency);
        if (icon) args.push("-i", icon);
        args.push(title, body);
        Quickshell.execDetached(args);
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
                
                // Show notification only on reload (not initial load) and if enabled
                if (root.initialLoadComplete && adapter.services.toasts.configLoaded) {
                    root.sendNotification(
                        "Config reloaded",
                        loadTime > 0 ? `Configuration loaded in ${loadTime}ms` : "Configuration successfully reloaded",
                        "preferences-system",
                        "low"
                    );
                }
                
                root.initialLoadComplete = true;
                root.loadStartTime = null;
                
            } catch (e) {
                console.error("Config: Failed to parse config:", e.message);
                if (adapter.services.toasts.configError) {
                    root.sendNotification(
                        "Config error",
                        `Failed to load config: ${e.message}`,
                        "dialog-error",
                        "critical"
                    );
                }
            }
        }
        
        onLoadFailed: err => {
            if (err !== FileViewError.FileNotFound) {
                console.error("Config: Failed to read config file:", err);
                if (adapter.services.toasts.configError) {
                    root.sendNotification(
                        "Config error",
                        `Failed to read config file: ${FileViewError[err] || err}`,
                        "dialog-error",
                        "critical"
                    );
                }
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
