pragma ComponentBehavior: Bound

import qs.services
import qs.config
import qs.components
import QtQuick
import QtQuick.Layouts

import "context"

StyledRect {
    id: root

    // required property ShellScreen screen

    readonly property int activeWsId: Niri.focusedWorkspaceIndex + 1
    readonly property var occupied: Niri.workspaceHasWindows
    readonly property int groupOffset: Math.floor((Niri.focusedWorkspaceIndex) / Config.bar.workspaces.shown) * Config.bar.workspaces.shown

    readonly property int focusedWindowId: Niri.focusedWindow?.id ?? -1

    implicitHeight: layout.implicitHeight + Appearance.padding.small * 2
    implicitWidth: Config.bar.sizes.innerWidth

    color: Colours.tPalette.m3surfaceContainer
    radius: Appearance.rounding.normal

    signal requestWindowPopout

    Connections {
        target: Niri
        function onWsContextTypeChanged() {
            if (Niri.wsContextType === "workspaces") {
                Niri.wsContextAnchor = root;
            }
        }
    }

    Loader {
        active: Config.bar.workspaces.occupiedBg
        asynchronous: true

        anchors.fill: parent
        anchors.margins: Appearance.padding.small

        sourceComponent: OccupiedBg {
            workspaces: workspaces
            occupied: root.occupied
            groupOffset: root.groupOffset
        }
    }

    Loader {
        // Right click on window context menu
        active: Config.bar.workspaces.windowRighClickContext && Niri.wsContextType !== "none"
        asynchronous: true

        anchors.left: parent.left
        anchors.leftMargin: Appearance.padding.small

        z: Niri.wsContextType === "workspaces" ? -10 : 0

        sourceComponent: ContextBg {
            groupOffset: root.groupOffset
            wsOffset: root.y
            anchorWs: Niri.wsContextAnchor
        }
    }

    //TODO, For Niri, workspace context menu on right click.
    // Loader {
    //     active: Config.bar.workspaces.windowRighClickContext && Niri.wsContextType !== "none"
    //     asynchronous: true
    //     z: Niri.wsContextType === "item" ? 10 : 1

    //     anchors.right: parent.right
    //     anchors.rightMargin: -Appearance.padding.small

    //     sourceComponent: ContextIndicator {
    //         groupOffset: root.groupOffset
    //         wsOffset: root.y
    //         anchorWs: Niri.wsContextAnchor
    //     }
    // }

    Loader {
        anchors.left: parent.left
        anchors.right: parent.right
        active: Config.bar.workspaces.activeIndicator
        asynchronous: true

        sourceComponent: ActiveIndicator {
            activeWsId: root.activeWsId
            workspaces: workspaces
            mask: layout
            groupOffset: root.groupOffset
        }
    }

    ColumnLayout {
        id: layout

        z: 1

        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        anchors.leftMargin: Appearance.padding.small
        spacing: Math.floor(Appearance.spacing.small)

        Repeater {
            id: workspaces

            model: Config.bar.workspaces.shown > Niri.getWorkspaceCount() ? Niri.getWorkspaceCount() : Config.bar.workspaces.shown

            Workspace {
                activeWsId: root.activeWsId
                occupied: root.occupied
                groupOffset: root.groupOffset
                focusedWindowId: root.focusedWindowId
                windowPopoutSignal: root
            }
        }
    }

    Loader {
        id: pager
        active: Config.bar.workspaces.pagerActive

        anchors.top: parent.bottom
        anchors.horizontalCenter: parent.horizontalCenter
        z: -1

        sourceComponent: Pager {
            groupOffset: root.groupOffset
        }
    }
}
