pragma ComponentBehavior: Bound

import qs.components
import qs.components.effects
import qs.services
import qs.config
import qs.utils
import Quickshell
import Quickshell.Widgets
import Quickshell.Services.Notifications
import QtQuick
import QtQuick.Layouts

StyledRect {
    id: root

    required property Notifs.Notif modelData
    readonly property bool hasImage: modelData.image.length > 0
    readonly property bool hasAppIcon: modelData.appIcon.length > 0
    readonly property int nonAnimHeight: summary.implicitHeight + (root.expanded ? appName.height + body.height + actions.height + actions.anchors.topMargin : bodyPreview.height) + inner.anchors.margins * 2
    property bool expanded
    property bool pendingDismiss: false

    Timer {
        id: undoTimer
        interval: 3000
        onTriggered: Notifs.discardNotification(root.modelData.notificationId)
    }

    function startDismiss(): void {
        pendingDismiss = true;
        undoTimer.start();
    }

    function undoDismiss(): void {
        pendingDismiss = false;
        undoTimer.stop();
        root.x = 0;
    }

    color: root.modelData.urgency === NotificationUrgency.Critical ? Colours.palette.m3secondaryContainer : Colours.tPalette.m3surfaceContainer
    radius: Appearance.rounding.normal
    implicitWidth: Config.notifs.sizes.width
    implicitHeight: inner.implicitHeight

    property real animX: Config.notifs.sizes.width
    x: 0

    Component.onCompleted: animX = 0

    Behavior on animX {
        Anim {
            easing.bezierCurve: Appearance.anim.curves.emphasizedDecel
        }
    }

    transform: Translate {
        x: root.animX
    }

    RetainableLock {
        object: root.modelData.notification
        locked: true
    }

    MouseArea {
        property int startY

        anchors.fill: parent
        hoverEnabled: true
        cursorShape: root.expanded && body.hoveredLink ? Qt.PointingHandCursor : pressed ? Qt.ClosedHandCursor : undefined
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton
        preventStealing: true

        onEntered: root.modelData.timer?.stop()
        onExited: {
            if (!pressed)
                root.modelData.timer?.start();
        }

        drag.target: parent
        drag.axis: Drag.XAxis

        onPressed: event => {
            root.modelData.timer?.stop();
            startY = event.y;
            if (event.button === Qt.MiddleButton)
                Notifs.discardNotification(root.modelData.notificationId);
        }
        onReleased: event => {
            if (!containsMouse)
                root.modelData.timer?.start();

            if (Math.abs(root.x) < Config.notifs.sizes.width * Config.notifs.clearThreshold)
                root.x = 0;
            else
                root.startDismiss();
        }
        onPositionChanged: event => {
            if (pressed) {
                const diffY = event.y - startY;
                if (Math.abs(diffY) > Config.notifs.expandThreshold)
                    root.expanded = diffY > 0;
            }
        }
        onClicked: event => {
            if (!Config.notifs.actionOnClick || event.button !== Qt.LeftButton)
                return;

            const actions = root.modelData.actions;
            if (actions?.length === 1)
                Notifs.attemptInvokeAction(root.modelData.notificationId, actions[0].identifier);
        }

        Item {
            id: inner

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: Appearance.padding.md

            implicitHeight: root.nonAnimHeight

            Behavior on implicitHeight {
                Anim {
                    duration: Appearance.anim.durations.expressiveDefaultSpatial
                    easing.bezierCurve: Appearance.anim.curves.expressiveDefaultSpatial
                }
            }

            Loader {
                id: image

                active: root.hasImage
                asynchronous: true

                anchors.left: parent.left
                anchors.top: parent.top
                width: Config.notifs.sizes.image
                height: Config.notifs.sizes.image
                visible: root.hasImage || root.hasAppIcon

                sourceComponent: ClippingRectangle {
                    radius: Appearance.rounding.full
                    implicitWidth: Config.notifs.sizes.image
                    implicitHeight: Config.notifs.sizes.image

                    Image {
                        anchors.fill: parent
                        source: Qt.resolvedUrl(root.modelData.image)
                        fillMode: Image.PreserveAspectCrop
                        cache: false
                        asynchronous: true
                    }
                }
            }

            Loader {
                id: appIcon

                active: root.hasAppIcon || !root.hasImage
                asynchronous: true

                anchors.horizontalCenter: root.hasImage ? undefined : image.horizontalCenter
                anchors.verticalCenter: root.hasImage ? undefined : image.verticalCenter
                anchors.right: root.hasImage ? image.right : undefined
                anchors.bottom: root.hasImage ? image.bottom : undefined

                sourceComponent: StyledRect {
                    radius: Appearance.rounding.full
                    color: root.modelData.urgency === NotificationUrgency.Critical ? Colours.palette.m3error : root.modelData.urgency === NotificationUrgency.Low ? Colours.layer(Colours.palette.m3surfaceContainerHighest, 2) : Colours.palette.m3secondaryContainer
                    implicitWidth: root.hasImage ? Config.notifs.sizes.badge : Config.notifs.sizes.image
                    implicitHeight: root.hasImage ? Config.notifs.sizes.badge : Config.notifs.sizes.image

                    Loader {
                        id: icon

                        active: root.hasAppIcon
                        asynchronous: true

                        anchors.centerIn: parent

                        width: Math.round(parent.width * 0.6)
                        height: Math.round(parent.width * 0.6)

                        sourceComponent: ColouredIcon {
                            anchors.fill: parent
                            source: Quickshell.iconPath(root.modelData.appIcon)
                            colour: root.modelData.urgency === NotificationUrgency.Critical ? Colours.palette.m3onError : root.modelData.urgency === NotificationUrgency.Low ? Colours.palette.m3onSurface : Colours.palette.m3onSecondaryContainer
                            layer.enabled: root.modelData.appIcon.endsWith("symbolic")
                        }
                    }

                    Loader {
                        active: !root.hasAppIcon
                        asynchronous: true
                        anchors.centerIn: parent
                        anchors.horizontalCenterOffset: -Appearance.font.size.titleMedium * 0.02
                        anchors.verticalCenterOffset: Appearance.font.size.titleMedium * 0.02

                        sourceComponent: MaterialIcon {
                            text: Icons.getNotifIcon(root.modelData.summary, root.modelData.urgency)

                            color: root.modelData.urgency === NotificationUrgency.Critical ? Colours.palette.m3onError : root.modelData.urgency === NotificationUrgency.Low ? Colours.palette.m3onSurface : Colours.palette.m3onSecondaryContainer
                            font.pointSize: Appearance.font.size.titleMedium
                        }
                    }
                }
            }

            StyledText {
                id: appName

                anchors.top: parent.top
                anchors.left: image.right
                anchors.leftMargin: Appearance.spacing.md

                animate: true
                text: appNameMetrics.elidedText
                maximumLineCount: 1
                color: Colours.palette.m3onSurfaceVariant
                font.pointSize: Appearance.font.size.labelLarge

                opacity: root.expanded ? 1 : 0

                Behavior on opacity {
                    Anim {}
                }
            }

            TextMetrics {
                id: appNameMetrics

                text: root.modelData.appName
                font.family: appName.font.family
                font.pointSize: appName.font.pointSize
                elide: Text.ElideRight
                elideWidth: expandBtn.x - time.width - timeSep.width - summary.x - Appearance.spacing.sm * 3
            }

            StyledText {
                id: summary

                anchors.top: parent.top
                anchors.left: image.right
                anchors.leftMargin: Appearance.spacing.md

                animate: true
                text: summaryMetrics.elidedText
                maximumLineCount: 1
                height: implicitHeight

                states: State {
                    name: "expanded"
                    when: root.expanded

                    PropertyChanges {
                        summary.maximumLineCount: undefined
                    }

                    AnchorChanges {
                        target: summary
                        anchors.top: appName.bottom
                    }
                }

                transitions: Transition {
                    PropertyAction {
                        target: summary
                        property: "maximumLineCount"
                    }
                    AnchorAnimation {
                        duration: Appearance.anim.durations.normal
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: Appearance.anim.curves.standard
                    }
                }

                Behavior on height {
                    Anim {}
                }
            }

            TextMetrics {
                id: summaryMetrics

                text: root.modelData.summary
                font.family: summary.font.family
                font.pointSize: summary.font.pointSize
                elide: Text.ElideRight
                elideWidth: expandBtn.x - time.width - timeSep.width - summary.x - Appearance.spacing.sm * 3 - (primaryAction.visible && primaryAction.item ? primaryAction.item.width + Appearance.spacing.sm : 0)
            }

            StyledText {
                id: timeSep

                anchors.top: parent.top
                anchors.left: summary.right
                anchors.leftMargin: Appearance.spacing.sm

                text: "•"
                color: Colours.palette.m3onSurfaceVariant
                font.pointSize: Appearance.font.size.labelLarge

                states: State {
                    name: "expanded"
                    when: root.expanded

                    AnchorChanges {
                        target: timeSep
                        anchors.left: appName.right
                    }
                }

                transitions: Transition {
                    AnchorAnimation {
                        duration: Appearance.anim.durations.normal
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: Appearance.anim.curves.standard
                    }
                }
            }

            StyledText {
                id: time

                anchors.top: parent.top
                anchors.left: timeSep.right
                anchors.leftMargin: Appearance.spacing.sm

                animate: true
                horizontalAlignment: Text.AlignLeft
                text: root.modelData.timeStr
                color: Colours.palette.m3onSurfaceVariant
                font.pointSize: Appearance.font.size.labelLarge
            }

            Item {
                id: expandBtn

                anchors.right: parent.right
                anchors.top: parent.top

                implicitWidth: expandIcon.height
                implicitHeight: expandIcon.height

                StateLayer {
                    radius: Appearance.rounding.full
                    color: root.modelData.urgency === NotificationUrgency.Critical ? Colours.palette.m3onSecondaryContainer : Colours.palette.m3onSurface

                    function onClicked() {
                        root.expanded = !root.expanded;
                    }
                }

                MaterialIcon {
                    id: expandIcon

                    anchors.centerIn: parent

                    animate: true
                    text: root.expanded ? "expand_less" : "expand_more"
                    font.pointSize: Appearance.font.size.bodyMedium
                }
            }

            // Primary action inline (visible when collapsed and actions exist)
            Loader {
                id: primaryAction

                active: root.modelData.actions.length > 0
                visible: !root.expanded

                anchors.right: expandBtn.left
                anchors.top: parent.top
                anchors.rightMargin: Appearance.spacing.sm

                sourceComponent: StyledRect {
                    radius: Appearance.rounding.full
                    color: root.modelData.urgency === NotificationUrgency.Critical ? Colours.palette.m3secondary : Colours.layer(Colours.palette.m3surfaceContainerHigh, 2)
                    implicitWidth: primaryActionText.implicitWidth + Appearance.padding.sm * 2
                    implicitHeight: primaryActionText.implicitHeight + Appearance.padding.xs

                    StateLayer {
                        radius: Appearance.rounding.full
                        color: root.modelData.urgency === NotificationUrgency.Critical ? Colours.palette.m3onSecondary : Colours.palette.m3onSurface

                        function onClicked(): void {
                            Notifs.attemptInvokeAction(root.modelData.notificationId, root.modelData.actions[0].identifier);
                        }
                    }

                    StyledText {
                        id: primaryActionText
                        anchors.centerIn: parent
                        text: root.modelData.actions[0]?.text ?? ""
                        color: root.modelData.urgency === NotificationUrgency.Critical ? Colours.palette.m3onSecondary : Colours.palette.m3onSurfaceVariant
                        font.pointSize: Appearance.font.size.labelSmall
                        font.weight: Font.Medium
                    }
                }

                opacity: root.expanded ? 0 : 1
                Behavior on opacity {
                    Anim {}
                }
            }

            StyledText {
                id: bodyPreview

                anchors.left: summary.left
                anchors.right: expandBtn.left
                anchors.top: summary.bottom
                anchors.rightMargin: Appearance.spacing.sm

                animate: true
                textFormat: Text.MarkdownText
                text: bodyPreviewMetrics.elidedText
                color: Colours.palette.m3onSurfaceVariant
                font.pointSize: Appearance.font.size.labelLarge

                opacity: root.expanded ? 0 : 1

                Behavior on opacity {
                    Anim {}
                }
            }

            TextMetrics {
                id: bodyPreviewMetrics

                text: root.modelData.body
                font.family: bodyPreview.font.family
                font.pointSize: bodyPreview.font.pointSize
                elide: Text.ElideRight
                elideWidth: bodyPreview.width
            }

            StyledText {
                id: body

                anchors.left: summary.left
                anchors.right: expandBtn.left
                anchors.top: summary.bottom
                anchors.rightMargin: Appearance.spacing.sm

                animate: true
                textFormat: Text.MarkdownText
                text: root.modelData.body
                color: Colours.palette.m3onSurfaceVariant
                font.pointSize: Appearance.font.size.labelLarge
                wrapMode: Text.WrapAtWordBoundaryOrAnywhere
                height: text ? implicitHeight : 0

                onLinkActivated: link => {
                    if (!root.expanded)
                        return;

                    Quickshell.execDetached(["app2unit", "-O", "--", link]);
                    root.modelData.notification.dismiss(); // TODO: change back to popup when notif dock impled
                }

                opacity: root.expanded ? 1 : 0

                Behavior on opacity {
                    Anim {}
                }
            }

            RowLayout {
                id: actions

                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: body.bottom
                anchors.topMargin: Appearance.spacing.sm

                spacing: Appearance.spacing.md

                opacity: root.expanded ? 1 : 0

                Behavior on opacity {
                    Anim {}
                }

                Action {
                    modelData: QtObject {
                        readonly property string text: qsTr("Close")
                        readonly property string identifier: ""
                        function invoke(): void {
                            Notifs.discardNotification(root.modelData.notificationId);
                        }
                    }
                }

                Repeater {
                    model: root.modelData.actions

                    delegate: Component {
                        Action {}
                    }
                }
            }
        }
    }

    // Undo overlay — shown during pending dismiss
    Rectangle {
        anchors.fill: parent
        radius: root.radius
        color: Colours.palette.m3inverseSurface
        visible: root.pendingDismiss
        opacity: root.pendingDismiss ? 1 : 0

        Behavior on opacity {
            Anim {
                duration: Appearance.anim.durations.small
            }
        }

        Row {
            anchors.centerIn: parent
            spacing: Appearance.spacing.lg

            StyledText {
                anchors.verticalCenter: parent.verticalCenter
                text: qsTr("Dismissed")
                color: Colours.palette.m3inverseOnSurface
                font.pointSize: Appearance.font.size.labelLarge
            }

            StyledRect {
                anchors.verticalCenter: parent.verticalCenter
                radius: Appearance.rounding.full
                color: Colours.palette.m3inversePrimary
                implicitWidth: undoText.implicitWidth + Appearance.padding.md * 2
                implicitHeight: undoText.implicitHeight + Appearance.padding.xs * 2

                StateLayer {
                    radius: Appearance.rounding.full
                    color: Colours.palette.m3onSurface

                    function onClicked(): void {
                        root.undoDismiss();
                    }
                }

                StyledText {
                    id: undoText
                    anchors.centerIn: parent
                    text: qsTr("Undo")
                    color: Colours.palette.m3onSurface
                    font.pointSize: Appearance.font.size.labelLarge
                    font.bold: true
                }
            }
        }
    }

    component Action: StyledRect {
        id: action

        required property var modelData

        radius: Appearance.rounding.full
        color: root.modelData.urgency === NotificationUrgency.Critical ? Colours.palette.m3secondary : Colours.layer(Colours.palette.m3surfaceContainerHigh, 2)

        Layout.preferredWidth: actionText.width + Appearance.padding.md * 2
        Layout.preferredHeight: actionText.height + Appearance.padding.xs * 2
        implicitWidth: actionText.width + Appearance.padding.md * 2
        implicitHeight: actionText.height + Appearance.padding.xs * 2

        StateLayer {
            radius: Appearance.rounding.full
            color: root.modelData.urgency === NotificationUrgency.Critical ? Colours.palette.m3onSecondary : Colours.palette.m3onSurface

            function onClicked(): void {
                // Route through service if this is a real notification action
                // (has identifier); otherwise call invoke() directly (e.g. Close button)
                if (action.modelData.identifier !== undefined && action.modelData.identifier !== "")
                    Notifs.attemptInvokeAction(root.modelData.notificationId, action.modelData.identifier);
                else
                    action.modelData.invoke();
            }
        }

        StyledText {
            id: actionText

            anchors.centerIn: parent
            text: actionTextMetrics.elidedText
            color: root.modelData.urgency === NotificationUrgency.Critical ? Colours.palette.m3onSecondary : Colours.palette.m3onSurfaceVariant
            font.pointSize: Appearance.font.size.labelLarge
        }

        TextMetrics {
            id: actionTextMetrics

            text: action.modelData.text
            font.family: actionText.font.family
            font.pointSize: actionText.font.pointSize
            elide: Text.ElideRight
            elideWidth: {
                const numActions = root.modelData.actions.length + 1;
                return (inner.width - actions.spacing * (numActions - 1)) / numActions - Appearance.padding.md * 2;
            }
        }
    }
}
