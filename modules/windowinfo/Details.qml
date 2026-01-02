import qs.components
import qs.services
import qs.config
import QtQuick
import QtQuick.Layouts

// import qs.modules.bar.popouts

ColumnLayout {
    id: root

    property var client: null // NEW LOGIC

    Connections {
        target: Niri // Listen to the Niri singleton
        function onFocusedWindowChanged(): void {
            root.client = Niri.focusedWindow || Niri.lastFocusedWindow || null;
        // console.log("ClientDetailView: Niri.focusedWindow changed. Displaying client:", root.client ? root.client.id : "null/none");
        }
    }

    // Initial setup in Component.onCompleted
    Component.onCompleted: {
        root.client = Niri.focusedWindow || Niri.lastFocusedWindow;
        // console.log("ClientDetailView: Initial client set to:", root.client ? root.client.id : "null/none");
    }

    anchors.fill: parent
    spacing: Appearance.spacing.small

    Label {
        Layout.topMargin: Appearance.padding.large * 2

        text: root.client?.title ?? qsTr("No active client")
        wrapMode: Text.WrapAtWordBoundaryOrAnywhere

        font.pointSize: Appearance.font.size.large
        font.weight: 500
    }

    Label {
        text: root.client?.app_id ?? qsTr("No active client")
        color: Colours.palette.m3tertiary

        font.pointSize: Appearance.font.size.larger
    }

    StyledRect {
        Layout.fillWidth: true
        Layout.preferredHeight: 1
        Layout.leftMargin: Appearance.padding.large * 2
        Layout.rightMargin: Appearance.padding.large * 2
        Layout.topMargin: Appearance.spacing.normal
        Layout.bottomMargin: Appearance.spacing.large

        color: Colours.palette.m3secondary
    }

    Detail {
        icon: "location_on"
        property var adress: root.client?.layout?.pos_in_scrolling_layout ?? [-1, -1]
        text: qsTr("Address: %1, %2").arg(adress[0] ?? -1).arg(adress[1] ?? -1)
        color: Colours.palette.m3primary
    }
    Loader {
        active: root.client?.is_floating ?? false
        sourceComponent: Detail {
            icon: "location_searching"
            property var pos: root.client?.layout?.tile_pos_in_workspace_view ?? [-1, -1]
            text: qsTr("Position: %1, %2").arg(pos[0] ?? -1).arg(pos[1] ?? -1)
        }
    }

    Detail {
        icon: "resize"
        property var size: root.client?.layout?.window_size ?? [-1, -1]
        text: qsTr("Size: %1 x %2").arg(size[0] ?? -1).arg(size[1] ?? -1)
        color: Colours.palette.m3tertiary
    }

    Detail {
        icon: "workspaces"
        text: {
            const workspaceId = root.client?.workspace_id;
            if (workspaceId !== undefined && workspaceId !== null) {
                // Find the workspace object in Niri's list
                const ws = Niri.currentOutputWorkspaces.find(w => w.id === workspaceId);
                return qsTr("Workspace: %1 (%2)").arg(ws?.name ?? "unknown").arg(workspaceId);
            }
            return qsTr("Workspace: unknown");
        }
        color: Colours.palette.m3secondary
    }

    Detail {
        icon: "desktop_windows"
        text: {
            if (!Niri.focusedMonitorName || !Niri.outputs)
                return qsTr("Monitor: unknown");
            const mon = Niri.outputs[Niri.focusedMonitorName];
            if (!mon)
                return qsTr("Monitor: unknown");
            const modes = mon.modes?.[0];
            if (!modes)
                return qsTr("Monitor: %1").arg(mon.name ?? "unknown");
            const scale = mon.logical?.scale ?? 1;
            return qsTr("Monitor: %1 (%3px x %4px) @(%2) #(%5)").arg(mon.name ?? "unknown").arg(modes.refresh_rate ?? 0).arg(modes.width ?? 0).arg(modes.height ?? 0).arg(scale);
        }
    }

    // Detail {
    //     icon: "page_header"
    //     text: qsTr("Initial title: %1").arg(root.client?.initialTitle ?? "unknown")
    //     color: Colours.palette.m3tertiary
    // }

    Detail {
        icon: "category"
        text: qsTr("App ID: %1").arg(root.client?.app_id ?? "unknown")
    }

    Detail {
        icon: "account_tree"
        text: qsTr("Process id: %1").arg(root.client?.pid ?? -1)
        color: Colours.palette.m3primary
    }

    Detail {
        icon: "picture_in_picture_center"
        text: qsTr("Floating: %1").arg(root.client?.is_floating ? "yes" : "no")
        color: Colours.palette.m3secondary
    }

    // Detail {
    //     icon: "gradient"
    //     text: qsTr("Xwayland: %1").arg(root.client?.xwayland ? "yes" : "no")
    // }

    // Detail {
    //     icon: "keep"
    //     text: qsTr("Pinned: %1").arg(root.client?.pinned ? "yes" : "no")
    //     color: Colours.palette.m3secondary
    // }

    // Detail {
    //     icon: "fullscreen"
    //     text: {
    //         const fs = root.client?.fullscreen;
    //         if (fs)
    //             return qsTr("Fullscreen state: %1").arg(fs == 0 ? "off" : fs == 1 ? "maximised" : "on");
    //         return qsTr("Fullscreen state: unknown");
    //     }
    //     color: Colours.palette.m3tertiary
    // }

    Item {
        Layout.fillHeight: true
    }

    component Detail: RowLayout {
        id: detail

        required property string icon
        required property string text
        property alias color: icon.color

        Layout.leftMargin: Appearance.padding.large
        Layout.rightMargin: Appearance.padding.large
        Layout.fillWidth: true

        spacing: Appearance.spacing.smaller

        MaterialIcon {
            id: icon

            Layout.alignment: Qt.AlignVCenter
            text: detail.icon
        }

        StyledText {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter

            text: detail.text
            elide: Text.ElideRight
            font.pointSize: Appearance.font.size.normal
        }
    }

    component Label: StyledText {
        Layout.leftMargin: Appearance.padding.large
        Layout.rightMargin: Appearance.padding.large
        Layout.fillWidth: true
        elide: Text.ElideRight
        horizontalAlignment: Text.AlignHCenter
        animate: true
    }
}
