pragma ComponentBehavior: Bound

import qs.components
import qs.components.images
import qs.components.filedialog
import qs.services
import qs.config
import qs.utils
import Caelestia
import QtQuick
import QtMultimedia

Item {
    id: root

    property string source: Wallpapers.current
    property Item current: one

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
            if (root.source && one.path === "" && two.path === "") {
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
                spacing: Appearance.spacing.xxl

                MaterialIcon {
                    text: "sentiment_stressed"
                    color: Colours.palette.m3onSurfaceVariant
                    font.pointSize: Appearance.font.size.headlineLarge * 5
                }

                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Appearance.spacing.sm

                    StyledText {
                        text: qsTr("Wallpaper missing?")
                        color: Colours.palette.m3onSurfaceVariant
                        font.pointSize: Appearance.font.size.headlineLarge * 2
                        font.bold: true
                    }

                    StyledRect {
                        implicitWidth: selectWallText.implicitWidth + Appearance.padding.xl * 2
                        implicitHeight: selectWallText.implicitHeight + Appearance.padding.xs * 2

                        radius: Appearance.rounding.full
                        color: Colours.palette.m3primary

                        FileDialog {
                            id: dialog

                            title: qsTr("Select a wallpaper")
                            filterLabel: qsTr("Image or Video files")
                            filters: Images.validImageExtensions.concat(["mp4", "mkv", "webm", "mov", "avi", "m4v"])
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
                            font.pointSize: Appearance.font.size.titleMedium
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

    component Img: Item {
        id: item

        property string path: ""

        function update(): void {
            console.log("Img.update()", item.id === "one" ? "one" : "two", "path:", path, "target:", root.source);
            if (path === root.source) {
                console.log("Path matches, setting current immediately");
                root.current = item;
            } else {
                path = root.source;
            }
        }

        anchors.fill: parent
        opacity: 0
        scale: Wallpapers.showPreview ? 1 : 0.8

        readonly property bool isVideo: Wallpapers.isPathVideo(path)

        Connections {
            target: Wallpapers
            function onFrameReady(p): void {
                if (p === item.path && item.isVideo) {
                    console.log("Img: frame ready, force-updating fallback");
                    const old = frameFallback.path;
                    frameFallback.path = "";
                    frameFallback.path = old;
                }
            }
        }

        onPathChanged: {
            const video = Wallpapers.isPathVideo(path);
            console.log("Img path changed:", path, "isPathVideo:", video);
            if (video && path !== "") {
                if (root.current === item) {
                    console.log("Path changed for current item, playing video");
                    player.play();
                } else {
                    console.log("Path changed for non-current item, setting current");
                    root.current = item;
                }
            }
        }

        // Show the extracted frame for videos as a still image fallback
        CachingImage {
            id: frameFallback
            anchors.fill: parent
            path: {
                if (!item.isVideo || item.path === "") return "";
                const src = Wallpapers.getColorSource(item.path);
                return CUtils.exists(src) ? src : "";
            }

            // RAM Optimization: Ensure we don't load more than screen resolution
            sourceSize.width: root.width
            sourceSize.height: root.height

            visible: item.isVideo
            opacity: 1
            z: 1
        }

        CachingImage {
            id: img
            anchors.fill: parent
            path: !item.isVideo ? item.path : ""
            visible: !item.isVideo
            opacity: status === Image.Ready ? 1 : 0
            z: 2
            onStatusChanged: {
                if (status === Image.Ready && !item.isVideo) {
                    console.log("Image ready, setting current");
                    root.current = item;
                }
            }
        }

        VideoOutput {
            id: videoOutput
            anchors.fill: parent
            visible: item.isVideo
            fillMode: VideoOutput.PreserveAspectCrop
            z: 3
        }

        MediaPlayer {
            id: player
            videoOutput: videoOutput
            loops: MediaPlayer.Infinite

            onErrorOccurred: (error, errorString) => console.error("MediaPlayer Error:", errorString)
            onMediaStatusChanged: {
                if (mediaStatus === MediaPlayer.LoadedMedia && root.current === item && item.isVideo) {
                    console.log("MediaPlayer loaded for current item, playing");
                    player.play();
                }
            }

            audioOutput: AudioOutput {
                muted: true
            }
        }

        states: [
            State {
                name: "visible"
                when: root.current === item

                PropertyChanges {
                    item.opacity: 1
                    item.scale: 1
                    player.source: item.isVideo ? (item.path.startsWith("/") ? "file://" + item.path : item.path) : ""
                }

                StateChangeScript {
                    script: {
                        console.log("Img visible state activated for", item.path);
                        if (item.isVideo) {
                            console.log("Starting video playback");
                            // Small delay to ensure source is applied before play()
                            Qt.callLater(() => player.play());
                        }
                    }
                }
            },
            State {
                name: "hidden"
                when: root.current !== item

                PropertyChanges {
                    item.opacity: 0
                    item.scale: Wallpapers.showPreview ? 1 : 0.8
                }

                StateChangeScript {
                    script: {
                        if (item.isVideo) {
                            console.log("Releasing video resources for hidden item");
                            player.stop();
                            player.source = "";
                        }
                    }
                }
            }
        ]

        transitions: Transition {
            Anim {
                target: item
                properties: "opacity,scale"
            }
        }
    }
}
