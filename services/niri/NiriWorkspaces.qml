import QtQuick
import Quickshell
import Quickshell.Io

// Workspaces module - handles workspace state, switching, and context menu
Item {
    id: root
    visible: false
    
    required property var core
    
    property var allWorkspaces: []
    property int focusedWorkspaceIndex: 0
    property string focusedWorkspaceId: ""
    property var currentOutputWorkspaces: []
    property string focusedMonitorName: ""
    property var workspaceHasWindows: ({})
    
    // Context menu state
    property bool wsContextExpanded: false
    property var wsContextAnchor: null
    property string wsContextType: "none"
    
    Timer {
        id: wsAnchorClearTimer
        interval: 300
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

    Connections {
        target: root.core
        function onInitialized() {
            root.loadInitialData();
        }
        function onNiriEvent(event) {
            if (event.WorkspacesChanged) {
                root.handleWorkspacesChanged(event.WorkspacesChanged);
            } else if (event.WorkspaceActivated) {
                root.handleWorkspaceActivated(event.WorkspaceActivated);
            }
        }
    }

    function loadInitialData(): void {
        if (!core?.niriAvailable) return;
        initialDataQuery.running = true;
    }
    
    Process {
        id: initialDataQuery
        command: ["niri", "msg", "-j", "workspaces"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                if (text && text.trim()) {
                    try {
                        const data = JSON.parse(text.trim());
                        root.handleWorkspacesChanged({ workspaces: data });
                    } catch (e) {
                        console.warn("NiriWorkspaces: Failed to parse initial data:", e);
                    }
                }
            }
        }
    }

    function handleWorkspacesChanged(data): void {
        allWorkspaces = [...data.workspaces].sort((a, b) => a.idx - b.idx);
        focusedWorkspaceIndex = allWorkspaces.findIndex(w => w.is_focused);
        
        if (focusedWorkspaceIndex >= 0) {
            const focusedWs = allWorkspaces[focusedWorkspaceIndex];
            focusedWorkspaceId = focusedWs.id;
            focusedMonitorName = focusedWs.output;
            console.log("NiriWorkspaces: Focused monitor:", focusedMonitorName);
        } else {
            focusedWorkspaceIndex = 0;
            focusedWorkspaceId = "";
        }
        updateCurrentOutputWorkspaces();
    }

    function handleWorkspaceActivated(data): void {
        focusedWorkspaceId = data.id;
        focusedWorkspaceIndex = allWorkspaces.findIndex(w => w.id === data.id);
        
        if (focusedWorkspaceIndex >= 0) {
            const activatedWs = allWorkspaces[focusedWorkspaceIndex];
            for (let i = 0; i < allWorkspaces.length; i++) {
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

    function updateCurrentOutputWorkspaces(): void {
        if (!focusedMonitorName) {
            currentOutputWorkspaces = allWorkspaces;
            return;
        }
        currentOutputWorkspaces = allWorkspaces.filter(w => w.output === focusedMonitorName);
    }

    function updateWorkspaceHasWindows(windows): void {
        let newState = {};
        for (const ws of allWorkspaces) {
            newState[ws.idx] = false;
        }
        for (const window of windows) {
            if (window.workspace_id !== undefined && window.workspace_id !== null) {
                const idx = getWorkspaceIdxById(window.workspace_id);
                if (idx >= 0) newState[idx] = true;
            }
        }
        if (JSON.stringify(workspaceHasWindows) !== JSON.stringify(newState)) {
            workspaceHasWindows = newState;
            console.log("NiriWorkspaces: Updated workspaceHasWindows:", JSON.stringify(newState));
        }
    }

    function getWorkspaceIdxById(workspaceId): int {
        const ws = allWorkspaces.find(w => w.id === workspaceId);
        return ws ? ws.idx : -1;
    }
}
