import qs.components
import qs.services
import qs.config
import QtQuick
import QtQuick.Layouts

// Lock status display - uses Niri service for reactive state
ColumnLayout {
    id: root

    spacing: Appearance.spacing.small

    StyledText {
        text: qsTr("Capslock: %1").arg(Niri.capsLock ? "Enabled" : "Disabled")
    }

    StyledText {
        text: qsTr("Numlock: %1").arg(Niri.numLock ? "Enabled" : "Disabled")
    }
}
