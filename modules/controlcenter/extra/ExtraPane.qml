pragma ComponentBehavior: Bound

import ".."
import "../components"
import qs.components
import qs.components.controls
import qs.components.effects
import qs.components.containers
import qs.services
import qs.config
import Caelestia
import Quickshell
import Quickshell.Widgets
import QtQuick
import QtQuick.Layouts

Item {
    id: root

    required property Session session

    property bool mangaEnabled: Config.extra.manga ?? true
    property bool novelEnabled: Config.extra.novel ?? true

    anchors.fill: parent

    function saveConfig() {
        Config.extra.manga = root.mangaEnabled;
        Config.extra.novel = root.novelEnabled;
        Config.markDirty("extra");
    }

    ClippingRectangle {
        id: extraClippingRect
        anchors.fill: parent
        anchors.margins: Appearance.padding.md
        anchors.leftMargin: 0
        anchors.rightMargin: Appearance.padding.md

        radius: extraBorder.innerRadius
        color: "transparent"

        Loader {
            id: extraLoader
            anchors.fill: parent
            anchors.margins: Appearance.padding.xl + Appearance.padding.md
            anchors.leftMargin: Appearance.padding.xl
            anchors.rightMargin: Appearance.padding.xl

            sourceComponent: extraContentComponent
        }
    }

    InnerBorder {
        id: extraBorder
        leftThickness: 0
        rightThickness: Appearance.padding.md
    }

    Component {
        id: extraContentComponent

        StyledFlickable {
            id: extraFlickable
            flickableDirection: Flickable.VerticalFlick
            contentHeight: extraLayout.height

            StyledScrollBar.vertical: StyledScrollBar {
                flickable: extraFlickable
            }

            ColumnLayout {
                id: extraLayout
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                spacing: Appearance.spacing.lg

                RowLayout {
                    spacing: Appearance.spacing.md

                    StyledText {
                        text: qsTr("Extra Features")
                        font.pointSize: Appearance.font.size.titleMedium
                        font.weight: 500
                    }
                }

                // Features Section
                SectionContainer {
                    alignTop: true

                    StyledText {
                        text: qsTr("Features")
                        font.pointSize: Appearance.font.size.bodyMedium
                    }

                    SwitchRow {
                        label: qsTr("Manga")
                        checked: root.mangaEnabled
                        onToggled: checked => {
                            root.mangaEnabled = checked;
                            root.saveConfig();
                        }
                    }

                    SwitchRow {
                        label: qsTr("Novel")
                        checked: root.novelEnabled
                        onToggled: checked => {
                            root.novelEnabled = checked;
                            root.saveConfig();
                        }
                    }
                }
            }
        }
    }
}
