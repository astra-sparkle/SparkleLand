import QtQuick

// Compact media title label.
// 紧凑媒体标题标签。
Item {
    id: root

    property var theme
    property font titleFont
    property bool playing: false
    property bool useThemeBackground: true
    property string title: ""

    // Use accent text only when media is playing and the theme background is enabled.
    // 仅在播放且启用主题背景时使用强调色文字。
    readonly property bool highlighted: root.playing && root.useThemeBackground

    implicitHeight: 32
    implicitWidth: titleLabel.implicitWidth + 24

    Text {
        id: titleLabel

        anchors.fill: parent
        anchors.leftMargin: 12
        anchors.rightMargin: 12
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
