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

    // SPlayer-Next shares one port between the socket and the HTTP API
    // SPlayer-Next 的套接字与 HTTP 接口共用同一端口
    property string url: "ws://127.0.0.1:14558/ws"
    property bool autoConnect: true
    property int reconnectInterval: 5000
    // High-frequency position events are not broadcast, polling keeps progress current
    // 高频进度事件不会广播，轮询保持播放位置更新
    property int pollInterval: 1000

    // Connection state
    // 连接状态
    property bool connected: false
    property int clientCount: 0
    property string lastError: ""
    // Keep one log line per outage instead of one per retry
    // 每次断线只记录一条日志，避免重试刷屏
    property bool outageLogged: false

    // Playback state mirrored from the SPlayer-Next events
    // 由 SPlayer-Next 事件同步的播放状态
    property bool playing: false
    property string playState: ""
    property string trackId: ""
    property string songTitle: ""
    property string artistName: ""
    property string albumName: ""
    property string coverUrl: ""
    property real position: 0
    property real duration: 0
    // Track whose lyrics were last requested, avoids duplicate fetches
    // 最近一次请求歌词的曲目，避免重复请求
    property string lyricsTrackId: ""

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

    readonly property Timer reconnectTimer: Timer {
        interval: root.reconnectInterval
        repeat: false

        onTriggered: root.connectSocket()
    }

    readonly property Timer pollTimer: Timer {
        interval: root.pollInterval
        repeat: true
        running: root.connected

        onTriggered: root.requestSnapshot()
    }

    Component.onCompleted: {
        if (root.autoConnect) {
            root.connectSocket();
        }
    }

    // Toggle active because a socket left active by a failed attempt will not reopen by itself
    // 切换 active，因为失败后仍为活动状态的套接字不会自行重连
    function connectSocket() {
        if (root.connected || root.socket.status === WebSocket.Connecting) {
            return;
        }
        root.reconnectTimer.stop();
        if (root.url.length === 0) {
            return;
        }

        root.autoConnect = true;
        root.socket.active = false;
        root.socket.active = true;
    }

    function disconnectSocket() {
        root.autoConnect = false;
        root.reconnectTimer.stop();
        root.socket.active = false;
    }

    function scheduleReconnect() {
        if (!root.autoConnect || root.reconnectTimer.running) {
            return;
        }
        root.reconnectTimer.start();
    }

    // Send a command message; returns false while disconnected
    // 发送命令消息；未连接时返回 false
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
        root.sendCommand("seek", { "positionMs": Math.max(0, Number(positionMs) || 0) });
    }

    function setVolume(volume) {
        root.sendCommand("setVolume", { "volume": Math.min(1, Math.max(0, Number(volume) || 0)) });
    }

    function handleStatus(status) {
        if (status === WebSocket.Open) {
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

        if (root.connected) {
            root.connected = false;
            console.info("[Sparkle Land] SPlayer-Next WebSocket 已断开");
            root.connectionChanged();
        }

        if (status === WebSocket.Error) {
            root.lastError = root.socket.errorString;
            if (!root.outageLogged) {
                root.outageLogged = true;
                console.info("[Sparkle Land] SPlayer-Next 服务不可用，稍后重试：", root.lastError);
            }
        }

        root.scheduleReconnect();
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
        if (typeof data.position === "number" && isFinite(data.position)) {
            root.setPosition(data.position);
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
                root.songTitle = "";
                root.artistName = "";
                root.albumName = "";
                root.coverUrl = "";
                root.setDuration(0);
                root.setPosition(0);
                root.clearLyrics();
                root.songChanged();
            }
            return;
        }

        const trackChanged = nextTrack.id !== root.trackId || nextTrack.title !== root.songTitle;
        root.trackId = nextTrack.id;
        root.songTitle = nextTrack.title;
        root.artistName = nextTrack.artist;
        root.albumName = nextTrack.album;
        root.coverUrl = nextTrack.cover;
        if (nextTrack.duration > 0) {
            root.setDuration(nextTrack.duration);
        }
        if (trackChanged) {
            root.setPosition(0);
            root.clearLyrics();
            root.requestLyrics();
        }
        root.songChanged();
    }

    function applyLyricLines(lines) {
        if (root.lyrics !== null && typeof root.lyrics.setLyrics === "function") {
            root.lyrics.setLyrics(lines);
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

    function requestJson(path, onSuccess) {
        const request = new XMLHttpRequest();
        request.open("GET", root.apiBaseUrl + path);
        request.onreadystatechange = function() {
            if (request.readyState !== XMLHttpRequest.DONE) {
                return;
            }
            if (request.status !== 200) {
                root.noteFailure("HTTP " + request.status + " " + path);
                return;
            }

            let payload = null;
            try {
                payload = JSON.parse(request.responseText);
            } catch (error) {
                root.noteFailure("无法解析 " + path + " 响应");
                return;
            }
            onSuccess(payload);
        };
        request.send();
    }

    function requestSnapshot() {
        root.requestJson("/now-playing", root.applySnapshot);
    }

    // Lyrics are not part of the snapshot and are fetched once per track
    // 歌词不在快照内，每首曲目单独获取一次
    function requestLyrics() {
        if (root.trackId.length === 0 || root.trackId === root.lyricsTrackId) {
            return;
        }
        root.lyricsTrackId = root.trackId;
        root.requestJson("/lyrics", root.applyLyricPayload);
    }

    function applySnapshot(snapshot) {
        if (snapshot === null || typeof snapshot !== "object") {
            return;
        }
        root.applyTrack(snapshot.track);
        root.applyLyricOffset(snapshot.lyricOffsetMs);
        root.applyStatus(snapshot);
    }

    function applyLyricPayload(payload) {
        if (payload === null || typeof payload !== "object") {
            return;
        }
        root.applyLyricOffset(payload.lyricOffsetMs);
        root.applyLyricLines(payload.lyric);
    }

    function clearLyrics() {
        root.lyricsTrackId = "";
        if (root.lyrics !== null && typeof root.lyrics.clear === "function") {
            root.lyrics.clear();
        }
        root.lyricChanged();
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
