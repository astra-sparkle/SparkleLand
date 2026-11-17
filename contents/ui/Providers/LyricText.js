// Lyric text splitting: cuts a line into the part shown on its row and the part
// carried over to the next row
// 歌词文本切分：把一行歌词拆成当前行显示的部分与顺延到下一行的部分

// A row holds 30 half-width characters, that is 15 full-width characters
// 一行容纳 30 个半角字符，即 15 个全角字符
const HALF_WIDTH_LIMIT = 30;
const FULL_WIDTH_LIMIT = HALF_WIDTH_LIMIT / 2;

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

function isComma(character) {
    return character === "," || character === "，";
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

    // Prefer a space so the first row ends on a word boundary; the last space that
    // still fits wins
    // 优先在空格处断行，使首行结束于词边界；取仍能放下的最后一个空格
    let spaceCut = -1;
    let consumed = 0;
    for (let index = 0; index < characters.length; ++index) {
        if (characters[index] === " " && consumed > 0 && consumed <= HALF_WIDTH_LIMIT) {
            spaceCut = index;
        }
        consumed += units[index];
    }
    if (spaceCut > 0) {
        return cutAt(characters, spaceCut);
    }

    // A comma between one half and two thirds of the line marks a natural pause, so
    // the row ends right after it
    // 句长一半到三分之二之间存在逗号时，逗号是自然的停顿，首行止于该逗号之后
    const pauseStart = Math.floor(characters.length / 2);
    const pauseEnd = Math.round(characters.length * 2 / 3);
    let commaCut = -1;
    for (let index = pauseStart; index < pauseEnd && index < characters.length; ++index) {
        if (isComma(characters[index])) {
            commaCut = index + 1;
        }
    }
    if (commaCut > 0) {
        return cutAt(characters, Math.min(commaCut, limit));
    }

    // Without a usable space or comma, cut near two thirds of the sentence and fall
    // back to the row limit when that position is too far right
    // 没有可用的空格或逗号时，在整句约三分之二处切分；该位置过靠右时按行宽截断
    let target = Math.max(1, Math.round(characters.length * 2 / 3));
    if (target > limit) {
        target = limit;
    }
    return cutAt(characters, Math.max(1, target));
}
