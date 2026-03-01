pragma Singleton

import qs.config
import Caelestia.Services
import Quickshell

Singleton {
    id: root

    readonly property alias provider: provider
    readonly property alias values: provider.values

    CavaProvider {
        id: provider

        bars: Config.services.visualiserBars
    }
}
