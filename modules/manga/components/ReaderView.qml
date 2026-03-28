import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import qs.services
import qs.config
import "../../../components"
import "../../../components/controls"

Item {
    id: readerView

    // ── Exposed API ──────────────────────────────────────────────────────────
    readonly property var c: Colours.tPalette
    readonly property string fontDisplay: Config.appearance.font.family.sans
    readonly property string fontBody:    Config.appearance.font.family.sans

    // Emitted when the user navigates back
    signal backRequested()

    // ── Internal state ───────────────────────────────────────────────────────
    property bool headerVisible: true

    // Called by the parent to reset state when re-entering this view
    function reset() {
        headerVisible = true
    }

    // ── Ink-black background ─────────────────────────────────────────────────
    Rectangle { anchors.fill: parent; color: "black" }

    // ── Reader header ────────────────────────────────────────────────────────
    Rectangle {
        id: readerHeader
        anchors { top: parent.top; left: parent.left; right: parent.right }
        height: 64
        color: Qt.alpha(c.m3surfaceContainerLowest, 0.9)
        z: 10
        opacity: readerView.headerVisible ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }

        RowLayout {
            anchors { fill: parent; leftMargin: Appearance.padding.sm; rightMargin: Appearance.padding.md }
            spacing: Appearance.spacing.sm

            IconButton {
                type: IconButton.Text
                icon: "arrow_back"
                onClicked: {
                    Manga.clearChapterPages()
                    readerView.backRequested()
                }
            }

            StyledText {
                Layout.fillWidth: true
                text: Manga.currentManga ? Manga.currentManga.title : ""
                font.pointSize: Appearance.font.size.bodyLarge
                font.weight: Font.Bold
                color: c.m3onSurface
                elide: Text.ElideRight
            }

            // Page counter badge
            StyledRect {
                visible: Manga.chapterPages.length > 0
                height: 28
                width: pageCountText.implicitWidth + 24
                radius: Appearance.rounding.full
                color: c.m3surfaceContainerHigh

                StyledText {
                    id: pageCountText
                    anchors.centerIn: parent
                    text: qsTr("%1 / %2").arg(pageListView.currentIndex + 1).arg(Manga.chapterPages.length)
                    font.pointSize: Appearance.font.size.labelLarge
                    font.weight: Font.Bold
                    color: c.m3onSurfaceVariant
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

    // ── Fetching pages overlay ───────────────────────────────────────────────
    Rectangle {
        anchors.fill: parent
        color: "black"
        visible: Manga.isFetchingPages
        z: 8

        ColumnLayout {
            anchors.centerIn: parent
            spacing: Appearance.spacing.md

            StyledBusyIndicator {
                Layout.alignment: Qt.AlignHCenter
                running: parent.visible
            }
            
            StyledText {
                Layout.alignment: Qt.AlignHCenter
                text: qsTr("Loading pages...")
                color: "white"
                opacity: 0.7
            }
        }
    }

    // ── Pages error overlay ──────────────────────────────────────────────────
    Rectangle {
        anchors.fill: parent
        color: "black"
        visible: Manga.pagesError.length > 0 && !Manga.isFetchingPages
        z: 7

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
                text: Manga.pagesError
                color: "white"
                wrapMode: Text.Wrap
                Layout.preferredWidth: 300
                horizontalAlignment: Text.AlignHCenter
            }
            
            TextButton {
                Layout.alignment: Qt.AlignHCenter
                text: qsTr("Retry")
                onClicked: Manga.refreshChapterPages()
            }
        }
    }

    // ── Page list ────────────────────────────────────────────────────────────
    ListView {
        id: pageListView
        anchors {
            fill: parent
            topMargin: readerView.headerVisible ? readerHeader.height : 0
        }
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        model: Manga.chapterPages
        spacing: Appearance.spacing.xs
        Behavior on anchors.topMargin { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }

        // Tap anywhere to toggle header
        MouseArea {
            anchors.fill: parent
            propagateComposedEvents: true
            onClicked: {
                readerView.headerVisible = !readerView.headerVisible
                mouse.accepted = false
            }
        }

        delegate: Item {
            width: pageListView.width
            height: pageImg.implicitHeight > 0
                ? pageImg.implicitHeight * (pageListView.width / pageImg.implicitWidth)
                : pageListView.width * 1.4

            Image {
                id: pageImg
                anchors.fill: parent
                source: modelData.url || ""
                fillMode: Image.PreserveAspectFit
                asynchronous: true
                cache: true
                opacity: status === Image.Ready ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: 350 } }
            }

            Rectangle {
                anchors.fill: parent
                color: "#111"
                visible: pageImg.status !== Image.Ready

                ColumnLayout {
                    anchors.centerIn: parent
                    spacing: Appearance.spacing.sm

                    StyledBusyIndicator {
                        Layout.alignment: Qt.AlignHCenter
                        running: parent.visible
                        implicitHeight: 24
                        implicitWidth: 24
                    }
                    
                    StyledText {
                        Layout.alignment: Qt.AlignHCenter
                        text: qsTr("Page %1").arg(modelData.index + 1)
                        color: "white"
                        font.pointSize: Appearance.font.size.labelSmall
                        opacity: 0.5
                    }
                }
            }
        }

        ScrollBar.vertical: StyledScrollBar {}
    }

    // ── Reading progress bar (bottom) ─────────────────────────────────────────
    Rectangle {
        anchors { bottom: parent.bottom; left: parent.left; right: parent.right }
        height: 4
        z: 9
        visible: Manga.chapterPages.length > 0
        color: Qt.alpha("white", 0.1)

        Rectangle {
            width: Manga.chapterPages.length > 0
                ? parent.width * ((pageListView.currentIndex + 1) / Manga.chapterPages.length)
                : 0
            height: parent.height
            color: c.m3primary
            Behavior on width { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
        }
    }
}
