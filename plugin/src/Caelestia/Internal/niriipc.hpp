#pragma once

#include "nirisocket.hpp"

#include <qjsonarray.h>
#include <qjsonobject.h>
#include <qobject.h>
#include <qqmlintegration.h>
#include <qtimer.h>
#include <qvariant.h>

namespace caelestia {

/// NiriIpc — QML singleton providing native IPC access to the niri compositor.
///
/// Replaces all Process-based niri msg spawning with a persistent socket.
/// Exposes the same property shape as the old QML services so consumers
/// can migrate transparently.
class NiriIpc : public QObject {
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON

    // ── Core ──
    Q_PROPERTY(bool available READ available NOTIFY availableChanged)

    // ── Workspaces ──
    Q_PROPERTY(QVariantList workspaces READ workspaces NOTIFY workspacesChanged)
    Q_PROPERTY(int focusedWorkspaceIndex READ focusedWorkspaceIndex NOTIFY focusedWorkspaceChanged)
    Q_PROPERTY(int focusedWorkspaceId READ focusedWorkspaceId NOTIFY focusedWorkspaceChanged)
    Q_PROPERTY(QString focusedMonitorName READ focusedMonitorName NOTIFY focusedWorkspaceChanged)
    Q_PROPERTY(QVariantList currentOutputWorkspaces READ currentOutputWorkspaces NOTIFY workspacesChanged)
    Q_PROPERTY(QVariantMap workspaceHasWindows READ workspaceHasWindows NOTIFY workspaceHasWindowsChanged)

    // ── Windows ──
    Q_PROPERTY(QVariantList windows READ windows NOTIFY windowsChanged)
    Q_PROPERTY(int focusedWindowIndex READ focusedWindowIndex NOTIFY focusedWindowChanged)
    Q_PROPERTY(QString focusedWindowId READ focusedWindowId NOTIFY focusedWindowChanged)
    Q_PROPERTY(QString focusedWindowTitle READ focusedWindowTitle NOTIFY focusedWindowChanged)
    Q_PROPERTY(QString focusedWindowClass READ focusedWindowClass NOTIFY focusedWindowChanged)
    Q_PROPERTY(QVariantMap focusedWindow READ focusedWindow NOTIFY focusedWindowChanged)
    Q_PROPERTY(QVariantMap lastFocusedWindow READ lastFocusedWindow NOTIFY lastFocusedWindowChanged)
    Q_PROPERTY(QString scrollDirection READ scrollDirection NOTIFY scrollDirectionChanged)
    Q_PROPERTY(bool inOverview READ inOverview NOTIFY inOverviewChanged)

    // ── Outputs ──
    Q_PROPERTY(QVariantMap outputs READ outputs NOTIFY outputsChanged)

    // ── Keyboard ──
    Q_PROPERTY(QVariantList kbLayoutsArray READ kbLayoutsArray NOTIFY keyboardChanged)
    Q_PROPERTY(int kbLayoutIndex READ kbLayoutIndex NOTIFY keyboardChanged)
    Q_PROPERTY(QString kbLayouts READ kbLayouts NOTIFY keyboardChanged)
    Q_PROPERTY(QString defaultKbLayout READ defaultKbLayout NOTIFY keyboardChanged)
    Q_PROPERTY(QString kbLayout READ kbLayout NOTIFY keyboardChanged)
    Q_PROPERTY(bool capsLock READ capsLock NOTIFY capsLockChanged)
    Q_PROPERTY(bool numLock READ numLock NOTIFY numLockChanged)

public:
    explicit NiriIpc(QObject* parent = nullptr);

    // ── Property getters ──
    [[nodiscard]] bool available() const;

    [[nodiscard]] QVariantList workspaces() const;
    [[nodiscard]] int focusedWorkspaceIndex() const;
    [[nodiscard]] int focusedWorkspaceId() const;
    [[nodiscard]] QString focusedMonitorName() const;
    [[nodiscard]] QVariantList currentOutputWorkspaces() const;
    [[nodiscard]] QVariantMap workspaceHasWindows() const;

    [[nodiscard]] QVariantList windows() const;
    [[nodiscard]] int focusedWindowIndex() const;
    [[nodiscard]] QString focusedWindowId() const;
    [[nodiscard]] QString focusedWindowTitle() const;
    [[nodiscard]] QString focusedWindowClass() const;
    [[nodiscard]] QVariantMap focusedWindow() const;
    [[nodiscard]] QVariantMap lastFocusedWindow() const;
    [[nodiscard]] QString scrollDirection() const;
    [[nodiscard]] bool inOverview() const;

    [[nodiscard]] QVariantMap outputs() const;

    [[nodiscard]] QVariantList kbLayoutsArray() const;
    [[nodiscard]] int kbLayoutIndex() const;
    [[nodiscard]] QString kbLayouts() const;
    [[nodiscard]] QString defaultKbLayout() const;
    [[nodiscard]] QString kbLayout() const;
    [[nodiscard]] bool capsLock() const;
    [[nodiscard]] bool numLock() const;

    // ── Actions (Q_INVOKABLE for QML) ──
    Q_INVOKABLE bool action(const QString& actionName, const QVariantList& args = {});

    // ── Workspace Helpers ──
    Q_INVOKABLE int getWorkspaceIdxById(int workspaceId) const;

signals:
    void availableChanged();
    void workspacesChanged();
    void focusedWorkspaceChanged();
    void workspaceHasWindowsChanged();
    void windowsChanged();
    void focusedWindowChanged();
    void lastFocusedWindowChanged();
    void scrollDirectionChanged();
    void inOverviewChanged();
    void outputsChanged();
    void keyboardChanged();
    void capsLockChanged();
    void numLockChanged();
    void windowOpenedOrChanged(const QVariantMap& windowData);

private slots:
    void onEventStreamConnected();
    void onEventStreamDisconnected();
    void onEvent(const QJsonObject& event);

private:
    void fetchInitialState();
    void handleWorkspacesChanged(const QJsonObject& data);
    void handleWindowsChanged(const QJsonObject& data);
    void handleWindowOpenedOrChanged(const QJsonObject& data);
    void handleWindowClosed(const QJsonObject& data);
    void handleWindowFocusChanged(const QJsonObject& data);
    void handleWindowLayoutsChanged(const QJsonObject& data);
    void handleOutputsChanged(const QJsonObject& data);
    void handleKeyboardLayoutsChanged(const QJsonObject& data);
    void handleOverviewOpenedOrClosed(const QJsonObject& data);

    void updateCurrentOutputWorkspaces();
    void updateWorkspaceHasWindows();
    void updateFocusedWindowFields();
    void sortWindowsList();
    void setupLedWatchers();
    void readLedState();

    NiriEventSocket m_eventSocket;
    NiriRequestSocket m_requestSocket;

    bool m_available = false;

    // Workspace state
    QVariantList m_workspaces;
    int m_focusedWorkspaceIndex = -1;
    int m_focusedWorkspaceId = -1;
    QString m_focusedMonitorName;
    QVariantList m_currentOutputWorkspaces;
    QVariantMap m_workspaceHasWindows;

    // Window state
    QVariantList m_windows;
    int m_focusedWindowIndex = -1;
    QString m_focusedWindowId;
    QString m_focusedWindowTitle;
    QString m_focusedWindowClass;
    QVariantMap m_focusedWindow;
    QVariantMap m_lastFocusedWindow;
    int m_lastFocusedColumn = -1;
    QString m_scrollDirection = QStringLiteral("none");
    bool m_inOverview = false;

    // Output state
    QVariantMap m_outputs;

    // Keyboard state
    QVariantList m_kbLayoutsArray;
    int m_kbLayoutIndex = 0;
    QString m_kbLayouts = QStringLiteral("?");

    // LED state
    bool m_capsLock = false;
    bool m_numLock = false;
    QTimer m_ledPollTimer;
    QString m_capsLockPath;
    QString m_numLockPath;
};

} // namespace caelestia
