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

    readonly property bool _inLibrary:
        Novel.currentNovel ? Novel.isInLibrary(Novel.currentNovel.id) : false

    readonly property var _reversedChapters:
        Novel.currentNovel ? Novel.currentNovel.chapters.slice().reverse() : []

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
                anchors { fill: parent; leftMargin: Appearance.padding.sm; rightMargin: Appearance.padding.md }
                spacing: Appearance.spacing.sm

                IconButton {
                    type: IconButton.Text
                    icon: "arrow_back"
                    onClicked: { Novel.clearDetail(); detailView.backRequested() }
                }

                StyledText {
                    Layout.fillWidth: true
                    text: Novel.currentNovel ? Novel.currentNovel.title : ""
                    font.pointSize: Appearance.font.size.titleMedium
                    font.weight: Font.Bold
                    color: c.m3onSurface; elide: Text.ElideRight
                }

                IconButton {
                    id: favButton
                    visible: Novel.currentNovel !== null
                    type: IconButton.Tonal
                    icon: detailView._inLibrary ? "done" : "add"
                    checked: detailView._inLibrary
                    toggle: true
                    onClicked: {
                        if (detailView._inLibrary) {
                            Novel.removeFromLibrary(Novel.currentNovel.id)
                        } else {
                            Novel.addToLibrary({
                                id:       Novel.currentNovel.id,
                                title:    Novel.currentNovel.title,
                                coverUrl: Novel.currentNovel.coverUrl
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
            Layout.preferredHeight: Novel.currentNovel !== null ? 170 : 0
            clip: true
            Behavior on Layout.preferredHeight { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }

            Image {
                anchors.fill: parent
                source: Novel.currentNovel ? Novel.currentNovel.coverUrl : ""
                fillMode: Image.PreserveAspectCrop
                asynchronous: true; opacity: 0.15
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
                    Layout.preferredWidth: 100; Layout.preferredHeight: 140
                    variant: Card.Variant.Elevated
                    padding: 0
                    clip: true

                    Image {
                        anchors.fill: parent
                        source: Novel.currentNovel ? Novel.currentNovel.coverUrl : ""
                        fillMode: Image.PreserveAspectCrop; asynchronous: true
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: Appearance.spacing.sm

                    StyledRect {
                        visible: Novel.currentNovel && Novel.currentNovel.status.length > 0
                        height: 22; width: statusText.implicitWidth + 16; radius: Appearance.rounding.extraSmall
                        color: c.m3tertiaryContainer

                        StyledText {
                            id: statusText; anchors.centerIn: parent
                            text: Novel.currentNovel ? (Novel.currentNovel.status || "").toUpperCase() : ""
                            font.pointSize: Appearance.font.size.labelSmall
                            font.weight: Font.Bold
                            color: c.m3onTertiaryContainer
                        }
                    }

                    StyledText {
                        Layout.fillWidth: true
                        text: Novel.currentNovel ? Novel.currentNovel.author : ""
                        font.weight: Font.Bold
                        color: c.m3onSurface; elide: Text.ElideRight
                    }

                    StyledText {
                        visible: Novel.currentNovel && Novel.currentNovel.genres.length > 0
                        Layout.fillWidth: true
                        text: Novel.currentNovel ? Novel.currentNovel.genres.join(" · ") : ""
                        font.pointSize: Appearance.font.size.labelLarge
                        color: c.m3primary; opacity: 0.9; elide: Text.ElideRight
                    }

                    StyledText {
                        Layout.fillWidth: true
                        text: Novel.currentNovel ? Novel.currentNovel.description : ""
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
            visible: Novel.currentNovel !== null

            RowLayout {
                anchors { fill: parent; leftMargin: Appearance.padding.lg; rightMargin: Appearance.padding.lg }

                StyledText {
                    text: Novel.currentNovel ? qsTr("%1 chapters").arg(Novel.currentNovel.chapters.length) : ""
                    font.pointSize: Appearance.font.size.labelLarge
                    color: c.m3onSurfaceVariant; opacity: 0.7
                }

                Item { Layout.fillWidth: true }

                // Last-read badge
                StyledRect {
                    readonly property var _entry: Novel.currentNovel ? Novel.getLibraryEntry(Novel.currentNovel.id) : null
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
                                var e = Novel.currentNovel ? Novel.getLibraryEntry(Novel.currentNovel.id) : null
                                return e ? qsTr("Ch. %1").arg(e.lastReadChapterNum) : ""
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

        // ── Chapter list ──────────────────────────────────────────────────────
        Item {
            Layout.fillWidth: true; Layout.fillHeight: true

            // Loading overlay
            Rectangle {
                anchors.fill: parent; color: c.m3background
                visible: Novel.isFetchingDetail; z: 5

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
                model: Novel.currentNovel ? Novel.currentNovel.chapters : []

                ScrollBar.vertical: StyledScrollBar {}

                delegate: Item {
                    width: chapterList.width; height: 64

                    readonly property var _libEntry: Novel.currentNovel ? Novel.getLibraryEntry(Novel.currentNovel.id) : null
                    readonly property bool isLastRead: _libEntry !== null && _libEntry !== undefined && _libEntry.lastReadChapterId === modelData.id

                    Rectangle {
                        anchors.fill: parent
                        color: isLastRead ? Qt.alpha(c.m3primary, 0.08) : "transparent"
                    }

                    StateLayer {
                        anchors.fill: parent
                        onClicked: {
                            Novel.fetchChapter(modelData.id)
                            detailView.chapterSelected(modelData.id)
                            if (Novel.currentNovel && Novel.isInLibrary(Novel.currentNovel.id)) {
                                Novel.updateLastRead(Novel.currentNovel.id, modelData.id, modelData.chapter)
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
                                text: modelData.chapter || "?"
                                font.weight: Font.Bold
                                color: isLastRead ? c.m3onPrimary : c.m3onSurface
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true; spacing: 2

                            StyledText {
                                Layout.fillWidth: true
                                text: modelData.title || qsTr("Chapter %1").arg(modelData.chapter || "")
                                font.weight: Font.Medium
                                color: c.m3onSurface; elide: Text.ElideRight
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
