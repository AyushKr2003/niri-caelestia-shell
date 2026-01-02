pragma ComponentBehavior: Bound

import qs.services
import qs.config
import QtQuick
import qs.components

Item {
    id: root

    property var groupedWindowsArray: [] // Holds full group objects

    ListModel {
        id: groupedWindowsModel
    }

    // Public API
    property int spacing: 0
    property var model: groupedWindowsModel
    property real dragThreshold: 8

    // Properties passed through to WindowIcon
    required property Item workspace
    required property int focusedWindowId
    required property int activeWsId
    required property int ws
    required property int idx
    required property int groupOffset
    required property Item windowPopoutSignal

    property bool isWsFocused: root.activeWsId === root.ws

    property var wsWindows: {
        const wsIndex = root.idx + root.groupOffset;
        if (wsIndex < 0 || wsIndex >= Niri.currentOutputWorkspaces.length)
            return [];
        const niriWorkspace = Niri.currentOutputWorkspaces[wsIndex];
        if (!niriWorkspace)
            return [];
        return Niri.getWindowsByWorkspaceId(niriWorkspace.id);
    }

    function updateGroupedWindowsModel() {
        const wsIndex = root.idx + root.groupOffset;
        if (wsIndex < 0 || wsIndex >= Niri.currentOutputWorkspaces.length)
            return;
        const niriWorkspace = Niri.currentOutputWorkspaces[wsIndex];
        if (!niriWorkspace)
            return;

        var wsWindows = Niri.getWindowsByWorkspaceId(niriWorkspace.id);
        var newGroups;

        if (Config.bar.workspaces.groupIconsByApp && Config.bar.workspaces.groupingRespectsLayout) {
            newGroups = Niri.groupWindowsByLayoutAndId(wsWindows);
        } else if (Config.bar.workspaces.groupIconsByApp) {
            newGroups = Niri.groupWindowsByApp(wsWindows);
        } else {
            newGroups = wsWindows.map(w => ({
                        app_id: w.app_id,
                        id: w.id,
                        title: w.title,
                        windows: [w],
                        count: 1,
                        main: w
                    }));
        }

        root.groupedWindowsArray = newGroups;

        // Remove old items
        for (let i = groupedWindowsModel.count - 1; i >= 0; --i) {
            let oldItem = groupedWindowsModel.get(i);
            if (!newGroups.find(g => g.id === oldItem.id && g.app_id === oldItem.app_id)) {
                groupedWindowsModel.remove(i);
            }
        }

        // Insert or update
        for (let i = 0; i < newGroups.length; ++i) {
            let g = newGroups[i];
            let idx = -1;

            for (let j = 0; j < groupedWindowsModel.count; ++j) {
                let old = groupedWindowsModel.get(j);
                if ((g.id && old.id === g.id) && (g.app_id && old.app_id === g.app_id)) {
                    idx = j;
                    break;
                }
            }

            let modelItem = {
                app_id: g.app_id,
                id: g.id,
                title: g.title,
                count: g.count,
                windows: g.windows,
                main: g.main
            };

            if (idx >= 0) {
                for (let key in modelItem) {
                    groupedWindowsModel.setProperty(idx, key, modelItem[key]);
                }
                if (idx !== i)
                    groupedWindowsModel.move(idx, i, 1);
            } else {
                groupedWindowsModel.insert(i, modelItem);
            }
        }
    }

    onWsWindowsChanged: updateGroupedWindowsModel()
    Component.onCompleted: updateGroupedWindowsModel()

    // Drag state
    property Item draggedItem: null

    // Signals
    signal itemReordered(var item, int fromIndex, int toIndex)

    //Here for now, will be moved to Workspace.qml later for other features such as drag and drop to workspaces etc.
    onItemReordered: (item, fromIndex, toIndex) => {
        // 1. Flatten all windows

        if (fromIndex === toIndex - 1 || fromIndex === toIndex)
            return;

        let flatWindows = [];
        for (let group of root.groupedWindowsArray) {
            flatWindows = flatWindows.concat(group.windows);
        }

        // 2. Get dragged windows
        let draggedWindows = Array.isArray(item.groupWindowData) ? item.groupWindowData : [item.groupWindowData];

        // 3. Remove dragged windows from flat list
        flatWindows = flatWindows.filter(w => !draggedWindows.some(dw => dw.id === w.id));

        // 4. Calculate flat insertion index (add group sizes up to toIndex)
        let flatIndex = 0;
        for (let i = 0; i < toIndex; ++i) {
            let group = root.groupedWindowsArray[i];
            if (group && group.windows) {
                flatIndex += group.windows.length;
            }
        }

        // 5. Adjust insertion index if moving down (after removal, indices shift)
        if ((fromIndex < toIndex)) {
            flatIndex -= 1;
        }

        // 6. Insert dragged windows at new position
        flatWindows.splice(flatIndex, 0, ...draggedWindows);

        // 7. Compute new indices (1-based for backend)
        let indices = draggedWindows.map(w => flatWindows.findIndex(x => x.id === w.id));

        // 8. Call backend to update order
        Niri.moveGroupColumnsSequential(Niri.focusedWindowId, draggedWindows.map(w => w.id), flatIndex + 1, 5);
    }

    // height: column.height
    // width: column.width
    implicitWidth: column.implicitWidth
    implicitHeight: column.implicitHeight

    // Drop indicator
    Rectangle {
        id: dropIndicator
        anchors.horizontalCenter: parent.horizontalCenter
        width: parent.width - Appearance.padding.small
        height: Appearance.padding.small
        color: root.isWsFocused ? Colours.palette.m3primaryContainer : Colours.palette.m3primaryContainer
        radius: Appearance.rounding.small
        visible: false
        z: 200

        Behavior on y {
            Anim {
                easing.bezierCurve: Appearance.anim.curves.emphasized
            }
        }
    }

    Column {
        id: column

        add: Transition {
            NumberAnimation {
                properties: "scale"
                from: 0
                to: 1
                duration: Appearance.anim.durations.normal
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Appearance.anim.curves.standardDecel
            }
        }

        move: Transition {
            NumberAnimation {
                properties: "scale"
                to: 1
                duration: Appearance.anim.durations.normal
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Appearance.anim.curves.standardDecel
            }
            NumberAnimation {
                properties: "x,y"
                duration: Appearance.anim.durations.normal
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Appearance.anim.curves.emphasized
            }
        }

        populate: Transition {
            NumberAnimation {
                properties: "scale"
                from: 0
                to: 1
                duration: Appearance.anim.durations.normal
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Appearance.anim.curves.standardDecel
            }
        }

        // anchors.horizontalCenter: parent.horizontalCenter

        Repeater {
            id: repeater
            model: root.model
            anchors.left: parent.left

            delegate: WindowIcon {
                id: icon
                workspace: root.workspace

                required property var modelData
                required property int index

                property var fullGroup: root.groupedWindowsArray[index]

                windowData: Config.bar.workspaces.groupIconsByApp ? fullGroup.main : fullGroup
                groupWindowData: Config.bar.workspaces.groupIconsByApp ? (fullGroup.windows || []) : [fullGroup]
                windowCount: Config.bar.workspaces.groupIconsByApp ? fullGroup.count : 1
                isFocused: Config.bar.workspaces.groupIconsByApp ? fullGroup.windows.some(w => w.id === root.focusedWindowId) : root.focusedWindowId === fullGroup.id
                isWsFocused: root.isWsFocused
                curWindowIndex: index
                wsWindowCount: root.model ? root.model.count : 0

                onDragStart: iconItem => {
                    if (root.draggedItem)
                        return;

                    // Position the preview under the cursor
                    icon.dgprw.visible = true;
                    icon.dgprw.x = iconItem.mapToItem(iconItem, iconItem.width / 2, 0).x;
                    icon.dgprw.y = iconItem.mapToItem(iconItem, 0, iconItem.height / 2).y;

                    root.draggedItem = icon;
                    icon.z = 100;
                    icon.opacity = 0.7;
                    dropIndicator.visible = true;
                    root.updateDropIndicator(icon.y);
                }

                onDragUpdate: (iconItem, mouseY, mouseX) => {
                    if (root.draggedItem !== icon)
                        return;

                    // Move preview with mouse
                    let globalPos = iconItem.mapToItem(iconItem, mouseX, mouseY);
                    icon.dgprw.x = globalPos.x - icon.dgprw.height / 2;
                    icon.dgprw.y = globalPos.y - icon.dgprw.height / 2;
                    root.updateDropIndicator(iconItem.mapToItem(iconItem, 0, mouseY).y);
                }

                onDragEnd: iconItem => {
                    if (root.draggedItem !== icon)
                        return;
                    icon.dgprw.visible = false;

                    icon.opacity = 1.0;
                    icon.z = 0;
                    dropIndicator.visible = false;

                    if (icon.dropTargetIndex !== undefined && icon.dropTargetIndex !== icon.index) {
                        root.itemReordered(icon, icon.index, icon.dropTargetIndex);
                    }

                    root.draggedItem = null;
                    icon.dropTargetIndex = -1;
                }

                onRequestPopup: (groupWindowData, iconItem) => {
                    root.windowPopoutSignal.requestWindowPopout();
                }
            }
        }
    }

    function updateDropIndicator(globalY) {
        let targetIndex = 0;
        let targetY = 0;

        for (let i = 0; i < repeater.count; i++) {
            let child = repeater.itemAt(i);

            if (!child || child === root.draggedItem)
                continue;

            let childY = child.y + child.height / 2;
            if (globalY < childY) {
                targetIndex = i;
                targetY = child.y - Config.bar.workspaces.windowIconGap;
                break;
            }
            targetIndex = i + 1;
            targetY = child.y + child.height + root.spacing;
        }

        if (root.draggedItem) {
            root.draggedItem.dropTargetIndex = targetIndex;
        }
        dropIndicator.y = targetY;
    }
}
