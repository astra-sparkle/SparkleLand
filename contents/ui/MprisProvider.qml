import QtQuick
import org.kde.plasma.private.mpris as Mpris

// 使用 Plasma 私有 MPRIS 模块提供曲目信息、封面和播放控制。
QtObject {
    id: root

    readonly property var mpris2Model: Mpris.Mpris2Model {
    }

    // 无播放器或曲名无效时返回空字符串。
    readonly property string trackTitle: {
        const player = root.mpris2Model.currentPlayer;
        const track = player ? player.track : undefined;
        return typeof track === "string" ? track : "";
    }

    readonly property bool playing: {
        const player = root.mpris2Model.currentPlayer;
        return !!player && player.playbackStatus === Mpris.PlaybackStatus.Playing;
    }

    // 展开面板使用的专辑封面。
    readonly property string artUrl: {
        const player = root.mpris2Model.currentPlayer;
        const url = player ? player.artUrl : undefined;
        return (url === undefined || url === null) ? "" : String(url);
    }

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
