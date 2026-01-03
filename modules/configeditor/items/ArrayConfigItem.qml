import "../"
import qs.components
import qs.components.controls
import qs.services
import qs.config
import Quickshell
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

ColumnLayout {
    id: root

    required property var configObject
    required property var propertyData
    required property var sectionPath

    readonly property var nestedPath: sectionPath.concat([propertyData.name])
    property var arrayData: configObject[propertyData.name] ?? []
    readonly property string statePath: nestedPath.join(".")
    readonly property int nestingLevel: sectionPath.length - 1
    readonly property int leftIndent: nestingLevel * Appearance.padding.larger
    property bool expanded: ConfigParser.getExpandedState(statePath)

    // Detect if this is an array of objects (like warnLevels) or simple values
    readonly property bool isObjectArray: arrayData.length > 0 && typeof arrayData[0] === "object"
    readonly property bool isStringArray: arrayData.length > 0 && typeof arrayData[0] === "string"

    onExpandedChanged: ConfigParser.setExpandedState(statePath, expanded)

    Connections {
        target: ConfigParser
        function onValueChanged(path) {
            if (path.length >= root.nestedPath.length) {
                let isInScope = true;
                for (let i = 0; i < root.nestedPath.length; i++) {
                    if (path[i] !== root.nestedPath[i]) {
                        isInScope = false;
                        break;
                    }
                }
                if (isInScope) {
                    root.arrayData = root.configObject[root.propertyData.name] ?? [];
                }
            }
        }
    }

    spacing: 0

    // Header
    StyledRect {
        Layout.fillWidth: true
        Layout.leftMargin: root.leftIndent
        implicitHeight: 56

        color: root.expanded ? Qt.rgba(
            Colours.palette.m3tertiaryContainer.r,
            Colours.palette.m3tertiaryContainer.g,
            Colours.palette.m3tertiaryContainer.b,
            0.3
        ) : "transparent"
        radius: Appearance.rounding.normal

        StateLayer {
            radius: parent.radius
            function onClicked(): void {
                root.expanded = !root.expanded;
            }
        }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: Appearance.padding.normal
            anchors.rightMargin: Appearance.padding.normal
            spacing: Appearance.spacing.normal

            MaterialIcon {
                text: root.expanded ? "expand_more" : "chevron_right"
                color: Colours.palette.m3onSurface
                font.pointSize: Appearance.font.size.normal
            }

            StyledText {
                Layout.fillWidth: true
                text: ConfigParser.formatPropertyName(root.propertyData.name)
                font.pointSize: Appearance.font.size.normal
                color: Colours.palette.m3onSurface
            }

            // Array length badge
            StyledRect {
                Layout.preferredWidth: 32
                Layout.preferredHeight: 24
                color: Colours.palette.m3tertiaryContainer
                radius: 12

                StyledText {
                    anchors.centerIn: parent
                    text: root.arrayData.length.toString()
                    font.pointSize: Appearance.font.size.small
                    color: Colours.palette.m3onTertiaryContainer
                }
            }

            // Add button
            StyledRect {
                Layout.preferredWidth: 32
                Layout.preferredHeight: 32
                color: Colours.palette.m3primary
                radius: Appearance.rounding.full

                StateLayer {
                    radius: parent.radius
                    color: Colours.palette.m3onPrimary
                    function onClicked(): void {
                        addNewItem();
                    }
                }

                MaterialIcon {
                    anchors.centerIn: parent
                    text: "add"
                    font.pointSize: Appearance.font.size.normal
                    color: Colours.palette.m3onPrimary
                }
            }

            MaterialIcon {
                text: "data_array"
                color: Colours.palette.m3onSurfaceVariant
                font.pointSize: Appearance.font.size.normal
                opacity: 0.5
            }
        }
    }

    // Array items
    Item {
        Layout.fillWidth: true
        Layout.leftMargin: root.leftIndent + Appearance.padding.normal
        Layout.preferredHeight: arrayColumn.implicitHeight
        visible: root.expanded

        // Left border line
        Rectangle {
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.leftMargin: Appearance.padding.small
            width: 2
            color: Colours.palette.m3tertiary
            opacity: 0.3
            radius: 1
        }

        ColumnLayout {
            id: arrayColumn
            anchors.fill: parent
            anchors.leftMargin: Appearance.padding.normal
            spacing: Appearance.spacing.small

            Repeater {
                model: root.expanded ? root.arrayData : []

                delegate: Loader {
                    required property var modelData
                    required property int index

                    Layout.fillWidth: true

                    sourceComponent: root.isObjectArray ? objectItemComponent : 
                                    root.isStringArray ? stringItemComponent : 
                                    simpleItemComponent
                }
            }
        }
    }

    // Components for different array item types
    Component {
        id: objectItemComponent

        ArrayObjectItem {
            itemData: modelData
            itemIndex: index
            arrayPath: root.nestedPath
            onRemove: removeItem(index)
            onUpdate: (newData) => updateItem(index, newData)
        }
    }

    Component {
        id: stringItemComponent

        ArrayStringItem {
            value: modelData
            itemIndex: index
            onRemove: removeItem(index)
            onUpdate: (newValue) => updateItem(index, newValue)
        }
    }

    Component {
        id: simpleItemComponent

        ArraySimpleItem {
            value: modelData
            itemIndex: index
            onRemove: removeItem(index)
            onUpdate: (newValue) => updateItem(index, newValue)
        }
    }

    function addNewItem(): void {
        const newArray = Array.from(root.arrayData);
        if (root.isObjectArray && newArray.length > 0) {
            // Clone structure from first item
            const template = {};
            const firstItem = newArray[0];
            for (const key in firstItem) {
                if (typeof firstItem[key] === "boolean") template[key] = false;
                else if (typeof firstItem[key] === "number") template[key] = 0;
                else if (typeof firstItem[key] === "string") template[key] = "";
                else template[key] = firstItem[key];
            }
            newArray.push(template);
        } else if (root.isStringArray) {
            newArray.push("");
        } else {
            newArray.push("");
        }
        ConfigParser.updateValue(root.nestedPath, newArray);
    }

    function removeItem(index: int): void {
        const newArray = Array.from(root.arrayData);
        newArray.splice(index, 1);
        ConfigParser.updateValue(root.nestedPath, newArray);
    }

    function updateItem(index: int, value): void {
        const newArray = Array.from(root.arrayData);
        newArray[index] = value;
        ConfigParser.updateValue(root.nestedPath, newArray);
    }
}
