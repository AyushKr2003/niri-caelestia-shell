pragma ComponentBehavior: Bound

import qs.components
import qs.services
import qs.config
import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland

Variants {
    id: root
    model: Quickshell.screens

    PanelWindow {
        id: backdropWindow
        required property var modelData

        screen: modelData

        WlrLayershell.layer: WlrLayer.Background
        WlrLayershell.namespace: "quickshell:Backdrop"
        WlrLayershell.exclusionMode: ExclusionMode.Ignore

        anchors.top: true
        anchors.bottom: true
        anchors.left: true
        anchors.right: true

        color: "transparent"

        // Aurora backdrop - always enabled
        readonly property int backdropBlurRadius: 80
        readonly property real auroraOverlayOpacity: 0

        Item {
            anchors.fill: parent

            // Aurora-style blurred wallpaper
            Image {
                id: auroraWallpaper
                anchors.fill: parent
                fillMode: Image.PreserveAspectCrop
                source: Wallpapers.current
                asynchronous: true
                cache: true

                layer.enabled: Appearance.effectsEnabled
                layer.effect: MultiEffect {
                    blurEnabled: true
                    blur: backdropWindow.backdropBlurRadius / 100.0
                    blurMax: 64
                }
            }

            // Aurora-style color overlay
            Rectangle {
                anchors.fill: parent
                color: Qt.rgba(
                    Colours.palette.m3surfaceContainer.r,
                    Colours.palette.m3surfaceContainer.g,
                    Colours.palette.m3surfaceContainer.b,
                    backdropWindow.auroraOverlayOpacity
                )
            }
        }
    }
}
