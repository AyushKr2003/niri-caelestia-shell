"""
Config manager — reads/writes ~/.config/wallhaven/config.toml
Falls back to a simple key=value parser if tomllib is unavailable.
"""

import os
import logging
from pathlib import Path
from typing import Any, Optional

log = logging.getLogger(__name__)

# tomllib: stdlib on 3.11+, else try tomli, else manual fallback
try:
    import tomllib
    _HAS_TOML = True
except ImportError:
    try:
        import tomli as tomllib      # type: ignore
        _HAS_TOML = True
    except ImportError:
        _HAS_TOML = False

try:
    import tomli_w as _tomliw
    def _dumps(d: dict) -> str:
        return _tomliw.dumps(d)
except ImportError:
    def _dumps(d: dict) -> str:      # type: ignore[misc]
        lines = []
        for k, v in d.items():
            if v is None:
                continue
            if isinstance(v, bool):
                lines.append(f"{k} = {'true' if v else 'false'}")
            elif isinstance(v, (int, float)):
                lines.append(f"{k} = {v}")
            else:
                lines.append(f'{k} = "{v}"')
        return "\n".join(lines) + "\n"

# ── defaults ──────────────────────────────────────────────────────────────

DEFAULTS: dict = {
    "api_key":            "",
    "download_dir":       str(Path.home() / "Pictures" / "wallhaven"),
    "workers":            3,
    "skip_existing":      True,
    "default_resolution": "",      # e.g. "1920x1080"
    "default_ratio":      "",      # e.g. "16x9"
    "default_purity":     "sfw",
    "default_sorting":    "date_added",
    "verbose":            False,
}

_CONFIG_PATH = Path(
    os.environ.get("XDG_CONFIG_HOME", str(Path.home() / ".config"))
) / "niri_caelestia" / "wallhaven"


class Config:
    def __init__(self, path: Optional[Path] = None):
        self.path  = path or _CONFIG_PATH
        self._data = dict(DEFAULTS)
        self._load()

    def _load(self) -> None:
        if not self.path.exists():
            return
        if _HAS_TOML:
            try:
                with open(self.path, "rb") as f:
                    self._data.update(tomllib.load(f))
            except Exception as e:
                log.warning("Config parse error: %s", e)
        else:
            # minimal fallback parser
            for line in self.path.read_text().splitlines():
                line = line.strip()
                if not line or line.startswith("#"):
                    continue
                if "=" in line:
                    k, _, v = line.partition("=")
                    k = k.strip(); v = v.strip().strip('"').strip("'")
                    if v.lower() == "true":   v = True    # type: ignore
                    elif v.lower() == "false": v = False  # type: ignore
                    elif v.isdigit():          v = int(v) # type: ignore
                    if k in DEFAULTS:
                        self._data[k] = v

    def save(self) -> None:
        self.path.parent.mkdir(parents=True, exist_ok=True)
        self.path.write_text(_dumps(self._data))

    def get(self, key: str, fallback: Any = None) -> Any:
        return self._data.get(key, fallback)

    def set(self, key: str, value: Any) -> None:
        if key not in DEFAULTS:
            raise KeyError(f"Unknown config key: {key!r}")
        self._data[key] = value

    # typed shortcuts
    @property
    def api_key(self) -> str:        return str(self._data.get("api_key", ""))
    @property
    def download_dir(self) -> Path:  return Path(str(self._data.get("download_dir", DEFAULTS["download_dir"])))
    @property
    def workers(self) -> int:        return int(self._data.get("workers", 3))
    @property
    def skip_existing(self) -> bool: return bool(self._data.get("skip_existing", True))
    @property
    def verbose(self) -> bool:       return bool(self._data.get("verbose", False))

    def display(self) -> str:
        lines = [f"Config: {self.path}", ""]
        for k, v in self._data.items():
            val = "***" if k == "api_key" and v else (v or "(not set)")
            lines.append(f"  {k:<25} {val}")
        return "\n".join(lines)
