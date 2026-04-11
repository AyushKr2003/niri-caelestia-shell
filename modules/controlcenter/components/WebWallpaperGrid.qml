pragma ComponentBehavior: Bound

import ".."
import "../../../components"
import qs.components
import qs.components.controls
import qs.components.effects
import qs.components.containers
import qs.components.images
import qs.services
import qs.config
import qs.utils
import Caelestia
import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts
import QtQuick.Effects

ColumnLayout {
    id: root

    required property Session session
    
    spacing: Appearance.spacing.lg
    Layout.fillWidth: true
    Layout.minimumHeight: 400

    // Properties & State
    readonly property string scriptBaseDir: Qt.resolvedUrl("../../../scripts/webWallpaper").toString().replace("file://", "")
    property string currentServer: "uhdpaper" 
    readonly property string scriptDir: scriptBaseDir + "/" + currentServer

    property string keyword: ""
    property string resolution: currentServer === "uhdpaper" ? "2k" : "1920x1080"
    property bool loading: false
    property var wallpapers: []
    property var categoriesList: []

    property var wallhavenCategories: ["general", "anime"]
    property var wallhavenPurity: ["sfw"]
    property string wallhavenSort: "date_added"
    property string wallhavenRange: "1M"
    property string wallhavenColor: ""
    property bool showApiKey: false
    property bool isClearingApiKey: false
    property bool wallhavenHasApiKey: false

    property int currentApiPage: 1
    property int lastApiPage: 1

    property int currentPage: 0
    readonly property int itemsPerPage: 4 * grid.columnsCount
    readonly property var paginatedWallpapers: wallpapers.slice(currentPage * itemsPerPage, (currentPage + 1) * itemsPerPage)

    // Modular Filter Section
    WebWallpaperFilters {
        id: filterSection
        gridRoot: root
    }

    // Grid section
    Item {
        Layout.fillWidth: true
        Layout.fillHeight: true
        implicitHeight: 4 * (140 + Appearance.spacing.lg)
        
        GridView {
            id: grid
            anchors.fill: parent
            visible: root.wallpapers.length > 0 && !root.loading

            interactive: false
            height: contentHeight

            readonly property int minCellWidth: 200 + Appearance.spacing.lg
            readonly property int columnsCount: Math.max(1, Math.floor(width / minCellWidth))

            cellWidth: width / columnsCount
            cellHeight: 140 + Appearance.spacing.lg

            model: root.paginatedWallpapers
            clip: true

            delegate: Item {
                id: rootDelegate
                required property var modelData

                width: grid.cellWidth
                height: grid.cellHeight

                WebWallpaperDelegate {
                    anchors.fill: parent
                    modelData: rootDelegate.modelData
                    isDownloading: downloadProcess.running && downloadProcess.currentSlug === rootDelegate.modelData.slug
                    onClicked: root.downloadAndSet(rootDelegate.modelData.slug)
                }
            }
        }

        StyledBusyIndicator {
            anchors.centerIn: parent
            visible: root.loading
        }

        StyledText {
            anchors.centerIn: parent
            text: qsTr("No wallpapers found or search something...")
            visible: root.wallpapers.length === 0 && !root.loading
            opacity: 0.6
        }
    }

    // Pagination Navigation
    RowLayout {
        Layout.alignment: Qt.AlignHCenter
        Layout.topMargin: Appearance.spacing.md
        visible: root.wallpapers.length > root.itemsPerPage && !root.loading
        spacing: Appearance.spacing.lg

        IconButton {
            icon: "chevron_left"
            onClicked: if (root.currentPage > 0) root.currentPage--
            enabled: root.currentPage > 0
            type: IconButton.Tonal
        }

        StyledText {
            text: qsTr("Page %1 of %2").arg(root.currentPage + 1).arg(Math.ceil(root.wallpapers.length / root.itemsPerPage))
            font.pointSize: Appearance.font.size.bodyMedium
            font.weight: 500
        }

        IconButton {
            icon: "chevron_right"
            onClicked: {
                if ((root.currentPage + 1) * root.itemsPerPage < root.wallpapers.length) {
                    root.currentPage++;
                } else if (root.currentServer === "wallhaven" && root.currentApiPage < root.lastApiPage) {
                    root.currentApiPage++;
                    root.fetchWallpapers(false);
                    root.currentPage++;
                }
            }
            enabled: ((root.currentPage + 1) * root.itemsPerPage < root.wallpapers.length) || (root.currentServer === "wallhaven" && root.currentApiPage < root.lastApiPage)
            type: IconButton.Tonal
        }
    }

    // Logic & Processes
    function fetchWallpapers(reset) {
        if (reset === undefined) reset = true;
        if (reset) {
            root.currentPage = 0;
            root.currentApiPage = 1;
            root.wallpapers = [];
        }
        root.loading = true;
        let cmd = "";
        if (root.currentServer === "uhdpaper") {
            cmd = `cd '${root.scriptDir}' && $CAELESTIA_VIRTUAL_ENV/bin/python3 main.py ${root.keyword ? "--keyword '" + root.keyword + "'" : ""} --pages 3 --list --json`;
        } else {
            let cats = root.wallhavenCategories.join(",");
            let purity = root.wallhavenPurity.join(",");
            let sort = root.wallhavenSort;
            let range = root.wallhavenRange;
            let color = root.wallhavenColor;
            cmd = `cd '${root.scriptDir}' && $CAELESTIA_VIRTUAL_ENV/bin/python3 main.py search ${root.keyword ? "'" + root.keyword + "'" : ""} --categories '${cats}' --purity '${purity}' --sort '${sort}' ${sort === "toplist" ? "--range " + range : ""} ${color ? "--colors " + color : ""} --resolution ${root.resolution} --page ${root.currentApiPage} --json`;
        }
        listProcess.command = ["bash", "-c", cmd];
        listProcess.running = true;
    }

    function fetchCategories() {
        if (root.currentServer !== "uhdpaper") return;
        categoryProcess.command = ["bash", "-c", `cd '${root.scriptDir}' && $CAELESTIA_VIRTUAL_ENV/bin/python3 main.py --categories --json`];
        categoryProcess.running = true;
    }

    function downloadAndSet(slug) {
        downloadProcess.currentSlug = slug;
        let cmd = "";
        if (root.currentServer === "uhdpaper") {
            cmd = `cd '${root.scriptDir}' && $CAELESTIA_VIRTUAL_ENV/bin/python3 main.py --slug '${slug}' --res ${root.resolution} --output $HOME/Pictures/Wallpapers --json`;
        } else {
            cmd = `cd '${root.scriptDir}' && $CAELESTIA_VIRTUAL_ENV/bin/python3 main.py download '${slug}' --dir $HOME/Pictures/Wallpapers --json`;
        }
        downloadProcess.command = ["bash", "-c", cmd];
        downloadProcess.running = true;
    }

    function saveApiKey(key) {
        root.isClearingApiKey = false;
        configProcess.command = ["bash", "-c", `cd '${root.scriptDir}' && $CAELESTIA_VIRTUAL_ENV/bin/python3 main.py config set api_key ${key}`];
        configProcess.running = true;
    }

    function clearApiKey() {
        root.isClearingApiKey = true;
        configProcess.command = ["bash", "-c", `cd '${root.scriptDir}' && $CAELESTIA_VIRTUAL_ENV/bin/python3 main.py config set api_key ""`];
        configProcess.running = true;
    }

    function checkApiKey() {
        checkApiKeyProcess.command = ["bash", "-c", `cd '${root.scriptBaseDir}/wallhaven' && $CAELESTIA_VIRTUAL_ENV/bin/python3 main.py config show`];
        checkApiKeyProcess.running = true;
    }

    function notify(title, message, icon, type) {
        Toaster.toast(title, message, icon, type);
    }

    Process {
        id: listProcess
        stdout: StdioCollector {
            onStreamFinished: {
                root.loading = false;
                if (text) {
                    try {
                        let response = JSON.parse(text);
                        let newData = [];
                        if (root.currentServer === "wallhaven") {
                            root.lastApiPage = response.meta.last_page;
                            let rawData = response.data;
                            for (let i = 0; i < rawData.length; i++) {
                                newData.push({ slug: rawData[i].id, url_thumb: rawData[i].thumbs.large });
                            }
                        } else {
                            newData = response;
                        }
                        if (root.currentApiPage === 1) root.wallpapers = newData;
                        else root.wallpapers = root.wallpapers.concat(newData);
                    } catch (e) { console.error("Failed to parse wallpaper list:", e, "Output was:", text); }
                }
            }
        }
        stderr: StdioCollector {
            onStreamFinished: if (text) console.warn("List process error:", text)
        }
    }

    Process {
        id: categoryProcess
        stdout: StdioCollector {
            onStreamFinished: {
                if (text) {
                    try {
                        const data = JSON.parse(text);
                        const list = [];
                        for (let key in data) list.push({name: key, query: data[key]});
                        root.categoriesList = list;
                    } catch (e) { console.error("Failed to parse categories:", e, "Output was:", text); }
                }
            }
        }
    }

    Process {
        id: checkApiKeyProcess
        stdout: StdioCollector {
            onStreamFinished: {
                if (text) {
                    // Check if api_key is followed by anything other than (not set)
                    root.wallhavenHasApiKey = text.indexOf("api_key                   ***") !== -1;
                }
            }
        }
    }

    Process {
        id: configProcess
        stdout: StdioCollector {
            onStreamFinished: if (text && configProcess.exitCode === 0) console.log("Wallhaven config updated:", text)
        }
        stderr: StdioCollector {
            onStreamFinished: if (text && configProcess.exitCode !== 0) console.warn("Config process error:", text)
        }
        onExited: (code) => {
            if (code === 0) {
                if (!root.isClearingApiKey) {
                    root.wallhavenHasApiKey = true;
                    root.notify(qsTr("Wallhaven Config"), qsTr("Settings updated successfully"), "key", Toast.Success);
                } else {
                    root.wallhavenHasApiKey = false;
                }
            } else {
                root.notify(qsTr("Wallhaven Config"), qsTr("Invalid API Key. Please check and try again."), "key_off", Toast.Error);
            }
            root.isClearingApiKey = false;
        }
    }

    Process {
        id: downloadProcess
        property string currentSlug: ""
        stdout: StdioCollector {
            onStreamFinished: {
                if (text) {
                    try {
                        const result = JSON.parse(text);
                        if (result.status === "success") Wallpapers.setWallpaper(result.path);
                    } catch (e) { console.error("Failed to parse download result:", e, "Output was:", text); }
                }
                downloadProcess.currentSlug = "";
            }
        }
    }
    
    Component.onCompleted: {
        fetchCategories();
        fetchWallpapers();
        checkApiKey();
    }
}
