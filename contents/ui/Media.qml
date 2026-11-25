import QtQuick

Item {
    id: root

    property var theme
    property font titleFont
    property bool playing: false
    property bool useThemeBackground: true
    property string title: ""
    // Horizontal inset of the title text; the lyric frame uses its own padding
    // 曲名文字的左右内边距；歌词框内使用其自身的内边距
    property real horizontalPadding: 12

    // Use accent text only when media is playing and the theme background is enabled
    // 仅在播放且启用主题背景时使用强调色文字
    readonly property bool highlighted: root.playing && root.useThemeBackground

    implicitHeight: 32
    implicitWidth: titleLabel.implicitWidth + root.horizontalPadding * 2

    Text {
        id: titleLabel

        anchors.fill: parent
        anchors.leftMargin: root.horizontalPadding
        anchors.rightMargin: root.horizontalPadding
        color: root.highlighted ? root.theme.accentTextColor : root.theme.textColor
        elide: Text.ElideRight
        font: root.titleFont
        horizontalAlignment: Text.AlignHCenter
        maximumLineCount: 1
        text: root.title
        verticalAlignment: Text.AlignVCenter
        wrapMode: Text.NoWrap
    }
}
