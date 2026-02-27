pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Caelestia
import qs.config
import qs.services
import qs.utils

Singleton {
    id: root

    // --- Core ---
    readonly property bool niriAvailable: NiriIpc.available

    // --- Workspaces ---
    readonly property var allWorkspaces: NiriIpc.workspaces
    readonly property int focusedWorkspaceIndex: NiriIpc.focusedWorkspaceIndex
    readonly property int focusedWorkspaceId: NiriIpc.focusedWorkspaceId
    readonly property var currentOutputWorkspaces: NiriIpc.currentOutputWorkspaces
    readonly property string focusedMonitorName: NiriIpc.focusedMonitorName
    readonly property var workspaceHasWindows: NiriIpc.workspaceHasWindows

    // UI context menu state
    property bool wsContextExpanded: false
    property var wsContextAnchor: null
    property string wsContextType: "none"
    
    property Timer wsAnchorClearTimer: Timer {
        interval: Appearance.anim.durations.normal
        repeat: false
        onTriggered: {
            if (root.wsContextAnchor === null) {
                root.wsContextType = "none";
            }
        }
    }

    onWsContextAnchorChanged: {
        wsAnchorClearTimer.stop();
        if (wsContextAnchor === null) {
            wsAnchorClearTimer.start();
        }
    }

    // --- Windows ---
    readonly property var windows: NiriIpc.windows
    readonly property int focusedWindowIndex: NiriIpc.focusedWindowIndex
    readonly property string focusedWindowId: NiriIpc.focusedWindowId
    readonly property string focusedWindowTitle: NiriIpc.focusedWindowTitle
    readonly property string focusedWindowClass: NiriIpc.focusedWindowClass
    readonly property var focusedWindow: NiriIpc.focusedWindow
    readonly property var lastFocusedWindow: NiriIpc.lastFocusedWindow
    readonly property string scrollDirection: NiriIpc.scrollDirection
    readonly property bool inOverview: NiriIpc.inOverview
    signal windowOpenedOrChanged(var windowData)

    // --- Outputs ---
    readonly property var outputs: NiriIpc.outputs
    
    // --- Keyboard ---
    readonly property var kbLayoutsArray: NiriIpc.kbLayoutsArray
    readonly property int kbLayoutIndex: NiriIpc.kbLayoutIndex
    readonly property string kbLayouts: NiriIpc.kbLayouts
    readonly property string defaultKbLayout: NiriIpc.defaultKbLayout
    readonly property string kbLayout: NiriIpc.kbLayout
    readonly property bool capsLock: NiriIpc.capsLock
    readonly property bool numLock: NiriIpc.numLock

    property bool _lockKeysInitialized: false
    Timer { interval: 1500; running: true; onTriggered: root._lockKeysInitialized = true }

    onCapsLockChanged: {
        if (!_lockKeysInitialized || !Config.utilities.toasts.capsLockChanged)
            return;
        if (capsLock)
            Toaster.toast(qsTr("Caps lock enabled"), qsTr("Caps lock is currently enabled"), "keyboard_capslock_badge");
        else
            Toaster.toast(qsTr("Caps lock disabled"), qsTr("Caps lock is currently disabled"), "keyboard_capslock");
    }

    onNumLockChanged: {
        if (!_lockKeysInitialized || !Config.utilities.toasts.numLockChanged)
            return;
        if (numLock)
            Toaster.toast(qsTr("Num lock enabled"), qsTr("Num lock is currently enabled"), "looks_one");
        else
            Toaster.toast(qsTr("Num lock disabled"), qsTr("Num lock is currently disabled"), "timer_1");
    }

    onKbLayoutChanged: {
        if (!_lockKeysInitialized || !Config.utilities.toasts.kbLayoutChanged)
            return;
        Toaster.toast(qsTr("Keyboard layout changed"), qsTr("Layout changed to: %1").arg(kbLayout), "keyboard");
    }

    // --- Initialization ---
    Connections {
        target: NiriIpc
        function onWindowOpenedOrChanged(windowData) {
            root.windowOpenedOrChanged(windowData);
        }
    }

    Component.onCompleted: console.log("NiriService: Using native C++ IPC (NiriIpc)")

    // --- Workspace Functions ---
    function getWorkspaceIdxById(workspaceId) {
        return NiriIpc.getWorkspaceIdxById(workspaceId);
    }

    function getActiveWorkspaceName() {
        if (allWorkspaces && focusedWorkspaceIndex >= 0 && focusedWorkspaceIndex < allWorkspaces.length) {
            return allWorkspaces[focusedWorkspaceIndex].name || "";
        }
        return "";
    }

    function getWorkspaceNameByIndex(idx) {
        if (allWorkspaces && idx >= 0 && idx < allWorkspaces.length) {
            return allWorkspaces[idx].name || "";
        }
        return "";
    }

    function getWorkspaceNameById(id) {
        if (allWorkspaces && id >= 0) {
            const ws = allWorkspaces.find(w => w.id === id);
            return ws?.name || "";
        }
        return "";
    }

    function getWorkspaceByIndex(index) {
        if (index >= 0 && index < allWorkspaces.length) {
            return allWorkspaces[index];
        }
        return null;
    }

    function getWorkspaceCount() {
        return allWorkspaces.length;
    }

    function getOccupiedWorkspaceCount() {
        return allWorkspaces.filter(w => w.active_window_id !== "").length;
    }

    function getCurrentOutputWorkspaceNumbers() {
        return currentOutputWorkspaces.map(w => w.idx + 1);
    }

    function getCurrentWorkspaceNumber() {
        if (focusedWorkspaceIndex >= 0 && focusedWorkspaceIndex < allWorkspaces.length) {
            return allWorkspaces[focusedWorkspaceIndex].idx;
        }
        return 1;
    }

    function switchToWorkspace(workspaceId) {
        if (!niriAvailable) return false;
        return NiriIpc.action("focus-workspace", [workspaceId.toString()]);
    }

    function switchToWorkspaceUpDown(direction) {
        if (!niriAvailable) return false;
        return NiriIpc.action("focus-workspace-" + direction, []);
    }

    function switchToWorkspaceByIndex(index) {
        if (!niriAvailable || index < 0 || index >= allWorkspaces.length) return false;
        return switchToWorkspace(allWorkspaces[index].idx);
    }

    function switchToWorkspaceByNumber(number, output) {
        if (!niriAvailable) return false;
        const targetOutput = output || focusedMonitorName;
        if (!targetOutput) {
            console.warn("NiriService: No output specified for workspace switching");
            return false;
        }
        const outputWorkspaces = allWorkspaces
            .filter(w => w.output === targetOutput)
            .sort((a, b) => a.idx - b.idx);
        if (number >= 1 && number <= outputWorkspaces.length) {
            return switchToWorkspace(outputWorkspaces[number - 1].idx);
        }
        console.warn("NiriService: No workspace", number, "found on output", targetOutput);
        return false;
    }

    function moveWindowToWorkspace(workspaceIdx) {
        if (!niriAvailable) return false;
        return NiriIpc.action("move-window-to-workspace", [workspaceIdx.toString()]);
    }

    // --- Window Functions ---
    function getActiveWorkspaceWindows() {
        if (!allWorkspaces || focusedWorkspaceIndex === undefined) return [];
        const currentWs = allWorkspaces[focusedWorkspaceIndex];
        if (!currentWs?.id) return [];
        return windows.filter(w => w.workspace_id === currentWs.id);
    }

    function getWindowsByWorkspaceId(wsid) {
        return windows.filter(w => w.workspace_id === wsid);
    }

    function getWindowsByWorkspaceIndex(index) {
        if (index < 0 || index >= allWorkspaces.length) return [];
        const wsId = allWorkspaces[index].id;
        return windows.filter(w => w.workspace_id === wsId);
    }

    function getWindowsInScreen(screenX, screenY, screenWidth, screenHeight, windowBorder, padding) {
        if (!focusedWindow?.layout?.pos_in_scrolling_layout) return [];
        
        const focusedCol = focusedWindow.layout.pos_in_scrolling_layout[0];
        const focusedRow = focusedWindow.layout.pos_in_scrolling_layout[1];
        
        return getActiveWorkspaceWindows().map(window => {
            if (!window.layout?.pos_in_scrolling_layout || !window.layout?.window_size) return null;
            
            const colOffset = window.layout.pos_in_scrolling_layout[0] - focusedCol;
            const rowOffset = window.layout.pos_in_scrolling_layout[1] - focusedRow;
            const focusedWidth = focusedWindow.layout.window_size[0];
            
            let focusedScreenX;
            if (focusedWidth < screenWidth - windowBorder) {
                focusedScreenX = scrollDirection === "left" ? 5 : screenWidth - focusedWidth;
            } else {
                focusedScreenX = 0;
            }
            
            const winX = focusedScreenX + (colOffset * window.layout.window_size[0]) - windowBorder;
            const winY = rowOffset * window.layout.window_size[1] + windowBorder;
            const winW = window.layout.window_size[0] - padding * 2;
            const winH = window.layout.window_size[1] - padding * 2;
            
            if (winX < screenWidth + windowBorder && winY < screenHeight && winX + winW > 0 && winY + winH > 0) {
                return { window: window, screenX: winX, screenY: winY, screenW: winW, screenH: winH };
            }
            return null;
        }).filter(item => item !== null);
    }

    function focusWindow(windowID) {
        if (!niriAvailable) return false;
        if (Number(windowID) === Number(focusedWindowId) && Config.bar.workspaces.doubleClickToCenter) {
            return centerWindow();
        }
        return NiriIpc.action("focus-window", ["--id", windowID.toString()]);
    }

    function closeWindow(windowId) {
        if (!niriAvailable) return false;
        const id = windowId ? windowId.toString() : focusedWindowId.toString();
        return NiriIpc.action("close-window", ["--id", id]);
    }

    function closeFocusedWindow() {
        if (!niriAvailable) return false;
        return NiriIpc.action("close-window", []);
    }

    function toggleWindowFloating(windowId) {
        if (!niriAvailable) return false;
        const id = windowId ? windowId.toString() : focusedWindowId.toString();
        return NiriIpc.action("toggle-window-floating", ["--id", id]);
    }

    function toggleWindowOpacity() {
        if (!niriAvailable) return false;
        return NiriIpc.action("toggle-window-rule-opacity", []);
    }

    function expandColumnToAvailable() {
        if (!niriAvailable) return false;
        return NiriIpc.action("expand-column-to-available-width", []);
    }

    function centerWindow() {
        if (!niriAvailable) return false;
        return NiriIpc.action("center-window", []);
    }

    function screenshotWindow() {
        if (!niriAvailable) return false;
        return NiriIpc.action("screenshot-window", []);
    }

    function keyboardShortcutsInhibitWindow() {
        if (!niriAvailable) return false;
        return NiriIpc.action("toggle-keyboard-shortcuts-inhibit", []);
    }

    function toggleWindowedFullscreen() {
        if (!niriAvailable) return false;
        return NiriIpc.action("toggle-windowed-fullscreen", []);
    }

    function toggleFullscreen() {
        if (!niriAvailable) return false;
        return NiriIpc.action("fullscreen-window", []);
    }

    function toggleMaximize() {
        if (!niriAvailable) return false;
        return NiriIpc.action("maximize-column", []);
    }

    function toggleOverview() {
        if (!niriAvailable) return false;
        return NiriIpc.action("toggle-overview", []);
    }

    function doScreenTransition(delayMs) {
        if (!niriAvailable) return false;
        var delay = delayMs !== undefined ? delayMs : 500;
        return NiriIpc.action("do-screen-transition", ["-d", delay.toString()]);
    }

    function moveColumnToIndex(windowId, index) {
        if (!niriAvailable) return false;
        if (focusWindow(windowId)) {
            return NiriIpc.action("move-column-to-index", [index.toString()]);
        }
        return false;
    }

    function moveColumnToIndexAfterFocus(windowId, index, delayMs) {
        if (!niriAvailable) return false;
        
        if (Number(windowId) === Number(focusedWindowId)) {
            return NiriIpc.action("move-column-to-index", [index.toString()]);
        }
        
        focusWindow(windowId);
        
        var delay = delayMs !== undefined ? delayMs : 25;
        var timer = Qt.createQmlObject(
            'import QtQuick; Timer { interval: ' + delay + '; repeat: false }', 
            root
        );
        timer.triggered.connect(function() {
            timer.stop();
            timer.destroy();
            NiriIpc.action("move-column-to-index", [index.toString()]);
        });
        timer.start();
        return true;
    }

    function moveGroupColumnsSequential(curWindowId, windowIds, targetIndex, delayMs) {
        var i = 0;
        
        function moveNext() {
            if (i >= windowIds.length) {
                var timer = Qt.createQmlObject(
                    'import QtQuick; Timer { interval: ' + (delayMs * (i + 1) || 100) + '; repeat: false }',
                    root
                );
                timer.triggered.connect(function() {
                    timer.stop();
                    timer.destroy();
                    focusWindow(Number(curWindowId));
                });
                timer.start();
                return;
            }

            var windowId = windowIds[i];
            var timer = Qt.createQmlObject(
                'import QtQuick; Timer { interval: ' + (delayMs * (i + 1) || 100) + '; repeat: false }',
                root
            );
            timer.triggered.connect(function() {
                timer.stop();
                timer.destroy();
                moveColumnToIndexAfterFocus(windowId, targetIndex);
                i++;
                moveNext();
            });
            timer.start();
        }
        moveNext();
    }

    // --- Grouping Functions ---
    function sortWindows(windowList) {
        return windowList.slice().sort((a, b) => {
            const aPos = Array.isArray(a.layout?.pos_in_scrolling_layout) 
                ? a.layout.pos_in_scrolling_layout : [0, 0];
            const bPos = Array.isArray(b.layout?.pos_in_scrolling_layout) 
                ? b.layout.pos_in_scrolling_layout : [0, 0];
            if (aPos[0] !== bPos[0]) return aPos[0] - bPos[0];
            return aPos[1] - bPos[1];
        });
    }

    function groupWindowsByApp(windowList) {
        windowList = sortWindows(windowList);
        var groups = {};
        
        for (var j = 0; j < windowList.length; j++) {
            var w = windowList[j];
            var appId = w.app_id || "unknown";
            if (!groups[appId]) {
                groups[appId] = {
                    app_id: appId,
                    id: w.id,
                    title: w.title,
                    index: w.index,
                    windows: []
                };
            }
            groups[appId].windows.push(w);
        }
        
        var result = [];
        for (var key in groups) {
            var g = groups[key];
            g.count = g.windows.length;
            g.main = g.windows[0];
            result.push(g);
        }
        return result;
    }

    function groupWindowsByLayoutAndId(windowList) {
        windowList = sortWindows(windowList);
        var groups = [];
        var currentGroup = null;

        for (var j = 0; j < windowList.length; j++) {
            var w = windowList[j];
            if (!currentGroup || currentGroup.app_id !== w.app_id) {
                currentGroup = {
                    app_id: w.app_id,
                    windows: [w],
                    count: 1,
                    title: w.title,
                    id: w.id,
                    main: w
                };
                groups.push(currentGroup);
            } else {
                currentGroup.windows.push(w);
                currentGroup.count = currentGroup.windows.length;
            }
        }
        return groups;
    }
}
