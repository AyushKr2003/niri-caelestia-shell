import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import qs.config
import qs.services
import "../../components"
import "../../components/controls"
import "./components"

Item {
    id: root
    
    property var visibilities

    anchors {
        top: parent.top
        bottom: parent.bottom
        left: parent.left
    }
    implicitWidth: 600
    visible: false

    readonly property var c: Colours.tPalette
    readonly property string fontBody: Config.appearance.font.family.sans

    property int tabIndex: 0

    property int browseStack: 0
    property int libraryStack: 0

    property string selectedMangaId: ""

    function reset() {
        console.log("[MangaReader] Resetting state")
        root.tabIndex = 0
        root.browseStack = 0
        root.libraryStack = 0
        Manga.clearChapterList()
        Manga.clearChapterPages()
        browseView.reset()
        browseDetail.reset()
        libraryDetail.reset()
    }

    onVisibleChanged: {
        if (visible) {
            root.reset()
        }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        Rectangle {
            Layout.fillWidth: true
            height: 48
            color: c.m3surfaceContainerLow
            z: 10

            Rectangle {
                anchors { bottom: parent.bottom; left: parent.left; right: parent.right }
                height: 1; color: c.m3outlineVariant; opacity: 0.4
            }

            Row {
                anchors.fill: parent

                Repeater {
                    model: [
                        { label: qsTr("Browse"),  icon: "explore" },
                        { label: qsTr("Library"), icon: "library_books" }
                    ]

                    delegate: Item {
                        width: root.width / 2
                        height: parent.height

                        readonly property bool active: root.tabIndex === index

                        StateLayer {
                            anchors.fill: parent
                            color: active ? Colours.palette.m3primary : Colours.palette.m3onSurface
                            opacity: active ? 0.12 : 0
                            
                            function onClicked(): void {
                                root.tabIndex = index
                            }
                        }

                        RowLayout {
                            anchors.centerIn: parent
                            spacing: Appearance.spacing.sm

                            MaterialIcon {
                                text: modelData.icon
                                font.pointSize: Appearance.font.size.bodyLarge
                                color: active ? c.m3primary : c.m3onSurfaceVariant
                                opacity: active ? 1 : 0.7
                                Behavior on color { ColorAnimation { duration: 180 } }
                            }
                            
                            StyledText {
                                text: modelData.label
                                font.pointSize: Appearance.font.size.labelLarge
                                font.weight: active ? Font.Bold : Font.Normal
                                color: active ? c.m3primary : c.m3onSurfaceVariant
                                opacity: active ? 1 : 0.7
                                Behavior on color { ColorAnimation { duration: 180 } }
                            }
                        }

                        Rectangle {
                            anchors {
                                bottom: parent.bottom
                                horizontalCenter: parent.horizontalCenter
                            }
                            width: active ? parent.width * 0.6 : 0
                            height: 3; radius: 1.5
                            color: c.m3primary
                            Behavior on width { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
                        }
                    }
                }
            }
        }

        StackLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            currentIndex: root.tabIndex

            Item {

                BrowseView {
                    id: browseView
                    anchors.fill: parent
                    visible: root.browseStack === 0
                    opacity: visible ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }

                    onMangaSelected: function(mangaId) {
                        root.selectedMangaId = mangaId
                        root.browseStack = 1
                    }
                }

                DetailView {
                    id: browseDetail
                    anchors.fill: parent
                    visible: root.browseStack === 1
                    opacity: visible ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }

                    onBackRequested:   { root.browseStack = 0 }
                    onChapterSelected: { root.browseStack = 2 }
                }

                ReaderView {
                    id: browseReader
                    anchors.fill: parent
                    visible: root.browseStack === 2
                    opacity: visible ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }

                    onBackRequested: {
                        root.browseStack = 1
                        browseReader.reset()
                    }
                }
            }

            Item {
                LibraryView {
                    anchors.fill: parent
                    visible: root.libraryStack === 0
                    opacity: visible ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }

                    onMangaSelected: function(mangaId) {
                        root.selectedMangaId = mangaId
                        root.libraryStack = 1
                    }
                }

                DetailView {
                    id: libraryDetail
                    anchors.fill: parent
                    visible: root.libraryStack === 1
                    opacity: visible ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }

                    onBackRequested:   { root.libraryStack = 0 }
                    onChapterSelected: { root.libraryStack = 2 }
                }

                ReaderView {
                    id: libraryReader
                    anchors.fill: parent
                    visible: root.libraryStack === 2
                    opacity: visible ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }

                    onBackRequested: {
                        root.libraryStack = 1
                        libraryReader.reset()
                    }
                }
            }
        }
    }
}
