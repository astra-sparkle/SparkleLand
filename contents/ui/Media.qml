import QtQuick

// 媒体信息：只显示曲目名。
// 刻意不提供任何播放控制（播放/暂停/上一首/下一首一律不做）——
// 面板上对媒体条目唯一的交互是 main.qml 里的「打开完整视图」。
Item {
    id: root

    property var theme
    property font panelFont
    property bool playing: false
    property bool useThemeBackground: true
    property string title: ""

    readonly property bool highlighted: root.playing && root.useThemeBackground

    implicitHeight: 32
    implicitWidth: titleLabel.implicitWidth + 24

    Rectangle {
        anchors.fill: parent
        // 未播放或用户关掉主题色背景时不绘制
        color: root.highlighted ? root.theme.highlightColor : "transparent"
        radius: 4
        visible: root.highlighted
    }

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
