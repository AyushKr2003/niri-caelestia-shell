pragma ComponentBehavior: Bound

import qs.components
import qs.services
import qs.config
import QtQuick
import QtQuick.Effects

Item {
    id: root

    required property Item bar
    required property real borderThickness
    required property real borderRounding

    anchors.fill: parent
    visible: root.borderThickness > 0

    StyledRect {
        anchors.fill: parent
        color: Colours.palette.m3surface

        layer.enabled: root.visible
        layer.effect: MultiEffect {
            maskSource: mask
            maskEnabled: true
            maskInverted: true
            maskThresholdMin: 0.5
            maskSpreadAtMin: 1
        }
    }

    Item {
        id: mask

        anchors.fill: parent
        layer.enabled: root.visible
        visible: false

        Rectangle {
            anchors.fill: parent
            anchors.margins: root.borderThickness
            anchors.leftMargin: root.bar.implicitWidth
            radius: root.borderRounding
        }
    }
}
