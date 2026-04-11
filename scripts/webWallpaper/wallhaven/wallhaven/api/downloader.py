"""
Download wallpapers — single file or concurrent batch.
Supports resume (HTTP Range) and skip-existing deduplication.
"""

import logging
from dataclasses import dataclass
from pathlib import Path
from typing import Callable, List, Optional
from concurrent.futures import ThreadPoolExecutor, as_completed

import requests
from requests.adapters import HTTPAdapter
from urllib3.util.retry import Retry

from wallhaven.models.wallpaper import Wallpaper

log = logging.getLogger(__name__)


def _dl_session() -> requests.Session:
    s = requests.Session()
    r = Retry(total=3, backoff_factor=1, status_forcelist=[500, 502, 503, 504])
    s.mount("https://", HTTPAdapter(max_retries=r))
    return s


def _dest(wallpaper: Wallpaper, directory: Path) -> Path:
    return directory / f"wallhaven-{wallpaper.id}.{wallpaper.extension}"


def _exists(path: Path) -> bool:
    return path.exists() and path.stat().st_size > 0


# ── single download ───────────────────────────────────────────────────────

def download_wallpaper(
    wallpaper:      Wallpaper,
    directory:      Path,
    api_key:        Optional[str]                    = None,
    chunk_size:     int                              = 8192,
    skip_existing:  bool                             = True,
) -> Path:
    """
    Download *wallpaper* into *directory*.
    Resumes partial downloads via HTTP Range header.
    Returns the final local path.
    """
    directory.mkdir(parents=True, exist_ok=True)
    dest = _dest(wallpaper, directory)

    if skip_existing and _exists(dest):
        log.debug("skip %s — already at %s", wallpaper.id, dest)
        return dest

    headers: dict = {}
    if api_key:
        headers["X-API-Key"] = api_key

    # Resume support
    bytes_done = 0
    if dest.exists():
        bytes_done = dest.stat().st_size
        headers["Range"] = f"bytes={bytes_done}-"

    sess = _dl_session()
    resp = sess.get(wallpaper.path, headers=headers, stream=True, timeout=(5, 60))
    resp.raise_for_status()

    mode = "ab" if bytes_done else "wb"
    log.info("↓ %s  →  %s", wallpaper.id, dest)

    with open(dest, mode) as f:
        for chunk in resp.iter_content(chunk_size=chunk_size):
            if chunk:
                f.write(chunk)

    return dest


# ── batch download ────────────────────────────────────────────────────────

@dataclass
class DownloadResult:
    wallpaper: Wallpaper
    path:      Optional[Path]      = None
    error:     Optional[Exception] = None
    skipped:   bool                = False

    @property
    def ok(self) -> bool:
        return self.error is None


ProgressHook = Callable[[DownloadResult, int, int], None]


def download_batch(
    wallpapers:    List[Wallpaper],
    directory:     Path,
    api_key:       Optional[str]          = None,
    workers:       int                    = 3,
    skip_existing: bool                   = True,
    on_progress:   Optional[ProgressHook] = None,
) -> List[DownloadResult]:
    """
    Download *wallpapers* concurrently (up to *workers* threads).
    Calls *on_progress(result, done, total)* after each file completes.
    Returns list of DownloadResult in completion order.
    """
    results: List[DownloadResult] = []
    total = len(wallpapers)
    done  = 0

    def _task(wp: Wallpaper) -> DownloadResult:
        try:
            path    = download_wallpaper(wp, directory, api_key=api_key, skip_existing=skip_existing)
            skipped = skip_existing and _exists(_dest(wp, directory)) and path == _dest(wp, directory)
            return DownloadResult(wp, path=path, skipped=skipped)
        except Exception as exc:
            log.error("failed %s: %s", wp.id, exc)
            return DownloadResult(wp, error=exc)

    with ThreadPoolExecutor(max_workers=workers) as pool:
        futures = {pool.submit(_task, wp): wp for wp in wallpapers}
        for future in as_completed(futures):
            result = future.result()
            results.append(result)
            done += 1
            if on_progress:
                on_progress(result, done, total)

    return results
