import QtQuick
import "LyricText.js" as LyricText
import "SPlayer_Next.js" as SPlayerNext

// Lyric state fed by the active backend: normalized lines and the active line
// 由当前生效后端填充的歌词状态：规范化后的歌词行与当前行
QtObject {
    id: root

    // Normalized lines: { startTime, endTime, text, translation, roman, background, duet }
    // 规范化后的歌词行：{ startTime, endTime, text, translation, roman, background, duet }
    property var lines: []
    // Backend that produced the current lines, so the other backend cannot wipe them
    // 生成当前歌词行的后端；另一后端不得清空这些行
    property string owner: ""
    // Playback position in milliseconds
    // 播放位置，单位毫秒
    property real position: 0
    // Track duration in milliseconds
    // 曲目时长，单位毫秒
    property real duration: 0
    // Lyric offset in milliseconds, positive values show lyrics earlier
    // 歌词偏移，单位为毫秒，正值使歌词提前
    property real offset: 0
    property int currentIndex: -1

    // Full-width characters a single lyric row can hold, shared with the view
    // 单个歌词行可容纳的全角字符数，与视图共用
    readonly property int lineUnitLimit: LyricText.FULL_WIDTH_LIMIT
    readonly property bool available: root.lines.length > 0
    // Nothing has been sung yet: the position is still before the first line
    // 尚未唱到任何歌词：位置仍在首行之前
    readonly property bool beforeFirstLine: root.available && root.currentIndex < 0
    readonly property var currentLine: root.currentIndex >= 0 && root.currentIndex < root.lines.length
        ? root.lines[root.currentIndex]
        : null
    readonly property string currentText: root.currentLine !== null ? root.currentLine.text : ""
    readonly property string currentTranslation: root.currentLine !== null ? root.currentLine.translation : ""
    readonly property string currentRoman: root.currentLine !== null ? root.currentLine.roman : ""
    readonly property string nextText: root.currentIndex + 1 < root.lines.length
        ? root.lines[root.currentIndex + 1].text
        : ""
    // Progress inside the active line, used for karaoke style highlighting
    // 当前行内部的进度，用于卡拉 OK 式高亮
    readonly property real lineProgress: {
        if (root.currentLine === null) {
            return 0;
        }
        const span = root.currentLine.endTime - root.currentLine.startTime;
        if (span <= 0) {
            return 0;
        }
        return Math.max(0, Math.min(1, (root.position + root.offset - root.currentLine.startTime) / span));
    }

    // Split a lyric line into the part kept on its row and the overflow
    // 把一行歌词拆成留在本行的部分与溢出部分
    function splitLine(text) {
        return LyricText.splitLine(text);
    }

    // Store an already normalized line array, the backend owns parsing and caching
    // 写入已规范化的歌词行数组，解析与缓存由后端负责
    function setLines(source, sourceName) {
        root.owner = typeof sourceName === "string" ? sourceName : "";
        root.lines = Array.isArray(source) ? source : [];
        root.refreshIndex();
    }

    // A named call only clears the lines that backend produced itself
    // 指定名称时只清除该后端自己写入的歌词
    function clear(sourceName) {
        const name = typeof sourceName === "string" ? sourceName : "";
        if (name.length > 0 && root.owner.length > 0 && name !== root.owner) {
            return;
        }

        root.lines = [];
        root.offset = 0;
        root.currentIndex = -1;
        root.owner = "";
    }

    function syncOffset(milliseconds) {
        const value = Math.round(Number(milliseconds) || 0);
        if (root.offset === value) {
            return;
        }
        root.offset = value;
        root.refreshIndex();
    }

    // Position updates arrive with the snapshot poll
    // 位置由快照轮询更新
    function syncPosition(milliseconds) {
        const value = Math.max(0, Number(milliseconds) || 0);
        if (root.position === value) {
            return;
        }
        root.position = value;
        root.refreshIndex();
    }

    function syncDuration(milliseconds) {
        root.duration = Math.max(0, Number(milliseconds) || 0);
    }

    function refreshIndex() {
        const index = SPlayerNext.indexAt(root.lines, root.position + root.offset);
        if (index !== root.currentIndex) {
            root.currentIndex = index;
        }
    }
}
