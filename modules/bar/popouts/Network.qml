pragma ComponentBehavior: Bound

import qs.components
import qs.components.controls
import qs.services
import qs.config
import qs.utils
import Quickshell
import QtQuick
import QtQuick.Layouts

ColumnLayout {
    id: root

    required property Item wrapper

    property string connectingToSsid: ""
    property var passwordNetwork: null
    property bool showPasswordDialog: false

    spacing: Appearance.spacing.sm
    width: Config.bar.sizes.networkWidth

    StyledText {
        Layout.topMargin: Appearance.padding.md
        Layout.rightMargin: Appearance.padding.xs
        text: qsTr("Wifi %1").arg(Nmcli.wifiEnabled ? "enabled" : "disabled")
        font.weight: 500
    }

    Toggle {
        label: qsTr("Enabled")
        checked: Nmcli.wifiEnabled
        toggle.onToggled: Nmcli.enableWifi(checked)
    }

    StyledText {
        Layout.topMargin: Appearance.spacing.sm
        Layout.rightMargin: Appearance.padding.xs
        text: qsTr("%1 networks available").arg(Nmcli.networks.length)
        color: Colours.palette.m3onSurfaceVariant
        font.pointSize: Appearance.font.size.labelLarge
    }

    Repeater {
        model: ScriptModel {
            values: [...Nmcli.networks].sort((a, b) => {
                if (a.active !== b.active)
                    return b.active - a.active;
                return b.strength - a.strength;
            }).slice(0, 8)
        }

        RowLayout {
            id: networkItem

            required property Nmcli.AccessPoint modelData
            readonly property bool isConnecting: root.connectingToSsid === modelData.ssid

            Layout.fillWidth: true
            Layout.rightMargin: Appearance.padding.xs
            spacing: Appearance.spacing.sm

            opacity: 0
            scale: 0.7

            Component.onCompleted: {
                opacity = 1;
                scale = 1;
            }

            Behavior on opacity {
                Anim {}
            }

            Behavior on scale {
                Anim {}
            }

            MaterialIcon {
                text: Icons.getNetworkIcon(networkItem.modelData.strength)
                color: networkItem.modelData.active ? Colours.palette.m3primary : Colours.palette.m3onSurfaceVariant
            }

            MaterialIcon {
                visible: networkItem.modelData.isSecure
                text: "lock"
                font.pointSize: Appearance.font.size.labelLarge
            }

            StyledText {
                Layout.leftMargin: Appearance.spacing.sm / 2
                Layout.rightMargin: Appearance.spacing.sm / 2
                Layout.fillWidth: true
                text: networkItem.modelData.ssid
                elide: Text.ElideRight
                font.weight: networkItem.modelData.active ? 500 : 400
                color: networkItem.modelData.active ? Colours.palette.m3primary : Colours.palette.m3onSurface
            }

            StyledRect {
                implicitWidth: implicitHeight
                implicitHeight: wirelessConnectIcon.implicitHeight + Appearance.padding.xs

                radius: Appearance.rounding.full
                color: Qt.alpha(Colours.palette.m3primary, networkItem.modelData.active ? 1 : 0)

                StyledBusyIndicator {
                    anchors.fill: parent
                    running: networkItem.isConnecting
                }

                StateLayer {
                    color: networkItem.modelData.active ? Colours.palette.m3onPrimary : Colours.palette.m3onSurface
                    disabled: networkItem.isConnecting || !Nmcli.wifiEnabled

                    function onClicked(): void {
                        if (networkItem.modelData.active) {
                            Nmcli.disconnectFromNetwork();
                        } else {
                            root.connectingToSsid = networkItem.modelData.ssid;
                            NetworkConnection.handleConnect(networkItem.modelData, null, network => {
                                // Password is required - show password popout
                                root.passwordNetwork = network;
                                root.showPasswordDialog = true;
                                root.wrapper.currentName = "wirelesspassword";
                            });
                        }
                    }
                }

                MaterialIcon {
                    id: wirelessConnectIcon

                    anchors.centerIn: parent
                    animate: true
                    text: networkItem.modelData.active ? "link_off" : "link"
                    color: networkItem.modelData.active ? Colours.palette.m3onPrimary : Colours.palette.m3onSurface

                    opacity: networkItem.isConnecting ? 0 : 1

                    Behavior on opacity {
                        Anim {}
                    }
                }
            }
        }
    }

    StyledRect {
        Layout.topMargin: Appearance.spacing.sm
        Layout.fillWidth: true
        implicitHeight: rescanBtn.implicitHeight + Appearance.padding.xs * 2

        radius: Appearance.rounding.full
        color: Colours.palette.m3primaryContainer

        StateLayer {
            color: Colours.palette.m3onPrimaryContainer
            disabled: Nmcli.scanning || !Nmcli.wifiEnabled

            function onClicked(): void {
                Nmcli.rescanWifi();
            }
        }

        RowLayout {
            id: rescanBtn

            anchors.centerIn: parent
            spacing: Appearance.spacing.sm
            opacity: Nmcli.scanning ? 0 : 1

            MaterialIcon {
                id: scanIcon

                animate: true
                text: "wifi_find"
                color: Colours.palette.m3onPrimaryContainer
            }

            StyledText {
                text: qsTr("Rescan networks")
                color: Colours.palette.m3onPrimaryContainer
            }

            Behavior on opacity {
                Anim {}
            }
        }

        StyledBusyIndicator {
            anchors.centerIn: parent
            strokeWidth: Appearance.padding.xs / 2
            bgColour: "transparent"
            implicitHeight: parent.implicitHeight - Appearance.padding.sm * 2
            running: Nmcli.scanning
        }
    }

    // Reset connecting state when network changes
    Connections {
        target: Nmcli

        function onActiveChanged(): void {
            if (Nmcli.active && root.connectingToSsid === Nmcli.active.ssid) {
                root.connectingToSsid = "";
                // Close password dialog if we successfully connected
                if (root.showPasswordDialog && root.passwordNetwork && Nmcli.active.ssid === root.passwordNetwork.ssid) {
                    root.showPasswordDialog = false;
                    root.passwordNetwork = null;
                    if (root.wrapper.currentName === "wirelesspassword") {
                        root.wrapper.currentName = "network";
                    }
                }
            }
        }

        function onConnectionFailed(ssid): void {
            if (root.connectingToSsid === ssid) {
                root.connectingToSsid = "";
            }
        }

        function onScanningChanged(): void {
            if (!Nmcli.scanning)
                scanIcon.rotation = 0;
        }
    }

    Connections {
        function onCurrentNameChanged(): void {
            // Clear password network when leaving password dialog
            if (root.wrapper.currentName !== "wirelesspassword" && root.showPasswordDialog) {
                root.showPasswordDialog = false;
                root.passwordNetwork = null;
            }
        }

        target: root.wrapper
    }

    component Toggle: RowLayout {
        required property string label
        property alias checked: toggle.checked
        property alias toggle: toggle

        Layout.fillWidth: true
        Layout.rightMargin: Appearance.padding.xs
        spacing: Appearance.spacing.lg

        StyledText {
            Layout.fillWidth: true
            text: parent.label
        }

        StyledSwitch {
            id: toggle
        }
    }
}
