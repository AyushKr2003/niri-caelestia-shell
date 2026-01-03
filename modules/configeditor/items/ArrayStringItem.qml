import "../"
import qs.components
import qs.components.controls
import qs.services
import qs.config
import Quickshell
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// Component for editing string items in an array (like terminal commands)
StyledRect {
    id: root

    required property string value
    required property int itemIndex

    signal remove()
    signal update(string newValue)

    implicitHeight: 44
    radius: Appearance.rounding.small
    color: Colours.palette.m3surfaceContainerLow

    RowLayout {
        anchors.fill: parent
        anchors.margins: Appearance.padding.small
        spacing: Appearance.spacing.small

        // Index badge
        StyledRect {
            Layout.preferredWidth: 24
            Layout.preferredHeight: 24
            radius: Appearance.rounding.full
            color: Colours.palette.m3secondaryContainer

            StyledText {
                anchors.centerIn: parent
                text: (root.itemIndex + 1).toString()
                font.pointSize: Appearance.font.size.extraSmall
                font.weight: Font.Medium
                color: Colours.palette.m3onSecondaryContainer
            }
        }

        // Text field
        StyledRect {
            Layout.fillWidth: true
            Layout.fillHeight: true
            radius: Appearance.rounding.small
            color: Colours.palette.m3surfaceContainerHigh

            StyledTextField {
                anchors.fill: parent
                anchors.margins: Appearance.padding.small
                text: root.value
                background: null
                onEditingFinished: root.update(text)
            }
        }

        // Delete button
        StyledRect {
            Layout.preferredWidth: 28
            Layout.preferredHeight: 28
            radius: Appearance.rounding.full
            color: "transparent"

            StateLayer {
                radius: parent.radius
                color: Colours.palette.m3error
                function onClicked(): void {
                    root.remove();
                }
            }

            MaterialIcon {
                anchors.centerIn: parent
                text: "close"
                font.pointSize: Appearance.font.size.smaller
                color: Colours.palette.m3error
            }
        }
    }
}
