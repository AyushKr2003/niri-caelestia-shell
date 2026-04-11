pragma ComponentBehavior: Bound

import qs.components.effects
import qs.services
import qs.config
import Quickshell.Services.SystemTray
import QtQuick

MouseArea {
    id: root

    required property SystemTrayItem modelData

    acceptedButtons: Qt.LeftButton | Qt.RightButton
    implicitWidth: Config.bar.tray.compact ? Appearance.font.size.labelLarge * 1.5 : Appearance.font.size.labelLarge * 1.8
    implicitHeight: implicitWidth

    onClicked: event => {
        if (event.button === Qt.LeftButton)
            modelData.activate();
        else
            modelData.secondaryActivate();
    }

    ColouredIcon {
        id: icon

        anchors.fill: parent
        anchors.margins: Appearance.padding.xs
        source: {
            let icon = root.modelData.icon;
            if (icon.includes("?path=")) {
                const [name, path] = icon.split("?path=");
                icon = `file://${path}/${name.slice(name.lastIndexOf("/") + 1)}`;
            }
            return icon;
        }
        colour: Colours.palette.m3secondary
        layer.enabled: Config.bar.tray.recolour && status === Image.Ready
    }
}
