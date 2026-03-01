#pragma once

#include "service.hpp"
#include <qqmlintegration.h>

namespace caelestia {

class ServiceRef : public QObject {
    Q_OBJECT
    QML_ELEMENT

    Q_PROPERTY(Service* service READ service WRITE setService NOTIFY serviceChanged)

public:
    explicit ServiceRef(Service* service = nullptr, QObject* parent = nullptr);
    ~ServiceRef();

    [[nodiscard]] Service* service() const;
    void setService(Service* service);

signals:
    void serviceChanged();

private:
    Service* m_service;
};

} // namespace caelestia
