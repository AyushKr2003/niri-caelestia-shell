pragma ComponentBehavior: Bound

import qs.components
import qs.config
import Quickshell
import Quickshell.Widgets
import QtQuick
import QtQuick.Layouts
//later additions
import qs.components
import qs.components.widgets
import qs.services

Item {
    id: root

    required property PersistentProperties visibilities
    required property PersistentProperties state
    readonly property real nonAnimWidth: view.implicitWidth + viewWrapper.anchors.margins * 2

    implicitWidth: nonAnimWidth
    implicitHeight: tabs.implicitHeight + tabs.anchors.topMargin + column.implicitHeight + viewWrapper.anchors.margins * 2

    Tabs {
        id: tabs

        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.topMargin: Appearance.padding.normal
        anchors.margins: Appearance.padding.large

        nonAnimWidth: root.nonAnimWidth - anchors.margins * 2
        state: root.state
    }

    ClippingRectangle {
        id: viewWrapper

        anchors.top: tabs.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: Appearance.padding.large

        radius: Appearance.rounding.normal
        color: "transparent"

        ColumnLayout {
            id: column
            // anchors.fill: parent

            Flickable {
                id: view

                readonly property int currentIndex: root.state.currentTab
                readonly property Item currentItem: row.children[currentIndex]

                // anchors.fill: parent

                flickableDirection: Flickable.HorizontalFlick

                implicitWidth: currentItem.implicitWidth
                implicitHeight: currentItem.implicitHeight

                contentX: currentItem.x
                contentWidth: row.implicitWidth
                contentHeight: row.implicitHeight

                onContentXChanged: {
                    if (!moving)
                        return;

                    const x = contentX - currentItem.x;
                    if (x > currentItem.implicitWidth / 2)
                        root.state.currentTab = Math.min(root.state.currentTab + 1, tabs.count - 1);
                    else if (x < -currentItem.implicitWidth / 2)
                        root.state.currentTab = Math.max(root.state.currentTab - 1, 0);
                }

                onDragEnded: {
                    const x = contentX - currentItem.x;
                    if (x > currentItem.implicitWidth / 10)
                        root.state.currentTab = Math.min(root.state.currentTab + 1, tabs.count - 1);
                    else if (x < -currentItem.implicitWidth / 10)
                        root.state.currentTab = Math.max(root.state.currentTab - 1, 0);
                    else
                        contentX = Qt.binding(() => currentItem.x);
                }

                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.LeftButton
                    hoverEnabled: true
                    cursorShape: pressed || view.dragging ? Qt.ClosedHandCursor : Qt.ArrowCursor
                    // Prevent this MouseArea from interfering with Flickable's own drag
                    // propagateComposedEvents: true
                    // onPressed: mouse => mouse.accepted = true
                    // onReleased: mouse => mouse.accepted = false
                    // onClicked: mouse => mouse.accepted = false
                    // onDoubleClicked: mouse => mouse.accepted = false
                    // onWheel: wheel => wheel.accepted = false
                }

                RowLayout {
                    id: row

                    Pane {
                        sourceComponent: Dash {
                            visibilities: root.visibilities
                            state: root.state
                        }
                    }

                    Pane {
                        sourceComponent: Media {
                            visibilities: root.visibilities
                        }
                    }

                    Pane {
                        sourceComponent: Performance {}
                    }

                    Pane {
                        sourceComponent: WeatherPanel {}
                    }

                    Pane {
                        sourceComponent: NiriThing {}
                    }
                }

                Behavior on contentX {
                    Anim {}
                }
            }

            StyledRect {
                id: separator

                Layout.topMargin: Appearance.spacing.normal
                Layout.alignment: Qt.AlignHCenter
                Layout.fillWidth: true

                implicitHeight: 1
                color: Colours.palette.m3outlineVariant
            }

            RowLayout {
                id: styledRadialButton
                Layout.alignment: Qt.AlignLeft
                Layout.topMargin: Appearance.spacing.small
                Layout.leftMargin: Appearance.spacing.small
                Layout.rightMargin: Appearance.spacing.small

                ActiveWindow {
                    //TODO Add a way to mitigate overflow, I implemented a solution in dashboard/ActiveWindow but it's meh.
                    id: activeWindow
                    Layout.fillWidth: true
                }

                Item {
                    Layout.fillWidth: true
                }

                WindowDecorations {}
            }
        }
    }

    Behavior on implicitWidth {
        Anim {
            duration: Appearance.anim.durations.large
            easing.bezierCurve: Appearance.anim.curves.emphasized
        }
    }

    Behavior on implicitHeight {
        Anim {
            duration: Appearance.anim.durations.large
            easing.bezierCurve: Appearance.anim.curves.emphasized
        }
    }

    component Pane: Loader {
        Layout.alignment: Qt.AlignTop

        Component.onCompleted: active = Qt.binding(() => {
            const vx = Math.floor(view.visibleArea.xPosition * view.contentWidth);
            const vex = Math.floor(vx + view.visibleArea.widthRatio * view.contentWidth);
            return (vx >= x && vx <= x + implicitWidth) || (vex >= x && vex <= x + implicitWidth);
        })
    }
}
