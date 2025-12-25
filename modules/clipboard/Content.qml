pragma ComponentBehavior: Bound

import qs.components
import qs.components.controls
import qs.components.containers
import qs.services
import qs.config
import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

Item {
    id: root

    required property var wrapper
    required property PersistentProperties visibilities

    readonly property int padding: Appearance.padding.large
    readonly property int rounding: Appearance.rounding.large

    implicitWidth: 380
    implicitHeight: 500

    anchors.top: parent?.top
    anchors.right: parent?.right

    ListModel { id: clipboardModel }
    ListModel { id: filteredModel }

    Process {
        id: cliphistProc
        command: ["cliphist", "list"]
        stdout: StdioCollector {
            onStreamFinished: {
                clipboardModel.clear()
                const lines = text.trim().split("\n")
                for (const line of lines) {
                    if (!line) continue
                    const parts = line.split("\t")
                    clipboardModel.append({
                        id: parts[0],
                        content: parts.slice(1).join("\t"),
                        isImage: line.includes("[[ binary data")
                    })
                }
                filterItems()
            }
        }
    }

    function refresh() { cliphistProc.running = true }

    function wipeAll() {
        Quickshell.execDetached(["cliphist", "wipe"])
        clipboardModel.clear()
        filteredModel.clear()
    }

    function filterItems() {
        const query = searchInput.text.toLowerCase()
        filteredModel.clear()

        for (let i = 0; i < clipboardModel.count; i++) {
            const item = clipboardModel.get(i)
            if (query === "" || item.content.toLowerCase().includes(query)) {
                filteredModel.append(item)
            }
        }

        if (filteredModel.count > 0) {
            listView.currentIndex = 0
        }
    }

    Connections {
        target: root.visibilities

        function onClipboardChanged(): void {
            if (root.visibilities.clipboard) {
                refresh()
                Qt.callLater(() => searchInput.forceActiveFocus())
            } else {
                searchInput.text = ""
            }
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: root.padding
        spacing: Appearance.spacing.normal

        /* HEADER */
        RowLayout {
            Layout.fillWidth: true
            spacing: Appearance.spacing.normal

            MaterialIcon {
                text: "content_paste"
                font.pointSize: Appearance.font.size.large
                color: Colours.palette.m3primary
            }

            StyledText {
                text: qsTr("Clipboard")
                font.pointSize: Appearance.font.size.large
                font.weight: Font.Bold
                Layout.fillWidth: true
            }

            // Wipe all button
            StyledRect {
                Layout.preferredWidth: 32
                Layout.preferredHeight: 32
                radius: Appearance.rounding.small
                color: "transparent"

                StateLayer {
                    radius: parent.radius
                    color: Colours.palette.m3error

                    function onClicked(): void {
                        wipeAll()
                    }
                }

                MaterialIcon {
                    anchors.centerIn: parent
                    text: "delete_sweep"
                    font.pointSize: Appearance.font.size.larger
                    color: Colours.palette.m3error
                }
            }

            // Close button
            StyledRect {
                Layout.preferredWidth: 32
                Layout.preferredHeight: 32
                radius: Appearance.rounding.small
                color: "transparent"

                StateLayer {
                    radius: parent.radius
                    color: Colours.palette.m3onSurface

                    function onClicked(): void {
                        root.visibilities.clipboard = false
                    }
                }

                MaterialIcon {
                    anchors.centerIn: parent
                    text: "close"
                    font.pointSize: Appearance.font.size.larger
                    color: Colours.palette.m3onSurfaceVariant
                }
            }
        }

        /* SEARCH BAR */
        StyledRect {
            Layout.fillWidth: true
            Layout.preferredHeight: Math.max(searchIcon.implicitHeight, searchInput.implicitHeight, clearIcon.implicitHeight)
            radius: Appearance.rounding.small
            color: Colours.tPalette.m3surfaceContainer

            MaterialIcon {
                id: searchIcon
                anchors.verticalCenter: parent.verticalCenter
                anchors.left: parent.left
                anchors.leftMargin: Appearance.padding.normal
                text: "search"
                color: Colours.palette.m3onSurfaceVariant
            }

            StyledTextField {
                id: searchInput
                anchors.left: searchIcon.right
                anchors.right: clearIcon.left
                anchors.leftMargin: Appearance.spacing.small
                anchors.rightMargin: Appearance.spacing.small
                topPadding: Appearance.padding.larger
                bottomPadding: Appearance.padding.larger

                placeholderText: qsTr("Search...")

                onTextChanged: filterItems()

                Keys.onPressed: (event) => {
                    if (event.key === Qt.Key_Down) {
                        listView.forceActiveFocus()
                        event.accepted = true
                    } else if (event.key === Qt.Key_Escape) {
                        if (text === "") {
                            root.visibilities.clipboard = false
                        } else {
                            text = ""
                        }
                        event.accepted = true
                    } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                        listView.forceActiveFocus()
                        listView.activateCurrent()
                        event.accepted = true
                    }
                }
            }

            MaterialIcon {
                id: clearIcon
                anchors.verticalCenter: parent.verticalCenter
                anchors.right: parent.right
                anchors.rightMargin: Appearance.padding.normal

                width: searchInput.text ? implicitWidth : implicitWidth / 2
                opacity: searchInput.text ? 1 : 0

                text: "close"
                color: Colours.palette.m3onSurfaceVariant

                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: searchInput.text ? Qt.PointingHandCursor : undefined
                    onClicked: searchInput.text = ""
                }

                Behavior on width {
                    Anim {
                        duration: Appearance.anim.durations.small
                    }
                }

                Behavior on opacity {
                    Anim {
                        duration: Appearance.anim.durations.small
                    }
                }
            }
        }

        /* CLIPBOARD LIST */
        StyledClippingRect {
            Layout.fillWidth: true
            Layout.fillHeight: true
            radius: Appearance.rounding.small
            color: Colours.tPalette.m3surfaceContainer

            StyledListView {
                id: listView
                anchors.fill: parent
                anchors.margins: Appearance.padding.smaller
                model: filteredModel
                spacing: Appearance.spacing.small
                currentIndex: 0
                highlightFollowsCurrentItem: true
                clip: true

                highlightMoveDuration: Appearance.anim.durations.normal
                highlightResizeDuration: 0

                highlight: StyledRect {
                    radius: Appearance.rounding.small
                    color: Colours.palette.m3onSurface
                    opacity: 0.08
                }

                delegate: ClipboardItem {
                    required property int index
                    required property string id
                    required property string content
                    required property bool isImage

                    entryId: id
                    entryText: content
                    isImageEntry: isImage
                    selected: ListView.isCurrentItem
                    width: listView.width

                    onActivated: {
                        Quickshell.execDetached(["sh", "-c", "cliphist decode '" + id + "' | wl-copy"])
                        root.visibilities.clipboard = false
                    }

                    onDeleteRequested: {
                        Quickshell.execDetached(["cliphist", "delete", id])

                        // Remove from both models
                        for (let i = 0; i < clipboardModel.count; i++) {
                            if (clipboardModel.get(i).id === id) {
                                clipboardModel.remove(i)
                                break
                            }
                        }
                        filteredModel.remove(index)
                    }
                }

                Keys.onPressed: (event) => {
                    if (event.key === Qt.Key_Down && currentIndex < count - 1) {
                        currentIndex++
                        event.accepted = true
                    } else if (event.key === Qt.Key_Up) {
                        if (currentIndex > 0) {
                            currentIndex--
                        } else {
                            searchInput.forceActiveFocus()
                        }
                        event.accepted = true
                    } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                        activateCurrent()
                        event.accepted = true
                    } else if (event.key === Qt.Key_Escape) {
                        root.visibilities.clipboard = false
                        event.accepted = true
                    } else if (event.key === Qt.Key_Delete) {
                        if (currentIndex >= 0 && currentIndex < count) {
                            const entryId = filteredModel.get(currentIndex).id
                            Quickshell.execDetached(["cliphist", "delete", entryId])

                            for (let i = 0; i < clipboardModel.count; i++) {
                                if (clipboardModel.get(i).id === entryId) {
                                    clipboardModel.remove(i)
                                    break
                                }
                            }
                            filteredModel.remove(currentIndex)
                        }
                        event.accepted = true
                    }
                }

                function activateCurrent() {
                    if (currentIndex < 0 || currentIndex >= count) return
                    const entryId = filteredModel.get(currentIndex).id
                    Quickshell.execDetached(["sh", "-c", "cliphist decode '" + entryId + "' | wl-copy"])
                    root.visibilities.clipboard = false
                }

                ScrollBar.vertical: StyledScrollBar {}
            }

            // Empty state
            Column {
                visible: filteredModel.count === 0
                anchors.centerIn: parent
                spacing: Appearance.spacing.normal

                MaterialIcon {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: searchInput.text === "" ? "content_paste_off" : "search_off"
                    font.pointSize: Appearance.font.size.extraLarge
                    color: Colours.palette.m3outline
                }

                StyledText {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: searchInput.text === "" ? qsTr("No clipboard history") : qsTr("No results found")
                    font.pointSize: Appearance.font.size.normal
                    color: Colours.palette.m3outline
                }
            }
        }

        /* FOOTER */
        RowLayout {
            Layout.fillWidth: true
            spacing: Appearance.spacing.normal

            StyledText {
                text: filteredModel.count + " " + qsTr("items")
                font.pointSize: Appearance.font.size.small
                color: Colours.palette.m3outline
            }

            Item { Layout.fillWidth: true }

            RowLayout {
                spacing: Appearance.spacing.small

                MaterialIcon {
                    text: "keyboard_return"
                    font.pointSize: Appearance.font.size.extraSmall
                    color: Colours.palette.m3outline
                }

                StyledText {
                    text: qsTr("Select")
                    font.pointSize: Appearance.font.size.extraSmall
                    color: Colours.palette.m3outline
                }
            }

            RowLayout {
                spacing: Appearance.spacing.small

                MaterialIcon {
                    text: "backspace"
                    font.pointSize: Appearance.font.size.extraSmall
                    color: Colours.palette.m3outline
                }

                StyledText {
                    text: qsTr("Delete")
                    font.pointSize: Appearance.font.size.extraSmall
                    color: Colours.palette.m3outline
                }
            }
        }
    }
}
