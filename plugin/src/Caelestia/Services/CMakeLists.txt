qml_module(caelestia-services
    URI Caelestia.Services
    SOURCES
        service.hpp service.cpp
        serviceref.hpp serviceref.cpp
        beattracker.hpp beattracker.cpp
        audiocollector.hpp audiocollector.cpp
        audioprovider.hpp audioprovider.cpp
        cavaprovider.hpp cavaprovider.cpp
        sysmonitor.hpp sysmonitor.cpp
    LIBRARIES
        PkgConfig::Pipewire
        PkgConfig::Aubio
        PkgConfig::Cava
)
