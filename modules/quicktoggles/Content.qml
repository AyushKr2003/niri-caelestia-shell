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
                                sourceSize.width: 280

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

        /* WEATHER SECTION */
        StyledRect {
            id: weatherSection
            Layout.fillWidth: true
            implicitHeight: weatherLayout.implicitHeight + Appearance.padding.normal * 2
            radius: Appearance.rounding.normal
            color: Colours.tPalette.m3surfaceContainer

            property bool editingLocation: root.visibilities.editingWeatherLocation

            ColumnLayout {
                id: weatherLayout
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: Appearance.padding.normal
                spacing: Appearance.spacing.small

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Appearance.spacing.normal

                    // Weather icon
                    MaterialIcon {
                        text: Weather.icon
                        font.pointSize: Appearance.font.size.extraLarge * 1.5
                        color: Colours.palette.m3secondary
                    }

                    // Weather info
                    ColumnLayout {
                        spacing: 0

                        StyledText {
                            text: Weather.temp
                            font.pointSize: Appearance.font.size.large
                            font.weight: 700
                            color: Colours.palette.m3onSurface
                        }

                        StyledText {
                            text: Weather.description
                            font.pointSize: Appearance.font.size.smaller
                            color: Colours.palette.m3onSurfaceVariant
                        }
                    }

                    Item { Layout.fillWidth: true }

                    // Right side info
                    ColumnLayout {
                        spacing: 2

                        RowLayout {
                            spacing: Appearance.spacing.small
                            Layout.alignment: Qt.AlignRight

                            MaterialIcon {
                                text: "water_drop"
                                font.pointSize: Appearance.font.size.small
                                color: Colours.palette.m3tertiary
                            }
                            StyledText {
                                text: Weather.humidity + "%"
                                font.pointSize: Appearance.font.size.smaller
                                color: Colours.palette.m3onSurfaceVariant
                            }
                        }

                        // City with edit button
                        RowLayout {
                            Layout.alignment: Qt.AlignRight
                            spacing: Appearance.spacing.small

                            StyledText {
                                text: Weather.city || "Loading..."
                                font.pointSize: Appearance.font.size.extraSmall
                                color: Colours.palette.m3outline
                                visible: !weatherSection.editingLocation
                            }

                            // Edit button
                            StyledRect {
                                Layout.preferredWidth: 16
                                Layout.preferredHeight: 16
                                radius: Appearance.rounding.small
                                color: "transparent"
                                visible: !weatherSection.editingLocation

                                StateLayer {
                                    radius: parent.radius
                                    color: Colours.palette.m3primary

                                    function onClicked(): void {
                                        root.visibilities.editingWeatherLocation = true
                                        locationInput.text = Config.services.weatherLocation || Weather.city || ""
                                        locationInput.forceActiveFocus()
                                    }
                                }

                                MaterialIcon {
                                    anchors.centerIn: parent
                                    text: "edit"
                                    font.pointSize: Appearance.font.size.extraSmall
                                    color: Colours.palette.m3outline
                                }
                            }
                        }
                    }
                }

                // Location edit field
                RowLayout {
                    Layout.fillWidth: true
                    spacing: Appearance.spacing.small
                    visible: weatherSection.editingLocation

                    StyledRect {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 32
                        radius: Appearance.rounding.small
                        color: Colours.tPalette.m3surfaceContainerHigh

                        StyledTextField {
                            id: locationInput
                            anchors.fill: parent
                            anchors.leftMargin: Appearance.padding.small
                            anchors.rightMargin: Appearance.padding.small
                            placeholderText: qsTr("Enter city name...")
                            verticalAlignment: Text.AlignVCenter

                            Keys.onReturnPressed: saveLocation()
                            Keys.onEnterPressed: saveLocation()
                            Keys.onEscapePressed: {
                                root.visibilities.editingWeatherLocation = false
                            }

                            function saveLocation(): void {
                                if (text.trim() !== "") {
                                    saveLocationProcess.command = ["sh", "-c", 
                                        `sed -i 's/"weatherLocation": "[^"]*"/"weatherLocation": "${text.trim()}"/' '${Paths.config}/shell.json'`
                                    ]
                                    saveLocationProcess.running = true
                                }
                                root.visibilities.editingWeatherLocation = false
                            }
                        }
                    }

                    // Save button
                    StyledRect {
                        Layout.preferredWidth: 32
                        Layout.preferredHeight: 32
                        radius: Appearance.rounding.small
                        color: Colours.palette.m3primaryContainer

                        StateLayer {
                            radius: parent.radius
                            color: Colours.palette.m3onPrimaryContainer

                            function onClicked(): void {
                                locationInput.saveLocation()
                            }
                        }

                        MaterialIcon {
                            anchors.centerIn: parent
                            text: "check"
                            font.pointSize: Appearance.font.size.small
                            color: Colours.palette.m3onPrimaryContainer
                        }
                    }

                    // Cancel button
                    StyledRect {
                        Layout.preferredWidth: 32
                        Layout.preferredHeight: 32
                        radius: Appearance.rounding.small
                        color: Colours.tPalette.m3surfaceContainerHigh

                        StateLayer {
                            radius: parent.radius
                            color: Colours.palette.m3onSurface

                            function onClicked(): void {
                                root.visibilities.editingWeatherLocation = false
                            }
                        }

                        MaterialIcon {
                            anchors.centerIn: parent
                            text: "close"
                            font.pointSize: Appearance.font.size.small
                            color: Colours.palette.m3onSurfaceVariant
                        }
                    }
                }
            }

            Process {
                id: saveLocationProcess
                onExited: {
                    // Reload weather after config is saved
                    Weather.reload()
                }
            }
        }

        /* QUICK TOGGLES SECTION */
        StyledRect {
            id: togglesSection
            Layout.fillWidth: true
            implicitHeight: togglesLayout.implicitHeight + Appearance.padding.large * 2
            radius: Appearance.rounding.normal
            color: Colours.tPalette.m3surfaceContainer

            ColumnLayout {
                id: togglesLayout
                anchors.fill: parent
                anchors.margins: Appearance.padding.large
                spacing: Appearance.spacing.normal

                StyledText {
                    text: qsTr("Quick Toggles")
                    font.pointSize: Appearance.font.size.normal
                }

                RowLayout {
                    Layout.alignment: Qt.AlignHCenter
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
                        icon: "settings"
                        inactiveOnColour: Colours.palette.m3onSurfaceVariant
                        toggle: false
                        onClicked: {
                            root.visibilities.quicktoggles = false;
                            openControlCenter("network");
                        }
                    }

                    Toggle {
                        icon: "notifications_off"
                        checked: Notifs.dnd
                        onClicked: Notifs.dnd = !Notifs.dnd
                    }

                    Toggle {
                        icon: "vpn_key"
                        checked: VPN.connected
                        enabled: !VPN.connecting
                        visible: Config.utilities.vpn.provider.some(p => typeof p === "object" ? (p.enabled === true) : false)
                        onClicked: VPN.toggle()
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
