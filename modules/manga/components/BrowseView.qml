import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import qs.config
import qs.services
import "../../../components"
import "../../../components/controls"

Item {
    id: browseView

    // ── Exposed API ──────────────────────────────────────────────────────────
    readonly property var c: Colours.tPalette
    readonly property string fontDisplay: Config.appearance.font.family.sans
    readonly property string fontBody: Config.appearance.font.family.sans

    // Emitted when the user taps a manga card
    signal mangaSelected(string mangaId)

    function reset() {
        console.log("[MangaBrowseView] Resetting search and filters")
        searchBar.text = ""
        searchBar.visible = false
        currentTagId = ""
        Manga.clearMangaList()
        Manga.fetchByOrigin("", true)
    }

    property string currentTagId: ""

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        // ── Header ──────────────────────────────────────────────────────────
        Rectangle {
            Layout.fillWidth: true
            height: 64
            color: c.m3surfaceContainerLow
            z: 2

            RowLayout {
                anchors { fill: parent; leftMargin: Appearance.padding.lg; rightMargin: Appearance.padding.lg }
                spacing: Appearance.spacing.md

                // Wordmark
                RowLayout {
                    spacing: Appearance.spacing.md
                    visible: !searchBar.visible
                    Layout.fillWidth: true

                    MaterialIcon {
                        text: "auto_stories"
                        color: c.m3primary
                        font.pointSize: Appearance.font.size.headlineLarge
                    }

                    StyledText {
                        text: qsTr("Manga")
                        font.pointSize: Appearance.font.size.headlineLarge
                        font.weight: Font.Bold
                        color: c.m3onSurface
                    }
                }

                // Search bar
                StyledInputField {
                    id: searchBar
                    Layout.fillWidth: true
                    visible: false
                    text: ""
                    horizontalAlignment: TextInput.AlignLeft
                    
                    onTextEdited: searchDebounce.restart()
                    
                    Keys.onEscapePressed: {
                        visible = false
                        text = ""
                        Manga.fetchByOrigin(browseView.currentTagId, true)
                    }
                }

                Timer {
                    id: searchDebounce
                    interval: 350
                    onTriggered: {
                        if (searchBar.text.trim().length > 0)
                            Manga.searchManga(searchBar.text.trim(), true)
                        else
                            Manga.fetchByOrigin(browseView.currentTagId, true)
                    }
                }

                IconButton {
                    id: searchToggle
                    type: IconButton.Tonal
                    icon: searchBar.visible ? "close" : "search"
                    onClicked: {
                        searchBar.visible = !searchBar.visible
                        if (searchBar.visible) {
                            searchBar.forceActiveFocus()
                        } else {
                            searchBar.text = ""
                            Manga.fetchByOrigin(browseView.currentTagId, true)
                        }
                    }
                }
            }

            Rectangle {
                anchors { bottom: parent.bottom; left: parent.left; right: parent.right }
                height: 1
                color: c.m3outlineVariant
                opacity: 0.5
            }
        }

        // ── Tag filter chips ─────────────────────────────────────────────────
        Rectangle {
            Layout.fillWidth: true
            height: 56
            color: c.m3surfaceContainerLow
            clip: true

            RowLayout {
                anchors { fill: parent; leftMargin: Appearance.padding.lg; rightMargin: Appearance.padding.lg }
                spacing: Appearance.spacing.sm

                Repeater {
                    model: [
                        { label: qsTr("Hot"),     tagId: "",       icon: "local_fire_department" },
                        { label: qsTr("Latest"),  tagId: "latest", icon: "new_releases" },
                        { label: qsTr("Manga"),   tagId: "ja",     icon: "menu_book" },
                        { label: qsTr("Manhwa"),  tagId: "ko",     icon: "auto_stories" },
                        { label: qsTr("Manhua"),  tagId: "zh",     icon: "import_contacts" }
                    ]

                    delegate: Chip {
                        text: modelData.label
                        icon: modelData.icon
                        selected: browseView.currentTagId === modelData.tagId
                        Layout.alignment: Qt.AlignVCenter
                        
                        onClicked: {
                            browseView.currentTagId = modelData.tagId
                            searchBar.text = ""
                            searchBar.visible = false
                            Manga.fetchByOrigin(modelData.tagId, true)
                        }
                    }
                }
            }

            Rectangle {
                anchors { bottom: parent.bottom; left: parent.left; right: parent.right }
                height: 1
                color: c.m3outlineVariant
                opacity: 0.3
            }
        }

        // ── Main content area ────────────────────────────────────────────────
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            // Loading state
            Rectangle {
                anchors.fill: parent
                color: c.m3background
                visible: Manga.isFetchingManga && Manga.mangaList.length === 0
                z: 10

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

            // Error state
            Rectangle {
                anchors.fill: parent
                color: c.m3background
                visible: Manga.mangaError.length > 0 && !Manga.isFetchingManga
                z: 9

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
                        text: Manga.mangaError
                        color: c.m3onSurfaceVariant
                        wrapMode: Text.Wrap
                        Layout.preferredWidth: 300
                        horizontalAlignment: Text.AlignHCenter
                    }
                    
                    TextButton {
                        Layout.alignment: Qt.AlignHCenter
                        text: qsTr("Retry")
                        onClicked: Manga.fetchByOrigin(browseView.currentTagId, true)
                    }
                }
            }

            // ── Manga grid ───────────────────────────────────────────────────
            GridView {
                id: mangaGrid
                anchors.fill: parent
                anchors.margins: Appearance.padding.md
                cellWidth: width / 3
                cellHeight: cellWidth * 1.6
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                model: Manga.mangaList

                ScrollBar.vertical: StyledScrollBar {}

                onContentYChanged: {
                    if (contentY + height > contentHeight - cellHeight * 2)
                        Manga.fetchNextMangaPage()
                }

                delegate: Item {
                    width: mangaGrid.cellWidth
                    height: mangaGrid.cellHeight

                    Card {
                        id: card
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
                                    source: modelData.thumbUrl || ""
                                    fillMode: Image.PreserveAspectCrop
                                    asynchronous: true
                                    cache: true
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

                                // Type badge
                                StyledRect {
                                    visible: modelData.type && modelData.type.length > 0
                                    anchors { top: parent.top; right: parent.right; topMargin: 8; rightMargin: 8 }
                                    height: 20
                                    radius: Appearance.rounding.extraSmall
                                    width: typeText.implicitWidth + 12
                                    color: Qt.alpha(c.m3surfaceContainerLowest, 0.8)

                                    StyledText {
                                        id: typeText
                                        anchors.centerIn: parent
                                        text: (modelData.type || "").toUpperCase()
                                        font.pointSize: Appearance.font.size.labelSmall
                                        font.weight: Font.Bold
                                        color: c.m3primary
                                    }
                                }
                            }

                            // Title bar
                            Item {
                                Layout.fillWidth: true
                                Layout.preferredHeight: titleText.implicitHeight + Appearance.padding.md

                                StyledText {
                                    id: titleText
                                    anchors {
                                        left: parent.left; right: parent.right
                                        verticalCenter: parent.verticalCenter
                                        leftMargin: Appearance.padding.sm; rightMargin: Appearance.padding.sm
                                    }
                                    text: modelData.title || ""
                                    font.weight: Font.Medium
                                    color: c.m3onSurface
                                    wrapMode: Text.Wrap
                                    maximumLineCount: 2
                                    elide: Text.ElideRight
                                }
                            }
                        }

                        StateLayer {
                            anchors.fill: parent
                            onClicked: {
                                Manga.fetchMangaDetail(modelData.id)
                                browseView.mangaSelected(modelData.id)
                            }
                        }
                    }
                }
            }
        }
    }
}
