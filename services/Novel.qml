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
        if (!Config.extra.novel) {
            Toaster.toast(qsTr("Novel feature disabled"), qsTr("Enable it in the Control Center settings"), "book", Toast.Warning)
            return false
        }
        return true
    }

    readonly property string apiUrl: "http://127.0.0.1:5151"

    // ── Novel list ───────────────────────────────────────────────────────────
    property list<var> novelList: []
    property bool isFetchingNovel: false
    property string novelError: ""
    property bool hasMoreNovels: false
    property int currentOffset: 0
    property int latestPage: 1
    property string currentSearchText: ""
    property string currentGenre: ""
    property string currentStatus: "All"

    // ── Novel detail ─────────────────────────────────────────────────────────
    property var currentNovel: null
    property bool isFetchingDetail: false
    property string detailError: ""

    // ── Chapter text ─────────────────────────────────────────────────────────
    property var currentChapter: null
    property bool isFetchingChapter: false
    property string chapterError: ""
    property string currentChapterId: ""

    // ── Request tracking ─────────────────────────────────────────────────────
    property int _activeRequestId: 0

    // ── Provider ─────────────────────────────────────────────────────────────
    PersistentProperties {
        id: providerProps
        property string activeProvider: "freewebnovel"
        reloadableId: "novel_provider"
    }

    property alias activeProvider: providerProps.activeProvider
    property bool isSwitchingProvider: false
    readonly property var availableProviders: [
        { name: "novelbin",     label: "NovelBin"     },
        { name: "freewebnovel", label: "FreeWebNovel" }
    ]

    function switchProvider(name, force) {
        if (!root._checkEnabled()) return
        if (!force && (name === root.activeProvider || root.isSwitchingProvider)) return
        root.isSwitchingProvider = true
        _post(root.apiUrl + "/provider/switch", { provider: name }, function(err, body) {
            root.isSwitchingProvider = false
            if (err) { console.warn("[ServiceNovel] Provider switch failed:", err); return }
            root.activeProvider = name
            clearNovelList()
            clearDetail()
            clearChapter()
            fetchHot()
        })
    }

    // ── Library ──────────────────────────────────────────────────────────────
    property list<var> libraryList: []
    property bool libraryLoaded: false

    readonly property string _rootPath: Paths.toLocalFile(Qt.resolvedUrl(".."))
    readonly property string _libraryPath: Paths.config + "/data/new_novel_library.json"

    FileView {
        id: libraryFile
        path: root._libraryPath
        onLoaded: {
            try {
                var data = JSON.parse(libraryFile.text())
                root.libraryList = Array.isArray(data) ? data : []
            } catch (e) {
                console.warn("[ServiceNovel] library parse error:", e)
                root.libraryList = []
            }
            root.libraryLoaded = true
            console.log("[ServiceNovel] Library loaded —", root.libraryList.length, "entries")
        }
        onLoadFailed: {
            root.libraryList = []
            root.libraryLoaded = true
            console.log("[ServiceNovel] No library file found, starting fresh")
        }
    }

    FileView {
        id: libraryWriter
        path: root._libraryPath
    }

    function _saveLibrary() {
        libraryWriter.setText(JSON.stringify(root.libraryList, null, 2))
        libraryWriter.save()
    }

    function addToLibrary(novel) {
        if (!root._checkEnabled()) return
        if (isInLibrary(novel.id)) return
        var entry = {
            id:                 novel.id,
            title:              novel.title,
            coverUrl:           novel.coverUrl,
            lastReadChapterId:  "",
            lastReadChapterNum: "",
            addedAt:            new Date().toISOString()
        }
        root.libraryList = [entry, ...root.libraryList]
        _saveLibrary()
        console.log("[ServiceNovel] Added to library:", novel.title)
    }

    function removeFromLibrary(novelId) {
        if (!root._checkEnabled()) return
        root.libraryList = root.libraryList.filter(function(e) { return e.id !== novelId })
        _saveLibrary()
        console.log("[ServiceNovel] Removed from library:", novelId)
    }

    function isInLibrary(novelId) {
        return root.libraryList.some(function(e) { return e.id === novelId })
    }

    function updateLastRead(novelId, chapterId, chapterNum) {
        if (!root._checkEnabled()) return
        root.libraryList = root.libraryList.map(function(e) {
            if (e.id !== novelId) return e
            return Object.assign({}, e, {
                lastReadChapterId:  chapterId,
                lastReadChapterNum: chapterNum
            })
        })
        _saveLibrary()
        console.log("[ServiceNovel] Last read updated —", novelId, "ch.", chapterNum)
    }

    function getLibraryEntry(novelId) {
        for (var i = 0; i < root.libraryList.length; i++) {
            if (root.libraryList[i].id === novelId) return root.libraryList[i]
        }
        return null
    }

    Component.onCompleted: {
        console.log("[ServiceNovel] Singleton instantiated")
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
            root._rootPath + "/scripts/novel/main.py"
        ]
        running: false // Started by healthPoller if needed
        onExited: (code) => {
            root.serverReady = false
            if (code !== 0 && code !== 1) {
                console.warn("[ServiceNovel] Server exited with code", code)
            }
        }
    }

    Timer {
        id: healthPoller
        interval: 2000
        repeat: true
        running: true
        onTriggered: {
            if (!Config.extra.novel) {
                if (serverProcess.running) {
                    console.log("[ServiceNovel] Novel feature disabled, stopping backend...")
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
                            console.log("[ServiceNovel] Backend connected at", root.apiUrl)
                            
                            // Sync server with persisted provider
                            try {
                                var data = JSON.parse(xhr.responseText)
                                if (data.provider !== root.activeProvider) {
                                    console.log("[ServiceNovel] Syncing provider to:", root.activeProvider)
                                    switchProvider(root.activeProvider, true)
                                } else {
                                    fetchHot()
                                }
                            } catch (e) {
                                fetchHot()
                            }
                        }
                    } else {
                        root.serverReady = false
                        if (!serverProcess.running && Config.extra.novel) {
                            console.log("[ServiceNovel] Backend not found, starting process...")
                            serverProcess.running = true
                        }
                    }
                }
            }
            xhr.open("GET", root.apiUrl + "/health")
            xhr.send()
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

    // ── Browse / Search ───────────────────────────────────────────────────────
    function fetchHot() {
        if (!root._checkEnabled()) return
        if (!root.serverReady) return
        root.isFetchingNovel = false // Force reset state
        root.novelError = ""
        root.novelList = []
        root.currentSearchText = ""
        root.currentGenre = ""
        root.isFetchingNovel = true
        const reqId = ++root._activeRequestId
        _get(root.apiUrl + "/hot", function(err, body) {
            if (reqId !== root._activeRequestId) return
            if (err) { root.novelError = "Request failed: " + err; root.isFetchingNovel = false; return }
            _parseNovelResults(body, true)
        })
    }

    function fetchLatest(reset) {
        if (!root._checkEnabled()) return
        if (!root.serverReady) return
        if (reset) {
            root.isFetchingNovel = false
            root.novelList = [];
            root.latestPage = 1
        } else if (root.isFetchingNovel) {
            return
        }
        
        root.currentSearchText = ""
        root.isFetchingNovel = true
        root.novelError = ""
        const reqId = ++root._activeRequestId
        _get(root.apiUrl + "/latest?page=" + root.latestPage, function(err, body) {
            if (reqId !== root._activeRequestId) return
            if (err) { root.novelError = "Request failed: " + err; root.isFetchingNovel = false; return }
            _parseNovelResults(body, false)
        })
    }

    function searchNovels(query, genre, status, reset) {
        if (!root._checkEnabled()) return
        if (!root.serverReady || root.isFetchingNovel) return
        if (reset) { root.novelList = []; root.currentOffset = 0 }
        root.currentSearchText = query
        root.currentGenre = genre || ""
        root.currentStatus = status || "All"
        root.isFetchingNovel = true
        root.novelError = ""
        const reqId = ++root._activeRequestId
        var url = root.apiUrl + "/search?q=" + encodeURIComponent(query) + "&page=1"
        if (genre)  url += "&genre="  + encodeURIComponent(genre)
        if (status && status !== "All") url += "&status=" + encodeURIComponent(status)
        _get(url, function(err, body) {
            if (reqId !== root._activeRequestId) return
            if (err) { root.novelError = "Request failed: " + err; root.isFetchingNovel = false; return }
            _parseNovelResults(body, false)
        })
    }

    function fetchNextPage() {
        if (!root._checkEnabled()) return
        if (!root.serverReady || !root.hasMoreNovels || root.isFetchingNovel) return
        const reqId = ++root._activeRequestId
        if (root.currentSearchText.length > 0) {
            root.currentOffset++
            root.isFetchingNovel = true
            root.novelError = ""
            var url = root.apiUrl + "/search?q=" + encodeURIComponent(root.currentSearchText)
                + "&page=" + (root.currentOffset + 1)
            if (root.currentGenre)  url += "&genre="  + encodeURIComponent(root.currentGenre)
            if (root.currentStatus && root.currentStatus !== "All")
                url += "&status=" + encodeURIComponent(root.currentStatus)
            _get(url, function(err, body) {
                if (reqId !== root._activeRequestId) return
                if (err) { root.novelError = "Request failed: " + err; root.isFetchingNovel = false; return }
                _parseNovelResults(body, false)
            })
        } else {
            root.latestPage++
            fetchLatest(false)
        }
    }

    function _parseNovelResults(json, isHot) {
        try {
            const data = JSON.parse(json)
            if (data.error) { root.novelError = data.error; root.isFetchingNovel = false; return }

            const items = isHot ? data : (data.results || [])

            root.novelList = [...root.novelList, ...items.map(function(item) {
                return {
                    id:            item.id            || "",
                    title:         item.title         || "",
                    coverUrl:      item.image         || "",
                    author:        item.author        || "",
                    latestChapter: item.latestChapter || "",
                    status:        item.status        || ""
                }
            })]

            root.hasMoreNovels = isHot ? false : (data.hasMore || false)
            root.novelError = ""
        } catch (e) {
            root.novelError = "Parse error: " + e
            console.error("[ServiceNovel]", e)
        }
        root.isFetchingNovel = false
    }

    // ── Novel detail ──────────────────────────────────────────────────────────
    function fetchNovelDetail(novelId) {
        if (!root._checkEnabled()) return
        if (!root.serverReady || root.isFetchingDetail) return
        root.isFetchingDetail = true
        root.currentNovel = null
        root.detailError = ""
        const url = root.apiUrl + "/info?id=" + encodeURIComponent(novelId)
        _get(url, function(err, body) {
            if (err) { root.detailError = "Request failed: " + err; root.isFetchingDetail = false; return }
            _parseNovelDetail(body)
        })
    }

    function _parseNovelDetail(json) {
        try {
            const data = JSON.parse(json)
            if (data.error) { root.detailError = data.error; root.isFetchingDetail = false; return }
            root.currentNovel = {
                id:          data.id          || "",
                title:       data.title       || "",
                description: data.description || "",
                status:      data.status      || "",
                author:      data.author      || "",
                coverUrl:    data.image       || "",
                genres:      data.genres      || [],
                chapters:    (data.chapters || []).map(function(ch) {
                    return {
                        id:      ch.id      || "",
                        chapter: ch.chapter || "",
                        title:   ch.title   || ""
                    }
                })
            }
            root.detailError = ""
        } catch (e) {
            root.detailError = "Parse error: " + e
            console.error("[ServiceNovel]", e)
        }
        root.isFetchingDetail = false
    }

    // ── Chapter reading ───────────────────────────────────────────────────────
    function fetchChapter(chapterId) {
        if (!root._checkEnabled()) return
        if (!root.serverReady || root.isFetchingChapter) return
        root.isFetchingChapter = true
        root.currentChapterId = chapterId
        root.currentChapter = null
        root.chapterError = ""
        const url = root.apiUrl + "/chapter?id=" + encodeURIComponent(chapterId)
        _get(url, function(err, body) {
            if (err) { root.chapterError = "Request failed: " + err; root.isFetchingChapter = false; return }
            _parseChapter(body)
        })
    }

    function _parseChapter(json) {
        try {
            const data = JSON.parse(json)
            if (data.error) { root.chapterError = data.error; root.isFetchingChapter = false; return }
            root.currentChapter = {
                id:         data.id         || "",
                title:      data.title      || "",
                paragraphs: data.paragraphs || [],
                wordCount:  data.wordCount  || 0,
                prevId:     data.prevId     || "",
                nextId:     data.nextId     || ""
            }
            root.chapterError = ""
        } catch (e) {
            root.chapterError = "Parse error: " + e
            console.error("[ServiceNovel]", e)
        }
        root.isFetchingChapter = false
    }

    function fetchPrevChapter() {
        if (!root._checkEnabled()) return
        if (!root.currentChapter || root.currentChapter.prevId === "") return
        fetchChapter(root.currentChapter.prevId)
    }

    function fetchNextChapter() {
        if (!root._checkEnabled()) return
        if (!root.currentChapter || root.currentChapter.nextId === "") return
        fetchChapter(root.currentChapter.nextId)
    }

    // ── Utility ───────────────────────────────────────────────────────────────
    function clearNovelList() {
        console.log("[ServiceNovel] Clearing novel list")
        root.novelList = []
        root.hasMoreNovels = false
        root.currentOffset = 0
        root.latestPage = 1
        root.novelError = ""
    }

    function clearChapter() {
        root.currentChapter = null
        root.currentChapterId = ""
        root.chapterError = ""
    }

    function clearDetail() {
        root.currentNovel = null
        root.detailError = ""
    }

    Connections {
        target: Config.extra
        function onNovelChanged() {
            if (!Config.extra.novel && serverProcess.running) {
                console.log("[ServiceNovel] [DEBUG] Novel feature disabled: stopping backend process immediately.")
                serverProcess.running = false
                root.serverReady = false
            }
        }
    }
}
