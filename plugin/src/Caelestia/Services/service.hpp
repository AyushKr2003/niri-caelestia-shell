#pragma once

#include <qmutex.h>
#include <qobject.h>
namespace caelestia {

class Service : public QObject {
    Q_OBJECT

    Q_PROPERTY(int refCount READ refCount NOTIFY refCountChanged)

public:
    explicit Service(QObject* parent = nullptr);

    [[nodiscard]] int refCount();

    void ref();
    void unref();

signals:
    void refCountChanged();

private:
    int m_refCount;
    QMutex m_mutex;

    virtual void start() = 0;
    virtual void stop() = 0;
};

} // namespace caelestia
