// niri-caelestia-sddm — Main.qml
// Faithful port of niri-caelestia-shell Center.qml / LockSurface.qml

import QtQuick
import QtQuick.Controls as Controls
import QtQuick.Layouts
import QtQuick.Effects
import SddmComponents
import "Components"

Rectangle {
    id: root
    width: Screen.width
    height: Screen.height

    // ── Theme Components ──────────────────────────────────────────────────
    Loader {
        id: paletteLoader
        source: "Components/Colors.qml"
        onLoaded: console.log("[sddm-caelestia] Palette loaded. Background color:", item.background)
    }
    Loader {
        id: settingsLoader
        source: "Components/Settings.qml"
    }

    readonly property var palette: paletteLoader.item
    readonly property var settings: settingsLoader.item

    // ── Material You color tokens ─────────────────────────────────────────
    readonly property color m3background: (palette && palette.background) || "#111118"
    readonly property color m3surface: (palette && palette.surface) || "#1c1b1f"
    readonly property color m3surfaceContainer: (palette && palette.surfaceContainer) || (palette && palette.surfaceVariant) || "#211f26"
    readonly property color m3surfaceContainerHigh: (palette && palette.surfaceContainerHigh) || (palette && palette.surfaceVariant) || "#2b2930"
    readonly property color m3surfaceContainerHighest: (palette && palette.surfaceContainerHighest) || (palette && palette.surfaceVariant) || "#36343b"
    readonly property color m3primary: (palette && palette.primary) || "#d0bcff"
    readonly property color m3onPrimary: (palette && palette.colPrimary) || "#21005d"
    readonly property color m3primaryContainer: (palette && palette.primaryContainer) || "#4f378b"
    readonly property color m3secondary: (palette && palette.secondary) || "#cbc2db"
    readonly property color m3secondaryContainer: (palette && palette.secondaryContainer) || (palette && palette.surfaceVariant) || "#4a4458"
    readonly property color m3onSecondaryContainer: (palette && (palette.colSecondaryContainer || palette.colSecondary)) || "#e8def8"
    readonly property color m3onSurface: (palette && palette.colSurface) || "#e6e1e5"
    readonly property color m3onSurfaceVariant: (palette && palette.colSurfaceVariant) || "#cac4d0"
    readonly property color m3outlineVariant: (palette && palette.outlineVariant) || "#49454f"
    readonly property color m3error: (palette && palette.error) || "#f2b8b5"
    readonly property color m3shadow: "#000000"

    // ── Config ────────────────────────────────────────────────────────────
    readonly property string rawWallpaperPath: (typeof config !== "undefined" && config.background) || ""
    readonly property string wallpaperPath: {
        let path = rawWallpaperPath;
        // Fallback to settings if theme.conf is empty
        if (path === "" && settings && settings.wallpaperPath) {
            path = settings.wallpaperPath;
        }
        
        if (path === "") return "";
        
        // Ensure absolute paths or URLs are handled
        if (path.indexOf("/") === 0 || path.indexOf("file://") === 0) {
            return (path.indexOf("file://") === 0) ? path : "file://" + path;
        }
        
        // Relative paths (like Backgrounds/wallpaper.jpg) need to be resolved
        return Qt.resolvedUrl(path);
    }

    onWallpaperPathChanged: console.log("[sddm-caelestia] Wallpaper path resolved to:", wallpaperPath)

    readonly property bool blurWallpaper: (settings && settings.blurWallpaper !== undefined) ? settings.blurWallpaper : true
    readonly property int blurRadius: (settings && settings.blurRadius) || 64
    readonly property real dimOpacity: (settings && settings.dimOpacity !== undefined) ? settings.dimOpacity : 0.20
    readonly property string fontClock: (settings && settings.clockFontFamily) || "Rubik"
    readonly property string fontUi: (settings && settings.uiFontFamily) || "Rubik"
    readonly property string fontMono: (settings && settings.monoFontFamily) || "JetBrains Mono Nerd Font"
    readonly property bool showAvatar: (settings && settings.showAvatars !== undefined) ? settings.showAvatars : true
    readonly property int animMs: (settings && settings.animDuration) || 300

    // Derived sizing
    readonly property real panelScale: Math.min(1.0, root.height / 1080)
    readonly property int panelWidth: Math.round(420 * panelScale)
    readonly property int panelHeight: Math.round(600 * panelScale)
    readonly property int panelRadius: Math.round(37.5 * panelScale)

    // ── PillComboBox Component ───────────────────────────────────────────
    component PillComboBox: Controls.ComboBox {
        id: cb
        implicitHeight: 32
        font.family: root.fontUi
        font.pixelSize: 12

        delegate: Controls.ItemDelegate {
            width: cb.width
            contentItem: Text {
                text: cb.textRole ? (Array.isArray(cb.model) ? modelData[cb.textRole] : (model ? model[cb.textRole] : "")) : modelData
                color: root.m3onSurface
                font: cb.font
                elide: Text.ElideRight
                verticalAlignment: Text.AlignVCenter
            }
            background: Rectangle {
                color: hovered ? Qt.rgba(root.m3primary.r, root.m3primary.g, root.m3primary.b, 0.15) : "transparent"
                radius: 6
            }
        }

        indicator: Text {
            x: cb.width - width - 8
            y: cb.topPadding + (cb.availableHeight - height) / 2
            text: "\ue5cf"
            font {
                family: "Material Symbols Rounded"
                pixelSize: 18
            }
            color: root.m3onSurfaceVariant
        }

        contentItem: Text {
            leftPadding: 12
            rightPadding: cb.indicator.width + 16
            text: cb.displayText
            font: cb.font
            color: root.m3onSurface
            verticalAlignment: Text.AlignVCenter
            elide: Text.ElideRight
        }

        background: Rectangle {
            implicitWidth: 120
            color: "transparent"
        }

        popup: Controls.Popup {
            y: -height - 8
            width: cb.width + 40
            padding: 6
            contentItem: ListView {
                clip: true
                implicitHeight: contentHeight
                model: cb.popup.visible ? cb.delegateModel : null
                currentIndex: cb.highlightedIndex
                Controls.ScrollBar.vertical: Controls.ScrollBar { }
            }
            background: Rectangle {
                color: Qt.rgba(root.m3surfaceContainerHigh.r, root.m3surfaceContainerHigh.g, root.m3surfaceContainerHigh.b, 0.97)
                radius: 12
                border {
                    width: 1
                    color: Qt.rgba(root.m3outlineVariant.r, root.m3outlineVariant.g, root.m3outlineVariant.b, 0.40)
                }
            }
        }
    }

    // ── InputField Component (Animated Dots) ─────────────────────────────
    component DotInput: Item {
        id: dotInputRoot
        property string inputText: ""
        Layout.fillWidth: true
        Layout.fillHeight: true
        clip: true

        Text {
            id: placeholder
            anchors.centerIn: parent
            text: root.loggingIn ? "Loading..." : "Password"
            color: root.loggingIn ? root.m3secondary : root.m3onSurfaceVariant
            font {
                family: root.fontMono
                pixelSize: Math.round(11 * root.panelScale)
            }
            opacity: dotInputRoot.inputText === "" ? 1 : 0
            Behavior on opacity {
                NumberAnimation {
                    duration: 200
                }
            }
        }

        ListView {
            id: charList
            anchors.centerIn: parent
            orientation: Qt.Horizontal
            spacing: Math.round(4 * root.panelScale)
            interactive: false
            model: dotInputRoot.inputText.length
            implicitHeight: Math.round(15 * root.panelScale)
            implicitWidth: count * (implicitHeight + spacing) - spacing

            delegate: Rectangle {
                width: charList.implicitHeight
                height: charList.implicitHeight
                radius: width / 4
                color: root.m3onSurface
                scale: 0
                opacity: 0
                Component.onCompleted: {
                    scale = 1
                    opacity = 1
                }
                Behavior on scale {
                    NumberAnimation {
                        duration: 200
                        easing.type: Easing.OutBack
                    }
                }
                Behavior on opacity {
                    NumberAnimation {
                        duration: 200
                    }
                }
            }
            Behavior on implicitWidth {
                NumberAnimation {
                    duration: 200
                    easing.type: Easing.OutCubic
                }
            }
        }
    }

    // ── Auth state ────────────────────────────────────────────────────────
    property bool authFailed: false
    property bool loggingIn: false
    property string statusMsg: ""

    color: m3background

    // ═══════════════════════════════════════════════════════════════════════
    // BACKGROUND LAYERS
    // ═══════════════════════════════════════════════════════════════════════

    Rectangle {
        anchors.fill: parent
        color: root.m3surface
    }

    Image {
        id: wallImg
        anchors.fill: parent
        source: wallpaperPath
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        cache: false
        visible: false
        onStatusChanged: {
            if (status === Image.Ready) console.log("[sddm-caelestia] Wallpaper loaded successfully")
            else if (status === Image.Error) console.warn("[sddm-caelestia] Failed to load wallpaper from:", source)
        }
    }

    MultiEffect {
        source: wallImg
        anchors.fill: parent
        visible: wallImg.status === Image.Ready
        blurEnabled: blurWallpaper
        blur: 1.0
        blurMax: blurRadius
    }

    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, dimOpacity)
    }

    // ═══════════════════════════════════════════════════════════════════════
    // AUTH LOGIC
    // ═══════════════════════════════════════════════════════════════════════

    Connections {
        target: (typeof sddm !== "undefined") ? sddm : null
        function onLoginFailed() {
            root.authFailed = true
            root.loggingIn = false
            root.statusMsg = "Incorrect password. Please try again."
            pwInput.text = ""
            failTimer.restart()
        }
        function onLoginSucceeded() {
            root.authFailed = false
            root.loggingIn = false
        }
    }

    Timer {
        id: failTimer
        interval: 4000
        onTriggered: {
            root.authFailed = false
            root.statusMsg = ""
        }
    }

    function doLogin() {
        if (pwInput.text.length === 0 || root.loggingIn) return
        root.loggingIn = true
        var u = (typeof userModel !== "undefined" && userModel.lastUser !== "") ? userModel.lastUser : "user"
        if (typeof sddm !== "undefined") {
            sddm.login(u, pwInput.text, (typeof sessionModel !== "undefined" ? sessionModel.lastIndex : 0))
        }
    }

    // ═══════════════════════════════════════════════════════════════════════
    // FLOATING CARD
    // ═══════════════════════════════════════════════════════════════════════

    Item {
        id: lockContent
        anchors.centerIn: parent
        width: root.panelWidth
        height: root.panelHeight
        scale: 0.88
        opacity: 0.0
        Component.onCompleted: cardEntryAnim.start()
        ParallelAnimation {
            id: cardEntryAnim
            NumberAnimation {
                target: lockContent
                property: "opacity"
                from: 0.0
                to: 1.0
                duration: root.animMs * 2
                easing.type: Easing.OutCubic
            }
            NumberAnimation {
                target: lockContent
                property: "scale"
                from: 0.88
                to: 1.0
                duration: root.animMs * 2
                easing.type: Easing.OutBack
            }
        }

        Rectangle {
            id: lockBg
            anchors.fill: parent
            radius: root.panelRadius
            color: root.m3surfaceContainer
            layer.enabled: true
            layer.effect: MultiEffect {
                shadowEnabled: true
                blurMax: 36
                shadowVerticalOffset: 8
                shadowBlur: 0.7
                shadowColor: Qt.rgba(0, 0, 0, 0.45)
            }
        }

        Rectangle {
            anchors.fill: parent
            radius: root.panelRadius
            color: "transparent"
            border {
                width: 1
                color: Qt.rgba(root.m3outlineVariant.r, root.m3outlineVariant.g, root.m3outlineVariant.b, 0.50)
            }
        }

        ColumnLayout {
            id: centerCol
            anchors {
                fill: parent
                margins: Math.round(15 * root.panelScale)
            }
            spacing: 0

            Item {
                Layout.fillHeight: true
                Layout.preferredHeight: 1
            }

            // ── CLOCK ──────────────────────────────────────────────────────
            Item {
                Layout.fillWidth: true
                Layout.bottomMargin: Math.round(4 * root.panelScale)
                implicitHeight: clockRow.implicitHeight
                Timer {
                    interval: 1000
                    repeat: true
                    running: true
                    triggeredOnStart: true
                    onTriggered: {
                        var n = new Date()
                        clockHours.text = Qt.formatTime(n, "hh")
                        clockMinutes.text = Qt.formatTime(n, "mm")
                        clockDate.text = Qt.formatDate(n, "dddd, d MMMM yyyy")
                        colonText.opacity = 1.0
                        colonFade.restart()
                    }
                }
                Row {
                    id: clockRow
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: Math.round(2 * root.panelScale)
                    Text {
                        id: clockHours
                        font {
                            family: root.fontClock
                            pixelSize: Math.round(82 * root.panelScale)
                            weight: Font.Bold
                        }
                        color: root.m3onSurface
                    }
                    Text {
                        id: colonText
                        text: ":"
                        font {
                            family: root.fontClock
                            pixelSize: Math.round(82 * root.panelScale)
                            weight: Font.Bold
                        }
                        color: root.m3primary
                        SequentialAnimation {
                            id: colonFade
                            PauseAnimation { duration: 300 }
                            NumberAnimation { target: colonText; property: "opacity"; to: 0.25; duration: 300 }
                            PauseAnimation { duration: 100 }
                            NumberAnimation { target: colonText; property: "opacity"; to: 1.0; duration: 300 }
                        }
                    }
                    Text {
                        id: clockMinutes
                        font {
                            family: root.fontClock
                            pixelSize: Math.round(82 * root.panelScale)
                            weight: Font.Bold
                        }
                        color: root.m3onSurface
                    }
                }
            }

            Text {
                id: clockDate
                Layout.alignment: Qt.AlignHCenter
                Layout.topMargin: Math.round(4 * root.panelScale)
                font {
                    family: root.fontMono
                    pixelSize: Math.round(13 * root.panelScale)
                    letterSpacing: 0.5
                }
                color: root.m3onSurfaceVariant
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.margins: Math.round(16 * root.panelScale)
                Layout.leftMargin: Math.round(20 * root.panelScale)
                Layout.rightMargin: Math.round(20 * root.panelScale)
                height: 1
                color: "transparent"
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0.00; color: "transparent" }
                    GradientStop { position: 0.15; color: Qt.rgba(root.m3outlineVariant.r, root.m3outlineVariant.g, root.m3outlineVariant.b, 0.60) }
                    GradientStop { position: 0.85; color: Qt.rgba(root.m3outlineVariant.r, root.m3outlineVariant.g, root.m3outlineVariant.b, 0.60) }
                    GradientStop { position: 1.00; color: "transparent" }
                }
            }

            // ── AVATAR ─────────────────────────────────────────────────────
            Item {
                Layout.alignment: Qt.AlignHCenter
                Layout.topMargin: Math.round(8 * root.panelScale)
                implicitWidth: avatarSize
                implicitHeight: avatarSize
                visible: root.showAvatar
                readonly property int avatarSize: Math.round(96 * root.panelScale)
                Rectangle {
                    anchors.fill: parent
                    radius: width / 2
                    color: Qt.rgba(root.m3secondaryContainer.r, root.m3secondaryContainer.g, root.m3secondaryContainer.b, 0.55)
                }
                Rectangle {
                    anchors {
                        fill: parent
                        margins: -3
                    }
                    radius: width / 2
                    color: "transparent"
                    border {
                        width: 2
                        color: Qt.rgba(root.m3primary.r, root.m3primary.g, root.m3primary.b, 0.45)
                    }
                }
                Rectangle {
                    anchors.fill: parent
                    radius: width / 2
                    clip: true
                    color: "transparent"
                    Image {
                        id: faceImg
                        anchors.fill: parent
                        source: (typeof userModel !== "undefined" && userModel.lastUser !== "") ? "file:///home/" + userModel.lastUser + "/.face" : ""
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        visible: status === Image.Ready
                    }
                    Text {
                        anchors.centerIn: parent
                        visible: faceImg.status !== Image.Ready
                        text: "\uE7FD"
                        font {
                            family: "Material Symbols Rounded"
                            pixelSize: Math.round(parent.width * 0.50)
                        }
                        color: root.m3onSurfaceVariant
                    }
                }
            }

            Text {
                Layout.alignment: Qt.AlignHCenter
                Layout.topMargin: Math.round(8 * root.panelScale)
                text: (typeof userModel !== "undefined" && userModel.lastUser !== "") ? userModel.lastUser : "user"
                font {
                    family: root.fontMono
                    pixelSize: Math.round(13 * root.panelScale)
                    weight: Font.Medium
                }
                color: root.m3onSurfaceVariant
            }

            // ── PASSWORD INPUT BAR ─────────────────────────────────────────
            Rectangle {
                id: inputBar
                Layout.fillWidth: true
                Layout.topMargin: Math.round(12 * root.panelScale)
                Layout.leftMargin: Math.round(15 * root.panelScale)
                Layout.rightMargin: Math.round(15 * root.panelScale)
                implicitHeight: Math.round(52 * root.panelScale)
                radius: implicitHeight / 2
                color: Qt.rgba(root.m3surfaceContainerHigh.r, root.m3surfaceContainerHigh.g, root.m3surfaceContainerHigh.b, 0.75)
                border {
                    width: pwInput.activeFocus ? 2 : 0
                    color: root.m3primary
                }
                Behavior on border.width {
                    NumberAnimation {
                        duration: 120
                    }
                }

                RowLayout {
                    anchors {
                        fill: parent
                        margins: Math.round(7 * root.panelScale)
                    }
                    spacing: Math.round(12 * root.panelScale)
                    Item {
                        Layout.alignment: Qt.AlignVCenter
                        implicitWidth: Math.round(36 * root.panelScale)
                        implicitHeight: Math.round(36 * root.panelScale)
                        Text {
                            anchors.centerIn: parent
                            text: root.authFailed ? "\uE899" : "\uE897"
                            font {
                                family: "Material Symbols Rounded"
                                pixelSize: Math.round(22 * root.panelScale)
                            }
                            color: root.authFailed ? root.m3error : (pwInput.activeFocus ? root.m3secondary : root.m3onSurfaceVariant)
                        }
                    }
                    DotInput {
                        id: dotInput
                        Layout.fillWidth: true
                        inputText: pwInput.text
                    }
                    Rectangle {
                        id: submitBtn
                        Layout.alignment: Qt.AlignVCenter
                        width: Math.round(34 * root.panelScale)
                        height: Math.round(34 * root.panelScale)
                        radius: width / 2
                        color: pwInput.text.length > 0 ? root.m3primary : Qt.rgba(root.m3surfaceContainerHigh.r, root.m3surfaceContainerHigh.g, root.m3surfaceContainerHigh.b, 0.80)
                        Text {
                            anchors.centerIn: parent
                            visible: !root.loggingIn
                            text: "\uE5C8"
                            font {
                                family: "Material Symbols Rounded"
                                pixelSize: Math.round(16 * root.panelScale)
                                weight: 500
                            }
                            color: pwInput.text.length > 0 ? root.m3onPrimary : root.m3onSurface
                        }
                        Controls.BusyIndicator {
                            anchors.centerIn: parent
                            visible: root.loggingIn
                            implicitWidth: Math.round(22 * root.panelScale)
                            implicitHeight: Math.round(22 * root.panelScale)
                        }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: doLogin()
                        }
                    }
                }
                Controls.TextField {
                    id: pwInput
                    anchors.fill: parent
                    opacity: 0
                    echoMode: TextInput.Password
                    focus: true
                    Keys.onReturnPressed: doLogin()
                    Keys.onEnterPressed: doLogin()
                    Component.onCompleted: forceActiveFocus()
                }
            }

            Item {
                Layout.fillWidth: true
                Layout.topMargin: Math.round(8 * root.panelScale)
                implicitHeight: Math.round(20 * root.panelScale)
                Text {
                    anchors.fill: parent
                    horizontalAlignment: Text.AlignHCenter
                    text: root.statusMsg
                    color: root.m3error
                    opacity: root.authFailed ? 1.0 : 0.0
                    font {
                        family: root.fontMono
                        pixelSize: Math.round(12 * root.panelScale)
                    }
                    Behavior on opacity {
                        NumberAnimation {
                            duration: 300
                        }
                    }
                }
            }
            Item {
                Layout.fillHeight: true
                Layout.preferredHeight: 2
            }
        }
    }

    // ═══════════════════════════════════════════════════════════════════════
    // BOTTOM BAR
    // ═══════════════════════════════════════════════════════════════════════

    Item {
        id: bottomBar
        anchors {
            left: parent.left
            right: parent.right
            bottom: parent.bottom
            bottomMargin: 24
        }
        height: 40
        opacity: 0
        Row {
            anchors {
                left: parent.left
                leftMargin: 32
                verticalCenter: parent.verticalCenter
            }
            spacing: 12
            Rectangle {
                height: 32
                radius: 16
                width: sessionCombo.width + 16
                color: root.m3surfaceContainer
                border {
                    width: 1
                    color: Qt.rgba(root.m3outlineVariant.r, root.m3outlineVariant.g, root.m3outlineVariant.b, 0.40)
                }
                PillComboBox {
                    id: sessionCombo
                    anchors.centerIn: parent
                    width: 148
                    model: (typeof sessionModel !== "undefined") ? sessionModel : []
                    currentIndex: (typeof sessionModel !== "undefined") ? sessionModel.lastIndex : 0
                    textRole: "name"
                    onActivated: {
                        if (typeof sessionModel !== "undefined") {
                            sessionModel.lastIndex = index
                        }
                    }
                }
            }
            Rectangle {
                height: 32
                radius: 16
                visible: (typeof keyboardModel !== "undefined") && keyboardModel.count > 0
                width: visible ? (keyboardCombo.width + 16) : 0
                color: root.m3surfaceContainer
                border {
                    width: 1
                    color: Qt.rgba(root.m3outlineVariant.r, root.m3outlineVariant.g, root.m3outlineVariant.b, 0.40)
                }
                PillComboBox {
                    id: keyboardCombo
                    anchors.centerIn: parent
                    width: 110
                    model: (typeof keyboardModel !== "undefined") ? keyboardModel : []
                    currentIndex: (typeof keyboardModel !== "undefined") ? keyboardModel.currentLayout : 0
                    textRole: "shortName"
                    onActivated: {
                        if (typeof keyboardModel !== "undefined") {
                            keyboardModel.currentLayout = index
                        }
                    }
                    indicator: Text {
                        x: keyboardCombo.width - width - 8
                        y: (keyboardCombo.availableHeight - height) / 2
                        text: "\ue312"
                        font {
                            family: "Material Symbols Rounded"
                            pixelSize: 18
                        }
                        color: root.m3onSurfaceVariant
                    }
                }
            }
        }

        Rectangle {
            anchors {
                right: parent.right
                rightMargin: 28
                verticalCenter: parent.verticalCenter
            }
            height: 32
            radius: 16
            width: 112
            color: root.m3surfaceContainer
            border {
                width: 1
                color: Qt.rgba(root.m3outlineVariant.r, root.m3outlineVariant.g, root.m3outlineVariant.b, 0.40)
            }
            Row {
                anchors.centerIn: parent
                spacing: 0
                Item {
                    width: 36
                    height: 32
                    Rectangle {
                        anchors.centerIn: parent
                        width: 26
                        height: 26
                        radius: 13
                        color: sMa.pressed ? Qt.rgba(root.m3primary.r, root.m3primary.g, root.m3primary.b, 0.28) : (sMa.containsMouse ? Qt.rgba(root.m3primary.r, root.m3primary.g, root.m3primary.b, 0.16) : "transparent")
                        Text {
                            anchors.centerIn: parent
                            text: "\uef44"
                            font {
                                family: "Material Symbols Rounded"
                                pixelSize: 15
                            }
                            color: sMa.containsMouse ? root.m3primary : root.m3onSurfaceVariant
                        }
                    }
                    MouseArea {
                        id: sMa
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: {
                            if (typeof sddm !== "undefined") {
                                sddm.suspend()
                            }
                        }
                    }
                }
                Item {
                    width: 36
                    height: 32
                    Rectangle {
                        anchors.centerIn: parent
                        width: 26
                        height: 26
                        radius: 13
                        color: rMa.pressed ? Qt.rgba(root.m3primary.r, root.m3primary.g, root.m3primary.b, 0.28) : (rMa.containsMouse ? Qt.rgba(root.m3primary.r, root.m3primary.g, root.m3primary.b, 0.16) : "transparent")
                        Text {
                            anchors.centerIn: parent
                            text: "\uf053"
                            font {
                                family: "Material Symbols Rounded"
                                pixelSize: 16
                            }
                            color: rMa.containsMouse ? root.m3primary : root.m3onSurfaceVariant
                        }
                    }
                    MouseArea {
                        id: rMa
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: {
                            if (typeof sddm !== "undefined") {
                                sddm.reboot()
                            }
                        }
                    }
                }
                Item {
                    width: 36
                    height: 32
                    Rectangle {
                        anchors.centerIn: parent
                        width: 26
                        height: 26
                        radius: 13
                        color: pMa.pressed ? Qt.rgba(root.m3error.r, root.m3error.g, root.m3error.b, 0.28) : (pMa.containsMouse ? Qt.rgba(root.m3error.r, root.m3error.g, root.m3error.b, 0.16) : "transparent")
                        Text {
                            anchors.centerIn: parent
                            text: "\ue8ac"
                            font {
                                family: "Material Symbols Rounded"
                                pixelSize: 16
                            }
                            color: pMa.containsMouse ? root.m3error : root.m3onSurfaceVariant
                        }
                    }
                    MouseArea {
                        id: pMa
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: {
                            if (typeof sddm !== "undefined") {
                                sddm.powerOff()
                            }
                        }
                    }
                }
            }
        }
        NumberAnimation {
            id: bottomBarFade
            target: bottomBar
            property: "opacity"
            to: 1
            duration: 900
            running: false
        }
        Component.onCompleted: {
            bottomBarFade.start()
        }
    }
}
