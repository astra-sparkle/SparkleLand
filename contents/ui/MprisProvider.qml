import QtQuick
import org.kde.plasma.private.mpris as Mpris

// 媒体实现候选 1：Plasma 私有 mpris 模块（本机已确认存在）。
//
// 这里刻意用**静态 import**，与本机可用的第三方插件 plasmusic-toolbar 完全同一套用法：
//   import org.kde.plasma.private.mpris as Mpris
//   model.currentPlayer.track
//   model.currentPlayer.playbackStatus === Mpris.PlaybackStatus.Playing
// 本机 kmpris.qmltypes 也确认了：Mpris2Model 有 currentPlayer；播放器有 track /
// playbackStatus；PlaybackStatus.Status 的取值含 Playing。
//
// 若该模块缺失，本文件会加载失败 —— main.qml 的候选机制会捕获并把真实原因打出来，
// 然后尝试下一个实现，所以这里可以放心使用静态 import。
QtObject {
    id: root

    // 用属性承载子对象，而不是裸的子对象声明：
    // 这在 QtObject 下一定成立，也是 plasmusic-toolbar 的写法。
    readonly property var mpris2Model: Mpris.Mpris2Model {
    }

    readonly property var player: root.mpris2Model.currentPlayer

    // 用 typeof 归一化：没有播放器时 track 可能是 undefined，避免 string 属性出现 "undefined"
    readonly property string trackTitle: {
        const player = root.mpris2Model.currentPlayer;
        const track = player ? player.track : undefined;
        return typeof track === "string" ? track : "";
    }

    readonly property bool playing: {
        const player = root.mpris2Model.currentPlayer;
        return !!player && player.playbackStatus === Mpris.PlaybackStatus.Playing;
    }

    // 专辑封面（展开面板的媒体控制器要用）
    readonly property string artUrl: {
        const player = root.mpris2Model.currentPlayer;
        const url = player ? player.artUrl : undefined;
        return (url === undefined || url === null) ? "" : String(url);
    }

    // ———— 媒体控制（PlayerContainer 的 Q_INVOKABLE 方法，名字首字母大写）————
    function next() {
        const player = root.mpris2Model.currentPlayer;
        if (player) {
            player.Next();
        }
    }

    function previous() {
        const player = root.mpris2Model.currentPlayer;
        if (player) {
            player.Previous();
        }
    }

    function togglePlaying() {
        const player = root.mpris2Model.currentPlayer;
        if (player) {
            player.PlayPause();
        }
    }
}
