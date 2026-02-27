#include "niriipc.hpp"

#include <qdir.h>
#include <qfile.h>
#include <qjsonarray.h>
#include <qjsondocument.h>
#include <qjsonobject.h>
#include <qjsonvalue.h>
#include <qdebug.h>

#include <algorithm>

namespace caelestia {

NiriIpc::NiriIpc(QObject* parent)
    : QObject(parent)
    , m_eventSocket(this)
    , m_requestSocket(this) {

    connect(&m_eventSocket, &NiriEventSocket::connected, this, &NiriIpc::onEventStreamConnected);
    connect(&m_eventSocket, &NiriEventSocket::disconnected, this, &NiriIpc::onEventStreamDisconnected);
    connect(&m_eventSocket, &NiriEventSocket::eventReceived, this, &NiriIpc::onEvent);
    connect(&m_ledWatcher, &QFileSystemWatcher::fileChanged, this, &NiriIpc::onLedFileChanged);

    setupLedWatchers();
    m_eventSocket.connectToNiri();
}

// ── Property getters ─────────────────────────────────────────────────

bool NiriIpc::available() const { return m_available; }

QVariantList NiriIpc::workspaces() const { return m_workspaces; }
int NiriIpc::focusedWorkspaceIndex() const { return m_focusedWorkspaceIndex; }
int NiriIpc::focusedWorkspaceId() const { return m_focusedWorkspaceId; }
QString NiriIpc::focusedMonitorName() const { return m_focusedMonitorName; }
QVariantList NiriIpc::currentOutputWorkspaces() const { return m_currentOutputWorkspaces; }
QVariantMap NiriIpc::workspaceHasWindows() const { return m_workspaceHasWindows; }

QVariantList NiriIpc::windows() const { return m_windows; }
int NiriIpc::focusedWindowIndex() const { return m_focusedWindowIndex; }
QString NiriIpc::focusedWindowId() const { return m_focusedWindowId; }
QString NiriIpc::focusedWindowTitle() const { return m_focusedWindowTitle; }
QString NiriIpc::focusedWindowClass() const { return m_focusedWindowClass; }
QVariantMap NiriIpc::focusedWindow() const { return m_focusedWindow; }
QVariantMap NiriIpc::lastFocusedWindow() const { return m_lastFocusedWindow; }
QString NiriIpc::scrollDirection() const { return m_scrollDirection; }
bool NiriIpc::inOverview() const { return m_inOverview; }

QVariantMap NiriIpc::outputs() const { return m_outputs; }

QVariantList NiriIpc::kbLayoutsArray() const { return m_kbLayoutsArray; }
int NiriIpc::kbLayoutIndex() const { return m_kbLayoutIndex; }
QString NiriIpc::kbLayouts() const { return m_kbLayouts; }

QString NiriIpc::defaultKbLayout() const {
    if (!m_kbLayoutsArray.isEmpty()) {
        return m_kbLayoutsArray.first().toString();
    }
    return QStringLiteral("?");
}

QString NiriIpc::kbLayout() const {
    if (m_kbLayoutIndex >= 0 && m_kbLayoutIndex < m_kbLayoutsArray.size()) {
        const QString name = m_kbLayoutsArray.at(m_kbLayoutIndex).toString();
        if (name.size() >= 2) {
            return name.left(2).toLower();
        }
    }
    return QStringLiteral("?");
}

bool NiriIpc::capsLock() const { return m_capsLock; }
bool NiriIpc::numLock() const { return m_numLock; }

// ── Actions ──────────────────────────────────────────────────────────

bool NiriIpc::action(const QString& actionName, const QVariantList& args) {
    if (!m_available) return false;

    // Convert action name from kebab-case to PascalCase for IPC
    QString pascalName;
    bool capitalizeNext = true;
    for (const QChar& c : actionName) {
        if (c == '-') {
            capitalizeNext = true;
        } else {
            pascalName += capitalizeNext ? c.toUpper() : c;
            capitalizeNext = false;
        }
    }

    // Build the inner action object based on niri's expected JSON format.
    // Each action has a specific schema; we match the patterns used by the QML layer.
    QJsonObject actionObj;
    QJsonValue innerValue;

    if (args.size() >= 2 && args.at(0).toString() == QStringLiteral("--id")) {
        // Actions with --id: FocusWindow, CloseWindow, ToggleWindowFloating
        // Format: {"ActionName": {"id": N}}
        QJsonObject inner;
        inner[QStringLiteral("id")] = args.at(1).toLongLong();
        innerValue = inner;
    } else if (args.size() == 2 && args.at(0).toString() == QStringLiteral("-d")) {
        // DoScreenTransition with delay: {"DoScreenTransition": {"delay_ms": N}}
        QJsonObject inner;
        inner[QStringLiteral("delay_ms")] = args.at(1).toInt();
        innerValue = inner;
    } else if (args.isEmpty()) {
        // No-arg actions.
        // Most accept {} but some need specific defaults.
        if (pascalName == QStringLiteral("ScreenshotWindow")) {
            QJsonObject inner;
            inner[QStringLiteral("id")] = QJsonValue::Null;
            inner[QStringLiteral("write_to_disk")] = true;
            inner[QStringLiteral("path")] = QJsonValue::Null;
            innerValue = inner;
        } else if (pascalName == QStringLiteral("CloseWindow") ||
                   pascalName == QStringLiteral("ToggleWindowFloating")) {
            QJsonObject inner;
            inner[QStringLiteral("id")] = QJsonValue::Null;
            innerValue = inner;
        } else {
            innerValue = QJsonObject();
        }
    } else if (args.size() == 1) {
        // Single positional arg — meaning depends on the action.
        bool isNumber = false;
        const qint64 num = args.at(0).toLongLong(&isNumber);

        if (pascalName == QStringLiteral("FocusWorkspace")) {
            // {"FocusWorkspace": {"reference": {"Index": N}}}
            QJsonObject ref;
            ref[QStringLiteral("Index")] = num;
            QJsonObject inner;
            inner[QStringLiteral("reference")] = ref;
            innerValue = inner;
        } else if (pascalName == QStringLiteral("MoveWindowToWorkspace")) {
            // {"MoveWindowToWorkspace": {"window_id": null, "reference": {"Index": N}, "focus": true}}
            QJsonObject ref;
            ref[QStringLiteral("Index")] = num;
            QJsonObject inner;
            inner[QStringLiteral("window_id")] = QJsonValue::Null;
            inner[QStringLiteral("reference")] = ref;
            inner[QStringLiteral("focus")] = true;
            innerValue = inner;
        } else if (pascalName == QStringLiteral("MoveColumnToIndex")) {
            // {"MoveColumnToIndex": {"index": N}}
            QJsonObject inner;
            inner[QStringLiteral("index")] = num;
            innerValue = inner;
        } else if (isNumber) {
            // Generic numeric arg — wrap as object with reasonable key
            QJsonObject inner;
            inner[QStringLiteral("id")] = num;
            innerValue = inner;
        } else {
            // String argument
            innerValue = args.at(0).toString();
        }
    } else {
        qWarning() << "NiriIpc: Unhandled action args for" << actionName << args;
        innerValue = QJsonObject();
    }

    actionObj[pascalName] = innerValue;

    QJsonObject wrapper;
    wrapper[QStringLiteral("Action")] = actionObj;
    const QByteArray payload = QJsonDocument(wrapper).toJson(QJsonDocument::Compact);

    m_requestSocket.action(payload);
    return true;
}

int NiriIpc::getWorkspaceIdxById(int workspaceId) const {
    for (const auto& v : m_workspaces) {
        const auto ws = v.toMap();
        if (ws.value(QStringLiteral("id")).toInt() == workspaceId) {
            return ws.value(QStringLiteral("idx")).toInt();
        }
    }
    return -1;
}

// ── Event Stream Slots ───────────────────────────────────────────────

void NiriIpc::onEventStreamConnected() {
    qDebug() << "NiriIpc: Event stream connected";
    m_available = true;
    emit availableChanged();
    fetchInitialState();
}

void NiriIpc::onEventStreamDisconnected() {
    qDebug() << "NiriIpc: Event stream disconnected";
    m_available = false;
    emit availableChanged();
}

void NiriIpc::onEvent(const QJsonObject& event) {
    if (event.contains(QStringLiteral("WorkspacesChanged"))) {
        handleWorkspacesChanged(event.value(QStringLiteral("WorkspacesChanged")).toObject());
    } else if (event.contains(QStringLiteral("WorkspaceActivated"))) {
        // WorkspaceActivated is handled within WorkspacesChanged in the new protocol
        // but may still arrive separately - handle it
        const auto data = event.value(QStringLiteral("WorkspaceActivated")).toObject();
        const int id = data.value(QStringLiteral("id")).toInt();
        const bool focused = data.value(QStringLiteral("focused")).toBool();
        Q_UNUSED(focused);
        m_focusedWorkspaceId = id;
        for (int i = 0; i < m_workspaces.size(); ++i) {
            auto ws = m_workspaces.at(i).toMap();
            if (ws.value(QStringLiteral("id")).toInt() == id) {
                m_focusedWorkspaceIndex = i;
                m_focusedMonitorName = ws.value(QStringLiteral("output")).toString();
                // Update active/focused flags on same output
                const QString output = m_focusedMonitorName;
                for (int j = 0; j < m_workspaces.size(); ++j) {
                    auto w = m_workspaces.at(j).toMap();
                    if (w.value(QStringLiteral("output")).toString() == output) {
                        w[QStringLiteral("is_active")] = (j == i);
                        w[QStringLiteral("is_focused")] = (j == i);
                        m_workspaces[j] = w;
                    }
                }
                break;
            }
        }
        updateCurrentOutputWorkspaces();
        emit workspacesChanged();
        emit focusedWorkspaceChanged();
    } else if (event.contains(QStringLiteral("WindowsChanged"))) {
        handleWindowsChanged(event.value(QStringLiteral("WindowsChanged")).toObject());
    } else if (event.contains(QStringLiteral("WindowOpenedOrChanged"))) {
        handleWindowOpenedOrChanged(event.value(QStringLiteral("WindowOpenedOrChanged")).toObject());
    } else if (event.contains(QStringLiteral("WindowClosed"))) {
        handleWindowClosed(event.value(QStringLiteral("WindowClosed")).toObject());
    } else if (event.contains(QStringLiteral("WindowFocusChanged"))) {
        handleWindowFocusChanged(event.value(QStringLiteral("WindowFocusChanged")).toObject());
    } else if (event.contains(QStringLiteral("WindowLayoutsChanged"))) {
        handleWindowLayoutsChanged(event.value(QStringLiteral("WindowLayoutsChanged")).toObject());
    } else if (event.contains(QStringLiteral("KeyboardLayoutsChanged"))) {
        handleKeyboardLayoutsChanged(event.value(QStringLiteral("KeyboardLayoutsChanged")).toObject());
    } else if (event.contains(QStringLiteral("OverviewOpenedOrClosed"))) {
        handleOverviewOpenedOrClosed(event.value(QStringLiteral("OverviewOpenedOrClosed")).toObject());
    } else if (event.contains(QStringLiteral("OutputsChanged"))) {
        handleOutputsChanged(event.value(QStringLiteral("OutputsChanged")).toObject());
    }
}

// ── Initial State ────────────────────────────────────────────────────

void NiriIpc::fetchInitialState() {
    // Initial query responses have PascalCase keys wrapping the data:
    //   {"Ok":{"Workspaces":[...]}}  -> result = {"Workspaces":[...]}
    // But event handlers expect lowercase keys matching the event format:
    //   {"WorkspacesChanged":{"workspaces":[...]}}
    // So we must unwrap the PascalCase key and re-wrap with the event format.

    // Fetch workspaces
    m_requestSocket.request("\"Workspaces\"", [this](bool ok, const QJsonObject& resp) {
        if (!ok) return;
        const auto result = resp.value(QStringLiteral("result")).toObject();
        // result = {"Workspaces": [...]} -> unwrap to event format {"workspaces": [...]}
        QJsonObject data;
        data[QStringLiteral("workspaces")] = result.value(QStringLiteral("Workspaces"));
        handleWorkspacesChanged(data);
    });

    // Fetch windows
    m_requestSocket.request("\"Windows\"", [this](bool ok, const QJsonObject& resp) {
        if (!ok) return;
        const auto result = resp.value(QStringLiteral("result")).toObject();
        // result = {"Windows": [...]} -> {"windows": [...]}
        QJsonObject data;
        data[QStringLiteral("windows")] = result.value(QStringLiteral("Windows"));
        handleWindowsChanged(data);
    });

    // Fetch focused window
    m_requestSocket.request("\"FocusedWindow\"", [this](bool ok, const QJsonObject& resp) {
        if (!ok) return;
        const auto result = resp.value(QStringLiteral("result")).toObject();
        // result = {"FocusedWindow": {id, title, ...}} or {"FocusedWindow": null}
        const auto win = result.value(QStringLiteral("FocusedWindow"));
        if (win.isObject()) {
            QJsonObject d;
            d[QStringLiteral("id")] = win.toObject().value(QStringLiteral("id"));
            handleWindowFocusChanged(d);
        }
    });

    // Fetch outputs
    m_requestSocket.request("\"Outputs\"", [this](bool ok, const QJsonObject& resp) {
        if (!ok) return;
        const auto result = resp.value(QStringLiteral("result")).toObject();
        // result = {"Outputs": {"eDP-1": {...}}} -> unwrap to the map of outputs
        const auto outputs = result.value(QStringLiteral("Outputs")).toObject();
        m_outputs = outputs.toVariantMap();
        emit outputsChanged();
    });

    // Fetch keyboard layouts
    m_requestSocket.request("\"KeyboardLayouts\"", [this](bool ok, const QJsonObject& resp) {
        if (!ok) return;
        const auto result = resp.value(QStringLiteral("result")).toObject();
        // result = {"KeyboardLayouts": {"names":[...], "current_idx":0}}
        // Event format: {"keyboard_layouts": {"names":[...], "current_idx":0}}
        QJsonObject data;
        data[QStringLiteral("keyboard_layouts")] = result.value(QStringLiteral("KeyboardLayouts"));
        handleKeyboardLayoutsChanged(data);
    });
}

// ── Event Handlers ───────────────────────────────────────────────────

static QVariantMap jsonObjectToVariantMap(const QJsonObject& obj) {
    return obj.toVariantMap();
}

static QVariantList jsonArrayToVariantList(const QJsonArray& arr) {
    return arr.toVariantList();
}

void NiriIpc::handleWorkspacesChanged(const QJsonObject& data) {
    const QJsonArray wsArray = data.value(QStringLiteral("workspaces")).toArray();

    QVariantList wsList = jsonArrayToVariantList(wsArray);

    // Sort by idx
    std::sort(wsList.begin(), wsList.end(), [](const QVariant& a, const QVariant& b) {
        return a.toMap().value(QStringLiteral("idx")).toInt()
             < b.toMap().value(QStringLiteral("idx")).toInt();
    });

    m_workspaces = wsList;

    // Find focused workspace
    m_focusedWorkspaceIndex = -1;
    m_focusedWorkspaceId = -1;
    for (int i = 0; i < m_workspaces.size(); ++i) {
        const auto ws = m_workspaces.at(i).toMap();
        if (ws.value(QStringLiteral("is_focused")).toBool()) {
            m_focusedWorkspaceIndex = i;
            m_focusedWorkspaceId = ws.value(QStringLiteral("id")).toInt();
            m_focusedMonitorName = ws.value(QStringLiteral("output")).toString();
            break;
        }
    }

    if (m_focusedWorkspaceIndex < 0 && !m_workspaces.isEmpty()) {
        m_focusedWorkspaceIndex = 0;
    }

    updateCurrentOutputWorkspaces();
    updateWorkspaceHasWindows();
    emit workspacesChanged();
    emit focusedWorkspaceChanged();
}

void NiriIpc::handleWindowsChanged(const QJsonObject& data) {
    const QJsonArray winArray = data.value(QStringLiteral("windows")).toArray();
    m_windows = jsonArrayToVariantList(winArray);

    // Ensure all windows have a layout object
    for (int i = 0; i < m_windows.size(); ++i) {
        auto w = m_windows.at(i).toMap();
        if (!w.contains(QStringLiteral("layout"))) {
            w[QStringLiteral("layout")] = QVariantMap();
            m_windows[i] = w;
        }
    }

    sortWindowsList();
    updateFocusedWindowFields();
    updateWorkspaceHasWindows();
    emit windowsChanged();
}

void NiriIpc::handleWindowOpenedOrChanged(const QJsonObject& data) {
    const QJsonObject winObj = data.value(QStringLiteral("window")).toObject();
    if (winObj.isEmpty()) return;

    const QVariantMap window = jsonObjectToVariantMap(winObj);
    const auto winId = window.value(QStringLiteral("id"));

    // Find or insert
    int existingIdx = -1;
    for (int i = 0; i < m_windows.size(); ++i) {
        if (m_windows.at(i).toMap().value(QStringLiteral("id")) == winId) {
            existingIdx = i;
            break;
        }
    }

    if (existingIdx >= 0) {
        // Merge updated fields into existing
        auto existing = m_windows.at(existingIdx).toMap();
        for (auto it = window.begin(); it != window.end(); ++it) {
            existing[it.key()] = it.value();
        }
        m_windows[existingIdx] = existing;
    } else {
        m_windows.append(window);
    }

    sortWindowsList();

    if (window.value(QStringLiteral("is_focused")).toBool()) {
        m_focusedWindowId = winId.toString();
        // Find new index after sort
        for (int i = 0; i < m_windows.size(); ++i) {
            if (m_windows.at(i).toMap().value(QStringLiteral("id")) == winId) {
                m_focusedWindowIndex = i;
                break;
            }
        }
    }

    updateFocusedWindowFields();
    updateWorkspaceHasWindows();
    emit windowsChanged();
    emit windowOpenedOrChanged(window);
}

void NiriIpc::handleWindowClosed(const QJsonObject& data) {
    const auto closedId = data.value(QStringLiteral("id")).toVariant();

    m_windows.erase(
        std::remove_if(m_windows.begin(), m_windows.end(), [&closedId](const QVariant& v) {
            return v.toMap().value(QStringLiteral("id")) == closedId;
        }),
        m_windows.end()
    );

    updateFocusedWindowFields();
    updateWorkspaceHasWindows();
    emit windowsChanged();
}

void NiriIpc::handleWindowFocusChanged(const QJsonObject& data) {
    if (data.contains(QStringLiteral("id")) && !data.value(QStringLiteral("id")).isNull()) {
        const QString newId = QString::number(data.value(QStringLiteral("id")).toInteger());
        m_focusedWindowId = newId;
        m_focusedWindowIndex = -1;
        for (int i = 0; i < m_windows.size(); ++i) {
            if (QString::number(m_windows.at(i).toMap().value(QStringLiteral("id")).toLongLong()) == newId) {
                m_focusedWindowIndex = i;
                break;
            }
        }
    } else {
        m_focusedWindowId.clear();
        m_focusedWindowIndex = -1;
    }

    updateFocusedWindowFields();
    emit focusedWindowChanged();
}

void NiriIpc::handleWindowLayoutsChanged(const QJsonObject& data) {
    const QJsonArray changes = data.value(QStringLiteral("changes")).toArray();
    if (changes.isEmpty()) return;

    for (const auto& change : changes) {
        const QJsonArray pair = change.toArray();
        if (pair.size() != 2) continue;

        const auto id = pair.at(0).toVariant();
        const auto layout = pair.at(1).toObject().toVariantMap();

        for (int i = 0; i < m_windows.size(); ++i) {
            if (m_windows.at(i).toMap().value(QStringLiteral("id")).toLongLong() == id.toLongLong()) {
                auto w = m_windows.at(i).toMap();
                w[QStringLiteral("layout")] = layout;
                m_windows[i] = w;
                break;
            }
        }
    }

    sortWindowsList();

    // Re-find focused index after sort
    if (!m_focusedWindowId.isEmpty()) {
        const auto fId = m_focusedWindowId.toLongLong();
        m_focusedWindowIndex = -1;
        for (int i = 0; i < m_windows.size(); ++i) {
            if (m_windows.at(i).toMap().value(QStringLiteral("id")).toLongLong() == fId) {
                m_focusedWindowIndex = i;
                break;
            }
        }
    }

    updateFocusedWindowFields();
    emit windowsChanged();
}

void NiriIpc::handleOutputsChanged(const QJsonObject& data) {
    // Event format: {"outputs": {"eDP-1": {...}, ...}}
    const auto outputs = data.value(QStringLiteral("outputs"));
    if (outputs.isObject()) {
        m_outputs = outputs.toObject().toVariantMap();
    } else {
        // Fallback: data itself is the outputs map
        m_outputs = data.toVariantMap();
    }
    emit outputsChanged();
}

void NiriIpc::handleKeyboardLayoutsChanged(const QJsonObject& data) {
    const QJsonObject kb = data.value(QStringLiteral("keyboard_layouts")).toObject();
    if (kb.isEmpty()) {
        // Direct format from initial fetch: {"names":[...],"current_idx":0}
        const QJsonArray names = data.value(QStringLiteral("names")).toArray();
        if (!names.isEmpty()) {
            m_kbLayoutsArray = jsonArrayToVariantList(names);
            QStringList namesList;
            for (const auto& v : m_kbLayoutsArray) {
                namesList.append(v.toString());
            }
            m_kbLayouts = namesList.join(QStringLiteral(","));

            m_kbLayoutIndex = data.value(QStringLiteral("current_idx")).toInt(0);
            emit keyboardChanged();
            return;
        }
        m_kbLayoutsArray.clear();
        m_kbLayouts = QStringLiteral("?");
        m_kbLayoutIndex = 0;
        emit keyboardChanged();
        return;
    }

    const QJsonArray names = kb.value(QStringLiteral("names")).toArray();
    m_kbLayoutsArray = jsonArrayToVariantList(names);

    QStringList namesList;
    for (const auto& v : m_kbLayoutsArray) {
        namesList.append(v.toString());
    }
    m_kbLayouts = namesList.isEmpty() ? QStringLiteral("?") : namesList.join(QStringLiteral(","));

    const int idx = kb.value(QStringLiteral("current_idx")).toInt(0);
    m_kbLayoutIndex = (idx >= 0 && idx < m_kbLayoutsArray.size()) ? idx : 0;

    emit keyboardChanged();
}

void NiriIpc::handleOverviewOpenedOrClosed(const QJsonObject& data) {
    const bool isOpen = data.value(QStringLiteral("is_open")).toBool();
    if (m_inOverview != isOpen) {
        m_inOverview = isOpen;
        emit inOverviewChanged();
    }
}

// ── Internal Helpers ─────────────────────────────────────────────────

void NiriIpc::updateCurrentOutputWorkspaces() {
    if (m_focusedMonitorName.isEmpty()) {
        m_currentOutputWorkspaces = m_workspaces;
        return;
    }

    m_currentOutputWorkspaces.clear();
    for (const auto& v : m_workspaces) {
        if (v.toMap().value(QStringLiteral("output")).toString() == m_focusedMonitorName) {
            m_currentOutputWorkspaces.append(v);
        }
    }
}

void NiriIpc::updateWorkspaceHasWindows() {
    QVariantMap newState;
    for (const auto& wsV : m_workspaces) {
        const auto ws = wsV.toMap();
        newState[QString::number(ws.value(QStringLiteral("idx")).toInt())] = false;
    }

    for (const auto& winV : m_windows) {
        const auto win = winV.toMap();
        const int wsId = win.value(QStringLiteral("workspace_id")).toInt();
        const int idx = getWorkspaceIdxById(wsId);
        if (idx >= 0) {
            newState[QString::number(idx)] = true;
        }
    }

    if (m_workspaceHasWindows != newState) {
        m_workspaceHasWindows = newState;
        emit workspaceHasWindowsChanged();
    }
}

void NiriIpc::updateFocusedWindowFields() {
    if (m_focusedWindowIndex >= 0 && m_focusedWindowIndex < m_windows.size()) {
        const auto win = m_windows.at(m_focusedWindowIndex).toMap();
        QString title = win.value(QStringLiteral("title")).toString();
        // Clean non-printable prefix characters
        while (!title.isEmpty() && title.at(0).unicode() < 0x20) {
            title.remove(0, 1);
        }
        m_focusedWindowTitle = title.isEmpty() ? QStringLiteral("(Unnamed window)") : title;
        m_focusedWindowClass = win.value(QStringLiteral("app_id")).toString();
        m_focusedWindow = win;

        // Track scroll direction
        const auto layout = win.value(QStringLiteral("layout")).toMap();
        const auto pos = layout.value(QStringLiteral("pos_in_scrolling_layout")).toList();
        if (pos.size() >= 2) {
            const int currentCol = pos.at(0).toInt();
            if (m_lastFocusedColumn >= 0) {
                const QString newDir = currentCol > m_lastFocusedColumn ? QStringLiteral("right")
                                     : currentCol < m_lastFocusedColumn ? QStringLiteral("left")
                                     : QStringLiteral("none");
                if (m_scrollDirection != newDir) {
                    m_scrollDirection = newDir;
                    emit scrollDirectionChanged();
                }
            }
            m_lastFocusedColumn = currentCol;
        }

        m_lastFocusedWindow = win;
        emit lastFocusedWindowChanged();
    } else {
        m_focusedWindowTitle.clear();
        m_focusedWindowClass = QStringLiteral("Desktop");
        m_focusedWindow.clear();
    }
    emit focusedWindowChanged();
}

void NiriIpc::sortWindowsList() {
    std::sort(m_windows.begin(), m_windows.end(), [](const QVariant& a, const QVariant& b) {
        const auto aLayout = a.toMap().value(QStringLiteral("layout")).toMap();
        const auto bLayout = b.toMap().value(QStringLiteral("layout")).toMap();
        const auto aPos = aLayout.value(QStringLiteral("pos_in_scrolling_layout")).toList();
        const auto bPos = bLayout.value(QStringLiteral("pos_in_scrolling_layout")).toList();
        const int ax = aPos.size() >= 1 ? aPos.at(0).toInt() : 0;
        const int ay = aPos.size() >= 2 ? aPos.at(1).toInt() : 0;
        const int bx = bPos.size() >= 1 ? bPos.at(0).toInt() : 0;
        const int by = bPos.size() >= 2 ? bPos.at(1).toInt() : 0;
        if (ax != bx) return ax < bx;
        return ay < by;
    });
}

// ── LED Watchers (capslock/numlock via /sys/class/leds) ──────────────

void NiriIpc::setupLedWatchers() {
    QDir ledsDir(QStringLiteral("/sys/class/leds"));
    if (!ledsDir.exists()) return;

    const auto entries = ledsDir.entryList(QDir::Dirs | QDir::NoDotAndDotDot);
    for (const auto& entry : entries) {
        const QString brightnessPath = ledsDir.filePath(entry) + QStringLiteral("/brightness");
        if (!QFile::exists(brightnessPath)) continue;

        if (entry.contains(QStringLiteral("capslock"), Qt::CaseInsensitive)) {
            m_capsLockPath = brightnessPath;
            m_ledWatcher.addPath(brightnessPath);
        } else if (entry.contains(QStringLiteral("numlock"), Qt::CaseInsensitive)) {
            m_numLockPath = brightnessPath;
            m_ledWatcher.addPath(brightnessPath);
        }
    }

    // Initial read
    readLedState();
}

void NiriIpc::readLedState() {
    auto readBrightness = [](const QString& path) -> bool {
        if (path.isEmpty()) return false;
        QFile file(path);
        if (!file.open(QIODevice::ReadOnly)) return false;
        const QByteArray data = file.readAll().trimmed();
        return data.toInt() > 0;
    };

    const bool newCaps = readBrightness(m_capsLockPath);
    const bool newNum = readBrightness(m_numLockPath);

    if (m_capsLock != newCaps) {
        m_capsLock = newCaps;
        emit capsLockChanged();
    }
    if (m_numLock != newNum) {
        m_numLock = newNum;
        emit numLockChanged();
    }
}

void NiriIpc::onLedFileChanged(const QString& path) {
    Q_UNUSED(path);
    readLedState();

    // QFileSystemWatcher may drop watches when files are replaced
    if (!m_capsLockPath.isEmpty() && !m_ledWatcher.files().contains(m_capsLockPath)) {
        m_ledWatcher.addPath(m_capsLockPath);
    }
    if (!m_numLockPath.isEmpty() && !m_ledWatcher.files().contains(m_numLockPath)) {
        m_ledWatcher.addPath(m_numLockPath);
    }
}

} // namespace caelestia
