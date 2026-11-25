// Lyric text splitting: cuts a line into the part shown on its row and the part
// carried over to the next row
// 歌词文本切分：把一行歌词拆成当前行显示的部分与顺延到下一行的部分

// A row holds 31 half-width units: 15 full-width labels doubled, then bumped from
// even to odd so a wide separator can still end the row
// 一行容纳 31 个半角单位：原先 15 个全角字符的两倍，再由偶数补一变为奇数，
// 使全角分隔符也能留在行尾
const HALF_WIDTH_LIMIT = 31;
// Full-width labels the layout reserves for one row, rounded up from the budget
// 布局为一行预留的全角字符数，由半角预算向上取整
const FULL_WIDTH_LIMIT = Math.ceil(HALF_WIDTH_LIMIT / 2);

// East Asian wide and full-width ranges, measured in half-width units
// 东亚宽字符与全角字符区间，以半角字符为单位度量
function isWide(codePoint) {
    return (codePoint >= 0x1100 && codePoint <= 0x115F)
        || (codePoint >= 0x2E80 && codePoint <= 0x303E)
        || (codePoint >= 0x3041 && codePoint <= 0x33FF)
        || (codePoint >= 0x3400 && codePoint <= 0x4DBF)
        || (codePoint >= 0x4E00 && codePoint <= 0x9FFF)
        || (codePoint >= 0xA000 && codePoint <= 0xA4CF)
        || (codePoint >= 0xA960 && codePoint <= 0xA97F)
        || (codePoint >= 0xAC00 && codePoint <= 0xD7A3)
        || (codePoint >= 0xF900 && codePoint <= 0xFAFF)
        || (codePoint >= 0xFE10 && codePoint <= 0xFE19)
        || (codePoint >= 0xFE30 && codePoint <= 0xFE6F)
        || (codePoint >= 0xFF00 && codePoint <= 0xFF60)
        || (codePoint >= 0xFFE0 && codePoint <= 0xFFE6)
        || (codePoint >= 0x1B000 && codePoint <= 0x1B001)
        || (codePoint >= 0x1F200 && codePoint <= 0x1F251)
        || (codePoint >= 0x20000 && codePoint <= 0x3FFFD);
}

// Full-width characters take two units, everything else takes one
// 全角字符计两个单位，其余字符计一个单位
function charUnits(character) {
    return isWide(character.codePointAt(0)) ? 2 : 1;
}

function textUnits(value) {
    if (typeof value !== "string" || value.length === 0) {
        return 0;
    }

    const characters = Array.from(value);
    let total = 0;
    for (let index = 0; index < characters.length; ++index) {
        total += charUnits(characters[index]);
    }
    return total;
}

// Split at a character index and drop the whitespace the cut leaves behind
// 在指定字符位置切分，并去掉切分处残留的空白
function cutAt(characters, index) {
    const head = characters.slice(0, index).join("").replace(/\s+$/, "");
    const tail = characters.slice(index).join("").replace(/^\s+/, "");
    return {
        "head": head,
        "tail": tail
    };
}

// Largest cut index that still fits the row
// 仍能放进该行的最大切分位置
function limitIndex(characters, units) {
    let total = 0;
    let index = 0;
    while (index < characters.length) {
        if (total + units[index] > HALF_WIDTH_LIMIT) {
            break;
        }
        total += units[index];
        ++index;
    }
    return index;
}

// Split entries: the comma and the period are listed separately, and both carry a
// heavier weight than a plain word space. Punctuation also keeps its mark on the row,
// while a space is left for the next row
// 切分条目：逗号与句号各自列出，权重都高于普通空格；标点保留在本行，空格则留给下一行
const SPLIT_ENTRIES = [
    {
        "characters": [ "。", "." ],
        "weight": 3,
        "include": true
    },
    {
        "characters": [ "，", "," ],
        "weight": 2,
        "include": true
    },
    {
        "characters": [ " " ],
        "weight": 1,
        "include": false
    }
];

function splitEntry(character) {
    for (let index = 0; index < SPLIT_ENTRIES.length; ++index) {
        if (SPLIT_ENTRIES[index].characters.indexOf(character) >= 0) {
            return SPLIT_ENTRIES[index];
        }
    }
    return null;
}

// Best break that fits the row: the heaviest entry wins, and equal weights keep the
// candidate closest to the row limit
// 能放进本行的最佳切分：权重最高的条目优先，同权重时取最靠近行宽上限的位置
function bestSplitCut(characters, units) {
    let bestCut = -1;
    let bestWeight = 0;
    let width = 0;
    for (let index = 0; index < characters.length; ++index) {
        const entry = splitEntry(characters[index]);
        if (entry !== null && width > 0) {
            // Punctuation may use the one extra unit the layout reserves for it
            // 标点可以使用布局额外预留的一个单位
            const capacity = HALF_WIDTH_LIMIT + (entry.include ? 1 : 0);
            const markUnits = entry.include ? units[index] : 0;
            const cut = index + (entry.include ? 1 : 0);
            if (cut < characters.length && width + markUnits <= capacity
                && (entry.weight > bestWeight
                    || (entry.weight === bestWeight && cut > bestCut))) {
                bestCut = cut;
                bestWeight = entry.weight;
            }
        }
        width += units[index];
    }
    return bestCut;
}

// Split a lyric line into the part kept on its row and the overflow
// 把一行歌词拆成留在本行的部分与溢出部分
function splitLine(value) {
    const text = typeof value === "string" ? value : "";
    const characters = Array.from(text);
    if (characters.length === 0) {
        return {
            "head": "",
            "tail": ""
        };
    }

    const units = [];
    let total = 0;
    for (let index = 0; index < characters.length; ++index) {
        units.push(charUnits(characters[index]));
        total += units[index];
    }

    if (total <= HALF_WIDTH_LIMIT) {
        return {
            "head": text,
            "tail": ""
        };
    }

    const limit = limitIndex(characters, units);

    const splitCut = bestSplitCut(characters, units);
    if (splitCut > 0) {
        return cutAt(characters, splitCut);
    }

    // Without a usable space or punctuation, cut near two thirds of the sentence and
    // fall back to the row limit when that position is too far right
    // 没有可用的空格或标点时，在整句约三分之二处切分；该位置过靠右时按行宽截断
    let target = Math.max(1, Math.round(characters.length * 2 / 3));
    if (target > limit) {
        target = limit;
    }
    return cutAt(characters, Math.max(1, target));
}
