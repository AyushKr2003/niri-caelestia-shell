pragma ComponentBehavior: Bound

import qs.components
import qs.components.controls
import qs.components.containers
import qs.services
import qs.config
import Quickshell
import Quickshell.Io as Io
import QtQuick
import QtQuick.Layouts

StyledRect {
    id: root

    required property var modelData
    required property var list
    readonly property bool isImage: modelData?.isImage ?? false
    readonly property string entryId: modelData?.entryId ?? ""
    readonly property string entryText: modelData?.entryText ?? ""

    color: Colours.tPalette.m3surfaceContainer
    radius: Appearance.rounding.small

    implicitWidth: 300
    implicitHeight: 400

    property string _decodingId: ""
    property bool imageReady: false
    readonly property string imagePath: root.entryId !== "" ? "/tmp/cliphist-launcher-preview-" + root.entryId + ".png" : ""

    onEntryIdChanged: {
        imageReady = false;
        decoder.running = false;
        _decodingId = "";
        if (isImage && entryId !== "") {
            decodeDebounce.restart();
        }
    }

    Timer {
        id: decodeDebounce
        interval: 100 // Debounce to prevent rapid decoding during navigation
        onTriggered: {
            if (root.entryId !== "" && root.isImage) {
                root._decodingId = root.entryId;
                // Escape single quotes for shell safety
                const escapedId = root.entryId.replace(/'/g, "'\\''");
                decoder.command = ["sh", "-c", "cliphist decode '" + escapedId + "' > '" + root.imagePath + "'"];
                decoder.running = true;
            }
        }
    }

    Io.Process {
        id: decoder
        
        onExited: (exitCode) => {
            // Only set ready if the process was for the current item and successful
            if (exitCode === 0 && root.entryId === root._decodingId && root.entryId !== "") {
                // Short sync delay to ensure the OS has finished writing the file
                syncTimer.restart();
            }
        }
    }

    Timer {
        id: syncTimer
        interval: 50
        onTriggered: root.imageReady = true
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Appearance.padding.lg
        spacing: Appearance.spacing.md

        // Header
        RowLayout {
            Layout.fillWidth: true
            spacing: Appearance.spacing.md

            MaterialIcon {
                text: root.isImage ? "image" : "description"
                color: Colours.palette.m3primary
                font.pointSize: Appearance.font.size.titleMedium
            }

            StyledText {
                text: root.isImage ? qsTr("Image Preview") : qsTr("Text Preview")
                font.pointSize: Appearance.font.size.titleMedium
                font.weight: 600
                color: Colours.palette.m3onSurface
                Layout.fillWidth: true
            }
        }

        // Content
        StyledRect {
            Layout.fillWidth: true
            Layout.fillHeight: true
            color: Colours.tPalette.m3surfaceContainerLow
            radius: Appearance.rounding.small
            clip: true

            // Image Preview
            Image {
                visible: root.isImage
                anchors.fill: parent
                anchors.margins: Appearance.padding.md
                // Only load when ready and path matches current ID to avoid stale/missing file errors
                source: (root.imageReady && root.entryId === root._decodingId && root.imagePath !== "") ? "file://" + root.imagePath : ""
                fillMode: Image.PreserveAspectFit
                asynchronous: true
                cache: false
                smooth: true

                onStatusChanged: {
                    if (status === Image.Error && root.imageReady) {
                        // If it fails even when we thought it was ready, reset and maybe retry later
                        console.warn("Failed to load image: " + source);
                    }
                }
            }

            // Text Preview
            StyledFlickable {
                visible: !root.isImage
                anchors.fill: parent
                contentWidth: width
                contentHeight: previewText.implicitHeight
                clip: true

                StyledText {
                    id: previewText
                    width: parent.width - Appearance.padding.md * 2
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.top: parent.top
                    anchors.topMargin: Appearance.padding.md
                    text: root.entryText
                    wrapMode: Text.Wrap
                    font.pointSize: Appearance.font.size.bodyMedium
                    color: Colours.palette.m3onSurfaceVariant
                }
            }

            // Loading state for image
            StyledRect {
                visible: root.isImage && !root.imageReady
                anchors.fill: parent
                color: Colours.tPalette.m3surfaceContainerLow
                radius: Appearance.rounding.small

                StyledBusyIndicator {
                    anchors.centerIn: parent
                }
            }
        }
    }
}
