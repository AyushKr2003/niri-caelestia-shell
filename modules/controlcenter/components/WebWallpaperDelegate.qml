pragma ComponentBehavior: Bound

import qs.components
import qs.components.controls
import qs.services
import qs.config
import QtQuick
import QtQuick.Layouts

Item {
    id: root
    
    required property var modelData
    required property bool isDownloading
    
    signal clicked()

    readonly property real itemMargin: Appearance.spacing.lg / 2
    readonly property real itemRadius: Appearance.rounding.normal

    visible: !!modelData

    StateLayer {
        anchors.fill: parent
        anchors.leftMargin: root.itemMargin
        anchors.rightMargin: root.itemMargin
        anchors.topMargin: root.itemMargin
        anchors.bottomMargin: root.itemMargin
        radius: root.itemRadius
        onClicked: root.clicked()
    }

    StyledClippingRect {
        anchors.fill: parent
        anchors.leftMargin: root.itemMargin
        anchors.rightMargin: root.itemMargin
        anchors.topMargin: root.itemMargin
        anchors.bottomMargin: root.itemMargin
        color: Colours.tPalette.m3surfaceContainer
        radius: root.itemRadius
        
        Image {
            source: root.modelData ? root.modelData.url_thumb : ""
            anchors.fill: parent
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            
            opacity: status === Image.Ready ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 300 } }

            onStatusChanged: {
                if (status === Image.Error && root.modelData) {
                    console.warn("Failed to load web wallpaper thumb:", root.modelData.url_thumb);
                }
            }
        }

        // Progress overlay
        Rectangle {
            anchors.fill: parent
            color: Qt.rgba(0, 0, 0, 0.5)
            visible: root.isDownloading
            
            StyledBusyIndicator {
                anchors.centerIn: parent
            }
        }

        // Filename overlay
        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            height: 30
            color: Qt.rgba(0, 0, 0, 0.4)
            
            StyledText {
                anchors.centerIn: parent
                width: parent.width - 10
                text: root.modelData ? root.modelData.slug : ""
                font.pointSize: Appearance.font.size.bodySmall
                color: "white"
                elide: Text.ElideMiddle
                horizontalAlignment: Text.AlignHCenter
            }
        }
    }
}
