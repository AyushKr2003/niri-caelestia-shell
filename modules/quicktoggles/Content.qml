pragma ComponentBehavior: Bound

import qs.components
import qs.components.controls
import qs.components.containers
import qs.components.effects
import qs.services
import qs.config
import qs.utils
import Quickshell
import Quickshell.Widgets
import Quickshell.Services.Notifications
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

Item {
    id: root

    required property var wrapper
    required property PersistentProperties visibilities

    readonly property int padding: Appearance.padding.large

    implicitWidth: 340
    implicitHeight: mainLayout.implicitHeight + padding * 2

    ColumnLayout {
        id: mainLayout
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: root.padding
        spacing: Appearance.spacing.normal

        /* NOTIFICATION HISTORY */
        StyledClippingRect {
            id: notifSection
            Layout.fillWidth: true
            Layout.preferredHeight: 220
            radius: Appearance.rounding.normal
            color: Colours.tPalette.m3surfaceContainer

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: Appearance.padding.normal
                spacing: Appearance.spacing.small

                // Header
                RowLayout {
                    id: notifHeader
                    Layout.fillWidth: true
                    spacing: Appearance.spacing.small

                    MaterialIcon {
                        text: "notifications"
                        font.pointSize: Appearance.font.size.normal
                        color: Colours.palette.m3primary
                    }

                    StyledText {
                        text: Notifs.list.length > 0 
                            ? qsTr("%1 notification%2").arg(Notifs.list.length).arg(Notifs.list.length === 1 ? "" : "s") 
                            : qsTr("Notifications")
                        font.pointSize: Appearance.font.size.smaller
                        font.weight: Font.Medium
                        Layout.fillWidth: true
                    }

                    // Clear all button
                    StyledRect {
                        Layout.preferredWidth: 24
                        Layout.preferredHeight: 24
                        radius: Appearance.rounding.small
                        color: "transparent"
                        visible: Notifs.list.length > 0

                        StateLayer {
                            radius: parent.radius
                            color: Colours.palette.m3error

                            function onClicked(): void {
                                for (const notif of Notifs.list)
                                    notif.notification.dismiss()
                            }
                        }

                        MaterialIcon {
                            anchors.centerIn: parent
                            text: "clear_all"
                            font.pointSize: Appearance.font.size.small
                            color: Colours.palette.m3error
                        }
                    }
                }

                // Notification list or empty state
                Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: true

                    // Empty state - like lock screen
                    Loader {
                        anchors.centerIn: parent
                        asynchronous: true
                        active: opacity > 0
                        opacity: Notifs.list.length > 0 ? 0 : 1

                        sourceComponent: ColumnLayout {
                            spacing: Appearance.spacing.normal

                            Image {
                                Layout.alignment: Qt.AlignHCenter
                                asynchronous: true
                                source: `file://${Quickshell.shellDir}/assets/dino.png`
                                fillMode: Image.PreserveAspectFit
                                sourceSize.width: 120

                                layer.enabled: true
                                layer.effect: Colouriser {
                                    colorizationColor: Colours.palette.m3outlineVariant
                                    brightness: 1
                                }
                            }

                            StyledText {
                                Layout.alignment: Qt.AlignHCenter
                                text: qsTr("No Notifications")
                                color: Colours.palette.m3outlineVariant
                                font.pointSize: Appearance.font.size.normal
                                font.weight: Font.Medium
                            }
                        }

                        Behavior on opacity {
                            Anim {
                                duration: Appearance.anim.durations.normal
                            }
                        }
                    }

                    // Notification list
                    StyledListView {
                        id: notifList
                        anchors.fill: parent
                        clip: true
                        spacing: Appearance.spacing.small
                        opacity: Notifs.list.length > 0 ? 1 : 0

                        model: ScriptModel {
                            values: [...Notifs.list].reverse()
                        }

                        delegate: NotificationItem {
                            required property var modelData
                            required property int index

                            width: notifList.width
                            notif: modelData
                        }

                        ScrollBar.vertical: StyledScrollBar {}

                        Behavior on opacity {
                            Anim {
                                duration: Appearance.anim.durations.normal
                            }
                        }
                    }
                }
            }
        }

        /* QUICK TOGGLES SECTION */
        StyledRect {
            id: togglesSection
            Layout.fillWidth: true
            implicitHeight: togglesLayout.implicitHeight + Appearance.padding.normal * 2
            radius: Appearance.rounding.normal
            color: Colours.tPalette.m3surfaceContainer

            ColumnLayout {
                id: togglesLayout
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: Appearance.padding.normal
                spacing: Appearance.spacing.normal

                // Header
                StyledText {
                    text: qsTr("Quick Toggles")
                    font.pointSize: Appearance.font.size.smaller
                    font.weight: Font.Medium
                    Layout.fillWidth: true
                }

                // Toggle buttons row
                RowLayout {
                    Layout.fillWidth: true
                    spacing: Appearance.spacing.normal

                    // Mic Mute Toggle
                    ToggleButton {
                        Layout.fillWidth: true
                        icon: Audio.sourceMuted ? "mic_off" : "mic"
                        label: qsTr("Mic")
                        active: !Audio.sourceMuted
                        onClicked: {
                            if (Audio.source?.audio)
                                Audio.source.audio.muted = !Audio.source.audio.muted
                        }
                    }

                    // Audio Mute Toggle
                    ToggleButton {
                        Layout.fillWidth: true
                        icon: Audio.muted ? "volume_off" : "volume_up"
                        label: qsTr("Sound")
                        active: !Audio.muted
                        onClicked: {
                            if (Audio.sink?.audio)
                                Audio.sink.audio.muted = !Audio.sink.audio.muted
                        }
                    }

                    // Keep Awake Toggle
                    ToggleButton {
                        Layout.fillWidth: true
                        icon: IdleInhibitor.enabled ? "coffee" : "bedtime"
                        label: qsTr("Awake")
                        active: IdleInhibitor.enabled
                        onClicked: IdleInhibitor.enabled = !IdleInhibitor.enabled
                    }
                }
            }
        }
    }

    // Toggle Button Component
    component ToggleButton: StyledRect {
        id: toggle

        property string icon
        property string label
        property bool active: false
        signal clicked()

        implicitWidth: 48
        implicitHeight: 48
        radius: Appearance.rounding.normal
        color: active ? Colours.palette.m3primaryContainer : Colours.tPalette.m3surfaceContainerHigh

        StateLayer {
            radius: parent.radius
            color: active ? Colours.palette.m3onPrimaryContainer : Colours.palette.m3onSurface

            function onClicked(): void {
                toggle.clicked()
            }
        }

        MaterialIcon {
            anchors.centerIn: parent
            text: toggle.icon
            font.pointSize: Appearance.font.size.larger
            color: toggle.active ? Colours.palette.m3onPrimaryContainer : Colours.palette.m3onSurfaceVariant
        }
    }

    // Notification Item Component
    component NotificationItem: StyledRect {
        id: notifItem

        property var notif

        implicitHeight: notifContent.implicitHeight + Appearance.padding.smaller * 2
        radius: Appearance.rounding.small
        color: notif?.urgency === NotificationUrgency.Critical ? Colours.palette.m3errorContainer : Colours.tPalette.m3surfaceContainerHigh

        RowLayout {
            id: notifContent
            anchors.fill: parent
            anchors.margins: Appearance.padding.smaller
            spacing: Appearance.spacing.small

            // App icon
            StyledRect {
                Layout.preferredWidth: 32
                Layout.preferredHeight: 32
                Layout.alignment: Qt.AlignTop
                radius: Appearance.rounding.full
                color: notifItem.notif?.urgency === NotificationUrgency.Critical ? Colours.palette.m3error : Colours.palette.m3secondaryContainer

                Loader {
                    anchors.centerIn: parent
                    asynchronous: true

                    sourceComponent: notifItem.notif?.appIcon ? appIconComp : materialIconComp

                    Component {
                        id: appIconComp

                        ColouredIcon {
                            implicitSize: 18
                            source: Quickshell.iconPath(notifItem.notif?.appIcon ?? "")
                            colour: notifItem.notif?.urgency === NotificationUrgency.Critical ? Colours.palette.m3onError : Colours.palette.m3onSecondaryContainer
                            layer.enabled: (notifItem.notif?.appIcon ?? "").endsWith("symbolic")
                        }
                    }

                    Component {
                        id: materialIconComp

                        MaterialIcon {
                            text: Icons.getNotifIcon(notifItem.notif?.summary ?? "", notifItem.notif?.urgency ?? NotificationUrgency.Normal)
                            font.pointSize: Appearance.font.size.normal
                            color: notifItem.notif?.urgency === NotificationUrgency.Critical ? Colours.palette.m3onError : Colours.palette.m3onSecondaryContainer
                        }
                    }
                }
            }

            // Content
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2

                StyledText {
                    Layout.fillWidth: true
                    text: notifItem.notif?.summary ?? ""
                    font.pointSize: Appearance.font.size.small
                    font.weight: Font.Medium
                    elide: Text.ElideRight
                    maximumLineCount: 1
                    color: notifItem.notif?.urgency === NotificationUrgency.Critical ? Colours.palette.m3onErrorContainer : Colours.palette.m3onSurface
                }

                StyledText {
                    Layout.fillWidth: true
                    text: notifItem.notif?.body ?? ""
                    font.pointSize: Appearance.font.size.extraSmall
                    elide: Text.ElideRight
                    maximumLineCount: 2
                    wrapMode: Text.WrapAtWordBoundaryOrAnywhere
                    color: notifItem.notif?.urgency === NotificationUrgency.Critical ? Colours.palette.m3onErrorContainer : Colours.palette.m3onSurfaceVariant
                    visible: text.length > 0
                }
            }

            // Time and dismiss
            ColumnLayout {
                Layout.alignment: Qt.AlignTop
                spacing: Appearance.spacing.small

                StyledText {
                    Layout.alignment: Qt.AlignRight
                    text: notifItem.notif?.timeStr ?? ""
                    font.pointSize: Appearance.font.size.extraSmall
                    color: Colours.palette.m3outline
                }

                // Dismiss button
                StyledRect {
                    Layout.preferredWidth: 20
                    Layout.preferredHeight: 20
                    Layout.alignment: Qt.AlignRight
                    radius: Appearance.rounding.small
                    color: "transparent"

                    StateLayer {
                        radius: parent.radius
                        color: Colours.palette.m3onSurface

                        function onClicked(): void {
                            notifItem.notif?.notification?.dismiss()
                        }
                    }

                    MaterialIcon {
                        anchors.centerIn: parent
                        text: "close"
                        font.pointSize: Appearance.font.size.extraSmall
                        color: Colours.palette.m3onSurfaceVariant
                    }
                }
            }
        }
    }
}
