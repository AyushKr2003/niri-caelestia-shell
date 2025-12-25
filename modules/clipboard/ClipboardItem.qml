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

    // Properties
    required property string entryId
    required property string entryText
    property bool isImageEntry: false
    property bool selected: false

    // Signals
    signal activated()
    signal deleteRequested()

    // Layout
    implicitWidth: ListView.view ? ListView.view.width : 600
    implicitHeight: isImageEntry ? 160 : Config.launcher.sizes.itemHeight

    // Main interaction layer
    StateLayer {
        id: stateLayer
        radius: Appearance.rounding.small

        function onClicked(): void {
            root.activated()
        }
    }

    // Selection highlight
    StyledRect {
        anchors.fill: parent
        radius: Appearance.rounding.small
        color: root.selected ? Qt.alpha(Colours.palette.m3primary, 0.12) : "transparent"
        border.color: root.selected ? Colours.palette.m3primary : "transparent"
        border.width: root.selected ? 1 : 0
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Appearance.padding.smaller
        spacing: Appearance.spacing.small

        /* IMAGE PREVIEW */
        StyledClippingRect {
            id: imageContainer
            visible: root.isImageEntry
            Layout.preferredHeight: root.isImageEntry ? 100 : 0
            Layout.fillWidth: true
            radius: Appearance.rounding.small
            color: Colours.tPalette.m3surfaceContainerLow

            // Track if we've started loading
            property bool imageReady: false
            property string imagePath: "/tmp/cliphist-" + root.entryId + ".png"

            Component.onCompleted: {
                if (root.isImageEntry && root.entryId) {
                    // Decode the image first, then load after a delay
                    Quickshell.execDetached([
                        "sh", "-c",
                        "cliphist decode " + root.entryId + " > " + imagePath
                    ])
                    imageLoadTimer.start()
                }
            }

            Timer {
                id: imageLoadTimer
                interval: 200
                onTriggered: {
                    imageContainer.imageReady = true
                }
            }

            Image {
                id: previewImage
                anchors.centerIn: parent
                // Only set source after timer fires to give cliphist time to write the file
                source: imageContainer.imageReady ? "file://" + imageContainer.imagePath : ""
                fillMode: Image.PreserveAspectFit
                asynchronous: true
                cache: false
                width: parent.width - Appearance.padding.normal * 2
                height: parent.height - Appearance.padding.normal * 2
                smooth: true

                // Retry loading if it fails initially
                onStatusChanged: {
                    if (status === Image.Error && retryTimer.retryCount < 3) {
                        retryTimer.start()
                    }
                }

                Timer {
                    id: retryTimer
                    property int retryCount: 0
                    interval: 300
                    onTriggered: {
                        retryCount++
                        // Force reload by toggling source
                        const oldSource = previewImage.source
                        previewImage.source = ""
                        previewImage.source = oldSource
                    }
                }
            }

            // Loading indicator
            StyledRect {
                visible: root.isImageEntry && (previewImage.status === Image.Loading || !imageContainer.imageReady)
                anchors.centerIn: parent
                width: 40
                height: 40
                radius: Appearance.rounding.full
                color: Colours.palette.m3surfaceContainerHigh

                MaterialIcon {
                    anchors.centerIn: parent
                    text: "progress_activity"
                    font.pointSize: Appearance.font.size.larger
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
            Column {
                visible: root.isImageEntry && previewImage.status === Image.Error
                anchors.centerIn: parent
                spacing: Appearance.spacing.small

                MaterialIcon {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "broken_image"
                    font.pointSize: Appearance.font.size.extraLarge
                    color: Colours.palette.m3outline
                }

                StyledText {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: qsTr("Image Preview")
                    font.pointSize: Appearance.font.size.small
                    color: Colours.palette.m3outline
                }
            }
        }

        /* TEXT & BUTTONS ROW */
        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: !root.isImageEntry
            spacing: Appearance.spacing.normal

            // Icon indicator
            MaterialIcon {
                text: root.isImageEntry ? "image" : "content_paste"
                font.pointSize: Appearance.font.size.larger
                color: root.isImageEntry ? Colours.palette.m3tertiary : Colours.palette.m3primary
            }

            StyledText {
                Layout.fillWidth: true
                text: root.entryText
                font.pointSize: Appearance.font.size.smaller
                elide: Text.ElideRight
                maximumLineCount: 1
            }

            /* COPY BUTTON */
            StyledRect {
                id: copyButton
                Layout.preferredWidth: 32
                Layout.preferredHeight: 32
                radius: Appearance.rounding.small
                color: "transparent"

                StateLayer {
                    radius: parent.radius
                    color: Colours.palette.m3primary

                    function onClicked(): void {
                        Quickshell.execDetached([
                            "sh", "-c", 
                            "cliphist decode '" + root.entryId + "' | wl-copy"
                        ])
                        copyFeedback.opacity = 1
                        copyFeedbackTimer.start()
                    }
                }

                MaterialIcon {
                    id: copyIcon
                    anchors.centerIn: parent
                    text: "content_copy"
                    font.pointSize: Appearance.font.size.normal
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
                    font.pointSize: Appearance.font.size.normal
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

            /* DELETE BUTTON */
            StyledRect {
                id: deleteButton
                Layout.preferredWidth: 32
                Layout.preferredHeight: 32
                radius: Appearance.rounding.small
                color: "transparent"

                StateLayer {
                    radius: parent.radius
                    color: Colours.palette.m3error

                    function onClicked(): void {
                        root.deleteRequested()
                    }
                }

                MaterialIcon {
                    anchors.centerIn: parent
                    text: "delete"
                    font.pointSize: Appearance.font.size.normal
                    color: Colours.palette.m3error
                }
            }
        }
    }
}
