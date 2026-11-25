import QtQuick
import "AMLL.js" as AMLL

// AMLL online lyric backend: used when the player exposes no lyrics of its own.
// Every request goes through the sliding window limiter, and a 429 reply lowers the
// budget from 50 to 30 requests per second for the rest of the session.
// AMLL 在线歌词后端：播放器自身没有歌词时使用。
// 所有请求都经过滑动窗口限流；收到 429 后，本次会话余下时间的
// 预算由每秒 50 次降为每秒 30 次。
QtObject {
    id: root

    // Lyrics sink injected by the provider registry
    // 由提供器注册中心注入的歌词接收方
    property var lyrics: null
    // MPRIS player of the current media app, injected by the provider registry
    // 当前媒体应用的 MPRIS 播放器，由提供器注册中心注入
    property var positionPlayer: null

    // Track metadata mirrored from MPRIS
    // 由 MPRIS 同步的曲目信息
    property string trackTitle: ""
    property string artistName: ""
    property string albumName: ""
    property bool playing: false
    // Only the registry decides when this backend owns the lyric sink
    // 仅当注册中心判定由本后端起效时才占用歌词接收方
    property bool active: false

    readonly property var defaults: AMLL.defaults()
    property string apiBaseUrl: root.defaults.apiBaseUrl
    property int requestTimeout: 8000
    // The service allows 50 requests per second; 429 lowers the ceiling to 30
    // 服务端允许每秒 50 次请求；收到 429 后上限降为 30
    property int requestLimit: root.defaults.requestLimit
    property int throttledRequestLimit: root.defaults.throttledRequestLimit
    property int retryLimit: 3
    // Parsed lyrics stay cached for this many tracks
    // 已解析歌词的缓存曲目数
    property int cacheLimit: root.defaults.cacheLimit
    property int positionInterval: 250
    property int resyncInterval: 2000

    // Current track identity used by every request and cache lookup
    // 当前曲目标识，供请求与缓存查找使用
    property string trackKey: ""
    // Track whose lyrics are already applied
    // 歌词已就绪的曲目
    property string lyricsTrackKey: ""
    property string lastError: ""
    property bool throttled: false
    property bool outageLogged: false
    property bool throttleLogged: false

    property var lineCache: AMLL.createLineCache(root.cacheLimit)
    readonly property var limiter: AMLL.createRateLimiter(root.requestLimit, root.throttledRequestLimit)

    // Pending reads and the ones still in flight, keyed by request URL
    // 等待中的读取与仍在途的读取，以请求地址为键
    property var queue: []
    property var inflight: ({})

    // Position is extrapolated locally between MPRIS updates
    // 位置在两次 MPRIS 更新之间本地外推
    property real position: 0
    property real duration: 0
    property real anchorPosition: 0
    property double anchorWallMs: 0
    property real anchorTolerance: 250

    readonly property Timer trackTimer: Timer {
        // Long enough to let title, artist and album settle after one metadata change
        // 足够长，使一次元数据变更中的标题、艺术家与专辑都已完成更新
        interval: 150
        repeat: false

        onTriggered: root.refreshTrack()
    }

    readonly property Timer dispatchTimer: Timer {
        repeat: false

        onTriggered: root.dispatch()
    }

    readonly property Timer advanceTimer: Timer {
        interval: root.positionInterval
        repeat: true
        running: root.active && root.playing

        onTriggered: root.advancePosition()
    }

    // Players do not push position changes while playing, so ask for one regularly
    // 播放期间播放器不会主动推送位置变化，因此定期主动查询
    readonly property Timer resyncTimer: Timer {
        interval: root.resyncInterval
        repeat: true
        running: root.active && root.playing

        onTriggered: root.requestPlayerPosition()
    }

    readonly property Connections positionWatcher: Connections {
        target: root.positionPlayer

        function onPositionChanged() {
            root.applyPlayerPosition();
        }
    }

    Component.onCompleted: {
        root.syncDurationFromPlayer();
        root.applyPlayerPosition();
    }

    // Three metadata fields change for one track switch, so coalesce them
    // 一次切歌会连续改动三个字段，因此合并刷新
    onTrackTitleChanged: root.trackTimer.restart()
    onArtistNameChanged: root.trackTimer.restart()
    onAlbumNameChanged: root.trackTimer.restart()
    onPlayingChanged: root.applyPlayerPosition()
    onActiveChanged: root.handleActiveChanged()
    onPositionPlayerChanged: {
        root.syncDurationFromPlayer();
        root.applyPlayerPosition();
    }

    function trackState() {
        return {
            "title": root.trackTitle,
            "artist": root.artistName,
            "album": root.albumName
        };
    }

    function handleActiveChanged() {
        if (!root.active) {
            root.cancelRequests();
            root.clearOwnLines();
            return;
        }

        root.syncDurationFromPlayer();
        root.applyPlayerPosition();
        root.refreshTrack();
        root.requestLyrics();
    }

    function refreshTrack() {
        const nextKey = AMLL.trackKey(root.trackState());
        if (nextKey === root.trackKey) {
            return;
        }

        root.trackKey = nextKey;
        root.lyricsTrackKey = "";
        root.cancelRequests();
        if (!root.active) {
            return;
        }

        root.clearOwnLines();
        root.syncAnchor(0, true);
        root.requestLyrics();
    }

    // Lyrics come from the cache when this track was already resolved
    // 该曲目此前已解析时直接从缓存取歌词
    function requestLyrics() {
        const key = root.trackKey;
        if (!root.active || key.length === 0 || key === root.lyricsTrackKey) {
            return;
        }

        const cached = root.lineCache.get(key);
        if (cached !== null) {
            root.applyLines(key, cached);
            return;
        }
        if (root.hasPending(key)) {
            return;
        }

        const track = root.trackState();
        root.enqueue(AMLL.searchUrl(root.apiBaseUrl, track, root.defaults.searchPageSize), key, function(payload) {
            root.handleSearch(key, track, payload);
        }, function() {
            root.noteMiss(key, "歌词搜索失败");
        });
    }

    function handleSearch(key, track, payload) {
        if (!root.active || key !== root.trackKey) {
            return;
        }

        const data = payload !== null && typeof payload === "object" ? payload.data : null;
        const items = data !== null && typeof data === "object" && Array.isArray(data.items) ? data.items : [];
        const item = AMLL.selectBestItem(items, track);
        if (item === null) {
            root.noteMiss(key, "未匹配到歌词");
            return;
        }

        root.enqueue(AMLL.lyricUrl(root.apiBaseUrl, item.id), key, function(reply) {
            root.handleLyric(key, reply);
        }, function() {
            root.noteMiss(key, "歌词获取失败");
        });
    }

    function handleLyric(key, payload) {
        if (!root.active || key !== root.trackKey) {
            return;
        }

        const data = payload !== null && typeof payload === "object" ? payload.data : null;
        const ttml = data !== null && typeof data === "object" && typeof data.lyrics === "string"
            ? data.lyrics
            : "";
        const lines = AMLL.parseTtml(ttml);
        if (lines.length === 0) {
            root.noteMiss(key, "歌词内容为空");
            return;
        }

        root.lineCache.put(key, lines);
        root.applyLines(key, lines);
    }

    function applyLines(key, lines) {
        if (!root.active || key !== root.trackKey) {
            return;
        }

        root.lyricsTrackKey = key;
        if (root.lyrics === null) {
            return;
        }
        // The online database carries no offset of its own
        // 在线数据库不提供歌词偏移
        if (typeof root.lyrics.syncOffset === "function") {
            root.lyrics.syncOffset(0);
        }
        if (typeof root.lyrics.setLines === "function") {
            root.lyrics.setLines(lines, "amll");
        }
        if (typeof root.lyrics.syncDuration === "function") {
            root.lyrics.syncDuration(root.duration);
        }
        root.syncLyricsPosition();
    }

    function clearOwnLines() {
        root.lyricsTrackKey = "";
        if (root.lyrics !== null && typeof root.lyrics.clear === "function") {
            root.lyrics.clear("amll");
        }
    }

    function noteMiss(key, message) {
        if (!root.active || key !== root.trackKey) {
            return;
        }
        root.lastError = message;
        console.info("[Sparkle Land] AMLL 歌词不可用：", message, root.trackTitle);
    }

    // Queue one read; the dispatcher starts it once the rate window allows
    // 入队一次读取，待频率窗口允许时由调度器发起
    function enqueue(url, key, onSuccess, onFailure) {
        root.queue.push({
            "url": url,
            "key": key,
            "onSuccess": onSuccess,
            "onFailure": onFailure,
            "attempts": 0,
            "notBefore": 0
        });
        root.scheduleDispatch();
    }

    // Queued and in-flight reads both count, so a re-activation cannot duplicate them
    // 排队中与在途的读取都计入，避免重新激活时重复请求
    function hasPending(key) {
        for (let index = 0; index < root.queue.length; ++index) {
            if (root.queue[index].key === key) {
                return true;
            }
        }

        const urls = Object.keys(root.inflight);
        for (let index = 0; index < urls.length; ++index) {
            if (root.inflight[urls[index]].key === key) {
                return true;
            }
        }
        return false;
    }

    // Wait out either the rate window or the retry backoff of the earliest entry
    // 等待频率窗口或最早条目重试退避中较晚结束的那个
    function scheduleDispatch() {
        if (!root.active || root.queue.length === 0) {
            root.dispatchTimer.stop();
            return;
        }

        const now = Date.now();
        const rateWait = root.limiter.delay(now);
        let wait = -1;
        for (let index = 0; index < root.queue.length; ++index) {
            const entryWait = Math.max(rateWait, Math.max(0, root.queue[index].notBefore - now));
            if (wait < 0 || entryWait < wait) {
                wait = entryWait;
            }
        }

        if (wait <= 0) {
            root.dispatch();
            return;
        }
        root.dispatchTimer.interval = Math.max(1, Math.ceil(wait));
        root.dispatchTimer.restart();
    }

    function dispatch() {
        if (!root.active || root.queue.length === 0) {
            return;
        }

        const now = Date.now();
        for (let index = 0; index < root.queue.length; ) {
            const entry = root.queue[index];
            if (entry.notBefore > now) {
                ++index;
                continue;
            }
            if (root.limiter.delay(now) > 0) {
                break;
            }
            root.queue.splice(index, 1);
            root.limiter.record(now);
            root.startRequest(entry);
        }
        root.scheduleDispatch();
    }

    function startRequest(entry) {
        const request = new XMLHttpRequest();
        let settled = false;

        root.inflight[entry.url] = {
            "request": request,
            "key": entry.key
        };

        function settle(handler) {
            if (settled) {
                return;
            }
            settled = true;
            const slot = root.inflight[entry.url];
            if (slot !== undefined && slot.request === request) {
                delete root.inflight[entry.url];
            }
            handler();
            root.scheduleDispatch();
        }

        request.open("GET", entry.url);
        request.timeout = root.requestTimeout;
        request.onreadystatechange = function() {
            if (request.readyState !== XMLHttpRequest.DONE) {
                return;
            }
            settle(function() {
                root.handleResponse(entry, request.status, request.responseText);
            });
        };
        request.ontimeout = function() {
            settle(function() {
                root.noteFailure("请求超时");
                root.retryRequest(entry);
            });
        };
        request.onerror = function() {
            settle(function() {
                root.noteFailure("网络错误");
                root.retryRequest(entry);
            });
        };
        request.send();
    }

    function handleResponse(entry, status, body) {
        if (!root.active || entry.key !== root.trackKey) {
            return;
        }

        if (status === 200) {
            let payload = null;
            try {
                payload = JSON.parse(body);
            } catch (error) {
                payload = null;
            }
            if (payload !== null && typeof payload === "object") {
                if (typeof entry.onSuccess === "function") {
                    entry.onSuccess(payload);
                }
            } else {
                root.retryRequest(entry);
            }
            return;
        }

        if (status === 429) {
            root.noteThrottled();
            root.retryRequest(entry);
            return;
        }

        // A missing lyric will not appear by retrying, so it ends the request
        // 歌词不存在时重试没有意义，直接结束该请求
        if (status === 404) {
            if (typeof entry.onFailure === "function") {
                entry.onFailure();
            }
            return;
        }

        root.noteFailure("HTTP " + status);
        root.retryRequest(entry);
    }

    function retryRequest(entry) {
        if (!root.active || entry.key !== root.trackKey) {
            return;
        }
        if (entry.attempts >= root.retryLimit) {
            if (typeof entry.onFailure === "function") {
                entry.onFailure();
            }
            return;
        }

        entry.attempts += 1;
        entry.notBefore = Date.now() + 1000 * entry.attempts;
        root.queue.push(entry);
    }

    function noteThrottled() {
        root.limiter.noteStatus(429);
        root.throttled = root.limiter.throttled();
        if (!root.throttleLogged) {
            root.throttleLogged = true;
            root.lastError = "AMLL 接口已限流";
            console.info("[Sparkle Land] AMLL 接口返回 429，请求上限降至每秒 30 次");
        }
    }

    function noteFailure(message) {
        root.lastError = message;
        if (!root.outageLogged) {
            root.outageLogged = true;
            console.info("[Sparkle Land] AMLL 请求失败：", message);
        }
    }

    function cancelRequests() {
        root.queue = [];
        root.dispatchTimer.stop();

        const urls = Object.keys(root.inflight);
        for (let index = 0; index < urls.length; ++index) {
            const request = root.inflight[urls[index]].request;
            delete root.inflight[urls[index]];
            request.onreadystatechange = null;
            request.ontimeout = null;
            request.onerror = null;
            request.abort();
        }
    }

    function syncDurationFromPlayer() {
        const player = root.positionPlayer;
        if (player === null) {
            root.duration = 0;
            return;
        }

        const microseconds = Number(player.length);
        if (!isFinite(microseconds) || microseconds <= 0) {
            return;
        }

        root.duration = Math.round(microseconds / 1000);
        if (root.active && root.lyrics !== null && typeof root.lyrics.syncDuration === "function") {
            root.lyrics.syncDuration(root.duration);
        }
    }

    function requestPlayerPosition() {
        const player = root.positionPlayer;
        if (player !== null && typeof player.updatePosition === "function") {
            player.updatePosition();
        }
    }

    // MPRIS reports microseconds, the lyric timeline works in milliseconds
    // MPRIS 使用微秒，歌词时间轴使用毫秒
    function applyPlayerPosition() {
        const player = root.positionPlayer;
        if (player === null) {
            return;
        }

        const microseconds = Number(player.position);
        if (!isFinite(microseconds) || microseconds < 0) {
            return;
        }

        root.syncDurationFromPlayer();
        root.syncAnchor(microseconds / 1000, !root.playing);
    }

    function syncAnchor(milliseconds, force) {
        const value = Math.max(0, Number(milliseconds) || 0);
        if (!force && root.playing && Math.abs(value - root.position) < root.anchorTolerance) {
            return;
        }

        root.anchorPosition = root.duration > 0 ? Math.min(value, root.duration) : value;
        root.anchorWallMs = Date.now();
        root.setPosition(root.anchorPosition);
    }

    function advancePosition() {
        if (!root.playing) {
            return;
        }
        const estimate = root.anchorPosition + (Date.now() - root.anchorWallMs);
        root.setPosition(root.duration > 0 ? Math.min(estimate, root.duration) : estimate);
    }

    function setPosition(milliseconds) {
        const value = Math.max(0, Number(milliseconds) || 0);
        if (root.position === value) {
            return;
        }

        root.position = value;
        root.syncLyricsPosition();
    }

    function syncLyricsPosition() {
        if (!root.active || root.lyrics === null || typeof root.lyrics.syncPosition !== "function") {
            return;
        }
        root.lyrics.syncPosition(root.position);
    }
}
