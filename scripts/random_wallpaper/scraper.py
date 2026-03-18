"""
uhdpaper.com Scraper
====================
Scrapes wallpaper image links from uhdpaper.com

===== FULLY RESEARCHED URL PATTERNS =====

Homepage:           https://www.uhdpaper.com/
Search by keyword:  https://www.uhdpaper.com/search?q=<keyword>&by-date=true
Next page:          https://www.uhdpaper.com/search?updated-max=<ISO_TIMESTAMP>&max-results=20

--- CDN IMAGE URLs (img.uhdpaper.com) ---

Thumbnail (low-res preview, ~400px wide):
  https://img.uhdpaper.com/wallpaper/<slug>-thumb.jpg?dl

FULL RESOLUTION PC WALLPAPERS (confirmed by fetching individual post pages):
  4K  3840x2160  →  https://img.uhdpaper.com/wallpaper/<slug>-pc-4k.jpg
  2K  2560x1440  →  https://img.uhdpaper.com/wallpaper/<slug>-pc-2k.jpg
  HD  1920x1080  →  https://img.uhdpaper.com/wallpaper/<slug>-pc-hd.jpg

Mobile/Portrait versions:
  4K portrait  2160x3840  →  https://img.uhdpaper.com/wallpaper/<slug>-phone-4k.jpg
  HD portrait  1080x1920  →  https://img.uhdpaper.com/wallpaper/<slug>-phone-hd.jpg

--- SLUG ANATOMY ---
Example: gojo-eyes-jujutsu-kaisen-284@5@k
         ^^^^^^^^^^^^^^^^^^^^^^^^ ^^^@^@^
         human-readable title    ID  tag variant

The '@' characters appear literally in the URL path (do NOT percent-encode).

--- HOW FULL-RES IS FOUND ---
The listing/search pages only show thumbnails. Full-res URLs are listed on
each wallpaper's individual post page, e.g.:
  https://www.uhdpaper.com/2025/11/gojo-eyes-4k-wallpaper-2845k.html
  → contains links like: img.uhdpaper.com/wallpaper/<slug>-pc-4k.jpg

Since listing pages don't link to individual posts, we derive the full-res
URLs directly from the slug using the confirmed suffix pattern above.
This avoids the need for an extra HTTP request per image.
"""

import re
import random
import requests
from bs4 import BeautifulSoup
from urllib.parse import quote_plus
from typing import Optional


HEADERS = {
    "User-Agent": (
        "Mozilla/5.0 (X11; Linux x86_64) "
        "AppleWebKit/537.36 (KHTML, like Gecko) "
        "Chrome/122.0.0.0 Safari/537.36"
    ),
    "Accept-Language": "en-US,en;q=0.9",
    "Referer": "https://www.uhdpaper.com/",
}

BASE_URL = "https://www.uhdpaper.com"
CDN_BASE = "https://img.uhdpaper.com/wallpaper"

# Resolution suffixes confirmed from individual post page research
RESOLUTIONS = {
    "4k":    "-pc-4k.jpg",    # 3840x2160
    "2k":    "-pc-2k.jpg",    # 2560x1440
    "1080p": "-pc-hd.jpg",    # 1920x1080  ← default for PC
    "thumb": "-thumb.jpg?dl", # ~400px wide preview only
}

# All known category search keywords (from the nav bar)
CATEGORIES = {
    "game":       "Video+Game",
    "anime":      "Anime",
    "movie":      "Movie",
    "series":     "TV+Series",
    "abstract":   "Abstract",
    "animals":    "Animals",
    "celebrity":  "Celebrity",
    "comics":     "Comics",
    "digitalart": "Digital+Art",
    "fantasy":    "Fantasy",
    "nature":     "Nature",
    "scenery":    "Scenery",
    "scifi":      "Sci-Fi",
    "space":      "Space",
}


def get_page(url: str) -> Optional[BeautifulSoup]:
    """Fetch a page and return parsed BeautifulSoup or None on failure."""
    try:
        resp = requests.get(url, headers=HEADERS, timeout=15)
        resp.raise_for_status()
        return BeautifulSoup(resp.text, "html.parser")
    except requests.RequestException as e:
        print(f"[ERROR] Failed to fetch {url}: {e}")
        return None


def extract_slugs_from_page(soup: BeautifulSoup) -> list[str]:
    """
    Extract all image slugs from a parsed listing/homepage.

    Two formats exist on the site:
      Old:  <img src="https://img.uhdpaper.com/wallpaper/<slug>-thumb.jpg?dl">
      New:  <img src="https://img.uhdpaper.com/wallpaper/<slug>">  (no extension, no thumb suffix)

    Both are handled here.
    """
    slugs = []
    seen = set()

    for img in soup.find_all("img"):
        src = img.get("src", "")
        if "img.uhdpaper.com/wallpaper/" not in src:
            continue

        # Pattern 1: old format with -thumb.jpg suffix
        match = re.search(r"/wallpaper/(.+?)-thumb\.jpg", src)
        if match:
            slug = match.group(1)
            if slug not in seen:
                seen.add(slug)
                slugs.append(slug)
            continue

        # Pattern 2: new format — raw slug, no extension
        # e.g. https://img.uhdpaper.com/wallpaper/anime-girl-blue-hair-894@5@m
        match = re.search(r"/wallpaper/([^\"'\s?#]+)$", src)
        if match:
            slug = match.group(1)
            # Skip asset files like ripple-horiz.svg, desktop.svg, etc.
            if "." not in slug or slug.endswith(".jpg") or slug.endswith(".png"):
                clean = slug.rstrip(".jpg").rstrip(".png")
                if clean not in seen:
                    seen.add(clean)
                    slugs.append(clean)

    return slugs


def slug_to_urls(slug: str) -> dict:
    """
    Given a slug, return all download URLs for this wallpaper.

    Full-res URL pattern confirmed from individual post pages:
      slug + '-pc-4k.jpg'   → 3840x2160
      slug + '-pc-2k.jpg'   → 2560x1440
      slug + '-pc-hd.jpg'   → 1920x1080
      slug + '-thumb.jpg'   → thumbnail only (~400px)
    """
    return {
        "slug":       slug,
        "url_4k":     f"{CDN_BASE}/{slug}-pc-4k.jpg",
        "url_2k":     f"{CDN_BASE}/{slug}-pc-2k.jpg",
        "url_1080p":  f"{CDN_BASE}/{slug}-pc-hd.jpg",
        "url_thumb":  f"{CDN_BASE}/{slug}-thumb.jpg?dl",
    }


def fetch_homepage_slugs() -> list[str]:
    """Fetch all image slugs from the homepage."""
    print("[INFO] Fetching homepage...")
    soup = get_page(BASE_URL)
    if not soup:
        return []
    slugs = extract_slugs_from_page(soup)
    print(f"[INFO] Found {len(slugs)} images on homepage.")
    return slugs


def fetch_search_slugs(keyword: str, max_pages: int = 1) -> list[str]:
    """
    Search uhdpaper for a keyword and return image slugs.

    Args:
        keyword:   search term, e.g. 'Nature', 'Anime', 'Space'
        max_pages: how many pages to scrape (~20 images each)
    """
    all_slugs = []
    query = CATEGORIES.get(keyword.lower().replace(" ", ""), keyword)
    url = f"{BASE_URL}/search?q={quote_plus(query)}&by-date=true"

    for page_num in range(max_pages):
        print(f"[INFO] Fetching search page {page_num + 1}: {url}")
        soup = get_page(url)
        if not soup:
            break

        slugs = extract_slugs_from_page(soup)
        all_slugs.extend(slugs)
        print(f"[INFO] Page {page_num + 1}: {len(slugs)} images found.")

        if page_num + 1 < max_pages:
            next_link = soup.find("a", string=re.compile(r"Next", re.I))
            if next_link and next_link.get("href"):
                url = next_link["href"]
                if not url.startswith("http"):
                    url = BASE_URL + url
            else:
                print("[INFO] No more pages found.")
                break

    return all_slugs


def get_random_wallpaper(keyword: Optional[str] = None) -> Optional[dict]:
    """
    Get a random wallpaper entry.

    Returns dict with keys: slug, url_4k, url_2k, url_1080p, url_thumb
    """
    slugs = fetch_search_slugs(keyword, max_pages=1) if keyword else fetch_homepage_slugs()

    if not slugs:
        print("[ERROR] No wallpapers found.")
        return None

    slug = random.choice(slugs)
    result = slug_to_urls(slug)
    print(f"[INFO] Selected: {slug}")
    return result


def list_all_categories() -> dict:
    """Return the full category → search query mapping."""
    return CATEGORIES