pragma ComponentBehavior: Bound

import qs.components
import qs.components.filedialog
import qs.config
import qs.utils
import qs.services
import Quickshell
import QtQuick
import Caelestia

Item {
    id: root

    required property PersistentProperties visibilities
    readonly property PersistentProperties state: PersistentProperties {
        property int currentTab
        property date currentDate: new Date()

        readonly property FileDialog facePicker: FileDialog {
            title: qsTr("Select a profile picture")
            filterLabel: qsTr("Image files")
            filters: Images.validImageExtensions
            onAccepted: path => {
                console.log("FileDialog accepted path:", path);
                if (CUtils.copyFile(Qt.resolvedUrl(path), Qt.resolvedUrl(`${Paths.home}/.face`)))
                    Quickshell.execDetached(["notify-send", "-a", "caelestia-shell", "-u", "low", "-h", `STRING:image-path:${path}`, "Profile picture changed", `Profile picture changed to ${Paths.shortenHome(path)}`]);
                else
                    Quickshell.execDetached(["notify-send", "-a", "caelestia-shell", "-u", "critical", "Unable to change profile picture", `Failed to change profile picture to ${Paths.shortenHome(path)}`]);
            }
        }
    }

    visible: height > 0
    implicitHeight: 0
    implicitWidth: content.implicitWidth

    states: [
        State {
            name: "open"
            when: root.visibilities.dashboard && Config.dashboard.enabled
            PropertyChanges {
                target: root
                implicitHeight: content.implicitHeight
            }
        }
    ]

    transitions: [
        Transition {
            from: ""
            to: "open"

            Anim {
                target: root
                property: "implicitHeight"
                duration: Appearance.anim.durations.expressiveDefaultSpatial
                easing.bezierCurve: Appearance.anim.curves.expressiveDefaultSpatial
            }
        },
        Transition {
            from: "open"
            to: ""

            Anim {
                target: root
                property: "implicitHeight"
                easing.bezierCurve: Appearance.anim.curves.emphasized
            }
        }
    ]

    Loader {
        id: content

        Component.onCompleted: active = Qt.binding(() => (root.visibilities.dashboard && Config.dashboard.enabled) || root.visible)

        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom

        sourceComponent: Content {
            visibilities: root.visibilities
            state: root.state
        }
    }
}
