pragma ComponentBehavior: Bound

import qs.components
import qs.services
import qs.config
import QtQuick
import QtQuick.Layouts

ColumnLayout {
    id: root

    property var client: null

    Connections {
        target: Niri // Listen to the Niri singleton
        function onFocusedWindowChanged(): void {
            root.client = Niri.focusedWindow || Niri.lastFocusedWindow || null;
        }
    }

    Component.onCompleted: {
        root.client = Niri.focusedWindow || Niri.lastFocusedWindow;
    }

    anchors.fill: parent
    spacing: Appearance.spacing.small

    // ***************************************************
    // Using the new CollapsibleSection component
    CollapsibleSection {
        id: moveWorkspaceDropdown // Give it an ID to reference its functions
        title: qsTr("Move to workspace")
        // The content for this dropdown is placed directly inside.
        // It automatically forms a Component and is assigned to contentComponent.
        GridLayout {
            id: wsGrid

            // rowSpacing: Appearance.spacing.smaller
            // columnSpacing: Appearance.spacing.smaller
            columns: 5

            Repeater {
                model: Niri.getWorkspaceCount()

                Button {
                    required property int index
                    readonly property int wsId: Math.floor((Niri.focusedWorkspaceIndex) / 10) * 10 + index + 1
                    readonly property bool isCurrent: (wsId - 1) % 10 === Niri.focusedWorkspaceIndex

                    color: isCurrent ? Colours.tPalette.m3surfaceContainerHighest : Colours.palette.m3tertiaryContainer
                    onColor: isCurrent ? Colours.palette.m3onSurface : Colours.palette.m3onTertiaryContainer
                    text: {
                        const ws = Niri.currentOutputWorkspaces[wsId - 1];
                        return ws?.name ?? String(wsId);
                    }
                    disabled: isCurrent

                    function onClicked(): void {
                        Niri.moveWindowToWorkspace(wsId);
                    // Call the collapse function on the CollapsibleSection instance
                    // moveWorkspaceDropdown.collapse();
                    }
                }
            }
        }
    }

    CollapsibleSection {
        id: utilities // Give it an ID to reference its functions
        title: qsTr("Utilities")
        backgroundMarginTop: 0

        //  toggleWindowOpacity
        //  expandColumnToAvailable
        //  centerWindow
        //  screenshotWindow
        //  keyboardShortcutsInhibitWindow
        //  toggleWindowedFullscreen
        //  toggleFullscreen
        //  toggleMaximize
        RowLayout {
            Layout.fillWidth: true
            // Layout.leftMargin: Appearance.padding.large
            // Layout.rightMargin: Appearance.padding.large

            Button {
                color: Colours.palette.m3secondaryContainer
                onColor: Colours.palette.m3onSecondaryContainer
                text: qsTr("Center")
                icon: "center_focus_strong"

                function onClicked(): void {
                    Niri.centerWindow();
                }
            }
            Button {
                color: Colours.palette.m3secondaryContainer
                onColor: Colours.palette.m3onSecondaryContainer
                text: qsTr("Screenshot")
                icon: "camera"
                // Layout.fillWidth: false

                function onClicked(): void {
                    Niri.screenshotWindow();
                }
            }
            Button {
                color: Colours.palette.m3secondaryContainer
                onColor: Colours.palette.m3onSecondaryContainer
                icon: "disabled_visible"
                text: qsTr("Inhibit Shortcuts")
                // Layout.fillWidth: false
                function onClicked(): void {
                    Niri.keyboardShortcutsInhibitWindow();
                }
            }
        }
    }

    // ***************************************************

    Loader {

        active: wrapper.isDetached
        asynchronous: true
        Layout.fillWidth: active
        visible: active
        Layout.leftMargin: Appearance.padding.large
        Layout.rightMargin: Appearance.padding.large
        Layout.bottomMargin: Appearance.padding.large

        sourceComponent: RowLayout {
            // Layout.fillWidth: true

            Button {
                readonly property bool isFloating: Niri.focusedWindow?.is_floating ?? false
                color: isFloating ? Colours.palette.m3primary : Colours.palette.m3secondaryContainer
                onColor: isFloating ? Colours.palette.m3onPrimary : Colours.palette.m3onSecondaryContainer
                text: root.client?.is_floating ? qsTr("Tile") : qsTr("Float")
                icon: root.client?.is_floating ? "grid_view" : "picture_in_picture"

                function onClicked(): void {
                    Niri.toggleWindowFloating();
                }
            }

            // Pin feature removed - Niri doesn't support window pinning
            // TODO: Implement alternative if Niri adds pin support in future

            Button {
                color: Colours.palette.m3secondaryContainer
                onColor: Colours.palette.m3onSecondaryContainer
                icon: "fullscreen"
                text: qsTr("Fullscreen")

                function onClicked(): void {
                    Niri.toggleMaximize();
                }
            }

            Button {
                color: Colours.palette.m3errorContainer
                onColor: Colours.palette.m3onErrorContainer
                text: qsTr("Kill")
                icon: "close"

                function onClicked(): void {
                    Niri.closeFocusedWindow();
                }
            }
        }
    }

    // Your global Button component (if defined here)
    component Button: StyledRect {
        property color onColor: Colours.palette.m3onSurface
        property alias disabled: stateLayer.disabled
        property alias text: label.text
        property alias icon: icon.text

        function onClicked(): void {
        }

        Layout.fillWidth: true

        radius: Appearance.rounding.small

        implicitHeight: (icon.implicitHeight + Appearance.padding.small * 2)
        implicitWidth: (52 + Appearance.padding.small * 2)

        MaterialIcon {
            id: icon
            color: parent.onColor
            font.pointSize: Appearance.font.size.large
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.verticalCenter: parent.verticalCenter

            opacity: icon.text ? !stateLayer.containsMouse : true
            Behavior on opacity {
                PropertyAnimation {
                    property: "opacity"
                    duration: Appearance.anim.durations.normal
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: Appearance.anim.curves.standard
                }
            }
        }

        StyledText {
            id: label
            color: parent.onColor
            font.pointSize: Appearance.font.size.small
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.verticalCenter: parent.verticalCenter

            opacity: icon.text ? stateLayer.containsMouse : true
            Behavior on opacity {
                PropertyAnimation {
                    property: "opacity"
                    duration: Appearance.anim.durations.normal
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: Appearance.anim.curves.standard
                }
            }
        }

        StateLayer {
            id: stateLayer
            color: parent.onColor
            function onClicked(): void {
                parent.onClicked();
            }
        }
    }
}
