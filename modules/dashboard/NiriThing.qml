import qs.components
import qs.services
import qs.config
import QtQuick
import QtQuick.Layouts

Item {
    id: root

    // Comfortable width to fit 4 workspace buttons in single row
    implicitWidth: 720
    implicitHeight: content.implicitHeight + Appearance.padding.large * 2

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

    ColumnLayout {
        id: content

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: Appearance.padding.large
        spacing: Appearance.spacing.normal

        // ***************************************************
        // WORKSPACE SECTION
        CollapsibleSection {
            id: moveWorkspaceDropdown
            Layout.fillWidth: true
            title: qsTr("Move Window to Workspace")

            GridLayout {
                id: wsGrid
                columns: 4  // Maximum 4 workspaces per row
                rowSpacing: Appearance.spacing.normal
                columnSpacing: Appearance.spacing.normal
                Layout.fillWidth: true

                Repeater {
                    model: Niri.getWorkspaceCount()

                    WorkspaceButton {
                        required property int index
                        readonly property int wsId: Math.floor((Niri.focusedWorkspaceIndex) / 10) * 10 + index + 1
                        readonly property bool isCurrent: (wsId - 1) % 10 === Niri.focusedWorkspaceIndex
                        readonly property int wsIndex: wsId - 1

                        Layout.fillWidth: true
                        active: isCurrent
                        text: {
                            if (wsIndex < 0 || wsIndex >= Niri.currentOutputWorkspaces.length)
                                return "Workspace " + wsId;
                            return Niri.currentOutputWorkspaces[wsIndex]?.name ?? ("Workspace " + wsId);
                        }
                        disabled: isCurrent

                        function onClicked(): void {
                            Niri.moveWindowToWorkspace(wsId);
                        }
                    }
                }
            }
        }

        // ***************************************************
        // UTILITIES SECTION
        CollapsibleSection {
            id: utilities
            Layout.fillWidth: true
            title: qsTr("Window Utilities")
            backgroundMarginTop: 0
            expanded: true

            //  toggleWindowOpacity
            //  expandColumnToAvailable
            //  centerWindow
            //  screenshotWindow
            //  keyboardShortcutsInhibitWindow
            //  toggleWindowedFullscreen
            //  toggleFullscreen
            //  toggleMaximize

            GridLayout {
                columns: 3
                rowSpacing: Appearance.spacing.normal
                columnSpacing: Appearance.spacing.normal
                Layout.fillWidth: true

                // Row 1: Main window controls
                ActionButton {
                    Layout.fillWidth: true
                    icon: "fullscreen"
                    text: qsTr("Fullscreen")
                    function onClicked(): void {
                        Niri.toggleFullscreen();
                    }
                }

                ActionButton {
                    Layout.fillWidth: true
                    icon: "fullscreen_exit"
                    text: qsTr("Fake Fullscreen")
                    function onClicked(): void {
                        Niri.toggleWindowedFullscreen();
                    }
                }

                ActionButton {
                    Layout.fillWidth: true
                    icon: "center_focus_strong"
                    text: qsTr("Center Window")
                    function onClicked(): void {
                        Niri.centerWindow();
                    }
                }

                // Row 2: Secondary actions
                ActionButton {
                    Layout.fillWidth: true
                    icon: "block"
                    text: qsTr("Inhibit Shortcuts")
                    function onClicked(): void {
                        Niri.keyboardShortcutsInhibitWindow();
                    }
                }

                ActionButton {
                    Layout.fillWidth: true
                    Layout.columnSpan: 2
                    icon: "photo_camera"
                    text: qsTr("Screenshot Window")
                    accent: true
                    function onClicked(): void {
                        Niri.screenshotWindow();
                    }
                }

                // // expandColumnToAvailable - Button 6
                // ActionButton {
                //     Layout.fillWidth: true
                //     icon: "view_column"
                //     text: qsTr("Expand Column")
                //     function onClicked(): void {
                //         Niri.expandColumnToAvailable();
                //     }
                // }

                // // toggleWindowOpacity - Button 5
                // ActionButton {
                //     Layout.fillWidth: true
                //     icon: "opacity"
                //     text: qsTr("Toggle Opacity")
                //     function onClicked(): void {
                //         Niri.toggleWindowOpacity();
                //     }
                // }
            }
        }

        // Rect {
        //     Layout.row: 1
        //     Layout.column: 4
        //     Layout.preferredWidth: resources.implicitWidth
        //     Layout.fillHeight: true
        // }

        // Rect {
        //     Layout.row: 0
        //     Layout.column: 5
        //     Layout.rowSpan: 2
        //     Layout.preferredWidth: media.implicitWidth
        //     Layout.fillHeight: true
        // }
    }

    // ***************************************************
    // COMPONENTS

    component Rect: StyledRect {
        radius: Appearance.rounding.small
        color: Colours.tPalette.m3surfaceContainer
    }

    // Workspace button - pill style for workspace selection
    component WorkspaceButton: StyledRect {
        id: wsBtn

        property bool active: false
        property alias disabled: stateLayer.disabled
        property alias text: label.text

        function onClicked(): void {}

        radius: Appearance.rounding.full
        color: active ? Colours.palette.m3primary : Colours.palette.m3surfaceContainerHigh

        implicitHeight: label.implicitHeight + Appearance.padding.small * 2
        implicitWidth: label.implicitWidth + Appearance.padding.normal * 2

        Behavior on color {
            CAnim {}
        }

        StateLayer {
            id: stateLayer
            radius: parent.radius
            color: active ? Colours.palette.m3onPrimary : Colours.palette.m3onSurface

            function onClicked(): void {
                wsBtn.onClicked();
            }
        }

        StyledText {
            id: label
            anchors.centerIn: parent
            color: active ? Colours.palette.m3onPrimary : Colours.palette.m3onSurface
            font.pointSize: Appearance.font.size.small
            font.weight: active ? Font.Medium : Font.Normal

            Behavior on color {
                CAnim {}
            }
        }
    }

    // Action button - card style for utility actions
    component ActionButton: StyledRect {
        id: actionBtn

        property alias disabled: actionStateLayer.disabled
        property alias text: actionLabel.text
        property alias icon: actionIcon.text
        property bool accent: false

        function onClicked(): void {}

        radius: Appearance.rounding.small
        color: accent ? Colours.palette.m3primaryContainer : Colours.palette.m3surfaceContainerHigh

        implicitHeight: contentCol.implicitHeight + Appearance.padding.normal * 2
        implicitWidth: Math.max(contentCol.implicitWidth + Appearance.padding.normal * 2, 100)

        Behavior on color {
            CAnim {}
        }

        StateLayer {
            id: actionStateLayer
            radius: parent.radius
            color: accent ? Colours.palette.m3onPrimaryContainer : Colours.palette.m3onSurface

            function onClicked(): void {
                actionBtn.onClicked();
            }
        }

        Column {
            id: contentCol
            anchors.centerIn: parent
            spacing: Appearance.spacing.smaller

            MaterialIcon {
                id: actionIcon
                anchors.horizontalCenter: parent.horizontalCenter
                color: accent ? Colours.palette.m3onPrimaryContainer : Colours.palette.m3onSurface
                font.pointSize: Appearance.font.size.large
                text: "radio_button_unchecked"

                Behavior on color {
                    CAnim {}
                }
            }

            StyledText {
                id: actionLabel
                anchors.horizontalCenter: parent.horizontalCenter
                color: accent ? Colours.palette.m3onPrimaryContainer : Colours.palette.m3onSurfaceVariant
                font.pointSize: Appearance.font.size.smaller
                horizontalAlignment: Text.AlignHCenter

                Behavior on color {
                    CAnim {}
                }
            }
        }
    }

    // Legacy Button component (kept for compatibility)
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

        RowLayout {
            anchors.verticalCenter: parent.verticalCenter
            anchors.horizontalCenter: parent.horizontalCenter

            // anchors.left: parent.left

            Item {
                Layout.fillWidth: true
            }
            MaterialIcon {
                id: icon
                color: parent.parent.onColor
                // font.pointSize: Appearance.font.size.large
                text: "radio_button_unchecked"
                font.pointSize: label.font.pointSize * 3.0

                // anchors.verticalCenter: parent.verticalCenter
                Layout.alignment: Qt.AlignVCenter

                // opacity: icon.text ? !stateLayer.containsMouse : true
                // Behavior on opacity {
                //     PropertyAnimation {w
                //         property: "opacity"
                //         duration: Appearance.anim.durations.normal
                //         easing.type: Easing.BezierSpline
                //         easing.bezierCurve: Appearance.anim.curves.standard
                //     }
                // }
            }
            StyledText {
                id: label
                color: parent.parent.onColor
                font.pointSize: Appearance.font.size.small
                wrapMode: Text.WordWrap
                maximumLineCount: 2
                Layout.preferredWidth: 90 // Adjust as needed for your layout
                // Optionally, set elide if text is too long
                elide: Text.ElideRight
                verticalAlignment: Text.AlignVCenter
                // horizontalAlignment: Text.AlignLeft
                // opacity: icon.text ? stateLayer.containsMouse : true
                // Behavior on opacity {
                //     PropertyAnimation {
                //         property: "opacity"
                //         duration: Appearance.anim.durations.normal
                //         easing.type: Easing.BezierSpline
                //         easing.bezierCurve: Appearance.anim.curves.standard
                //     }
                // }
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