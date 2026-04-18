pragma ComponentBehavior: Bound

import "items"
import "services"
import qs.components
import qs.components.controls
import qs.components.containers
import qs.services
import qs.config
import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Controls

StyledListView {
    id: root

    required property TextField search
    required property PersistentProperties visibilities

    // Debounce search text to avoid re-filtering on every keystroke
    property string _debouncedText: search.text
    Timer {
        id: _searchDebounce
        interval: 120
        onTriggered: root._debouncedText = root.search.text
    }
    Connections {
        target: root.search
        function onTextChanged(): void {
            // Immediate update for short strings (mode detection), debounce for actual search
            if (root.search.text.length <= 1)
                root._debouncedText = root.search.text;
            else
                _searchDebounce.restart();
        }
    }

    // Clipboard data
    ListModel { id: clipboardModel }

    property var _clipFilteredValues: {
        const query = _debouncedText.slice(`${Config.launcher.actionPrefix}clip `.length).toLowerCase();
        let result = [];
        for (let i = 0; i < clipboardModel.count; i++) {
            const item = clipboardModel.get(i);
            if (query === "" || item.entryText.toLowerCase().includes(query)) {
                result.push({ entryId: item.entryId, entryText: item.entryText, isImage: item.isImage });
            }
        }
        return result;
    }

    Process {
        id: cliphistProc
        command: ["cliphist", "list"]
        stdout: StdioCollector {
            onStreamFinished: {
                clipboardModel.clear();
                const lines = text.trim().split("\n");
                for (const line of lines) {
                    if (!line) continue;
                    const parts = line.split("\t");
                    clipboardModel.append({
                        entryId: parts[0],
                        entryText: parts.slice(1).join("\t"),
                        isImage: line.includes("[[ binary data")
                    });
                }
            }
        }
    }

    function refreshClipboard(): void { cliphistProc.running = true; }

    function removeClipEntry(entryId: string): void {
        for (let i = 0; i < clipboardModel.count; i++) {
            if (clipboardModel.get(i).entryId === entryId) {
                clipboardModel.remove(i);
                break;
            }
        }
    }

    model: ScriptModel {
        id: model

        onValuesChanged: root.currentIndex = 0
    }

    spacing: Appearance.spacing.sm
    orientation: Qt.Vertical
    implicitHeight: {
        if (state === "emoji")
            return Math.min(Config.launcher.maxShown * Config.launcher.sizes.itemHeight, 400);
        return (Config.launcher.sizes.itemHeight + spacing) * Math.min(Config.launcher.maxShown, count) - spacing;
    }

    highlightMoveDuration: Appearance.anim.durations.normal
    highlightResizeDuration: 0

    highlight: StyledRect {
        radius: Appearance.rounding.small
        color: Colours.palette.m3onSurface
        opacity: 0.08
    }

    state: {
        const text = _debouncedText;
        const prefix = Config.launcher.actionPrefix;
        if (text.startsWith(prefix)) {
            for (const action of ["calc", "scheme", "variant", "clip", "emoji", "web"])
                if (text.startsWith(`${prefix}${action} `))
                    return action;

            return "actions";
        }

        return "apps";
    }

    onStateChanged: {
        if (state === "scheme" || state === "variant")
            Schemes.reload();
        if (state === "clip")
            refreshClipboard();
    }

    states: [
        State {
            name: "apps"

            PropertyChanges {
                model.values: Apps.search(root._debouncedText)
                root.delegate: appItem
            }
        },
        State {
            name: "actions"

            PropertyChanges {
                model.values: Actions.query(root._debouncedText)
                root.delegate: actionItem
            }
        },
        State {
            name: "calc"

            PropertyChanges {
                model.values: [0]
                root.delegate: calcItem
            }
        },
        State {
            name: "scheme"

            PropertyChanges {
                model.values: Schemes.query(root._debouncedText)
                root.delegate: schemeItem
            }
        },
        State {
            name: "variant"

            PropertyChanges {
                model.values: M3Variants.query(root._debouncedText)
                root.delegate: variantItem
            }
        },
        State {
            name: "clip"

            PropertyChanges {
                model.values: root._clipFilteredValues
                root.delegate: clipItem
            }
        },
        State {
            name: "emoji"

            PropertyChanges {
                model.values: [0]
                root.delegate: emojiItem
            }
        },
        State {
            name: "web"

            PropertyChanges {
                model.values: [0]
                root.delegate: webItem
            }
        }
    ]

    transitions: Transition {
        SequentialAnimation {
            ParallelAnimation {
                Anim {
                    target: root
                    property: "opacity"
                    from: 1
                    to: 0
                    duration: Appearance.anim.durations.small
                    easing.bezierCurve: Appearance.anim.curves.standardAccel
                }
                Anim {
                    target: root
                    property: "scale"
                    from: 1
                    to: 0.9
                    duration: Appearance.anim.durations.small
                    easing.bezierCurve: Appearance.anim.curves.standardAccel
                }
            }
            PropertyAction {
                targets: [model, root]
                properties: "values,delegate"
            }
            ParallelAnimation {
                Anim {
                    target: root
                    property: "opacity"
                    from: 0
                    to: 1
                    duration: Appearance.anim.durations.small
                    easing.bezierCurve: Appearance.anim.curves.standardDecel
                }
                Anim {
                    target: root
                    property: "scale"
                    from: 0.9
                    to: 1
                    duration: Appearance.anim.durations.small
                    easing.bezierCurve: Appearance.anim.curves.standardDecel
                }
            }
            PropertyAction {
                targets: [root.add, root.remove]
                property: "enabled"
                value: true
            }
        }
    }

    ScrollBar.vertical: StyledScrollBar {}

    add: Transition {
        enabled: !root.state

        Anim {
            properties: "opacity,scale"
            from: 0
            to: 1
        }
    }

    remove: Transition {
        enabled: !root.state

        Anim {
            properties: "opacity,scale"
            from: 1
            to: 0
        }
    }

    move: Transition {
        Anim {
            property: "y"
        }
        Anim {
            properties: "opacity,scale"
            to: 1
        }
    }

    addDisplaced: Transition {
        Anim {
            property: "y"
            duration: Appearance.anim.durations.small
        }
        Anim {
            properties: "opacity,scale"
            to: 1
        }
    }

    displaced: Transition {
        Anim {
            property: "y"
        }
        Anim {
            properties: "opacity,scale"
            to: 1
        }
    }

    Component {
        id: appItem

        AppItem {
            visibilities: root.visibilities
        }
    }

    Component {
        id: actionItem

        ActionItem {
            list: root
        }
    }

    Component {
        id: calcItem

        CalcItem {
            list: root
        }
    }

    Component {
        id: schemeItem

        SchemeItem {
            list: root
        }
    }

    Component {
        id: variantItem

        VariantItem {
            list: root
        }
    }

    Component {
        id: clipItem

        ClipItem {
            list: root
        }
    }

    Component {
        id: emojiItem

        EmojiList {
            search: root.search
            visibilities: root.visibilities
        }
    }

    Component {
        id: webItem

        WebItem {
            list: root
        }
    }
}
