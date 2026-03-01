#pragma once

#include "service.hpp"
#include <cstdint>
#include <qqmlintegration.h>
#include <qtimer.h>

namespace caelestia {

class AudioProcessor : public QObject {
    Q_OBJECT

public:
    explicit AudioProcessor(QObject* parent = nullptr);
    ~AudioProcessor();

    void init();

protected:
    uint32_t m_sampleRate;
    uint32_t m_chunkSize;

private:
    QTimer* m_timer;

    Q_INVOKABLE void start();
    Q_INVOKABLE void stop();

    virtual void process() = 0;
};

class AudioProvider : public Service {
    Q_OBJECT

public:
    explicit AudioProvider(QObject* parent = nullptr);
    ~AudioProvider();

protected:
    AudioProcessor* m_processor;

    void init();

private:
    QThread* m_thread;

    void start() override;
    void stop() override;
};

} // namespace caelestia
