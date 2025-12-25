pragma ComponentBehavior: Bound

import qs.services
import Quickshell
import Quickshell.Io

Scope {
    id: root

    IpcHandler {
        target: "quicktoggles"

        function open(): void {
            const visibilities = Visibilities.getForActive()
            visibilities.quicktoggles = true
        }

        function close(): void {
            const visibilities = Visibilities.getForActive()
            visibilities.quicktoggles = false
        }

        function toggle(): void {
            const visibilities = Visibilities.getForActive()
            visibilities.quicktoggles = !visibilities.quicktoggles
        }
    }
}
