"""
downloader.py
=============
Downloads full-resolution PC wallpapers from uhdpaper.com CDN.

Resolution priority (all confirmed from live post pages):
  4K   → <slug>-pc-4k.jpg   (3840x2160)
  2K   → <slug>-pc-2k.jpg   (2560x1440)
  1080p→ <slug>-pc-hd.jpg   (1920x1080)  ← DEFAULT target for PC
  thumb→ <slug>-thumb.jpg   (tiny preview, ~400px)  ← last fallback only

Strategy: try resolutions in order from highest to lowest.
The thumb is NEVER used as a primary target — only as absolute last resort.
"""

import sys
import os
import re
import requests
from typing import Optional

HEADERS = {
    "User-Agent": (
        "Mozilla/5.0 (X11; Linux x86_64) "
        "AppleWebKit/537.36 (KHTML, like Gecko) "
        "Chrome/122.0.0.0 Safari/537.36"
    ),
    "Referer": "https://www.uhdpaper.com/",
    "Accept": "image/avif,image/webp,image/apng,image/svg+xml,image/*,*/*;q=0.8",
}

MIN_VALID_SIZE_BYTES = 50 * 1024  # anything under 50 KB is likely an error page


def sanitize_filename(slug: str, suffix: str) -> str:
    """Convert slug + resolution suffix to a safe filename."""
    name = re.sub(r"[@/\\:*?\"<>|]", "_", slug)
    return f"{name}{suffix}.jpg"


def _try_download(url: str, save_path: str) -> Optional[str]:
    """
    Attempt to download from url to save_path.
    Returns save_path on success, None on failure.
    """
    if os.path.exists(save_path):
        print(f"         ✓ Already exists → {save_path}", file=sys.stderr)
        return save_path

    try:
        with requests.get(url, headers=HEADERS, stream=True, timeout=30) as resp:
            if resp.status_code != 200:
                print(f"         ✗ HTTP {resp.status_code}", file=sys.stderr)
                return None

            content_type = resp.headers.get("Content-Type", "")
            if "image" not in content_type and "octet-stream" not in content_type:
                print(f"         ✗ Not an image ({content_type})", file=sys.stderr)
                return None

            data = b"".join(resp.iter_content(chunk_size=8192))

            if len(data) < MIN_VALID_SIZE_BYTES:
                print(f"         ✗ Too small ({len(data)/1024:.1f} KB) — likely error page", file=sys.stderr)
                return None

            with open(save_path, "wb") as f:
                f.write(data)

            print(f"         ✓ {len(data)/1024:.0f} KB saved → {save_path}", file=sys.stderr)
            return save_path

    except requests.RequestException as e:
        print(f"         ✗ {e}", file=sys.stderr)
        return None


def download_best_wallpaper(
    wallpaper: dict,
    output_dir: str = "./wallpapers",
    preferred_res: str = "4k",
) -> Optional[str]:
    """
    Download the best available resolution of a wallpaper.

    Args:
        wallpaper:     dict from scraper.slug_to_urls() with keys:
                       slug, url_4k, url_2k, url_1080p, url_thumb
        output_dir:    directory to save image (created if missing)
        preferred_res: starting resolution — '4k', '2k', or '1080p'
                       the downloader tries this first, then falls back down

    Returns:
        Path to downloaded file, or None if all attempts fail.
    """
    os.makedirs(output_dir, exist_ok=True)
    slug = wallpaper["slug"]

    order = ["4k", "2k", "1080p"]
    try:
        start_idx = order.index(preferred_res.lower().replace(" ", ""))
    except ValueError:
        start_idx = 0

    attempt_order = order[start_idx:]

    res_map = {
        "4k":    ("4K  3840×2160", "url_4k",    "_4K"),
        "2k":    ("2K  2560×1440", "url_2k",    "_2K"),
        "1080p": ("HD  1920×1080", "url_1080p", "_HD"),
    }

    for res_key in attempt_order:
        label, url_key, fname_suffix = res_map[res_key]
        url = wallpaper.get(url_key)
        if not url:
            continue

        filename = sanitize_filename(slug, fname_suffix)
        save_path = os.path.join(output_dir, filename)

        print(f"   → Trying {label}", file=sys.stderr)
        print(f"     {url}", file=sys.stderr)
        result = _try_download(url, save_path)
        if result:
            return result

    # Last resort: thumbnail (warn user explicitly)
    print("\n   ⚠  All full-resolution attempts failed.", file=sys.stderr)
    print("   → Falling back to thumbnail (low resolution preview only)...", file=sys.stderr)
    thumb_url = wallpaper.get("url_thumb")
    if thumb_url:
        filename = sanitize_filename(slug, "_thumb")
        save_path = os.path.join(output_dir, filename)
        print(f"     {thumb_url}", file=sys.stderr)
        result = _try_download(thumb_url, save_path)
        if result:
            print("   ⚠  Only thumbnail was available for this wallpaper.", file=sys.stderr)
            return result

    print("[ERROR] All download attempts failed for this wallpaper.", file=sys.stderr)
    return None
