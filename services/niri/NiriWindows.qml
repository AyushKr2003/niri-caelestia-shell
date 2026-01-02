import QtQuick
import Quickshell
import Quickshell.Io

// Windows module - handles window state, focus, and window actions
Item {
    id: root
    visible: false
    
    required property var core
    required property var workspaces
    
    property var windows: []
    property int focusedWindowIndex: -1
    property string focusedWindowId: ""
    property string focusedWindowTitle: "(No active window)"
    property string focusedWindowClass: "(No active window)"
    property var focusedWindow: windows[focusedWindowIndex] ?? null
    property var lastFocusedWindow: null
    property int lastFocusedColumn: -1
    property string scrollDirection: "none"
    property bool inOverview: false
    
    signal windowOpenedOrChanged(var windowData)

    onFocusedWindowIdChanged: {
        if (focusedWindow) {
            lastFocusedWindow = focusedWindow;
            const pos = focusedWindow.layout?.pos_in_scrolling_layout;
            if (Array.isArray(pos)) {
                const currentCol = pos[0];
                if (lastFocusedColumn >= 0) {
                    scrollDirection = currentCol > lastFocusedColumn ? "right" 
                                    : currentCol < lastFocusedColumn ? "left" 
                                    : "none";
                }
                lastFocusedColumn = currentCol;
            } else {
                scrollDirection = "none";
            }
        }
    }

    onWindowsChanged: {
        if (workspaces) {
            workspaces.updateWorkspaceHasWindows(windows);
        }
    }

    Connections {
        target: root.core
        function onInitialized() {
            root.loadInitialData();
        }
        function onNiriEvent(event) {
            if (event.WindowsChanged) {
                root.handleWindowsChanged(event.WindowsChanged);
            } else if (event.WindowLayoutsChanged) {
                root.handleWindowLayoutsChanged(event.WindowLayoutsChanged);
            } else if (event.WindowClosed) {
                root.handleWindowClosed(event.WindowClosed);
            } else if (event.WindowFocusChanged) {
                root.handleWindowFocusChanged(event.WindowFocusChanged);
            } else if (event.WindowOpenedOrChanged) {
                root.handleWindowOpenedOrChanged(event.WindowOpenedOrChanged);
            } else if (event.OverviewOpenedOrClosed) {
                root.inOverview = event.OverviewOpenedOrClosed.is_open;
            }
        }
    }

    function loadInitialData(): void {
        if (!core?.niriAvailable) return;
        initialWindowsQuery.running = true;
        initialFocusedQuery.running = true;
    }

    Process {
        id: initialWindowsQuery
        command: ["niri", "msg", "-j", "windows"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                if (text && text.trim()) {
                    try {
                        const data = JSON.parse(text.trim());
                        if (data?.windows) {
                            root.handleWindowsChanged(data);
                            console.log("NiriWindows: Loaded", data.windows.length, "initial windows");
                        }
                    } catch (e) {
                        console.warn("NiriWindows: Failed to parse initial windows:", e);
                    }
                }
            }
        }
    }

    Process {
        id: initialFocusedQuery
        command: ["niri", "msg", "-j", "focused-window"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                if (text && text.trim()) {
                    try {
                        const data = JSON.parse(text.trim());
                        if (data?.id) {
                            root.handleWindowFocusChanged({ id: data.id });
                            console.log("NiriWindows: Initial focused window:", data.id);
                        }
                    } catch (e) {
                        console.warn("NiriWindows: Failed to parse focused window:", e);
                    }
                }
            }
        }
    }

    function handleWindowsChanged(data): void {
        let newWindows = data.windows.slice();
        for (let i = 0; i < newWindows.length; i++) {
            if (!newWindows[i].layout) {
                newWindows[i].layout = {};
            }
        }
        windows = sortWindows(newWindows);
        updateFocusedWindow();
    }

    function handleWindowLayoutsChanged(data): void {
        if (!data.changes) return;
        const prevFocusedWindow = (focusedWindowIndex >= 0 && focusedWindowIndex < windows.length) 
            ? windows[focusedWindowIndex] : null;

        let updatedWindows = windows.map(w => Object.assign({}, w));
        for (var i = 0; i < data.changes.length; i++) {
            var id = data.changes[i][0];
            var layout = data.changes[i][1];
            var idx = updatedWindows.findIndex(w => w.id === id);
            if (idx >= 0) {
                updatedWindows[idx].layout = layout;
            }
        }

        updatedWindows = sortWindows(updatedWindows);
        let newFocusIdx = -1;
        if (prevFocusedWindow) {
            newFocusIdx = updatedWindows.findIndex(w => w.id === prevFocusedWindow.id);
        }
        focusedWindowIndex = newFocusIdx;
        windows = updatedWindows;
        updateFocusedWindow();
    }

    function handleWindowClosed(data): void {
        windows = windows.filter(w => w.id !== data.id);
        updateFocusedWindow();
    }

    function handleWindowFocusChanged(data): void {
        if (data.id) {
            focusedWindowId = data.id;
            focusedWindowIndex = windows.findIndex(w => w.id === data.id);
        } else {
            focusedWindowId = "";
            focusedWindowIndex = -1;
        }
        updateFocusedWindow();
    }

    function handleWindowOpenedOrChanged(data): void {
        if (!data.window) return;
        const window = data.window;
        let updatedWindows = windows.slice();
        const existingIndex = updatedWindows.findIndex(w => w.id === window.id);
        
        if (existingIndex >= 0) {
            updatedWindows[existingIndex] = Object.assign({}, updatedWindows[existingIndex], window);
        } else {
            updatedWindows.push(window);
        }
        
        windows = sortWindows(updatedWindows);
        if (window.is_focused) {
            focusedWindowId = window.id;
            focusedWindowIndex = windows.findIndex(w => w.id === window.id);
        }
        updateFocusedWindow();
        windowOpenedOrChanged(window);
    }

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

    function cleanWindowTitle(title) {
        return title ? title.replace(/^[^\x20-\x7E]+/, "") : title;
    }

    function updateFocusedWindow(): void {
        if (focusedWindowIndex >= 0 && focusedWindowIndex < windows.length) {
            const win = windows[focusedWindowIndex];
            focusedWindowTitle = cleanWindowTitle(win.title) || "(Unnamed window)";
            focusedWindowClass = cleanWindowTitle(win.app_id) || "";
        } else {
            focusedWindowTitle = "";
            focusedWindowClass = "Desktop";
        }
    }
}
