#include "beattracker.hpp"

#include "audiocollector.hpp"
#include "audioprovider.hpp"
#include <aubio/aubio.h>

namespace caelestia {

BeatProcessor::BeatProcessor(QObject* parent)
    : AudioProcessor(parent)
    , m_tempo(new_aubio_tempo("default", 1024, m_chunkSize, m_sampleRate))
    , m_in(new_fvec(m_chunkSize))
    , m_out(new_fvec(2)) {};

BeatProcessor::~BeatProcessor() {
    del_aubio_tempo(m_tempo);
    del_fvec(m_in);
    del_fvec(m_out);
}

void BeatProcessor::process() {
    AudioCollector::instance()->readChunk(m_in->data, m_chunkSize);

    aubio_tempo_do(m_tempo, m_in, m_out);
    if (m_out->data[0] != 0.0f) {
        emit beat(aubio_tempo_get_bpm(m_tempo));
    }
}

BeatTracker::BeatTracker(QObject* parent)
    : AudioProvider(parent)
    , m_bpm(120) {
    m_processor = new BeatProcessor();
    init();

    connect(static_cast<BeatProcessor*>(m_processor), &BeatProcessor::beat, this, &BeatTracker::updateBpm);
}

smpl_t BeatTracker::bpm() const {
    return m_bpm;
}

void BeatTracker::updateBpm(smpl_t bpm) {
    if (!qFuzzyCompare(bpm + 1.0f, m_bpm + 1.0f)) {
        m_bpm = bpm;
        emit bpmChanged();
    }
}

} // namespace caelestia
