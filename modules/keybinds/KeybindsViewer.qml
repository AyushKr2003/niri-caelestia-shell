import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

ApplicationWindow {
    id: window
    width: 700
    height: 800
    visible: true
    title: "Niri Keybinds Viewer"
    color: "#121212"

    ListModel { id: allKeybindsModel }
    ListModel { id: filteredModel }

    Component.onCompleted: loadKeybinds()

    function loadKeybinds() {
        allKeybindsModel.clear()
        filteredModel.clear()

        var xhr = new XMLHttpRequest()
        xhr.open("GET", Qt.resolvedUrl("keybinds.json") + "?t=" + Date.now())
        xhr.onreadystatechange = function () {
            if (xhr.readyState === XMLHttpRequest.DONE && xhr.status === 200) {
                var data = JSON.parse(xhr.responseText)
                for (var i = 0; i < data.length; i++) {
                    allKeybindsModel.append(data[i])
                }
                applyFilter()
            }
        }
        xhr.send()
    }

    function applyFilter() {
        filteredModel.clear()
        var q = searchField.text.toLowerCase()

        for (var i = 0; i < allKeybindsModel.count; i++) {
            var item = allKeybindsModel.get(i)
            if (
                q === "" ||
                item.key.toLowerCase().includes(q) ||
                item.action.toLowerCase().includes(q)
            ) {
                filteredModel.append(item)
            }
        }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 8

        Text {
            text: "Keybinds"
            font.pixelSize: 22
            font.bold: true
            color: "#ffffff"
            Layout.alignment: Qt.AlignHCenter
        }

        TextField {
            id: searchField
            placeholderText: "Search key or action…"
            Layout.fillWidth: true
            focus: true
            color: "#ffffff"
            background: Rectangle {
                color: "#1e1e1e"
                radius: 6
            }
            onTextChanged: applyFilter()
        }

        ListView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            model: filteredModel

            delegate: Rectangle {
                width: ListView.view.width
                height: 44
                radius: 6
                color: index % 2 === 0 ? "#1a1a1a" : "#161616"

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 10
                    spacing: 16

                    Text {
                        text: model.key
                        font.bold: true
                        color: "#9cdcfe"
                        Layout.preferredWidth: parent.width * 0.35
                        elide: Text.ElideRight
                    }

                    Text {
                        text: model.action
                        color: "#d4d4d4"
                        Layout.preferredWidth: parent.width * 0.6
                        elide: Text.ElideRight
                    }
                }
            }
        }
    }
}
