import Quickshell.Io

JsonObject {
    property Apps apps: Apps {}
    property Battery battery: Battery {}

    component Apps: JsonObject {
        property list<string> terminal: ["foot"]
        property list<string> audio: ["pavucontrol"]
        property list<string> playback: ["mpv"]
        property list<string> explorer: ["thunar"]
    }

    component Battery: JsonObject {
        property list<var> warnLevels: [
            {
                level: 30,
                title: "Low battery",
                message: "You might want to plug in a charger",
                icon: "battery_2_bar"
            },
            {
                level: 20,
                title: "Did you see the previous message?",
                message: "You should probably plug in a charger <b>now</b>",
                icon: "battery_1_bar"
            },
            {
                level: 10,
                title: "Critical battery level",
                message: "PLUG THE CHARGER RIGHT NOW!!",
                icon: "battery_alert",
                critical: true
            }
        ]
        property int criticalLevel: 3 // Battery level to trigger critical action (e.g., suspend)
        property bool enableWarnings: true
    }
}
