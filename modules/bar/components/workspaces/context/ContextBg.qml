pragma ComponentBehavior: Bound

import qs.services
import qs.config
import QtQuick
import qs.components.effects
import qs.components

Item {
    id: root

    required property int groupOffset
    required property int wsOffset
    required property Item anchorWs

    // --- Helpers ---
    readonly property bool isItem: Niri.wsContextType === "item"
    readonly property bool isWorkspaces: Niri.wsContextType === "workspaces"
    readonly property bool isWorkspace: Niri.wsContextType === "workspace"
    readonly property bool hasWindows: (isItem && anchorWs.wsWindowCount > 0) || (isWorkspace && anchorWs.isOccupied)
    readonly property bool isFocused: (isItem && anchorWs.isWsFocused) || (isWorkspace && (Number(anchorWs.index) === Number(Niri.focusedWorkspaceIndex)))

    readonly property int rounding: Appearance.rounding.small
    readonly property int gPadding: isItem ? Appearance.padding.small / 2 : 0
    readonly property int cornerPieceSize: Config.bar.workspaces.windowIconSize + Appearance.padding.small

    property bool activated: false
    Component.onCompleted: root.activated = true

    property color bgColor: isWorkspaces ? Colours.palette.m3surfaceContainer : ((isFocused) ? Qt.alpha(Colours.palette.m3primary, 0.95) : (hasWindows ? Colours.palette.m3surfaceContainerHigh : "transparent"))

    // --- Highlight Rect ---
    component HighlightRect: Rectangle {
        id: hrect

        color: root.bgColor

        width: root.activated && Niri.wsContextAnchor ? Config.bar.workspaces.windowContextWidth + Config.bar.workspaces.windowIconSize : Config.bar.workspaces.windowIconSize
        height: (root.anchorWs?.height ?? 0) + root.gPadding * 2

        x: 0
        y: root.anchorWs?.mapToItem(root, 0, 0).y - root.gPadding ?? 0

        radius: root.rounding
        topRightRadius: Appearance.rounding.normal
        bottomRightRadius: Appearance.rounding.normal

        Behavior on color {
            CAnim {
                easing.bezierCurve: Appearance.anim.curves.emphasized
            }
        }

        Behavior on radius {
            Anim {
                easing.bezierCurve: Appearance.anim.curves.emphasized
            }
        }
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

        Behavior on width {
            Anim {
                easing.bezierCurve: Appearance.anim.curves.emphasized
            }
        }
        Behavior on height {
            Anim {
                easing.bezierCurve: Appearance.anim.curves.emphasized
            }
        }
        Behavior on opacity {
            Anim {
                easing.bezierCurve: Appearance.anim.curves.emphasized
            }
        }

        Behavior on x {
            Anim {
                easing.bezierCurve: Appearance.anim.curves.emphasized
            }
        }
        Behavior on y {
            Anim {
                easing.bezierCurve: Appearance.anim.curves.emphasized
            }
        }
    }

    HighlightRect {
        id: highlightLow
        color: !root.isWorkspaces ? Colours.palette.m3surfaceContainer : "transparent"

        anchors.fill: highlight

        anchors.margins: -Appearance.padding.small

        anchors.leftMargin: Config.bar.workspaces.windowIconSize
        topLeftRadius: 0
        bottomLeftRadius: 0

        Corner {
            property bool firstWorkspace: (root.isWorkspace && root.anchorWs.index === 0)
            cornerType: 2

            height: !(Niri.wsContextAnchor || root.activated) || (firstWorkspace) ? 0 : root.cornerPieceSize
        }
        Corner {
            property bool lastWindowNWorkspace: (root.isItem && ((root.anchorWs.curWindowIndex === root.anchorWs.wsWindowCount - 1) && (root.anchorWs.workspace.index === Config.bar.workspaces.shown - 1)))
            property bool lastWorkspace: (root.isWorkspace && root.anchorWs.index === Config.bar.workspaces.shown - 1)

            cornerType: 0
            height: !(Niri.wsContextAnchor || root.activated) || (lastWorkspace || (lastWindowNWorkspace)) ? 0 : root.cornerPieceSize
        }
    }

    HighlightRect {
        id: highlight

        topRightRadius: Appearance.rounding.small
        bottomRightRadius: Appearance.rounding.small

        Corner {
            cornerType: 2
            anchors.leftMargin: Config.bar.workspaces.windowIconSize - 1
            height: !(Niri.wsContextAnchor || root.activated) || root.isWorkspace ? 0 : root.cornerPieceSize
        }
        Corner {
            property bool lastWindow: (root.isItem && (root.anchorWs.curWindowIndex === root.anchorWs.wsWindowCount - 1))

            cornerType: 0
            anchors.leftMargin: Config.bar.workspaces.windowIconSize - 1
            height: !(Niri.wsContextAnchor || root.activated) || (root.isWorkspace || lastWindow) ? 0 : root.cornerPieceSize
        }
    }

    // --- Optional corner piece (if needed later) ---
    component Corner: CornerPiece {
        property int cornerType: 0 // 1 = bottom, 3 = top
        width: root.activated && !root.isWorkspaces && Niri.wsContextAnchor ? root.cornerPieceSize : 0
        height: root.cornerPieceSize
        radius: Appearance.padding.large * 1.3
        orientation: cornerType
        color: parent.color

        anchors.left: parent.left
        anchors.leftMargin: Appearance.padding.small
        anchors.top: cornerType === 0 ? parent.bottom : undefined
        anchors.bottom: cornerType === 2 ? parent.top : undefined
        anchors.topMargin: cornerType === 0 ? -1 : undefined
        anchors.bottomMargin: cornerType === 2 ? -1 : undefined

        Behavior on height {
            Anim {
                easing.bezierCurve: Appearance.anim.curves.emphasized
            }
        }

        Behavior on width {
            Anim {
                easing.bezierCurve: Appearance.anim.curves.emphasized
            }
        }

        Behavior on anchors.leftMargin {
            Anim {
                easing.bezierCurve: Appearance.anim.curves.emphasized
            }
        }
    }
}
