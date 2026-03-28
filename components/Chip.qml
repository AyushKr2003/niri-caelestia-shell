import qs.services
import qs.config
import QtQuick
import QtQuick.Layouts

StyledRect {
    id: root

    property string text
    property string icon
    property bool selected: false
    property bool closable: false

    signal clicked()
    signal closeClicked()

    radius: Appearance.rounding.small
    implicitWidth: row.implicitWidth + Appearance.padding.md * 2
    implicitHeight: row.implicitHeight + Appearance.padding.xs * 2

    color: selected ? Colours.palette.m3secondaryContainer : "transparent"
    border.width: selected ? 0 : 1
    border.color: Colours.palette.m3outline

    StateLayer {
        radius: root.radius
        color: selected ? Colours.palette.m3onSecondaryContainer : Colours.palette.m3onSurface

        function onClicked(): void {
            root.clicked();
        }
    }

    RowLayout {
        id: row

        anchors {
            verticalCenter: parent ? parent.verticalCenter : undefined
            horizontalCenter: parent ? parent.horizontalCenter : undefined
        }
        spacing: Appearance.spacing.xs

        MaterialIcon {
            visible: root.icon.length > 0
            text: root.icon
            font.pointSize: Appearance.font.size.labelLarge
            color: selected ? Colours.palette.m3onSecondaryContainer : Colours.palette.m3onSurfaceVariant
        }

        StyledText {
            text: root.text
            font.pointSize: Appearance.font.size.labelLarge
            color: selected ? Colours.palette.m3onSecondaryContainer : Colours.palette.m3onSurfaceVariant
        }

        MaterialIcon {
            visible: root.closable
            text: "close"
            font.pointSize: Appearance.font.size.labelLarge
            color: selected ? Colours.palette.m3onSecondaryContainer : Colours.palette.m3onSurfaceVariant

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: root.closeClicked()
            }
        }
    }
}
