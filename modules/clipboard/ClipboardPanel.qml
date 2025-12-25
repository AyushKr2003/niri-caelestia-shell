pragma ComponentBehavior: Bound

import qs.services
import Quickshell
import Quickshell.Io

// IPC handler for clipboard - delegates to the drawer system
Scope {
    id: root

    IpcHandler {
        target: "clipboard"

        function open(): void {
            const visibilities = Visibilities.getForActive()
            visibilities.clipboard = true
        }

        function close(): void {
            const visibilities = Visibilities.getForActive()
            visibilities.clipboard = false
        }

        function toggle(): void {
            const visibilities = Visibilities.getForActive()
            visibilities.clipboard = !visibilities.clipboard
        }
    }
}
