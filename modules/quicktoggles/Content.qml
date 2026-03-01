pragma ComponentBehavior: Bound

import qs.components
import qs.components.controls
import qs.components.containers
import qs.components.effects
import qs.services
import qs.config
import qs.utils
import Quickshell
import Quickshell.Bluetooth
import Quickshell.Io
import Quickshell.Widgets
import Quickshell.Services.Notifications
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

Item {
    id: root

    required property var wrapper
    required property PersistentProperties visibilities

    readonly property int padding: Math.max(Appearance.padding.large, Config.border.rounding)

    implicitWidth: 450
    implicitHeight: mainLayout.implicitHeight + padding * 2

    ColumnLayout {
        id: mainLayout
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: root.padding
        spacing: Appearance.spacing.small

        /* ─── NOTIFICATIONS ─── */
        StyledClippingRect {
            id: notifSection
            Layout.fillWidth: true
            Layout.preferredHeight: notifExpanded ? expandedHeight : collapsedHeight
            radius: Appearance.rounding.normal
            color: Colours.tPalette.m3surfaceContainer

            readonly property bool notifExpanded: root.visibilities.notifsExpanded
            readonly property int collapsedHeight: notifHeader.implicitHeight + Appearance.padding.normal * 2
            readonly property int listContentHeight: notifHeader.implicitHeight + Appearance.padding.normal * 2 + Appearance.spacing.small + notifList.contentHeight + Appearance.spacing.small * Math.max(0, Notifs.list.length - 1) + Appearance.padding.normal
            readonly property int screenHalfHeight: (Screen.height || 1080) / 2
            readonly property int expandedHeight: Notifs.list.length === 0
                ? collapsedHeight + 120
                : Math.max(collapsedHeight + 120, Math.min(listContentHeight, screenHalfHeight))

            Behavior on Layout.preferredHeight {
                Anim {
                    duration: Appearance.anim.durations.normal
                    easing.bezierCurve: Appearance.anim.curves.emphasized
                }
            }

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: Appearance.padding.normal
                spacing: Appearance.spacing.small

                // ── Header row ──
                RowLayout {
                    id: notifHeader
                    Layout.fillWidth: true
                    spacing: Appearance.spacing.small

                    MaterialIcon {
                        text: Notifs.dnd ? "notifications_off" : "notifications"
                        font.pointSize: Appearance.font.size.normal
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
                        font.pointSize: Appearance.font.size.smaller
                        font.weight: Font.Medium
                        Layout.fillWidth: true
                    }

                    // DND toggle
                    StyledRect {
                        Layout.preferredWidth: 28
                        Layout.preferredHeight: 28
                        radius: Appearance.rounding.full
                        color: Notifs.dnd ? Colours.palette.m3errorContainer : "transparent"

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
                            font.pointSize: Appearance.font.size.small
                            color: Notifs.dnd ? Colours.palette.m3onErrorContainer : Colours.palette.m3onSurfaceVariant
                        }
                    }

                    // Clear all
                    StyledRect {
                        Layout.preferredWidth: 28
                        Layout.preferredHeight: 28
                        radius: Appearance.rounding.full
                        color: "transparent"
                        visible: Notifs.list.length > 0 && notifSection.notifExpanded

                        StateLayer {
                            radius: parent.radius
                            color: Colours.palette.m3error

                            function onClicked(): void {
                                for (const notif of Notifs.list)
                                    notif.notification.dismiss();
                            }
                        }

                        MaterialIcon {
                            anchors.centerIn: parent
                            text: "delete_sweep"
                            font.pointSize: Appearance.font.size.small
                            color: Colours.palette.m3error
                        }
                    }

                    // Expand / collapse chevron
                    StyledRect {
                        Layout.preferredWidth: 28
                        Layout.preferredHeight: 28
                        radius: Appearance.rounding.full
                        color: "transparent"

                        StateLayer {
                            radius: parent.radius
                            color: Colours.palette.m3onSurface

                            function onClicked(): void {
                                root.visibilities.notifsExpanded = !root.visibilities.notifsExpanded;
                            }
                        }

                        MaterialIcon {
                            anchors.centerIn: parent
                            text: notifSection.notifExpanded ? "keyboard_arrow_up" : "keyboard_arrow_down"
                            font.pointSize: Appearance.font.size.normal
                            color: Colours.palette.m3onSurfaceVariant

                            Behavior on rotation {
                                Anim {
                                    duration: Appearance.anim.durations.small
                                    easing.bezierCurve: Appearance.anim.curves.emphasized
                                }
                            }
                        }
                    }
                }

                // ── Notification body (only when expanded) ──
                Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    visible: notifSection.notifExpanded
                    opacity: notifSection.notifExpanded ? 1 : 0

                    Behavior on opacity {
                        Anim {
                            duration: Appearance.anim.durations.normal
                        }
                    }

                    // Empty state
                    ColumnLayout {
                        anchors.centerIn: parent
                        visible: Notifs.list.length === 0
                        spacing: Appearance.spacing.small

                        MaterialIcon {
                            Layout.alignment: Qt.AlignHCenter
                            text: "notifications_none"
                            font.pointSize: Appearance.font.size.extraLarge * 1.5
                            color: Colours.palette.m3outlineVariant
                        }

                        StyledText {
                            Layout.alignment: Qt.AlignHCenter
                            text: qsTr("All clear")
                            color: Colours.palette.m3outlineVariant
                            font.pointSize: Appearance.font.size.smaller
                        }
                    }

                    // Notification list
                    StyledListView {
                        id: notifList
                        anchors.fill: parent
                        clip: true
                        spacing: Appearance.spacing.small
                        visible: Notifs.list.length > 0

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
                    }
                }
            }
        }

        /* ─── QUICK TOGGLES ─── */
        StyledRect {
            id: togglesSection
            Layout.fillWidth: true
            implicitHeight: togglesRow.implicitHeight + Appearance.padding.normal * 2
            radius: Appearance.rounding.normal
            color: Colours.tPalette.m3surfaceContainer

            RowLayout {
                id: togglesRow
                anchors.fill: parent
                anchors.margins: Appearance.padding.normal
                spacing: Appearance.spacing.small

                Toggle {
                    icon: "wifi"
                    checked: Network.wifiEnabled
                    onClicked: Network.toggleWifi()
                }

                Toggle {
                    icon: "bluetooth"
                    checked: Bluetooth.defaultAdapter?.enabled ?? false
                    onClicked: {
                        const adapter = Bluetooth.defaultAdapter;
                        if (adapter)
                            adapter.enabled = !adapter.enabled;
                    }
                }

                Toggle {
                    icon: "mic"
                    checked: !Audio.sourceMuted
                    onClicked: {
                        const audio = Audio.source?.audio;
                        if (audio)
                            audio.muted = !audio.muted;
                    }
                }

                Toggle {
                    icon: "vpn_key"
                    checked: VPN.connected
                    enabled: !VPN.connecting
                    visible: Config.utilities.vpn.provider.some(p => typeof p === "object" ? (p.enabled === true) : false)
                    onClicked: VPN.toggle()
                }

                Toggle {
                    icon: "settings"
                    inactiveOnColour: Colours.palette.m3onSurfaceVariant
                    toggle: false
                    onClicked: {
                        root.visibilities.quicktoggles = false;
                        openControlCenter("network");
                    }
                }
            }
        }

    }

    function openControlCenter(pane: string): void {
        const panelsPopouts = root.wrapper && root.wrapper.parent ? root.wrapper.parent.popouts : null;
        if (panelsPopouts) {
            panelsPopouts.detach(pane);
        }
        // Close the quicktoggles panel after opening the ControlCenter popout
        if (root.visibilities) {
            root.visibilities.quicktoggles = false;
        }
    }

    // Toggle component matching Hyprland's utilities/cards/Toggles style
    component Toggle: IconButton {
        Layout.fillWidth: true
        Layout.preferredWidth: implicitWidth + (stateLayer.pressed ? Appearance.padding.large : internalChecked ? Appearance.padding.smaller : 0)
        radius: stateLayer.pressed ? Appearance.rounding.small / 2 : internalChecked ? Appearance.rounding.small : Appearance.rounding.normal
        inactiveColour: Colours.layer(Colours.palette.m3surfaceContainerHighest, 2)
        toggle: true
        radiusAnim.duration: Appearance.anim.durations.expressiveFastSpatial
        radiusAnim.easing.bezierCurve: Appearance.anim.curves.expressiveFastSpatial

        Behavior on Layout.preferredWidth {
            Anim {
                duration: Appearance.anim.durations.expressiveFastSpatial
                easing.bezierCurve: Appearance.anim.curves.expressiveFastSpatial
            }
        }
    }

    // Notification Item Component
    component NotificationItem: StyledRect {
        id: notifItem

        property var notif
        property bool expanded: false

        // Whether the body text is truncated (needs expand)
        readonly property bool bodyTruncated: bodyText.truncated

        implicitHeight: notifContent.implicitHeight + Appearance.padding.smaller * 2
        radius: Appearance.rounding.small
        color: notif?.urgency === NotificationUrgency.Critical ? Colours.palette.m3errorContainer : Colours.tPalette.m3surfaceContainerHigh

        Behavior on implicitHeight {
            Anim {
                duration: Appearance.anim.durations.small
                easing.bezierCurve: Appearance.anim.curves.emphasizedDecel
            }
        }

        // Click to expand/collapse — only when body is long enough
        StateLayer {
            anchors.fill: parent
            radius: notifItem.radius
            color: notifItem.notif?.urgency === NotificationUrgency.Critical ? Colours.palette.m3onErrorContainer : Colours.palette.m3onSurface
            disabled: !notifItem.bodyTruncated && !notifItem.expanded

            function onClicked(): void {
                notifItem.expanded = !notifItem.expanded
            }
        }

        RowLayout {
            id: notifContent
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: Appearance.padding.smaller
            spacing: Appearance.spacing.small

            // App icon
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
                                font.pointSize: Appearance.font.size.normal
                                color: notifItem.notif?.urgency === NotificationUrgency.Critical ? Colours.palette.m3onError : Colours.palette.m3onSecondaryContainer
                            }
                        }
                    }
                }
            }

            // Content
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2

                // App name when expanded
                StyledText {
                    Layout.fillWidth: true
                    text: notifItem.notif?.appName ?? ""
                    font.pointSize: Appearance.font.size.ultraSmall
                    font.weight: Font.Medium
                    color: Colours.palette.m3outline
                    visible: notifItem.expanded && text.length > 0
                    elide: Text.ElideRight
                    maximumLineCount: 1
                }

                StyledText {
                    Layout.fillWidth: true
                    text: notifItem.notif?.summary ?? ""
                    font.pointSize: Appearance.font.size.small
                    font.weight: Font.Medium
                    elide: notifItem.expanded ? Text.ElideNone : Text.ElideRight
                    maximumLineCount: notifItem.expanded ? 3 : 1
                    wrapMode: notifItem.expanded ? Text.WrapAtWordBoundaryOrAnywhere : Text.NoWrap
                    color: notifItem.notif?.urgency === NotificationUrgency.Critical ? Colours.palette.m3onErrorContainer : Colours.palette.m3onSurface
                }

                StyledText {
                    id: bodyText
                    Layout.fillWidth: true
                    text: notifItem.notif?.body ?? ""
                    font.pointSize: Appearance.font.size.extraSmall
                    elide: notifItem.expanded ? Text.ElideNone : Text.ElideRight
                    maximumLineCount: notifItem.expanded ? 20 : 2
                    wrapMode: Text.WrapAtWordBoundaryOrAnywhere
                    color: notifItem.notif?.urgency === NotificationUrgency.Critical ? Colours.palette.m3onErrorContainer : Colours.palette.m3onSurfaceVariant
                    visible: text.length > 0
                }

                // Notification image when expanded
                Image {
                    Layout.fillWidth: true
                    Layout.maximumHeight: 120
                    source: (notifItem.expanded && notifItem.notif?.image) ? notifItem.notif.image : ""
                    fillMode: Image.PreserveAspectFit
                    visible: notifItem.expanded && status === Image.Ready
                    asynchronous: true
                }

                // Action buttons when expanded
                Flow {
                    Layout.fillWidth: true
                    spacing: Appearance.spacing.small
                    visible: notifItem.expanded && notifActionsRepeater.count > 0

                    Repeater {
                        id: notifActionsRepeater
                        model: notifItem.notif?.actions ?? []

                        delegate: StyledRect {
                            required property var modelData

                            implicitWidth: actionLabel.implicitWidth + Appearance.padding.normal * 2
                            implicitHeight: actionLabel.implicitHeight + Appearance.padding.small * 2
                            radius: Appearance.rounding.small
                            color: notifItem.notif?.urgency === NotificationUrgency.Critical ? Colours.palette.m3error : Colours.palette.m3secondaryContainer

                            StateLayer {
                                radius: parent.radius
                                color: notifItem.notif?.urgency === NotificationUrgency.Critical ? Colours.palette.m3onError : Colours.palette.m3onSecondaryContainer

                                function onClicked(): void {
                                    modelData.invoke()
                                }
                            }

                            StyledText {
                                id: actionLabel
                                anchors.centerIn: parent
                                text: modelData.text ?? ""
                                font.pointSize: Appearance.font.size.ultraSmall
                                font.weight: Font.Medium
                                color: notifItem.notif?.urgency === NotificationUrgency.Critical ? Colours.palette.m3onError : Colours.palette.m3onSecondaryContainer
                            }
                        }
                    }
                }

                // Expand indicator
                MaterialIcon {
                    Layout.alignment: Qt.AlignHCenter
                    text: notifItem.expanded ? "expand_less" : "expand_more"
                    font.pointSize: Appearance.font.size.extraSmall
                    color: Colours.palette.m3outline
                    visible: notifItem.bodyTruncated || notifItem.expanded
                    opacity: 0.6
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
