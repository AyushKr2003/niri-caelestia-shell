//@ pragma Env QS_NO_RELOAD_POPUP=1
//@ pragma Env QSG_RENDER_LOOP=threaded
//@ pragma Env QT_QUICK_FLICKABLE_WHEEL_DECELERATION=10000

import "modules"
import "modules/drawers"
import "modules/areapicker"
import "modules/lock"
import "modules/clipboard"
import "modules/quicktoggles"
import "modules/keybinds"
import "modules/background"
import qs.modules.controlcenter
import qs.services
// import "./modules/sidebarLeft/"
// import "./modules/sidebarRight/"

import Quickshell

ShellRoot {
    // property bool enableSidebarLeft: true
    // property bool enableSidebarRight: false
    Backdrop {}
    Background {}
    Drawers {}
    AreaPicker {}
    Lock {}

    Shortcuts {}
    ClipboardPanel {}
    QuickTogglesPanel {}
    KeybindsPanel {}
    
    // Initialize BatteryMonitor service
    property var _batteryMonitor: BatteryMonitor
    // LazyLoader { active: enableSidebarLeft; component: SidebarLeft {} }
    // LazyLoader { active: enableSidebarRight; component: SidebarRight {} }
}
