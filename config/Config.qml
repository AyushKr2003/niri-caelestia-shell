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
    property alias lock: adapter.lock
    property alias utilities: adapter.utilities
    property alias extra: adapter.extra
    property alias services: adapter.services
    property alias paths: adapter.paths

    // Track whether this is the initial load or a reload
    property bool initialLoadComplete: false
    
    // Timer to measure config load time
    property var loadStartTime: null

    property bool recentlySaved: false
    property var _cachedSections: ({})
    property var _dirtySections: new Set()

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
                configFile.setText(JSON.stringify(serializeConfig(), null, 2));
                configFile.watchChanges = true;
                root.configSaved();
            } catch (e) {
                configFile.watchChanges = true;
                console.error("Config: Failed to save:", e.message);
                root.configError(e.message);
            }
        }
    }

    function serializeConfig(): var {
        const sections = {
            appearance: serializeAppearance,
            general: serializeGeneral,
            background: serializeBackground,
            bar: serializeBar,
            border: serializeBorder,
            dashboard: serializeDashboard,
            controlCenter: serializeControlCenter,
            launcher: serializeLauncher,
            notifs: serializeNotifs,
            osd: serializeOsd,
            session: serializeSession,
            lock: serializeLock,
            utilities: serializeUtilities,
            services: serializeServices,
            paths: serializePaths,
            extra: serializeExtra
        };

        const result = {};
        const dirty = _dirtySections;
        const noCache = Object.keys(_cachedSections).length === 0;

        for (const [key, fn] of Object.entries(sections)) {
            if (noCache || dirty.has(key)) {
                _cachedSections[key] = fn();
            }
            result[key] = _cachedSections[key];
        }

        _dirtySections.clear();
        return result;
    }

    function markDirty(section: string): void {
        _dirtySections.add(section);
        save();
    }

    function serializeAppearance(): var {
        return {
            rounding: { scale: 1.0 },
            spacing: { scale: 1.0 },
            padding: { scale: 1.0 },
            font: {
                family: {
                    sans: appearance.font.family.sans,
                    mono: appearance.font.family.mono,
                    material: appearance.font.family.material,
                    clock: appearance.font.family.clock
                },
                size: { scale: 1.0 }
            },
            anim: {
                durations: { scale: 1.0 }
            },
            transparency: {
                enabled: appearance.transparency.enabled,
                reduceTransparency: appearance.transparency.reduceTransparency,
                base: appearance.transparency.base,
                layers: appearance.transparency.layers
            }
        };
    }

    function serializeGeneral(): var {
        return {
            isDistLogo: general.isDistLogo,
            apps: {
                terminal: general.apps.terminal,
                audio: general.apps.audio,
                playback: general.apps.playback,
                explorer: general.apps.explorer
            },
            battery: {
                warnLevels: general.battery.warnLevels,
                criticalLevel: general.battery.criticalLevel,
                enableWarnings: general.battery.enableWarnings
            }
        };
    }

    function serializeBackground(): var {
        return {
            enabled: background.enabled,
            wallpaperEnabled: background.wallpaperEnabled,
            desktopClock: {
                enabled: background.desktopClock.enabled,
                version: background.desktopClock.version,
                scale: background.desktopClock.scale,
                invertColors: background.desktopClock.invertColors,
                background: {
                    enabled: background.desktopClock.background.enabled,
                    opacity: background.desktopClock.background.opacity,
                    blur: background.desktopClock.background.blur
                },
                shadow: {
                    enabled: background.desktopClock.shadow.enabled,
                    opacity: background.desktopClock.shadow.opacity,
                    blur: background.desktopClock.shadow.blur
                }
            },
            visualiser: {
                enabled: background.visualiser.enabled,
                autoHide: background.visualiser.autoHide,
                blur: background.visualiser.blur,
                rounding: background.visualiser.rounding,
                spacing: background.visualiser.spacing
            }
        };
    }

    function serializeBar(): var {
        return {
            persistent: bar.persistent,
            showOnHover: bar.showOnHover,
            dragThreshold: bar.dragThreshold,
            scrollActions: {
                workspaces: bar.scrollActions.workspaces,
                volume: bar.scrollActions.volume,
                brightness: bar.scrollActions.brightness
            },
            workspaces: {
                shown: bar.workspaces.shown,
                activeIndicator: bar.workspaces.activeIndicator,
                occupiedBg: bar.workspaces.occupiedBg,
                showWindows: bar.workspaces.showWindows,
                perMonitorWorkspaces: bar.workspaces.perMonitorWorkspaces,
                windowIconImage: bar.workspaces.windowIconImage,
                windowIconGap: bar.workspaces.windowIconGap,
                windowIconSize: bar.workspaces.windowIconSize,
                groupIconsByApp: bar.workspaces.groupIconsByApp,
                groupingRespectsLayout: bar.workspaces.groupingRespectsLayout,
                focusedWindowBlob: bar.workspaces.focusedWindowBlob,
                windowRighClickContext: bar.workspaces.windowRighClickContext,
                windowContextDefaultExpand: bar.workspaces.windowContextDefaultExpand,
                doubleClickToCenter: bar.workspaces.doubleClickToCenter,
                windowContextWidth: bar.workspaces.windowContextWidth,
                activeTrail: bar.workspaces.activeTrail,
                pagerActive: bar.workspaces.pagerActive,
                label: bar.workspaces.label,
                occupiedLabel: bar.workspaces.occupiedLabel,
                activeLabel: bar.workspaces.activeLabel
            },
            activeWindow: {
                compact: bar.activeWindow.compact,
                inverted: bar.activeWindow.inverted
            },
            tray: {
                background: bar.tray.background,
                compact: bar.tray.compact,
                recolour: bar.tray.recolour
            },
            status: {
                showAudio: bar.status.showAudio,
                showMicrophone: bar.status.showMicrophone,
                showKbLayout: bar.status.showKbLayout,
                showNetwork: bar.status.showNetwork,
                showWifi: bar.status.showWifi,
                showBluetooth: bar.status.showBluetooth,
                showBattery: bar.status.showBattery,
                showLockStatus: bar.status.showLockStatus
            },
            clock: {
                background: bar.clock.background,
                showDate: bar.clock.showDate,
                showIcon: bar.clock.showIcon
            },
            popouts: {
                tray: bar.popouts.tray,
                statusIcons: bar.popouts.statusIcons
            },
            sizes: {
                innerWidth: bar.sizes.innerWidth,
                windowPreviewSize: bar.sizes.windowPreviewSize,
                trayMenuWidth: bar.sizes.trayMenuWidth,
                batteryWidth: bar.sizes.batteryWidth,
                networkWidth: bar.sizes.networkWidth
            },
            entries: bar.entries
        };
    }

    function serializeBorder(): var {
        return {
            thickness: border.thickness,
            rounding: border.rounding
        };
    }

    function serializeDashboard(): var {
        return {
            enabled: dashboard.enabled,
            showOnHover: dashboard.showOnHover,
            useWallpaperAvatar: dashboard.useWallpaperAvatar,
            mediaUpdateInterval: dashboard.mediaUpdateInterval,
            resourceUpdateInterval: dashboard.resourceUpdateInterval,
            dragThreshold: dashboard.dragThreshold,
            updateInterval: dashboard.updateInterval,
            performance: {
                showBattery: dashboard.performance.showBattery,
                showGpu: dashboard.performance.showGpu,
                showCpu: dashboard.performance.showCpu,
                showMemory: dashboard.performance.showMemory,
                showStorage: dashboard.performance.showStorage,
                showNetwork: dashboard.performance.showNetwork
            },
            sizes: {
                tabIndicatorHeight: dashboard.sizes.tabIndicatorHeight,
                tabIndicatorSpacing: dashboard.sizes.tabIndicatorSpacing,
                infoWidth: dashboard.sizes.infoWidth,
                infoIconSize: dashboard.sizes.infoIconSize,
                dateTimeWidth: dashboard.sizes.dateTimeWidth,
                mediaWidth: dashboard.sizes.mediaWidth,
                mediaProgressSweep: dashboard.sizes.mediaProgressSweep,
                mediaProgressThickness: dashboard.sizes.mediaProgressThickness,
                resourceProgessThickness: dashboard.sizes.resourceProgessThickness,
                weatherWidth: dashboard.sizes.weatherWidth,
                mediaCoverArtSize: dashboard.sizes.mediaCoverArtSize,
                mediaVisualiserSize: dashboard.sizes.mediaVisualiserSize,
                resourceSize: dashboard.sizes.resourceSize
            }
        };
    }

    function serializeControlCenter(): var {
        return {
            sizes: {
                heightMult: controlCenter.sizes.heightMult,
                ratio: controlCenter.sizes.ratio
            }
        };
    }

    function serializeLauncher(): var {
        return {
            enabled: launcher.enabled,
            showOnHover: launcher.showOnHover,
            maxShown: launcher.maxShown,
            maxWallpapers: launcher.maxWallpapers,
            specialPrefix: launcher.specialPrefix,
            actionPrefix: launcher.actionPrefix,
            enableDangerousActions: launcher.enableDangerousActions,
            dragThreshold: launcher.dragThreshold,
            vimKeybinds: launcher.vimKeybinds,
            favouriteApps: launcher.favouriteApps,
            hiddenApps: launcher.hiddenApps,
            useFuzzy: {
                apps: launcher.useFuzzy.apps,
                actions: launcher.useFuzzy.actions,
                schemes: launcher.useFuzzy.schemes,
                variants: launcher.useFuzzy.variants,
                wallpapers: launcher.useFuzzy.wallpapers
            },
            sizes: {
                itemWidth: launcher.sizes.itemWidth,
                itemHeight: launcher.sizes.itemHeight,
                wallpaperWidth: launcher.sizes.wallpaperWidth,
                wallpaperHeight: launcher.sizes.wallpaperHeight
            }
        };
    }

    function serializeNotifs(): var {
        return {
            expire: notifs.expire,
            defaultExpireTimeout: notifs.defaultExpireTimeout,
            clearThreshold: notifs.clearThreshold,
            expandThreshold: notifs.expandThreshold,
            actionOnClick: notifs.actionOnClick,
            groupPreviewNum: notifs.groupPreviewNum,
            sizes: {
                width: notifs.sizes.width,
                image: notifs.sizes.image,
                badge: notifs.sizes.badge
            }
        };
    }

    function serializeOsd(): var {
        return {
            enabled: osd.enabled,
            hideDelay: osd.hideDelay,
            enableBrightness: osd.enableBrightness,
            enableMicrophone: osd.enableMicrophone,
            sizes: {
                sliderWidth: osd.sizes.sliderWidth,
                sliderHeight: osd.sizes.sliderHeight
            }
        };
    }

    function serializeSession(): var {
        return {
            enabled: session.enabled,
            dragThreshold: session.dragThreshold,
            vimKeybinds: session.vimKeybinds,
            commands: {
                logout: session.commands.logout,
                shutdown: session.commands.shutdown,
                hibernate: session.commands.hibernate,
                reboot: session.commands.reboot
            },
            sizes: {
                button: session.sizes.button
            }
        };
    }

    function serializeLock(): var {
        return {
            recolourLogo: lock.recolourLogo,
            enableFprint: lock.enableFprint,
            showExtras: lock.showExtras,
            maxFprintTries: lock.maxFprintTries,
            sizes: {
                heightMult: lock.sizes.heightMult,
                ratio: lock.sizes.ratio,
                centerWidth: lock.sizes.centerWidth
            }
        };
    }

    function serializeUtilities(): var {
        return {
            enabled: utilities.enabled,
            maxToasts: utilities.maxToasts,
            sizes: {
                width: utilities.sizes.width,
                toastWidth: utilities.sizes.toastWidth
            },
            toasts: {
                configLoaded: utilities.toasts.configLoaded,
                chargingChanged: utilities.toasts.chargingChanged,
                gameModeChanged: utilities.toasts.gameModeChanged,
                dndChanged: utilities.toasts.dndChanged,
                audioOutputChanged: utilities.toasts.audioOutputChanged,
                audioInputChanged: utilities.toasts.audioInputChanged,
                capsLockChanged: utilities.toasts.capsLockChanged,
                numLockChanged: utilities.toasts.numLockChanged,
                kbLayoutChanged: utilities.toasts.kbLayoutChanged,
                kbLimit: utilities.toasts.kbLimit,
                vpnChanged: utilities.toasts.vpnChanged,
                nowPlaying: utilities.toasts.nowPlaying
            },
            vpn: {
                enabled: utilities.vpn.enabled,
                provider: utilities.vpn.provider
            }
        };
    }

    function serializeServices(): var {
        return {
            weatherLocation: services.weatherLocation,
            useFahrenheit: services.useFahrenheit,
            useTwelveHourClock: services.useTwelveHourClock,
            gpuType: services.gpuType,
            visualiserBars: services.visualiserBars,
            audioIncrement: services.audioIncrement,
            smartScheme: services.smartScheme,
            defaultPlayer: services.defaultPlayer,
            playerAliases: services.playerAliases,
            toasts: {
                configLoaded: services.toasts.configLoaded,
                configError: services.toasts.configError
            }
        };
    }

    function serializePaths(): var {
        return {
            wallpaperDir: paths.wallpaperDir,
            wallpaper: paths.wallpaper,
            sessionGif: paths.sessionGif,
            mediaGif: paths.mediaGif
        };
    }

    function serializeExtra(): var {
        return {
            manga: extra.manga,
            novel: extra.novel
        };
    }

    Timer {
        id: recentSaveCooldown
        interval: 2000
        onTriggered: root.recentlySaved = false
    }

    property int fileNotFoundRetries: 0

    Timer {
        id: reloadDebounce
        interval: 120
        onTriggered: configFile.reload()
    }

    Timer {
        id: fileNotFoundRetry
        interval: 250
        onTriggered: {
            root.loadStartTime = Date.now();
            configFile.reload();
        }
    }

    Process {
        id: configInitializer
        command: ["mkdir", "-p", Paths.config]
        running: false
        
        onExited: (exitCode, exitStatus) => {
            if (exitCode === 0) {
                console.log("Config: Directory created/exists:", Paths.config);
                const defaultConfig = JSON.stringify(root.serializeConfig(), null, 2);
                configFile.watchChanges = false;
                configFile.setText(defaultConfig);
                configFile.watchChanges = true;
                // Since it failed before, we should reload it now.
                configFile.reload();
            } else {
                console.error("Config: Failed to create directory:", Paths.config, "Exit code:", exitCode);
            }
        }
    }

    FileView {
        id: configFile
        
        path: `${Paths.config}/shell.json`
        watchChanges: true
        
        onFileChanged: {
            root.loadStartTime = Date.now();
            reloadDebounce.restart();
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
                root.fileNotFoundRetries = 0;
                
            } catch (e) {
                console.error("Config: Failed to parse config:", e.message);
                root.configError(e.message);
            }
        }
        
        onLoadFailed: err => {
            if (err === FileViewError.FileNotFound) {
                if (root.fileNotFoundRetries < 3) {
                    root.fileNotFoundRetries++;
                    console.log(`Config: Config file missing, retrying (${root.fileNotFoundRetries}/3)...`);
                    fileNotFoundRetry.restart();
                    return;
                }

                root.fileNotFoundRetries = 0;
                console.log("Config: Config file not found after retries, initializing default...");
                configInitializer.running = true;
            } else {
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
            property LockConfig lock: LockConfig {}
            property UtilitiesConfig utilities: UtilitiesConfig {}
            property ExtraConfig extra: ExtraConfig {}
            property ServiceConfig services: ServiceConfig {}
            property UserPaths paths: UserPaths {}
        }
    }
}
