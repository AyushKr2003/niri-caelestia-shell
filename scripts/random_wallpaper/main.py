#!/usr/bin/env -S\_/bin/sh\_-c\_"source\_\$(eval\_echo\_\$CAELESTIA_VIRTUAL_ENV)/bin/activate&&exec\_python\_-E\_"\$0"\_"\$@""
"""
uhdpaper-dl — Random UHD wallpaper downloader from uhdpaper.com
================================================================

Usage:
    python main.py                              # Random from homepage, tries 4K first
    python main.py --keyword "Nature"           # Search + random, tries 4K first
    python main.py --res 1080p                  # Prefer 1080p (still falls back if missing)
    python main.py --keyword "Anime" --list     # List all found URLs (no download)
    python main.py --categories                 # Show all available categories
    python main.py --output ~/Pictures/walls    # Custom save directory

Resolution behavior:
    --res 4k     tries 4K → 2K → 1080p → thumb  (default)
    --res 2k     tries 2K → 1080p → thumb
    --res 1080p  tries 1080p → thumb
"""

import argparse
import sys
import json
import os
import requests
import shutil
from scraper import (
    get_random_wallpaper,
    fetch_homepage_slugs,
    fetch_search_slugs,
    slug_to_urls,
    list_all_categories,
    HEADERS,
)
from downloader import download_best_wallpaper

# Cache directory for thumbnails to avoid hotlinking issues in QML
CACHE_DIR = os.path.expanduser("~/.cache/caelestia/web_wallpapers/thumbs")

def cache_thumbnail(wallpaper):
    """Download thumbnail to local cache and return local path."""
    os.makedirs(CACHE_DIR, exist_ok=True)
    slug = wallpaper["slug"]
    local_path = os.path.join(CACHE_DIR, f"{slug}-thumb.jpg")
    
    if os.path.exists(local_path) and os.path.getsize(local_path) > 1024:
        return f"file://{local_path}"
        
    url = wallpaper["url_thumb"]
    try:
        # Use existing headers from scraper to bypass hotlinking protection
        resp = requests.get(url, headers=HEADERS, timeout=10, stream=True)
        if resp.status_code == 200:
            with open(local_path, 'wb') as f:
                shutil.copyfileobj(resp.raw, f)
            return f"file://{local_path}"
    except Exception as e:
        print(f"[ERROR] Failed to cache thumbnail {slug}: {e}", file=sys.stderr)
        
    return url # Fallback to original URL if caching fails

def cmd_categories(as_json=False):
    cats = list_all_categories()
    if as_json:
        print(json.dumps(cats))
        return

    print("\n📁 Available Categories (use as --keyword value):\n", file=sys.stderr)
    for alias, query in cats.items():
        q = query.replace("+", " ")
        print(f"  {alias:<14}  →  python main.py --keyword \"{q}\"", file=sys.stderr)
    print(file=sys.stderr)


def cmd_list(keyword=None, pages=1, as_json=False):
    slugs = fetch_search_slugs(keyword, max_pages=pages) if keyword else fetch_homepage_slugs()
    if not slugs:
        if as_json:
            print(json.dumps([]))
        else:
            print("[ERROR] No images found.", file=sys.stderr)
        return

    results = []
    for slug in slugs:
        entry = slug_to_urls(slug)
        # Always cache thumbnails when listing for JSON (QML)
        if as_json:
            entry["url_thumb"] = cache_thumbnail(entry)
        results.append(entry)

    if as_json:
        print(json.dumps(results))
        return

    print(f"\n🖼  Found {len(slugs)} wallpaper(s):\n", file=sys.stderr)
    for i, res in enumerate(results, 1):
        print(f"  [{i:02d}] {res['slug']}", file=sys.stderr)
        print(f"        4K  (3840x2160): {res['url_4k']}", file=sys.stderr)
        print(f"        2K  (2560x1440): {res['url_2k']}", file=sys.stderr)
        print(f"        HD  (1920x1080): {res['url_1080p']}", file=sys.stderr)
        print(f"        Thumb (preview): {res['url_thumb']}", file=sys.stderr)
        print(file=sys.stderr)


def cmd_download(keyword=None, output_dir="./wallpapers", preferred_res="4k", as_json=False, slug=None):
    if slug:
        entry = slug_to_urls(slug)
    else:
        entry = get_random_wallpaper(keyword)

    if not entry:
        if as_json:
            print(json.dumps({"error": "No wallpaper found"}))
        else:
            print("[ERROR] Could not find any wallpapers.", file=sys.stderr)
        sys.exit(1)

    if not as_json:
        print(f"\n🎲 Selected wallpaper: {entry['slug']}", file=sys.stderr)
        print(f"   4K  URL: {entry['url_4k']}", file=sys.stderr)
        print(f"   2K  URL: {entry['url_2k']}", file=sys.stderr)
        print(f"   HD  URL: {entry['url_1080p']}", file=sys.stderr)
        print(f"\n⬇  Downloading (preferred: {preferred_res.upper()}, will fall back if unavailable)...\n", file=sys.stderr)

    saved = download_best_wallpaper(entry, output_dir=output_dir, preferred_res=preferred_res)

    if saved:
        if as_json:
            print(json.dumps({"status": "success", "path": saved, "slug": entry['slug']}))
        else:
            print(f"\n✅ Saved: {saved}", file=sys.stderr)
    else:
        if as_json:
            print(json.dumps({"status": "error", "message": "Download failed"}))
        else:
            print("\n❌ Download failed for all resolutions.", file=sys.stderr)
        sys.exit(1)


def main():
    parser = argparse.ArgumentParser(
        description="Download random UHD wallpapers from uhdpaper.com",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=__doc__,
    )
    parser.add_argument(
        "--keyword", "-k",
        type=str, default=None,
        help="Search keyword or category (e.g. 'Nature', 'Anime', 'Space')",
    )
    parser.add_argument(
        "--output", "-o",
        type=str, default="./wallpapers",
        help="Output directory (default: ./wallpapers)",
    )
    parser.add_argument(
        "--res", "-r",
        type=str, default="4k",
        choices=["4k", "2k", "1080p"],
        help="Preferred resolution: 4k (3840x2160), 2k (2560x1440), 1080p (1920x1080). Default: 4k",
    )
    parser.add_argument(
        "--list", "-l",
        action="store_true",
        help="List all found image URLs",
    )
    parser.add_argument(
        "--pages", "-p",
        type=int, default=1,
        help="Number of search result pages to scrape (~20 images/page). Default: 1",
    )
    parser.add_argument(
        "--categories", "-c",
        action="store_true",
        help="Show all available category shortcuts",
    )
    parser.add_argument(
        "--json", "-j",
        action="store_true",
        help="Output in JSON format",
    )
    parser.add_argument(
        "--slug", "-s",
        type=str, default=None,
        help="Download a specific wallpaper by its slug",
    )
    parser.add_argument(
        "--clear-cache",
        action="store_true",
        help="Clear the thumbnail cache",
    )

    args = parser.parse_args()

    if args.clear_cache:
        if os.path.exists(CACHE_DIR):
            print(f"[INFO] Clearing thumbnail cache: {CACHE_DIR}", file=sys.stderr)
            shutil.rmtree(CACHE_DIR)
        return

    if args.categories:
        cmd_categories(as_json=args.json)
        return

    if args.list:
        cmd_list(keyword=args.keyword, pages=args.pages, as_json=args.json)
        return

    cmd_download(
        keyword=args.keyword,
        output_dir=args.output,
        preferred_res=args.res,
        as_json=args.json,
        slug=args.slug
    )


if __name__ == "__main__":
    main()
