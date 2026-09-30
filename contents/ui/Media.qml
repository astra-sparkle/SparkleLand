import QtQuick

// 媒体信息：只显示曲目名。
// 刻意不提供任何播放控制（播放/暂停/上一首/下一首一律不做）——
// 面板上对媒体条目唯一的交互是 main.qml 里的「打开完整视图」。
//
// 背景高亮不在这里画：面板条目的媒体背景由 main.qml 统一绘制
//（因为展开时条目内容是时钟，但仍要保留媒体背景），这里只负责文字颜色。
Item {
    id: root

    property var theme
    property font panelFont
    property bool playing: false
    property bool useThemeBackground: true
    property string title: ""

    // 背景为「播放中的高亮色」时文字用 highlightedTextColor；
    // 暂停时背景是减淡/加深过的，用常规文字色更清楚。
    readonly property bool highlighted: root.playing && root.useThemeBackground

    implicitHeight: 32
    implicitWidth: titleLabel.implicitWidth + 24

    Text {
        id: titleLabel

        anchors.fill: parent
        anchors.leftMargin: 12
        anchors.rightMargin: 12
        color: root.highlighted ? root.theme.highlightedTextColor : root.theme.textColor
        elide: Text.ElideRight
        font: root.panelFont
        horizontalAlignment: Text.AlignHCenter
        maximumLineCount: 1
        text: root.title
        verticalAlignment: Text.AlignVCenter
        wrapMode: Text.NoWrap
    }
}
