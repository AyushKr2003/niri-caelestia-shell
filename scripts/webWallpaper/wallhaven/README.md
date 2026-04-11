# wallhaven

A modular Python wallpaper downloader for [wallhaven.cc](https://wallhaven.cc) using the official v1 API. No installation needed — just `pip install requests` and run `python main.py`.

---

## Requirements

```bash
pip install requests
```

That's the only dependency. No packaging, no entry points, no `pip install .`.

---

## Setup

```bash
# Clone or copy the folder anywhere
git clone <repo>
cd wallhaven

# Set your API key (get it at https://wallhaven.cc/settings/account)
python main.py config set api_key YOUR_KEY_HERE

# Set your download directory
python main.py config set download_dir ~/Pictures/walls
```

Your config is saved to `~/.config/wallhaven/config.toml` and auto-loaded on every run.

---

## Usage

```
python main.py <command> [options]
```

### Commands

| Command        | Description                              |
|----------------|------------------------------------------|
| `search`       | Search wallpapers with filters           |
| `random`       | Fetch random wallpaper(s)                |
| `download`     | Download by wallpaper ID(s)              |
| `info`         | Show full metadata for a wallpaper       |
| `collections`  | Browse and download collections          |
| `config`       | View or edit settings                    |

---

## search

Search with any combination of filters.

```bash
python main.py search [QUERY] [OPTIONS]
```

| Option | Description |
|--------|-------------|
| `query` | Search terms. Supports wallhaven operators: `+tag` require, `-tag` exclude, `@user` by uploader, `id:N` by tag id, `like:ID` similar |
| `--categories` | `general`, `anime`, `people` — comma-separated |
| `--purity` | `sfw`, `sketchy`, `nsfw` — comma-separated. NSFW requires API key |
| `--sort` | `date_added`, `relevance`, `random`, `views`, `favorites`, `toplist` |
| `--order` | `asc` or `desc` |
| `--range` | `1d` `3d` `1w` `1M` `3M` `6M` `1y` — only with `--sort toplist` |
| `--resolution` | Minimum resolution, e.g. `1920x1080` |
| `--resolutions` | Exact resolutions, comma-separated, e.g. `1920x1080,2560x1440` |
| `--ratios` | Aspect ratios, e.g. `16x9,21x9` |
| `--colors` | Hex colors to match, comma-separated (no `#`), e.g. `ff0000,000000` |
| `--page` | Page number (default `1`) |
| `-n N` | Number of results to show/download (default `24`) |
| `--download` | Download all results up to `-n` |
| `--dir PATH` | Override download directory for this run |
| `--json` | Output raw JSON instead of formatted table |

**Examples:**

```bash
# Top anime wallpapers from the last month
python main.py search anime --sort toplist --range 1M --categories anime

# 4K cyberpunk, 21:9 ultrawide
python main.py search "+cyberpunk +neon" --resolution 3840x1080 --ratios 21x9

# Search and immediately download the top 10
python main.py search "landscape" --sort favorites --ratios 16x9 -n 10 --download

# Search by dominant color
python main.py search --colors 000000,424153 --purity sfw

# Output JSON for scripting
python main.py search "space" --json | jq '.[].path'
```

---

## random

Fetch one or more random wallpapers. Optionally download them or print the path for shell piping.

```bash
python main.py random [OPTIONS]
```

| Option | Description |
|--------|-------------|
| `--categories` | `general`, `anime`, `people` |
| `--purity` | `sfw`, `sketchy`, `nsfw` |
| `--resolution` | Minimum resolution, e.g. `1920x1080` |
| `--ratios` | Aspect ratio, e.g. `16x9` |
| `--pick N` | How many random wallpapers to pick (default `1`) |
| `--download` | Download the picked wallpaper(s) |
| `--print-path` | Print only the local file path — for shell/quickshell integration |
| `--dir PATH` | Override download directory |

**Examples:**

```bash
# Show info for one random wallpaper
python main.py random --ratios 16x9

# Download 3 random anime wallpapers
python main.py random --categories anime --pick 3 --download

# Print path only — clean output for piping into a wallpaper setter
python main.py random --ratios 16x9 --resolution 1920x1080 --download --print-path
```

---

## download

Download one or more wallpapers by their ID.

```bash
python main.py download ID [ID ...] [--dir PATH] [--force]
```

| Option | Description |
|--------|-------------|
| `--dir PATH` | Override download directory |
| `--force` | Re-download even if the file already exists |

```bash
python main.py download 94x38z
python main.py download 94x38z ze1p56 abc123 --dir ~/Desktop
```

---

## info

Print full metadata for one or more wallpapers.

```bash
python main.py info ID [ID ...] [--json]
```

```bash
python main.py info 94x38z
python main.py info 94x38z --json
```

---

## collections

List or browse wallhaven collections.

```bash
python main.py collections [OPTIONS]
```

| Option | Description |
|--------|-------------|
| `--user USERNAME` | Browse another user's public collections (omit to use your own — requires API key) |
| `--id ID` | Collection ID to browse |
| `--purity` | Filter purity when browsing a collection |
| `--page N` | Page number |
| `--download` | Download all wallpapers from the collection |
| `--dir PATH` | Override download directory |

```bash
# List your own collections (requires API key)
python main.py collections

# List another user's public collections
python main.py collections --user johndoe

# Browse and download a specific collection
python main.py collections --user johndoe --id 42 --download
```

---

## config

View or change persistent settings.

```bash
python main.py config show              # print all settings
python main.py config path              # print the config file path
python main.py config set KEY VALUE     # update a setting
```

### Available keys

| Key | Default | Description |
|-----|---------|-------------|
| `api_key` | *(empty)* | Wallhaven API key — get it at [wallhaven.cc/settings/account](https://wallhaven.cc/settings/account) |
| `download_dir` | `~/Pictures/wallhaven` | Where wallpapers are saved |
| `workers` | `3` | Concurrent download threads |
| `skip_existing` | `true` | Skip files that already exist |
| `default_resolution` | *(empty)* | Default minimum resolution filter |
| `default_ratio` | *(empty)* | Default aspect ratio filter |
| `default_purity` | `sfw` | Default purity filter |
| `default_sorting` | `date_added` | Default sort order |
| `verbose` | `false` | Enable debug logging |

```bash
python main.py config set api_key       YOUR_KEY_HERE
python main.py config set download_dir  ~/Pictures/walls
python main.py config set workers       4
python main.py config set default_ratio 16x9
python main.py config set skip_existing true
```

---

## Quickshell / shell integration

The `--print-path` flag on `random` outputs **only** the absolute file path to stdout — nothing else — making it easy to pipe into any wallpaper setter.

```bash
# swww
swww img "$(python main.py random --ratios 16x9 --resolution 1920x1080 --download --print-path)"

# feh
feh --bg-fill "$(python main.py random --ratios 16x9 --download --print-path)"

# hyprpaper
WALL=$(python main.py random --ratios 16x9 --download --print-path)
hyprctl hyprpaper wallpaper ",$WALL"
```

**Quickshell QML example:**

```qml
Process {
    id: wallpaperProc
    command: [
        "python", "/path/to/wallhaven/main.py",
        "random", "--ratios", "16x9",
        "--resolution", "1920x1080",
        "--download", "--print-path"
    ]
    stdout: SplitParser {
        onRead: data => {
            const path = data.trim()
            if (path) Hyprland.dispatch(`hyprctl hyprpaper wallpaper ",${path}"`)
        }
    }
}
```

**Systemd timer for auto-rotation:**

```ini
# ~/.config/systemd/user/wallhaven.service
[Unit]
Description=Set random wallpaper

[Service]
Type=oneshot
ExecStart=/bin/bash -c 'swww img "$(python /path/to/wallhaven/main.py random --ratios 16x9 --download --print-path)"'
```

```ini
# ~/.config/systemd/user/wallhaven.timer
[Unit]
Description=Rotate wallpaper every 30 minutes

[Timer]
OnBootSec=1min
OnUnitActiveSec=30min

[Install]
WantedBy=timers.target
```

```bash
systemctl --user enable --now wallhaven.timer
```

---

## Project structure

```
wallhaven/
├── main.py                        ← entry point — run this
└── wallhaven/
    ├── api/
    │   ├── client.py              ← WallhavenClient — all API v1 endpoints
    │   └── downloader.py          ← single & concurrent batch download w/ resume
    ├── models/
    │   ├── enums.py               ← Category, Purity, Sorting, Order, TopRange
    │   └── wallpaper.py           ← Wallpaper & SearchMeta dataclasses
    └── utils/
        ├── config.py              ← ~/.config/wallhaven/config.toml manager
        └── formatter.py           ← coloured terminal output, progress bar
```

---

## API notes

- Rate limit is **45 requests/minute** — the client throttles automatically.
- NSFW content requires a valid API key.
- An API key is also needed for your own private collections and user settings.
- Downloads support **resume** via HTTP `Range` headers — interrupted downloads pick up where they left off.
- Auth errors print a hint pointing to `python main.py config set api_key`.