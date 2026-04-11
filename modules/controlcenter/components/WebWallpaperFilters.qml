pragma ComponentBehavior: Bound

import "../../../components"
import qs.components
import qs.components.controls
import qs.config
import qs.services
import Caelestia
import QtQuick
import QtQuick.Layouts

SectionContainer {
    id: root
    
    // The main grid component to sync properties with
    required property var gridRoot
    
    contentSpacing: Appearance.spacing.md

    RowLayout {
        spacing: Appearance.spacing.md
        Layout.fillWidth: true
        z: 1 

        // Server Selection Toggle
        IconTextButton {
            id: serverButton
            Layout.preferredWidth: 140
            Layout.preferredHeight: 40
            text: gridRoot.currentServer === "uhdpaper" ? "UHDpaper" : "Wallhaven"
            icon: gridRoot.currentServer === "uhdpaper" ? "cloud" : "explore"
            type: IconTextButton.Tonal
            onClicked: {
                gridRoot.currentServer = (gridRoot.currentServer === "uhdpaper" ? "wallhaven" : "uhdpaper");
                gridRoot.keyword = "";
                searchField.text = "";
                if (gridRoot.currentServer === "uhdpaper") {
                    gridRoot.resolution = "2k";
                    gridRoot.fetchCategories();
                } else {
                    gridRoot.resolution = "1920x1080";
                    gridRoot.categoriesList = [];
                }
                gridRoot.fetchWallpapers();
            }
            Tooltip { target: serverButton; text: qsTr("Click to switch server") }
        }

        StyledTextField {
            id: searchField
            Layout.fillWidth: true
            placeholderText: qsTr("Search wallpapers...")
            text: gridRoot.keyword
            onTextChanged: gridRoot.keyword = text
            onAccepted: gridRoot.fetchWallpapers()
        }

        IconButton {
            id: searchButton
            icon: "search"
            onClicked: gridRoot.fetchWallpapers()
            enabled: !gridRoot.loading
            Tooltip { target: searchButton; text: qsTr("Search") }
        }
        
        IconButton {
            id: randomButton
            icon: "casino"
            onClicked: {
                searchField.text = "";
                gridRoot.keyword = "";
                gridRoot.fetchWallpapers();
            }
            enabled: !gridRoot.loading
            Tooltip { target: randomButton; text: qsTr("Random") }
        }
    }

    // Categories Chips (UHDpaper)
    Flow {
        Layout.fillWidth: true
        Layout.topMargin: Appearance.spacing.xs
        Layout.bottomMargin: Appearance.spacing.xs
        spacing: Appearance.spacing.sm
        visible: gridRoot.categoriesList.length > 0 && gridRoot.currentServer === "uhdpaper"

        Repeater {
            model: gridRoot.categoriesList
            delegate: TextButton {
                required property var modelData
                text: modelData.name.charAt(0).toUpperCase() + modelData.name.slice(1)
                checked: gridRoot.keyword.toLowerCase() === modelData.name.toLowerCase()
                onClicked: {
                    gridRoot.keyword = modelData.name;
                    searchField.text = modelData.name;
                    gridRoot.fetchWallpapers();
                }
                type: checked ? TextButton.Filled : TextButton.Tonal
                font.pointSize: Appearance.font.size.labelLarge
            }
        }
    }

    // Wallhaven specific filters
    ColumnLayout {
        Layout.fillWidth: true
        Layout.topMargin: Appearance.spacing.sm
        spacing: Appearance.spacing.md
        visible: gridRoot.currentServer === "wallhaven"

        RowLayout {
            Layout.fillWidth: true
            spacing: Appearance.spacing.xxl

            // Categories
            ColumnLayout {
                spacing: Appearance.spacing.xs
                Layout.alignment: Qt.AlignTop
                StyledText {
                    text: qsTr("Categories")
                    font.pointSize: Appearance.font.size.labelLarge
                    font.weight: 600
                    color: Colours.palette.m3primary
                }
                RowLayout {
                    spacing: Appearance.spacing.xs
                    Repeater {
                        model: ["General", "Anime", "People"]
                        delegate: TextButton {
                            required property var modelData
                            text: modelData
                            checked: gridRoot.wallhavenCategories.indexOf(modelData.toLowerCase()) !== -1
                            onClicked: {
                                let cat = modelData.toLowerCase();
                                let list = [];
                                for(let i=0; i<gridRoot.wallhavenCategories.length; i++) list.push(gridRoot.wallhavenCategories[i]);
                                let idx = list.indexOf(cat);
                                if (idx === -1) list.push(cat);
                                else if (list.length > 1) list.splice(idx, 1);
                                gridRoot.wallhavenCategories = list;
                                gridRoot.fetchWallpapers();
                            }
                            type: checked ? TextButton.Filled : TextButton.Tonal
                            font.pointSize: Appearance.font.size.labelMedium
                        }
                    }
                }
            }

            // Purity
            ColumnLayout {
                spacing: Appearance.spacing.xs
                Layout.alignment: Qt.AlignTop
                StyledText {
                    text: qsTr("Purity")
                    font.pointSize: Appearance.font.size.labelLarge
                    font.weight: 600
                    color: Colours.palette.m3primary
                }
                RowLayout {
                    spacing: Appearance.spacing.xs
                    Repeater {
                        model: gridRoot.wallhavenHasApiKey ? ["SFW", "Sketchy", "NSFW"] : ["SFW", "Sketchy"]
                        delegate: TextButton {

                            required property var modelData
                            text: modelData
                            checked: gridRoot.wallhavenPurity.indexOf(modelData.toLowerCase()) !== -1
                            onClicked: {
                                let p = modelData.toLowerCase();
                                let list = [];
                                for(let i=0; i<gridRoot.wallhavenPurity.length; i++) list.push(gridRoot.wallhavenPurity[i]);
                                let idx = list.indexOf(p);
                                if (idx === -1) list.push(p);
                                else if (list.length > 1) list.splice(idx, 1);
                                gridRoot.wallhavenPurity = list;
                                gridRoot.fetchWallpapers();
                            }
                            type: checked ? TextButton.Filled : TextButton.Tonal
                            font.pointSize: Appearance.font.size.labelMedium
                        }
                    }
                }
            }
        }

        // Sorting
        ColumnLayout {
            spacing: Appearance.spacing.xs
            StyledText {
                text: qsTr("Sorting")
                font.pointSize: Appearance.font.size.labelLarge
                font.weight: 600
                color: Colours.palette.m3primary
            }
            Flow {
                Layout.fillWidth: true
                spacing: Appearance.spacing.xs
                Repeater {
                    model: [
                        {label: qsTr("Added"), val: "date_added"},
                        {label: qsTr("Relevance"), val: "relevance"},
                        {label: qsTr("Random"), val: "random"},
                        {label: qsTr("Views"), val: "views"},
                        {label: qsTr("Favorites"), val: "favorites"},
                        {label: qsTr("Toplist"), val: "toplist"}
                    ]
                    delegate: TextButton {
                        required property var modelData
                        text: modelData.label
                        checked: gridRoot.wallhavenSort === modelData.val
                        onClicked: {
                            gridRoot.wallhavenSort = modelData.val;
                            gridRoot.fetchWallpapers();
                        }
                        type: checked ? TextButton.Filled : TextButton.Tonal
                        font.pointSize: Appearance.font.size.labelMedium
                    }
                }
            }
        }

        // Color Palette
        ColumnLayout {
            spacing: Appearance.spacing.xs
            StyledText {
                text: qsTr("Color")
                font.pointSize: Appearance.font.size.labelLarge
                font.weight: 600
                color: Colours.palette.m3primary
            }
            Flow {
                Layout.fillWidth: true
                spacing: Appearance.spacing.sm

                // Clear color button
                IconButton {
                    id: clearColorButton
                    icon: "format_color_reset"
                    type: IconButton.Tonal
                    checked: gridRoot.wallhavenColor === ""
                    onClicked: {
                        gridRoot.wallhavenColor = "";
                        gridRoot.fetchWallpapers();
                    }
                    Tooltip { target: clearColorButton; text: qsTr("Clear color filter") }
                }

                Repeater {
                    model: ["660000", "cc0000", "ea4c88", "993399", "0066cc", "0099ff", "66cccc", "77cc33", "669900", "ffff00", "ff9900", "ff6600", "000000", "999999", "ffffff", "424153"]
                    delegate: StyledRect {
                        required property var modelData
                        width: 28
                        height: 28
                        radius: Appearance.rounding.full
                        color: "#" + modelData
                        border.width: gridRoot.wallhavenColor === modelData ? 2 : 1
                        border.color: gridRoot.wallhavenColor === modelData ? Colours.palette.m3primary : Qt.alpha(Colours.palette.m3outline, 0.5)

                        StateLayer {
                            anchors.fill: parent
                            radius: parent.radius
                            onClicked: {
                                if (gridRoot.wallhavenColor === modelData) gridRoot.wallhavenColor = "";
                                else gridRoot.wallhavenColor = modelData;
                                gridRoot.fetchWallpapers();
                            }
                        }
                    }
                }
            }
        }
        // Toplist Range
        ColumnLayout {
            spacing: Appearance.spacing.xs
            visible: gridRoot.wallhavenSort === "toplist"
            StyledText {
                text: qsTr("Range")
                font.pointSize: Appearance.font.size.labelLarge
                font.weight: 600
                color: Colours.palette.m3primary
            }
            RowLayout {
                spacing: Appearance.spacing.xs
                Repeater {
                    model: ["1d", "1w", "1M", "3M", "1y"]
                    delegate: TextButton {
                        required property var modelData
                        text: modelData
                        checked: gridRoot.wallhavenRange === modelData
                        onClicked: {
                            gridRoot.wallhavenRange = modelData;
                            gridRoot.fetchWallpapers();
                        }
                        type: checked ? TextButton.Filled : TextButton.Tonal
                        font.pointSize: Appearance.font.size.labelMedium
                    }
                }
            }
        }

        // API Key Section
        ColumnLayout {
            Layout.fillWidth: true
            spacing: Appearance.spacing.xs

            IconTextButton {
                text: gridRoot.showApiKey ? qsTr("Hide API Settings") : qsTr("Configure API Key")
                icon: gridRoot.showApiKey ? "expand_less" : "key"
                type: IconTextButton.Text
                onClicked: gridRoot.showApiKey = !gridRoot.showApiKey
            }

            RowLayout {
                visible: gridRoot.showApiKey
                Layout.fillWidth: true
                spacing: Appearance.spacing.md
                
                StyledTextField {
                    id: apiKeyField
                    Layout.fillWidth: true
                    placeholderText: qsTr("Enter Wallhaven API Key...")
                    echoMode: TextInput.Password
                    onAccepted: {
                        if (text.trim() === "") return;
                        gridRoot.saveApiKey(text.trim());
                        text = "";
                    }
                }
                
                IconButton {
                    id: saveApiKeyButton
                    icon: "save"
                    onClicked: {
                        gridRoot.saveApiKey(apiKeyField.text.trim());
                        apiKeyField.text = "";
                    }
                    enabled: apiKeyField.text.trim() !== ""
                    Tooltip { target: saveApiKeyButton; text: qsTr("Verify & Save Key") }
                }

                IconButton {
                    id: deleteApiKeyButton
                    icon: "delete"
                    type: IconButton.Tonal
                    onClicked: gridRoot.clearApiKey()
                    Tooltip { target: deleteApiKeyButton; text: qsTr("Clear API Key") }
                }

            }
        }
    }

    RowLayout {
        Layout.fillWidth: true
        Layout.topMargin: Appearance.spacing.sm
        spacing: Appearance.spacing.xxl

        // Resolution
        ColumnLayout {
            spacing: Appearance.spacing.xs
            Layout.alignment: Qt.AlignTop
            StyledText {
                text: qsTr("Resolution")
                font.pointSize: Appearance.font.size.labelLarge
                font.weight: 600
                color: Colours.palette.m3primary
            }

            RowLayout {
                spacing: Appearance.spacing.xs
                Repeater {
                    model: gridRoot.currentServer === "uhdpaper" ? ["4k", "2k", "1080p"] : ["3840x2160", "2560x1440", "1920x1080"]
                    delegate: TextButton {
                        required property var modelData
                        text: gridRoot.currentServer === "uhdpaper" ? modelData.toUpperCase() : modelData
                        checked: gridRoot.resolution === modelData
                        onClicked: gridRoot.resolution = modelData
                        type: checked ? TextButton.Filled : TextButton.Tonal
                        font.pointSize: Appearance.font.size.labelMedium
                    }
                }
            }
        }
    }
}
