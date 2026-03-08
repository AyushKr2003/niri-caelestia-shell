import qs.components
import qs.services
import qs.config
import qs.utils
import QtQuick

Item {
    id: root

    anchors.centerIn: parent

    implicitWidth: content.implicitWidth + Appearance.padding.lg * 2
    implicitHeight: content.implicitHeight + Appearance.padding.md * 2

    Component.onCompleted: Weather.reload()

    // Today's high/low from forecast
    readonly property var today: Weather.forecast && Weather.forecast.length > 0 ? Weather.forecast[0] : null
    readonly property string highLow: {
        if (!today) return "";
        if (Config.services.useFahrenheit)
            return "↑" + today.maxTempF + "°  ↓" + today.minTempF + "°";
        return "↑" + today.maxTempC + "°  ↓" + today.minTempC + "°";
    }


    Row {
        id: content
        anchors.centerIn: parent
        spacing: Appearance.spacing.xxl

        Column {
            anchors.verticalCenter: parent.verticalCenter
            spacing: Appearance.spacing.xs

            MaterialIcon {
                id: icon
                anchors.horizontalCenter: parent.horizontalCenter

                animate: true
                text: Weather.error ? "cloud_alert" : Weather.icon
                color: Weather.error ? Colours.palette.m3error : Colours.palette.m3secondary
                font.pointSize: Appearance.font.size.headlineLarge * 2
            }

            // Description below icon
            // StyledText {
            //     anchors.horizontalCenter: parent.horizontalCenter
            //     visible: !Weather.error
            //     animate: true
            //     text: Weather.description
            //     font.pointSize: Appearance.font.size.labelMedium
            //     color: Colours.palette.m3onSurfaceVariant
            // }
        }

        Column {
            id: info

            anchors.verticalCenter: parent.verticalCenter
            spacing: Appearance.spacing.xs

            // Temperature
            StyledText {
                animate: true
                text: Weather.error ? Weather.error : Weather.temp
                color: Weather.error ? Colours.palette.m3error : Colours.palette.m3primary
                font.pointSize: Weather.error ? Appearance.font.size.bodyMedium : Appearance.font.size.headlineLarge
                font.weight: 600
            }

            // High / Low temps
            StyledText {
                visible: !Weather.error && root.highLow !== ""
                animate: true
                text: root.highLow
                color: Colours.palette.m3onSurfaceVariant
                font.pointSize: Appearance.font.size.labelLarge
                font.weight: 500
                opacity: 0.85
            }


            // City
            StyledText {
                visible: !Weather.error && Weather.city !== ""
                animate: true
                text: "  " + Weather.city
                color: Colours.palette.m3onSurfaceVariant
                font.pointSize: Appearance.font.size.labelSmall
                font.weight: 400
                opacity: 0.7
                elide: Text.ElideRight
                width: Math.min(implicitWidth, root.parent ? root.parent.width - icon.implicitWidth - content.spacing - Appearance.padding.xl * 2 : implicitWidth)
            }
        }
    }
}
