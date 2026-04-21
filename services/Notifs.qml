pragma Singleton
pragma ComponentBehavior: Bound

import qs.config
import qs.utils
import qs.services
import Caelestia
import Quickshell
import Quickshell.Io
import Quickshell.Services.Notifications
import QtQuick

/**
 * Enhanced notification service.
 *
 * Improvements over the baseline:
 *  - Persistent JSON storage: notifications survive shell reloads
 *  - Stable IDs (idOffset): prevents ID collisions with the re-spawned server
 *  - Transient notification support: transient notifs are discarded on timeout
 *  - Per-notification timers: created dynamically and stored on the Notif object
 *  - Unread count tracking with markAllRead()
 *  - Notification grouping helpers: groupsByAppName / appNameList etc.
 *  - Centralised action invocation: attemptInvokeAction(id, identifier)
 *  - Richer signals: notify, discard, discardAll, timeout
 *  - Extended IPC: getUnread, markRead, discardAll, discardId
 */
Singleton {
    id: root

    // ── Public state ──────────────────────────────────────────────────────────

    readonly property list<Notif> list: []
    readonly property list<Notif> popups: list.filter(n => n.popup)

    property alias dnd: props.dnd

    /** Number of notifications received since last markAllRead(). */
    property int unread: 0

    /**
     * When true, new notifications will not create a popup.
     * Currently driven only by DND; extend as needed (e.g. fullscreen).
     */
    readonly property bool popupInhibited: props.dnd

    // ── Grouping helpers (mirrors end-4's design) ─────────────────────────────

    /** Map of appName → { appName, appIcon, notifications[], time } for ALL notifications. */
    readonly property var groupsByAppName: root._buildGroups(root.list)

    /** Same, but for popup-only notifications. */
    readonly property var popupGroupsByAppName: root._buildGroups(root.popups)

    /** App names sorted by most-recent notification, descending. */
    readonly property list<string> appNameList: root._sortedNames(root.groupsByAppName)

    /** App names for popups, sorted by most-recent notification, descending. */
    readonly property list<string> popupAppNameList: root._sortedNames(root.popupGroupsByAppName)

    // ── Signals ───────────────────────────────────────────────────────────────

    signal notify(notif: var)
    signal discard(id: int)
    signal discardAll()
    signal timeout(id: var)
    signal initDone()

    // ── Internal state ────────────────────────────────────────────────────────

    /**
     * Offset added to server-assigned IDs so that reloaded (persisted)
     * notifications never collide with fresh ones from the new server instance.
     */
    property int idOffset: 0

    // Latest time seen per appName — used for correct group sorting
    property var _latestTimeForApp: ({})

    // ── DND toast ─────────────────────────────────────────────────────────────

    onDndChanged: {
        if (!Config.utilities.toasts.dndChanged)
            return;

        if (dnd)
            Toaster.toast(qsTr("Do not disturb enabled"), qsTr("Popup notifications are now disabled"), "do_not_disturb_on");
        else
            Toaster.toast(qsTr("Do not disturb disabled"), qsTr("Popup notifications are now enabled"), "do_not_disturb_off");
    }

    // ── Persistent DND ───────────────────────────────────────────────────────

    PersistentProperties {
        id: props

        property bool dnd

        reloadableId: "notifs"
    }

    // ── Fullscreen ────────────────────────────────────────────────────────────

    function hasFullscreen(): bool {
        if (!Niri) return false;
        const currentWorkspace = Niri.allWorkspaces.find(w => w.is_active);
        return currentWorkspace ? Niri.windows.some(w => w.workspace_id === currentWorkspace.id && w.is_fullscreen) : false;
    }

    function shouldShowPopup(notification: var): bool {
        if (root.popupInhibited)
            return false;

        if (!hasFullscreen())
            return true;

        if (Config.notifs.fullscreen === "off")
            return false;

        return true;
    }

    // ── Notification server ───────────────────────────────────────────────────

    NotificationServer {
        id: server

        keepOnReload: false
        actionsSupported: true
        bodyHyperlinksSupported: true
        bodyImagesSupported: true
        bodyMarkupSupported: true
        bodySupported: true
        imageSupported: true
        persistenceSupported: true

        onNotification: notification => {
            notification.tracked = true;

            const newNotif = notifComp.createObject(root, {
                notificationId: notification.id + root.idOffset,
                notification: notification,
                isTransient: notification.hints?.transient ?? false,
                time: Date.now(),
            });

            root.list.push(newNotif);
            root._onListChanged();

            // Only show popup when not inhibited
            if (root.shouldShowPopup(notification)) {
                newNotif.popup = true;
                root.unread++;

                // Create a dismissal timer only when needed
                if (notification.expireTimeout !== 0) {
                    const interval = notification.expireTimeout < 0
                        ? (Config.notifs.popupTimeout ?? 7000)
                        : notification.expireTimeout;

                    newNotif.timer = notifTimerComp.createObject(root, {
                        notificationId: newNotif.notificationId,
                        interval: interval,
                    });
                }
            }

            root.notify(newNotif);
            root._saveToFile();
        }
    }

    // ── IPC ───────────────────────────────────────────────────────────────────

    IpcHandler {
        target: "notifs"

        /** Dismiss all popups (keeps them in history). */
        function clear(): void {
            root.timeoutAll();
        }

        function getDnd(): string {
            return props.dnd;
        }

        function toggleDnd(): void {
            props.dnd = !props.dnd;
        }

        function enableDnd(): void {
            props.dnd = true;
        }

        function disableDnd(): void {
            props.dnd = false;
        }

        /** Returns the current unread count. */
        function getUnread(): string {
            return root.unread.toString();
        }

        /** Reset the unread counter to 0. */
        function markRead(): void {
            root.markAllRead();
        }

        /** Permanently remove all notifications from history. */
        function discardAll(): void {
            root.discardAllNotifications();
        }

        /** Permanently remove a single notification by its stable ID. */
        function discardId(id: string): void {
            root.discardNotification(parseInt(id));
        }
    }

    // ── Public functions ──────────────────────────────────────────────────────

    /** Reset the unread counter. */
    function markAllRead(): void {
        root.unread = 0;
    }

    /**
     * Permanently remove a notification from the in-memory list and from the
     * notification server's tracked set. Emits `discard(id)`.
     */
    function discardNotification(id: int): void {
        const idx = root.list.findIndex(n => n.notificationId === id);
        if (idx !== -1) {
            root.list.splice(idx, 1);
            root._onListChanged();
            root._saveToFile();
        }

        // Also dismiss from server if still tracked (so the sender is notified)
        const serverIdx = server.trackedNotifications.values.findIndex(
            n => n.id + root.idOffset === id
        );
        if (serverIdx !== -1)
            server.trackedNotifications.values[serverIdx].dismiss();

        root.discard(id);
    }

    /** Permanently remove ALL notifications. Emits `discardAll()`. */
    function discardAllNotifications(): void {
        root.list.slice(0).forEach(n => {
            const serverIdx = server.trackedNotifications.values.findIndex(
                s => s.id + root.idOffset === n.notificationId
            );
            if (serverIdx !== -1)
                server.trackedNotifications.values[serverIdx].dismiss();
        });

        root.list.length = 0;
        root._triggerListChange();
        root._saveToFile();
        root.discardAll();
    }

    /** Stop the timer for a notification (e.g. on hover). */
    function cancelTimeout(id: int): void {
        const n = root.list.find(n => n.notificationId === id);
        if (n?.timer)
            n.timer.stop();
    }

    /**
     * Hide the popup for a notification (or discard it if transient).
     * Emits `timeout(id)`.
     */
    function timeoutNotification(id: int): void {
        const n = root.list.find(n => n.notificationId === id);
        if (!n) return;

        root.timeout(id);

        if (n.isTransient) {
            root.discardNotification(id);
        } else {
            n.popup = false;
        }
    }

    /** Hide all popups (keeps non-transient ones in history). */
    function timeoutAll(): void {
        // Collect IDs first to avoid mutating while iterating
        const ids = root.popups.map(n => n.notificationId);
        ids.forEach(id => root.timeoutNotification(id));
    }

    /**
     * Invoke a notification action by its identifier, then discard the notif.
     * @param id            The stable notificationId.
     * @param identifier    The action identifier string.
     */
    function attemptInvokeAction(id: int, identifier: string): void {
        const serverIdx = server.trackedNotifications.values.findIndex(
            n => n.id + root.idOffset === id
        );
        if (serverIdx !== -1) {
            const serverNotif = server.trackedNotifications.values[serverIdx];
            const action = serverNotif.actions.find(a => a.identifier === identifier);
            if (action)
                action.invoke();
        }
        root.discardNotification(id);
    }

    // ── Grouping helpers (private) ────────────────────────────────────────────

    function _buildGroups(notifs) {
        const groups = {};
        notifs.forEach(n => {
            if (!groups[n.appName]) {
                groups[n.appName] = {
                    appName: n.appName,
                    appIcon: n.appIcon,
                    notifications: [],
                    time: 0,
                };
            }
            groups[n.appName].notifications.push(n);
            groups[n.appName].time = root._latestTimeForApp[n.appName] ?? n.time;
        });
        return groups;
    }

    function _sortedNames(groups) {
        return Object.keys(groups).sort((a, b) => groups[b].time - groups[a].time);
    }

    // Called whenever `list` changes to keep _latestTimeForApp in sync
    function _onListChanged(): void {
        // Update latest time per app
        root.list.forEach(n => {
            if (!root._latestTimeForApp[n.appName] || n.time > root._latestTimeForApp[n.appName])
                root._latestTimeForApp[n.appName] = n.time;
        });
        // Prune apps that have no notifications left
        Object.keys(root._latestTimeForApp).forEach(app => {
            if (!root.list.some(n => n.appName === app))
                delete root._latestTimeForApp[app];
        });
        root._triggerListChange();
    }

    /** Force QML to re-evaluate all list bindings by replacing the array. */
    function _triggerListChange(): void {
        root.list = root.list.slice(0);
    }

    // ── Persistence ───────────────────────────────────────────────────────────

    function _notifToJSON(n) {
        return {
            notificationId: n.notificationId,
            actions: n.actions.map(a => ({ identifier: a.identifier, text: a.text })),
            appIcon: n.appIcon,
            appName: n.appName,
            body: n.body,
            image: n.image,
            isTransient: n.isTransient,
            summary: n.summary,
            time: n.time,
            urgency: n.urgency.toString(),
        };
    }

    function _saveToFile(): void {
        notifFileView.setText(JSON.stringify(root.list.map(n => root._notifToJSON(n)), null, 2));
    }

    Component.onCompleted: {
        notifFileView.reload();
    }

    FileView {
        id: notifFileView

        path: Qt.resolvedUrl(Paths.notificationsData)

        onLoaded: {
            let parsed = [];
            try {
                parsed = JSON.parse(notifFileView.text());
            } catch (e) {
                console.warn("[Notifs] Failed to parse notifications file:", e);
                parsed = [];
            }

            // Filter out transient notifications — they should never persist
            parsed = parsed.filter(n => !n.isTransient);

            root.list = parsed.map(data => notifComp.createObject(root, {
                notificationId: data.notificationId,
                // Actions from persisted notifications are meaningless (sender is gone)
                _savedActions: [],
                appIcon: data.appIcon ?? "",
                appName: data.appName ?? "",
                body: data.body ?? "",
                image: data.image ?? "",
                isTransient: false,
                summary: data.summary ?? "",
                time: data.time ?? 0,
                _savedUrgency: data.urgency ?? "normal",
            }));

            // Derive idOffset from the largest persisted ID so the new server
            // IDs cannot collide with the persisted ones
            let maxId = 0;
            root.list.forEach(n => { maxId = Math.max(maxId, n.notificationId); });
            root.idOffset = maxId;

            root._onListChanged();
            console.log("[Notifs] Loaded", root.list.length, "notification(s) from file, idOffset =", root.idOffset);
            root.initDone();
        }

        onLoadFailed: error => {
            if (error === FileViewError.FileNotFound) {
                console.log("[Notifs] No saved notifications file, starting fresh.");
                root.list = [];
                root._saveToFile();
            } else {
                console.warn("[Notifs] Error loading file:", error);
            }
            root.initDone();
        }
    }

    // ── Components ────────────────────────────────────────────────────────────

    /**
     * Notif — wrapper around a live or persisted notification.
     *
     * When constructed from the server, `notification` is set and most
     * properties are derived from it.  When restored from JSON, `notification`
     * is null and the `_saved*` overrides are used instead.
     */
    component Notif: QtObject {
        id: notif

        // Stable, cross-reload unique identifier
        property int notificationId

        // Set by the server on live notifications; null for persisted ones
        property Notification notification: null

        // Whether the popup is currently shown
        property bool popup: false

        // Whether this notif should be discarded (not just hidden) when it times out
        property bool isTransient: notification?.hints?.transient ?? false

        // Dismissal timer — created dynamically, may be null
        property Timer timer: null

        // ── Presentation data ─────────────────────────────────────────────────
        // When the notification is live, we read from the Notification object.
        // When restored from JSON, we fall back to _saved* properties.

        property list<NotificationAction> _liveActions: notification?.actions ?? []
        property list<var> _savedActions: []
        property list<var> actions: notification ? _liveActions : _savedActions

        property string _savedUrgency: "normal"
        readonly property var urgency: notification?.urgency ?? _savedUrgency

        readonly property string summary: notification?.summary ?? _savedSummary
        property string _savedSummary: ""
        readonly property string body: notification?.body ?? _savedBody
        property string _savedBody: ""
        readonly property string appIcon: notification?.appIcon ?? _savedAppIcon
        property string _savedAppIcon: ""
        readonly property string appName: notification?.appName ?? _savedAppName
        property string _savedAppName: ""
        readonly property string image: notification?.image ?? _savedImage
        property string _savedImage: ""

        // When this was received (ms since epoch)
        property double time: 0

        // Human-readable relative timestamp
        readonly property string timeStr: {
            const diff = Time.date.getTime() - time;
            const m = Math.floor(diff / 60000);
            const h = Math.floor(m / 60);
            const d = Math.floor(h / 24);

            if (d >= 1) return `${d}d`;
            if (h >= 1) return `${h}h`;
            if (m >= 1) return `${m}m`;
            return qsTr("now");
        }

        // ── Lifecycle ─────────────────────────────────────────────────────────

        readonly property Connections _serverConn: Connections {
            target: notif.notification?.Retainable ?? null

            function onDropped(): void {
                // Server dropped the notification — remove from history
                root.discardNotification(notif.notificationId);
            }

            function onAboutToDestroy(): void {
                notif.destroy();
            }
        }
    }

    /**
     * NotifTimer — drives automatic popup timeout / discard.
     * Destroyed immediately after firing.
     */
    component NotifTimer: Timer {
        required property int notificationId

        running: true

        onTriggered: {
            root.timeoutNotification(notificationId);
            destroy();
        }
    }

    Component {
        id: notifComp
        Notif {}
    }

    Component {
        id: notifTimerComp
        NotifTimer {}
    }
}
