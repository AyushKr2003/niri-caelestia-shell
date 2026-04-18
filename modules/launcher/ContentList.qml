pragma ComponentBehavior: Bound

import "items"
import qs.components
import qs.services
import qs.config
import qs.utils
import Quickshell
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id: root

    required property var wrapper
    required property PersistentProperties visibilities
    required property var panels
    required property TextField search
    required property int padding
    required property int rounding

    readonly property bool showWallpapers: search.text.startsWith(`${Config.launcher.actionPrefix}wallpaper `)
    readonly property Item currentList: showWallpapers ? wallpaperList.item : appList.item
    readonly property string activeMode: showWallpapers ? "wallpapers" : (appList.item?.state ?? "apps")

    readonly property bool showClipPreview: activeMode === "clip" && Boolean(currentList?.currentItem?.modelData)

    anchors.horizontalCenter: parent.horizontalCenter
    anchors.bottom: parent.bottom

    clip: true
    state: showWallpapers ? "wallpapers" : "apps"

    states: [
        State {
            name: "apps"

            PropertyChanges {
                root.implicitWidth: Config.launcher.sizes.itemWidth + (showClipPreview ? 300 + Appearance.spacing.lg : 0)
                root.implicitHeight: Math.max(appList.implicitHeight > 0 ? appList.implicitHeight : empty.implicitHeight, showClipPreview ? 400 : 0)
                appList.active: true
            }

            AnchorChanges {
                anchors.left: root.parent.left
                anchors.right: root.parent.right
            }
        },
        State {
            name: "wallpapers"

            PropertyChanges {
                root.implicitWidth: Math.max(Config.launcher.sizes.itemWidth * 1.2, wallpaperList.implicitWidth)
                root.implicitHeight: Config.launcher.sizes.wallpaperHeight
                wallpaperList.active: true
            }
        }
    ]

    Behavior on state {
        SequentialAnimation {
            Anim {
                target: root
                property: "opacity"
                from: 1
                to: 0
                duration: Appearance.anim.durations.small
            }
            PropertyAction {}
            Anim {
                target: root
                property: "opacity"
                from: 0
                to: 1
                duration: Appearance.anim.durations.small
            }
        }
    }

    Row {
        id: mainRow
        anchors.fill: parent
        spacing: Appearance.spacing.lg

        Loader {
            id: appList

            active: false
            asynchronous: true

            height: parent.height
            width: Config.launcher.sizes.itemWidth

            sourceComponent: AppList {
                search: root.search
                visibilities: root.visibilities
            }
        }

        ClipPreview {
            id: clipPreview
            visible: root.showClipPreview
            modelData: root.currentList?.currentItem?.modelData
            list: appList.item
            height: parent.height
            width: 300
        }
    }

    Loader {
        id: wallpaperList

        active: false
        asynchronous: true

        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.horizontalCenter: parent.horizontalCenter

        sourceComponent: WallpaperList {
            search: root.search
            visibilities: root.visibilities
            panels: root.panels
            wrapper: root.wrapper
        }
    }

    Row {
        id: empty

        opacity: root.currentList?.count === 0 ? 1 : 0
        scale: root.currentList?.count === 0 ? 1 : 0.5

        spacing: Appearance.spacing.lg
        padding: Appearance.padding.xl

        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.verticalCenter

        MaterialIcon {
            text: root.state === "wallpapers" ? "wallpaper_slideshow" : "manage_search"
            color: Colours.palette.m3onSurfaceVariant
            font.pointSize: Appearance.font.size.headlineLarge

            anchors.verticalCenter: parent.verticalCenter
        }

        Column {
            anchors.verticalCenter: parent.verticalCenter

            StyledText {
                text: root.state === "wallpapers" ? qsTr("No wallpapers found") : qsTr("No results")
                color: Colours.palette.m3onSurfaceVariant
                font.pointSize: Appearance.font.size.bodyLarge
                font.weight: 500
            }

            StyledText {
                text: root.state === "wallpapers" && Wallpapers.list.length === 0 ? qsTr("Try putting some wallpapers in %1").arg(Paths.shortenHome(Paths.wallsdir)) : qsTr("Try searching for something else")
                color: Colours.palette.m3onSurfaceVariant
                font.pointSize: Appearance.font.size.bodyMedium
            }
        }

        Behavior on opacity {
            Anim {}
        }

        Behavior on scale {
            Anim {}
        }
    }

    Behavior on implicitWidth {
        enabled: root.visibilities.launcher

        Anim {
            duration: Appearance.anim.durations.large
            easing.bezierCurve: Appearance.anim.curves.emphasizedDecel
        }
    }

    Behavior on implicitHeight {
        enabled: root.visibilities.launcher

        Anim {
            duration: Appearance.anim.durations.large
            easing.bezierCurve: Appearance.anim.curves.emphasizedDecel
        }
    }
}
