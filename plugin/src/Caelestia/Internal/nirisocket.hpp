#pragma once

#include <qbytearray.h>
#include <qlocalsocket.h>
#include <qobject.h>
#include <qtimer.h>

#include <deque>
#include <functional>

namespace caelestia {

/// Dedicated EventStream connection to niri's IPC socket.
/// Connects, sends "EventStream", then emits events continuously.
class NiriEventSocket : public QObject {
    Q_OBJECT

public:
    explicit NiriEventSocket(QObject* parent = nullptr);

    void connectToNiri();
    void disconnectFromNiri();
    [[nodiscard]] bool isConnected() const;

signals:
    void connected();
    void disconnected();
    void eventReceived(const QJsonObject& event);

private slots:
    void onConnected();
    void onDisconnected();
    void onReadyRead();
    void onError(QLocalSocket::LocalSocketError error);

private:
    void processLine(const QByteArray& line);
    void scheduleReconnect();

    QLocalSocket* m_socket = nullptr;
    QTimer m_reconnectTimer;
    QByteArray m_readBuffer;
    int m_reconnectDelay = 1000;
    bool m_handshakeDone = false;
};

/// Request/action connection to niri's IPC socket.
/// Each request opens a fresh connection, sends the payload, reads response, closes.
/// This avoids conflicts with the EventStream socket.
class NiriRequestSocket : public QObject {
    Q_OBJECT

public:
    using Callback = std::function<void(bool ok, const QJsonObject& response)>;

    explicit NiriRequestSocket(QObject* parent = nullptr);

    /// Send a request and receive response via callback.
    void request(const QByteArray& payload, Callback callback);

    /// Send an action (fire-and-forget, response discarded).
    void action(const QByteArray& payload);

private:
    struct PendingRequest {
        QByteArray payload;
        Callback callback; // nullptr for fire-and-forget
    };

    void processQueue();
    void startRequest(const PendingRequest& req);

    std::deque<PendingRequest> m_queue;
    bool m_busy = false;
};

} // namespace caelestia
