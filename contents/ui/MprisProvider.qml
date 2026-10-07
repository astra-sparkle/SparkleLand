import QtQuick
import org.kde.plasma.private.mpris as Mpris



// MPRIS data provider for track title, artwork and playback actions.
// 提供曲目名称、专辑封面和播放控制的 MPRIS 数据源。
QtObject {
    id: root

    readonly property var mpris2Model: Mpris.Mpris2Model {
    }

    function currentPlayer() {
        return root.mpris2Model.currentPlayer;
    }

    // Return an empty string when no player or title is available.
    // 当没有播放器或曲目标题时返回空字符串。
    readonly property string trackTitle: {
        const player = root.currentPlayer();
        const track = player ? player.track : undefined;
        return typeof track === "string" ? track : "";
    }

    readonly property bool playing: {
        const player = root.currentPlayer();
        return !!player && player.playbackStatus === Mpris.PlaybackStatus.Playing;
    }

    // 展开面板使用的专辑封面。
    readonly property string artUrl: {
        const player = root.currentPlayer();
        const url = player ? player.artUrl : undefined;
        return (url === undefined || url === null) ? "" : String(url);
    }

    function next() {
        const player = root.currentPlayer();
        if (player) {
            player.Next();
        }
    }

    function previous() {
        const player = root.currentPlayer();
        if (player) {
            player.Previous();
        }
    }

    function togglePlaying() {
        const player = root.currentPlayer();
        if (player) {
            player.PlayPause();
        }
    }
}
