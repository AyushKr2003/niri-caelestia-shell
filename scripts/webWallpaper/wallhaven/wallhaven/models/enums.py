from enum import Enum


class Category(str, Enum):
    GENERAL = "general"
    ANIME   = "anime"
    PEOPLE  = "people"


class Purity(str, Enum):
    SFW     = "sfw"
    SKETCHY = "sketchy"
    NSFW    = "nsfw"


class Sorting(str, Enum):
    DATE_ADDED = "date_added"
    RELEVANCE  = "relevance"
    RANDOM     = "random"
    VIEWS      = "views"
    FAVORITES  = "favorites"
    TOPLIST    = "toplist"


class Order(str, Enum):
    DESC = "desc"
    ASC  = "asc"


class TopRange(str, Enum):
    ONE_DAY      = "1d"
    THREE_DAYS   = "3d"
    ONE_WEEK     = "1w"
    ONE_MONTH    = "1M"
    THREE_MONTHS = "3M"
    SIX_MONTHS   = "6M"
    ONE_YEAR     = "1y"
