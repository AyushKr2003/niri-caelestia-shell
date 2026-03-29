#!/usr/bin/env python3
import sys
import os
import logging
import dbus
from io import StringIO

# This script monkey-patches kde-material-you-colors to handle cases where
# KDE Plasma components (like KWin) are not available, preventing crashes.
# It also mocks 'stty size' calls that fail in non-interactive shells.

def patch_kde_material_you_colors():
    # Configure logging to be less noisy and use stdout for info to avoid Quickshell "error" triggers
    logger = logging.getLogger()
    logger.setLevel(logging.INFO)
    handler = logging.StreamHandler(sys.stdout)
    handler.setFormatter(logging.Formatter('[PatchedKMYC] %(levelname)s: %(message)s'))
    logger.addHandler(handler)

    # 1. Mock 'stty size' to avoid noisy warnings in non-interactive environments
    original_popen = os.popen
    def safe_popen(cmd, mode='r', buffering=-1):
        if "stty size" in cmd:
            return StringIO("24 80")
        return original_popen(cmd, mode, buffering)
    os.popen = safe_popen

    # 2. Patch KWin reload logic
    try:
        from kde_material_you_colors.utils import kwin_utils
        
        def safe_reload():
            logging.info("Reloading KWin (Patched/Safe)")
            try:
                bus = dbus.SessionBus()
                kwin = dbus.Interface(
                    bus.get_object("org.kde.KWin", "/KWin"),
                    dbus_interface="org.kde.KWin",
                )
                kwin.reconfigure()
                logging.info("KWin reconfigured successfully")
            except dbus.DBusException as e:
                # Still log but at INFO level to stdout, so it's not a "WARN" in Quickshell
                logging.info(f"KWin not found on DBus, skipping reload: {e.get_dbus_message()}")
            except Exception as e:
                logging.debug(f"Unexpected error while reloading KWin: {e}")
                
        kwin_utils.reload = safe_reload
        
        def safe_klassy_update():
            try:
                path = "/KlassyDecoration"
                interface = "org.kde.Klassy.Style"
                method = "updateDecorationColorCache"
                msg = dbus.lowlevel.SignalMessage(path, interface, method)
                dbus.SessionBus().send_message(msg)
            except Exception:
                pass

        kwin_utils.klassy_update_decoration_color_cache = safe_klassy_update
        
    except ImportError:
        pass

    # 3. Patch Plasma scheme application
    try:
        from kde_material_you_colors.utils import plasma_utils
        
        original_apply = plasma_utils.apply_color_schemes
        def safe_apply_color_schemes(light=False):
            try:
                original_apply(light)
            except Exception as e:
                logging.info(f"Could not apply color schemes (expected outside KDE): {e}")
        
        plasma_utils.apply_color_schemes = safe_apply_color_schemes
    except ImportError:
        pass

if __name__ == "__main__":
    patch_kde_material_you_colors()
    
    # Now run the main tool
    try:
        from kde_material_you_colors.main import main
        # Ensure sys.argv[0] is correct for the internal argparse
        sys.argv[0] = 'kde-material-you-colors'
        sys.exit(main())
    except Exception as e:
        # Only real unexpected crashes go to stderr now
        print(f"[PatchedKMYC] FATAL ERROR: {e}", file=sys.stderr)
        sys.exit(1)
