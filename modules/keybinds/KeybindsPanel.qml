pragma ComponentBehavior: Bound

import qs.services
import Quickshell
import Quickshell.Io

// IPC handler for keybinds - delegates to the drawer system
Scope {
    id: root

    IpcHandler {
        target: "keybinds-panel"

        function open(): void {
            const visibilities = Visibilities.getForActive()
            visibilities.keybinds = true
        }

        function close(): void {
            const visibilities = Visibilities.getForActive()
            visibilities.keybinds = false
        }

        function toggle(): void {
            const visibilities = Visibilities.getForActive()
            visibilities.keybinds = !visibilities.keybinds
        }
    }
}
