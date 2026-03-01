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

    // CustomShortcut {
    //     name: "controlCenter"
    //     description: "Open control center"
    //     onPressed: WindowFactory.create()
    // }

    // CustomShortcut {
    //     name: "showall"
    //     description: "Toggle launcher, dashboard and osd"
    //     onPressed: {
    //         const v = Visibilities.getForActive();
    //         v.launcher = v.dashboard = v.osd = v.utilities = !(v.launcher || v.dashboard || v.osd || v.utilities);
    //     }
    // }

    // CustomShortcut {
    //     name: "session"
    //     description: "Toggle session menu"
    //     onPressed: {
    //         const visibilities = Visibilities.getForActive();
    //         visibilities.session = !visibilities.session;
    //     }
    // }

    // CustomShortcut {
    //     name: "launcher"
    //     description: "Toggle launcher"
    //     onPressed: root.launcherInterrupted = false
    //     onReleased: {
    //         if (!root.launcherInterrupted) {
    //             const visibilities = Visibilities.getForActive();
    //             visibilities.launcher = !visibilities.launcher;
    //         }
    //         root.launcherInterrupted = false;
    //     }
    // }

    // CustomShortcut {
    //     name: "launcherInterrupt"
    //     description: "Interrupt launcher keybind"
    //     onPressed: root.launcherInterrupted = true
    // }

    IpcHandler {
        target: "drawers"

        function toggle(drawer: string): void {
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
}
