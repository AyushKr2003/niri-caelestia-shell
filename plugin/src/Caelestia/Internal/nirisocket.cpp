#include "nirisocket.hpp"

#include <qdebug.h>
#include <qjsondocument.h>
#include <qjsonobject.h>
#include <qlocalsocket.h>
#include <QProcessEnvironment>

namespace caelestia {

static QString niriSocketPath() {
    return QProcessEnvironment::systemEnvironment().value(QStringLiteral("NIRI_SOCKET"));
}

// ── NiriEventSocket ──────────────────────────────────────────────────

NiriEventSocket::NiriEventSocket(QObject* parent)
    : QObject(parent)
    , m_socket(new QLocalSocket(this)) {

    m_reconnectTimer.setSingleShot(true);
    connect(&m_reconnectTimer, &QTimer::timeout, this, &NiriEventSocket::connectToNiri);

    connect(m_socket, &QLocalSocket::connected, this, &NiriEventSocket::onConnected);
    connect(m_socket, &QLocalSocket::disconnected, this, &NiriEventSocket::onDisconnected);
    connect(m_socket, &QLocalSocket::readyRead, this, &NiriEventSocket::onReadyRead);
    connect(m_socket, &QLocalSocket::errorOccurred, this, &NiriEventSocket::onError);
}

void NiriEventSocket::connectToNiri() {
    const QString path = niriSocketPath();
    if (path.isEmpty()) {
        qWarning() << "NiriEventSocket: NIRI_SOCKET not set";
        return;
    }

    if (m_socket->state() != QLocalSocket::UnconnectedState) {
        m_socket->abort();
    }

    m_readBuffer.clear();
    m_handshakeDone = false;
    m_reconnectDelay = 1000;
    m_socket->connectToServer(path);
}

void NiriEventSocket::disconnectFromNiri() {
    m_reconnectTimer.stop();
    if (m_socket->state() != QLocalSocket::UnconnectedState) {
        m_socket->abort();
    }
}

bool NiriEventSocket::isConnected() const {
    return m_socket->state() == QLocalSocket::ConnectedState && m_handshakeDone;
}

void NiriEventSocket::onConnected() {
    qDebug() << "NiriEventSocket: Connected, starting event stream";
    m_socket->write("\"EventStream\"\n");
    m_socket->flush();
}

void NiriEventSocket::onDisconnected() {
    qDebug() << "NiriEventSocket: Disconnected";
    m_handshakeDone = false;
    emit disconnected();
    scheduleReconnect();
}

void NiriEventSocket::onReadyRead() {
    m_readBuffer.append(m_socket->readAll());

    int pos;
    while ((pos = static_cast<int>(m_readBuffer.indexOf('\n'))) != -1) {
        const QByteArray line = m_readBuffer.left(pos).trimmed();
        m_readBuffer.remove(0, pos + 1);
        if (!line.isEmpty()) {
            processLine(line);
        }
    }
}

void NiriEventSocket::processLine(const QByteArray& line) {
    QJsonParseError err;
    const QJsonDocument doc = QJsonDocument::fromJson(line, &err);
    if (err.error != QJsonParseError::NoError) {
        qWarning() << "NiriEventSocket: JSON parse error:" << err.errorString();
        return;
    }

    const QJsonObject obj = doc.object();

    if (!m_handshakeDone) {
        // First response is {"Ok":"Handled"} for EventStream
        m_handshakeDone = true;
        m_reconnectDelay = 1000;
        qDebug() << "NiriEventSocket: Event stream active";
        emit connected();
        return;
    }

    emit eventReceived(obj);
}

void NiriEventSocket::onError(QLocalSocket::LocalSocketError error) {
    if (error == QLocalSocket::PeerClosedError) return;
    qWarning() << "NiriEventSocket: Error:" << m_socket->errorString();
    scheduleReconnect();
}

void NiriEventSocket::scheduleReconnect() {
    if (!m_reconnectTimer.isActive()) {
        qDebug() << "NiriEventSocket: Reconnecting in" << m_reconnectDelay << "ms";
        m_reconnectTimer.start(m_reconnectDelay);
        m_reconnectDelay = qMin(m_reconnectDelay * 2, 30000);
    }
}

// ── NiriRequestSocket ────────────────────────────────────────────────

NiriRequestSocket::NiriRequestSocket(QObject* parent)
    : QObject(parent) {}

void NiriRequestSocket::request(const QByteArray& payload, Callback callback) {
    m_queue.push_back({payload, std::move(callback)});
    if (!m_busy) {
        processQueue();
    }
}

void NiriRequestSocket::action(const QByteArray& payload) {
    m_queue.push_back({payload, nullptr});
    if (!m_busy) {
        processQueue();
    }
}

void NiriRequestSocket::processQueue() {
    if (m_queue.empty()) {
        m_busy = false;
        return;
    }

    m_busy = true;
    auto req = std::move(m_queue.front());
    m_queue.pop_front();
    startRequest(req);
}

void NiriRequestSocket::startRequest(const PendingRequest& req) {
    const QString path = niriSocketPath();
    if (path.isEmpty()) {
        qWarning() << "NiriRequestSocket: NIRI_SOCKET not set";
        if (req.callback) req.callback(false, QJsonObject());
        processQueue();
        return;
    }

    auto* sock = new QLocalSocket(this);
    auto payload = req.payload;
    auto callback = req.callback;

    connect(sock, &QLocalSocket::connected, this, [sock, payload]() {
        sock->write(payload + "\n");
        sock->flush();
    });

    auto* buffer = new QByteArray();

    connect(sock, &QLocalSocket::readyRead, this, [sock, buffer]() {
        buffer->append(sock->readAll());
        if (buffer->contains('\n')) {
            sock->disconnectFromServer();
        }
    });

    connect(sock, &QLocalSocket::disconnected, this, [this, sock, buffer, callback]() {
        if (callback) {
            const QByteArray line = buffer->trimmed();
            QJsonParseError err;
            const QJsonDocument doc = QJsonDocument::fromJson(line, &err);
            if (err.error != QJsonParseError::NoError) {
                qWarning() << "NiriRequestSocket: JSON parse error:" << err.errorString();
                callback(false, QJsonObject());
            } else {
                const QJsonObject obj = doc.object();
                const bool ok = obj.contains(QStringLiteral("Ok"));
                callback(ok, ok ? QJsonObject{{QStringLiteral("result"), obj.value(QStringLiteral("Ok"))}}
                               : obj);
            }
        }
        delete buffer;
        sock->deleteLater();
        processQueue();
    });

    connect(sock, &QLocalSocket::errorOccurred, this, [this, sock, buffer, callback](QLocalSocket::LocalSocketError) {
        qWarning() << "NiriRequestSocket: Error:" << sock->errorString();
        if (callback) callback(false, QJsonObject());
        delete buffer;
        sock->deleteLater();
        processQueue();
    });

    sock->connectToServer(path);
}

} // namespace caelestia
