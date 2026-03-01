#include "service.hpp"

#include <qdebug.h>

namespace caelestia {

Service::Service(QObject* parent)
    : QObject(parent)
    , m_refCount(0) {}

int Service::refCount() {
    QMutexLocker locker(&m_mutex);
    return m_refCount;
}

void Service::ref() {
    bool needsStart = false;

    {
        QMutexLocker locker(&m_mutex);
        if (m_refCount == 0) {
            needsStart = true;
        }
        m_refCount++;
    }
    emit refCountChanged();

    if (needsStart) {
        QMetaObject::invokeMethod(this, &Service::start, Qt::QueuedConnection);
    }
}

void Service::unref() {
    bool needsStop = false;

    {
        QMutexLocker locker(&m_mutex);
        if (m_refCount == 0) {
            qWarning() << "ServiceRef::unref: attempted to unref service with no active refs";
            return;
        }
        m_refCount--;
        if (m_refCount == 0) {
            needsStop = true;
        }
    }
    emit refCountChanged();

    if (needsStop) {
        QMetaObject::invokeMethod(this, &Service::stop, Qt::QueuedConnection);
    }
}

} // namespace caelestia
