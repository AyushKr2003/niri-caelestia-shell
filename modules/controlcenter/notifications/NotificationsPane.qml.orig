pragma ComponentBehavior: Bound

import ".."
import "../components"
import qs.components
import qs.components.controls
import qs.components.effects
import qs.components.containers
import qs.services
import qs.config
import Quickshell
import Quickshell.Widgets
import QtQuick
import QtQuick.Layouts

Item {
    id: root

    required property Session session

    property bool expire: Config.notifs.expire ?? true
    property int defaultExpireTimeout: Config.notifs.defaultExpireTimeout ?? 5000
    property real clearThreshold: Config.notifs.clearThreshold ?? 0.3
    property bool actionOnClick: Config.notifs.actionOnClick ?? false
    property int groupPreviewNum: Config.notifs.groupPreviewNum ?? 3
    property int expandThreshold: Config.notifs.expandThreshold ?? 20
    property int popupWidth: Config.notifs.sizes.width ?? 400
    property int imageSize: Config.notifs.sizes.image ?? 41
    property int badgeSize: Config.notifs.sizes.badge ?? 20

    anchors.fill: parent

    function saveConfig() {
        Config.notifs.expire = root.expire;
        Config.notifs.defaultExpireTimeout = root.defaultExpireTimeout;
        Config.notifs.clearThreshold = root.clearThreshold;
        Config.notifs.actionOnClick = root.actionOnClick;
        Config.notifs.groupPreviewNum = root.groupPreviewNum;
        Config.notifs.expandThreshold = root.expandThreshold;
        Config.notifs.sizes.width = root.popupWidth;
        Config.notifs.sizes.image = root.imageSize;
        Config.notifs.sizes.badge = root.badgeSize;
        Config.markDirty("notifs");
    }

    ClippingRectangle {
        id: notifsClippingRect
        anchors.fill: parent
        anchors.margins: Appearance.padding.md
        anchors.leftMargin: 0
        anchors.rightMargin: Appearance.padding.md

        radius: notifsBorder.innerRadius
        color: "transparent"

        Loader {
            id: notifsLoader
            anchors.fill: parent
            anchors.margins: Appearance.padding.xl + Appearance.padding.md
            anchors.leftMargin: Appearance.padding.xl
            anchors.rightMargin: Appearance.padding.xl

            sourceComponent: notifsContentComponent
        }
    }

    InnerBorder {
        id: notifsBorder
        leftThickness: 0
        rightThickness: Appearance.padding.md
    }

    Component {
        id: notifsContentComponent

        StyledFlickable {
            id: notifsFlickable
            flickableDirection: Flickable.VerticalFlick
            contentHeight: notifsLayout.height

            StyledScrollBar.vertical: StyledScrollBar {
                flickable: notifsFlickable
            }

            ColumnLayout {
                id: notifsLayout
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                spacing: Appearance.spacing.lg

                RowLayout {
                    spacing: Appearance.spacing.md

                    StyledText {
                        text: qsTr("Notifications")
                        font.pointSize: Appearance.font.size.titleMedium
                        font.weight: 500
                    }
                }

                // Behaviour Section
                SectionContainer {
                    alignTop: true

                    StyledText {
                        text: qsTr("Behaviour")
                        font.pointSize: Appearance.font.size.bodyMedium
                    }

                    SwitchRow {
                        label: qsTr("Auto-expire notifications")
                        checked: root.expire
                        onToggled: checked => {
                            root.expire = checked;
                            root.saveConfig();
                        }
                    }

                    SwitchRow {
                        label: qsTr("Single action on click")
                        checked: root.actionOnClick
                        onToggled: checked => {
                            root.actionOnClick = checked;
                            root.saveConfig();
                        }
                    }

                    SectionContainer {
                        contentSpacing: Appearance.spacing.lg

                        SliderInput {
                            Layout.fillWidth: true

                            label: qsTr("Expire timeout")
                            value: root.defaultExpireTimeout
                            from: 1000
                            to: 30000
                            stepSize: 500
                            suffix: "ms"
                            validator: IntValidator { bottom: 1000; top: 30000 }
                            formatValueFunction: val => Math.round(val).toString()
                            parseValueFunction: text => parseInt(text)

                            onValueModified: newValue => {
                                root.defaultExpireTimeout = Math.round(newValue);
                                root.saveConfig();
                            }
                        }
                    }
                }

                // Gestures Section
                SectionContainer {
                    alignTop: true

                    StyledText {
                        text: qsTr("Gestures")
                        font.pointSize: Appearance.font.size.bodyMedium
                    }

                    SectionContainer {
                        contentSpacing: Appearance.spacing.lg

                        SliderInput {
                            Layout.fillWidth: true

                            label: qsTr("Swipe dismiss threshold")
                            value: root.clearThreshold * 100
                            from: 10
                            to: 90
                            suffix: "%"
                            validator: IntValidator { bottom: 10; top: 90 }
                            formatValueFunction: val => Math.round(val).toString()
                            parseValueFunction: text => parseInt(text)

                            onValueModified: newValue => {
                                root.clearThreshold = newValue / 100;
                                root.saveConfig();
                            }
                        }

                        SliderInput {
                            Layout.fillWidth: true

                            label: qsTr("Expand threshold")
                            value: root.expandThreshold
                            from: 10
                            to: 100
                            stepSize: 5
                            suffix: "px"
                            validator: IntValidator { bottom: 10; top: 100 }
                            formatValueFunction: val => Math.round(val).toString()
                            parseValueFunction: text => parseInt(text)

                            onValueModified: newValue => {
                                root.expandThreshold = Math.round(newValue);
                                root.saveConfig();
                            }
                        }
                    }
                }

                // Display Section
                SectionContainer {
                    alignTop: true

                    StyledText {
                        text: qsTr("Display")
                        font.pointSize: Appearance.font.size.bodyMedium
                    }

                    SectionContainer {
                        contentSpacing: Appearance.spacing.lg

                        SliderInput {
                            Layout.fillWidth: true

                            label: qsTr("Group preview count")
                            value: root.groupPreviewNum
                            from: 1
                            to: 10
                            stepSize: 1
                            validator: IntValidator { bottom: 1; top: 10 }
                            formatValueFunction: val => Math.round(val).toString()
                            parseValueFunction: text => parseInt(text)

                            onValueModified: newValue => {
                                root.groupPreviewNum = Math.round(newValue);
                                root.saveConfig();
                            }
                        }

                        SliderInput {
                            Layout.fillWidth: true

                            label: qsTr("Popup width")
                            value: root.popupWidth
                            from: 200
                            to: 800
                            stepSize: 25
                            suffix: "px"
                            validator: IntValidator { bottom: 200; top: 800 }
                            formatValueFunction: val => Math.round(val).toString()
                            parseValueFunction: text => parseInt(text)

                            onValueModified: newValue => {
                                root.popupWidth = Math.round(newValue);
                                root.saveConfig();
                            }
                        }

                        SliderInput {
                            Layout.fillWidth: true

                            label: qsTr("Image size")
                            value: root.imageSize
                            from: 16
                            to: 96
                            stepSize: 1
                            suffix: "px"
                            validator: IntValidator { bottom: 16; top: 96 }
                            formatValueFunction: val => Math.round(val).toString()
                            parseValueFunction: text => parseInt(text)

                            onValueModified: newValue => {
                                root.imageSize = Math.round(newValue);
                                root.saveConfig();
                            }
                        }

                        SliderInput {
                            Layout.fillWidth: true

                            label: qsTr("Badge size")
                            value: root.badgeSize
                            from: 10
                            to: 48
                            stepSize: 1
                            suffix: "px"
                            validator: IntValidator { bottom: 10; top: 48 }
                            formatValueFunction: val => Math.round(val).toString()
                            parseValueFunction: text => parseInt(text)

                            onValueModified: newValue => {
                                root.badgeSize = Math.round(newValue);
                                root.saveConfig();
                            }
                        }
                    }
                }
            }
        }
    }
}
