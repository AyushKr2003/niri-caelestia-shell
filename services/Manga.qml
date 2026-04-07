pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.config
import qs.utils
import Caelestia

Singleton {
    id: root

    function _checkEnabled() {
        if (!Config.extra.manga) {
            Toaster.toast(qsTr("Manga feature disabled"), qsTr("Enable it in the Control Center settings"), "manga", Toast.Warning)
            return false
        }
        return true
    }

    readonly property string apiUrl: "http://127.0.0.1:5150"

    // ── Manga list ───────────────────────────────────────────────────────────
    property list<var> mangaList: []
    property bool isFetchingManga: false
    property string mangaError: ""
    property bool hasMoreManga: false
    property int currentOffset: 0
    property int latestPage: 1
    property string currentSearchText: ""
    property string currentOrigin: ""

    // ── Manga detail ─────────────────────────────────────────────────────────
    property var currentManga: null
    property bool isFetchingDetail: false
    property string detailError: ""

    // ── Chapter pages ────────────────────────────────────────────────────────
    property list<var> chapterPages: []
    property bool isFetchingPages: false
    property string pagesError: ""
    property string currentChapterId: ""
    property bool dataSaverMode: false

    // ── Favorites ────────────────────────────────────────────────────────────
    property list<var> favoritesList: []
    property bool isFetchingFavs: false
    property int favNewCount: 0

    // ── Downloads ────────────────────────────────────────────────────────────
    property list<var> downloadsList: []
    property var downloadProgress: ({})

    // ── Request tracking ─────────────────────────────────────────────────────
    property int _activeRequestId: 0

    // ── Library ──────────────────────────────────────────────────────────────
    // Each entry: { id, title, coverUrl, lastReadChapterId, lastReadChapterNum, addedAt }
    property list<var> libraryList: []
    property bool libraryLoaded: false

    readonly property string _rootPath: Paths.toLocalFile(Qt.resolvedUrl(".."))
    readonly property string _libraryPath: Paths.config + "/data/manga_library.json"

    // FileView for reading
    FileView {
        id: libraryFile
        path: root._libraryPath
        onLoaded: {
            try {
                var data = JSON.parse(libraryFile.text())
                root.libraryList = Array.isArray(data) ? data : []
            } catch (e) {
                console.warn("[ServiceManga] library parse error:", e)
                root.libraryList = []
            }
            root.libraryLoaded = true
            console.log("[ServiceManga] Library loaded —", root.libraryList.length, "entries")
        }
        onLoadFailed: {
            // File doesn't exist yet — start empty
            root.libraryList = []
            root.libraryLoaded = true
            console.log("[ServiceManga] No library file found, starting fresh")
        }
    }

    // FileView for writing
    FileView {
        id: libraryWriter
        path: root._libraryPath
    }

    function _saveLibrary() {
        libraryWriter.setText(JSON.stringify(root.libraryList, null, 2))
        libraryWriter.save()
    }

    function addToLibrary(manga) {
        // manga must have: id, title, coverUrl
        if (isInLibrary(manga.id)) return
        var entry = {
            id:                  manga.id,
            title:               manga.title,
            coverUrl:            manga.coverUrl,
            lastReadChapterId:   "",
            lastReadChapterNum:  "",
            addedAt:             new Date().toISOString()
        }
        root.libraryList = [entry, ...root.libraryList]
        _saveLibrary()
        console.log("[ServiceManga] Added to library:", manga.title)
    }

    function removeFromLibrary(mangaId) {
        root.libraryList = root.libraryList.filter(function(e) { return e.id !== mangaId })
        _saveLibrary()
        console.log("[ServiceManga] Removed from library:", mangaId)
    }

    function isInLibrary(mangaId) {
        return root.libraryList.some(function(e) { return e.id === mangaId })
    }

    function updateLastRead(mangaId, chapterId, chapterNum) {
        root.libraryList = root.libraryList.map(function(e) {
            if (e.id !== mangaId) return e
            return Object.assign({}, e, {
                lastReadChapterId:  chapterId,
                lastReadChapterNum: chapterNum
            })
        })
        _saveLibrary()
        console.log("[ServiceManga] Last read updated —", mangaId, "ch.", chapterNum)
    }

    function getLibraryEntry(mangaId) {
        for (var i = 0; i < root.libraryList.length; i++) {
            if (root.libraryList[i].id === mangaId) return root.libraryList[i]
        }
        return null
    }

    // Load library as soon as the singleton initialises
    Component.onCompleted: {
        console.log("[ServiceManga] Singleton instantiated")
        libraryFile.reload()
    }

    // ── Backend server ───────────────────────────────────────────────────────
    property bool serverReady: false

    Process {
        id: serverProcess
        command: [
            "bash", "-c",
            "export CAELESTIA_DATA_DIR=\"$1\" && exec \"$2\" \"$3\"",
            "--",
            Paths.config + "/data",
            (Quickshell.env("CAELESTIA_VIRTUAL_ENV") || (Quickshell.env("XDG_STATE_HOME") || (Quickshell.env("HOME") + "/.local/state")) + "/quickshell/.venv") + "/bin/python3",
            root._rootPath + "/scripts/manga/manga_server.py"
        ]
        running: false // Started by healthPoller if needed
        onExited: (code) => {
            root.serverReady = false
            if (code !== 0 && code !== 1) { // 1 usually means 'port busy' which we handle via lazy start
                console.warn("[ServiceManga] Server exited with code", code)
            }
        }
    }

    Timer {
        id: healthPoller
        interval: 2000
        repeat: true
        running: true
        onTriggered: {
            if (!Config.extra.manga) {
                if (serverProcess.running) {
                    console.log("[ServiceManga] Manga feature disabled, stopping backend...")
                    serverProcess.running = false
                }
                root.serverReady = false
                return
            }

            var xhr = new XMLHttpRequest()
            xhr.onreadystatechange = function() {
                if (xhr.readyState === 4) {
                    if (xhr.status === 200) {
                        if (!root.serverReady) {
                            root.serverReady = true
                            console.log("[ServiceManga] Backend connected at", root.apiUrl)
                            fetchByOrigin("", true)
                            fetchFavorites()
                            fetchDownloads()
                        }
                    } else {
                        root.serverReady = false
                        if (!serverProcess.running && Config.extra.manga) {
                            console.log("[ServiceManga] Backend not found, starting process...")
                            serverProcess.running = true
                        }
                    }
                }
            }
            xhr.open("GET", root.apiUrl + "/health")
            xhr.send()
        }
    }

    Timer {
        id: favChecker
        interval: 900000
        repeat: true
        running: root.serverReady && root.favoritesList.length > 0
        onTriggered: checkFavoritesForUpdates()
    }

    Timer {
        id: dlPoller
        interval: 500
        repeat: true
        running: false
        onTriggered: {
            var hasActive = false
            var ids = Object.keys(root.downloadProgress)
            for (var i = 0; i < ids.length; i++) {
                var st = root.downloadProgress[ids[i]].status
                if (st === "downloading" || st === "pending") { hasActive = true; break }
            }
            if (!hasActive) { dlPoller.stop(); return }
            for (var j = 0; j < ids.length; j++) {
                var s = root.downloadProgress[ids[j]].status
                if (s === "downloading" || s === "pending")
                    _pollOne(ids[j])
            }
        }
    }

    // ── HTTP helpers ──────────────────────────────────────────────────────────
    function _get(url, onDone) {
        var xhr = new XMLHttpRequest()
        xhr.onreadystatechange = function() {
            if (xhr.readyState !== 4) return
            if (xhr.status === 200) onDone(null, xhr.responseText)
            else onDone("HTTP " + xhr.status, null)
        }
        xhr.open("GET", url)
        xhr.send()
    }

    function _post(url, data, onDone) {
        var xhr = new XMLHttpRequest()
        xhr.onreadystatechange = function() {
            if (xhr.readyState !== 4) return
            if (xhr.status === 200) onDone(null, xhr.responseText)
            else onDone("HTTP " + xhr.status, null)
        }
        xhr.open("POST", url)
        xhr.setRequestHeader("Content-Type", "application/json")
        xhr.send(JSON.stringify(data))
    }

    // ── Origin → type mapping ─────────────────────────────────────────────────
    function _originType(origin) {
        if (origin === "ko") return "Manhwa"
        if (origin === "ja") return "Manga"
        if (origin === "zh") return "Manhua"
        return ""
    }

    // ── Browse / Search ───────────────────────────────────────────────────────
    function fetchByOrigin(origin, reset) {
        if (!root._checkEnabled()) return
        if (!root.serverReady) return
        if (reset) {
            root.isFetchingManga = false
            root.mangaList = []
            root.currentOffset = 0
            root.latestPage = 1
        } else if (root.isFetchingManga) {
            return
        }
        
        root.currentOrigin = origin
        root.currentSearchText = ""
        const reqId = ++root._activeRequestId

        if (origin === "") {
            root.isFetchingManga = true
            root.mangaError = ""
            const url = root.apiUrl + "/hot"
            _get(url, function(err, body) {
                if (reqId !== root._activeRequestId) return
                if (err) { root.mangaError = "Request failed: " + err; root.isFetchingManga = false; return }
                _parseMangaResults(body)
            })
        } else if (origin === "latest") {
            if (reset) root.latestPage = 1
            root.isFetchingManga = true
            root.mangaError = ""
            const url = root.apiUrl + "/latest?page=" + root.latestPage
            _get(url, function(err, body) {
                if (reqId !== root._activeRequestId) return
                if (err) { root.mangaError = "Request failed: " + err; root.isFetchingManga = false; return }
                _parseMangaResults(body)
            })
        } else {
            _doSearch("a", _originType(origin), root.currentOffset, "Popularity", reqId)
        }
    }

    function searchManga(query, reset) {
        if (!root._checkEnabled()) return
        if (!root.serverReady || root.isFetchingManga) return
        if (reset) { root.mangaList = []; root.currentOffset = 0 }
        root.currentSearchText = query
        const reqId = ++root._activeRequestId
        _doSearch(query, _originType(root.currentOrigin), root.currentOffset, "Best Match", reqId)
    }

    function fetchNextMangaPage() {
        if (!root._checkEnabled()) return
        if (!root.serverReady || !root.hasMoreManga || root.isFetchingManga) return
        const reqId = ++root._activeRequestId
        if (root.currentSearchText.length > 0) {
            _doSearch(root.currentSearchText, _originType(root.currentOrigin), root.currentOffset, "Best Match", reqId)
        } else if (root.currentOrigin === "latest") {
            root.latestPage++
            fetchByOrigin("latest", false)
        } else {
            _doSearch("a", _originType(root.currentOrigin), root.currentOffset, "Popularity", reqId)
        }
    }

    function _doSearch(query, type, offset, sort, reqId) {
        root.isFetchingManga = true
        root.mangaError = ""
        let url = root.apiUrl + "/search?q=" + encodeURIComponent(query)
            + "&offset=" + offset + "&sort=" + encodeURIComponent(sort)
        if (type) url += "&type=" + encodeURIComponent(type)
        _get(url, function(err, body) {
            if (reqId !== root._activeRequestId) return
            if (err) { root.mangaError = "Request failed: " + err; root.isFetchingManga = false; return }
            _parseMangaResults(body)
        })
    }

    function _parseMangaResults(json) {
        try {
            const data = JSON.parse(json)
            if (data.error) { root.mangaError = data.error; root.isFetchingManga = false; return }

            const isHot    = Array.isArray(data)
            const isLatest = !isHot && data.nextPage !== undefined
            const items    = isHot ? data : (data.results || [])

            root.mangaList = [...root.mangaList, ...items.map(item => ({
                id:       item.id     || "",
                title:    item.title  || "",
                thumbUrl: item.image  || "",
                status:   item.status || "",
                type:     item.type   || "",
                author:   ""
            }))]

            root.hasMoreManga = isHot ? false : (data.hasMore || false)
            if (!isHot && !isLatest)
                root.currentOffset = data.nextOffset || (root.currentOffset + items.length)

            root.mangaError = ""
        } catch (e) {
            root.mangaError = "Parse error: " + e
            console.error("[ServiceManga]", e)
        }
        root.isFetchingManga = false
    }

    // ── Manga detail ──────────────────────────────────────────────────────────
    function fetchMangaDetail(mangaId) {
        if (!root._checkEnabled()) return
        if (!root.serverReady || root.isFetchingDetail) return
        root.isFetchingDetail = true
        root.currentManga = null
        root.detailError = ""
        const url = root.apiUrl + "/info?id=" + encodeURIComponent(mangaId)
        _get(url, function(err, body) {
            if (err) { root.detailError = "Request failed: " + err; root.isFetchingDetail = false; return }
            _parseMangaDetail(body)
        })
    }

    function _parseMangaDetail(json) {
        try {
            const data = JSON.parse(json)
            if (data.error) { root.detailError = data.error; root.isFetchingDetail = false; return }
            root.currentManga = {
                id:          data.id          || "",
                title:       data.title       || "",
                description: data.description || "",
                status:      data.status      || "",
                year:        0,
                coverUrl:    data.image       || "",
                authors:     data.authors     || [],
                tags:        data.tags        || [],
                chapters:    (data.chapters   || []).map(ch => ({
                    id:        ch.id        || "",
                    chapter:   ch.chapter   || "",
                    title:     ch.title     || "",
                    pages:     0,
                    group:     "",
                    publishAt: ch.publishAt || ""
                }))
            }
            root.detailError = ""
        } catch (e) {
            root.detailError = "Parse error: " + e
            console.error("[ServiceManga]", e)
        }
        root.isFetchingDetail = false
    }

    // ── Chapter pages ─────────────────────────────────────────────────────────
    function fetchChapterPages(chapterId) {
        if (!root._checkEnabled()) return
        if (!root.serverReady || root.isFetchingPages) return
        root.isFetchingPages = true
        root.currentChapterId = chapterId
        root.chapterPages = []
        root.pagesError = ""
        const url = root.apiUrl + "/pages?chapterId=" + encodeURIComponent(chapterId)
        _get(url, function(err, body) {
            if (err) { root.pagesError = "Request failed: " + err; root.isFetchingPages = false; return }
            _parseChapterPages(body)
        })
    }

    function fetchOfflineChapterPages(chapterId) {
        if (!root._checkEnabled()) return
        if (!root.serverReady || root.isFetchingPages) return
        root.isFetchingPages = true
        root.currentChapterId = chapterId
        root.chapterPages = []
        root.pagesError = ""
        const url = root.apiUrl + "/dl/pages?chapterId=" + encodeURIComponent(chapterId)
        _get(url, function(err, body) {
            if (err) { root.pagesError = "Request failed: " + err; root.isFetchingPages = false; return }
            _parseChapterPages(body)
        })
    }

    function _parseChapterPages(json) {
        try {
            const data = JSON.parse(json)
            if (data.error || !Array.isArray(data)) {
                root.pagesError = data.error || "Invalid response"
                root.isFetchingPages = false
                return
            }
            if (data.length === 0) {
                root.pagesError = "No pages found for this chapter"
                root.isFetchingPages = false
                return
            }
            root.chapterPages = data.map((p, idx) => ({
                index:     idx,
                url:       p.img || "",
                localPath: p.img || "",
                ready:     true
            }))
            root.pagesError = ""
            root.isFetchingPages = false
        } catch (e) {
            root.pagesError = "Parse error: " + e
            root.isFetchingPages = false
        }
    }

    // ── Favorites ─────────────────────────────────────────────────────────────
    function fetchFavorites() {
        if (!root.serverReady || root.isFetchingFavs) return
        root.isFetchingFavs = true
        _get(root.apiUrl + "/favorites", function(err, body) {
            root.isFetchingFavs = false
            if (err) { console.warn("[ServiceManga] favorites fetch failed:", err); return }
            try {
                const data = JSON.parse(body)
                root.favoritesList = data
                root.favNewCount = data.filter(f => f.hasNewChapters).length
            } catch (e) {
                console.error("[ServiceManga] favorites parse error:", e)
            }
        })
    }

    function addFavorite(manga) {
        if (!root._checkEnabled()) return
        if (!root.serverReady) return
        const rawUrl = _extractRawUrl(manga.coverUrl)
        _post(root.apiUrl + "/favorites/add",
            { id: manga.id, title: manga.title, imageUrl: rawUrl },
                function(err, body) { if (!err) fetchFavorites() })
    }

    function removeFavorite(mangaId) {
        if (!root._checkEnabled()) return
        if (!root.serverReady) return
        _post(root.apiUrl + "/favorites/remove", { id: mangaId },
                function(err, body) { if (!err) fetchFavorites() })
    }

    function isFavorite(mangaId) {
        return root.favoritesList.some(f => f.id === mangaId)
    }

    function markChapterSeen(mangaId, chapterId) {
        if (!root._checkEnabled()) return
        if (!root.serverReady) return
        _post(root.apiUrl + "/favorites/mark-seen",
            { id: mangaId, chapterId: chapterId },
                function(err, body) { if (!err) fetchFavorites() })
    }

    function checkFavoritesForUpdates() {
        if (!root.serverReady) return
        _get(root.apiUrl + "/favorites/check", function(err, body) {
            if (err) { console.warn("[ServiceManga] fav check failed:", err); return }
            try {
                const data = JSON.parse(body)
                if (data.updated && data.updated.length > 0) fetchFavorites()
            } catch (e) {}
        })
    }

    // ── Downloads ─────────────────────────────────────────────────────────────
    function fetchDownloads() {
        if (!root.serverReady) return
        _get(root.apiUrl + "/dl/list", function(err, body) {
            if (err) { console.warn("[ServiceManga] dl/list failed:", err); return }
            try { root.downloadsList = JSON.parse(body) }
            catch (e) { console.error("[ServiceManga] dl/list parse error:", e) }
        })
    }

    function startDownload(chapter, manga) {
        if (!root._checkEnabled()) return
        if (!root.serverReady) return
        const rawCover = _extractRawUrl(manga.coverUrl)
        var dp = Object.assign({}, root.downloadProgress)
        dp[chapter.id] = { status: "pending", total: 0, done: 0 }
        root.downloadProgress = dp
        dlPoller.start()
        _post(root.apiUrl + "/dl/start", {
            mangaId:      manga.id,
            chapterId:    chapter.id,
            chapterNum:   chapter.chapter,
            chapterTitle: chapter.title,
            mangaTitle:   manga.title,
            rawCoverUrl:  rawCover
        }, function(err, body) {
            if (err) {
                var dp2 = Object.assign({}, root.downloadProgress)
                dp2[chapter.id] = { status: "error", total: 0, done: 0 }
                root.downloadProgress = dp2
            }
        })
    }

    function _pollOne(chapterId) {
        if (!root.serverReady) return
        _get(root.apiUrl + "/dl/progress?chapterId=" + encodeURIComponent(chapterId),
                function(err, body) {
                if (err) return
                try {
                    const prog = JSON.parse(body)
                    var dp = Object.assign({}, root.downloadProgress)
                    dp[chapterId] = prog
                    root.downloadProgress = dp
                    if (prog.status === "done") fetchDownloads()
                } catch(e) {}
            })
    }

    function getDownloadProgress(chapterId) {
        return root.downloadProgress[chapterId] || { status: "not_started", total: 0, done: 0 }
    }

    function deleteDownload(chapterId) {
        if (!root._checkEnabled()) return
        if (!root.serverReady) return
        _post(root.apiUrl + "/dl/delete", { chapterId: chapterId },
                function(err, body) { if (!err) fetchDownloads() })
    }

    // ── Utility ───────────────────────────────────────────────────────────────
    function _extractRawUrl(proxyUrl) {
        const match = proxyUrl.match(/[?&]url=([^&]+)/)
        return match ? decodeURIComponent(match[1]) : proxyUrl
    }

    function downloadMorePages(upTo) {}

    function refreshChapterPages() {
        if (!root.serverReady || root.currentChapterId.length === 0) return
        root.chapterPages = []
        fetchChapterPages(root.currentChapterId)
    }

    function clearChapterList() {
        if (root.currentManga)
            root.currentManga = Object.assign({}, root.currentManga, { chapters: [] })
    }

    function clearChapterPages() {
        root.chapterPages = []
        root.currentChapterId = ""
        root.pagesError = ""
    }

    function clearMangaList() {
        console.log("[ServiceManga] Clearing manga list")
        root.mangaList = []
        root.hasMoreManga = false
        root.currentOffset = 0
        root.latestPage = 1
        root.mangaError = ""
    }

    Connections {
        target: Config.extra
        function onMangaChanged() {
            if (!Config.extra.manga && serverProcess.running) {
                console.log("[ServiceManga] [DEBUG] Manga feature disabled: stopping backend process immediately.")
                serverProcess.running = false
                root.serverReady = false
            }
        }
    }
}
