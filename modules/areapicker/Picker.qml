pragma ComponentBehavior: Bound

import qs.components
import qs.services
import qs.config
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import QtQuick.Effects

MouseArea {
    id: root

    required property LazyLoader loader
    required property ShellScreen screen

    // Niri doesn't expose border/rounding config, use sensible defaults
    property int borderWidth: 2
    property int rounding: 8

    property bool onClient

    property real realBorderWidth: onClient ? borderWidth : 2
    property real realRounding: onClient ? rounding : 0

    property real ssx
    property real ssy

    property real sx: 0
    property real sy: 0
    property real ex: screen.width
    property real ey: screen.height

    property real rsx: Math.min(sx, ex)
    property real rsy: Math.min(sy, ey)
    property real sw: Math.abs(sx - ex)
    property real sh: Math.abs(sy - ey)

    // Get windows in current workspace using Niri service
    property var clients: {
        if (!Niri.niriAvailable) return [];
        // Get windows filtered to current workspace
        const wsWindows = Niri.getActiveWorkspaceWindows();
        // Sort by layout position (column, then row)
        return wsWindows.slice().sort((a, b) => {
            const aPos = a.layout?.pos_in_scrolling_layout || [0, 0];
            const bPos = b.layout?.pos_in_scrolling_layout || [0, 0];
            // Sort by column first, then row
            if (aPos[0] !== bPos[0]) return aPos[0] - bPos[0];
            return aPos[1] - bPos[1];
        });
    }

    // Get window geometry from Niri's layout data
    // Niri provides window_size in layout but not absolute position on screen
    // We need to compute position based on the focused window and layout offsets
    function getWindowGeometry(window) {
        if (!window?.layout?.window_size) return null;
        
        const size = window.layout.window_size;
        const pos = window.layout.pos_in_scrolling_layout || [0, 0];
        
        // For Niri, we estimate window position based on layout
        // This is approximate since Niri uses scrolling layout
        const focusedWindow = Niri.focusedWindow;
        if (!focusedWindow?.layout?.pos_in_scrolling_layout) {
            // Fallback: center the window
            return {
                x: (screen.width - size[0]) / 2,
                y: (screen.height - size[1]) / 2,
                w: size[0],
                h: size[1]
            };
        }
        
        const focusedPos = focusedWindow.layout.pos_in_scrolling_layout;
        const focusedSize = focusedWindow.layout.window_size || [screen.width, screen.height];
        
        // Calculate offset from focused window
        const colOffset = pos[0] - focusedPos[0];
        const rowOffset = pos[1] - focusedPos[1];
        
        // Estimate focused window's screen position (centered or left-aligned)
        const focusedX = focusedSize[0] < screen.width ? (screen.width - focusedSize[0]) / 2 : 0;
        const focusedY = focusedSize[1] < screen.height ? (screen.height - focusedSize[1]) / 2 : 0;
        
        return {
            x: focusedX + (colOffset * size[0]),
            y: focusedY + (rowOffset * size[1]),
            w: size[0],
            h: size[1]
        };
    }

    function checkClientRects(x: real, y: real): void {
        for (const client of clients) {
            const geom = getWindowGeometry(client);
            if (!geom) continue;
            
            const cx = geom.x;
            const cy = geom.y;
            const cw = geom.w;
            const ch = geom.h;
            
            if (cx <= x && cy <= y && cx + cw >= x && cy + ch >= y) {
                onClient = true;
                sx = cx;
                sy = cy;
                ex = cx + cw;
                ey = cy + ch;
                break;
            }
        }
    }

    anchors.fill: parent
    opacity: 0
    hoverEnabled: true
    cursorShape: Qt.CrossCursor

    Component.onCompleted: {
        // Break binding if frozen
        if (loader.freeze)
            clients = clients;

        opacity = 1;

        const c = clients[0];
        if (c) {
            const geom = getWindowGeometry(c);
            if (geom) {
                onClient = true;
                sx = geom.x;
                sy = geom.y;
                ex = geom.x + geom.w;
                ey = geom.y + geom.h;
            } else {
                sx = screen.width / 2 - 100;
                sy = screen.height / 2 - 100;
                ex = screen.width / 2 + 100;
                ey = screen.height / 2 + 100;
            }
        } else {
            sx = screen.width / 2 - 100;
            sy = screen.height / 2 - 100;
            ex = screen.width / 2 + 100;
            ey = screen.height / 2 + 100;
        }
    }

    onPressed: event => {
        ssx = event.x;
        ssy = event.y;
    }

    onReleased: {
        if (closeAnim.running)
            return;

        Quickshell.execDetached(["sh", "-c", `grim -l 0 -g '${screen.x + Math.ceil(rsx)},${screen.y + Math.ceil(rsy)} ${Math.floor(sw)}x${Math.floor(sh)}' - | swappy -f -`]);
        closeAnim.start();
    }

    onPositionChanged: event => {
        const x = event.x;
        const y = event.y;

        if (pressed) {
            onClient = false;
            sx = ssx;
            sy = ssy;
            ex = x;
            ey = y;
        } else {
            checkClientRects(x, y);
        }
    }

    focus: true
    Keys.onEscapePressed: closeAnim.start()

    SequentialAnimation {
        id: closeAnim

        PropertyAction {
            target: root.loader
            property: "closing"
            value: true
        }
        ParallelAnimation {
            Anim {
                target: root
                property: "opacity"
                to: 0
                duration: Appearance.anim.durations.large
            }
            ExAnim {
                target: root
                properties: "rsx,rsy"
                to: 0
            }
            ExAnim {
                target: root
                property: "sw"
                to: root.screen.width
            }
            ExAnim {
                target: root
                property: "sh"
                to: root.screen.height
            }
        }
        PropertyAction {
            target: root.loader
            property: "activeAsync"
            value: false
        }
    }

    // Listen for workspace changes via Niri service
    Connections {
        target: Niri

        function onFocusedWorkspaceIdChanged(): void {
            root.checkClientRects(root.mouseX, root.mouseY);
        }
    }

    // Niri config loading via niri msg
    // Note: Niri doesn't expose border/rounding config via IPC, using defaults above
    // If you want to read from niri config file, you'd need to parse ~/.config/niri/config.kdl

    Loader {
        anchors.fill: parent

        active: root.loader.freeze
        asynchronous: true

        sourceComponent: ScreencopyView {
            captureSource: root.screen
        }
    }

    StyledRect {
        anchors.fill: parent
        color: Colours.palette.m3secondaryContainer
        opacity: 0.3

        layer.enabled: true
        layer.effect: MultiEffect {
            maskSource: selectionWrapper
            maskEnabled: true
            maskInverted: true
            maskSpreadAtMin: 1
            maskThresholdMin: 0.5
        }
    }

    Item {
        id: selectionWrapper

        anchors.fill: parent
        layer.enabled: true
        visible: false

        Rectangle {
            id: selectionRect

            radius: root.realRounding
            x: root.rsx
            y: root.rsy
            implicitWidth: root.sw
            implicitHeight: root.sh
        }
    }

    Rectangle {
        color: "transparent"
        radius: root.realRounding > 0 ? root.realRounding + root.realBorderWidth : 0
        border.width: root.realBorderWidth
        border.color: Colours.palette.m3primary

        x: selectionRect.x - root.realBorderWidth
        y: selectionRect.y - root.realBorderWidth
        implicitWidth: selectionRect.implicitWidth + root.realBorderWidth * 2
        implicitHeight: selectionRect.implicitHeight + root.realBorderWidth * 2

        Behavior on border.color {
            CAnim {}
        }
    }

    Behavior on opacity {
        Anim {
            duration: Appearance.anim.durations.large
        }
    }

    Behavior on rsx {
        enabled: !root.pressed

        ExAnim {}
    }

    Behavior on rsy {
        enabled: !root.pressed

        ExAnim {}
    }

    Behavior on sw {
        enabled: !root.pressed

        ExAnim {}
    }

    Behavior on sh {
        enabled: !root.pressed

        ExAnim {}
    }

    component ExAnim: Anim {
        duration: Appearance.anim.durations.expressiveDefaultSpatial
        easing.bezierCurve: Appearance.anim.curves.expressiveDefaultSpatial
    }
}
