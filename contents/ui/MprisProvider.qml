import QtQuick
import org.kde.plasma.private.mpris as Mpris

// 提供 Plasma MPRIS 模型的曲目信息和播放控制。
QtObject {
    id: root

    // QtObject 没有默认子对象属性，模型需通过属性承载。
    readonly property var mpris2Model: Mpris.Mpris2Model {
    }

    readonly property string trackTitle: {
        const player = root.mpris2Model.currentPlayer;
        const track = player ? player.track : undefined;
        return typeof track === "string" ? track : "";
    }

    readonly property bool playing: {
        const player = root.mpris2Model.currentPlayer;
        return !!player && player.playbackStatus === Mpris.PlaybackStatus.Playing;
    }

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
