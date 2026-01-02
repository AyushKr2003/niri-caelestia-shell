import qs.components
// import qs.components.controls
import qs.services
import qs.utils
import qs.config
import Quickshell.Widgets
import QtQuick
import QtQuick.Layouts

// WindowInfo module is available via wrapper.detach("winfo")

Item {
    id: root

    required property Item wrapper

    implicitWidth: Niri.focusedWindowTitle /*Niri.activeToplevel*/  ? child.implicitWidth : -Appearance.padding.large * 2
    implicitHeight: child.implicitHeight

    ColumnLayout {
        id: child

        anchors.left: parent.left
        spacing: Appearance.spacing.normal

        // height: 20
        // width: Config.bar.sizes.windowPreviewSize - 100

        RowLayout {
            id: detailsRow

            Layout.alignment: Qt.AlignLeft
            // anchors.left: parent.left
            // anchors.right: parent.right
            spacing: Appearance.spacing.normal

            IconImage {
                id: icon

                Layout.alignment: Qt.AlignVCenter
                implicitSize: details.implicitHeight
                source: Icons.getAppIcon(Niri.focusedWindowClass ?? "", "image-missing")
            }

            ColumnLayout {
                id: details

                spacing: 0
                Layout.fillWidth: true

                StyledText {
                    Layout.fillWidth: true
                    text: Niri.focusedWindowTitle ?? ""
                    font.pointSize: Appearance.font.size.normal
                    elide: Text.ElideRight
                    Layout.preferredWidth: 200
                }

                StyledText {
                    Layout.fillWidth: true
                    text: Niri.focusedWindowClass ?? ""
                    color: Colours.palette.m3onSurfaceVariant
                    elide: Text.ElideRight
                }
            }

            Item {
                implicitWidth: expandIcon.implicitHeight + Appearance.padding.small * 2
                implicitHeight: expandIcon.implicitHeight + Appearance.padding.small * 2

                Layout.alignment: Qt.AlignVCenter

                StateLayer {
                    radius: Appearance.rounding.normal

                    function onClicked(): void {
                        root.wrapper.detach("winfo");
                    }
                }

                MaterialIcon {
                    id: expandIcon

                    anchors.centerIn: parent
                    anchors.horizontalCenterOffset: font.pointSize * 0.05

                    text: "chevron_right"

                    font.pointSize: Appearance.font.size.large
                }
            }
        }

        // StyledRect {
        //     // Layout.fillWidth: true
        //     // Layout.fillHeight: true
        //     // clip: true

        //     // Layout.preferredHeight: buttons.implicitHeight
        //     // height : 250

        //     height: 200

        //     width: Config.bar.sizes.windowPreviewSize
        //     // color: Colours.palette.m3surfaceContainer
        //     radius: Appearance.rounding.normal

        //     Flickable {
        //         id: flick
        //         anchors.fill: parent
        //         contentHeight: buttons.implicitHeight

        //         interactive: true
        //         clip: true

        //         Buttons {
        //             id: buttons
        //             // Your buttons content here
        //         }

        //         ScrollBar.vertical: StyledScrollBar {}
        //     }
        // }

        // ClippingWrapperRectangle {
        //     color: "transparent"
        //     radius: Appearance.rounding.small
        //
        //     ScreencopyView {
        //         id: preview
        //
        //         // captureSource: Niri.activeToplevel ?? null
        //         captureSource: Quickshell.Wayland.findClientByPid(Niri.focusedWindow.pid) ?? null
        //         live: visible
        //
        //         constraintSize.width: Config.bar.sizes.windowPreviewSize
        //         constraintSize.height: Config.bar.sizes.windowPreviewSize
        //     }
        // }

        // RowLayout {
        //     id: windowdecorations
        //     anchors.right: parent.right

        //     Loader {
        //         active: Niri.focusedWindow.is_floating
        //         asynchronous: true
        //         Layout.fillWidth: active
        //         visible: active
        //         // Layout.leftMargin: active ? 0 : -parent.spacing * 2
        //         // Layout.rightMargin: active ? 0 : -parent.spacing * 2

        //         sourceComponent: WindowDecorations {
        //             color: Colours.palette.m3secondaryContainer
        //             onColor: Colours.palette.m3onSecondaryContainer

        //             icon: "push_pin"
        //             function onClicked(): void {
        //                 Niri.dispatch(`pin address:0x${root.client?.address}`);
        //             }
        //         }
        //     }

        //     WindowDecorations {

        //         color: Niri.focusedWindow.is_floating ? Colours.palette.m3primary : Colours.palette.m3secondaryContainer
        //         onColor: Niri.focusedWindow.is_floating ? Colours.palette.m3onPrimary : Colours.palette.m3onSecondaryContainer

        //         icon: Niri.focusedWindow.is_floating ? "grid_view" : "picture_in_picture"
        //         function onClicked(): void {
        //             Niri.toggleWindowFloating();
        //         }
        //     }

        //     WindowDecorations {
        //         color: Colours.palette.m3tertiary
        //         onColor: Colours.palette.m3onTertiary

        //         icon: "fullscreen"
        //         function onClicked(): void {
        //             Niri.toggleMaximize();
        //         }
        //     }
        //     WindowDecorations {
        //         color: Colours.palette.m3errorContainer
        //         onColor: Colours.palette.m3onErrorContainer

        //         icon: "close"
        //         function onClicked(): void {
        //             Niri.closeFocusedWindow();
        //         }
        //     }
        // }
    }
}
