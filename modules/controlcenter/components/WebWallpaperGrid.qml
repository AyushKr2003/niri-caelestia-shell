pragma ComponentBehavior: Bound

import ".."
import "../../components"
import qs.components
import qs.components.controls
import qs.components.effects
import qs.components.containers
import qs.components.images
import qs.services
import qs.config
import qs.utils
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

    readonly property string scriptDir: Qt.resolvedUrl("../../../scripts/random_wallpaper").toString().replace("file://", "")

    property string keyword: ""
    property string resolution: "2k"
    property bool loading: false
    property var wallpapers: []
    property var categoriesList: []

    property int currentPage: 0
    readonly property int itemsPerPage: 4 * grid.columnsCount
    readonly property var paginatedWallpapers: wallpapers.slice(currentPage * itemsPerPage, (currentPage + 1) * itemsPerPage)

    // Search & Options section
    SectionContainer {
        Layout.fillWidth: true
        contentSpacing: Appearance.spacing.md

        RowLayout {
            spacing: Appearance.spacing.md
            Layout.fillWidth: true

            StyledTextField {
                id: searchField
                Layout.fillWidth: true
                placeholderText: qsTr("Search wallpapers...")
                text: root.keyword
                onTextChanged: root.keyword = text
                onAccepted: root.fetchWallpapers()
            }

            IconButton {
                icon: "search"
                onClicked: root.fetchWallpapers()
                enabled: !root.loading
            }
            
            IconButton {
                icon: "casino"
                onClicked: {
                    searchField.text = "";
                    root.keyword = "";
                    root.fetchWallpapers();
                }
                enabled: !root.loading
            }
        }

        // Categories Chips
        Flow {
            Layout.fillWidth: true
            Layout.topMargin: Appearance.spacing.xs
            Layout.bottomMargin: Appearance.spacing.xs
            spacing: Appearance.spacing.sm
            visible: root.categoriesList.length > 0

            Repeater {
                model: root.categoriesList
                delegate: TextButton {
                    required property var modelData
                    text: modelData.name.charAt(0).toUpperCase() + modelData.name.slice(1)
                    checked: root.keyword.toLowerCase() === modelData.name.toLowerCase()
                    onClicked: {
                        root.keyword = modelData.name;
                        searchField.text = modelData.name;
                        root.fetchWallpapers();
                    }
                    type: checked ? TextButton.Filled : TextButton.Tonal
                    font.pointSize: Appearance.font.size.labelLarge
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.topMargin: Appearance.spacing.sm
            spacing: Appearance.spacing.xxl

            // Resolution
            ColumnLayout {
                spacing: Appearance.spacing.xs
                Layout.alignment: Qt.AlignTop
                StyledText {
                    text: qsTr("Resolution")
                    font.pointSize: Appearance.font.size.labelLarge
                    font.weight: 600
                    color: Colours.palette.m3primary
                }

                RowLayout {
                    spacing: Appearance.spacing.xs
                    Repeater {
                        model: ["4k", "2k", "1080p"]
                        delegate: TextButton {
                            required property var modelData
                            text: modelData.toUpperCase()
                            checked: root.resolution === modelData
                            onClicked: root.resolution = modelData
                            type: checked ? TextButton.Filled : TextButton.Tonal
                            font.pointSize: Appearance.font.size.labelMedium
                        }
                    }
                }
            }
        }
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

            interactive: false // Pagination handles movement
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
                required property int index

                width: grid.cellWidth
                height: grid.cellHeight

                readonly property real itemMargin: Appearance.spacing.lg / 2
                readonly property real itemRadius: Appearance.rounding.normal

                StateLayer {
                    anchors.fill: parent
                    anchors.leftMargin: itemMargin
                    anchors.rightMargin: itemMargin
                    anchors.topMargin: itemMargin
                    anchors.bottomMargin: itemMargin
                    radius: itemRadius

                    function onClicked(): void {
                        root.downloadAndSet(rootDelegate.modelData.slug);
                    }
                }

                StyledClippingRect {
                    anchors.fill: parent
                    anchors.leftMargin: itemMargin
                    anchors.rightMargin: itemMargin
                    anchors.topMargin: itemMargin
                    anchors.bottomMargin: itemMargin
                    color: Colours.tPalette.m3surfaceContainer
                    radius: itemRadius
                    
                    Image {
                        source: rootDelegate.modelData.url_thumb
                        anchors.fill: parent
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        
                        opacity: status === Image.Ready ? 1 : 0
                        Behavior on opacity { NumberAnimation { duration: 300 } }

                        onStatusChanged: {
                            if (status === Image.Error) {
                                console.warn("Failed to load web wallpaper thumb:", rootDelegate.modelData.url_thumb);
                            }
                        }
                    }

                    // Progress overlay
                    Rectangle {
                        anchors.fill: parent
                        color: Qt.rgba(0, 0, 0, 0.5)
                        visible: downloadProcess.running && downloadProcess.currentSlug === rootDelegate.modelData.slug
                        
                        StyledBusyIndicator {
                            anchors.centerIn: parent
                        }
                    }

                    // Filename overlay
                    Rectangle {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        height: 30
                        color: Qt.rgba(0, 0, 0, 0.4)
                        
                        StyledText {
                            anchors.centerIn: parent
                            width: parent.width - 10
                            text: rootDelegate.modelData.slug
                            font.pointSize: Appearance.font.size.bodySmall
                            color: "white"
                            elide: Text.ElideMiddle
                            horizontalAlignment: Text.AlignHCenter
                        }
                    }
                }
            }
        }

        // Loading indicator
        StyledBusyIndicator {
            anchors.centerIn: parent
            visible: root.loading
        }

        // Empty state
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
            onClicked: if ((root.currentPage + 1) * root.itemsPerPage < root.wallpapers.length) root.currentPage++
            enabled: (root.currentPage + 1) * root.itemsPerPage < root.wallpapers.length
            type: IconButton.Tonal
        }
    }

    function fetchWallpapers() {
        root.currentPage = 0;
        root.loading = true;
        root.wallpapers = [];
        const cmd = `cd '${root.scriptDir}' && $CAELESTIA_VIRTUAL_ENV/bin/python3 main.py ${root.keyword ? "--keyword '" + root.keyword + "'" : ""} --pages 1 --list --json`;
        listProcess.command = ["bash", "-c", cmd];
        listProcess.running = true;
    }

    function fetchCategories() {
        categoryProcess.command = ["bash", "-c", `cd '${root.scriptDir}' && $CAELESTIA_VIRTUAL_ENV/bin/python3 main.py --categories --json`];
        categoryProcess.running = true;
    }

    function downloadAndSet(slug) {
        downloadProcess.currentSlug = slug;
        downloadProcess.command = [
            "bash", "-c",
            `cd '${root.scriptDir}' && $CAELESTIA_VIRTUAL_ENV/bin/python3 main.py --slug '${slug}' --res ${root.resolution} --output $HOME/Pictures/Wallpapers --json`
        ];
        downloadProcess.running = true;
    }

    Process {
        id: listProcess
        
        stdout: StdioCollector {
            onStreamFinished: {
                root.loading = false;
                if (text) {
                    try {
                        root.wallpapers = JSON.parse(text);
                    } catch (e) {
                        console.error("Failed to parse wallpaper list:", e, "Output was:", text);
                    }
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
                        for (let key in data) {
                            list.push({name: key, query: data[key]});
                        }
                        root.categoriesList = list;
                    } catch (e) {
                        console.error("Failed to parse categories:", e, "Output was:", text);
                    }
                }
            }
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
                        if (result.status === "success") {
                            Wallpapers.setWallpaper(result.path);
                        }
                    } catch (e) {
                        console.error("Failed to parse download result:", e, "Output was:", text);
                    }
                }
                downloadProcess.currentSlug = "";
            }
        }
    }
    
    Component.onCompleted: {
        fetchCategories();
        fetchWallpapers();
    }
}
