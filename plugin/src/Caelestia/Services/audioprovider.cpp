#include "audioprovider.hpp"

#include "audiocollector.hpp"
#include "service.hpp"
#include <qdebug.h>
#include <qthread.h>

namespace caelestia {

AudioProcessor::AudioProcessor(QObject* parent)
    : QObject(parent)
    , m_sampleRate(AudioCollector::instance()->sampleRate())
    , m_chunkSize(AudioCollector::instance()->chunkSize()) {}

AudioProcessor::~AudioProcessor() {
    stop();
}

void AudioProcessor::init() {
    m_timer = new QTimer(this);
    m_timer->setInterval(static_cast<int>(m_chunkSize * 1000.0 / m_sampleRate));
    connect(m_timer, &QTimer::timeout, this, &AudioProcessor::process);
}

void AudioProcessor::start() {
    AudioCollector::instance()->ref();
    if (m_timer) {
        m_timer->start();
    }
}

void AudioProcessor::stop() {
    if (m_timer) {
        m_timer->stop();
    }
    AudioCollector::instance()->unref();
}

AudioProvider::AudioProvider(QObject* parent)
    : Service(parent)
    , m_processor(nullptr)
    , m_thread(nullptr) {}

AudioProvider::~AudioProvider() {
    if (m_thread) {
        m_thread->quit();
        m_thread->wait();
    }
}

void AudioProvider::init() {
    if (!m_processor) {
        qWarning() << "AudioProvider::init: attempted to init with no processor set";
        return;
    }

    m_thread = new QThread(this);
    m_processor->moveToThread(m_thread);

    connect(m_thread, &QThread::started, m_processor, &AudioProcessor::init);
    connect(m_thread, &QThread::finished, m_processor, &AudioProcessor::deleteLater);
    connect(m_thread, &QThread::finished, m_thread, &QThread::deleteLater);

    m_thread->start();
}

void AudioProvider::start() {
    if (m_processor) {
        QMetaObject::invokeMethod(m_processor, "start", Qt::QueuedConnection);
    }
}

void AudioProvider::stop() {
    if (m_processor) {
        QMetaObject::invokeMethod(m_processor, "stop", Qt::QueuedConnection);
    }
}

} // namespace caelestia
