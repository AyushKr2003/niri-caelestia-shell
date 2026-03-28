import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import qs.config
import qs.services
import "../../../components"
import "../../../components/controls"

Item {
    id: browseView

    readonly property var c: Colours.tPalette
    readonly property string fontDisplay: Config.appearance.font.family.sans
    readonly property string fontBody:    Config.appearance.font.family.sans

    signal novelSelected(string novelId)

    function reset() {
        console.log("[NovelBrowseView] Resetting search and filters")
        searchBar.text = ""
        searchBar.isSearchActive = false
        currentFilter = "hot"
        Novel.clearNovelList()
        Novel.fetchHot()
    }

    property string currentFilter: "hot"

    function _switchFilter(f) {
        if (currentFilter === f) return
        currentFilter = f
        searchBar.isSearchActive = false
        searchBar.text = ""
        Novel.clearNovelList()
        if (f === "hot") Novel.fetchHot()
        else             Novel.fetchLatest(true)
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        // ── Top bar ───────────────────────────────────────────────────────────
        Rectangle {
            Layout.fillWidth: true
            height: 64
            color: c.m3surfaceContainerLow
            z: 2

            RowLayout {
                anchors { fill: parent; leftMargin: Appearance.padding.lg; rightMargin: Appearance.padding.md }
                spacing: Appearance.spacing.md

                // Title (hidden while search bar is open)
                RowLayout {
                    spacing: Appearance.spacing.md
                    visible: !searchBar.isSearchActive
                    Layout.fillWidth: true

                    MaterialIcon {
                        text: "book"
                        color: c.m3primary
                        font.pointSize: Appearance.font.size.headlineLarge
                    }

                    StyledText {
                        text: qsTr("Novel")
                        font.pointSize: Appearance.font.size.headlineLarge
                        font.weight: Font.Bold
                        color: c.m3onSurface
                    }
                }

                // Search bar (shown when search icon is tapped)
                StyledRect {
                    id: searchBarContainer
                    visible: searchBar.isSearchActive
                    Layout.fillWidth: true
                    Layout.preferredHeight: 40
                    color: c.m3surfaceContainer
                    radius: Appearance.rounding.full
                    border.width: 1
                    border.color: searchBar.activeFocus ? c.m3primary : Qt.alpha(c.m3outline, 0.2)
                    
                    Behavior on border.color { CAnim {} }

                    RowLayout {
                        anchors { fill: parent; leftMargin: Appearance.padding.md; rightMargin: Appearance.padding.xs }
                        spacing: Appearance.spacing.sm

                        MaterialIcon {
                            text: "search"
                            font.pointSize: 20
                            color: c.m3primary
                            opacity: 0.7
                        }

                        StyledTextField {
                            id: searchBar
                            property bool isSearchActive: false
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignVCenter
                            placeholderText: qsTr("Search novels...")
                            text: ""
                            
                            onTextChanged: if (searchBar.isSearchActive) searchDebounce.restart()
                            
                            Keys.onEscapePressed: {
                                isSearchActive = false
                                text = ""
                                browseView.currentFilter = "hot"
                                Novel.fetchHot()
                            }
                        }

                        IconButton {
                            type: IconButton.Ghost
                            icon: "close"
                            onClicked: {
                                searchBar.isSearchActive = false
                                searchBar.text = ""
                                browseView.currentFilter = "hot"
                                Novel.fetchHot()
                            }
                            Tooltip { target: parent; text: qsTr("Close search") }
                        }
                    }
                }

                Timer {
                    id: searchDebounce
                    interval: 380
                    onTriggered: {
                        var q = searchBar.text.trim()
                        if (q.length > 0) {
                            browseView.currentFilter = "search"
                            Novel.searchNovels(q, "", "All", true)
                        } else {
                            browseView.currentFilter = "hot"
                            Novel.fetchHot()
                        }
                    }
                }

                // ── Provider dropdown button ──────────────────────────────────
                Item {
                    visible: !searchBar.isSearchActive
                    width: 160
                    height: 40

                    Card {
                        anchors.fill: parent
                        variant: Card.Variant.Outlined
                        radius: Appearance.rounding.full
                        
                        RowLayout {
                            anchors.centerIn: parent
                            spacing: Appearance.spacing.sm

                            StyledText {
                                text: {
                                    for (var i = 0; i < Novel.availableProviders.length; i++) {
                                        if (Novel.availableProviders[i].name === Novel.activeProvider)
                                            return Novel.availableProviders[i].label
                                    }
                                    return Novel.activeProvider
                                }
                                font.pointSize: Appearance.font.size.labelLarge
                                color: Novel.isSwitchingProvider ? c.m3onSurfaceVariant : c.m3onSurface
                            }

                            MaterialIcon {
                                visible: !Novel.isSwitchingProvider
                                text: providerMenu.expanded ? "arrow_drop_up" : "arrow_drop_down"
                                font.pointSize: Appearance.font.size.bodyLarge
                                color: c.m3onSurfaceVariant
                            }
                            
                            StyledBusyIndicator {
                                visible: Novel.isSwitchingProvider
                                implicitHeight: 16
                                implicitWidth: 16
                            }
                        }

                        StateLayer {
                            anchors.fill: parent
                            onClicked: {
                                if (!Novel.isSwitchingProvider)
                                    providerMenu.expanded = !providerMenu.expanded
                            }
                        }
                    }

                    Menu {
                        id: providerMenu
                        width: 160
                        x: parent.width - width
                        y: parent.height + Appearance.spacing.sm
                        
                        items: [
                            MenuItem {
                                text: "NovelBin"
                                property string providerName: "novelbin"
                            },
                            MenuItem {
                                text: "FreeWebNovel"
                                property string providerName: "freewebnovel"
                            }
                        ]

                        onItemSelected: item => {
                            Novel.switchProvider(item.providerName, false)
                        }

                        // Set active item based on Novel.activeProvider
                        Component.onCompleted: {
                            for (var i = 0; i < items.length; i++) {
                                if (items[i].providerName === Novel.activeProvider) {
                                    active = items[i];
                                    break;
                                }
                            }
                        }
                    }
                }

                IconButton {
                    id: searchToggle
                    visible: !searchBar.isSearchActive
                    type: IconButton.Tonal
                    icon: "search"
                    onClicked: {
                        searchBar.isSearchActive = true
                        searchBar.forceActiveFocus()
                    }
                }
            }

            Rectangle {
                anchors { bottom: parent.bottom; left: parent.left; right: parent.right }
                height: 1; color: c.m3outlineVariant; opacity: 0.5
            }
        }

        // ── Filter chips (Hot / Latest) ───────────────────────────────────────
        Rectangle {
            Layout.fillWidth: true; height: 56
            color: c.m3surfaceContainerLow; clip: true

            Row {
                anchors.centerIn: parent
                spacing: Appearance.spacing.md

                Chip {
                    text: qsTr("Hot")
                    icon: "local_fire_department"
                    selected: browseView.currentFilter === "hot"
                    onClicked: browseView._switchFilter("hot")
                }
                
                Chip {
                    text: qsTr("Latest")
                    icon: "new_releases"
                    selected: browseView.currentFilter === "latest"
                    onClicked: browseView._switchFilter("latest")
                }
            }

            Rectangle {
                anchors { bottom: parent.bottom; left: parent.left; right: parent.right }
                height: 1; color: c.m3outlineVariant; opacity: 0.3
            }
        }

        // ── Novel grid ────────────────────────────────────────────────────────
        Item {
            Layout.fillWidth: true; Layout.fillHeight: true

            // Loading overlay
            Rectangle {
                anchors.fill: parent; color: c.m3background; z: 10
                visible: Novel.isFetchingNovel && Novel.novelList.length === 0

                ColumnLayout {
                    anchors.centerIn: parent
                    spacing: Appearance.spacing.md

                    StyledBusyIndicator {
                        Layout.alignment: Qt.AlignHCenter
                        running: parent.visible
                    }
                    
                    StyledText {
                        Layout.alignment: Qt.AlignHCenter
                        text: qsTr("Loading titles...")
                        color: c.m3onSurfaceVariant
                        opacity: 0.7
                    }
                }
            }

            // Error overlay
            Rectangle {
                anchors.fill: parent; color: c.m3background; z: 9
                visible: Novel.novelError.length > 0 && !Novel.isFetchingNovel

                ColumnLayout {
                    anchors.centerIn: parent
                    spacing: Appearance.spacing.md
                    
                    MaterialIcon {
                        Layout.alignment: Qt.AlignHCenter
                        text: "error"
                        font.pointSize: 48
                        color: c.m3error
                    }
                    
                    StyledText {
                        Layout.alignment: Qt.AlignHCenter
                        text: Novel.novelError
                        color: c.m3onSurfaceVariant
                        wrapMode: Text.Wrap
                        Layout.preferredWidth: 300
                        horizontalAlignment: Text.AlignHCenter
                    }
                    
                    TextButton {
                        Layout.alignment: Qt.AlignHCenter
                        text: qsTr("Retry")
                        onClicked: {
                            if (browseView.currentFilter === "hot") Novel.fetchHot()
                            else Novel.fetchLatest(true)
                        }
                    }
                }
            }

            GridView {
                id: novelGrid
                anchors.fill: parent; anchors.margins: Appearance.padding.md
                cellWidth: width / 3
                cellHeight: cellWidth * 1.65
                clip: true; boundsBehavior: Flickable.StopAtBounds
                model: Novel.novelList

                ScrollBar.vertical: StyledScrollBar {}

                onContentYChanged: {
                    if (contentY + height > contentHeight - cellHeight * 2)
                        Novel.fetchNextPage()
                }

                delegate: Item {
                    width: novelGrid.cellWidth; height: novelGrid.cellHeight

                    Card {
                        id: nCard
                        anchors { fill: parent; margins: Appearance.spacing.sm }
                        variant: Card.Variant.Filled
                        clip: true

                        ColumnLayout {
                            anchors.fill: parent
                            spacing: 0

                            // Cover image
                            Item {
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                clip: true

                                Image {
                                    id: coverImg
                                    anchors.fill: parent
                                    source: modelData.coverUrl || ""
                                    fillMode: Image.PreserveAspectCrop; asynchronous: true; cache: true
                                    opacity: status === Image.Ready ? 1 : 0
                                    Behavior on opacity { NumberAnimation { duration: 300 } }
                                }

                                Rectangle {
                                    anchors.fill: parent
                                    color: c.m3surfaceContainerHigh
                                    visible: coverImg.status !== Image.Ready
                                    
                                    MaterialIcon {
                                        anchors.centerIn: parent
                                        text: "image"
                                        font.pointSize: 32
                                        color: c.m3outline
                                        opacity: 0.3
                                    }
                                }

                                // Status badge
                                StyledRect {
                                    visible: modelData.status && modelData.status.length > 0
                                    anchors { top: parent.top; left: parent.left; topMargin: 8; leftMargin: 8 }
                                    height: 18
                                    radius: Appearance.rounding.extraSmall
                                    width: statusBadge.implicitWidth + 12
                                    color: modelData.status === "Ongoing"
                                        ? Qt.alpha("#2E7D32", 0.85)
                                        : Qt.alpha("#1565C0", 0.85)

                                    StyledText {
                                        id: statusBadge; anchors.centerIn: parent
                                        text: (modelData.status || "").toUpperCase()
                                        font.pointSize: 8
                                        font.weight: Font.Bold
                                        color: "white"
                                    }
                                }
                            }

                            // Title bar
                            Item {
                                Layout.fillWidth: true
                                Layout.preferredHeight: nTitleCol.implicitHeight + Appearance.padding.md

                                ColumnLayout {
                                    id: nTitleCol
                                    anchors {
                                        left: parent.left; right: parent.right
                                        verticalCenter: parent.verticalCenter
                                        leftMargin: Appearance.padding.sm; rightMargin: Appearance.padding.sm
                                    }
                                    spacing: 2

                                    StyledText {
                                        Layout.fillWidth: true
                                        text: modelData.title || ""
                                        font.weight: Font.Medium
                                        color: c.m3onSurface
                                        wrapMode: Text.Wrap; maximumLineCount: 2; elide: Text.ElideRight
                                    }
                                    
                                    StyledText {
                                        visible: modelData.author && modelData.author.length > 0
                                        Layout.fillWidth: true
                                        text: modelData.author || ""
                                        font.pointSize: Appearance.font.size.labelSmall
                                        color: c.m3onSurfaceVariant; opacity: 0.7
                                        elide: Text.ElideRight
                                    }
                                }
                            }
                        }

                        StateLayer {
                            anchors.fill: parent
                            onClicked: {
                                Novel.fetchNovelDetail(modelData.id)
                                browseView.novelSelected(modelData.id)
                            }
                        }
                    }
                }
            }
        }
    }
}
