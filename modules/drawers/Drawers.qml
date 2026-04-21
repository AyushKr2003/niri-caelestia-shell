pragma ComponentBehavior: Bound

import qs.components
import qs.components.containers
import qs.services
import qs.config
import qs.modules.bar
import Quickshell
import Quickshell.Wayland
import QtQuick
import QtQuick.Effects

Variants {
    model: Quickshell.screens

    Scope {
        id: scope

        required property ShellScreen modelData

        Exclusions {
            screen: scope.modelData
            bar: bar
            borderThickness: win.borderThickness
        }

        StyledWindow {
            id: win

            screen: scope.modelData
            name: "drawers"
            WlrLayershell.exclusionMode: ExclusionMode.Ignore
            WlrLayershell.keyboardFocus: visibilities.launcher || visibilities.session || visibilities.keybinds || visibilities.editingWeatherLocation || visibilities.dashboard || visibilities.manga || visibilities.novel || panels.popouts.isDetached ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
            WlrLayershell.layer: hasFullscreen ? WlrLayer.Overlay : WlrLayer.Top

            readonly property var currentWorkspace: Niri.allWorkspaces.find(w => w.output === screen.name && w.is_active)
            readonly property bool hasFullscreen: currentWorkspace ? Niri.windows.some(w => w.workspace_id === currentWorkspace.id && w.is_fullscreen) : false
            property real borderThickness: hasFullscreen ? 0 : Config.border.thickness
            readonly property real borderLayoutThickness: hasFullscreen ? 0 : Config.border.thickness
            property real borderRounding: hasFullscreen ? 0 : Config.border.rounding
            property real shadowOpacity: hasFullscreen ? 0 : 0.7

            Behavior on borderRounding {
                NumberAnimation {
                    duration: Appearance.anim.durations.expressiveDefaultSpatial
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: Appearance.anim.curves.expressiveDefaultSpatial
                }
            }

            Behavior on shadowOpacity {
                NumberAnimation {
                    duration: Appearance.anim.durations.expressiveDefaultSpatial
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: Appearance.anim.curves.expressiveDefaultSpatial
                }
            }

            mask: Region {
                x: bar.implicitWidth
                y: win.borderLayoutThickness
                width: win.width - bar.implicitWidth - win.borderLayoutThickness
                height: win.height - win.borderLayoutThickness * 2
                intersection: Intersection.Xor

                regions: regions.instances
            }

            anchors.top: true
            anchors.bottom: true
            anchors.left: true
            anchors.right: true

            Variants {
                id: regions

                model: panels.children

                Region {
                    required property Item modelData

                    x: modelData.x + bar.implicitWidth
                    y: modelData.y + win.borderLayoutThickness
                    width: modelData.width
                    height: modelData.height
                    intersection: Intersection.Subtract
                }
            }

            // TODO: Implement focus grab for Niri when available

            StyledRect {
                anchors.fill: parent
                opacity: visibilities.session && Config.session.enabled ? 0.5 : 0
                color: Colours.palette.m3scrim

                Behavior on opacity {
                    Anim {}
                }
            }

            Item {
                anchors.fill: parent
                opacity: Colours.transparency.enabled ? Colours.transparency.base : 1
                layer.enabled: true
                layer.effect: MultiEffect {
                    shadowEnabled: true
                    blurMax: 15
                    shadowColor: Qt.alpha(Colours.palette.m3shadow, Math.max(0, win.shadowOpacity))
                }

                Border {
                    bar: bar
                    borderThickness: win.borderThickness
                    borderRounding: win.borderRounding
                }

                Backgrounds {
                    panels: panels
                    bar: bar
                    borderThickness: win.borderThickness
                    borderRounding: win.borderRounding
                }
            }

            PersistentProperties {
                id: visibilities

                property bool bar
                property bool osd
                property bool session
                property bool launcher
                property bool dashboard
                property bool utilities
                property bool clipboardRequested
                property bool quicktoggles
                property bool keybinds
                property bool editingWeatherLocation
                property bool notifsExpanded
                property bool manga
                property bool novel

                Component.onCompleted: Visibilities.screens[scope.modelData.name] = this
            }

            Interactions {
                screen: scope.modelData
                popouts: panels.popouts
                visibilities: visibilities
                panels: panels
                bar: bar
                fullscreen: win.hasFullscreen

                Panels {
                    id: panels

                    screen: scope.modelData
                    visibilities: visibilities
                    bar: bar
                    borderThickness: win.borderThickness
                }

                BarWrapper {
                    id: bar

                    anchors.top: parent.top
                    anchors.bottom: parent.bottom

                    screen: scope.modelData
                    visibilities: visibilities
                    popouts: panels.popouts
                    fullscreen: win.hasFullscreen

                    Component.onCompleted: Visibilities.bars.set(scope.modelData, this)
                }
            }
        }
    }

}
