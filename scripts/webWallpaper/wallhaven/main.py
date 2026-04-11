#!/usr/bin/env python3
"""
Wallhaven downloader — run directly, no installation needed.

Usage:
  python main.py search "cyberpunk" --ratio 16x9 --sort toplist --range 1M
  python main.py search --categories anime --resolution 2560x1440 --download
  python main.py random --ratio 16x9 --resolution 1920x1080
  python main.py random --ratio 16x9 --pick 3 --download
  python main.py download 94x38z ze1p56
  python main.py info 94x38z
  python main.py collections
  python main.py collections --user johndoe --id 42 --download
  python main.py config show
  python main.py config set api_key YOUR_KEY
  python main.py config set download_dir ~/Pictures/walls

Requirements:  pip install requests
"""

import argparse
import logging
import sys
import json
import os
import shutil
import requests
from pathlib import Path

# Make the wallhaven package importable when running from this directory
sys.path.insert(0, str(Path(__file__).parent))

from wallhaven.api.client    import WallhavenClient, WallhavenError, RateLimitError, AuthError
from wallhaven.api.downloader import download_wallpaper, download_batch
from wallhaven.models.enums  import Category, Purity, Sorting, Order, TopRange
from wallhaven.utils.config  import Config
from wallhaven.utils.formatter import fmt_detail, print_results, Progress, C

# Cache directory for thumbnails to avoid hotlinking issues in QML
CACHE_DIR = os.path.expanduser("~/.cache/caelestia/web_wallpapers/thumbs")

def cache_thumbnail(wallpaper_dict):
    """Download thumbnail to local cache and return local path."""
    os.makedirs(CACHE_DIR, exist_ok=True)
    wid = wallpaper_dict["id"]
    local_path = os.path.join(CACHE_DIR, f"wallhaven-{wid}-thumb.jpg")
    
    if os.path.exists(local_path) and os.path.getsize(local_path) > 1024:
        return f"file://{local_path}"
        
    url = wallpaper_dict.get("thumbs", {}).get("large")
    if not url:
        return ""

    try:
        # Standard headers to bypass some simple hotlinking protections
        headers = {
            "User-Agent": "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36",
            "Referer": "https://wallhaven.cc/"
        }
        resp = requests.get(url, headers=headers, timeout=10, stream=True)
        if resp.status_code == 200:
            with open(local_path, 'wb') as f:
                shutil.copyfileobj(resp.raw, f)
            return f"file://{local_path}"
    except Exception as e:
        print(f"[ERROR] Failed to cache thumbnail {wid}: {e}", file=sys.stderr)
        
    return url # Fallback to original URL if caching fails


# ══════════════════════════════════════════════════════════════════════════
#  Shared helpers
# ══════════════════════════════════════════════════════════════════════════

def _client(cfg: Config, args) -> WallhavenClient:
    key = getattr(args, "api_key", None) or cfg.api_key or None
    return WallhavenClient(api_key=key)


def _purities(raw: str | None) -> list[Purity] | None:
    if not raw:
        return None
    m = {"sfw": Purity.SFW, "sketchy": Purity.SKETCHY, "nsfw": Purity.NSFW}
    return [m[p] for p in raw.split(",") if p.strip() in m]


def _categories(raw: str | None) -> list[Category] | None:
    if not raw:
        return None
    m = {"general": Category.GENERAL, "anime": Category.ANIME, "people": Category.PEOPLE}
    return [m[c] for c in raw.split(",") if c.strip() in m]


def _colors(raw: str | None) -> list[str] | None:
    return [c.lstrip("#").strip() for c in raw.split(",") if c.strip()] if raw else None


def _resolutions(raw: str | None) -> list[str] | None:
    return [r.strip() for r in raw.split(",") if r.strip()] if raw else None


def _ratios(raw: str | None) -> list[str] | None:
    return [r.strip() for r in raw.split(",") if r.strip()] if raw else None


def _progress_hook(result, done: int, total: int, prog: Progress) -> None:
    prog.update(result.ok)
    if not result.ok:
        print(f"\n  {C.RED}✗{C.RST} {result.wallpaper.id}: {result.error}", file=sys.stderr)
    elif result.path and not result.skipped:
        print(f"\n  {C.GRN}↓{C.RST} {result.path}")


def _do_batch_download(wallpapers, cfg: Config, args) -> int:
    dest = Path(args.dir) if getattr(args, "dir", None) else cfg.download_dir
    n    = min(getattr(args, "n", len(wallpapers)), len(wallpapers))
    batch = wallpapers[:n]
    print(f"{C.BOLD}Downloading {n} wallpaper(s) → {dest}{C.RST}")
    prog = Progress(n)
    results = download_batch(
        batch, dest,
        api_key       = cfg.api_key or None,
        workers       = cfg.workers,
        skip_existing = cfg.skip_existing,
        on_progress   = lambda r, d, t: _progress_hook(r, d, t, prog),
    )
    prog.finish()
    return 0 if all(r.ok for r in results) else 1


# ══════════════════════════════════════════════════════════════════════════
#  Command handlers
# ══════════════════════════════════════════════════════════════════════════

# ── search ────────────────────────────────────────────────────────────────

def cmd_search(args, cfg: Config) -> int:
    client = _client(cfg, args)

    purities    = _purities(args.purity)    or _purities(cfg.get("default_purity"))
    categories  = _categories(args.categories)
    colors      = _colors(args.colors)
    resolutions = _resolutions(args.resolutions)
    ratios      = _ratios(args.ratios) or (
                      [cfg.get("default_ratio")] if cfg.get("default_ratio") else None)
    atleast     = args.resolution or cfg.get("default_resolution") or None
    sorting     = Sorting(args.sort)          if args.sort  else None
    order       = Order(args.order)           if args.order else None
    top_range   = TopRange(args.range)        if args.range else None

    try:
        wallpapers, meta = client.search(
            q           = args.query or None,
            categories  = categories,
            purities    = purities,
            sorting     = sorting,
            order       = order,
            top_range   = top_range,
            atleast     = atleast,
            resolutions = resolutions,
            ratios      = ratios,
            colors      = colors,
            page        = args.page,
        )
    except AuthError as e:
        print(f"{C.RED}Auth error:{C.RST} {e}\n"
              f"Set your API key:  python main.py config set api_key <KEY>", file=sys.stderr)
        return 1
    except WallhavenError as e:
        print(f"{C.RED}API error:{C.RST} {e}", file=sys.stderr)
        return 1

    if args.json:
        import dataclasses
        results = [dataclasses.asdict(w) for w in wallpapers]
        for r in results:
            r["thumbs"]["large"] = cache_thumbnail(r)
        
        output = {
            "data": results,
            "meta": dataclasses.asdict(meta)
        }
        print(json.dumps(output, default=str, indent=2))
    else:
        print_results(wallpapers, meta, as_json=False)

    if args.download and wallpapers:
        return _do_batch_download(wallpapers, cfg, args)

    return 0


# ── download ──────────────────────────────────────────────────────────────

def cmd_download(args, cfg: Config) -> int:
    client = _client(cfg, args)
    dest   = Path(args.dir) if args.dir else cfg.download_dir

    wallpapers = []
    for wid in args.ids:
        try:
            wallpapers.append(client.get_wallpaper(wid))
        except WallhavenError as e:
            print(f"{C.RED}✗{C.RST} {wid}: {e}", file=sys.stderr)

    if not wallpapers:
        if args.json:
            print(json.dumps({"status": "error", "message": "No wallpapers found"}))
        return 1

    if not args.json:
        print(f"{C.BOLD}Downloading {len(wallpapers)} wallpaper(s) → {dest}{C.RST}")
        prog = Progress(len(wallpapers))
    
    results = download_batch(
        wallpapers, dest,
        api_key       = cfg.api_key or None,
        workers       = cfg.workers,
        skip_existing = not args.force,
        on_progress   = (lambda r, d, t: _progress_hook(r, d, t, prog)) if not args.json else None,
    )

    if not args.json:
        prog.finish()
    else:
        # For QML, we assume the first one if multiple IDs were given (though usually it's one)
        first = results[0]
        if first.ok:
            print(json.dumps({"status": "success", "path": str(first.path), "id": first.wallpaper.id}))
        else:
            print(json.dumps({"status": "error", "message": first.error}))

    return 0 if all(r.ok for r in results) else 1


# ── random ────────────────────────────────────────────────────────────────

def cmd_random(args, cfg: Config) -> int:
    client = _client(cfg, args)

    purities   = _purities(args.purity)   or _purities(cfg.get("default_purity"))
    categories = _categories(args.categories)
    ratios     = _ratios(args.ratios) or (
                     [cfg.get("default_ratio")] if cfg.get("default_ratio") else None)
    atleast    = args.resolution or cfg.get("default_resolution") or None

    try:
        wallpapers, meta = client.search(
            categories = categories,
            purities   = purities,
            sorting    = Sorting.RANDOM,
            atleast    = atleast,
            ratios     = ratios,
        )
    except WallhavenError as e:
        print(f"{C.RED}API error:{C.RST} {e}", file=sys.stderr)
        return 1

    if not wallpapers:
        print("No wallpapers found.", file=sys.stderr)
        return 1

    picks = wallpapers[:args.pick]
    dest  = Path(args.dir) if args.dir else cfg.download_dir

    if args.download or args.print_path:
        for wp in picks:
            try:
                path = download_wallpaper(
                    wp, dest,
                    api_key       = cfg.api_key or None,
                    skip_existing = cfg.skip_existing,
                )
                # --print-path: clean single-line output for shell piping
                if args.print_path:
                    print(path)
                else:
                    print(f"{C.GRN}↓{C.RST} {path}")
            except Exception as e:
                print(f"{C.RED}✗{C.RST} {wp.id}: {e}", file=sys.stderr)
                return 1
    else:
        for wp in picks:
            print(fmt_detail(wp))

    return 0


# ── info ──────────────────────────────────────────────────────────────────

def cmd_info(args, cfg: Config) -> int:
    client = _client(cfg, args)
    for wid in args.ids:
        try:
            wp = client.get_wallpaper(wid)
            if args.json:
                import json, dataclasses
                print(json.dumps(dataclasses.asdict(wp), indent=2, default=str))
            else:
                print(fmt_detail(wp))
        except WallhavenError as e:
            print(f"{C.RED}✗{C.RST} {wid}: {e}", file=sys.stderr)
    return 0


# ── collections ───────────────────────────────────────────────────────────

def cmd_collections(args, cfg: Config) -> int:
    client = _client(cfg, args)
    try:
        if args.id:
            purities = _purities(args.purity)
            wallpapers, meta = client.get_collection_wallpapers(
                args.user or "", int(args.id), purities=purities, page=args.page
            )
            print_results(wallpapers, meta)
            if args.download and wallpapers:
                return _do_batch_download(wallpapers, cfg, args)
        else:
            cols = client.get_collections(args.user)
            if not cols:
                print("No collections found.")
                return 0
            print(f"\n{'ID':<8} {'Label':<30} {'Count':<8} Public")
            print("─" * 52)
            for c in cols:
                pub = f"{C.GRN}✓{C.RST}" if c.get("public") else f"{C.RED}✗{C.RST}"
                print(f"{c['id']:<8} {c.get('label',''):<30} {c.get('count',0):<8} {pub}")
            print()
    except AuthError as e:
        print(f"{C.RED}Auth error:{C.RST} {e}", file=sys.stderr)
        return 1
    except WallhavenError as e:
        print(f"{C.RED}API error:{C.RST} {e}", file=sys.stderr)
        return 1
    return 0


# ── config ────────────────────────────────────────────────────────────────

def cmd_config(args, cfg: Config) -> int:
    if args.config_cmd == "show":
        print(cfg.display())

    elif args.config_cmd == "path":
        print(cfg.path)

    elif args.config_cmd == "set":
        value = args.value
        if args.key in ("skip_existing", "verbose"):
            value = value.lower() in ("true", "1", "yes")
        elif args.key == "workers":
            value = int(value)
        
        # Verify API key if being set
        # Check for empty value or literal "" (common shell artifact)
        if args.key == "api_key" and value and value not in ('""', "''"):
            print(f"Verifying API key...", file=sys.stderr)
            # Try verification with header first
            test_client = WallhavenClient(api_key=value)
            try:
                test_client.get_user_settings()
                print(f"{C.GRN}✓{C.RST} API key is valid!", file=sys.stderr)
            except AuthError:
                print(f"{C.RED}✗{C.RST} Invalid API key. It was not saved.", file=sys.stderr)
                return 1
            except WallhavenError as e:
                # If /settings fails with 404, try collections or query param fallback
                # Some environments/proxies might return 404 for unauthorized access
                if "404" in str(e):
                    try:
                        # Try hitting search with apikey param directly to see if it's a header issue
                        # search id:1 is a safe, fast request
                        # Accessing BASE_URL via the global scope of the _get method
                        base_url = test_client._get.__globals__['BASE_URL']
                        params = {"q": "id:1", "apikey": value}
                        resp = test_client._sess.get(f"{base_url}/search", params=params, timeout=10)
                        if resp.status_code == 200:
                            print(f"{C.GRN}✓{C.RST} API key is valid (verified via search)! ", file=sys.stderr)
                        else:
                            print(f"{C.RED}✗{C.RST} Invalid API key (Server returned {resp.status_code}). It was not saved.", file=sys.stderr)
                            return 1
                    except Exception as e2:
                        print(f"{C.RED}✗{C.RST} Verification failed: {e2}", file=sys.stderr)
                        return 1
                else:
                    print(f"{C.RED}✗{C.RST} Verification failed: {e}", file=sys.stderr)
                    return 1
            except Exception as e:
                print(f"{C.RED}✗{C.RST} Verification failed: {e}", file=sys.stderr)
                return 1
        
        # If value is empty or quotes, we are clearing the key - just proceed to save
        if args.key == "api_key" and (not value or value in ('""', "''")):
            value = ""

        try:
            cfg.set(args.key, value)
            cfg.save()
            print(f"{C.GRN}✓{C.RST} {args.key} = {value!r}  (saved to {cfg.path})")
        except KeyError as e:
            print(f"{C.RED}Unknown key:{C.RST} {e}", file=sys.stderr)
            return 1

    return 0


# ══════════════════════════════════════════════════════════════════════════
#  Argument parser
# ══════════════════════════════════════════════════════════════════════════

def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        prog        = "python main.py",
        description = "Wallhaven.cc wallpaper downloader",
        formatter_class = argparse.RawDescriptionHelpFormatter,
        epilog = """
examples:
  python main.py search "mountain" --ratio 16x9 --sort toplist --range 1M
  python main.py search --categories anime --purity sfw --resolution 2560x1440 --download
  python main.py random --ratio 16x9 --resolution 1920x1080 --pick 1 --print-path
  python main.py download 94x38z ze1p56
  python main.py info 94x38z --json
  python main.py collections
  python main.py collections --user johndoe --id 42 --download
  python main.py config set api_key YOUR_KEY
  python main.py config set download_dir ~/Pictures/walls
  python main.py config show
        """,
    )
    parser.add_argument("--api-key", metavar="KEY",
                        help="Wallhaven API key (overrides config)")
    parser.add_argument("-v", "--verbose", action="store_true",
                        help="Debug logging")

    sub = parser.add_subparsers(dest="command", required=True)

    # ── search ────────────────────────────────────────────────────────────
    p = sub.add_parser("search", help="Search wallpapers")
    p.add_argument("query",        nargs="?",    default=None,
                   help="Search query. Supports: +tag -tag @user id:N like:ID")
    p.add_argument("--categories", metavar="C",  help="general,anime,people")
    p.add_argument("--purity",     metavar="P",  help="sfw,sketchy,nsfw")
    p.add_argument("--sort",
                   choices=[s.value for s in Sorting], default=None)
    p.add_argument("--order",
                   choices=["asc","desc"],        default=None)
    p.add_argument("--range",      metavar="R",
                   choices=[r.value for r in TopRange],
                   help="Toplist time window — requires --sort toplist")
    p.add_argument("--resolution", metavar="WxH", help="Minimum resolution e.g. 1920x1080")
    p.add_argument("--resolutions",metavar="LIST",help="Exact resolutions, comma-separated")
    p.add_argument("--ratios",     metavar="LIST",help="Aspect ratios e.g. 16x9,21x9")
    p.add_argument("--colors",     metavar="LIST",help="Hex colors, comma-separated")
    p.add_argument("--page",       type=int, default=1)
    p.add_argument("-n",           type=int, default=24, metavar="N",
                   help="Max results (default 24)")
    p.add_argument("--download",   action="store_true", help="Download results")
    p.add_argument("--dir",        metavar="PATH")
    p.add_argument("--json",       action="store_true", help="JSON output")

    # ── download ──────────────────────────────────────────────────────────
    p = sub.add_parser("download", aliases=["dl"],
                       help="Download wallpaper(s) by ID")
    p.add_argument("ids",    nargs="+", metavar="ID")
    p.add_argument("--dir",  metavar="PATH")
    p.add_argument("--force",action="store_true", help="Re-download if file exists")
    p.add_argument("--json", action="store_true", help="JSON output")

    # ── random ────────────────────────────────────────────────────────────
    p = sub.add_parser("random", help="Fetch random wallpaper(s)")
    p.add_argument("--categories", metavar="C")
    p.add_argument("--purity",     metavar="P")
    p.add_argument("--resolution", metavar="WxH", help="Minimum resolution")
    p.add_argument("--ratios",     metavar="RATIO", help="e.g. 16x9")
    p.add_argument("--pick",       type=int, default=1,
                   help="How many to pick (default 1)")
    p.add_argument("--download",   action="store_true")
    p.add_argument("--print-path", action="store_true",
                   help="Print file path only — for shell/quickshell piping")
    p.add_argument("--dir",        metavar="PATH")

    # ── info ──────────────────────────────────────────────────────────────
    p = sub.add_parser("info", help="Show wallpaper metadata")
    p.add_argument("ids",  nargs="+", metavar="ID")
    p.add_argument("--json", action="store_true")

    # ── collections ───────────────────────────────────────────────────────
    p = sub.add_parser("collections", help="Browse / download collections")
    p.add_argument("--user",     metavar="USERNAME")
    p.add_argument("--id",       metavar="ID",    help="Collection ID to browse")
    p.add_argument("--purity",   metavar="P")
    p.add_argument("--page",     type=int, default=1)
    p.add_argument("--download", action="store_true")
    p.add_argument("--dir",      metavar="PATH")

    # ── config ────────────────────────────────────────────────────────────
    p   = sub.add_parser("config", help="View / edit settings")
    cfg = p.add_subparsers(dest="config_cmd", required=True)
    cfg.add_parser("show", help="Print all settings")
    cfg.add_parser("path", help="Print config file path")
    s = cfg.add_parser("set",  help="Set a config value")
    s.add_argument("key")
    s.add_argument("value")

    return parser


# ══════════════════════════════════════════════════════════════════════════
#  Entry point
# ══════════════════════════════════════════════════════════════════════════

def main() -> int:
    parser = build_parser()
    args   = parser.parse_args()

    logging.basicConfig(
        format  = "%(levelname)s %(name)s: %(message)s",
        level   = logging.DEBUG if args.verbose else logging.WARNING,
        stream  = sys.stderr,
    )

    cfg = Config()

    handlers = {
        "search":      cmd_search,
        "download":    cmd_download,
        "dl":          cmd_download,
        "random":      cmd_random,
        "info":        cmd_info,
        "collections": cmd_collections,
        "config":      cmd_config,
    }

    try:
        return handlers[args.command](args, cfg)
    except KeyboardInterrupt:
        print("\nInterrupted.", file=sys.stderr)
        return 130
    except RateLimitError:
        print(
            f"{C.RED}Rate limited{C.RST} — Wallhaven allows 45 req/min. "
            "Wait a moment and retry.", file=sys.stderr
        )
        return 1
    except Exception as exc:
        if args.verbose:
            import traceback; traceback.print_exc()
        else:
            print(f"{C.RED}Error:{C.RST} {exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
