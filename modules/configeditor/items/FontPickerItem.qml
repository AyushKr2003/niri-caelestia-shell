import "../"
import qs.components
import qs.components.controls
import qs.services
import qs.config
import Quickshell
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

BaseConfigItem {
    id: root

    readonly property int nestingLevel: sectionPath.length - 1
    property bool pickerOpen: false

    implicitHeight: pickerOpen ? 56 + pickerContainer.height + Appearance.spacing.normal : 56

    // Subtle background for nested items
    Rectangle {
        anchors.fill: parent
        color: nestingLevel > 1 ? Qt.rgba(
            Colours.palette.m3surfaceContainerHighest.r,
            Colours.palette.m3surfaceContainerHighest.g,
            Colours.palette.m3surfaceContainerHighest.b,
            0.15 * (nestingLevel - 1)
        ) : "transparent"
        radius: Appearance.rounding.small
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.leftMargin: Appearance.padding.normal
        anchors.rightMargin: Appearance.padding.normal
        spacing: Appearance.spacing.small

        // Main row
        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 56
            spacing: Appearance.spacing.normal

            StyledText {
                Layout.fillWidth: true
                text: ConfigParser.formatPropertyName(root.propertyData.name)
                font.pointSize: Appearance.font.size.normal
                color: Colours.palette.m3onSurface
            }

            // Current font preview
            StyledRect {
                Layout.preferredWidth: 200
                Layout.preferredHeight: 36
                radius: Appearance.rounding.small
                color: Colours.palette.m3surfaceContainerHigh

                StyledText {
                    anchors.centerIn: parent
                    anchors.margins: Appearance.padding.small
                    text: root.currentValue ?? "Default"
                    font.family: root.currentValue ?? Appearance.font.family.sans
                    font.pointSize: Appearance.font.size.normal
                    color: Colours.palette.m3onSurface
                    elide: Text.ElideRight
                    width: parent.width - Appearance.padding.normal * 2
                    horizontalAlignment: Text.AlignHCenter
                }
            }

            // Toggle picker button
            StyledRect {
                Layout.preferredWidth: 100
                Layout.preferredHeight: 36
                radius: Appearance.rounding.small
                color: root.pickerOpen ? Colours.palette.m3primaryContainer : Colours.palette.m3surfaceContainerHigh

                StateLayer {
                    radius: parent.radius
                    function onClicked(): void {
                        root.pickerOpen = !root.pickerOpen;
                    }
                }

                RowLayout {
                    anchors.centerIn: parent
                    spacing: Appearance.spacing.small

                    MaterialIcon {
                        text: root.pickerOpen ? "expand_less" : "expand_more"
                        font.pointSize: Appearance.font.size.normal
                        color: root.pickerOpen ? Colours.palette.m3onPrimaryContainer : Colours.palette.m3onSurface
                    }

                    StyledText {
                        text: qsTr("Pick")
                        font.pointSize: Appearance.font.size.smaller
                        color: root.pickerOpen ? Colours.palette.m3onPrimaryContainer : Colours.palette.m3onSurface
                    }
                }
            }
        }

        // Font picker container
        Item {
            id: pickerContainer
            Layout.fillWidth: true
            Layout.preferredHeight: visible ? 300 : 0
            visible: root.pickerOpen
            clip: true

            Behavior on Layout.preferredHeight {
                Anim { duration: Appearance.anim.durations.normal }
            }

            StyledRect {
                anchors.fill: parent
                radius: Appearance.rounding.normal
                color: Colours.palette.m3surfaceContainer

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: Appearance.padding.normal
                    spacing: Appearance.spacing.small

                    // Search field
                    StyledRect {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 40
                        radius: Appearance.rounding.small
                        color: Colours.palette.m3surfaceContainerHigh

                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: Appearance.padding.small
                            spacing: Appearance.spacing.small

                            MaterialIcon {
                                text: "search"
                                font.pointSize: Appearance.font.size.normal
                                color: Colours.palette.m3onSurfaceVariant
                            }

                            StyledTextField {
                                id: searchField
                                Layout.fillWidth: true
                                placeholderText: qsTr("Search fonts...")
                                background: null
                            }
                        }
                    }

                    // Recommended fonts section
                    StyledText {
                        visible: searchField.text === ""
                        text: qsTr("Recommended")
                        font.pointSize: Appearance.font.size.small
                        font.weight: Font.Medium
                        color: Colours.palette.m3onSurfaceVariant
                    }

                    // Font list
                    ListView {
                        id: fontList
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true
                        spacing: 2

                        model: searchField.text === "" ? 
                            FontDatabase.recommendedFonts.filter(f => FontDatabase.fontList.includes(f)) :
                            FontDatabase.searchFonts(searchField.text)

                        ScrollBar.vertical: StyledScrollBar {}

                        delegate: StyledRect {
                            required property string modelData
                            required property int index

                            width: fontList.width
                            height: 44
                            radius: Appearance.rounding.small
                            color: root.currentValue === modelData ? 
                                Colours.palette.m3primaryContainer : "transparent"

                            StateLayer {
                                radius: parent.radius
                                function onClicked(): void {
                                    root.updateValue(parent.modelData);
                                    root.pickerOpen = false;
                                }
                            }

                            RowLayout {
                                anchors.fill: parent
                                anchors.margins: Appearance.padding.normal
                                spacing: Appearance.spacing.normal

                                StyledText {
                                    Layout.fillWidth: true
                                    text: modelData
                                    font.family: modelData
                                    font.pointSize: Appearance.font.size.normal
                                    color: root.currentValue === modelData ?
                                        Colours.palette.m3onPrimaryContainer : Colours.palette.m3onSurface
                                    elide: Text.ElideRight
                                }

                                // Preview text
                                StyledText {
                                    text: "Aa Bb 123"
                                    font.family: modelData
                                    font.pointSize: Appearance.font.size.small
                                    color: Colours.palette.m3onSurfaceVariant
                                    opacity: 0.7
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    Behavior on implicitHeight {
        Anim { duration: Appearance.anim.durations.normal }
    }
}
