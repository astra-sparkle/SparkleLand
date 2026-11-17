import QtQuick
import "SPlayer_Next.js" as SPlayerNext

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
    // Lyric offset in milliseconds, positive values show lyrics earlier
    // 歌词偏移，单位为毫秒，正值使歌词提前
    property real offset: 0
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
        return Math.max(0, Math.min(1, (root.position + root.offset - root.currentLine.startTime) / span));
    }

    // Store an already normalized line array, the backend owns parsing and caching
    // 写入已规范化的歌词行数组，解析与缓存由后端负责
    function setLines(source) {
        root.lines = Array.isArray(source) ? source : [];
        root.refreshIndex();
    }

    function clear() {
        root.lines = [];
        root.offset = 0;
        root.currentIndex = -1;
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
