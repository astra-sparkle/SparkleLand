// AMLL lyric helpers: request limiting, TTML parsing and local line caching
// AMLL 歌词辅助函数：请求限流、TTML 解析与本地歌词行缓存

// Official AMLL TTML database base address
// AMLL TTML 官方数据库基础地址
const API_BASE_URL = "https://api.amll.dev";

// The service allows an average of 50 requests per second per address; a 429 reply
// means that budget is already spent, so this client drops to 30 requests per second
// for the rest of the session
// 服务端按地址平均每秒允许 50 次请求；收到 429 表示该预算已耗尽，
// 客户端在本次会话余下时间降至每秒 30 次
const REQUEST_LIMIT = 50;
const THROTTLED_REQUEST_LIMIT = 30;
const RATE_WINDOW_MS = 1000;

// Local lyric cache size, in tracks
// 本地歌词缓存可容纳的曲目数
const LINE_CACHE_LIMIT = 30;

// Trailing duration given to the last lyric line
// 最后一行歌词的默认持续时长
const LAST_LINE_DURATION = 8000;

// A handful of candidates is enough to pick the closest match
// 少量候选即可选出最接近的匹配
const SEARCH_PAGE_SIZE = 5;

function positiveInteger(value, fallback) {
    const number = Math.round(Number(value));
    return isFinite(number) && number > 0 ? number : fallback;
}

// Defaults are read through a function because QML exposes functions of an imported
// script reliably, unlike top-level lexical declarations
// 默认值通过函数读取：QML 对导入脚本只可靠地暴露函数，而不保证暴露顶层词法声明
function defaults() {
    return {
        "apiBaseUrl": API_BASE_URL,
        "requestLimit": REQUEST_LIMIT,
        "throttledRequestLimit": THROTTLED_REQUEST_LIMIT,
        "cacheLimit": LINE_CACHE_LIMIT,
        "searchPageSize": SEARCH_PAGE_SIZE
    };
}

// Collapse the whitespace spanning word boundaries
// 合并词与词之间的空白
function normalizeText(value) {
    if (typeof value !== "string") {
        return "";
    }
    return value.replace(/\s+/g, " ").trim();
}

function normalizeForMatch(value) {
    return normalizeText(value).toLowerCase();
}

function decodeEntities(value) {
    return String(value)
        .replace(/&lt;/g, "<")
        .replace(/&gt;/g, ">")
        .replace(/&quot;/g, "\"")
        .replace(/&apos;/g, "'")
        .replace(/&#(\d+);/g, function(match, code) {
            return String.fromCharCode(Number(code));
        })
        .replace(/&#x([0-9a-f]+);/gi, function(match, code) {
            return String.fromCharCode(parseInt(code, 16));
        })
        .replace(/&amp;/g, "&");
}

// TTML accepts clock times ("1:01.818") and offset times ("10.0s")
// TTML 支持时钟时间（"1:01.818"）与偏移时间（"10.0s"）
function parseTimestamp(value) {
    if (typeof value !== "string") {
        return 0;
    }

    const text = value.trim();
    if (text.length === 0) {
        return 0;
    }

    const offset = /^([0-9]+(?:\.[0-9]+)?)(ms|s|m|h)$/i.exec(text);
    if (offset !== null) {
        const amount = Number(offset[1]);
        const unit = offset[2].toLowerCase();
        const factor = unit === "ms" ? 1 : (unit === "s" ? 1000 : (unit === "m" ? 60000 : 3600000));
        return isFinite(amount) ? Math.max(0, Math.round(amount * factor)) : 0;
    }

    const parts = text.split(":");
    if (parts.length === 0 || parts.length > 3) {
        return 0;
    }

    let seconds = 0;
    for (let index = 0; index < parts.length; ++index) {
        const amount = Number(parts[index]);
        if (!isFinite(amount)) {
            return 0;
        }
        seconds = seconds * 60 + amount;
    }
    return Math.max(0, Math.round(seconds * 1000));
}

function attributeMap(source) {
    const attributes = {};
    const pattern = /([\w:-]+)\s*=\s*"([^"]*)"|([\w:-]+)\s*=\s*'([^']*)'/g;
    let match = pattern.exec(source);
    while (match !== null) {
        const name = (match[1] !== undefined ? match[1] : match[3]).toLowerCase();
        const value = match[1] !== undefined ? match[2] : match[4];
        attributes[name] = decodeEntities(value);
        match = pattern.exec(source);
    }
    return attributes;
}

function normalizeRole(value) {
    const role = typeof value === "string" ? value.trim().toLowerCase() : "";
    return role === "x-translation" || role === "x-roman" || role === "x-bg" ? role : "";
}

function appendCandidate(list, text, language) {
    const code = typeof language === "string" ? language : "";
    for (let index = 0; index < list.length; ++index) {
        if (list[index].language === code) {
            list[index].text += text;
            return;
        }
    }
    list.push({
        "language": code,
        "text": text
    });
}

// Auxiliary rows may carry one candidate per language; the first non-empty one wins
// 辅助歌词行可能包含多种语言，取第一条非空内容
function firstCandidateText(list) {
    for (let index = 0; index < list.length; ++index) {
        const text = normalizeText(list[index].text);
        if (text.length > 0) {
            return text;
        }
    }
    return "";
}

function pushLine(lines, begin, end, text, translation, roman, background, duet) {
    const body = normalizeText(text);
    const translated = normalizeText(translation);
    const romanized = normalizeText(roman);
    if (body.length === 0 && translated.length === 0 && romanized.length === 0) {
        return;
    }

    const startTime = parseTimestamp(begin);
    const endTime = parseTimestamp(end);
    lines.push({
        "startTime": startTime,
        "endTime": endTime > startTime ? endTime : 0,
        "text": body,
        "translation": translated,
        "roman": romanized,
        "background": background,
        "duet": duet
    });
}

function createLine(attributes) {
    return {
        "begin": attributes.begin !== undefined ? attributes.begin : "",
        "end": attributes.end !== undefined ? attributes.end : "",
        "agent": attributes["ttm:agent"] !== undefined ? attributes["ttm:agent"] : "",
        "role": normalizeRole(attributes["ttm:role"] !== undefined ? attributes["ttm:role"] : attributes.role),
        "text": "",
        "translations": [],
        "romans": [],
        "background": {
            "begin": "",
            "end": "",
            "text": "",
            "translations": [],
            "romans": []
        }
    };
}

function pushCurrentLine(lines, line) {
    if (line === null) {
        return;
    }

    const duet = line.agent.length > 0 && line.agent !== "v1";
    pushLine(lines, line.begin, line.end, line.text,
        firstCandidateText(line.translations), firstCandidateText(line.romans),
        line.role === "x-bg", duet);

    // Background vocals share the line timing unless their span carries its own
    // 背景和声默认沿用整行时间，其 span 自带时间时以 span 为准
    const backgroundText = normalizeText(line.background.text);
    if (backgroundText.length > 0) {
        pushLine(lines,
            line.background.begin.length > 0 ? line.background.begin : line.begin,
            line.background.end.length > 0 ? line.background.end : line.end,
            line.background.text,
            firstCandidateText(line.background.translations),
            firstCandidateText(line.background.romans),
            true, duet);
    }
}

function finishLines(lines) {
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

// Parse AMLL TTML into the flat line model shared with the player backends.
// Only line level data is needed, so the nested word spans are flattened.
// 将 AMLL TTML 解析为与播放器后端共用的扁平行模型。
// 视图只需要行级数据，因此逐词 span 会被展平。
function parseTtml(source) {
    if (typeof source !== "string" || source.length === 0) {
        return [];
    }

    let xml = source.replace(/<!--[\s\S]*?-->/g, "")
        .replace(/<\?[\s\S]*?\?>/g, "")
        .replace(/<!DOCTYPE[^>]*>/gi, "");
    xml = xml.replace(/<!\[CDATA\[([\s\S]*?)\]\]>/g, function(match, text) {
        return text.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;");
    });

    const tokens = xml.match(/<[^>]*>|[^<]+/g) || [];
    const lines = [];
    let current = null;
    let spans = [];

    // Word spans carry no role, so the closest role-bearing ancestor decides the target
    // 逐词 span 没有 role，由最近带 role 的祖先决定内容归属
    function effectiveSpan() {
        for (let index = spans.length - 1; index >= 0; --index) {
            if (spans[index].role.length > 0) {
                return spans[index];
            }
        }
        return null;
    }

    function insideBackground() {
        for (let index = 0; index < spans.length; ++index) {
            if (spans[index].role === "x-bg") {
                return true;
            }
        }
        return false;
    }

    function appendText(text) {
        if (current === null || text.length === 0) {
            return;
        }

        const span = effectiveSpan();
        const role = span !== null ? span.role : "";
        const background = insideBackground();
        if (role === "x-translation") {
            appendCandidate(background ? current.background.translations : current.translations,
                text, span.language);
        } else if (role === "x-roman") {
            appendCandidate(background ? current.background.romans : current.romans,
                text, span.language);
        } else if (role === "x-bg" || background) {
            current.background.text += text;
        } else {
            current.text += text;
        }
    }

    for (let index = 0; index < tokens.length; ++index) {
        const token = tokens[index];
        if (token.charAt(0) !== "<") {
            appendText(decodeEntities(token));
            continue;
        }

        if (/^<\s*\//.test(token)) {
            const close = /^<\s*\/\s*([\w:-]+)/.exec(token);
            if (close === null) {
                continue;
            }
            const name = close[1].toLowerCase();
            if (name === "span") {
                if (spans.length > 0) {
                    spans.pop();
                }
            } else if (name === "p") {
                pushCurrentLine(lines, current);
                current = null;
                spans = [];
            }
            continue;
        }

        const open = /^<\s*([\w:-]+)/.exec(token);
        if (open === null) {
            continue;
        }

        const name = open[1].toLowerCase();
        if (name === "br") {
            if (current !== null) {
                current.text += "\n";
            }
            continue;
        }
        if (name === "p") {
            current = createLine(attributeMap(token));
            spans = [];
            continue;
        }
        if (name === "span") {
            if (current === null || /\/\s*>$/.test(token)) {
                continue;
            }
            const attributes = attributeMap(token);
            const role = normalizeRole(attributes["ttm:role"] !== undefined
                ? attributes["ttm:role"]
                : attributes.role);
            spans.push({
                "role": role,
                "language": attributes["xml:lang"] !== undefined ? attributes["xml:lang"] : ""
            });
            if (role === "x-bg" && current.background.begin.length === 0
                    && attributes.begin !== undefined) {
                current.background.begin = attributes.begin;
                current.background.end = attributes.end !== undefined ? attributes.end : "";
            }
        }
    }

    return finishLines(lines);
}

// Split combined MPRIS artists so the query only carries the leading name
// 拆分 MPRIS 的合并艺术家，使查询只带上首位艺术家
function firstArtist(value) {
    const text = typeof value === "string" ? value : "";
    const parts = text.split(/[,/]/);
    for (let index = 0; index < parts.length; ++index) {
        const name = normalizeText(parts[index]);
        if (name.length > 0) {
            return name;
        }
    }
    return "";
}

// Stable cache key: the same title from different albums or artists stays apart
// 稳定的缓存键：不同专辑或艺术家的同名曲目不会混淆
function trackKey(track) {
    if (track === null || typeof track !== "object") {
        return "";
    }
    const title = normalizeForMatch(track.title);
    if (title.length === 0) {
        return "";
    }
    return title + "\u0001" + normalizeForMatch(track.artist) + "\u0001" + normalizeForMatch(track.album);
}

function apiBase(value) {
    if (typeof value !== "string" || value.length === 0) {
        return API_BASE_URL;
    }
    return value.replace(/\/+$/, "");
}

function searchUrl(baseUrl, track, pageSize) {
    const parameters = [];
    const title = normalizeText(track.title);
    const artist = firstArtist(track.artist);
    const album = normalizeText(track.album);
    if (title.length > 0) {
        parameters.push("musicName=" + encodeURIComponent(title));
    }
    if (artist.length > 0) {
        parameters.push("artistName=" + encodeURIComponent(artist));
    }
    if (album.length > 0) {
        parameters.push("albumName=" + encodeURIComponent(album));
    }
    const size = Math.max(1, Math.min(100, Math.round(Number(pageSize) || SEARCH_PAGE_SIZE)));
    parameters.push("pageSize=" + size);
    return apiBase(baseUrl) + "/v1/lyrics/search?" + parameters.join("&");
}

function lyricUrl(baseUrl, id) {
    return apiBase(baseUrl) + "/v1/lyrics/get?id=" + encodeURIComponent(String(id));
}

function hasExact(values, needle) {
    for (let index = 0; index < values.length; ++index) {
        if (normalizeForMatch(values[index]) === needle) {
            return true;
        }
    }
    return false;
}

function hasContaining(values, needle) {
    for (let index = 0; index < values.length; ++index) {
        if (normalizeForMatch(values[index]).indexOf(needle) >= 0) {
            return true;
        }
    }
    return false;
}

// True when one of the candidate titles is a non-empty part of the track title,
// as happens with single edits that append a suffix
// 当某个候选曲名是曲目标题的非空子串时返回 true，
// 单曲版本常见这种附加后缀的情况
function containedIn(values, needle) {
    for (let index = 0; index < values.length; ++index) {
        const candidate = normalizeForMatch(values[index]);
        if (candidate.length > 0 && needle.indexOf(candidate) >= 0) {
            return true;
        }
    }
    return false;
}

// Pick the closest candidate; items without a usable title match are ignored
// 选出最接近的候选；标题不匹配的条目会被忽略
function selectBestItem(items, track) {
    if (!Array.isArray(items) || items.length === 0) {
        return null;
    }

    const title = normalizeForMatch(track.title);
    const artist = normalizeForMatch(firstArtist(track.artist));
    const album = normalizeForMatch(track.album);
    if (title.length === 0) {
        return null;
    }

    let best = null;
    let bestScore = 0;
    for (let index = 0; index < items.length; ++index) {
        const item = items[index];
        if (item === null || typeof item !== "object") {
            continue;
        }

        const names = Array.isArray(item.musicNames) ? item.musicNames : [];
        const artists = Array.isArray(item.artistNames) ? item.artistNames : [];
        const albums = Array.isArray(item.albumNames) ? item.albumNames : [];
        let score = 0;
        if (hasExact(names, title)) {
            score += 100;
        } else if (hasContaining(names, title)) {
            score += 60;
        } else if (containedIn(names, title)) {
            score += 40;
        } else {
            continue;
        }

        if (artist.length > 0 && hasContaining(artists, artist)) {
            score += 20;
        }
        if (album.length > 0 && hasContaining(albums, album)) {
            score += 10;
        }

        if (score > bestScore) {
            bestScore = score;
            best = item;
        }
    }

    return best;
}

// Bounded LRU cache of normalized lyric lines, keyed by track
// 按曲目缓存已规范化歌词行的有界 LRU
function createLineCache(limit) {
    const capacity = positiveInteger(limit, LINE_CACHE_LIMIT);
    const entries = {};
    let keys = [];

    function promote(key) {
        const index = keys.indexOf(key);
        if (index >= 0) {
            keys.splice(index, 1);
        }
        keys.unshift(key);
    }

    return {
        "get": function(key) {
            if (typeof key !== "string" || key.length === 0
                    || !Object.prototype.hasOwnProperty.call(entries, key)) {
                return null;
            }
            promote(key);
            return entries[key];
        },
        "put": function(key, lines) {
            if (typeof key !== "string" || key.length === 0 || !Array.isArray(lines)) {
                return;
            }
            entries[key] = lines;
            promote(key);
            while (keys.length > capacity) {
                delete entries[keys.pop()];
            }
        },
        "clear": function() {
            keys = [];
            for (const key in entries) {
                delete entries[key];
            }
        },
        "size": function() {
            return keys.length;
        }
    };
}

// Sliding window limiter: at most `limit` requests inside any one second window.
// A 429 reply lowers the window budget to `reducedLimit` for the rest of the session.
// 滑动窗口限流：任意一秒内最多 `limit` 次请求。
// 收到 429 后，本次会话余下时间的窗口预算降为 `reducedLimit`。
function createRateLimiter(limit, reducedLimit) {
    const initial = positiveInteger(limit, REQUEST_LIMIT);
    const reduced = Math.min(initial, positiveInteger(reducedLimit, THROTTLED_REQUEST_LIMIT));
    let active = initial;
    let sends = [];

    function prune(now) {
        while (sends.length > 0 && now - sends[0] >= RATE_WINDOW_MS) {
            sends.shift();
        }
    }

    return {
        "limit": function() {
            return active;
        },
        "throttled": function() {
            return active < initial;
        },
        // Milliseconds to wait before the next request may start; 0 when a slot is free
        // 下一次请求还需等待的毫秒数；有空闲名额时为 0
        "delay": function(now) {
            const at = Number(now);
            if (!isFinite(at)) {
                return 0;
            }
            prune(at);
            if (sends.length < active) {
                return 0;
            }
            return Math.max(0, RATE_WINDOW_MS - (at - sends[0]));
        },
        "record": function(now) {
            const at = Number(now);
            const stamp = isFinite(at) ? at : Date.now();
            sends.push(stamp);
            prune(stamp);
        },
        "noteStatus": function(status) {
            if (Number(status) === 429) {
                active = reduced;
            }
        }
    };
}
