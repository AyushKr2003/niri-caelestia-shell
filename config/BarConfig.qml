import Quickshell.Io

JsonObject {
    property bool persistent: false
    property bool showOnHover: true
    property int dragThreshold: 20
    property ScrollActions scrollActions: ScrollActions {}
    property Workspaces workspaces: Workspaces {}
    property Tray tray: Tray {}
    property Status status: Status {}
    property Clock clock: Clock {}
    property Popouts popouts: Popouts {}
    property Sizes sizes: Sizes {}

    property list<var> entries: [
        {
            id: "logo",
            enabled: true
        },
        {
            id: "workspaces",
            enabled: true
        },
        {
            id: "spacer",
            enabled: true
        },
        {
            id: "activeWindow",
            enabled: true
        },
        {
            id: "spacer",
            enabled: true
        },
        {
            id: "tray",
            enabled: true
        },
        {
            id: "clock",
            enabled: true
        },
        {
            id: "statusIcons",
            enabled: true
        },
        {
            id: "power",
            enabled: true
        },
        {
            id: "idleInhibitor",
            enabled: false
        }
    ]

    component ScrollActions: JsonObject {
        property bool workspaces: true
        property bool volume: true
        property bool brightness: true
    }

    component Workspaces: JsonObject {
        property int shown: 4
        property bool activeIndicator: true
        property bool occupiedBg: true
        property bool showWindows: true
        property bool perMonitorWorkspaces: true
        property bool windowIconImage: true // false -> MaterialIcons, true -> IconImage
        property int windowIconGap: 5
        property int windowIconSize: 30
        property bool groupIconsByApp: false
        property bool groupingRespectsLayout: true
        property bool focusedWindowBlob: true
        property bool windowRighClickContext: true
        property bool windowContextDefaultExpand: true
        property bool doubleClickToCenter: true
        property int windowContextWidth: 250
        property bool activeTrail: false
        property bool pagerActive: true
        property string label: "◦" // ""
        property string occupiedLabel: "⊙" // "󰮯"
        property string activeLabel: "󰮯" //Handled in workspace.qml
    }

    component Tray: JsonObject {
        property bool background: false
        property bool compact: false
        property bool recolour: false
    }

    component Status: JsonObject {
        property bool showAudio: false
        property bool showMicrophone: false
        property bool showKbLayout: false
        property bool showNetwork: true
        property bool showWifi: true
        property bool showBluetooth: true
        property bool showBattery: true
        property bool showLockStatus: true
    }

    component Clock: JsonObject {
        property bool showIcon: true
    }

    component Popouts: JsonObject {
        property bool activeWindow: true
        property bool tray: true
        property bool statusIcons: true
    }

    component Sizes: JsonObject {
        property int innerWidth: 40
        property int windowPreviewSize: 400
        property int trayMenuWidth: 300
        property int batteryWidth: 250
        property int networkWidth: 320
    }
}
