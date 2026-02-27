pragma ComponentBehavior: Bound

import qs.components
import qs.services
import qs.config
import Quickshell
import QtQuick

Item {
    id: root

    required property Repeater workspaces
    required property var occupied
    required property int groupOffset

    property list<var> pills: []

    onGroupOffsetChanged: buildPills()
    onOccupiedChanged: buildPills()

    function buildPills() {
        let count = 0;
        const start = groupOffset;
        const end = start + Config.bar.workspaces.shown;
        for (const [ws, occ] of Object.entries(occupied)) {
            if (ws > start && ws <= end && occ) {
                if (!occupied[ws - 1]) {
                    if (pills[count])
                        pills[count].start = ws;
                    else
                        pills.push(pillComp.createObject(root, {
                            start: ws
                        }));
                    count++;
                }
                if (!occupied[ws + 1])
                    pills[count - 1].end = ws;
            }
        }
        if (pills.length > count)
            pills.splice(count, pills.length - count).forEach(p => p.destroy());
    }

    Repeater {
        model: ScriptModel {
            values: root.pills.filter(p => p)
        }

        StyledRect {
            id: rect

            required property var modelData

            readonly property Workspace start: root.workspaces.itemAt(getWsIdx(modelData.start)) ?? null
            readonly property Workspace end: root.workspaces.itemAt(getWsIdx(modelData.end)) ?? null
            property bool isContextActiveInWs: Niri.wsContextType === "workspaces" && Niri.wsContextAnchor
            function getWsIdx(ws: int): int {
                let i = ws - 1;
                while (i < 0)
                    i += Config.bar.workspaces.shown;
                return i % Config.bar.workspaces.shown;
            }

            anchors {
                // horizontalCenter: root.horizontalCenter
                left: root.left
                right: root.right
                rightMargin: isContextActiveInWs ? -Config.bar.workspaces.windowContextWidth + Appearance.padding.small : 0
            }

            topRightRadius: isContextActiveInWs ? Appearance.rounding.normal : radius
            bottomRightRadius: isContextActiveInWs ? Appearance.rounding.normal : radius

            y: (start?.y ?? 0)
            // implicitWidth: Config.bar.sizes.innerWidth - Appearance.padding.small * 2 + 2
            implicitHeight: start && end ? end.y + end.size - start.y : 0
            // implicitHeight: end?.y + end?.height - start?.y

            color: Colours.palette.m3primary
            radius: Appearance.rounding.small

            scale: 0
            Component.onCompleted: scale = 1.0

            Behavior on topRightRadius {
                Anim {
                    easing.bezierCurve: Appearance.anim.curves.emphasized
                }
            }
            Behavior on bottomRightRadius {
                Anim {
                    easing.bezierCurve: Appearance.anim.curves.emphasized
                }
            }

            Behavior on scale {
                Anim {
                    easing.bezierCurve: Appearance.anim.curves.standardDecel
                }
            }

            Behavior on anchors.rightMargin {
                Anim {
                    duration: Appearance.anim.durations.normal
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: Appearance.anim.curves.emphasized
                }
            }

            Behavior on y {
                Anim {}
            }

            Behavior on implicitHeight {
                Anim {}
            }
        }
    }

    component Pill: QtObject {
        property int start
        property int end
    }

    Component {
        id: pillComp

        Pill {}
    }
}
