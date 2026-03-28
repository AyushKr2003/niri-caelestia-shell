import qs.components
import qs.config
import Quickshell
import QtQuick
import "./"

Item {
    id: root

    required property var visibilities

    visible: width > 0
    implicitWidth: 0
    implicitHeight: parent.height

    states: State {
        name: "visible"
        when: root.visibilities.manga

        PropertyChanges {
            root.implicitWidth: 600
        }
    }

    transitions: [
        Transition {
            from: ""
            to: "visible"

            Anim {
                target: root
                property: "implicitWidth"
                duration: Appearance.anim.durations.normal
                easing.bezierCurve: Appearance.anim.curves.emphasizedDecel
            }
        },
        Transition {
            from: "visible"
            to: ""

            Anim {
                target: root
                property: "implicitWidth"
                duration: Appearance.anim.durations.normal
                easing.bezierCurve: Appearance.anim.curves.emphasizedAccel
            }
        }
    ]

    MangaReader {
        id: mangaReader
        width: 600
        height: parent.height
        anchors.left: parent.left
        visible: root.visible
        visibilities: root.visibilities
    }

    clip: true
}
