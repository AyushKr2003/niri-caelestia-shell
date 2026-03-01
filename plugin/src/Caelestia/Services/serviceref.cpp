#include "serviceref.hpp"

#include "service.hpp"

namespace caelestia {

ServiceRef::ServiceRef(Service* service, QObject* parent)
    : QObject(parent)
    , m_service(service) {
    if (m_service) {
        m_service->ref();
    }
}

ServiceRef::~ServiceRef() {
    if (m_service) {
        m_service->unref();
    }
}

Service* ServiceRef::service() const {
    return m_service;
}

void ServiceRef::setService(Service* service) {
    if (m_service == service) {
        return;
    }

    if (m_service) {
        m_service->unref();
    }

    m_service = service;
    emit serviceChanged();

    if (m_service) {
        m_service->ref();
    }
}

} // namespace caelestia
