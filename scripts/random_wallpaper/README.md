# uhdpaper-dl 🖼
(Build by AI)

Random UHD wallpaper downloader from [uhdpaper.com](https://www.uhdpaper.com/)  
Downloads full PC-resolution wallpapers (4K / 2K / 1080p).  
Built for easy integration into QuickShell or any wallpaper daemon.

---

## 📁 Project Structure

```
uhdpaper-downloader/
├── main.py           ← CLI entry point (all flags live here)
├── scraper.py        ← HTML scraping + slug extraction (BeautifulSoup)
├── downloader.py     ← HTTP download with resolution waterfall
├── requirements.txt  ← Python dependencies
├── .gitignore        ← Ignores wallpapers/, venv/, __pycache__, etc.
└── README.md         ← This file
```

---

## 🚀 Quick Start

```bash
# 1. Install dependencies
pip install -r requirements.txt

# 2. Download a random wallpaper (tries 4K first, falls back to 2K → 1080p)
python main.py

# 3. Download with a keyword, prefer 1080p
python main.py --keyword "Nature" --res 1080p

# 4. Save to a custom directory
python main.py --keyword "Anime" --output ~/Pictures/walls

# 5. List all found URLs without downloading
python main.py --keyword "Space" --list

# 6. Show all built-in category shortcuts
python main.py --categories

# 7. Scrape multiple pages before picking randomly (~20 images/page)
python main.py --keyword "Cyberpunk" --pages 3
```

---

## 🎛️ CLI Reference

| Flag | Short | Default | Description |
|------|-------|---------|-------------|
| `--keyword` | `-k` | homepage | Search term or category alias (e.g. `"Nature"`, `"anime"`) |
| `--res` | `-r` | `4k` | Preferred resolution: `4k`, `2k`, or `1080p` |
| `--output` | `-o` | `./wallpapers` | Directory to save the downloaded image |
| `--list` | `-l` | off | Print all found URLs, skip download |
| `--pages` | `-p` | `1` | Number of search result pages to scrape |
| `--categories` | `-c` | off | Show all built-in category aliases |

---

## 🔬 Full Site Research & URL Analysis

### Site Architecture

uhdpaper.com runs on **Google Blogger (Blogspot CMS)**. This means:

- No official API — pure HTML scraping required
- Listing pages show ~20 wallpapers each
- Pagination uses Blogger's `updated-max` ISO timestamp cursor
- All images are served from a dedicated CDN subdomain (`img.uhdpaper.com`)
- Individual wallpaper post pages contain the full-resolution download links

---

### Page URLs

#### Homepage
```
https://www.uhdpaper.com/
```
Returns the ~20 most recently posted wallpapers.

#### Search / Category
```
https://www.uhdpaper.com/search?q=<keyword>&by-date=true
```

#### Pagination (auto-followed by scraper)
```
https://www.uhdpaper.com/search?updated-max=2026-03-05T11:04:00%2B08:00&max-results=20
```
The scraper finds and follows `Next »` anchor links automatically.

#### Resolution-filtered browsing
```
https://www.uhdpaper.com/search/label/3840x2160   # 4K only
https://www.uhdpaper.com/search/label/7680x4320   # 8K only
```

---

### Built-in Category Aliases

These short aliases map to the site's nav bar search queries. Pass them to `--keyword`.

| Alias | Resolves to | Full search URL |
|-------|-------------|-----------------|
| `game` | `Video+Game` | `/search?q=Video+Game&by-date=true` |
| `anime` | `Anime` | `/search?q=Anime&by-date=true` |
| `movie` | `Movie` | `/search?q=Movie&by-date=true` |
| `series` | `TV+Series` | `/search?q=TV+Series&by-date=true` |
| `abstract` | `Abstract` | `/search?q=Abstract&by-date=true` |
| `animals` | `Animals` | `/search?q=Animals&by-date=true` |
| `celebrity` | `Celebrity` | `/search?q=Celebrity&by-date=true` |
| `comics` | `Comics` | `/search?q=Comics&by-date=true` |
| `digitalart` | `Digital+Art` | `/search?q=Digital+Art&by-date=true` |
| `fantasy` | `Fantasy` | `/search?q=Fantasy&by-date=true` |
| `nature` | `Nature` | `/search?q=Nature&by-date=true` |
| `scenery` | `Scenery` | `/search?q=Scenery&by-date=true` |
| `scifi` | `Sci-Fi` | `/search?q=Sci-Fi&by-date=true` |
| `space` | `Space` | `/search?q=Space&by-date=true` |

You can also pass **any free-form keyword** directly — it doesn't have to be an alias:
```bash
python main.py --keyword "Goku"
python main.py --keyword "Cyberpunk"
python main.py --keyword "Mountain"
```

---

### CDN Image URLs (Confirmed from Live Post Pages)

All images are served from `img.uhdpaper.com`. The full-resolution URLs were confirmed
by fetching individual wallpaper post pages (e.g. `/2025/11/gojo-eyes-4k-wallpaper-2845k.html`)
and reading the download link section directly.

#### Full PC Resolution URLs

| Resolution | Dimensions | URL Pattern |
|------------|------------|-------------|
| **4K** | 3840 × 2160 | `https://img.uhdpaper.com/wallpaper/<slug>-pc-4k.jpg` |
| **2K** | 2560 × 1440 | `https://img.uhdpaper.com/wallpaper/<slug>-pc-2k.jpg` |
| **1080p** | 1920 × 1080 | `https://img.uhdpaper.com/wallpaper/<slug>-pc-hd.jpg` |

#### Mobile / Portrait URLs (available but not used by default)

| Resolution | Dimensions | URL Pattern |
|------------|------------|-------------|
| 4K portrait | 2160 × 3840 | `https://img.uhdpaper.com/wallpaper/<slug>-phone-4k.jpg` |
| HD portrait | 1080 × 1920 | `https://img.uhdpaper.com/wallpaper/<slug>-phone-hd.jpg` |

#### Thumbnail (listing preview only — not a wallpaper)

```
https://img.uhdpaper.com/wallpaper/<slug>-thumb.jpg?dl
```

> ⚠️ The thumbnail is only a small preview (~400px wide). It is used as an absolute
> last-resort fallback only if all full-resolution URLs fail.

---

### Slug Anatomy

Every wallpaper has a unique **slug** that appears in both CDN image URLs and the listing page HTML.

Example slug: `gojo-eyes-jujutsu-kaisen-284@5@k`

```
gojo-eyes-jujutsu-kaisen  -  284  @  5  @  k
^^^^^^^^^^^^^^^^^^^^^^^^^     ^^^    ^     ^
  human-readable title        ID   tag  variant
```

- **Title**: kebab-case description of the image content
- **Numeric ID**: unique identifier for the post
- **`@tag`**: tag/category index on the post
- **`@variant`**: image variant or upload batch letter

> The `@` characters appear **literally** in CDN paths. Do **not** percent-encode them.

#### Two slug formats exist on the site

Older posts embed a thumbnail `<img>` with the `-thumb.jpg?dl` suffix. Newer posts
embed the raw slug with no extension at all. The scraper handles both:

```html
<!-- Old format (older posts) -->
<img src="https://img.uhdpaper.com/wallpaper/gojo-eyes-jujutsu-kaisen-284@5@k-thumb.jpg?dl">

<!-- New format (recent posts) -->
<img src="https://img.uhdpaper.com/wallpaper/anime-girl-blue-hair-894@5@m">
```

Both are parsed and produce the same set of full-resolution download URLs.

---

## ⚙️ How the Downloader Works

### Scraping flow

```
1. Fetch homepage or search URL
2. Parse all <img> tags from img.uhdpaper.com/wallpaper/
3. Extract slugs (handle both old -thumb and new bare-slug formats)
4. Pick one slug at random
5. Build full-resolution CDN URLs from the slug + known suffixes
```

### Resolution waterfall

The downloader never starts from the thumbnail. It attempts resolutions from best to worst
and stops as soon as a valid image (≥ 50 KB, correct Content-Type) is saved:

```
--res 4k    →  tries: 4K → 2K → 1080p → thumbnail (last resort)
--res 2k    →  tries: 2K → 1080p → thumbnail (last resort)
--res 1080p →  tries: 1080p → thumbnail (last resort)
```

If the thumbnail is downloaded as a fallback, a warning is printed so you know
the full-res wasn't available.

### Output filenames

Files are saved with a resolution suffix so multiple downloads don't overwrite each other:

```
wallpapers/
  gojo-eyes-jujutsu-kaisen-284_5_k_4K.jpg    ← 3840x2160
  northern-lights-night-sky-11_2_b_HD.jpg    ← 1920x1080
```

(`@` in slugs is replaced with `_` in filenames for filesystem safety.)

---

## 🔧 Using as a Library

```python
from scraper import fetch_homepage_slugs, fetch_search_slugs, slug_to_urls, get_random_wallpaper
from downloader import download_best_wallpaper

# Get a random Nature wallpaper entry
wallpaper = get_random_wallpaper(keyword="Nature")
# wallpaper = {
#   'slug':      'northern-lights-night-sky-scenery-digital-art-11@2@b',
#   'url_4k':    'https://img.uhdpaper.com/wallpaper/...−pc-4k.jpg',
#   'url_2k':    'https://img.uhdpaper.com/wallpaper/...−pc-2k.jpg',
#   'url_1080p': 'https://img.uhdpaper.com/wallpaper/...−pc-hd.jpg',
#   'url_thumb': 'https://img.uhdpaper.com/wallpaper/...−thumb.jpg?dl',
# }

# Download it (tries 4K first, falls back automatically)
saved_path = download_best_wallpaper(wallpaper, output_dir="./wallpapers", preferred_res="4k")
print(saved_path)  # ./wallpapers/northern-lights-..._4K.jpg

# Or build URLs manually from a known slug
urls = slug_to_urls("batman-gotham-city-811@2@b")
print(urls["url_4k"])    # https://img.uhdpaper.com/wallpaper/batman-gotham-city-811@2@b-pc-4k.jpg
print(urls["url_1080p"]) # https://img.uhdpaper.com/wallpaper/batman-gotham-city-811@2@b-pc-hd.jpg
```

---

## 🐚 QuickShell Integration (Future Plan)

For use with [QuickShell](https://quickshell.outfoxxed.me/), wrap the CLI in a shell script:

```bash
#!/bin/bash
# ~/.config/quickshell/get-wallpaper.sh

KEYWORD="${1:-}"   # pass a category or leave blank for homepage random
OUT_DIR="/tmp/quickshell-wall"

cd /path/to/uhdpaper-downloader
python main.py --keyword "$KEYWORD" --res 1080p --output "$OUT_DIR"

# Print the path of the latest downloaded file for QuickShell to consume
ls -t "$OUT_DIR"/*.jpg 2>/dev/null | head -1
```

Then in QuickShell (QML):
```qml
Process {
    id: wallpaperFetch
    command: ["bash", "/path/to/get-wallpaper.sh", "Nature"]
    onExited: {
        var path = stdout.trim()
        // pass path to your wallpaper setter
    }
}
```

Or pipe directly into `swww` / `hyprpaper`:
```bash
python main.py --keyword "Nature" --res 1080p -o /tmp/wall/ && \
  swww img "$(ls -t /tmp/wall/*.jpg | head -1)" --transition-type fade
```

---

## ⚠️ Notes & Limitations

1. **No API** — uhdpaper.com has no public API. This is pure HTML scraping via BeautifulSoup.
2. **~20 results per page** — Use `--pages N` to scrape more before picking randomly.
3. **CDN availability** — Not every resolution exists for every wallpaper. The waterfall fallback handles this gracefully.
4. **Scrape responsibly** — If doing bulk scraping, add `time.sleep(1)` between requests in `scraper.py` to avoid hammering the CDN.
5. **Site structure** — The site is Blogger-based; if they change their CDN URL scheme, update the `RESOLUTIONS` suffixes in `scraper.py`.

---

## 📦 Dependencies

```
requests>=2.31.0       # HTTP client
beautifulsoup4>=4.12.0 # HTML parsing
lxml>=5.0.0            # Fast HTML parser backend for BeautifulSoup
```

Install with:
```bash
pip install -r requirements.txt
```