pragma ComponentBehavior: Bound

import qs.components
import qs.components.controls
import qs.services
import qs.config
import Quickshell
import QtQuick
import QtQuick.Layouts

Item {
    id: root

    required property var list
    required property var modelData

    readonly property string entryId: modelData?.entryId ?? ""
    readonly property string entryText: modelData?.entryText ?? ""
    readonly property bool isImageEntry: modelData?.isImage ?? false

    readonly property string displayText: isImageEntry ? "image" : entryText

    function onClicked(): void {
        Quickshell.execDetached(["sh", "-c", "cliphist decode '" + root.entryId + "' | wl-copy"]);
        root.list.visibilities.launcher = false;
    }

    implicitHeight: isImageEntry ? Config.launcher.sizes.itemHeight + 120 : Config.launcher.sizes.itemHeight

    anchors.left: parent?.left
    anchors.right: parent?.right

    StateLayer {
        radius: Appearance.rounding.small

        function onClicked(): void {
            root.onClicked();
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.leftMargin: Appearance.padding.lg
        anchors.rightMargin: Appearance.padding.lg
        anchors.topMargin: Appearance.padding.sm
        anchors.bottomMargin: Appearance.padding.sm
        spacing: Appearance.spacing.sm

        /* IMAGE PREVIEW */
        StyledClippingRect {
            id: imageContainer
            visible: root.isImageEntry
            Layout.fillWidth: true
            Layout.preferredHeight: root.isImageEntry ? 100 : 0
            radius: Appearance.rounding.small
            color: Colours.tPalette.m3surfaceContainerLow

            property bool imageReady: false
            property string imagePath: "/tmp/cliphist-launcher-" + root.entryId + ".png"

            Component.onCompleted: {
                if (root.isImageEntry && root.entryId) {
                    Quickshell.execDetached([
                        "sh", "-c",
                        "cliphist decode " + root.entryId + " > " + imagePath
                    ]);
                    imageLoadTimer.start();
                }
            }

            Timer {
                id: imageLoadTimer
                interval: 200
                onTriggered: imageContainer.imageReady = true
            }

            Image {
                id: previewImage
                anchors.centerIn: parent
                source: imageContainer.imageReady ? "file://" + imageContainer.imagePath : ""
                fillMode: Image.PreserveAspectFit
                asynchronous: true
                cache: false
                width: parent.width - Appearance.padding.md * 2
                height: parent.height - Appearance.padding.md * 2
                smooth: true

                onStatusChanged: {
                    if (status === Image.Error && retryTimer.retryCount < 3) {
                        retryTimer.start();
                    }
                }

                Timer {
                    id: retryTimer
                    property int retryCount: 0
                    interval: 300
                    onTriggered: {
                        retryCount++;
                        const oldSource = previewImage.source;
                        previewImage.source = "";
                        previewImage.source = oldSource;
                    }
                }
            }

            // Loading spinner
            StyledRect {
                visible: root.isImageEntry && (previewImage.status === Image.Loading || !imageContainer.imageReady)
                anchors.centerIn: parent
                width: 32
                height: 32
                radius: Appearance.rounding.full
                color: Colours.palette.m3surfaceContainerHigh

                MaterialIcon {
                    anchors.centerIn: parent
                    text: "progress_activity"
                    font.pointSize: Appearance.font.size.bodyMedium
                    color: Colours.palette.m3primary

                    RotationAnimation on rotation {
                        loops: Animation.Infinite
                        from: 0
                        to: 360
                        duration: 1000
                    }
                }
            }

            // Error state
            MaterialIcon {
                visible: root.isImageEntry && previewImage.status === Image.Error
                anchors.centerIn: parent
                text: "broken_image"
                font.pointSize: Appearance.font.size.headlineLarge
                color: Colours.palette.m3outline
            }
        }

        /* TEXT & BUTTONS ROW */
        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: !root.isImageEntry
            spacing: Appearance.spacing.lg

            // Icon
            MaterialIcon {
                text: root.isImageEntry ? "image" : "content_paste"
                font.pointSize: Appearance.font.size.headlineLarge
                color: root.isImageEntry ? Colours.palette.m3tertiary : Colours.palette.m3primary
                Layout.alignment: Qt.AlignVCenter
            }

            // Text content
            StyledText {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
                text: root.displayText
                font.pointSize: Appearance.font.size.bodySmall
                elide: Text.ElideRight
                maximumLineCount: 1
                color: root.isImageEntry ? Colours.palette.m3outline : Colours.palette.m3onSurface
            }

            // Copy button
            StyledRect {
                Layout.preferredWidth: 32
                Layout.preferredHeight: 32
                Layout.alignment: Qt.AlignVCenter
                radius: Appearance.rounding.small
                color: "transparent"

                StateLayer {
                    radius: parent.radius
                    color: Colours.palette.m3primary

                    function onClicked(): void {
                        Quickshell.execDetached([
                            "sh", "-c",
                            "cliphist decode '" + root.entryId + "' | wl-copy"
                        ]);
                        copyFeedback.opacity = 1;
                        copyFeedbackTimer.start();
                    }
                }

                MaterialIcon {
                    id: copyIcon
                    anchors.centerIn: parent
                    text: "content_copy"
                    font.pointSize: Appearance.font.size.bodyMedium
                    color: Colours.palette.m3primary
                    opacity: copyFeedback.opacity === 0 ? 1 : 0

                    Behavior on opacity {
                        Anim {
                            duration: Appearance.anim.durations.small
                        }
                    }
                }

                MaterialIcon {
                    id: copyFeedback
                    anchors.centerIn: parent
                    text: "check"
                    font.pointSize: Appearance.font.size.bodyMedium
                    color: Colours.palette.m3tertiary
                    opacity: 0

                    Behavior on opacity {
                        Anim {
                            duration: Appearance.anim.durations.small
                        }
                    }
                }

                Timer {
                    id: copyFeedbackTimer
                    interval: 800
                    onTriggered: copyFeedback.opacity = 0
                }
            }

            // Delete button
            StyledRect {
                Layout.preferredWidth: 32
                Layout.preferredHeight: 32
                Layout.alignment: Qt.AlignVCenter
                radius: Appearance.rounding.small
                color: "transparent"

                StateLayer {
                    radius: parent.radius
                    color: Colours.palette.m3error

                    function onClicked(): void {
                        Quickshell.execDetached(["cliphist", "delete", root.entryId]);
                        root.list.removeClipEntry(root.entryId);
                    }
                }

                MaterialIcon {
                    anchors.centerIn: parent
                    text: "delete"
                    font.pointSize: Appearance.font.size.bodyMedium
                    color: Colours.palette.m3error
                }
            }
        }
    }
}
