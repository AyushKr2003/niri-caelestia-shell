pragma Singleton

import Quickshell
import QtQuick

Singleton {
    id: root

    // Toast type constants (matching hyprland C++ Toast::Type enum)
    readonly property int typeInfo: 0
    readonly property int typeSuccess: 1
    readonly property int typeWarning: 2
    readonly property int typeError: 3

    property var toasts: []

    function toast(title: string, message: string, icon: string, type: int, timeout: int): void {
        if (type === undefined || type === null)
            type = typeInfo;

        if (!icon) {
            switch (type) {
            case typeSuccess:
                icon = "check_circle_unread";
                break;
            case typeWarning:
                icon = "warning";
                break;
            case typeError:
                icon = "error";
                break;
            default:
                icon = "info";
                break;
            }
        }

        if (!timeout || timeout <= 0) {
            switch (type) {
            case typeWarning:
                timeout = 7000;
                break;
            case typeError:
                timeout = 10000;
                break;
            default:
                timeout = 5000;
                break;
            }
        }

        const t = toastComp.createObject(root, {
            title: title,
            message: message,
            icon: icon,
            type: type,
            timeout: timeout
        });

        t.finishedClose.connect(function() {
            const idx = root.toasts.indexOf(t);
            if (idx !== -1) {
                const copy = root.toasts.slice();
                copy.splice(idx, 1);
                root.toasts = copy;
                t.destroy();
            }
        });

        root.toasts = [t, ...root.toasts.slice()];
    }

    Component {
        id: toastComp

        QtObject {
            id: toast

            property bool closed: false
            property string title
            property string message
            property string icon
            property int timeout: 5000
            property int type: 0

            property var _locks: []

            signal finishedClose()

            function close(): void {
                if (!closed)
                    closed = true;

                if (_locks.length === 0)
                    finishedClose();
            }

            function lock(sender: var): void {
                if (_locks.indexOf(sender) === -1)
                    _locks.push(sender);
            }

            function unlock(sender: var): void {
                const idx = _locks.indexOf(sender);
                if (idx !== -1) {
                    _locks.splice(idx, 1);
                    if (closed && _locks.length === 0)
                        finishedClose();
                }
            }

            readonly property Timer _timer: Timer {
                interval: toast.timeout
                running: true
                repeat: false
                onTriggered: toast.close()
            }
        }
    }
}
