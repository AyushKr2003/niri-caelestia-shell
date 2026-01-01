import qs.config
import qs.modules.osd as Osd
import qs.modules.notifications as Notifications
import qs.modules.session as Session
import qs.modules.launcher as Launcher
import qs.modules.dashboard as Dashboard
import qs.modules.bar.popouts as BarPopouts
import qs.modules.utilities as Utilities
import qs.modules.clipboard as Clipboard
import qs.modules.quicktoggles as QuickToggles
import qs.modules.keybinds as KeybindsModule
import Quickshell
import QtQuick

Item {
    id: root

    required property ShellScreen screen
    required property PersistentProperties visibilities
    required property Item bar

    readonly property Osd.Wrapper osd: osd
    readonly property Notifications.Wrapper notifications: notifications
    readonly property Session.Wrapper session: session
    readonly property Launcher.Wrapper launcher: launcher
    readonly property Dashboard.Wrapper dashboard: dashboard
    readonly property BarPopouts.Wrapper popouts: popouts
    readonly property Utilities.Wrapper utilities: utilities
    readonly property Clipboard.Wrapper clipboard: clipboard
    readonly property QuickToggles.Wrapper quicktoggles: quicktoggles
    readonly property KeybindsModule.Wrapper keybinds: keybinds

    anchors.fill: parent
    anchors.margins: Config.border.thickness
    anchors.leftMargin: bar.implicitWidth

    Osd.Wrapper {
        id: osd

        clip: root.visibilities.session
        screen: root.screen
        visibilities: root.visibilities

        anchors.verticalCenter: parent.verticalCenter
        anchors.right: parent.right
        anchors.rightMargin: session.width
    }

    Notifications.Wrapper {
        id: notifications

        visibilities: root.visibilities
        panel: root

        anchors.top: parent.top
        anchors.right: parent.right
    }

    Session.Wrapper {
        id: session

        visibilities: root.visibilities

        anchors.verticalCenter: parent.verticalCenter
        anchors.right: parent.right
    }

    Launcher.Wrapper {
        id: launcher

        visibilities: root.visibilities
        panels: root

        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
    }

    Dashboard.Wrapper {
        id: dashboard

        visibilities: root.visibilities

        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
    }

    BarPopouts.Wrapper {
        id: popouts

        screen: root.screen

        x: isDetached ? (root.width - nonAnimWidth) / 2 : 0
        y: {
            if (isDetached)
                return (root.height - nonAnimHeight) / 2;

            const off = currentCenter - Config.border.thickness - nonAnimHeight / 2;
            const diff = root.height - Math.floor(off + nonAnimHeight);
            if (diff < 0)
                return off + diff;
            return Math.max(off, 0);
        }
    }

    Utilities.Wrapper {
        id: utilities

        visibility: root.visibilities.utilities

        anchors.bottom: parent.bottom
        anchors.right: parent.right
    }

    Clipboard.Wrapper {
        id: clipboard

        visibilities: root.visibilities

        anchors.top: parent.top
        anchors.right: parent.right
    }

    QuickToggles.Wrapper {
        id: quicktoggles

        visibilities: root.visibilities

        anchors.bottom: parent.bottom
        anchors.right: parent.right
    }

    KeybindsModule.Wrapper {
        id: keybinds

        visibilities: root.visibilities

        anchors.bottom: parent.bottom
        anchors.right: parent.right
    }
}
