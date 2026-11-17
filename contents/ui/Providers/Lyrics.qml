import QtQuick
import "Splayer.js" as Splayer

// Lyric state fed by the SPlayer backend: normalized lines and the active line
// 由 SPlayer 后端填充的歌词状态：规范化后的歌词行与当前行
QtObject {
    id: root

    // Normalized lines: { startTime, endTime, text, translation, roman, background, duet }
    // 规范化后的歌词行：{ startTime, endTime, text, translation, roman, background, duet }
    property var lines: []
    // Playback position in milliseconds
    // 播放位置，单位毫秒
    property real position: 0
    // Track duration in milliseconds
    // 曲目时长，单位毫秒
    property real duration: 0
    property int currentIndex: -1

    readonly property bool available: root.lines.length > 0
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
        return Math.max(0, Math.min(1, (root.position - root.currentLine.startTime) / span));
    }

    // Accept the parsed LyricLine array of SPlayer-Next
    // 接收 SPlayer-Next 的已解析歌词行数组
    function setLyrics(source) {
        root.lines = Splayer.normalizeLines(source);
        root.refreshIndex();
    }

    function clear() {
        root.lines = [];
        root.currentIndex = -1;
    }

    // The player reports the active line itself, including the lyric offset
    // 播放器直接上报当前行，其中已包含歌词偏移
    function syncLine(index, milliseconds) {
        const value = Math.max(0, Number(milliseconds) || 0);
        if (root.position !== value) {
            root.position = value;
        }

        const reported = Number(index);
        const next = isFinite(reported) && reported >= -1 && reported < root.lines.length
            ? Math.round(reported)
            : -1;
        if (next !== root.currentIndex) {
            root.currentIndex = next;
        }
    }

    // Position updates arrive with every progress event
    // 每次进度事件都会更新播放位置
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
        const index = Splayer.indexAt(root.lines, root.position);
        if (index !== root.currentIndex) {
            root.currentIndex = index;
        }
    }
}
