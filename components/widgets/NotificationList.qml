pragma ComponentBehavior: Bound

import qs.components
import qs.components.containers
import qs.components.controls
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

    property bool showHeader: true
    property bool showDndToggle: true
    property bool showClearAll: true
    property bool expandable: true
    property bool expanded: true

    signal cleared

    readonly property real desiredContentHeight: headerRow.implicitHeight + column.spacing + notifList.contentHeight + notifList.spacing * Math.max(0, Notifs.list.length - 1)

    implicitHeight: column.implicitHeight

    ColumnLayout {
        id: column
        anchors.fill: parent
        spacing: Appearance.spacing.sm

        // Header row
        RowLayout {
            id: headerRow
            Layout.fillWidth: true
            visible: root.showHeader
            spacing: Appearance.spacing.sm

            MaterialIcon {
                text: Notifs.dnd ? "notifications_off" : "notifications"
                font.pointSize: Appearance.font.size.bodyMedium
                color: Notifs.dnd ? Colours.palette.m3outline : Colours.palette.m3primary
            }

            StyledText {
                text: {
                    if (Notifs.dnd)
                        return qsTr("Do Not Disturb");
                    if (Notifs.list.length > 0)
                        return qsTr("%1 notification%2").arg(Notifs.list.length).arg(Notifs.list.length === 1 ? "" : "s");
                    return qsTr("Notifications");
                }
                font.pointSize: Appearance.font.size.bodySmall
                font.weight: Font.Medium
                Layout.fillWidth: true
            }

            StyledRect {
                Layout.preferredWidth: 28
                Layout.preferredHeight: 28
                radius: Appearance.rounding.full
                color: Notifs.dnd ? Colours.palette.m3errorContainer : "transparent"
                visible: root.showDndToggle

                StateLayer {
                    radius: parent.radius
                    color: Notifs.dnd ? Colours.palette.m3onErrorContainer : Colours.palette.m3onSurface

                    function onClicked(): void {
                        Notifs.dnd = !Notifs.dnd;
                    }
                }

                MaterialIcon {
                    anchors.centerIn: parent
                    text: Notifs.dnd ? "do_not_disturb_on" : "do_not_disturb_off"
                    font.pointSize: Appearance.font.size.labelLarge
                    color: Notifs.dnd ? Colours.palette.m3onErrorContainer : Colours.palette.m3onSurfaceVariant
                }
            }

            StyledRect {
                Layout.preferredWidth: 28
                Layout.preferredHeight: 28
                radius: Appearance.rounding.full
                color: "transparent"
                visible: root.showClearAll && Notifs.list.length > 0 && root.expanded

                StateLayer {
                    radius: parent.radius
                    color: Colours.palette.m3error

                    function onClicked(): void {
                        Notifs.discardAllNotifications();
                        root.cleared();
                    }
                }

                MaterialIcon {
                    anchors.centerIn: parent
                    text: "delete_sweep"
                    font.pointSize: Appearance.font.size.labelLarge
                    color: Colours.palette.m3error
                }
            }

            StyledRect {
                Layout.preferredWidth: 28
                Layout.preferredHeight: 28
                radius: Appearance.rounding.full
                color: "transparent"
                visible: root.expandable

                StateLayer {
                    radius: parent.radius
                    color: Colours.palette.m3onSurface

                    function onClicked(): void {
                        root.expanded = !root.expanded;
                    }
                }

                MaterialIcon {
                    anchors.centerIn: parent
                    text: root.expanded ? "keyboard_arrow_up" : "keyboard_arrow_down"
                    font.pointSize: Appearance.font.size.bodyMedium
                    color: Colours.palette.m3onSurfaceVariant
                }
            }
        }

        // Notification body
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: root.expanded
            clip: true

            // Empty state
            ColumnLayout {
                anchors.centerIn: parent
                visible: Notifs.list.length === 0
                spacing: Appearance.spacing.sm

                MaterialIcon {
                    Layout.alignment: Qt.AlignHCenter
                    text: "notifications_none"
                    font.pointSize: Appearance.font.size.headlineLarge * 1.5
                    color: Colours.palette.m3outlineVariant
                }

                StyledText {
                    Layout.alignment: Qt.AlignHCenter
                    text: qsTr("All clear")
                    color: Colours.palette.m3outlineVariant
                    font.pointSize: Appearance.font.size.bodySmall
                }
            }

            StyledListView {
                id: notifList
                anchors.fill: parent
                clip: true
                spacing: Appearance.spacing.sm
                visible: Notifs.list.length > 0

                model: ScriptModel {
                    values: [...Notifs.list].reverse()
                }

                delegate: NotifItem {
                    required property var modelData
                    required property int index

                    width: notifList.width
                    notif: modelData
                }

                ScrollBar.vertical: StyledScrollBar {}
            }
        }
    }

    // Compact notification item component
    component NotifItem: StyledRect {
        id: notifItem

        property var notif
        property bool itemExpanded: false

        readonly property bool bodyTruncated: bodyText.truncated

        implicitHeight: notifContent.implicitHeight + Appearance.padding.sm * 2
        radius: Appearance.rounding.small
        color: notif?.urgency === NotificationUrgency.Critical ? Colours.palette.m3errorContainer : Colours.tPalette.m3surfaceContainerHigh

        Behavior on implicitHeight {
            Anim {
                duration: Appearance.anim.durations.small
                easing.bezierCurve: Appearance.anim.curves.emphasizedDecel
            }
        }

        StateLayer {
            anchors.fill: parent
            radius: notifItem.radius
            color: notifItem.notif?.urgency === NotificationUrgency.Critical ? Colours.palette.m3onErrorContainer : Colours.palette.m3onSurface
            disabled: !notifItem.bodyTruncated && !notifItem.itemExpanded

            function onClicked(): void {
                notifItem.itemExpanded = !notifItem.itemExpanded;
            }
        }

        RowLayout {
            id: notifContent
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: Appearance.padding.sm
            spacing: Appearance.spacing.sm

            Item {
                Layout.preferredWidth: 32
                Layout.preferredHeight: 32
                Layout.maximumHeight: 32
                Layout.alignment: Qt.AlignTop

                StyledRect {
                    width: 32
                    height: 32
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
                                font.pointSize: Appearance.font.size.bodyMedium
                                color: notifItem.notif?.urgency === NotificationUrgency.Critical ? Colours.palette.m3onError : Colours.palette.m3onSecondaryContainer
                            }
                        }
                    }
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2

                StyledText {
                    Layout.fillWidth: true
                    text: notifItem.notif?.appName ?? ""
                    font.pointSize: Appearance.font.size.labelSmall
                    font.weight: Font.Medium
                    color: Colours.palette.m3outline
                    visible: notifItem.itemExpanded && text.length > 0
                    elide: Text.ElideRight
                    maximumLineCount: 1
                }

                StyledText {
                    Layout.fillWidth: true
                    text: notifItem.notif?.summary ?? ""
                    font.pointSize: Appearance.font.size.labelLarge
                    font.weight: Font.Medium
                    elide: notifItem.itemExpanded ? Text.ElideNone : Text.ElideRight
                    maximumLineCount: notifItem.itemExpanded ? 3 : 1
                    wrapMode: notifItem.itemExpanded ? Text.WrapAtWordBoundaryOrAnywhere : Text.NoWrap
                    color: notifItem.notif?.urgency === NotificationUrgency.Critical ? Colours.palette.m3onErrorContainer : Colours.palette.m3onSurface
                }

                StyledText {
                    id: bodyText
                    Layout.fillWidth: true
                    text: notifItem.notif?.body ?? ""
                    font.pointSize: Appearance.font.size.labelMedium
                    elide: notifItem.itemExpanded ? Text.ElideNone : Text.ElideRight
                    maximumLineCount: notifItem.itemExpanded ? 20 : 2
                    wrapMode: Text.WrapAtWordBoundaryOrAnywhere
                    color: notifItem.notif?.urgency === NotificationUrgency.Critical ? Colours.palette.m3onErrorContainer : Colours.palette.m3onSurfaceVariant
                    visible: text.length > 0
                }

                Image {
                    Layout.fillWidth: true
                    Layout.maximumHeight: 120
                    source: (notifItem.itemExpanded && notifItem.notif?.image) ? notifItem.notif.image : ""
                    fillMode: Image.PreserveAspectFit
                    visible: notifItem.itemExpanded && status === Image.Ready
                    asynchronous: true
                }

                Flow {
                    Layout.fillWidth: true
                    spacing: Appearance.spacing.sm
                    visible: notifItem.itemExpanded && notifActionsRepeater.count > 0

                    Repeater {
                        id: notifActionsRepeater
                        model: notifItem.notif?.actions ?? []

                        delegate: StyledRect {
                            required property var modelData

                            implicitWidth: actionLabel.implicitWidth + Appearance.padding.md * 2
                            implicitHeight: actionLabel.implicitHeight + Appearance.padding.xs * 2
                            radius: Appearance.rounding.small
                            color: notifItem.notif?.urgency === NotificationUrgency.Critical ? Colours.palette.m3error : Colours.palette.m3secondaryContainer

                            StateLayer {
                                radius: parent.radius
                                color: notifItem.notif?.urgency === NotificationUrgency.Critical ? Colours.palette.m3onError : Colours.palette.m3onSecondaryContainer

                                function onClicked(): void {
                                    modelData.invoke();
                                }
                            }

                            StyledText {
                                id: actionLabel
                                anchors.centerIn: parent
                                text: modelData.text ?? ""
                                font.pointSize: Appearance.font.size.labelSmall
                                font.weight: Font.Medium
                                color: notifItem.notif?.urgency === NotificationUrgency.Critical ? Colours.palette.m3onError : Colours.palette.m3onSecondaryContainer
                            }
                        }
                    }
                }

                MaterialIcon {
                    Layout.alignment: Qt.AlignHCenter
                    text: notifItem.itemExpanded ? "expand_less" : "expand_more"
                    font.pointSize: Appearance.font.size.labelMedium
                    color: Colours.palette.m3outline
                    visible: notifItem.bodyTruncated || notifItem.itemExpanded
                    opacity: 0.6
                }
            }

            ColumnLayout {
                Layout.alignment: Qt.AlignTop
                spacing: Appearance.spacing.sm

                StyledText {
                    Layout.alignment: Qt.AlignRight
                    text: notifItem.notif?.timeStr ?? ""
                    font.pointSize: Appearance.font.size.labelMedium
                    color: Colours.palette.m3outline
                }

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
                            if (notifItem.notif)
                                Notifs.discardNotification(notifItem.notif.notificationId);
                        }
                    }

                    MaterialIcon {
                        anchors.centerIn: parent
                        text: "close"
                        font.pointSize: Appearance.font.size.labelMedium
                        color: Colours.palette.m3onSurfaceVariant
                    }
                }
            }
        }
    }
}
