import qs.components
import qs.services
import qs.config
import qs.utils
import QtQuick

Item {
    id: root

    anchors.centerIn: parent

    implicitWidth: icon.implicitWidth + info.implicitWidth + info.anchors.leftMargin

    Component.onCompleted: Weather.reload()

    MaterialIcon {
        id: icon

        anchors.verticalCenter: parent.verticalCenter
        anchors.left: parent.left

        animate: true
        text: Weather.error ? "cloud_alert" : Weather.icon
        color: Weather.error ? Colours.palette.m3error : Colours.palette.m3secondary
        font.pointSize: Appearance.font.size.extraLarge * 2
    }

    Column {
        id: info

        anchors.verticalCenter: parent.verticalCenter
        anchors.left: icon.right
        anchors.leftMargin: Appearance.spacing.large

        spacing: Appearance.spacing.small

        StyledText {
            anchors.horizontalCenter: parent.horizontalCenter

            animate: true
            text: Weather.error ? Weather.error : Weather.temp
            color: Weather.error ? Colours.palette.m3error : Colours.palette.m3primary
            font.pointSize: Weather.error ? Appearance.font.size.normal : Appearance.font.size.extraLarge
            font.weight: 500
        }

        StyledText {
            anchors.horizontalCenter: parent.horizontalCenter
            visible: !Weather.error

            animate: true
            text: Weather.description

            elide: Text.ElideRight
            width: Math.min(implicitWidth, root.parent.width - icon.implicitWidth - info.anchors.leftMargin - Appearance.padding.large * 2)
        }
    }
}
