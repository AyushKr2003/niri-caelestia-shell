import qs.components.misc
import qs.modules.controlcenter
import qs.services
import qs.config
import Caelestia
import Quickshell
import Quickshell.Io
import QtQuick

Scope {
    id: root

    property bool launcherInterrupted

    Connections {
        target: Config

        function onConfigSaved(): void {
            if (Config.utilities.toasts.configLoaded)
                Toaster.toast(qsTr("Config saved"), qsTr("Configuration saved successfully"), "rule_settings");
        }

        function onConfigLoaded(elapsed: int): void {
            if (Config.utilities.toasts.configLoaded)
                Toaster.toast(qsTr("Config loaded"), qsTr("Config loaded in %1ms").arg(elapsed), "rule_settings");
        }

        function onConfigError(message: string): void {
            Toaster.toast(qsTr("Config error"), message, "settings_alert", Toast.Error);
        }
    }

    IpcHandler {
        target: "drawers"

        function toggle(drawer: string): void {
            if (drawer === "manga" && !Config.extra.manga) {
                Toaster.toast(qsTr("Manga feature disabled"), qsTr("Enable it in the Control Center settings"), "manga", Toast.Warning)
                return
            }
            if (drawer === "novel" && !Config.extra.novel) {
                Toaster.toast(qsTr("Novel feature disabled"), qsTr("Enable it in the Control Center settings"), "book", Toast.Warning)
                return
            }

            if (list().split("\n").includes(drawer)) {
                const visibilities = Visibilities.getForActive();
                visibilities[drawer] = !visibilities[drawer];
            } else {
                console.warn(`[IPC] Drawer "${drawer}" does not exist`);
            }
        }

        function list(): string {
            const visibilities = Visibilities.getForActive();
            return Object.keys(visibilities).filter(k => typeof visibilities[k] === "boolean").join("\n");
        }
    }

    IpcHandler {
        target: "controlCenter"

        function open(): void {
            WindowFactory.create();
        }
    }

    IpcHandler {
        target: "toaster"

        function info(title: string, message: string, icon: string): void {
            Toaster.toast(title, message, icon, Toast.Info);
        }

        function success(title: string, message: string, icon: string): void {
            Toaster.toast(title, message, icon, Toast.Success);
        }

        function warn(title: string, message: string, icon: string): void {
            Toaster.toast(title, message, icon, Toast.Warning);
        }

        function error(title: string, message: string, icon: string): void {
            Toaster.toast(title, message, icon, Toast.Error);
        }
    }

    IpcHandler {
        target: "clipboard"

        function open(): void {
            const visibilities = Visibilities.getForActive()
            visibilities.clipboardRequested = true
            visibilities.launcher = true
        }

        function close(): void {
            const visibilities = Visibilities.getForActive()
            visibilities.launcher = false
        }

        function toggle(): void {
            const visibilities = Visibilities.getForActive()
            if (visibilities.launcher) {
                visibilities.launcher = false
            } else {
                visibilities.clipboardRequested = true
                visibilities.launcher = true
            }
        }
    }

    IpcHandler {
        target: "mangaReader"
        function toggle(): void {
            if (!Config.extra.manga) {
                Toaster.toast(qsTr("Manga feature disabled"), qsTr("Enable it in the Control Center settings"), "manga", Toast.Warning)
                return
            }
            const visibilities = Visibilities.getForActive()
            visibilities.manga = !visibilities.manga
        }
    }

    IpcHandler {
        target: "novelReader"
        function toggle(): void {
            if (!Config.extra.novel) {
                Toaster.toast(qsTr("Novel feature disabled"), qsTr("Enable it in the Control Center settings"), "book", Toast.Warning)
                return
            }
            const visibilities = Visibilities.getForActive()
            visibilities.novel = !visibilities.novel
        }
    }
}
