"""
Terminal output — coloured tables, wallpaper detail, progress bar.
Pure stdlib, degrades gracefully when colours are unsupported.
"""

import os
import sys
import shutil
from typing import List, Optional

from wallhaven.models.wallpaper import Wallpaper, SearchMeta

# ── colour support ────────────────────────────────────────────────────────

_COLOR = sys.stdout.isatty() and "NO_COLOR" not in os.environ

class C:
    RST  = "\033[0m"    if _COLOR else ""
    BOLD = "\033[1m"    if _COLOR else ""
    DIM  = "\033[2m"    if _COLOR else ""
    RED  = "\033[31m"   if _COLOR else ""
    GRN  = "\033[32m"   if _COLOR else ""
    YLW  = "\033[33m"   if _COLOR else ""
    BLU  = "\033[34m"   if _COLOR else ""
    MAG  = "\033[35m"   if _COLOR else ""
    CYN  = "\033[36m"   if _COLOR else ""


def _swatch(hex_color: str) -> str:
    """Render a hex colour as a coloured terminal block."""
    if not _COLOR:
        return f"#{hex_color}"
    h = hex_color.lstrip("#")
    try:
        r, g, b = int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16)
        return f"\033[38;2;{r};{g};{b}m█\033[0m"
    except Exception:
        return h


_PURITY = {"sfw": C.GRN, "sketchy": C.YLW, "nsfw": C.RED}
_CAT    = {"general": C.CYN, "anime": C.MAG, "people": C.BLU}


# ── wallpaper display ─────────────────────────────────────────────────────

def fmt_row(wp: Wallpaper, idx: Optional[int] = None) -> str:
    num     = f"{C.DIM}{idx:>3}.{C.RST} " if idx is not None else ""
    purity  = _PURITY.get(wp.purity, "")  + wp.purity   + C.RST
    cat     = _CAT.get(wp.category, "")   + wp.category  + C.RST
    swatches= " ".join(_swatch(c) for c in wp.colors[:5])
    return (
        f"{num}{C.BOLD}{wp.id}{C.RST}  "
        f"{C.CYN}{wp.resolution:<12}{C.RST}  "
        f"{purity:<20}  {cat:<20}  "
        f"❤ {C.RED}{wp.favorites:<5}{C.RST}  "
        f"{wp.file_size_human:<9}  {swatches}"
    )


def fmt_detail(wp: Wallpaper) -> str:
    bar = "─" * 52
    lines = [
        f"\n{C.BOLD}{bar}{C.RST}",
        f"  {C.BOLD}ID          {C.RST}{wp.id}",
        f"  {C.BOLD}URL         {C.RST}{wp.url}",
        f"  {C.BOLD}Resolution  {C.RST}{wp.resolution}",
        f"  {C.BOLD}Category    {C.RST}{wp.category}",
        f"  {C.BOLD}Purity      {C.RST}{wp.purity}",
        f"  {C.BOLD}File size   {C.RST}{wp.file_size_human}",
        f"  {C.BOLD}File type   {C.RST}{wp.file_type}",
        f"  {C.BOLD}Views       {C.RST}{wp.views:,}",
        f"  {C.BOLD}Favorites   {C.RST}{wp.favorites:,}",
        f"  {C.BOLD}Created     {C.RST}{wp.created_at or '—'}",
        f"  {C.BOLD}Source      {C.RST}{wp.source or '—'}",
        f"  {C.BOLD}Direct URL  {C.RST}{wp.path}",
    ]
    if wp.colors:
        lines.append(f"  {C.BOLD}Colors      {C.RST}" + " ".join(_swatch(c) for c in wp.colors))
    if wp.tags:
        names = ", ".join(t.get("name", "") for t in wp.tags[:10])
        lines.append(f"  {C.BOLD}Tags        {C.RST}{names}")
    lines.append(f"{C.BOLD}{bar}{C.RST}\n")
    return "\n".join(lines)


def print_results(wallpapers: List[Wallpaper], meta: SearchMeta, as_json: bool = False) -> None:
    if as_json:
        import json, dataclasses
        print(json.dumps([dataclasses.asdict(w) for w in wallpapers], default=str, indent=2))
        return
    print(f"\n{C.BOLD}Found {meta.total:,} wallpapers  (page {meta.current_page}/{meta.last_page}){C.RST}\n")
    for i, wp in enumerate(wallpapers, 1):
        print(fmt_row(wp, i))
    print()


# ── progress bar ──────────────────────────────────────────────────────────

class Progress:
    """Minimal single-line progress bar — no external dependencies."""

    def __init__(self, total: int, label: str = "Downloading"):
        self.total  = total
        self.label  = label
        self.done   = 0
        self.errors = 0
        self._w     = max(20, shutil.get_terminal_size((80, 24)).columns - 35)

    def update(self, ok: bool) -> None:
        self.done += 1
        if not ok:
            self.errors += 1
        pct    = self.done / self.total if self.total else 1
        filled = int(self._w * pct)
        bar    = "█" * filled + "░" * (self._w - filled)
        status = f"{C.RED}✗{self.errors}{C.RST}" if self.errors else f"{C.GRN}✓{C.RST}"
        print(
            f"\r{C.BOLD}{self.label}{C.RST} [{bar}] "
            f"{self.done}/{self.total} {status}",
            end="", flush=True,
        )

    def finish(self) -> None:
        ok = self.done - self.errors
        print(
            f"\n{C.GRN}✓ {ok} downloaded{C.RST}"
            + (f"  {C.RED}{self.errors} failed{C.RST}" if self.errors else "")
        )
