import ".."
import qs.services
import qs.config
import QtQuick
import QtQuick.Controls

ScrollBar {
    id: root

    property Flickable flickable: null
    property bool shouldBeActive
    property real nonAnimPosition
    property bool animating

    onHoveredChanged: {
        if (!flickable) return;
        if (hovered)
            shouldBeActive = true;
        else
            shouldBeActive = flickable.moving;
    }

    property bool _updatingFromFlickable: false
    property bool _updatingFromUser: false

    onPositionChanged: {
        if (!flickable) return;
        if (_updatingFromUser) {
            _updatingFromUser = false;
            return;
        }
        if (position === nonAnimPosition) {
            animating = false;
            return;
        }
        if (!animating && !_updatingFromFlickable && !fullMouse.pressed) {
            nonAnimPosition = position;
        }
    }

    Connections {
        enabled: root.flickable !== null
        target: root.flickable
        function onContentYChanged() {
            if (!root.animating && !fullMouse.pressed) {
                root._updatingFromFlickable = true;
                const contentHeight = root.flickable.contentHeight;
                const height = root.flickable.height;
                if (contentHeight > height) {
                    root.nonAnimPosition = Math.max(0, Math.min(1, root.flickable.contentY / (contentHeight - height)));
                } else {
                    root.nonAnimPosition = 0;
                }
                root._updatingFromFlickable = false;
            }
        }
    }

    Component.onCompleted: {
        if (flickable) {
            const contentHeight = flickable.contentHeight;
            const height = flickable.height;
            if (contentHeight > height) {
                nonAnimPosition = Math.max(0, Math.min(1, flickable.contentY / (contentHeight - height)));
            }
        }
    }

    implicitWidth: flickable ? Appearance.padding.small : 6

    contentItem: StyledRect {
        anchors.left: parent ? parent.left : undefined
        anchors.right: parent ? parent.right : undefined
        opacity: {
            if (root.flickable) {
                if (root.size === 1)
                    return 0;
                if (fullMouse.pressed)
                    return 1;
                if (mouse.containsMouse)
                    return 0.8;
                if (root.policy === ScrollBar.AlwaysOn || root.shouldBeActive)
                    return 0.6;
                return 0;
            } else {
                return root.pressed ? 1 : root.policy === ScrollBar.AlwaysOn || (root.active && root.size < 1) ? 0.8 : 0;
            }
        }
        radius: Appearance.rounding.full
        color: Colours.palette.m3secondary

        MouseArea {
            id: mouse

            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            hoverEnabled: true
            acceptedButtons: Qt.NoButton
        }

        Behavior on opacity {
            Anim {}
        }
    }

    Connections {
        enabled: root.flickable !== null
        target: root.flickable

        function onMovingChanged(): void {
            if (root.flickable.moving)
                root.shouldBeActive = true;
            else
                hideDelay.restart();
        }
    }

    Timer {
        id: hideDelay

        interval: 600
        onTriggered: root.shouldBeActive = (root.flickable ? root.flickable.moving : false) || root.hovered
    }

    CustomMouseArea {
        id: fullMouse

        anchors.fill: parent
        preventStealing: root.flickable !== null

        onPressed: event => {
            if (!root.flickable) return;
            root.animating = true;
            root._updatingFromUser = true;
            const newPos = Math.max(0, Math.min(1 - root.size, event.y / root.height - root.size / 2));
            root.nonAnimPosition = newPos;
            if (root.flickable) {
                const contentHeight = root.flickable.contentHeight;
                const height = root.flickable.height;
                if (contentHeight > height) {
                    const maxContentY = contentHeight - height;
                    const maxPos = 1 - root.size;
                    const contentY = maxPos > 0 ? (newPos / maxPos) * maxContentY : 0;
                    root.flickable.contentY = Math.max(0, Math.min(maxContentY, contentY));
                }
            }
        }

        onPositionChanged: event => {
            if (!root.flickable) return;
            root._updatingFromUser = true;
            const newPos = Math.max(0, Math.min(1 - root.size, event.y / root.height - root.size / 2));
            root.nonAnimPosition = newPos;
            if (root.flickable) {
                const contentHeight = root.flickable.contentHeight;
                const height = root.flickable.height;
                if (contentHeight > height) {
                    const maxContentY = contentHeight - height;
                    const maxPos = 1 - root.size;
                    const contentY = maxPos > 0 ? (newPos / maxPos) * maxContentY : 0;
                    root.flickable.contentY = Math.max(0, Math.min(maxContentY, contentY));
                }
            }
        }

        function onWheel(event: WheelEvent): void {
            if (root.flickable) {
                root.animating = true;
                root._updatingFromUser = true;
                let newPos = root.nonAnimPosition;
                if (event.angleDelta.y > 0)
                    newPos = Math.max(0, root.nonAnimPosition - 0.1);
                else if (event.angleDelta.y < 0)
                    newPos = Math.min(1 - root.size, root.nonAnimPosition + 0.1);
                root.nonAnimPosition = newPos;
                if (root.flickable) {
                    const contentHeight = root.flickable.contentHeight;
                    const height = root.flickable.height;
                    if (contentHeight > height) {
                        const maxContentY = contentHeight - height;
                        const maxPos = 1 - root.size;
                        const contentY = maxPos > 0 ? (newPos / maxPos) * maxContentY : 0;
                        root.flickable.contentY = Math.max(0, Math.min(maxContentY, contentY));
                    }
                }
            } else {
                if (event.angleDelta.y > 0)
                    root.decrease();
                else if (event.angleDelta.y < 0)
                    root.increase();
            }
        }
    }

    Behavior on position {
        enabled: root.flickable !== null && !fullMouse.pressed

        Anim {}
    }
}
