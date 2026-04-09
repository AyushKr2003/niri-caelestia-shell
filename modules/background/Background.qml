pragma ComponentBehavior: Bound

import qs.components
import qs.components.containers
import qs.services
import qs.config
import Quickshell
import Quickshell.Wayland
import QtQuick

Loader {
    active: Config.background.enabled

    sourceComponent: Variants {
        model: Quickshell.screens

        StyledWindow {
            id: win

            required property var modelData

            screen: modelData
            name: "background"
            WlrLayershell.exclusionMode: ExclusionMode.Ignore
            WlrLayershell.layer: Config.background.wallpaperEnabled ? WlrLayer.Background : WlrLayer.Bottom
            color: Config.background.wallpaperEnabled ? "black" : "transparent"
            surfaceFormat.opaque: false

            anchors.top: true
            anchors.bottom: true
            anchors.left: true
            anchors.right: true

            Item {
                id: behindClock

                readonly property bool isFocusedScreen: win.modelData.name === Niri.focusedMonitorName

                anchors.fill: parent

                Loader {
                    id: wallpaperLoader

                    anchors.fill: parent
                    active: Config.background.wallpaperEnabled

                    sourceComponent: Wallpaper {}
                }

                Loader {
                    anchors.fill: parent
                    active: behindClock.isFocusedScreen

                    sourceComponent: Visualiser {
                        anchors.fill: parent
                        screen: win.modelData
                        wallpaper: wallpaperLoader
                    }
                }
            }

            Loader {
                id: clockLoader
                active: Config.background.desktopClock.enabled && behindClock.isFocusedScreen

                anchors.margins: Appearance.padding.xl * 2
                anchors.leftMargin: Appearance.padding.xl * 2 + Config.bar.sizes.innerWidth + Math.max(Appearance.padding.sm, Config.border.thickness)

                anchors.top: parent.top
                anchors.left: parent.left

                transform: Translate {
                    x: Config.background.desktopClock.xOffset
                    y: Config.background.desktopClock.yOffset
                }

                function updateSource() {
                    setSource(`../clock/${Config.background.desktopClock.version}/DesktopClock.qml`, {
                        wallpaper: behindClock,
                        absX: Qt.binding(() => clockLoader.x),
                        absY: Qt.binding(() => clockLoader.y)
                    });
                }

                onActiveChanged: if (active) updateSource()
                Component.onCompleted: if (active) updateSource()

                Connections {
                    target: Config.background.desktopClock
                    function onVersionChanged() { if (clockLoader.active) clockLoader.updateSource(); }
                }
            }
        }
    }
}
