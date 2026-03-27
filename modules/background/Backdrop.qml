pragma ComponentBehavior: Bound

import qs.components
import qs.services
import qs.config
import Caelestia
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

        Connections {
            target: Wallpapers
            function onFrameReady(path): void {
                if (path === Wallpapers.current) {
                    console.log("Backdrop: frame ready, force-updating source");
                    const old = bgImage.source;
                    bgImage.source = "";
                    bgImage.source = old;
                }
            }
        }

        // Use the same wallpaper source as the main background
        readonly property string wallpaperSource: {
            const path = Wallpapers.current;
            if (!path) return "";
            
            const source = Wallpapers.getColorSource(path);
            // Ensure file:// prefix for local paths
            if (source.toString().startsWith("/")) return "file://" + source;
            return source;
        }

        Rectangle {
            anchors.fill: parent
            color: "black"
        }

        Rectangle {
            anchors.fill: parent
            color: Colours.palette.m3background
            opacity: Colours.transparency.enabled ? 0.8 : 1
        }

        Image {
            id: bgImage
            anchors.fill: parent
            fillMode: Image.PreserveAspectCrop
            source: {
                const src = backdropWindow.wallpaperSource;
                if (!src) return "";
                // If it's a local file (file://), check if it exists before trying to load
                if (src.startsWith("file://")) {
                    const localPath = src.substring(7);
                    if (!CUtils.exists(localPath)) return "";
                }
                return src;
            }

            // RAM Optimization: Scale down significantly before blurring.
            // Since the image is blurred by 0.8 (heavy), we don't need full resolution.
            sourceSize.width: backdropWindow.width / 4
            sourceSize.height: backdropWindow.height / 4

            asynchronous: true
            cache: true
            smooth: true

            opacity: status === Image.Ready ? 1 : 0
            Behavior on opacity { Anim {} }

            layer.enabled: status === Image.Ready
            layer.effect: MultiEffect {
                autoPaddingEnabled: false
                blurEnabled: true
                blur: 0.8
                blurMax: 64
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
