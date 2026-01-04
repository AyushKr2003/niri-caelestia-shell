import "../"
import qs.components
import qs.components.controls
import qs.services
import qs.config
import Quickshell
import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import QtQuick.Layouts

// Component for editing object items in an array (like warnLevels entries)
StyledRect {
    id: root

    required property var itemData
    required property int itemIndex
    required property var arrayPath

    property bool expanded: false

    signal remove()
    signal update(var newData)

    implicitHeight: expanded ? headerHeight + contentColumn.implicitHeight + Appearance.spacing.normal : headerHeight
    readonly property int headerHeight: 64

    radius: Appearance.rounding.normal
    color: Colours.palette.m3surfaceContainerLow

    Behavior on implicitHeight {
        Anim { duration: Appearance.anim.durations.normal }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Appearance.padding.small
        spacing: Appearance.spacing.small

        // Header row
        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: root.headerHeight - Appearance.padding.small * 2
            spacing: Appearance.spacing.small

            // Expand/collapse button
            StyledRect {
                Layout.preferredWidth: 32
                Layout.preferredHeight: 32
                radius: Appearance.rounding.full
                color: "transparent"

                StateLayer {
                    radius: parent.radius
                    function onClicked(): void {
                        root.expanded = !root.expanded;
                    }
                }

                MaterialIcon {
                    anchors.centerIn: parent
                    text: root.expanded ? "expand_more" : "chevron_right"
                    font.pointSize: Appearance.font.size.normal
                    color: Colours.palette.m3onSurface
                }
            }

            // Index badge
            StyledRect {
                Layout.preferredWidth: 28
                Layout.preferredHeight: 28
                radius: Appearance.rounding.full
                color: Colours.palette.m3secondaryContainer

                StyledText {
                    anchors.centerIn: parent
                    text: (root.itemIndex + 1).toString()
                    font.pointSize: Appearance.font.size.small
                    font.weight: Font.Medium
                    color: Colours.palette.m3onSecondaryContainer
                }
            }

            // Preview of item (show title or first string property)
            StyledText {
                Layout.fillWidth: true
                text: root.itemData.title ?? root.itemData.name ?? 
                      root.itemData.label ?? `Item ${root.itemIndex + 1}`
                font.pointSize: Appearance.font.size.normal
                color: Colours.palette.m3onSurface
                elide: Text.ElideRight
            }

            // Icon preview if has icon property
            StyledRect {
                visible: root.itemData.icon !== undefined
                Layout.preferredWidth: 32
                Layout.preferredHeight: 32
                radius: Appearance.rounding.small
                color: Colours.palette.m3surfaceContainerHigh

                MaterialIcon {
                    anchors.centerIn: parent
                    text: root.itemData.icon ?? ""
                    font.pointSize: Appearance.font.size.normal
                    color: Colours.palette.m3onSurface
                }
            }

            // Delete button
            StyledRect {
                Layout.preferredWidth: 32
                Layout.preferredHeight: 32
                radius: Appearance.rounding.full
                color: "transparent"

                StateLayer {
                    radius: parent.radius
                    color: Colours.palette.m3error
                    function onClicked(): void {
                        root.remove();
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

        // Expanded content - edit each property
        ColumnLayout {
            id: contentColumn
            Layout.fillWidth: true
            Layout.leftMargin: Appearance.padding.normal
            visible: root.expanded
            spacing: Appearance.spacing.small

            Repeater {
                model: root.expanded ? Object.keys(root.itemData) : []

                delegate: RowLayout {
                    required property string modelData
                    required property int index

                    Layout.fillWidth: true
                    spacing: Appearance.spacing.normal

                    StyledText {
                        Layout.preferredWidth: 100
                        text: ConfigParser.formatPropertyName(modelData)
                        font.pointSize: Appearance.font.size.smaller
                        color: Colours.palette.m3onSurfaceVariant
                    }

                    Loader {
                        Layout.fillWidth: true
                        sourceComponent: {
                            const value = root.itemData[modelData];
                            const propName = modelData.toLowerCase();
                            
                            // Special handling for icon properties
                            if (propName === "icon") return iconEditorComponent;
                            
                            if (typeof value === "boolean") return boolEditorComponent;
                            if (typeof value === "number") return numberEditorComponent;
                            return stringEditorComponent;
                        }

                        property string propName: modelData
                        property var propValue: root.itemData[modelData]
                    }
                }
            }
        }
    }

    // Editor components
    Component {
        id: stringEditorComponent

        StyledRect {
            height: 48
            radius: Appearance.rounding.small
            color: Colours.palette.m3surfaceContainerHigh

            StyledTextField {
                anchors.fill: parent
                anchors.margins: Appearance.padding.small
                text: propValue ?? ""
                background: null
                onEditingFinished: {
                    const newData = Object.assign({}, root.itemData);
                    newData[propName] = text;
                    root.update(newData);
                }
            }
        }
    }

    Component {
        id: numberEditorComponent

        StyledRect {
            height: 48
            radius: Appearance.rounding.small
            color: Colours.palette.m3surfaceContainerHigh

            StyledTextField {
                anchors.fill: parent
                anchors.margins: Appearance.padding.small
                text: propValue?.toString() ?? "0"
                inputMethodHints: Qt.ImhFormattedNumbersOnly
                background: null
                onEditingFinished: {
                    const newData = Object.assign({}, root.itemData);
                    newData[propName] = parseFloat(text) || 0;
                    root.update(newData);
                }
            }
        }
    }

    Component {
        id: boolEditorComponent

        StyledSwitch {
            checked: propValue ?? false
            onToggled: {
                const newData = Object.assign({}, root.itemData);
                newData[propName] = checked;
                root.update(newData);
            }
        }
    }

    Component {
        id: iconEditorComponent

        RowLayout {
            spacing: Appearance.spacing.small

            StyledRect {
                Layout.preferredWidth: 48
                Layout.preferredHeight: 48
                radius: Appearance.rounding.small
                color: Colours.palette.m3surfaceContainerHigh

                MaterialIcon {
                    anchors.centerIn: parent
                    text: propValue ?? "help"
                    font.pointSize: Appearance.font.size.normal
                    color: Colours.palette.m3onSurface
                }
            }

            StyledRect {
                Layout.fillWidth: true
                Layout.preferredHeight: 48
                radius: Appearance.rounding.small
                color: Colours.palette.m3surfaceContainerHigh

                StyledTextField {
                    id: iconField
                    anchors.fill: parent
                    anchors.margins: Appearance.padding.small
                    text: propValue ?? ""
                    placeholderText: qsTr("Icon name...")
                    background: null
                    onEditingFinished: {
                        const newData = Object.assign({}, root.itemData);
                        newData[propName] = text;
                        root.update(newData);
                    }
                }
            }

            // Icon picker button
            StyledRect {
                Layout.preferredWidth: 48
                Layout.preferredHeight: 48
                radius: Appearance.rounding.small
                color: Colours.palette.m3primaryContainer

                StateLayer {
                    radius: parent.radius
                    function onClicked(): void {
                        iconPickerPopup.open();
                    }
                }

                MaterialIcon {
                    anchors.centerIn: parent
                    text: "search"
                    font.pointSize: Appearance.font.size.normal
                    color: Colours.palette.m3onPrimaryContainer
                }

                Popup {
                    id: iconPickerPopup
                    width: 300
                    height: 350
                    x: -width + parent.width
                    y: parent.height + Appearance.spacing.small

                    background: StyledRect {
                        color: Colours.palette.m3surfaceContainer
                        radius: Appearance.rounding.normal

                        layer.enabled: true
                        layer.effect: MultiEffect {
                            shadowEnabled: true
                            blurMax: 15
                            shadowColor: Qt.alpha(Colours.palette.m3shadow, 0.5)
                        }
                    }

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: Appearance.padding.normal
                        spacing: Appearance.spacing.small

                        StyledRect {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 40
                            radius: Appearance.rounding.small
                            color: Colours.palette.m3surfaceContainerHigh

                            RowLayout {
                                anchors.fill: parent
                                anchors.margins: Appearance.padding.small
                                spacing: Appearance.spacing.small

                                MaterialIcon {
                                    text: "search"
                                    color: Colours.palette.m3onSurfaceVariant
                                }

                                StyledTextField {
                                    id: popupSearchField
                                    Layout.fillWidth: true
                                    placeholderText: qsTr("Search icons...")
                                    background: null
                                }
                            }
                        }

                        GridView {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            clip: true
                            cellWidth: 44
                            cellHeight: 44

                            model: IconDatabase.searchIcons(popupSearchField.text)

                            ScrollBar.vertical: StyledScrollBar {}

                            delegate: Item {
                                required property string modelData

                                width: 44
                                height: 44

                                StyledRect {
                                    anchors.fill: parent
                                    anchors.margins: 2
                                    radius: Appearance.rounding.small
                                    color: propValue === parent.modelData ?
                                        Colours.palette.m3primaryContainer : "transparent"

                                    StateLayer {
                                        radius: parent.radius
                                        function onClicked(): void {
                                            const newData = Object.assign({}, root.itemData);
                                            newData[propName] = modelData;
                                            root.update(newData);
                                            iconPickerPopup.close();
                                        }
                                    }

                                    MaterialIcon {
                                        anchors.centerIn: parent
                                        text: parent.parent.modelData
                                        font.pointSize: Appearance.font.size.larger
                                        color: propValue === parent.parent.modelData ?
                                            Colours.palette.m3onPrimaryContainer : Colours.palette.m3onSurface
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
