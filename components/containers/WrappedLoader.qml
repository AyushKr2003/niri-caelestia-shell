import QtQuick
import QtQuick.Layouts

// Reusable loader wrapper for conditional components with Layout support
// Provides enabled/disabled state management with proper visibility and loading

Loader {
    id: root

    // Required properties that must be bound by parent
    required property bool enabled
    required property string id
    required property int index

    // Optional: reference to parent repeater for first/last detection
    property var repeater: null
    property real vPadding: 0

    // Find first enabled item in repeater
    function findFirstEnabled(): Item {
        if (!repeater) return null;
        const count = repeater.count;
        for (let i = 0; i < count; i++) {
            const item = repeater.itemAt(i);
            if (item?.enabled) return item;
        }
        return null;
    }

    // Find last enabled item in repeater
    function findLastEnabled(): Item {
        if (!repeater) return null;
        for (let i = repeater.count - 1; i >= 0; i--) {
            const item = repeater.itemAt(i);
            if (item?.enabled) return item;
        }
        return null;
    }

    Layout.alignment: Qt.AlignHCenter

    // Add padding to first and last enabled components when repeater is set
    Layout.topMargin: repeater && findFirstEnabled() === this ? vPadding : 0
    Layout.bottomMargin: repeater && findLastEnabled() === this ? vPadding : 0

    visible: enabled
    active: enabled
}
