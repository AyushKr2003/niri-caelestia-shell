"""
Wallhaven API v1 client.

Covers all official endpoints:
  /api/v1/search
  /api/v1/w/{id}
  /api/v1/tag/{id}
  /api/v1/settings          (requires API key)
  /api/v1/collections       (requires API key)
  /api/v1/collections/{username}/{id}
"""

import time
import logging
from typing import Optional, List, Dict, Any, Tuple

import requests
from requests.adapters import HTTPAdapter
from urllib3.util.retry import Retry

from wallhaven.models.wallpaper import Wallpaper, SearchMeta
from wallhaven.models.enums import Category, Purity, Sorting, Order, TopRange

log = logging.getLogger(__name__)

BASE_URL          = "https://wallhaven.cc/api/v1"
RATE_LIMIT        = 45          # requests per minute
_MIN_INTERVAL     = 60.0 / RATE_LIMIT   # ~1.33 s between requests


# ── Exceptions ────────────────────────────────────────────────────────────

class WallhavenError(Exception):
    def __init__(self, status: int, msg: str):
        self.status = status
        super().__init__(f"HTTP {status}: {msg}")

class RateLimitError(WallhavenError):
    pass

class AuthError(WallhavenError):
    pass


# ── Session factory ───────────────────────────────────────────────────────

def _session(retries: int = 3) -> requests.Session:
    s = requests.Session()
    r = Retry(
        total=retries,
        backoff_factor=1.5,
        status_forcelist=[500, 502, 503, 504],
        allowed_methods=["GET"],
    )
    adapter = HTTPAdapter(max_retries=r)
    s.mount("https://", adapter)
    s.mount("http://",  adapter)
    return s


# ── Bitmask helpers ───────────────────────────────────────────────────────

def _categories_mask(cats: List[Category]) -> str:
    return (
        f"{'1' if Category.GENERAL in cats else '0'}"
        f"{'1' if Category.ANIME   in cats else '0'}"
        f"{'1' if Category.PEOPLE  in cats else '0'}"
    )

def _purity_mask(purities: List[Purity]) -> str:
    return (
        f"{'1' if Purity.SFW     in purities else '0'}"
        f"{'1' if Purity.SKETCHY in purities else '0'}"
        f"{'1' if Purity.NSFW    in purities else '0'}"
    )


# ── Client ────────────────────────────────────────────────────────────────

class WallhavenClient:
    """
    Thin, rate-limited wrapper around the Wallhaven v1 REST API.

    Args:
        api_key  - Optional key from wallhaven.cc/settings/account.
                   Required for NSFW content and authenticated endpoints.
        timeout  - (connect_s, read_s) per request.
        retries  - Auto-retry count on server errors (5xx).
    """

    def __init__(
        self,
        api_key:  Optional[str]       = None,
        timeout:  Tuple[int, int]     = (5, 30),
        retries:  int                 = 3,
    ):
        self.api_key = api_key
        self.timeout = timeout
        self._sess   = _session(retries)
        self._last_t: float = 0.0

    # ── internal ──────────────────────────────────────────────────────────

    def _headers(self) -> Dict[str, str]:
        h = {"Accept": "application/json"}
        if self.api_key:
            h["X-API-Key"] = self.api_key
        return h

    def _throttle(self) -> None:
        wait = _MIN_INTERVAL - (time.monotonic() - self._last_t)
        if wait > 0:
            time.sleep(wait)

    def _get(self, path: str, params: Optional[Dict] = None) -> Dict[str, Any]:
        url    = f"{BASE_URL}{path}"
        params = {k: v for k, v in (params or {}).items() if v is not None}

        self._throttle()
        log.debug("GET %s  params=%s", url, params)

        try:
            resp = self._sess.get(
                url, headers=self._headers(), params=params, timeout=self.timeout
            )
        finally:
            self._last_t = time.monotonic()

        if resp.status_code == 401:
            raise AuthError(401, "Invalid or missing API key.")
        if resp.status_code == 429:
            raise RateLimitError(429, "Rate limit hit (45 req/min). Wait a moment.")
        if not resp.ok:
            raise WallhavenError(resp.status_code, resp.text[:300])

        return resp.json()

    # ── public API ────────────────────────────────────────────────────────

    def search(
        self,
        q:           Optional[str]           = None,
        categories:  Optional[List[Category]] = None,
        purities:    Optional[List[Purity]]   = None,
        sorting:     Optional[Sorting]        = None,
        order:       Optional[Order]          = None,
        top_range:   Optional[TopRange]       = None,
        atleast:     Optional[str]            = None,   # "1920x1080"
        resolutions: Optional[List[str]]      = None,
        ratios:      Optional[List[str]]      = None,
        colors:      Optional[List[str]]      = None,
        page:        int                      = 1,
        seed:        Optional[str]            = None,
    ) -> Tuple[List[Wallpaper], SearchMeta]:
        params: Dict[str, Any] = {
            "q":           q,
            "sorting":     sorting.value   if sorting   else None,
            "order":       order.value     if order     else None,
            "topRange":    top_range.value if top_range else None,
            "atleast":     atleast,
            "resolutions": ",".join(resolutions) if resolutions else None,
            "ratios":      ",".join(ratios)      if ratios      else None,
            "colors":      ",".join(c.lstrip("#") for c in colors) if colors else None,
            "page":        page,
            "seed":        seed,
        }
        if categories:
            params["categories"] = _categories_mask(categories)
        if purities:
            params["purity"] = _purity_mask(purities)

        data = self._get("/search", params)
        return (
            [Wallpaper.from_dict(w) for w in data.get("data", [])],
            SearchMeta.from_dict(data.get("meta", {})),
        )

    def get_wallpaper(self, wallpaper_id: str) -> Wallpaper:
        return Wallpaper.from_dict(self._get(f"/w/{wallpaper_id}")["data"])

    def get_tag(self, tag_id: int) -> Dict[str, Any]:
        return self._get(f"/tag/{tag_id}")["data"]

    def get_user_settings(self) -> Dict[str, Any]:
        """Requires API key."""
        return self._get("/settings")["data"]

    def get_collections(self, username: Optional[str] = None) -> List[Dict]:
        path = f"/collections/{username}" if username else "/collections"
        return self._get(path)["data"]

    def get_collection_wallpapers(
        self,
        username:      str,
        collection_id: int,
        purities:      Optional[List[Purity]] = None,
        page:          int                    = 1,
    ) -> Tuple[List[Wallpaper], SearchMeta]:
        params: Dict[str, Any] = {"page": page}
        if purities:
            params["purity"] = _purity_mask(purities)
        data = self._get(f"/collections/{username}/{collection_id}", params)
        return (
            [Wallpaper.from_dict(w) for w in data.get("data", [])],
            SearchMeta.from_dict(data.get("meta", {})),
        )
