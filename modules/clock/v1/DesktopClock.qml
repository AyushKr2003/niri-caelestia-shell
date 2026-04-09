pragma ComponentBehavior: Bound

import qs.components
import qs.services
import qs.config
import QtQuick
import QtQuick.Layouts
import QtQuick.Effects

Item {
    id: root

    property Item wallpaper
    property real absX
    property real absY

    property real mScale: Config.background.desktopClock.scale
    readonly property bool bgEnabled: Config.background.desktopClock.background.enabled
    readonly property bool blurEnabled: bgEnabled && Config.background.desktopClock.background.blur
    readonly property bool invertColors: Config.background.desktopClock.invertColors
    readonly property bool useLightSet: Colours.light ? !invertColors : invertColors
    readonly property color safePrimary: useLightSet ? Colours.palette.m3primaryContainer : Colours.palette.m3primary
    readonly property color safeSecondary: useLightSet ? Colours.palette.m3secondaryContainer : Colours.palette.m3secondary
    readonly property color safeTertiary: useLightSet ? Colours.palette.m3tertiaryContainer : Colours.palette.m3tertiary

    implicitWidth: layout.implicitWidth + (Appearance.padding.xl * 4 * root.mScale)
    implicitHeight: layout.implicitHeight + (Appearance.padding.xl * 2 * root.mScale)

    Item {
        id: clockContainer

        anchors.fill: parent

        layer.enabled: Config.background.desktopClock.shadow.enabled
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: Colours.palette.m3shadow
            shadowOpacity: Config.background.desktopClock.shadow.opacity
            shadowBlur: Config.background.desktopClock.shadow.blur
        }

        Loader {
            anchors.fill: parent
            active: root.blurEnabled

            sourceComponent: MultiEffect {
                source: ShaderEffectSource {
                    sourceItem: root.wallpaper
                    sourceRect: Qt.rect(root.absX, root.absY, root.width, root.height)
                }
                maskSource: backgroundPlate
                maskEnabled: true
                blurEnabled: true
                blur: 1
                blurMax: 64
                autoPaddingEnabled: false
            }
        }

        StyledRect {
            id: backgroundPlate

            visible: root.bgEnabled
            anchors.fill: parent
            radius: Appearance.rounding.large * root.mScale
            opacity: Config.background.desktopClock.background.opacity
            color: Colours.palette.m3surface

            layer.enabled: root.blurEnabled
        }

        RowLayout {
            id: layout

            anchors.centerIn: parent
            spacing: Appearance.spacing.xl * root.mScale

            RowLayout {
                spacing: Appearance.spacing.sm

                StyledText {
                    text: Time.hourStr
                    font.pointSize: Appearance.font.size.headlineLarge * 3 * root.mScale
                    font.weight: Font.Bold
                    color: root.safePrimary
                }

                StyledText {
                    text: ":"
                    font.pointSize: Appearance.font.size.headlineLarge * 3 * root.mScale
                    color: root.safeTertiary
                    opacity: 0.8
                    Layout.topMargin: -Appearance.padding.xl * 1.5 * root.mScale
                }

                StyledText {
                    text: Time.minuteStr
                    font.pointSize: Appearance.font.size.headlineLarge * 3 * root.mScale
                    font.weight: Font.Bold
                    color: root.safeSecondary
                }

                Loader {
                    Layout.alignment: Qt.AlignTop
                    Layout.topMargin: Appearance.padding.xl * 1.4 * root.mScale

                    active: Config.services.useTwelveHourClock
                    visible: active

                    sourceComponent: StyledText {
                        text: Time.amPmStr
                        font.pointSize: Appearance.font.size.titleMedium * root.mScale
                        color: root.safeSecondary
                    }
                }
            }

            StyledRect {
                Layout.fillHeight: true
                Layout.preferredWidth: 4 * root.mScale
                Layout.topMargin: Appearance.spacing.xl * root.mScale
                Layout.bottomMargin: Appearance.spacing.xl * root.mScale
                radius: Appearance.rounding.full
                color: root.safePrimary
                opacity: 0.8
            }

            ColumnLayout {
                spacing: 0

                StyledText {
                    text: Time.format("MMMM").toUpperCase()
                    font.pointSize: Appearance.font.size.titleMedium * root.mScale
                    font.letterSpacing: 4
                    font.weight: Font.Bold
                    color: root.safeSecondary
                }

                StyledText {
                    text: Time.format("dd")
                    font.pointSize: Appearance.font.size.headlineLarge * root.mScale
                    font.letterSpacing: 2
                    font.weight: Font.Medium
                    color: root.safePrimary
                }

                StyledText {
                    text: Time.format("dddd")
                    font.pointSize: Appearance.font.size.bodyLarge * root.mScale
                    font.letterSpacing: 2
                    color: root.safeSecondary
                }
            }
        }
    }

    Behavior on mScale {
        Anim {
            duration: Appearance.anim.durations.expressiveDefaultSpatial
            easing.bezierCurve: Appearance.anim.curves.expressiveDefaultSpatial
        }
    }

    Behavior on implicitWidth {
        Anim {
            duration: Appearance.anim.durations.small
        }
    }

    MouseArea {
        id: dragArea
        anchors.fill: parent
        cursorShape: containsMouse ? (pressed ? Qt.SizeAllCursor : Qt.OpenHandCursor) : Qt.ArrowCursor
        hoverEnabled: true

        property real lastX: 0
        property real lastY: 0

        onPressed: mouse => {
            lastX = mouse.x
            lastY = mouse.y
        }

        onPositionChanged: mouse => {
            if (pressed) {
                let dx = mouse.x - lastX
                let dy = mouse.y - lastY
                Config.background.desktopClock.xOffset += dx
                Config.background.desktopClock.yOffset += dy
            }
        }

        onWheel: wheel => {
            wheel.accepted = false
        }
    }

    WheelHandler {
        property real sensitivity: 0.1
        onWheel: event => {
            let delta = event.rotation > 0 ? sensitivity : -sensitivity
            Config.background.desktopClock.scale = Math.max(0.4, Math.min(5.0, Config.background.desktopClock.scale + delta))
        }
    }
}
