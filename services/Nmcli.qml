pragma Singleton
pragma ComponentBehavior: Bound

import Quickshell
import QtQuick
import Caelestia.Services

Singleton {
    id: root

    // These properties map to the NetworkManager API
    property bool wifiEnabled: NetworkManagerProvider.wifiEnabled
    property bool isConnected: NetworkManagerProvider.isConnected
    property string activeConnection: NetworkManagerProvider.activeConnection
    readonly property bool scanning: NetworkManagerProvider.scanning
    
    // Convert native QVariantList of maps to our AccessPoint objects
    readonly property list<AccessPoint> networks: {
        let list = []
        for (let i = 0; i < NetworkManagerProvider.networks.length; i++) {
            list.push(apComp.createObject(root, { lastIpcObject: NetworkManagerProvider.networks[i] }))
        }
        return list
    }
    
    readonly property AccessPoint active: networks.find(n => n.active) ?? null

    // For backwards compability with code relying on NetworkManager properties
    property var deviceStatus: null
    property var wirelessInterfaces: []
    property var ethernetInterfaces: []
    property string activeInterface: ""
    property list<string> savedConnections: []
    property list<string> savedConnectionSsids: []
    property var ethernetDevices: []

    signal connectionFailed(string ssid)

    // Legacy method stubs adapted to native DBus
    function enableWifi(enabled: bool, callback: var): void {
        NetworkManagerProvider.wifiEnabled = enabled;
        if (callback) callback({success: true, output: ""});
    }

    function toggleWifi(callback: var): void {
        NetworkManagerProvider.toggleWifi();
        if (callback) callback({success: true, output: ""});
    }

    function getWifiStatus(callback: var): void {
        if (callback) callback(NetworkManagerProvider.wifiEnabled);
    }
    
    function rescanWifi(): void {
        NetworkManagerProvider.rescanWifi();
    }
    
    function scanWirelessNetworks(interfaceName: string, callback: var): void {
        NetworkManagerProvider.rescanWifi();
        if (callback) callback({success: true});
    }

    function connectToNetwork(ssid: string, password: string, bssid: string, callback: var): void {
        if (password && password.length > 0) {
            NetworkManagerProvider.connectToSecureNetwork(ssid, password);
        } else {
            NetworkManagerProvider.connectToNetwork(ssid);
        }
        if (callback) callback({success: true, output: "", needsPassword: false});
    }

    function connectToNetworkWithPasswordCheck(ssid: string, isSecure: bool, callback: var, bssid: string): void {
        connectToNetwork(ssid, "", bssid, callback);
    }

    function connectWireless(ssid: string, password: string, bssid: string, callback: var, retryCount: int): void {
        connectToNetwork(ssid, password, bssid, callback);
    }

    function forgetNetwork(ssid: string, callback: var): void {
        NetworkManagerProvider.deleteNetwork(ssid);
        if (callback) callback({success: true, output: ""});
    }

    function disconnectFromNetwork(): void {
        NetworkManagerProvider.disconnectFromNetwork();
    }

    function refreshStatus(callback: var): void {
        if (callback) callback({
            connected: NetworkManagerProvider.isConnected,
            interface: "",
            connection: NetworkManagerProvider.activeConnection
        });
    }

    function getNetworks(callback: var): void {
        if (callback) callback([]);
    }

    function hasSavedProfile(ssid: string): bool {
        return false;
    }

    component AccessPoint: QtObject {
        required property var lastIpcObject
        readonly property string ssid: lastIpcObject.ssid
        readonly property string bssid: lastIpcObject.bssid
        readonly property int strength: lastIpcObject.strength
        readonly property int frequency: lastIpcObject.frequency
        readonly property bool active: lastIpcObject.active
        readonly property string security: lastIpcObject.security
        readonly property bool isSecure: security !== ""
    }

    Component {
        id: apComp
        AccessPoint {}
    }
}
