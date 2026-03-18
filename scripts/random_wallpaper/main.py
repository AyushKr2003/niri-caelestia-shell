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
from scraper import (
    get_random_wallpaper,
    fetch_homepage_slugs,
    fetch_search_slugs,
    slug_to_urls,
    list_all_categories,
)
from downloader import download_best_wallpaper


def cmd_categories():
    cats = list_all_categories()
    print("\n📁 Available Categories (use as --keyword value):\n")
    for alias, query in cats.items():
        q = query.replace("+", " ")
        print(f"  {alias:<14}  →  python main.py --keyword \"{q}\"")
    print()


def cmd_list(keyword=None, pages=1):
    slugs = fetch_search_slugs(keyword, max_pages=pages) if keyword else fetch_homepage_slugs()
    if not slugs:
        print("[ERROR] No images found.")
        return

    print(f"\n🖼  Found {len(slugs)} wallpaper(s):\n")
    for i, slug in enumerate(slugs, 1):
        urls = slug_to_urls(slug)
        print(f"  [{i:02d}] {slug}")
        print(f"        4K  (3840x2160): {urls['url_4k']}")
        print(f"        2K  (2560x1440): {urls['url_2k']}")
        print(f"        HD  (1920x1080): {urls['url_1080p']}")
        print(f"        Thumb (preview): {urls['url_thumb']}")
        print()


def cmd_download(keyword=None, output_dir="./wallpapers", preferred_res="4k"):
    entry = get_random_wallpaper(keyword)
    if not entry:
        print("[ERROR] Could not find any wallpapers.")
        sys.exit(1)

    print(f"\n🎲 Selected wallpaper: {entry['slug']}")
    print(f"   4K  URL: {entry['url_4k']}")
    print(f"   2K  URL: {entry['url_2k']}")
    print(f"   HD  URL: {entry['url_1080p']}")
    print(f"\n⬇  Downloading (preferred: {preferred_res.upper()}, will fall back if unavailable)...\n")

    saved = download_best_wallpaper(entry, output_dir=output_dir, preferred_res=preferred_res)

    if saved:
        print(f"\n✅ Saved: {saved}")
    else:
        print("\n❌ Download failed for all resolutions.")
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
        help="List all found image URLs without downloading",
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

    args = parser.parse_args()

    if args.categories:
        cmd_categories()
        return

    if args.list:
        cmd_list(keyword=args.keyword, pages=args.pages)
        return

    cmd_download(keyword=args.keyword, output_dir=args.output, preferred_res=args.res)


if __name__ == "__main__":
    main()