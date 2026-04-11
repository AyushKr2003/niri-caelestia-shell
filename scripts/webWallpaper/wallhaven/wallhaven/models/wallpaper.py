from dataclasses import dataclass, field
from typing import Optional, List, Dict


@dataclass
class WallpaperThumb:
    large:    str
    original: str
    small:    str


@dataclass
class Wallpaper:
    id:          str
    url:         str
    short_url:   str
    path:        str        # direct image download URL
    purity:      str
    category:    str
    dimension_x: int
    dimension_y: int
    resolution:  str
    ratio:       str
    file_size:   int
    file_type:   str
    thumbs:      WallpaperThumb
    views:       int              = 0
    favorites:   int              = 0
    source:      str              = ""
    created_at:  Optional[str]    = None
    colors:      List[str]        = field(default_factory=list)
    tags:        List[Dict]       = field(default_factory=list)

    @classmethod
    def from_dict(cls, data: dict) -> "Wallpaper":
        t = data.get("thumbs", {})
        return cls(
            id          = data["id"],
            url         = data.get("url", ""),
            short_url   = data.get("short_url", ""),
            path        = data.get("path", ""),
            purity      = data.get("purity", "sfw"),
            category    = data.get("category", ""),
            dimension_x = data.get("dimension_x", 0),
            dimension_y = data.get("dimension_y", 0),
            resolution  = data.get("resolution", ""),
            ratio       = data.get("ratio", ""),
            file_size   = data.get("file_size", 0),
            file_type   = data.get("file_type", ""),
            thumbs      = WallpaperThumb(
                large    = t.get("large", ""),
                original = t.get("original", ""),
                small    = t.get("small", ""),
            ),
            views      = data.get("views", 0),
            favorites  = data.get("favorites", 0),
            source     = data.get("source", ""),
            created_at = data.get("created_at"),
            colors     = data.get("colors", []),
            tags       = data.get("tags", []),
        )

    @property
    def extension(self) -> str:
        if self.file_type:
            return self.file_type.split("/")[-1].replace("jpeg", "jpg")
        return self.path.rsplit(".", 1)[-1] if "." in self.path else "jpg"

    @property
    def file_size_human(self) -> str:
        size = self.file_size
        for unit in ("B", "KB", "MB", "GB"):
            if size < 1024:
                return f"{size:.1f} {unit}"
            size /= 1024
        return f"{size:.1f} GB"

    def __str__(self) -> str:
        return (
            f"[{self.id}] {self.resolution} "
            f"{self.category}/{self.purity} "
            f"({self.file_size_human}) ❤ {self.favorites}"
        )


@dataclass
class SearchMeta:
    current_page: int
    last_page:    int
    per_page:     int
    total:        int
    query:        Optional[str]
    seed:         Optional[str]

    @classmethod
    def from_dict(cls, meta: dict) -> "SearchMeta":
        return cls(
            current_page = meta.get("current_page", 1),
            last_page    = meta.get("last_page", 1),
            per_page     = meta.get("per_page", 24),
            total        = meta.get("total", 0),
            query        = meta.get("query"),
            seed         = meta.get("seed"),
        )
