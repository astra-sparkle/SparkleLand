import QtQuick
import org.kde.plasma.private.mpris as Mpris

QtObject {
    id: root

    readonly property Mpris.Mpris2Model mpris2Model: Mpris.Mpris2Model {}
    readonly property var currentPlayer: root.mpris2Model.currentPlayer

    // Return an empty string when no player or title is available
    // 没有播放器或曲目标题时返回空字符串
    readonly property string trackTitle: {
        const player = root.currentPlayer;
        const track = player ? player.track : undefined;
        return typeof track === "string" ? track : "";
    }

    // MPRIS reports every credited artist in one string; the online lyric backend
    // narrows it down to the leading name when it queries the database
    // MPRIS 将全部艺术家合并为一个字符串；在线歌词后端查询数据库时会取首位艺术家
    readonly property string artistName: {
        const player = root.currentPlayer;
        const artist = player ? player.artist : undefined;
        return typeof artist === "string" ? artist : "";
    }

    readonly property string albumName: {
        const player = root.currentPlayer;
        const album = player ? player.album : undefined;
        return typeof album === "string" ? album : "";
    }

    readonly property bool playing: {
        const player = root.currentPlayer;
        return !!player && player.playbackStatus === Mpris.PlaybackStatus.Playing;
    }

    // Album artwork shared by the compact cover and the expanded panel
    // 紧凑封面与展开面板共用的专辑封面
    readonly property string artUrl: {
        const player = root.currentPlayer;
        const url = player ? player.artUrl : undefined;
        return (url === undefined || url === null) ? "" : String(url);
    }

    // MPRIS identity of the current player; the SPlayer-Next socket is only contacted
    // while this app reports playback
    // 当前播放器的 MPRIS 标识；仅当该应用报告播放时才连接 SPlayer-Next 套接字
    readonly property string identity: {
        const player = root.currentPlayer;
        const value = player ? player.identity : undefined;
        return typeof value === "string" ? value : "";
    }

    // SPlayer-Next is the only player backend this applet reads lyrics from; other
    // players fall back to the online lyric backend
    // SPlayer-Next 是本小组件唯一读取自带歌词的播放器后端；其他播放器使用在线歌词后端回退
    readonly property bool isSplayerNext: root.identity.toLowerCase().indexOf("splayer") >= 0

    function next() {
        const player = root.currentPlayer;
        if (player) {
            player.Next();
        }
    }

    function previous() {
        const player = root.currentPlayer;
        if (player) {
            player.Previous();
        }
    }

    function togglePlaying() {
        const player = root.currentPlayer;
        if (player) {
            player.PlayPause();
        }
    }
}
