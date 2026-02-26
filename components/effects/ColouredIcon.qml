pragma ComponentBehavior: Bound

import Caelestia
import Quickshell.Widgets
import QtQuick

IconImage {
    id: root

    required property color colour
    property color dominantColour
    property bool _dominantReady: false

    asynchronous: true
    visible: status === Image.Ready || status === Image.Loading

    layer.enabled: _dominantReady
    layer.effect: Colouriser {
        sourceColor: root.dominantColour
        colorizationColor: root.colour
    }

    function _requestDominant(): void {
        if (status === Image.Ready)
            CUtils.getDominantColour(root, c => { dominantColour = c; _dominantReady = true; });
    }

    Component.onCompleted: _requestDominant()

    onStatusChanged: {
        if (status === Image.Ready)
            _requestDominant();
    }
}
