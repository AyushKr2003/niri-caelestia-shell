import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import qs.config
import qs.services
import "../../../components"
import "../../../components/controls"

Item {
    id: detailView

    readonly property var c: Colours.tPalette
    readonly property string fontDisplay: Config.appearance.font.family.sans
    readonly property string fontBody:    Config.appearance.font.family.sans

    signal backRequested()
    signal chapterSelected(string chapterId)

    function formatChapter(ch) {
        if (!ch) return "?"
        const match = ch.match(/\d+(\.\d+)?/)
        return match ? match[0] : ch
    }

    readonly property bool _inLibrary:
        Manga.currentManga ? Manga.isInLibrary(Manga.currentManga.id) : false

    property bool _sortAscending: false
    property string _chapterFilter: ""

    function reset() {
        console.log("[MangaDetailView] Resetting filters")
        _chapterFilter = ""
        _sortAscending = false
    }

    readonly property var _processedChapters: {
        if (!Manga.currentManga) return []
        let chapters = Manga.currentManga.chapters.slice()
        
        // Filter
        if (detailView._chapterFilter.trim() !== "") {
            const f = detailView._chapterFilter.trim().toLowerCase()
            chapters = chapters.filter(ch => {
                const num = detailView.formatChapter(ch.chapter).toLowerCase()
                const title = (ch.title || "").toLowerCase()
                return num.includes(f) || title.includes(f)
            })
        }

        // Sort
        chapters.sort((a, b) => {
            const numA = parseFloat(detailView.formatChapter(a.chapter)) || 0
            const numB = parseFloat(detailView.formatChapter(b.chapter)) || 0
            return detailView._sortAscending ? numA - numB : numB - numA
        })

        return chapters
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        // ── Header ────────────────────────────────────────────────────────────
        Rectangle {
            Layout.fillWidth: true
            height: 64
            color: c.m3surfaceContainerLow
            z: 2

            RowLayout {
                anchors { fill: parent; leftMargin: Appearance.padding.lg; rightMargin: Appearance.padding.lg }
                spacing: Appearance.spacing.sm

                IconButton {
                    type: IconButton.Text
                    icon: "arrow_back"
                    onClicked: { Manga.clearChapterList(); detailView.backRequested() }
                }

                StyledText {
                    Layout.fillWidth: true
                    text: Manga.currentManga ? Manga.currentManga.title : ""
                    font.pointSize: Appearance.font.size.titleMedium
                    font.weight: Font.Bold
                    color: c.m3onSurface; elide: Text.ElideRight
                }

                IconButton {
                    id: favButton
                    visible: Manga.currentManga !== null
                    type: IconButton.Tonal
                    icon: detailView._inLibrary ? "done" : "add"
                    checked: detailView._inLibrary
                    toggle: true
                    onClicked: {
                        if (detailView._inLibrary) {
                            Manga.removeFromLibrary(Manga.currentManga.id)
                        } else {
                            Manga.addToLibrary({
                                id:       Manga.currentManga.id,
                                title:    Manga.currentManga.title,
                                coverUrl: Manga.currentManga.coverUrl
                            })
                        }
                    }
                    Tooltip {
                        target: favButton
                        text: detailView._inLibrary ? qsTr("Remove from library") : qsTr("Add to library")
                    }
                }
            }

            Rectangle {
                anchors { bottom: parent.bottom; left: parent.left; right: parent.right }
                height: 1; color: c.m3outlineVariant; opacity: 0.5
            }
        }

        // ── Hero banner ───────────────────────────────────────────────────────
        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: Manga.currentManga !== null ? 160 : 0
            clip: true
            Behavior on Layout.preferredHeight { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }

            Image {
                anchors.fill: parent
                source: Manga.currentManga ? Manga.currentManga.coverUrl : ""
                fillMode: Image.PreserveAspectCrop
                asynchronous: true; opacity: 0.2
            }
            
            Rectangle {
                anchors.fill: parent
                gradient: Gradient {
                    GradientStop { position: 0.0; color: Qt.alpha(c.m3surfaceContainerLow, 0.8) }
                    GradientStop { position: 1.0; color: c.m3background }
                }
            }

            RowLayout {
                anchors { fill: parent; margins: Appearance.padding.lg }
                spacing: Appearance.spacing.lg

                Card {
                    Layout.preferredWidth: 90; Layout.preferredHeight: 130
                    variant: Card.Variant.Elevated
                    padding: 0
                    clip: true

                    Image {
                        anchors.fill: parent
                        source: Manga.currentManga ? Manga.currentManga.coverUrl : ""
                        fillMode: Image.PreserveAspectCrop; asynchronous: true
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: Appearance.spacing.sm

                    StyledRect {
                        visible: Manga.currentManga && Manga.currentManga.status.length > 0
                        height: 22; width: statusText.implicitWidth + 16; radius: Appearance.rounding.extraSmall
                        color: c.m3tertiaryContainer

                        StyledText {
                            id: statusText; anchors.centerIn: parent
                            text: Manga.currentManga ? (Manga.currentManga.status || "").toUpperCase() : ""
                            font.pointSize: Appearance.font.size.labelSmall
                            font.weight: Font.Bold
                            color: c.m3onTertiaryContainer
                        }
                    }

                    StyledText {
                        Layout.fillWidth: true
                        text: Manga.currentManga ? (Manga.currentManga.authors || []).join(", ") : ""
                        font.weight: Font.Bold
                        color: c.m3onSurface; elide: Text.ElideRight
                    }

                    StyledText {
                        Layout.fillWidth: true
                        text: Manga.currentManga ? Manga.currentManga.description : ""
                        font.pointSize: Appearance.font.size.bodySmall
                        color: c.m3onSurfaceVariant
                        wrapMode: Text.Wrap; maximumLineCount: 3
                        elide: Text.ElideRight; opacity: 0.8; lineHeight: 1.3
                    }
                }
            }

            Rectangle {
                anchors { bottom: parent.bottom; left: parent.left; right: parent.right }
                height: 1; color: c.m3outlineVariant; opacity: 0.3
            }
        }

        // ── Chapter count + last-read strip ───────────────────────────────────
        Rectangle {
            Layout.fillWidth: true; height: 40
            color: c.m3surfaceContainerLow
            visible: Manga.currentManga !== null

            RowLayout {
                anchors { fill: parent; leftMargin: Appearance.padding.lg; rightMargin: Appearance.padding.lg }

                StyledText {
                    text: Manga.currentManga ? qsTr("%1 chapters").arg(Manga.currentManga.chapters.length) : ""
                    font.pointSize: Appearance.font.size.labelLarge
                    color: c.m3onSurfaceVariant; opacity: 0.7
                }

                Item { Layout.fillWidth: true }

                // Last-read badge
                StyledRect {
                    readonly property var _entry: Manga.currentManga ? Manga.getLibraryEntry(Manga.currentManga.id) : null
                    visible: _entry !== null && _entry !== undefined && _entry.lastReadChapterNum !== ""
                    height: 24; width: lastReadText.implicitWidth + 20; radius: Appearance.rounding.full
                    color: c.m3primaryContainer

                    RowLayout {
                        anchors.centerIn: parent
                        spacing: 4
                        MaterialIcon { text: "history"; font.pointSize: 14; color: c.m3onPrimaryContainer }
                        StyledText {
                            id: lastReadText
                            text: {
                                var e = Manga.currentManga ? Manga.getLibraryEntry(Manga.currentManga.id) : null
                                return e ? qsTr("Ch. %1").arg(detailView.formatChapter(e.lastReadChapterNum)) : ""
                            }
                            font.pointSize: Appearance.font.size.labelSmall
                            font.weight: Font.Bold
                            color: c.m3onPrimaryContainer
                        }
                    }
                }
            }

            Rectangle {
                anchors { bottom: parent.bottom; left: parent.left; right: parent.right }
                height: 1; color: c.m3outlineVariant; opacity: 0.3
            }
        }

        // ── Search & Sort bar ────────────────────────────────────────────────
        Rectangle {
            Layout.fillWidth: true; height: 64
            color: c.m3surfaceContainerLow
            visible: Manga.currentManga !== null

            RowLayout {
                anchors {
                    fill: parent
                    leftMargin: Appearance.padding.lg
                    rightMargin: Appearance.padding.lg
                    topMargin: Appearance.padding.md
                    bottomMargin: Appearance.padding.md
                }
                spacing: Appearance.spacing.md

                StyledRect {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    color: c.m3surfaceContainer
                    radius: Appearance.rounding.full
                    border.width: 1
                    border.color: chapterSearch.activeFocus ? c.m3primary : Qt.alpha(c.m3outline, 0.2)
                    
                    Behavior on border.color { CAnim {} }

                    RowLayout {
                        anchors { fill: parent; leftMargin: Appearance.padding.md; rightMargin: Appearance.padding.sm }
                        spacing: Appearance.spacing.sm

                        MaterialIcon {
                            text: "search"
                            font.pointSize: 20
                            color: c.m3primary
                            opacity: 0.7
                        }

                        StyledTextField {
                            id: chapterSearch
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignVCenter
                            placeholderText: qsTr("Filter chapters...")
                            text: detailView._chapterFilter
                            onTextChanged: detailView._chapterFilter = text
                        }

                        IconButton {
                            visible: detailView._chapterFilter !== ""
                            type: IconButton.Text
                            icon: "close"
                            font.pointSize: 18
                            padding: Appearance.padding.xs
                            onClicked: {
                                detailView._chapterFilter = ""
                                chapterSearch.text = ""
                            }
                            Tooltip { target: parent; text: qsTr("Clear filter") }
                        }
                    }
                }

                IconButton {
                    type: IconButton.Tonal
                    icon: detailView._sortAscending ? "arrow_upward" : "arrow_downward"
                    onClicked: detailView._sortAscending = !detailView._sortAscending
                    Tooltip {
                        target: parent
                        text: detailView._sortAscending ? qsTr("Sort: Ascending") : qsTr("Sort: Descending")
                    }
                }
            }

            Rectangle {
                anchors { bottom: parent.bottom; left: parent.left; right: parent.right }
                height: 1; color: c.m3outlineVariant; opacity: 0.3
            }
        }

        // ── Chapter list ──────────────────────────────────────────────────────
        Item {
            Layout.fillWidth: true; Layout.fillHeight: true

            // Loading overlay
            Rectangle {
                anchors.fill: parent; color: c.m3background
                visible: Manga.isFetchingDetail; z: 5

                ColumnLayout {
                    anchors.centerIn: parent; spacing: Appearance.spacing.md

                    StyledBusyIndicator { Layout.alignment: Qt.AlignHCenter; running: parent.visible }
                    StyledText {
                        Layout.alignment: Qt.AlignHCenter
                        text: qsTr("Fetching chapters...")
                        color: c.m3onSurfaceVariant; opacity: 0.7
                    }
                }
            }

            ListView {
                id: chapterList
                anchors.fill: parent; clip: true
                boundsBehavior: Flickable.StopAtBounds
                model: detailView._processedChapters

                ScrollBar.vertical: StyledScrollBar {}

                delegate: Item {
                    width: chapterList.width; height: 64

                    readonly property var _libEntry: Manga.currentManga ? Manga.getLibraryEntry(Manga.currentManga.id) : null
                    readonly property bool isLastRead: _libEntry !== null && _libEntry !== undefined && _libEntry.lastReadChapterId === modelData.id

                    Rectangle {
                        anchors.fill: parent
                        color: isLastRead ? Qt.alpha(c.m3primary, 0.08) : "transparent"
                    }

                    StateLayer {
                        anchors.fill: parent
                        onClicked: {
                            Manga.fetchChapterPages(modelData.id)
                            detailView.chapterSelected(modelData.id)
                            if (Manga.currentManga && Manga.isInLibrary(Manga.currentManga.id)) {
                                Manga.updateLastRead(Manga.currentManga.id, modelData.id, modelData.chapter)
                            }
                        }
                    }

                    RowLayout {
                        anchors { fill: parent; leftMargin: Appearance.padding.lg; rightMargin: Appearance.padding.lg }
                        spacing: Appearance.spacing.md

                        StyledRect {
                            Layout.preferredWidth: 48; Layout.preferredHeight: 32; radius: Appearance.rounding.small
                            color: isLastRead ? c.m3primary : c.m3surfaceContainerHigh

                            StyledText {
                                anchors.centerIn: parent
                                text: detailView.formatChapter(modelData.chapter)
                                font.weight: Font.Bold
                                color: isLastRead ? c.m3onPrimary : c.m3onSurface
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true; spacing: 2

                            StyledText {
                                Layout.fillWidth: true
                                text: modelData.title || qsTr("Chapter %1").arg(detailView.formatChapter(modelData.chapter))
                                font.weight: Font.Medium
                                color: c.m3onSurface; elide: Text.ElideRight
                            }
                            StyledText {
                                text: modelData.publishAt ? Qt.formatDate(new Date(modelData.publishAt), "MMM d, yyyy") : ""
                                font.pointSize: Appearance.font.size.labelSmall
                                color: c.m3onSurfaceVariant; opacity: 0.6
                            }
                        }

                        MaterialIcon {
                            text: "chevron_right"; color: c.m3outline
                        }
                    }

                    Rectangle {
                        anchors { bottom: parent.bottom; left: parent.left; right: parent.right; leftMargin: 72 }
                        height: 1; color: c.m3outlineVariant; opacity: 0.2
                    }
                }
            }
        }
    }
}
