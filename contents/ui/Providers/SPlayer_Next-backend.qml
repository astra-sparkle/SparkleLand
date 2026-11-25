import QtQuick
import QtWebSockets
import "SPlayer_Next.js" as SPlayerNext

// SPlayer-Next WebSocket backend: playback events, control commands and lyric delivery
// SPlayer-Next WebSocket 后端：播放事件、控制命令与歌词下发
QtObject {
    id: root

    // Lyrics sink injected by the provider registry
    // 由提供器注册中心注入的歌词接收方
    property var lyrics: null
    // MPRIS player of the same app, injected by the provider registry
    // 同一应用的 MPRIS 播放器，由提供器注册中心注入
    property var positionPlayer: null

    // SPlayer-Next shares one port between the socket and the HTTP API
    // SPlayer-Next 的套接字与 HTTP 接口共用同一端口
    property string url: "ws://127.0.0.1:14558/ws"
    // The socket is opened only while MPRIS reports an SPlayer-Next playback session,
    // and only once per session: a failed attempt waits until that target is lost
    // 仅在 MPRIS 报告 SPlayer-Next 播放会话期间建立连接，且每次会话只尝试一次：
    // 失败后等待该目标消失，再重新开始
    property bool sessionAttempted: false
    // Give up on a hanging handshake instead of leaving the socket connecting forever
    // 握手无响应时放弃，避免套接字长期停留在连接中状态
    property int connectTimeout: 8000
    // HTTP reads: at most one request per endpoint, aborted when it takes too long
    // HTTP 读取：每个端点同时最多一个请求，超时即中止
    property int requestTimeout: 4000
    // Lyric fetches retry a bounded number of times per track
    // 每首曲目的歌词请求有次数上限的重试
    property int lyricsRetryLimit: 3
    property int lyricsRetryInterval: 3000
    // Position advances locally between server snapshots, lyric ticks never touch the API
    // 位置在两次服务端快照之间本地推进，歌词刷新不访问接口
    property int positionInterval: 250
    // The socket pushes status only on transport changes, so one light snapshot per
    // interval guarantees that seeks are calibrated within 2 s in every state
    // 套接字仅在传输状态变化时推送 status，因此每个间隔一次轻量快照
    // 可保证任何状态下跳转都在 2 秒内完成校准
    property int resyncInterval: 2000

    // Connection state
    // 连接状态
    property bool connected: false
    property int clientCount: 0
    property string lastError: ""
    // Keep one log line per outage instead of one per retry
    // 每次断线只记录一条日志，避免重试刷屏
    property bool outageLogged: false
    // Endpoint path to the request still in flight, so a slow server cannot pile up reads
    // 仍在途中的请求路径，避免响应缓慢时堆积读取
    property var inflightRequests: ({})

    // Playback state mirrored from the SPlayer-Next events
    // 由 SPlayer-Next 事件同步的播放状态
    property bool playing: false
    property string playState: ""
    property string trackId: ""
    property string trackKey: ""
    property string songTitle: ""
    property string artistName: ""
    property string albumName: ""
    property string coverUrl: ""
    property real position: 0
    property real duration: 0
    // Anchor pair used to extrapolate the position while playing
    // 播放期间用于外推位置的锚点对
    property real anchorPosition: 0
    property double anchorWallMs: 0
    // Playback rate reported by the status frames, used to scale extrapolation
    // 状态帧上报的播放速率，用于缩放外推
    property real playbackRate: 1
    // Snapshots that differ less than this keep the smoother local estimate
    // 差异小于该值的快照保留更平滑的本地估算
    property real anchorTolerance: 250
    // Track whose lyrics are already applied
    // 歌词已就绪的曲目
    property string lyricsTrackKey: ""
    // Track whose lyric request is still in flight
    // 歌词请求仍在进行中的曲目
    property string lyricsRequestKey: ""
    // Failed lyric requests for the current track, capped by lyricsRetryLimit
    // 当前曲目的歌词请求失败次数，上限为 lyricsRetryLimit
    property int lyricsRetries: 0
    // Parsed lyrics are reused across replays and panel rebuilds, kept for 30 tracks
    // 已解析歌词在重播与面板重建时复用，最多保留 30 首
    property int cacheLimit: 30
    property var lineCache: SPlayerNext.createLineCache(root.cacheLimit)

    signal connectionChanged()
    signal songChanged()
    signal playbackChanged()
    signal progressChanged()
    signal lyricChanged()
    signal errorOccurred(string message)

    // HTTP endpoint derived from the socket address
    // 由套接字地址推导的 HTTP 接口地址
    readonly property string apiBaseUrl: {
        const base = root.url.replace(/^ws/, "http").replace(/\/ws$/, "");
        return base + "/api";
    }

    // MPRIS titles use the same track title as the socket events
    // MPRIS 标题与套接字事件的曲目标题一致
    readonly property bool mprisMatched: root.positionPlayer !== null
        && root.songTitle.length > 0
        && root.positionPlayer.track === root.songTitle

    readonly property WebSocket socket: WebSocket {
        url: root.url
        active: false

        onTextMessageReceived: function(message) {
            root.handleMessage(message);
        }
        onStatusChanged: function(status) {
            root.handleStatus(status);
        }
    }

    // Abandon a handshake that never completes; the session keeps its single attempt
    // 放弃始终未完成的握手；该播放会话仍只保留这一次尝试
    readonly property Timer connectTimer: Timer {
        interval: root.connectTimeout
        repeat: false

        onTriggered: {
            if (root.connected || root.socket.status !== WebSocket.Connecting) {
                return;
            }
            root.handleConnectTimeout();
        }
    }

    readonly property Timer lyricsRetryTimer: Timer {
        interval: root.lyricsRetryInterval
        repeat: false

        onTriggered: root.requestLyrics()
    }

    readonly property Timer positionTimer: Timer {
        interval: root.positionInterval
        repeat: true
        running: root.playing

        onTriggered: root.advancePosition()
    }

    readonly property Timer resyncTimer: Timer {
        interval: root.resyncInterval
        repeat: true
        running: root.connected

        onTriggered: root.requestSnapshot()
    }

    // MPRIS position updates arrive on seeks and transport changes for free
    // MPRIS 位置更新在跳转与播放状态变化时自动到达，无需额外开销
    readonly property Connections positionWatcher: Connections {
        target: root.positionPlayer

        function onPositionChanged() {
            root.applyPlayerPosition();
        }
    }

    onPositionPlayerChanged: root.refreshPlayerPosition()

    // The connection lifetime belongs to the provider registry: it calls
    // requestConnection() when MPRIS starts reporting SPlayer-Next playback and
    // releaseSession() when that target disappears. Nothing connects on its own and
    // nothing retries in the background.
    // 连接生命周期由提供器注册中心掌握：MPRIS 开始报告 SPlayer-Next 播放时调用
    // requestConnection()，该目标消失时调用 releaseSession()。组件不会自行连接，
    // 也不会在后台重试。

    // Open the socket at most once per playback session
    // 每次播放会话最多打开一次套接字
    function requestConnection(targetPlaying) {
        const allowed = SPlayerNext.shouldAttemptConnection({
            "attempted": root.sessionAttempted,
            "connected": root.connected,
            "connecting": root.socket.status === WebSocket.Connecting,
            "targetPlaying": targetPlaying === true
        });
        if (!allowed || root.url.length === 0) {
            return false;
        }

        root.sessionAttempted = true;
        root.outageLogged = false;
        // Toggle active because a socket left active by a failed attempt will not reopen by itself
        // 切换 active，因为失败后仍为活动状态的套接字不会自行重连
        root.socket.active = false;
        root.socket.active = true;
        root.connectTimer.restart();
        return true;
    }

    // End the current session so the next playback may try once more
    // 结束当前会话，使下一次播放可以再尝试一次
    function releaseSession() {
        root.sessionAttempted = false;
        root.connectTimer.stop();
        root.cancelRequests();
        if (root.socket.active) {
            root.socket.active = false;
        }
        if (root.playing) {
            root.playing = false;
            root.playbackChanged();
        }
        root.playState = "";
        root.clearLyrics();
    }

    function handleConnectTimeout() {
        root.lastError = "连接超时";
        if (!root.outageLogged) {
            root.outageLogged = true;
            console.info("[Sparkle Land] SPlayer-Next 连接超时，本次播放不再重试：", root.url);
        }
        root.socket.active = false;
    }

    // Send a command message; returns false while disconnected
    // 发送命令消息；未连接时返回 false
    //
    // Provider API: transport and playback commands are reached through the registry.
    // Everything below stays available even while the panel does not call it yet, so a
    // future compact layout or media page can use the same backend.
    // 提供器接口：传输与播放命令通过注册中心访问。以下接口即使当前面板尚未调用也保留，
    // 供后续紧凑布局或媒体页继续复用同一后端。
    function sendText(text) {
        if (!root.connected) {
            return false;
        }
        root.socket.sendTextMessage(text);
        return true;
    }

    function sendCommand(op, payload) {
        return root.sendText(SPlayerNext.commandMessage(op, payload));
    }

    function play() {
        root.sendCommand("play");
    }

    function pause() {
        root.sendCommand("pause");
    }

    function stop() {
        root.sendCommand("stop");
    }

    function next() {
        root.sendCommand("next");
    }

    function previous() {
        root.sendCommand("prev");
    }

    function toggle() {
        if (root.playing) {
            root.pause();
        } else {
            root.play();
        }
    }

    function seek(positionMs) {
        const value = Math.max(0, Number(positionMs) || 0);
        if (root.sendCommand("seek", { "positionMs": value })) {
            // Trust the requested position immediately instead of waiting for the resync
            // 立即采用请求的位置，无需等待校准
            root.syncAnchor(value, true);
        }
    }

    function setVolume(volume) {
        root.sendCommand("setVolume", { "volume": Math.min(1, Math.max(0, Number(volume) || 0)) });
    }

    function handleStatus(status) {
        if (status === WebSocket.Open) {
            root.connectTimer.stop();
            if (root.connected) {
                return;
            }
            root.connected = true;
            root.lastError = "";
            root.outageLogged = false;
            console.info("[Sparkle Land] SPlayer-Next WebSocket 已连接");
            root.connectionChanged();
            // The socket pushes changes only, so read the current snapshot once
            // 套接字只推送变化，因此先读取一次当前快照
            root.requestSnapshot();
            return;
        }

        if (status === WebSocket.Connecting) {
            return;
        }

        // Any teardown ends what this session could read, so pending reads are dropped
        // 任何断开都意味着本次会话无法再读取，因此丢弃在途请求
        root.connectTimer.stop();
        root.cancelRequests();

        if (root.connected) {
            root.connected = false;
            console.info("[Sparkle Land] SPlayer-Next WebSocket 已断开");
            root.connectionChanged();
        }

        // Without the socket nothing refreshes playback or lyrics, so stale state must not
        // keep extrapolating a position
        // 断开后没有事件刷新播放与歌词，因此不能让过期状态继续外推位置
        if (root.playing) {
            root.playing = false;
            root.playbackChanged();
        }
        if (root.trackKey.length > 0) {
            root.clearLyrics();
        }
        root.playState = "";

        // No retry here: a failed attempt waits for the next playback session
        // 此处不重试：失败的尝试等待下一次播放会话
        if (status === WebSocket.Error) {
            root.lastError = root.socket.errorString;
            if (!root.outageLogged) {
                root.outageLogged = true;
                console.info("[Sparkle Land] SPlayer-Next 服务不可用，本次播放不再重试：", root.lastError);
            }
        }
    }

    function handleMessage(rawMessage) {
        const message = SPlayerNext.parseMessage(rawMessage);
        if (message === null) {
            console.warn("[Sparkle Land] SPlayer-Next 消息无法解析：", rawMessage);
            return;
        }

        if (message.kind === "hello") {
            root.clientCount = Number(message.clients) || 0;
            return;
        }
        if (message.kind === "error") {
            root.reportError(typeof message.error === "string" ? message.error : "");
            return;
        }
        if (message.kind !== "event") {
            return;
        }

        switch (message.type) {
        case "status":
            root.applyStatus(message.data);
            break;
        case "track":
            root.applyTrack(message.data.track);
            break;
        case "lyric":
            root.applyLyricLines(message.data.lyric);
            break;
        case "lyricOffset":
            root.applyLyricOffset(message.data.offsetMs);
            break;
        case "ended":
            root.applyEnded();
            break;
        default:
            break;
        }
    }

    function applyStatus(data) {
        const previousState = root.playState;
        if (typeof data.state === "string" && data.state !== root.playState) {
            root.playState = data.state;
        }
        const nextPlaying = root.playState === "playing";
        if (nextPlaying !== root.playing) {
            root.playing = nextPlaying;
            root.playbackChanged();
        }

        const statusDuration = Number(data.duration);
        if (isFinite(statusDuration) && statusDuration > 0) {
            root.setDuration(statusDuration);
        }
        // Status frames carry the rate, snapshots repeat it every interval
        // 状态帧包含播放速率，快照每隔一个间隔重复提供
        const rate = Number(data.speed);
        if (isFinite(rate) && rate > 0) {
            root.playbackRate = rate;
        }
        if (typeof data.position === "number" && isFinite(data.position)) {
            // Transport changes must re-anchor so the pause time is not extrapolated
            // 传输状态变化必须重设锚点，避免把暂停时长计入外推
            root.syncAnchor(data.position, root.playState !== previousState);
        }
    }

    function applyEnded() {
        if (!root.playing) {
            return;
        }
        root.playing = false;
        root.playbackChanged();
    }

    function applyTrack(track) {
        const nextTrack = SPlayerNext.trackState(track);
        if (nextTrack === null) {
            if (root.trackId.length > 0) {
                root.trackId = "";
                root.trackKey = "";
                root.songTitle = "";
                root.artistName = "";
                root.albumName = "";
                root.coverUrl = "";
                root.setDuration(0);
                root.syncAnchor(0, true);
                root.clearLyrics();
                root.songChanged();
            }
            return;
        }

        const trackChanged = nextTrack.key !== root.trackKey || nextTrack.title !== root.songTitle;
        // Re-emitting on every snapshot would make consumers refresh needlessly
        // 每次快照都发信号会让消费者做无谓刷新
        const metadataChanged = trackChanged
            || nextTrack.artist !== root.artistName
            || nextTrack.album !== root.albumName
            || nextTrack.cover !== root.coverUrl;
        root.trackId = nextTrack.id;
        root.trackKey = nextTrack.key;
        root.songTitle = nextTrack.title;
        root.artistName = nextTrack.artist;
        root.albumName = nextTrack.album;
        root.coverUrl = nextTrack.cover;
        if (nextTrack.duration > 0) {
            root.setDuration(nextTrack.duration);
        }
        if (trackChanged) {
            root.syncAnchor(0, true);
            root.clearLyrics();
            // Replays reuse the parsed lines instead of a second request
            // 重播时复用已解析歌词行，不再请求
            const cachedLines = root.lineCache.get(nextTrack.key);
            if (cachedLines !== null) {
                root.lyricsTrackKey = nextTrack.key;
                root.showLines(cachedLines);
            } else {
                root.requestLyrics();
            }
        }
        if (metadataChanged) {
            root.songChanged();
        }
    }

    function applyLyricLines(source) {
        const lines = SPlayerNext.normalizeLines(source);
        // An empty event must not wipe lines the player already delivered
        // 空事件不得清掉播放器已送达的歌词
        if (lines.length === 0) {
            return;
        }
        if (root.trackKey.length > 0) {
            root.lineCache.put(root.trackKey, lines);
            // The player pushed the lines itself, so this track needs no fetch
            // 播放器主动送达了歌词，该曲目无需再请求
            root.lyricsTrackKey = root.trackKey;
            root.lyricsRetries = 0;
            root.lyricsRetryTimer.stop();
        }
        root.showLines(lines);
    }

    function showLines(lines) {
        if (root.lyrics !== null && typeof root.lyrics.setLines === "function") {
            root.lyrics.setLines(lines, "splayer");
        }
        root.lyricChanged();
    }

    // Positive offsets show the lyrics earlier, matching the player behaviour
    // 正偏移使歌词提前，与播放器行为一致
    function applyLyricOffset(offsetMs) {
        if (root.lyrics !== null && typeof root.lyrics.syncOffset === "function") {
            root.lyrics.syncOffset(offsetMs);
        }
    }

    // Abort every read that is still in flight, used when the socket goes away
    // 中止所有在途读取，套接字断开时调用
    function cancelRequests() {
        const paths = Object.keys(root.inflightRequests);
        for (let index = 0; index < paths.length; ++index) {
            root.abortRequest(paths[index]);
        }
        root.inflightRequests = {};
    }

    function abortRequest(path) {
        const request = root.inflightRequests[path];
        if (request === undefined || request === null) {
            return;
        }
        // Drop the handlers first so the abort cannot be reported as a failure
        // 先移除回调，避免中止被当作读取失败上报
        request.onreadystatechange = null;
        request.ontimeout = null;
        request.abort();
        delete root.inflightRequests[path];
    }

    // One read per endpoint at a time: a slow server must not stack requests up behind
    // the resync timer, and a hanging read gives up instead of blocking forever
    // 同一端点同时只发起一个读取：响应缓慢的服务器不会让请求堆积在同步定时器之后，
    // 长时间无响应的读取会主动放弃而不是永久阻塞
    function requestJson(path, onSuccess, onFailure) {
        const previous = root.inflightRequests[path];
        if (previous !== undefined && previous !== null) {
            return false;
        }

        const request = new XMLHttpRequest();
        root.inflightRequests[path] = request;

        function finish(ok, payload) {
            // A newer read for the same endpoint took over; this reply is stale
            // 同一端点已有更新的读取接管，本次响应视为过期
            if (root.inflightRequests[path] !== request) {
                return;
            }
            delete root.inflightRequests[path];
            if (ok) {
                onSuccess(payload);
            } else if (typeof onFailure === "function") {
                onFailure();
            }
        }

        request.open("GET", root.apiBaseUrl + path);
        request.timeout = root.requestTimeout;
        request.onreadystatechange = function() {
            if (request.readyState !== XMLHttpRequest.DONE) {
                return;
            }
            if (request.status !== 200) {
                root.noteFailure("HTTP " + request.status + " " + path);
                finish(false);
                return;
            }

            let payload = null;
            try {
                payload = JSON.parse(request.responseText);
            } catch (error) {
                root.noteFailure("无法解析 " + path + " 响应");
                finish(false);
                return;
            }
            finish(true, payload);
        };
        request.ontimeout = function() {
            root.noteFailure("请求超时 " + path);
            finish(false);
        };
        request.send();
        return true;
    }

    function requestSnapshot() {
        root.requestJson("/now-playing", root.applySnapshot, null);
    }

    // Lyrics are not part of the snapshot and are fetched once per track, with a
    // bounded number of retries while the player still reports them as unavailable
    // 歌词不在快照内，每首曲目单独获取一次；播放器仍报告不可用时进行次数有限的重试
    function requestLyrics() {
        if (!SPlayerNext.shouldRequestLyrics({
                "trackKey": root.trackKey,
                "appliedKey": root.lyricsTrackKey,
                "requestKey": root.lyricsRequestKey,
                "retries": root.lyricsRetries,
                "limit": root.lyricsRetryLimit
            })) {
            return;
        }

        const key = root.trackKey;
        root.lyricsRequestKey = key;
        root.requestJson("/lyrics", function(payload) {
            root.applyLyricPayload(key, payload);
        }, function() {
            root.applyLyricPayload(key, null);
        });
    }

    function applySnapshot(snapshot) {
        if (snapshot === null || typeof snapshot !== "object") {
            return;
        }
        root.applyTrack(snapshot.track);
        // The player may finish loading lyrics after the first request, retry while they are missing
        // 播放器可能在首次请求后才加载完歌词，缺失时继续重试
        if (snapshot.lyricAvailable === true) {
            root.requestLyrics();
        }
        root.applyLyricOffset(snapshot.lyricOffsetMs);
        root.applyStatus(snapshot);
    }

    function applyLyricPayload(key, payload) {
        if (root.lyricsRequestKey === key) {
            root.lyricsRequestKey = "";
        }
        // A reply for another track is stale and must be dropped
        // 其他曲目的响应属于过期数据，必须丢弃
        if (key !== root.trackKey) {
            return;
        }
        // A failed read or an empty answer may mean the player has not finished loading
        // the lyrics yet, so release the track for a bounded retry
        // 读取失败或返回空内容可能只是播放器尚未加载完歌词，
        // 因此释放该曲目，以便进行次数有限的重试
        if (payload === null || typeof payload !== "object") {
            root.scheduleLyricsRetry();
            return;
        }
        if (typeof payload.trackId === "string" && payload.trackId.length > 0
                && payload.trackId !== root.trackId) {
            return;
        }
        if (!Array.isArray(payload.lyric) || payload.lyric.length === 0) {
            root.scheduleLyricsRetry();
            return;
        }
        root.applyLyricOffset(payload.lyricOffsetMs);
        root.applyLyricLines(payload.lyric);
    }

    function scheduleLyricsRetry() {
        if (root.trackKey.length === 0 || root.trackKey === root.lyricsTrackKey) {
            return;
        }
        if (root.lyricsRetries >= root.lyricsRetryLimit) {
            return;
        }

        root.lyricsRetries += 1;
        if (!root.lyricsRetryTimer.running) {
            root.lyricsRetryTimer.restart();
        }
    }

    function clearLyrics() {
        root.lyricsTrackKey = "";
        root.lyricsRequestKey = "";
        root.lyricsRetries = 0;
        root.lyricsRetryTimer.stop();
        root.abortRequest("/lyrics");
        if (root.lyrics !== null && typeof root.lyrics.clear === "function") {
            root.lyrics.clear("splayer");
        }
        root.lyricChanged();
    }

    // Anchor the estimate to a server position and its local arrival time
    // 将估算锚定到服务端位置及其本地到达时间
    function syncAnchor(milliseconds, force) {
        const value = Math.max(0, Number(milliseconds) || 0);
        if (!force && root.playing && Math.abs(value - root.position) < root.anchorTolerance) {
            return;
        }
        root.anchorPosition = root.duration > 0 ? Math.min(value, root.duration) : value;
        root.anchorWallMs = Date.now();
        root.setPosition(root.anchorPosition);
    }

    // Extrapolate from the anchor; the position timer never touches the API
    // 由锚点外推；位置定时器不访问接口
    function advancePosition() {
        if (!root.playing) {
            return;
        }
        const elapsed = (Date.now() - root.anchorWallMs) * root.playbackRate;
        const estimate = root.anchorPosition + elapsed;
        root.setPosition(root.duration > 0 ? Math.min(estimate, root.duration) : estimate);
    }

    function setPosition(milliseconds) {
        const value = Math.max(0, Number(milliseconds) || 0);
        if (root.position === value) {
            return;
        }
        root.position = value;
        root.progressChanged();
        root.syncLyrics();
    }

    function setDuration(milliseconds) {
        const value = Math.max(0, Number(milliseconds) || 0);
        if (root.duration === value) {
            return;
        }
        root.duration = value;
        if (root.lyrics !== null && typeof root.lyrics.syncDuration === "function") {
            root.lyrics.syncDuration(value);
        }
    }

    function syncLyrics() {
        if (root.lyrics !== null && typeof root.lyrics.syncPosition === "function") {
            root.lyrics.syncPosition(root.position);
        }
    }

    // Ask the player for a fresh position once, its reply arrives as a signal
    // 向播放器请求一次最新位置，结果以信号形式返回
    function refreshPlayerPosition() {
        const player = root.positionPlayer;
        if (player !== null && typeof player.updatePosition === "function") {
            player.updatePosition();
        }
    }

    // MPRIS reports microseconds, the lyric timeline works in milliseconds
    // MPRIS 使用微秒，歌词时间轴使用毫秒
    function applyPlayerPosition() {
        if (!root.mprisMatched) {
            return;
        }

        const microseconds = Number(root.positionPlayer.position);
        if (!isFinite(microseconds) || microseconds < 0) {
            return;
        }
        root.syncAnchor(microseconds / 1000);
    }

    // Report an HTTP read failure once per outage
    // HTTP 读取失败在每次故障中只报告一次
    function noteFailure(message) {
        root.lastError = message;
        if (!root.outageLogged) {
            root.outageLogged = true;
            console.info("[Sparkle Land] SPlayer-Next 状态读取失败：", message);
        }
    }

    function reportError(message) {
        const text = typeof message === "string" && message.length > 0 ? message : "未知错误";
        root.lastError = text;
        console.warn("[Sparkle Land] SPlayer-Next 错误：", text);
        root.errorOccurred(text);
    }
}
