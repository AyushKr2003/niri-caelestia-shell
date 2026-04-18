pragma ComponentBehavior: Bound

import qs.components
import qs.components.controls
import qs.services
import qs.config
import qs.utils
import Caelestia
import Quickshell
import Quickshell.Io as Io
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id: root

    required property TextField search
    required property PersistentProperties visibilities

    readonly property var categoryData: [
        { id: "recent", name: qsTr("Recent"), icon: "history" },
        { id: "people", name: qsTr("People"), icon: "mood" },
        { id: "nature", name: qsTr("Nature"), icon: "park" },
        { id: "food", name: qsTr("Food"), icon: "fastfood" },
        { id: "activity", name: qsTr("Activities"), icon: "sports_esports" },
        { id: "travel", name: qsTr("Travel"), icon: "flight" },
        { id: "objects", name: qsTr("Objects"), icon: "lightbulb" },
        { id: "symbols", name: qsTr("Symbols"), icon: "category" },
        { id: "flags", name: qsTr("Flags"), icon: "flag" }
    ]

    property string currentCategory: "people"
    property int categoryIndex: 1
    
    onCategoryIndexChanged: {
        currentCategory = categoryData[categoryIndex].id;
        grid.currentIndex = -1; // Reset selection on category change
    }

    PersistentProperties {
        id: recentEmojis
        reloadableId: "launcher_recent_emojis"
        property string list: "[]"
    }

    function addRecent(emoji): void {
        let current = [];
        try {
            current = JSON.parse(recentEmojis.list);
            if (!Array.isArray(current)) current = [];
        } catch (e) {
            current = [];
        }
        
        const index = current.findIndex(e => e.emoji === emoji.emoji);
        if (index !== -1) current.splice(index, 1);
        current.unshift(emoji);
        if (current.length > 30) current = current.slice(0, 30);
        recentEmojis.list = JSON.stringify(current);
    }

    property var _allEmojis: []
    property var _emojisByCategory: ({})

    Io.FileView {
        id: emojiFile
        path: Paths.toLocalFile(Qt.resolvedUrl("../../assets/emoji.json"))
        
        onLoaded: {
            try {
                const data = JSON.parse(text());
                root._allEmojis = data;
                
                const byCat = {};
                for (const item of data) {
                    if (!byCat[item.category]) byCat[item.category] = [];
                    byCat[item.category].push(item);
                }
                root._emojisByCategory = byCat;
            } catch (e) {
                console.error("EmojiList: Failed to parse emoji.json:", e.message);
            }
        }
        
        onLoadFailed: err => {
            console.error("EmojiList: Failed to load emoji.json:", err);
        }
    }

    property var _filteredEmojis: {
        const query = root.search.text.slice(`${Config.launcher.actionPrefix}emoji `.length).toLowerCase();
        
        if (query === "") {
            if (currentCategory === "recent") {
                try {
                    const recent = JSON.parse(recentEmojis.list);
                    return Array.isArray(recent) ? recent : [];
                } catch (e) { return []; }
            }
            return _emojisByCategory[currentCategory] || [];
        }
        
        const results = _allEmojis.filter(e => 
            e.name.toLowerCase().includes(query) || 
            e.emoji.includes(query) ||
            (e.keywords && e.keywords.some(k => k.toLowerCase().includes(query)))
        );
        
        return results.filter((v, i, a) => a.findIndex(t => (t.emoji === v.emoji)) === i);
    }

    implicitWidth: Config.launcher.sizes.itemWidth
    implicitHeight: Config.launcher.maxShown * Config.launcher.sizes.itemHeight

    ColumnLayout {
        id: contentColumn
        anchors.fill: parent
        spacing: Appearance.spacing.md

        // Category Bar
        StyledRect {
            id: categoryHeader
            Layout.fillWidth: true
            Layout.preferredHeight: 64
            color: Colours.tPalette.m3surfaceContainerLow
            radius: Appearance.rounding.small
            visible: root.search.text.startsWith(`${Config.launcher.actionPrefix}emoji `) && root.search.text.length <= `${Config.launcher.actionPrefix}emoji `.length

            RowLayout {
                anchors.fill: parent
                anchors.margins: Appearance.padding.sm
                spacing: Appearance.spacing.xs

                Repeater {
                    model: root.categoryData
                    delegate: Item {
                        id: catBtn
                        Layout.fillWidth: true
                        Layout.fillHeight: true

                        required property var modelData
                        required property int index
                        readonly property bool active: root.currentCategory === modelData.id
                        readonly property bool hovered: catStateLayer.containsMouse

                        // Background highlight on hover
                        StyledRect {
                            anchors.fill: parent
                            anchors.margins: 4
                            radius: Appearance.rounding.small
                            color: Colours.palette.m3onSurface
                            opacity: catBtn.hovered ? 0.08 : 0
                            Behavior on opacity { Anim { duration: Appearance.anim.durations.small } }
                        }

                        StateLayer {
                            id: catStateLayer
                            radius: Appearance.rounding.small
                            onClicked: {
                                root.categoryIndex = index;
                            }
                        }

                        MaterialIcon {
                            anchors.centerIn: parent
                            anchors.verticalCenterOffset: catBtn.active ? -2 : 0
                            text: modelData.icon ?? ""
                            color: catBtn.active ? Colours.palette.m3primary : (catBtn.hovered ? Colours.palette.m3onSurface : Colours.palette.m3onSurfaceVariant)
                            font.pointSize: Appearance.font.size.titleMedium
                            
                            Behavior on color { CAnim {} }
                            Behavior on anchors.verticalCenterOffset { Anim { duration: Appearance.anim.durations.small } }
                        }

                        // Selection Indicator (Tab look)
                        Rectangle {
                            anchors.bottom: parent.bottom
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: catBtn.active ? parent.width : 0
                            height: 2
                            color: Colours.palette.m3primary
                            opacity: catBtn.active ? 1 : 0

                            Behavior on width { Anim { duration: Appearance.anim.durations.normal; easing.bezierCurve: Appearance.anim.curves.emphasized } }
                            Behavior on opacity { Anim { duration: Appearance.anim.durations.normal } }
                        }


                        Tooltip {
                            target: catBtn
                            text: modelData.name ?? ""
                            visible: catBtn.hovered
                        }
                    }
                }
            }
        }
        
        // Search Header
        StyledRect {
            Layout.fillWidth: true
            Layout.preferredHeight: 40
            color: "transparent"
            visible: !categoryHeader.visible
            
            StyledText {
                anchors.left: parent.left
                anchors.leftMargin: Appearance.padding.md
                anchors.verticalCenter: parent.verticalCenter
                text: qsTr("Search Results")
                font.pointSize: Appearance.font.size.labelLarge
                font.weight: 600
                color: Colours.palette.m3primary
            }
        }

        // Main Grid Area
        StyledRect {
            Layout.fillWidth: true
            Layout.fillHeight: true
            color: Colours.tPalette.m3surfaceContainer
            radius: Appearance.rounding.small
            clip: true

            GridView {
                id: grid
                anchors.fill: parent
                anchors.margins: Appearance.padding.sm
                cellWidth: width / 6
                cellHeight: cellWidth
                model: root._filteredEmojis
                
                currentIndex: -1
                
                highlightMoveDuration: Appearance.anim.durations.normal

                highlight: Rectangle {
                    radius: Appearance.rounding.small
                    color: Qt.alpha(Colours.palette.m3primary, 0.12)
                    border.width: 2
                    border.color: Colours.palette.m3primary
                    z: -1
                    antialiasing: true
                }

                delegate: Item {
                    id: emojiItem
                    width: grid.cellWidth
                    height: grid.cellHeight

                    required property var modelData
                    required property int index
                    readonly property bool hovered: emojiStateLayer.containsMouse
                    readonly property bool isCurrent: grid.currentIndex === index

                    function onClicked(): void {
                        Quickshell.execDetached(["sh", "-c", "echo -n '" + (modelData?.emoji ?? "") + "' | wl-copy"]);
                        if (modelData) root.addRecent(modelData);
                        root.visibilities.launcher = false;
                    }

                    StateLayer {
                        id: emojiStateLayer
                        radius: Appearance.rounding.small
                        onClicked: {
                            emojiItem.onClicked();
                        }
                    }

                    Text {
                        anchors.centerIn: parent
                        text: modelData?.emoji ?? ""
                        font.pointSize: Appearance.font.size.headlineLarge
                        color: Colours.palette.m3onSurface
                        renderType: Text.QtRendering
                    }

                    Tooltip {
                        target: emojiItem
                        text: modelData?.name ?? ""
                        visible: emojiItem.hovered
                    }
                }

                ScrollBar.vertical: StyledScrollBar {}
                
                // No Results View
                ColumnLayout {
                    anchors.centerIn: parent
                    visible: grid.count === 0
                    spacing: Appearance.spacing.md
                    opacity: 0.6

                    MaterialIcon {
                        Layout.alignment: Qt.AlignHCenter
                        text: "sentiment_dissatisfied"
                        font.pointSize: 48
                        color: Colours.palette.m3onSurfaceVariant
                    }

                    StyledText {
                        Layout.alignment: Qt.AlignHCenter
                        text: qsTr("No emojis found")
                        color: Colours.palette.m3onSurfaceVariant
                        font.pointSize: Appearance.font.size.bodyMedium
                    }
                }
            }
        }

        // Preview Footer
        StyledRect {
            id: footer
            Layout.fillWidth: true
            Layout.preferredHeight: 64
            color: Colours.tPalette.m3surfaceContainerLow
            radius: Appearance.rounding.small
            
            readonly property var activeEmoji: {
                if (grid.currentIndex !== -1 && grid.model && grid.model[grid.currentIndex]) 
                    return grid.model[grid.currentIndex];
                return null;
            }

            RowLayout {
                anchors.fill: parent
                anchors.margins: Appearance.padding.md
                spacing: Appearance.padding.lg

                Text {
                    text: footer.activeEmoji?.emoji ?? "✨"
                    font.pointSize: 24
                    color: Colours.palette.m3onSurface
                    opacity: footer.activeEmoji ? 1 : 0.3
                    renderType: Text.QtRendering
                    Behavior on opacity { Anim { duration: Appearance.anim.durations.small } }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0

                    StyledText {
                        Layout.fillWidth: true
                        text: footer.activeEmoji?.name ?? qsTr("Select an emoji")
                        font.pointSize: Appearance.font.size.labelLarge
                        font.weight: 600
                        color: Colours.palette.m3onSurface
                        elide: Text.ElideRight
                        textFormat: Text.PlainText
                    }

                    StyledText {
                        Layout.fillWidth: true
                        text: (footer.activeEmoji?.keywords ?? []).join(", ")
                        font.pointSize: Appearance.font.size.labelSmall
                        color: Colours.palette.m3onSurfaceVariant
                        elide: Text.ElideRight
                        visible: text !== ""
                        textFormat: Text.PlainText
                    }
                }
                
                // Shortcut hints
                Row {
                    spacing: Appearance.spacing.md
                    opacity: 0.5
                    visible: categoryHeader.visible

                    Row {
                        spacing: 4
                        MaterialIcon { text: "keyboard_arrow_up"; font.pointSize: 12 }
                        StyledText { text: "PgUp"; font.pointSize: 10 }
                    }
                    Row {
                        spacing: 4
                        MaterialIcon { text: "keyboard_arrow_down"; font.pointSize: 12 }
                        StyledText { text: "PgDn"; font.pointSize: 10 }
                    }
                }
            }
        }
    }

    // Navigation for keyboard
    function incrementCurrentIndex(): void { 
        if (grid.currentIndex === -1) grid.currentIndex = 0;
        else grid.moveCurrentIndexRight(); 
    }
    function decrementCurrentIndex(): void { 
        if (grid.currentIndex === -1) grid.currentIndex = 0;
        else grid.moveCurrentIndexLeft(); 
    }
    function moveUp(): void { 
        if (grid.currentIndex === -1) grid.currentIndex = 0;
        else grid.moveCurrentIndexUp(); 
    }
    function moveDown(): void { 
        if (grid.currentIndex === -1) grid.currentIndex = 0;
        else grid.moveCurrentIndexDown(); 
    }
    function moveLeft(): void { decrementCurrentIndex(); }
    function moveRight(): void { incrementCurrentIndex(); }
    
    function nextCategory(): void {
        root.categoryIndex = (root.categoryIndex + 1) % root.categoryData.length;
    }
    
    function prevCategory(): void {
        root.categoryIndex = (root.categoryIndex - 1 + root.categoryData.length) % root.categoryData.length;
    }

    readonly property alias currentItem: grid.currentItem
    readonly property alias count: grid.count
}
