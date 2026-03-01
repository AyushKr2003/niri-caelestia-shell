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

        // Use the same wallpaper source as the main background
        readonly property string wallpaperSource: {
            const path = Wallpapers.current;
            if (!path) return "";
            // Ensure file:// prefix for local paths
            if (path.startsWith("/")) return "file://" + path;
            return path;
        }

        Item {
            id: blurContainer
            anchors.fill: parent

            layer.enabled: bgImage.status === Image.Ready
            layer.effect: MultiEffect {
                blurEnabled: true
                blur: 0.8
                blurMax: 64
            }

            Image {
                id: bgImage
                anchors.fill: parent
                fillMode: Image.PreserveAspectCrop
                source: backdropWindow.wallpaperSource
                asynchronous: true
                cache: true
                smooth: true
                sourceSize.width: backdropWindow.screen?.width ?? 1920
                sourceSize.height: backdropWindow.screen?.height ?? 1080

                onStatusChanged: {
                    console.log("Backdrop image status:", status, "source:", source.toString().slice(-40))
                }
            }
        }

        // Tint overlay (on top of blurred image)
        Rectangle {
            anchors.fill: parent
            color: Colours.palette.m3surface
            opacity: 0.15
        }
    }
}
