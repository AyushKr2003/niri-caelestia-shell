pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config
import qs.utils

Singleton {
    id: root

    // Scroll direction tracking
    property int lastFocusedColumn: -1
    property string scrollDirection: "none" // "left", "right", "none"

    // Workspace management
    property var wsContextExpanded: false
    property var wsContextAnchor: null
    property string wsContextType: "none" // "item", "workspace", "workspaces", "none"
    property Timer wsAnchorClearTimer: Timer {
        interval: Appearance.anim.durations.normal // ms, adjust as you like
        repeat: false
        onTriggered: {
            if (root.wsContextAnchor === null) {
                root.wsContextType = "none";
            }
        }
    }

    onWsContextAnchorChanged: {
        // cancel any existing countdown
        wsAnchorClearTimer.stop();
        // only start timer if it’s null
        if (wsContextAnchor === null) {
            wsAnchorClearTimer.start();
        }
    }

    // Workspace management
    property var allWorkspaces: []
    property int focusedWorkspaceIndex: 0
    property string focusedWorkspaceId: ""
    property var currentOutputWorkspaces: []

    // Window management
    property var windows: []
    property int focusedWindowIndex: -1
    property string focusedWindowTitle: "(No active window)"
    property string focusedWindowClass: "(No active window)"
    property string focusedWindowId: ""

    // Outputs / Monitor management:
    property var outputs: ({})
    property string focusedMonitorName: ""
    onOutputsChanged: console.log(outputs)

    // Overview state
    property bool inOverview: false
    signal windowOpenedOrChanged(var windowData)

    // Keyboard layout

    // Note: CapsLock/NumLock detection is now handled by LockStatus.qml
    // using system-level /sys/class/leds/* paths for compositor-agnostic detection

    property var kbLayoutsArray: []
    property bool capsLock: false
    property bool numLock: false
    property string defaultKbLayout: kbLayouts[0] || "?"
    property int kbLayoutIndex: 0
    property string kbLayouts: "?"
    readonly property string kbLayout: (kbLayoutsArray.length > 0 && kbLayoutIndex >= 0 && kbLayoutIndex < kbLayoutsArray.length) ? kbLayoutsArray[kbLayoutIndex].slice(0, 2).toLowerCase() : "?"

    // Last focused window
    property var focusedWindow: root.windows[root.focusedWindowIndex]
    property var lastFocusedWindow: null

    // Monitor changes to focusedWindowId to update lastFocusedWindow
    onFocusedWindowIdChanged: {
        if (focusedWindow) {
            // Only update if a window is truly focused
            root.lastFocusedWindow = focusedWindow;
            // Track scroll direction
            const pos = focusedWindow.layout?.pos_in_scrolling_layout;
            if (Array.isArray(pos)) {
                const currentCol = pos[0];
                if (lastFocusedColumn >= 0) {
                    scrollDirection = currentCol > lastFocusedColumn ? "right" : currentCol < lastFocusedColumn ? "left" : "none";
                }
                lastFocusedColumn = currentCol;
            } else {
                scrollDirection = "none";
            }
        }
    }

    property var workspaceHasWindows: ({})
    function updateWorkspaceHasWindows() {
        let newWorkspaceHasWindows = {};
        // Initialize all known workspaces to false
        for (const ws of root.allWorkspaces) {
            // Use allWorkspaces here
            newWorkspaceHasWindows[ws.idx] = false;
        }

        // Iterate through all windows and mark their workspace as having windows
        for (const window of root.windows) {
            if (window.workspace_id !== undefined && window.workspace_id !== null) {
                newWorkspaceHasWindows[getWorkspaceIdxById(window.workspace_id)] = true;
            }
        }

        // Only update if there's an actual change to avoid unnecessary property change signals
        if (JSON.stringify(root.workspaceHasWindows) !== JSON.stringify(newWorkspaceHasWindows)) {
            root.workspaceHasWindows = newWorkspaceHasWindows;
            console.log("NiriService: updateWorkspaceHasWindows() called. Current state:", JSON.stringify(root.workspaceHasWindows));
        }
    }

    function getWorkspaceIdxById(workspaceId) {
        const ws = allWorkspaces.find(w => w.id === workspaceId);
        return ws ? ws.idx : -1;
    }

    // Call updateWorkspaceHasWindows when relevant properties change
    onAllWorkspacesChanged: updateWorkspaceHasWindows() // Update if workspaces themselves change
    onWindowsChanged: updateWorkspaceHasWindows() // Explicitly update when the windows list changes

    // Feature availability
    property bool niriAvailable: false

    Component.onCompleted: {
        console.log("NiriService: Component.onCompleted - initializing service");
        checkNiriAvailability();

        console.log("Paths.home:", Paths.home);
        console.log("Paths.pictures:", Paths.pictures);
        console.log("Paths.data:", Paths.data);
        console.log("Paths.state:", Paths.state);
        console.log("Paths.cache:", Paths.cache);
        console.log("Paths.config:", Paths.config);
        console.log("Paths.imagecache:", Paths.imagecache);
        console.log("Paths.wallsdir:", Paths.wallsdir);
        console.log("Paths.libdir:", Paths.libdir);
    }

    // Check if niri is available
    Process {
        id: niriCheck
        command: ["which", "niri"]
        onExited: exitCode => {
            root.niriAvailable = exitCode === 0;
            if (root.niriAvailable) {
                console.log("NiriService: niri found, starting event stream and loading initial data");
                eventStreamProcess.running = true;
                root.loadInitialWorkspaceData();
            } else {
                console.log("NiriService: niri not found, workspace features disabled");
            }
        }
    }

    function checkNiriAvailability() {
        niriCheck.running = true;
    }

    // Load initial workspace data
    Process {
        id: initialDataQuery
        command: ["niri", "msg", "-j", "workspaces"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                if (text && text.trim()) {
                    try {
                        console.log("NiriService: Loaded initial workspace data");
                        const workspaces = JSON.parse(text.trim());
                        // Initial query returns array directly, event stream wraps it in WorkspacesChanged
                        root.handleWorkspacesChanged({
                            workspaces: workspaces
                        });
                    } catch (e) {
                        console.warn("NiriService: Failed to parse initial workspace data:", e);
                    }
                }
            }
        }
    }

    // Load initial outputs data
    Process {
        id: initialOutputsQuery
        command: ["niri", "msg", "-j", "outputs"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                if (text && text.trim()) {
                    try {
                        const outputsData = JSON.parse(text.trim());
                        root.handleOutputsChanged(outputsData);
                    } catch (e) {
                        console.warn("NiriService: Failed to parse initial outputs data:", e);
                    }
                }
            }
        }
    }

    // Load initial windows data
    Process {
        id: initialWindowsQuery
        command: ["niri", "msg", "-j", "windows"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                if (text && text.trim()) {
                    try {
                        const windowsData = JSON.parse(text.trim());
                        if (windowsData && windowsData.windows) {
                            root.handleWindowsChanged(windowsData);
                            console.log("NiriService: Loaded", windowsData.windows.length, "initial windows");
                        }
                    } catch (e) {
                        console.warn("NiriService: Failed to parse initial windows data:", e);
                    }
                }
            }
        }
    }

    // Load initial focused window data
    Process {
        id: initialFocusedWindowQuery
        command: ["niri", "msg", "-j", "focused-window"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                if (text && text.trim()) {
                    try {
                        const focusedData = JSON.parse(text.trim());
                        if (focusedData && focusedData.id) {
                            root.handleWindowFocusChanged({
                                id: focusedData.id
                            });
                            console.log("NiriService: Loaded initial focused window:", focusedData.id);
                        }
                    } catch (e) {
                        console.warn("NiriService: Failed to parse initial focused window data:", e);
                    }
                }
            }
        }
    }

    function loadInitialWorkspaceData() {
        console.log("NiriService: Loading initial workspace data...");
        initialDataQuery.running = true;
        initialWindowsQuery.running = true;
        initialFocusedWindowQuery.running = true;
        initialOutputsQuery.running = true; // Add this line
    }

    // Event stream for real-time updates
    Process {
        id: eventStreamProcess
        command: ["niri", "msg", "-j", "event-stream"]
        running: false // Will be enabled after niri check
        stdout: SplitParser {
            onRead: data => {
                try {
                    const event = JSON.parse(data.trim());
                    root.handleNiriEvent(event);
                } catch (e) {
                    console.warn("NiriService: Failed to parse event:", data, e);
                }
            }
        }
        onExited: exitCode => {
            if (exitCode !== 0 && root.niriAvailable) {
                console.warn("NiriService: Event stream exited with code", exitCode, "restarting immediately");
                eventStreamProcess.running = true;
            }
        }
    }

    function handleNiriEvent(event) {
        if (event.WorkspacesChanged) {
            handleWorkspacesChanged(event.WorkspacesChanged);
        } else if (event.WorkspaceActivated) {
            handleWorkspaceActivated(event.WorkspaceActivated);
        } else if (event.WindowLayoutsChanged) {
            handleWindowLayoutsChanged(event.WindowLayoutsChanged);
        } else if (event.WindowsChanged) {
            handleWindowsChanged(event.WindowsChanged);
        } else if (event.WindowClosed) {
            handleWindowClosed(event.WindowClosed);
        } else if (event.WindowFocusChanged) {
            handleWindowFocusChanged(event.WindowFocusChanged);
        } else if (event.WindowOpenedOrChanged) {
            handleWindowOpenedOrChanged(event.WindowOpenedOrChanged);
        } else if (event.OverviewOpenedOrClosed) {
            handleOverviewChanged(event.OverviewOpenedOrClosed);
        } else if (event.KeyboardLayoutsChanged) {
            handleKeyboardLayoutsChanged(event.KeyboardLayoutsChanged);
        }
    }
    function handleKeyboardLayoutsChanged(data) {
        if (data && data.keyboard_layouts && data.keyboard_layouts.names && data.keyboard_layouts.names.length > 0) {
            kbLayoutsArray = data.keyboard_layouts.names;
            kbLayouts = data.keyboard_layouts.names.join(",");
            var idx = data.keyboard_layouts.current_idx;
            if (idx >= 0 && idx < data.keyboard_layouts.names.length) {
                kbLayoutIndex = idx;
            } else {
                kbLayoutIndex = 0;
            }
        } else {
            kbLayoutsArray = [];
            kbLayouts = "?";
            kbLayoutIndex = 0;
        }
    }

    function handleWindowLayoutsChanged(data) {
        if (!data.changes)
            return;

        // Save the currently focused window object
        var prevFocusedWindow = (focusedWindowIndex >= 0 && focusedWindowIndex < windows.length) ? windows[focusedWindowIndex] : null;

        // Copy and update layouts
        var updatedWindows = windows.map(w => Object.assign({}, w));
        for (var i = 0; i < data.changes.length; i++) {
            var id = data.changes[i][0];
            var layout = data.changes[i][1];
            var idx = updatedWindows.findIndex(w => w.id === id);
            if (idx >= 0) {
                updatedWindows[idx].layout = layout;
            }
        }

        // Sort windows by new layout
        updatedWindows = sortWindows(updatedWindows);

        // Find the new index of the previously focused window
        var newFocusIdx = -1;
        if (prevFocusedWindow) {
            newFocusIdx = updatedWindows.findIndex(w => w.id === prevFocusedWindow.id);
        }
        focusedWindowIndex = newFocusIdx;

        windows = updatedWindows;
        updateFocusedWindow();
    }

    function handleWorkspacesChanged(data) {
        allWorkspaces = [...data.workspaces].sort((a, b) => a.idx - b.idx);
        focusedWorkspaceIndex = allWorkspaces.findIndex(w => w.is_focused);
        if (focusedWorkspaceIndex >= 0) {
            var focusedWs = allWorkspaces[focusedWorkspaceIndex];
            focusedWorkspaceId = focusedWs.id;
            focusedMonitorName = focusedWs.output;
            console.log(focusedMonitorName);
        } else {
            focusedWorkspaceIndex = 0;
            focusedWorkspaceId = "";
        }
        updateCurrentOutputWorkspaces();
    }

    function handleWorkspaceActivated(data) {
        focusedWorkspaceId = data.id;
        focusedWorkspaceIndex = allWorkspaces.findIndex(w => w.id === data.id);
        if (focusedWorkspaceIndex >= 0) {
            var activatedWs = allWorkspaces[focusedWorkspaceIndex];
            for (var i = 0; i < allWorkspaces.length; i++) {
                if (allWorkspaces[i].output === activatedWs.output) {
                    allWorkspaces[i].is_active = false;
                    allWorkspaces[i].is_focused = false;
                }
            }
            allWorkspaces[focusedWorkspaceIndex].is_active = true;
            allWorkspaces[focusedWorkspaceIndex].is_focused = data.focused || false;
            focusedMonitorName = activatedWs.output || "";
            updateCurrentOutputWorkspaces();
            allWorkspacesChanged();
        } else {
            focusedWorkspaceIndex = 0;
        }
    }

    function sortWindows(windows) {
        return windows.slice().sort(function (a, b) {
            const aPos = Array.isArray(a.layout?.pos_in_scrolling_layout) ? a.layout.pos_in_scrolling_layout : [0, 0];
            const bPos = Array.isArray(b.layout?.pos_in_scrolling_layout) ? b.layout.pos_in_scrolling_layout : [0, 0];
            const aCol = aPos[0];
            const bCol = bPos[0];
            const aRow = aPos[1];
            const bRow = bPos[1];
            if (aCol !== bCol) {
                return aCol - bCol;
            }
            return aRow - bRow;
        });
    }

    function handleWindowsChanged(data) {
        var newWindows = data.windows.slice(); // shallow copy
        for (var i = 0; i < newWindows.length; i++) {
            if (!newWindows[i].layout) {
                newWindows[i].layout = {};
            }
        }
        windows = sortWindows(newWindows);
        updateFocusedWindow();
    }

    function handleWindowClosed(data) {
        windows = windows.filter(w => w.id !== data.id);
        updateFocusedWindow();
    }

    function handleWindowFocusChanged(data) {
        if (data.id) {
            focusedWindowId = data.id;
            focusedWindowIndex = windows.findIndex(w => w.id === data.id);
        } else {
            focusedWindowId = "";
            focusedWindowIndex = -1;
        }
        updateFocusedWindow();
    }

    function handleOutputsChanged(data) {
        outputs = data;
        console.log("NiriService: Updated outputs:", Object.keys(outputs));
    }

    function handleWindowOpenedOrChanged(data) {
        if (!data.window)
            return;
        var window = data.window;
        var updatedWindows = windows.slice();
        var existingIndex = updatedWindows.findIndex(function (w) {
            return w.id === window.id;
        });
        if (existingIndex >= 0) {
            updatedWindows[existingIndex] = Object.assign({}, updatedWindows[existingIndex], window);
        } else {
            updatedWindows.push(window);
        }
        windows = sortWindows(updatedWindows);
        if (window.is_focused) {
            focusedWindowId = window.id;
            focusedWindowIndex = updatedWindows.findIndex(function (w) {
                return w.id === window.id;
            });
        }
        updateFocusedWindow();
        windowOpenedOrChanged(window);
    }

    function handleOverviewChanged(data) {
        inOverview = data.is_open;
    }

    function updateCurrentOutputWorkspaces() {
        if (!focusedMonitorName) {
            currentOutputWorkspaces = allWorkspaces;
            return;
        }
        var outputWs = allWorkspaces.filter(w => w.output === focusedMonitorName);
        currentOutputWorkspaces = outputWs;
    }

    function cleanWindowTitle(windowTitle) {
        if (windowTitle) {
            return windowTitle.replace(/^[^\x20-\x7E]+/, "");
        }
        return windowTitle;
    }

    function updateFocusedWindow() {
        if (focusedWindowIndex >= 0 && focusedWindowIndex < windows.length) {
            var focusedWin = windows[focusedWindowIndex];
            focusedWindowTitle = cleanWindowTitle(focusedWin.title) || "(Unnamed window)";
            focusedWindowClass = cleanWindowTitle(focusedWin.app_id) || "";
        } else {
            focusedWindowTitle = "";
            focusedWindowClass = "Desktop";
        }
    }

    // Public API functions
    function getActiveWorkspaceName() {
        if (root.allWorkspaces && root.focusedWorkspaceIndex >= 0 && root.focusedWorkspaceIndex < root.allWorkspaces.length) {
            return root.allWorkspaces[root.focusedWorkspaceIndex].name || "";
        }
        return "";
    }

    function getWorkspaceNameByIndex(idx) {
        if (root.allWorkspaces && idx >= 0 && idx < root.allWorkspaces.length) {
            return root.allWorkspaces[idx].name || "";
        }
        return "";
    }

    function getWorkspaceNameById(id) {
        if (root.allWorkspaces && id >= 0) {
            return root.allWorkspaces.find(w => w.id === id).name || "";
        }
        return "";
    }

    function getActiveWorkspaceWindows() {
        if (!root.allWorkspaces || root.focusedWorkspaceIndex === undefined)
            return [];
        var currentWorkspaceObj = root.allWorkspaces[root.focusedWorkspaceIndex];
        if (!currentWorkspaceObj || currentWorkspaceObj.id === undefined)
            return [];
        var currentWorkspaceId = currentWorkspaceObj.id;
        return root.windows ? root.windows.filter(function (windowObj) {
            return windowObj.workspace_id === currentWorkspaceId;
        }) : [];
    }

    function getWindowsByWorkspaceId(wsid) {
        const windowsByWorkspace = {};
        for (const workspace of allWorkspaces) {
            windowsByWorkspace[workspace.id] = windows.filter(window => window.workspace_id === workspace.id);
        }
        return windowsByWorkspace[wsid] || [];
    }

    function getWindowsByWorkspaceIndex(index) {
        if (index < 0 || index >= allWorkspaces.length)
            return [];
        const workspaceId = allWorkspaces[index].id;
        return windows.filter(window => window.workspace_id === workspaceId);
    }

    function switchToWorkspace(workspaceId) {
        if (!niriAvailable)
            return false;
        Quickshell.execDetached(["niri", "msg", "action", "focus-workspace", workspaceId.toString()]);
        return true;
    }

    function switchToWorkspaceUpDown(string) {
        if (!niriAvailable)
            return false;
        Quickshell.execDetached(["niri", "msg", "action", `focus-workspace-${string}`]);
        return true;
    }

    function toggleWindowFloating(windowId) {
        if (!niriAvailable)
            return false;
        Quickshell.execDetached(["niri", "msg", "action", `toggle-window-floating`, `--id`, windowId ? windowId.toString() : focusedWindowId.toString()]);
        return true;
    }

    function focusWindow(windowID) {
        if (!niriAvailable)
            return false;

        if (Number(windowID) === Number(focusedWindowId) && Config.bar.workspaces.doubleClickToCenter) {
            centerWindow();
            return true;
        }

        Quickshell.execDetached(["niri", "msg", "action", `focus-window`, `--id`, windowID.toString()]);
        return true;
    }

    function closeFocusedWindow() {
        if (!niriAvailable)
            return false;
        Quickshell.execDetached(["niri", "msg", "action", `close-window`]);
        return true;
    }

    function closeWindow(windowId) {
        if (!niriAvailable)
            return false;
        Quickshell.execDetached(["niri", "msg", "action", `close-window`, `--id`, windowId ? windowId.toString() : focusedWindowId.toString()]);
        return true;
    }

    function toggleWindowOpacity() {
        if (!niriAvailable)
            return false;
        Quickshell.execDetached(["niri", "msg", "action", `toggle-window-rule-opacity`]);
        return true;
    }

    function expandColumnToAvailable() {
        if (!niriAvailable)
            return false;
        Quickshell.execDetached(["niri", "msg", "action", `expand-column-to-available-width`]);
        return true;
    }

    function centerWindow() {
        if (!niriAvailable)
            return false;
        Quickshell.execDetached(["niri", "msg", "action", `center-window`]);
        return true;
    }

    function screenshotWindow() {
        if (!niriAvailable)
            return false;
        Quickshell.execDetached(["niri", "msg", "action", `screenshot-window`]);
        return true;
    }

    function keyboardShortcutsInhibitWindow() {
        if (!niriAvailable)
            return false;
        Quickshell.execDetached(["niri", "msg", "action", `toggle-keyboard-shortcuts-inhibit`]);
        return true;
    }

    function toggleWindowedFullscreen() {
        if (!niriAvailable)
            return false;
        Quickshell.execDetached(["niri", "msg", "action", `toggle-windowed-fullscreen`]);
        return true;
    }

    function toggleFullscreen() {
        if (!niriAvailable)
            return false;
        Quickshell.execDetached(["niri", "msg", "action", `fullscreen-window`]);
        return true;
    }

    function toggleMaximize() {
        if (!niriAvailable)
            return false;
        Quickshell.execDetached(["niri", "msg", "action", `maximize-column`]);
        return true;
    }

    function toggleOverview() {
        if (!niriAvailable)
            return false;
        Quickshell.execDetached(["niri", "msg", "action", `toggle-overview`]);
        return true;
    }

    function doScreenTransition(delayMs = 500) {
        if (!niriAvailable)
            return false;
        Quickshell.execDetached(["niri", "msg", "action", `do-screen-transition -d`, delayMs.toString()]);
        return true;
    }

    function moveGroupColumnsSequential(curWindowId, windowIds, targetIndex, delayMs) {
        var i = 0;
        // toggleOverview();
        function moveNext() {
            if (i >= windowIds.length) {
                // After all moves, focus curWindowId, hax!
                var timer = Qt.createQmlObject('import QtQuick 2.0; Timer { interval: ' + (delayMs * (i + 1) || 100) + '; repeat: false }', root);
                timer.triggered.connect(function () {
                    timer.stop();
                    timer.destroy();
                    // toggleOverview();

                    focusWindow(Number(curWindowId));
                    i++;
                });
                timer.start();
                return;
            }

            var windowId = windowIds[i];
            var timer = Qt.createQmlObject('import QtQuick 2.0; Timer { interval: ' + (delayMs * (i + 1) || 100) + '; repeat: false }', root);
            timer.triggered.connect(function () {
                timer.stop();
                timer.destroy();
                Niri.moveColumnToIndexAfterFocus(windowId, targetIndex);
                i++;
                moveNext();
            });
            timer.start();
        }
        moveNext();
    }

    function moveColumnToIndexAfterFocus(windowId, index, delayMs = 2) {
        if (!niriAvailable)
            return false;

        if (Number(windowId) === Number(focusedWindowId)) {
            // Already focused,
            Quickshell.execDetached(["niri", "msg", "action", "move-column-to-index", index.toString()]);
            return true;
        }

        focusWindow(windowId);

        var delay = delayMs !== undefined ? delayMs : 25; // Default to 25ms
        var timer = Qt.createQmlObject('import QtQuick 2.0; Timer { interval: ' + delay + '; repeat: false }', root);
        timer.triggered.connect(function () {
            timer.stop();
            timer.destroy();
            Quickshell.execDetached(["niri", "msg", "action", "move-column-to-index", index.toString()]);
        });
        timer.start();
        return true;
    }

    function moveColumnToIndex(windowId, index) {
        if (!niriAvailable)
            return false;
        if (focusWindow(windowId)) {
            Quickshell.execDetached(["niri", "msg", "action", `move-column-to-index`, index.toString()]);
            return true;
        }
        return true;
    }

    function moveWindowToWorkspace(workspaceId) {
        if (!niriAvailable)
            return false;
        Quickshell.execDetached(["niri", "msg", "action", `move-window-to-workspace`, workspaceId.toString()]);
        return true;
    }

    function switchToWorkspaceByIndex(index) {
        if (!niriAvailable || index < 0 || index >= allWorkspaces.length)
            return false;
        var workspace = allWorkspaces[index];
        return switchToWorkspace(workspace.id);
    }

    function switchToWorkspaceByNumber(number, output) {
        if (!niriAvailable)
            return false;
        var targetOutput = output || focusedMonitorName;
        if (!targetOutput) {
            console.warn("NiriService: No output specified for workspace switching");
            return false;
        }
        var outputWorkspaces = allWorkspaces.filter(w => w.output === targetOutput).sort((a, b) => a.idx - b.idx);
        if (number >= 1 && number <= outputWorkspaces.length) {
            var workspace = outputWorkspaces[number - 1];
            return switchToWorkspace(workspace.id);
        }
        console.warn("NiriService: No workspace", number, "found on output", targetOutput);
        return false;
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

    // Picker helpers
    function getCurrentOutputWorkspaceNumbers() {
        return currentOutputWorkspaces.map(w => w.idx + 1);
    }

    function getCurrentWorkspaceNumber() {
        if (focusedWorkspaceIndex >= 0 && focusedWorkspaceIndex < allWorkspaces.length) {
            return allWorkspaces[focusedWorkspaceIndex].idx + 1;
        }
        return 1;
    }

    function getWindowsInScreen(screenX, screenY, screenWidth, screenHeight, windowBorder, padding) {
        if (!focusedWindow?.layout?.pos_in_scrolling_layout)
            return [];
        const focusedCol = focusedWindow.layout.pos_in_scrolling_layout[0];
        const focusedRow = focusedWindow.layout.pos_in_scrolling_layout[1];
        return getActiveWorkspaceWindows().map(window => {
            if (!window.layout?.pos_in_scrolling_layout || !window.layout?.window_size)
                return null;
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
                return {
                    window: window,
                    screenX: winX,
                    screenY: winY,
                    screenW: winW,
                    screenH: winH
                };
            }
            return null;
        }).filter(item => item !== null);
    }

    // Grouping helpers
    function groupWindowsByApp(windows) {
        windows = sortWindows(windows);
        var groups = {};
        for (var i = 0; i < windows.length; i++) {
            var w = windows[i];
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

    function groupWindowsByLayoutAndId(windows) {
        // console.log("=== groupWindowsByLayoutAndId START ===");
        windows = sortWindows(windows); // make sure layout order is respected
        // console.log("Input windows (sorted):");
        // for (var i = 0; i < windows.length; i++) {
        // console.log(" ", i, windows[i].app_id, windows[i].title, windows[i].id);
        // }

        var groups = [];
        var currentGroup = null;

        for (var i = 0; i < windows.length; i++) {
            var w = windows[i];

            if (!currentGroup || currentGroup.app_id !== w.app_id) {
                // Start a new group
                currentGroup = {
                    app_id: w.app_id,
                    windows: [w],
                    count: 1,
                    title: w.title,
                    id: w.id,
                    main: w
                };
                groups.push(currentGroup);
                // console.log(" → new group", w.app_id, "starting with window", w.id);
            } else {
                // Extend the current group
                currentGroup.windows.push(w);
                currentGroup.count = currentGroup.windows.length;
                // console.log(" → extended group", w.app_id, "size now", currentGroup.count);
            }
        }

        // console.log("Final groups:");
        for (var i = 0; i < groups.length; i++) {
            var g = groups[i];
            // console.log(" Group", i, "app:", g.app_id, "count:", g.count, "window IDs:", g.windows.map(x => x.id).join(", "));
        }
        // console.log("=== groupWindowsByLayoutAndId END ===");

        return groups;
    }
}
