pragma ComponentBehavior: Bound

import qs.services
import qs.components.controls
import QtQuick
import QtQuick.Layouts
import qs.config

// 3 Styled Radial buttons
RowLayout {
    id: root
    property var client: Niri.focusedWindow
    property int implicitSize: Appearance.font.size.normal

    spacing: Appearance.padding.small / 2

    // Pin feature removed - Niri doesn't support window pinning
    // TODO: Implement alternative if Niri adds pin support in future

    StyledRadialButton {
        disabled: !root.client
        basecolor: root.client.is_floating ? Colours.palette.m3primary : Colours.palette.m3secondaryContainer
        onColor: root.client.is_floating ? Colours.palette.m3onPrimary : Colours.palette.m3onSecondaryContainer

        implicitSize: root.implicitSize

        icon: root.client.is_floating ? "grid_view" : "picture_in_picture"
        function onClicked(): void {
            console.log("Toggling floating for", root.client?.id);
            Niri.toggleWindowFloating(root.client?.id);
        }
    }

    Loader {
        active: root.client?.is_focused
        asynchronous: true
        visible: active

        sourceComponent: StyledRadialButton {
            disabled: !root.client
            basecolor: Colours.palette.m3tertiary
            onColor: Colours.palette.m3onTertiary

            implicitSize: root.implicitSize

            icon: "fullscreen"
            function onClicked(): void {
                Niri.toggleMaximize();
            }
        }
    }

    StyledRadialButton {
        disabled: !root.client
        basecolor: Colours.palette.m3errorContainer
        onColor: Colours.palette.m3onErrorContainer
        icon: "close"

        implicitSize: root.implicitSize

        function onClicked(): void {
            Niri.closeWindow(root.client?.id);
        }
    }
}
