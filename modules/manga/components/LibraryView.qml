import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import qs.config
import qs.services
import "../../../components"
import "../../../components/controls"

Item {
    id: libraryView

    readonly property var c: Colours.tPalette
    readonly property string fontDisplay: Config.appearance.font.family.sans
    readonly property string fontBody:    Config.appearance.font.family.sans

    // Emitted when the user taps an entry — parent handles navigation
    signal mangaSelected(string mangaId)

    // ── Background ────────────────────────────────────────────────────────────
    Rectangle { anchors.fill: parent; color: c.m3background }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        // ── Empty state ───────────────────────────────────────────────────────
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: Manga.libraryList.length === 0 && Manga.libraryLoaded

            ColumnLayout {
                anchors.centerIn: parent
                spacing: Appearance.spacing.md

                MaterialIcon {
                    Layout.alignment: Qt.AlignHCenter
                    text: "library_books"
                    font.pointSize: 64
                    color: c.m3outline
                    opacity: 0.3
                }

                StyledText {
                    Layout.alignment: Qt.AlignHCenter
                    text: qsTr("Your library is empty")
                    font.pointSize: Appearance.font.size.titleMedium
                    font.weight: Font.Bold
                    color: c.m3onSurface
                    opacity: 0.5
                }

                StyledText {
                    Layout.alignment: Qt.AlignHCenter
                    text: qsTr("Open any manga and tap + to add it here")
                    font.pointSize: Appearance.font.size.bodySmall
                    color: c.m3onSurfaceVariant
                    opacity: 0.4
                }
            }
        }

        // ── Loading ──────────────────────────────────────────────────────────
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: !Manga.libraryLoaded

            StyledBusyIndicator {
                anchors.centerIn: parent
                running: parent.visible
            }
        }

        GridView {
            id: libGrid
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: Manga.libraryList.length > 0
            anchors.margins: Appearance.padding.md
            cellWidth: width / 3
            cellHeight: cellWidth * 1.7
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            model: Manga.libraryList

            ScrollBar.vertical: StyledScrollBar {}

            delegate: Item {
                width: libGrid.cellWidth
                height: libGrid.cellHeight

                Card {
                    id: libCard
                    anchors { fill: parent; margins: Appearance.spacing.sm }
                    variant: Card.Variant.Filled
                    clip: true

                    ColumnLayout {
                        anchors.fill: parent
                        spacing: 0

                        Item {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            clip: true

                            Image {
                                id: libCover
                                anchors.fill: parent
                                source: modelData.coverUrl || ""
                                fillMode: Image.PreserveAspectCrop
                                asynchronous: true
                                cache: true
                                opacity: status === Image.Ready ? 1 : 0
                                Behavior on opacity { NumberAnimation { duration: 300 } }
                            }

                            Rectangle {
                                anchors.fill: parent
                                color: c.m3surfaceContainerHigh
                                visible: libCover.status !== Image.Ready

                                MaterialIcon {
                                    anchors.centerIn: parent
                                    text: "image"
                                    font.pointSize: 32
                                    color: c.m3outline
                                    opacity: 0.3
                                }
                            }
                        }

                        StyledRect {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 32
                            color: c.m3surfaceContainerHigh

                            RowLayout {
                                anchors { fill: parent; leftMargin: Appearance.padding.sm; rightMargin: Appearance.padding.sm }
                                spacing: 4

                                MaterialIcon {
                                    text: modelData.lastReadChapterNum ? "play_arrow" : "pause"
                                    font.pointSize: 14
                                    color: modelData.lastReadChapterNum ? c.m3primary : c.m3outline
                                }

                                StyledText {
                                    Layout.fillWidth: true
                                    text: modelData.lastReadChapterNum ? qsTr("Ch. %1").arg(modelData.lastReadChapterNum) : qsTr("Not started")
                                    font.pointSize: Appearance.font.size.labelSmall
                                    font.weight: Font.Bold
                                    color: modelData.lastReadChapterNum ? c.m3onSurface : c.m3onSurfaceVariant
                                    elide: Text.ElideRight
                                }
                            }
                        }

                        Item {
                            Layout.fillWidth: true
                            Layout.preferredHeight: libTitleText.implicitHeight + Appearance.padding.md

                            StyledText {
                                id: libTitleText
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
                            libraryView.mangaSelected(modelData.id)
                        }
                    }
                }
            }
        }
    }
}
