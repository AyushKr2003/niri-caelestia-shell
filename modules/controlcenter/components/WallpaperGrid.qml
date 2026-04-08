pragma ComponentBehavior: Bound

import ".."
import qs.components
import qs.components.controls
import qs.components.effects
import qs.components.images
import qs.services
import qs.config
import QtQuick
import QtQuick.Layouts
import QtQuick.Effects

GridView {
    id: root

    required property Session session
    
    Layout.fillWidth: true
    Layout.fillHeight: true
    Layout.minimumHeight: 400
    
    implicitHeight: Math.max(400, contentHeight)
    interactive: false
    height: contentHeight

    readonly property int minCellWidth: 200 + Appearance.spacing.lg
    readonly property int columnsCount: Math.max(1, Math.floor(width / minCellWidth))

    cellWidth: width / columnsCount
    cellHeight: 140 + Appearance.spacing.lg

    model: Wallpapers.list

    clip: true

    delegate: Item {
        id: rootDelegate
        required property var modelData
        required property int index

        width: root.cellWidth
        height: root.cellHeight

        readonly property bool isCurrent: rootDelegate.modelData && rootDelegate.modelData.path === Wallpapers.actualCurrent
        readonly property bool isVideo: Wallpapers.isPathVideo(rootDelegate.modelData.path)
        readonly property real itemMargin: Appearance.spacing.lg / 2
        readonly property real itemRadius: Appearance.rounding.normal

        StateLayer {
            anchors.fill: parent
            anchors.leftMargin: itemMargin
            anchors.rightMargin: itemMargin
            anchors.topMargin: itemMargin
            anchors.bottomMargin: itemMargin
            radius: itemRadius

            function onClicked(): void {
                Wallpapers.setWallpaper(rootDelegate.modelData.path);
            }
        }

        StyledClippingRect {
            id: image

            anchors.fill: parent
            anchors.leftMargin: itemMargin
            anchors.rightMargin: itemMargin
            anchors.topMargin: itemMargin
            anchors.bottomMargin: itemMargin
            color: Colours.tPalette.m3surfaceContainer
            radius: itemRadius
            antialiasing: true
            layer.enabled: true
            layer.smooth: true

            CachingImage {
                id: cachingImage

                path: Wallpapers.getColorSource(rootDelegate.modelData.path)
                anchors.fill: parent
                fillMode: Image.PreserveAspectCrop
                cache: true
                visible: opacity > 0
                antialiasing: true
                smooth: true
                sourceSize: Qt.size(width, height)

                opacity: status === Image.Ready ? 1 : 0

                Behavior on opacity {
                    NumberAnimation {
                        duration: 1000
                        easing.type: Easing.OutQuad
                    }
                }
            }

            // Play symbol overlay for videos
            MaterialIcon {
                anchors.centerIn: parent
                anchors.horizontalCenterOffset: font.pointSize * 0.1
                text: "play_arrow"
                color: "white"
                font.pointSize: Appearance.font.size.headlineLarge * 2
                visible: rootDelegate.isVideo

                layer.enabled: true
                layer.effect: MultiEffect {
                    shadowEnabled: true
                    shadowColor: Qt.alpha("black", 0.5)
                    blurMax: 12
                }
            }

            // Fallback if CachingImage fails to load
            Image {
                id: fallbackImage

                anchors.fill: parent
                source: fallbackTimer.triggered && cachingImage.status !== Image.Ready ? Wallpapers.getColorSource(rootDelegate.modelData.path) : ""
                asynchronous: true
                fillMode: Image.PreserveAspectCrop
                cache: true
                visible: opacity > 0
                antialiasing: true
                smooth: true
                sourceSize: Qt.size(width, height)

                opacity: status === Image.Ready && cachingImage.status !== Image.Ready ? 1 : 0

                Behavior on opacity {
                    NumberAnimation {
                        duration: 1000
                        easing.type: Easing.OutQuad
                    }
                }
            }

            Timer {
                id: fallbackTimer

                property bool triggered: false
                interval: 800
                running: cachingImage.status === Image.Loading || cachingImage.status === Image.Null
                onTriggered: triggered = true
            }

            // Gradient overlay for filename
            Rectangle {
                id: filenameOverlay

                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom

                implicitHeight: filenameText.implicitHeight + Appearance.padding.md * 1.5
                radius: 0

                gradient: Gradient {
                    GradientStop {
                        position: 0.0
                        color: Qt.rgba(Colours.palette.m3surface.r, Colours.palette.m3surface.g, Colours.palette.m3surface.b, 0)
                    }
                    GradientStop {
                        position: 0.3
                        color: Qt.rgba(Colours.palette.m3surface.r, Colours.palette.m3surface.g, Colours.palette.m3surface.b, 0.7)
                    }
                    GradientStop {
                        position: 0.6
                        color: Qt.rgba(Colours.palette.m3surface.r, Colours.palette.m3surface.g, Colours.palette.m3surface.b, 0.9)
                    }
                    GradientStop {
                        position: 1.0
                        color: Qt.rgba(Colours.palette.m3surface.r, Colours.palette.m3surface.g, Colours.palette.m3surface.b, 0.95)
                    }
                }

                opacity: 0

                Behavior on opacity {
                    NumberAnimation {
                        duration: 1000
                        easing.type: Easing.OutCubic
                    }
                }

                Component.onCompleted: {
                    opacity = 1;
                }
            }
        }

        Rectangle {
            anchors.fill: parent
            anchors.leftMargin: itemMargin
            anchors.rightMargin: itemMargin
            anchors.topMargin: itemMargin
            anchors.bottomMargin: itemMargin
            color: "transparent"
            radius: itemRadius + border.width
            border.width: isCurrent ? 2 : 0
            border.color: Colours.palette.m3primary
            antialiasing: true
            smooth: true

            Behavior on border.width {
                NumberAnimation {
                    duration: 150
                    easing.type: Easing.OutQuad
                }
            }

            MaterialIcon {
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: Appearance.padding.xs

                visible: isCurrent
                text: "check_circle"
                color: Colours.palette.m3primary
                font.pointSize: Appearance.font.size.titleMedium
            }
        }

        StyledText {
            id: filenameText
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.leftMargin: Appearance.padding.md + Appearance.spacing.lg / 2
            anchors.rightMargin: Appearance.padding.md + Appearance.spacing.lg / 2
            anchors.bottomMargin: Appearance.padding.md

            text: rootDelegate.modelData.name
            font.pointSize: Appearance.font.size.bodySmall
            font.weight: 500
            color: isCurrent ? Colours.palette.m3primary : Colours.palette.m3onSurface
            elide: Text.ElideMiddle
            maximumLineCount: 1
            horizontalAlignment: Text.AlignHCenter

            opacity: 0

            Behavior on opacity {
                NumberAnimation {
                    duration: 1000
                    easing.type: Easing.OutCubic
                }
            }

            Component.onCompleted: {
                opacity = 1;
            }
        }
    }
}
