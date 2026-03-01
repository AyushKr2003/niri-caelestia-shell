pragma ComponentBehavior: Bound

import Caelestia
import Quickshell.Widgets
import QtQuick

IconImage {
    id: root

    required property color colour
    property alias dominantColour: analyser.dominantColour

    asynchronous: true
    visible: status === Image.Ready || status === Image.Loading

    layer.enabled: status === Image.Ready
    layer.effect: Colouriser {
        sourceColor: root.dominantColour
        colorizationColor: root.colour
    }

    ImageAnalyser {
        id: analyser
        sourceItem: root.status === Image.Ready ? root : null
    }
}
