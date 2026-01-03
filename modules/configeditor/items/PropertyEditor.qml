import "../"
import qs.components
import qs.components.controls
import qs.services
import qs.config
import Quickshell
import QtQuick
import QtQuick.Layouts

// Reusable property editor that handles all types using Loader for dynamic components
Loader {
    id: root

    required property var configObject
    required property var propertyData
    required property var sectionPath

    Layout.fillWidth: true
    Layout.preferredHeight: item?.implicitHeight ?? 0

    // Detect special property types by name
    readonly property bool isIconProperty: {
        const name = propertyData?.name?.toLowerCase() ?? "";
        return name === "icon" || name.endsWith("icon") || name.includes("icon");
    }
    
    readonly property bool isFontProperty: {
        const name = propertyData?.name?.toLowerCase() ?? "";
        const path = sectionPath.concat([propertyData?.name ?? ""]).join(".").toLowerCase();
        return name === "font" || name.endsWith("font") || 
               path.includes("font.family") || path.includes("fontfamily");
    }

    sourceComponent: {
        if (!propertyData?.name || !ConfigParser.formatPropertyName(propertyData.name).trim()) {
            return null;
        }

        // Handle arrays
        if (propertyData?.type === "list<var>") {
            return arrayComponent;
        }

        // Handle special string types
        if (propertyData?.type === "string") {
            if (isIconProperty) return iconPickerComponent;
            if (isFontProperty) return fontPickerComponent;
            return stringComponent;
        }

        switch (propertyData?.type) {
            case "bool": return boolComponent;
            case "int":
            case "real": return numberComponent;
            case "object": return objectComponent;
            default: return null;
        }
    }

    Component {
        id: boolComponent

        BoolConfigItem {
            configObject: root.configObject
            propertyData: root.propertyData
            sectionPath: root.sectionPath
        }
    }

    Component {
        id: stringComponent

        StringConfigItem {
            configObject: root.configObject
            propertyData: root.propertyData
            sectionPath: root.sectionPath
        }
    }

    Component {
        id: numberComponent

        NumberConfigItem {
            configObject: root.configObject
            propertyData: root.propertyData
            sectionPath: root.sectionPath
        }
    }

    Component {
        id: objectComponent

        Loader {
            id: objectLoader

            Component.onCompleted: {
                setSource("ObjectHeader.qml", {
                    "configObject": root.configObject,
                    "propertyData": root.propertyData,
                    "sectionPath": root.sectionPath
                });
            }
        }
    }

    Component {
        id: arrayComponent

        ArrayConfigItem {
            configObject: root.configObject
            propertyData: root.propertyData
            sectionPath: root.sectionPath
        }
    }

    Component {
        id: iconPickerComponent

        IconPickerItem {
            configObject: root.configObject
            propertyData: root.propertyData
            sectionPath: root.sectionPath
        }
    }

    Component {
        id: fontPickerComponent

        FontPickerItem {
            configObject: root.configObject
            propertyData: root.propertyData
            sectionPath: root.sectionPath
        }
    }
}
