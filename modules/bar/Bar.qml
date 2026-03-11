pragma ComponentBehavior: Bound

import qs.services
import qs.config
import "popouts" as BarPopouts
import "components"
import "components/workspaces"
import Quickshell
import QtQuick
import QtQuick.Layouts

ColumnLayout {
    id: root

    required property ShellScreen screen
    required property PersistentProperties visibilities
    required property BarPopouts.Wrapper popouts
    readonly property int vPadding: Appearance.padding.xl

    // Handle Workspace Popouts for Niri

    Connections {
        target: root.popouts
        function onHasCurrentChanged() {
            if (!root.popouts.hasCurrent && root.popouts.currentName === "wsWindow") {
                Niri.wsContextAnchor = null;
            }
        }
    }

    // Handle Popouts Hover

    function checkPopout(y: real): void {
        if (Niri.wsContextType === "workspaces") {
            // Workspace context menu
            const anchor = Niri.wsContextAnchor;
            if (!anchor) {
                popouts.hasCurrent = false;
                return;
            }
            popouts.currentCenter = Qt.binding(() => Math.round(anchor.mapToItem(root, anchor.width, (anchor.height) / 2).y));
            return;
        }

        const ch = childAt(width / 2, y) as WrappedLoader;
        if (!ch?.item) {
            popouts.hasCurrent = false;
            return;
        }

        const id = ch.id;
        const top = ch.y;
        const item = ch.item;
        const itemHeight = item.implicitHeight;

        if (id === "statusIcons") {
            const items = item.items;
            const icon = items.childAt(items.width / 2, mapToItem(items, 0, y).y);
            if (icon) {
                popouts.currentName = icon.name;
                popouts.currentCenter = Qt.binding(() => icon.mapToItem(root, 0, icon.implicitHeight / 2).y);
                popouts.hasCurrent = true;
            }
        } else if (id === "tray") {
            const index = Math.floor(((y - top) / itemHeight) * item.items.count);
            const trayItem = item.items.itemAt(index);
            if (trayItem) {
                popouts.currentName = `traymenu${index}`;
                popouts.currentCenter = Qt.binding(() => trayItem.mapToItem(root, 0, trayItem.implicitHeight / 2).y);
                popouts.hasCurrent = true;
            }
        } else if (id === "activeWindow") {
            popouts.currentName = id.toLowerCase();
            popouts.currentCenter = item.mapToItem(root, 0, itemHeight / 2).y;
            popouts.hasCurrent = true;
        }
    }

    function handleWheel(y: real, angleDelta: point): void {
        const ch = childAt(width / 2, y) as WrappedLoader;
        if (ch?.id === "workspaces" && Config.bar.scrollActions.workspaces) {
            Niri.switchToWorkspaceUpDown(angleDelta.y > 0 ? "up" : "down");
        } else if (Config.bar.scrollActions.volume) {
            if (angleDelta.y > 0)
                Audio.incrementVolume();
            else if (angleDelta.y < 0)
                Audio.decrementVolume();
        }
    }

    spacing: Appearance.spacing.lg

    Repeater {
        id: repeater

        model: Config.bar.entries

        DelegateChooser {
            role: "id"

            DelegateChoice {
                roleValue: "spacer"
                delegate: WrappedLoader {
                    Layout.fillHeight: enabled
                }
            }
            DelegateChoice {
                roleValue: "divider"
                delegate: WrappedLoader {
                    sourceComponent: Rectangle {
                        implicitWidth: Appearance.padding.md
                        implicitHeight: 1
                        color: Colours.palette.m3outlineVariant
                    }
                }
            }
            DelegateChoice {
                roleValue: "logo"
                delegate: WrappedLoader {
                    sourceComponent: OsIcon {
                        MouseArea {
                            anchors.fill: parent
                            acceptedButtons: Qt.RightButton
                            cursorShape: Qt.PointingHandCursor
                            onClicked: mouse => {
                                if (mouse.button === Qt.RightButton) {
                                    Niri.wsContextType = "workspaces";
                                    root.popouts.currentName = "wsWindow";
                                    root.popouts.hasCurrent = true;
                                }
                            }
                        }
                    }
                }
            }
            DelegateChoice {
                roleValue: "workspaces"
                delegate: WrappedLoader {
                    sourceComponent: Workspaces {

                        property var anchorItem: Niri.wsContextAnchor && Niri.wsContextType !== "none" ? Niri.wsContextAnchor : null

                        onRequestWindowPopout: {
                            if (anchorItem && Config.bar.workspaces.windowRighClickContext) {
                                root.popouts.currentName = "wsWindow";
                                root.popouts.currentCenter = Qt.binding(() => Math.round(anchorItem.mapToItem(null, anchorItem.width, (anchorItem.height) / 2).y));
                                root.popouts.hasCurrent = true;
                            }
                        }
                    }
                }
            }
            DelegateChoice {
                roleValue: "activeWindow"
                delegate: WrappedLoader {
                    sourceComponent: ActiveWindow {
                        bar: root
                        monitor: Brightness.getMonitorForScreen(root.screen)
                    }
                }
            }
            DelegateChoice {
                roleValue: "tray"
                delegate: WrappedLoader {
                    sourceComponent: Tray {}
                }
            }
            DelegateChoice {
                roleValue: "clock"
                delegate: WrappedLoader {
                    sourceComponent: Clock {}
                }
            }
            DelegateChoice {
                roleValue: "statusIcons"
                delegate: WrappedLoader {
                    sourceComponent: StatusIcons {}
                }
            }
            DelegateChoice {
                roleValue: "power"
                delegate: WrappedLoader {
                    sourceComponent: Power {
                        visibilities: root.visibilities
                    }
                }
            }
            DelegateChoice {
                roleValue: "idleInhibitor"
                delegate: WrappedLoader {
                    sourceComponent: IdleInhibitor {}
                }
            }
        }
    }

    // Cached first/last enabled items — recomputed once when repeater changes
    property Item firstEnabled: null
    property Item lastEnabled: null

    function updateEnabledCache(): void {
        let first = null;
        let last = null;
        const count = repeater.count;
        for (let i = 0; i < count; i++) {
            const item = repeater.itemAt(i);
            if (item?.enabled) {
                if (!first) first = item;
                last = item;
            }
        }
        firstEnabled = first;
        lastEnabled = last;
    }

    Connections {
        target: repeater
        function onCountChanged() { root.updateEnabledCache(); }
    }

    Component.onCompleted: updateEnabledCache()

    component WrappedLoader: Loader {
        required property bool enabled
        required property string id
        required property int index

        onEnabledChanged: root.updateEnabledCache()

        Layout.alignment: Qt.AlignHCenter

        Layout.topMargin: root.firstEnabled === this ? root.vPadding : 0
        Layout.bottomMargin: root.lastEnabled === this ? root.vPadding : 0

        asynchronous: true
        visible: enabled
        active: enabled
    }
}
