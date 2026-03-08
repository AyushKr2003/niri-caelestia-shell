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

// ── NiriListModel ────────────────────────────────────────────────────

NiriListModel::NiriListModel(QObject* parent) : QAbstractListModel(parent) {}

QHash<int, QByteArray> NiriListModel::roleNames() const {
    return { {ObjectRole, "modelData"} };
}

int NiriListModel::rowCount(const QModelIndex& parent) const {
    Q_UNUSED(parent);
    return m_items.size();
}

QVariant NiriListModel::data(const QModelIndex& index, int role) const {
    if (!index.isValid() || index.row() >= m_items.size() || index.row() < 0) return {};
    if (role == ObjectRole) return m_items.at(index.row());
    return {};
}

void NiriListModel::resetData(const QVariantList& items) {
    beginResetModel();
    m_items = items;
    endResetModel();
}

void NiriListModel::appendItem(const QVariantMap& item) {
    beginInsertRows(QModelIndex(), m_items.size(), m_items.size());
    m_items.append(item);
    endInsertRows();
}

void NiriListModel::setItem(int idx, const QVariantMap& item) {
    if (idx < 0 || idx >= m_items.size()) return;
    m_items[idx] = item;
    emit dataChanged(index(idx), index(idx), {ObjectRole});
}

void NiriListModel::removeItem(int idx) {
    if (idx < 0 || idx >= m_items.size()) return;
    beginRemoveRows(QModelIndex(), idx, idx);
    m_items.removeAt(idx);
    endRemoveRows();
}

const QVariantList& NiriListModel::items() const {
    return m_items;
}

// ── NiriIpc ──────────────────────────────────────────────────────────

NiriIpc::NiriIpc(QObject* parent)
    : QObject(parent)
    , m_eventSocket(this)
    , m_requestSocket(this) {

    m_workspacesModel = new NiriListModel(this);
    m_windowsModel = new NiriListModel(this);

    connect(&m_eventSocket, &NiriEventSocket::connected, this, &NiriIpc::onEventStreamConnected);
    connect(&m_eventSocket, &NiriEventSocket::disconnected, this, &NiriIpc::onEventStreamDisconnected);
    connect(&m_eventSocket, &NiriEventSocket::eventReceived, this, &NiriIpc::onEvent);

    setupLedWatchers();
    m_eventSocket.connectToNiri();
}

// ── Property getters ─────────────────────────────────────────────────

bool NiriIpc::available() const { return m_available; }

QAbstractListModel* NiriIpc::workspacesModel() const { return m_workspacesModel; }
QVariantList NiriIpc::workspaces() const { return m_workspacesModel->items(); }
int NiriIpc::focusedWorkspaceIndex() const { return m_focusedWorkspaceIndex; }
int NiriIpc::focusedWorkspaceId() const { return m_focusedWorkspaceId; }
QString NiriIpc::focusedMonitorName() const { return m_focusedMonitorName; }
QVariantList NiriIpc::currentOutputWorkspaces() const { return m_currentOutputWorkspaces; }
QVariantMap NiriIpc::workspaceHasWindows() const { return m_workspaceHasWindows; }

QAbstractListModel* NiriIpc::windowsModel() const { return m_windowsModel; }
QVariantList NiriIpc::windows() const { return m_windowsModel->items(); }
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
    const auto& wsList = m_workspacesModel->items();
    for (const auto& v : wsList) {
        const auto ws = v.toMap();
        if (ws.value(QStringLiteral("id")).toInt() == workspaceId) {
            return ws.value(QStringLiteral("idx")).toInt();
        }
    }
    return -1;
}

QVariantList NiriIpc::getWindowsByWorkspaceId(int wsId) const {
    QVariantList res;
    const auto& wins = m_windowsModel->items();
    for (const auto& w : wins) {
        auto map = w.toMap();
        if (map.value(QStringLiteral("workspace_id")).toInt() == wsId) {
            res.append(w);
        }
    }
    return res;
}

QVariantList NiriIpc::getWindowsByWorkspaceIndex(int index) const {
    const auto& wsList = m_workspacesModel->items();
    if (index < 0 || index >= wsList.size()) return {};
    int wsId = wsList.at(index).toMap().value(QStringLiteral("id")).toInt();
    return getWindowsByWorkspaceId(wsId);
}

QVariantList NiriIpc::getActiveWorkspaceWindows() const {
    if (m_focusedWorkspaceId < 0) return {};
    return getWindowsByWorkspaceId(m_focusedWorkspaceId);
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
        
        QVariantList currentWs = m_workspacesModel->items();
        for (int i = 0; i < currentWs.size(); ++i) {
            auto ws = currentWs.at(i).toMap();
            if (ws.value(QStringLiteral("id")).toInt() == id) {
                m_focusedWorkspaceIndex = i;
                m_focusedMonitorName = ws.value(QStringLiteral("output")).toString();
                // Update active/focused flags on same output
                const QString output = m_focusedMonitorName;
                for (int j = 0; j < currentWs.size(); ++j) {
                    auto w = currentWs.at(j).toMap();
                    if (w.value(QStringLiteral("output")).toString() == output) {
                        w[QStringLiteral("is_active")] = (j == i);
                        w[QStringLiteral("is_focused")] = (j == i);
                        currentWs[j] = w;
                        m_workspacesModel->setItem(j, w);
                    }
                }
                break;
            }
        }
        updateCurrentOutputWorkspaces();
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

    m_workspacesModel->resetData(wsList);

    // Find focused workspace
    m_focusedWorkspaceIndex = -1;
    m_focusedWorkspaceId = -1;
    for (int i = 0; i < wsList.size(); ++i) {
        const auto ws = wsList.at(i).toMap();
        if (ws.value(QStringLiteral("is_focused")).toBool()) {
            m_focusedWorkspaceIndex = i;
            m_focusedWorkspaceId = ws.value(QStringLiteral("id")).toInt();
            m_focusedMonitorName = ws.value(QStringLiteral("output")).toString();
            break;
        }
    }

    if (m_focusedWorkspaceIndex < 0 && !wsList.isEmpty()) {
        m_focusedWorkspaceIndex = 0;
    }

    updateCurrentOutputWorkspaces();
    updateWorkspaceHasWindows();
    emit workspacesChanged();
    emit focusedWorkspaceChanged();
}

void NiriIpc::handleWindowsChanged(const QJsonObject& data) {
    const QJsonArray winArray = data.value(QStringLiteral("windows")).toArray();
    QVariantList winList = jsonArrayToVariantList(winArray);

    // Ensure all windows have a layout object
    for (int i = 0; i < winList.size(); ++i) {
        auto w = winList.at(i).toMap();
        if (!w.contains(QStringLiteral("layout"))) {
            w[QStringLiteral("layout")] = QVariantMap();
            winList[i] = w;
        }
    }

    m_windowsModel->resetData(winList);

    sortWindowsList();
    rebuildWindowIndex();
    updateFocusedWindowFields();
    updateWorkspaceHasWindows();
    emit windowsChanged();
}

void NiriIpc::handleWindowOpenedOrChanged(const QJsonObject& data) {
    const QJsonObject winObj = data.value(QStringLiteral("window")).toObject();
    if (winObj.isEmpty()) return;

    const QVariantMap window = jsonObjectToVariantMap(winObj);
    const qint64 winId = window.value(QStringLiteral("id")).toLongLong();

    // O(1) lookup via hash index
    const int existingIdx = findWindowIndexById(winId);

    if (existingIdx >= 0) {
        // Merge updated fields into existing
        auto existing = m_windowsModel->items().at(existingIdx).toMap();
        for (auto it = window.begin(); it != window.end(); ++it) {
            existing[it.key()] = it.value();
        }
        m_windowsModel->setItem(existingIdx, existing);
    } else {
        m_windowsModel->appendItem(window);
    }

    sortWindowsList();
    rebuildWindowIndex();

    if (window.value(QStringLiteral("is_focused")).toBool()) {
        m_focusedWindowId = QString::number(winId);
        m_focusedWindowIndex = findWindowIndexById(winId);
    }

    updateFocusedWindowFields();
    updateWorkspaceHasWindows();
    emit windowsChanged();
    emit windowOpenedOrChanged(window);
}

void NiriIpc::handleWindowClosed(const QJsonObject& data) {
    const qint64 closedId = data.value(QStringLiteral("id")).toInteger();

    // O(1) lookup via hash
    const int idx = findWindowIndexById(closedId);
    if (idx >= 0) {
        m_windowsModel->removeItem(idx);
        rebuildWindowIndex();
    }

    updateFocusedWindowFields();
    updateWorkspaceHasWindows();
    emit windowsChanged();
}

void NiriIpc::handleWindowFocusChanged(const QJsonObject& data) {
    if (data.contains(QStringLiteral("id")) && !data.value(QStringLiteral("id")).isNull()) {
        const qint64 id = data.value(QStringLiteral("id")).toInteger();
        m_focusedWindowId = QString::number(id);
        m_focusedWindowIndex = findWindowIndexById(id);
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

        const qint64 id = pair.at(0).toInteger();
        const auto layout = pair.at(1).toObject().toVariantMap();

        // O(1) lookup via hash index
        const int idx = findWindowIndexById(id);
        if (idx >= 0) {
            auto w = m_windowsModel->items().at(idx).toMap();
            w[QStringLiteral("layout")] = layout;
            m_windowsModel->setItem(idx, w);
        }
    }

    sortWindowsList();
    rebuildWindowIndex();

    // Re-find focused index after sort via hash
    if (!m_focusedWindowId.isEmpty()) {
        m_focusedWindowIndex = findWindowIndexById(m_focusedWindowId.toLongLong());
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
        m_currentOutputWorkspaces = m_workspacesModel->items();
        return;
    }

    m_currentOutputWorkspaces.clear();
    const auto& wsList = m_workspacesModel->items();
    for (const auto& v : wsList) {
        if (v.toMap().value(QStringLiteral("output")).toString() == m_focusedMonitorName) {
            m_currentOutputWorkspaces.append(v);
        }
    }
}

void NiriIpc::updateWorkspaceHasWindows() {
    QVariantMap newState;
    const auto& wsList = m_workspacesModel->items();
    for (const auto& wsV : wsList) {
        const auto ws = wsV.toMap();
        newState[QString::number(ws.value(QStringLiteral("idx")).toInt())] = false;
    }

    const auto& winList = m_windowsModel->items();
    for (const auto& winV : winList) {
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
    const auto& winList = m_windowsModel->items();
    if (m_focusedWindowIndex >= 0 && m_focusedWindowIndex < winList.size()) {
        const auto win = winList.at(m_focusedWindowIndex).toMap();
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
    QVariantList winList = m_windowsModel->items();
    std::sort(winList.begin(), winList.end(), [](const QVariant& a, const QVariant& b) {
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
    m_windowsModel->resetData(winList);
}

void NiriIpc::rebuildWindowIndex() {
    m_windowIndex.clear();
    const auto& winList = m_windowsModel->items();
    m_windowIndex.reserve(winList.size());
    for (int i = 0; i < winList.size(); ++i) {
        const qint64 id = winList.at(i).toMap().value(QStringLiteral("id")).toLongLong();
        m_windowIndex.insert(id, i);
    }
}

int NiriIpc::findWindowIndexById(qint64 id) const {
    auto it = m_windowIndex.find(id);
    return (it != m_windowIndex.end()) ? it.value() : -1;
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
        } else if (entry.contains(QStringLiteral("numlock"), Qt::CaseInsensitive)) {
            m_numLockPath = brightnessPath;
        }
    }

    // Initial read
    readLedState();

    // Poll sysfs since inotify doesn't work on virtual files
    if (!m_capsLockPath.isEmpty() || !m_numLockPath.isEmpty()) {
        m_ledPollTimer.setInterval(1000);
        connect(&m_ledPollTimer, &QTimer::timeout, this, &NiriIpc::readLedState);
        m_ledPollTimer.start();
    }
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

} // namespace caelestia
