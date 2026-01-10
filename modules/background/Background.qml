pragma ComponentBehavior: Bound

import qs.components
import qs.components.images
import qs.services
import qs.config
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

Variants {
    id: root
    model: Quickshell.screens

    PanelWindow {
        id: bgRoot

        required property var modelData

        // Hide when fullscreen
        property bool hasFullscreenWindow: false
        visible: true

        // Workspaces
        property int firstWorkspaceId: 1
        property int lastWorkspaceId: 10

        readonly property string wallpaperPathallpapers.current || ""
        readonly property bool wallpaperIsGif: wallpaperPath.toLowerCase().endsWith(".gif")

        // Layer props
        screen: modelData
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Bottom
        WlrLayershell.namespace: "quickshell:background"
        anchors { top: true; bottom: true; left: true; right: true }
        color: "transparent"

        // Static wallpaper (non-GIF images)
        Image {
            id: wallpaper
            anchors.fill: parent
            visible: !bgRoot.wallpaperIsGif
            fillMode: Image.PreserveAspectCrop
            source: bgRoot.wallpaperPath
            asynchronous: true
            cache: false
        }

        // Animated GIF wallpaper
        AnimatedImage {
            id: gifWallpaper
            anchors.fill: parent
            visible: bgRoot.wallpaperIsGif
            source: bgRoot.wallpaperPath
            fillMode: Image.PreserveAspectCrop
            playing: visible
            asynchronous: true
        }
    }
}
