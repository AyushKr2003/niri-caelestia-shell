import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import qs.services
import qs.config
import "../../../components"
import "../../../components/controls"

Item {
    id: readerView

    readonly property var c: Colours.tPalette
    readonly property string fontDisplay: Config.appearance.font.family.sans
    readonly property string fontBody:    Config.appearance.font.family.sans

    signal backRequested()

    property real fontSize:      Appearance.font.size.bodyMedium + 4
    property real lineHeight:    1.6
    property bool headerVisible: true

    function reset() {
        headerVisible = true
        textScroll.contentY = 0
    }

    readonly property bool _hasPrev: Novel.currentChapter !== null && Novel.currentChapter.prevId !== ""
    readonly property bool _hasNext: Novel.currentChapter !== null && Novel.currentChapter.nextId !== ""

    Rectangle { anchors.fill: parent; color: Colours.palette.m3surface }

    // ── Header ────────────────────────────────────────────────────────────
    Rectangle {
        id: readerHeader
        anchors { top: parent.top; left: parent.left; right: parent.right }
        height: 64
        color: Qt.alpha(c.m3surfaceContainerLowest, 0.95)
        z: 10
        opacity: readerView.headerVisible ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }

        RowLayout {
            anchors { fill: parent; leftMargin: Appearance.padding.sm; rightMargin: Appearance.padding.md }
            spacing: Appearance.spacing.sm

            IconButton {
                type: IconButton.Text
                icon: "arrow_back"
                onClicked: { Novel.clearChapter(); readerView.backRequested() }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0
                StyledText {
                    Layout.fillWidth: true
                    text: Novel.currentNovel ? Novel.currentNovel.title : ""
                    font.pointSize: Appearance.font.size.labelSmall
                    color: c.m3onSurfaceVariant; opacity: 0.7
                    elide: Text.ElideRight
                }
                StyledText {
                    Layout.fillWidth: true
                    text: Novel.currentChapter ? Novel.currentChapter.title : ""
                    font.pointSize: Appearance.font.size.bodyLarge
                    font.weight: Font.Bold
                    color: c.m3onSurface
                    elide: Text.ElideRight
                }
            }

            RowLayout {
                spacing: Appearance.spacing.xs
                
                IconButton {
                    type: IconButton.Tonal
                    icon: "text_decrease"
                    onClicked: readerView.fontSize = Math.max(12, readerView.fontSize - 1)
                }
                
                IconButton {
                    type: IconButton.Tonal
                    icon: "text_increase"
                    onClicked: readerView.fontSize = Math.min(32, readerView.fontSize + 1)
                }
            }

            StyledRect {
                visible: Novel.currentChapter !== null && Novel.currentChapter.wordCount > 0
                height: 28
                width: wcTxt.implicitWidth + 24
                radius: Appearance.rounding.full
                color: c.m3surfaceContainerHigh

                StyledText {
                    id: wcTxt; anchors.centerIn: parent
                    text: Novel.currentChapter !== null ? qsTr("%1k words").arg((Math.round(Novel.currentChapter.wordCount / 100) / 10)) : ""
                    font.pointSize: Appearance.font.size.labelSmall
                    font.weight: Font.Bold
                    color: c.m3onSurfaceVariant
                }
            }
        }

        Rectangle {
            anchors { bottom: parent.bottom; left: parent.left; right: parent.right }
            height: 1; color: c.m3outlineVariant; opacity: 0.3
        }
    }

    // ── Progress bar (fixed below header) ──────────────────────────────────
    Rectangle {
        anchors { top: readerHeader.bottom; left: parent.left; right: parent.right }
        height: 2; z: 9
        color: Qt.alpha(c.m3primary, 0.1)
        
        Rectangle {
            width: textScroll.contentHeight > textScroll.height
                ? parent.width * Math.min(1, (textScroll.contentY + textScroll.height) / textScroll.contentHeight)
                : parent.width
            height: parent.height; color: c.m3primary
            Behavior on width { NumberAnimation { duration: 120 } }
        }
    }

    // ── Loading overlay ──────────────────────────────────────────────────
    Rectangle {
        anchors.fill: parent; color: c.m3surface; visible: Novel.isFetchingChapter; z: 8
        ColumnLayout {
            anchors.centerIn: parent; spacing: Appearance.spacing.md
            
            StyledBusyIndicator { Layout.alignment: Qt.AlignHCenter; running: parent.visible }
            StyledText {
                Layout.alignment: Qt.AlignHCenter
                text: qsTr("Loading chapter...")
                color: c.m3onSurfaceVariant; opacity: 0.7
            }
        }
    }

    // ── Error overlay ────────────────────────────────────────────────────
    Rectangle {
        anchors.fill: parent; color: c.m3surface; z: 7
        visible: Novel.chapterError.length > 0 && !Novel.isFetchingChapter
        
        ColumnLayout {
            anchors.centerIn: parent; spacing: Appearance.spacing.md
            
            MaterialIcon {
                Layout.alignment: Qt.AlignHCenter
                text: "error"
                font.pointSize: 48
                color: c.m3error
            }
            
            StyledText {
                Layout.alignment: Qt.AlignHCenter
                text: Novel.chapterError
                color: c.m3onSurfaceVariant
                wrapMode: Text.Wrap; Layout.preferredWidth: 300; horizontalAlignment: Text.AlignHCenter
            }
            
            TextButton {
                Layout.alignment: Qt.AlignHCenter
                text: qsTr("Retry")
                onClicked: Novel.fetchChapter(Novel.currentChapterId)
            }
        }
    }

    Flickable {
        id: textScroll
        anchors {
            fill: parent
            topMargin: readerView.headerVisible ? readerHeader.height : 2
            bottomMargin: 64
        }
        contentWidth: width
        contentHeight: textColumn.implicitHeight + 100
        clip: true; boundsBehavior: Flickable.StopAtBounds
        Behavior on anchors.topMargin { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }

        MouseArea {
            anchors.fill: parent; propagateComposedEvents: true
            onClicked: { readerView.headerVisible = !readerView.headerVisible; mouse.accepted = false }
        }

        Column {
            id: textColumn
            width: Math.min(parent.width - Appearance.padding.lg * 2, 800)
            anchors.horizontalCenter: parent.horizontalCenter
            topPadding: 48; bottomPadding: 64; spacing: 0

            StyledText {
                width: parent.width
                text: Novel.currentChapter ? Novel.currentChapter.title : ""
                font.pointSize: readerView.fontSize + 8
                font.weight: Font.Bold
                color: c.m3onSurface
                wrapMode: Text.Wrap; lineHeight: 1.2; bottomPadding: 24
            }

            // Divider
            Rectangle {
                width: 80; height: 4; radius: 2
                color: c.m3primary; opacity: 0.3
                visible: Novel.currentChapter !== null
            }

            Item { width: 1; height: 32 }

            Repeater {
                model: Novel.currentChapter ? Novel.currentChapter.paragraphs : []
                StyledText {
                    width: textColumn.width
                    text: modelData
                    font.pointSize: readerView.fontSize
                    color: c.m3onSurface
                    wrapMode: Text.Wrap; lineHeight: readerView.lineHeight
                    bottomPadding: Math.round(readerView.fontSize * readerView.lineHeight)
                    opacity: 0.9
                }
            }
        }

        ScrollBar.vertical: StyledScrollBar {}
    }

    // ── Navigation (bottom) ──────────────────────────────────────────────────
    Rectangle {
        anchors { bottom: parent.bottom; left: parent.left; right: parent.right }
        height: 64; color: Qt.alpha(c.m3surfaceContainerLowest, 0.95); z: 10

        Rectangle {
            anchors { top: parent.top; left: parent.left; right: parent.right }
            height: 1; color: c.m3outlineVariant; opacity: 0.3
        }

        RowLayout {
            anchors { fill: parent; leftMargin: Appearance.padding.lg; rightMargin: Appearance.padding.lg }
            spacing: Appearance.spacing.md

            IconButton {
                type: IconButton.Tonal
                icon: "navigate_before"
                disabled: !readerView._hasPrev
                opacity: readerView._hasPrev ? 1.0 : 0.3
                onClicked: { Novel.fetchPrevChapter(); textScroll.contentY = 0 }
            }

            StyledText {
                Layout.fillWidth: true
                text: Novel.currentChapter ? Novel.currentChapter.title : ""
                font.pointSize: Appearance.font.size.labelSmall
                color: c.m3onSurfaceVariant; opacity: 0.6
                elide: Text.ElideMiddle; horizontalAlignment: Text.AlignHCenter
            }

            IconButton {
                type: IconButton.Filled
                icon: "navigate_next"
                disabled: !readerView._hasNext
                opacity: readerView._hasNext ? 1.0 : 0.3
                onClicked: {
                    if (Novel.currentNovel && Novel.isInLibrary(Novel.currentNovel.id) && Novel.currentChapter)
                        Novel.updateLastRead(Novel.currentNovel.id, Novel.currentChapter.nextId, "")
                    Novel.fetchNextChapter()
                    textScroll.contentY = 0
                }
            }
        }
    }
}
