pragma ComponentBehavior: Bound

import qs.components
import qs.components.images
import qs.components.filedialog
import qs.services
import qs.config
import qs.utils
import QtQuick

Item {
    id: root

    property string source: Wallpapers.current
    property Image current: one

    anchors.fill: parent

    Component.onCompleted: {
        console.log("Wallpaper.qml - source:", source);
        console.log("Wallpaper.qml - Wallpapers.current:", Wallpapers.current);
        console.log("Wallpaper.qml - Wallpapers.actualCurrent:", Wallpapers.actualCurrent);
    }

    // Delayed initial load to ensure CachingImageManager is ready
    Timer {
        id: initialLoadTimer
        interval: 200
        running: root.source !== ""
        onTriggered: {
            console.log("Initial load timer triggered, source:", root.source);
            if (root.source && one.status !== Image.Ready && two.status !== Image.Ready) {
                one.path = root.source;
            }
        }
    }

    onSourceChanged: {
        console.log("Wallpaper.qml - source changed to:", source);
        if (!source)
            current = null;
        else if (current === one)
            two.update();
        else
            one.update();
    }

    Loader {
        anchors.fill: parent

        active: !root.source
        asynchronous: true

        sourceComponent: StyledRect {
            color: Colours.palette.m3surfaceContainer

            Row {
                anchors.centerIn: parent
                spacing: Appearance.spacing.large

                MaterialIcon {
                    text: "sentiment_stressed"
                    color: Colours.palette.m3onSurfaceVariant
                    font.pointSize: Appearance.font.size.extraLarge * 5
                }

                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Appearance.spacing.small

                    StyledText {
                        text: qsTr("Wallpaper missing?")
                        color: Colours.palette.m3onSurfaceVariant
                        font.pointSize: Appearance.font.size.extraLarge * 2
                        font.bold: true
                    }

                    StyledRect {
                        implicitWidth: selectWallText.implicitWidth + Appearance.padding.large * 2
                        implicitHeight: selectWallText.implicitHeight + Appearance.padding.small * 2

                        radius: Appearance.rounding.full
                        color: Colours.palette.m3primary

                        FileDialog {
                            id: dialog

                            title: qsTr("Select a wallpaper")
                            filterLabel: qsTr("Image files")
                            filters: Images.validImageExtensions
                            onAccepted: path => Wallpapers.setWallpaper(path)
                        }

                        StateLayer {
                            radius: parent.radius
                            color: Colours.palette.m3onPrimary

                            function onClicked(): void {
                                dialog.open();
                            }
                        }

                        StyledText {
                            id: selectWallText

                            anchors.centerIn: parent

                            text: qsTr("Set it now!")
                            color: Colours.palette.m3onPrimary
                            font.pointSize: Appearance.font.size.large
                        }
                    }
                }
            }
        }
    }

    Img {
        id: one
    }

    Img {
        id: two
    }

    component Img: CachingImage {
        id: img

        function update(): void {
            console.log("Img.update() called, path:", path, "source:", root.source);
            if (path === root.source)
                root.current = this;
            else
                path = root.source;
        }

        anchors.fill: parent
        sourceSize.width: root.width
        sourceSize.height: root.height
        opacity: 0
        scale: Wallpapers.showPreview ? 1 : 0.8

        onPathChanged: console.log("Img path changed to:", path)
        onStatusChanged: {
            console.log("Img status changed:", status, "Ready is:", Image.Ready);
            if (status === Image.Ready) {
                console.log("Image ready! Setting current");
                root.current = this;
            }
        }

        states: State {
            name: "visible"
            when: root.current === img

            PropertyChanges {
                img.opacity: 1
                img.scale: 1
            }
        }

        transitions: Transition {
            Anim {
                target: img
                properties: "opacity,scale"
            }
        }
    }
}
