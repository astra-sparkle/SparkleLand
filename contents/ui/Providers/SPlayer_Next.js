// SPlayer-Next helpers: WebSocket messages and parsed lyric lines
// SPlayer-Next 辅助函数：WebSocket 消息与已解析歌词行

// Message kinds the server may send
// 服务端可能下发的消息种类
const MESSAGE_KINDS = ["hello", "event", "ack", "error"];

// Trailing duration given to the last lyric line
// 最后一行歌词的默认持续时长
const LAST_LINE_DURATION = 8000;

// Commands carry the operation in "op", extra fields are merged next to it
// 命令以 "op" 标识操作，附加字段与之合并
function commandMessage(op, payload) {
    const message = { "op": op };
    if (payload !== null && typeof payload === "object") {
        const keys = Object.keys(payload);
        for (let index = 0; index < keys.length; ++index) {
            message[keys[index]] = payload[keys[index]];
        }
    }
    return JSON.stringify(message);
}

// Return null when the frame is not a server message
// 不是服务端消息时返回 null
function parseMessage(rawMessage) {
    if (typeof rawMessage !== "string" || rawMessage.length === 0) {
        return null;
    }

    let message = null;
    try {
        message = JSON.parse(rawMessage);
    } catch (error) {
        return null;
    }

    if (message === null || typeof message !== "object" || MESSAGE_KINDS.indexOf(message.kind) < 0) {
        return null;
    }
    // Event payloads are always objects, even when the server omits them
    // 事件载荷始终为对象，即使服务端省略该字段
    if (message.kind === "event" && (message.data === undefined || message.data === null
            || typeof message.data !== "object")) {
        message.data = {};
    }
    return message;
}

// Return null when the payload carries no track
// 载荷中没有曲目时返回 null
function trackState(track) {
    if (track === null || typeof track !== "object") {
        return null;
    }

    const artists = [];
    if (Array.isArray(track.artists)) {
        for (let index = 0; index < track.artists.length; ++index) {
            const artist = track.artists[index];
            if (artist !== null && typeof artist === "object" && typeof artist.name === "string") {
                artists.push(artist.name);
            }
        }
    }

    const album = track.album !== null && typeof track.album === "object" ? track.album : {};
    return {
        "id": typeof track.id === "string" ? track.id : "",
        "title": typeof track.title === "string" ? track.title : "",
        "artist": artists.join(" / "),
        "album": typeof album.name === "string" ? album.name : "",
        "cover": typeof track.cover === "string"
            ? track.cover
            : (typeof album.cover === "string" ? album.cover : ""),
        "duration": Math.max(0, Number(track.duration) || 0)
    };
}

function optionalText(value) {
    return typeof value === "string" ? value.trim() : "";
}

function lineText(line) {
    if (line === null || typeof line !== "object" || !Array.isArray(line.words)) {
        return "";
    }

    let text = "";
    for (let index = 0; index < line.words.length; ++index) {
        const word = line.words[index];
        if (word !== null && typeof word === "object" && typeof word.word === "string") {
            text += word.word;
        }
    }
    return text;
}

// Convert the parsed lyric lines into the flat form used by the view
// 将已解析歌词行转换为视图使用的扁平结构
function normalizeLines(source) {
    if (!Array.isArray(source)) {
        return [];
    }

    const lines = [];
    for (let index = 0; index < source.length; ++index) {
        const line = source[index];
        if (line === null || typeof line !== "object") {
            continue;
        }

        const text = lineText(line).trim();
        const translation = optionalText(line.translatedLyric);
        const roman = optionalText(line.romanLyric);
        if (text.length === 0 && translation.length === 0 && roman.length === 0) {
            continue;
        }

        const startTime = Math.max(0, Math.round(Number(line.startTime) || 0));
        const endTime = Math.max(0, Math.round(Number(line.endTime) || 0));
        lines.push({
            "startTime": startTime,
            "endTime": endTime > startTime ? endTime : 0,
            "text": text,
            "translation": translation,
            "roman": roman,
            "background": line.isBG === true,
            "duet": line.isDuet === true
        });
    }

    lines.sort(function(left, right) {
        return left.startTime - right.startTime;
    });

    // Fill missing or inverted end times from the next line
    // 用下一行补齐缺失或颠倒的结束时间
    for (let index = 0; index < lines.length; ++index) {
        const line = lines[index];
        if (line.endTime > line.startTime) {
            continue;
        }
        line.endTime = index + 1 < lines.length
            ? Math.max(line.startTime, lines[index + 1].startTime)
            : line.startTime + LAST_LINE_DURATION;
    }

    return lines;
}

// Binary search for the last line starting at or before the position
// 二分查找起点不晚于当前位置的最后一行
function indexAt(lines, positionMs) {
    if (!Array.isArray(lines) || lines.length === 0) {
        return -1;
    }
    if (positionMs < lines[0].startTime) {
        return -1;
    }

    let low = 0;
    let high = lines.length - 1;
    let found = -1;
    while (low <= high) {
        const middle = (low + high) >> 1;
        if (lines[middle].startTime <= positionMs) {
            found = middle;
            low = middle + 1;
        } else {
            high = middle - 1;
        }
    }
    return found;
}
