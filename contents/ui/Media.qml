import QtQuick

// 紧凑条目中的曲目名；播放控制位于展开面板。
Item {
    id: root

    property var theme
    property font titleFont
    property bool playing: false
    property bool useThemeBackground: true
    property string title: ""

    // 仅在播放且启用主题背景时使用高亮文字色。
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
        font: root.titleFont
        horizontalAlignment: Text.AlignHCenter
        maximumLineCount: 1
        text: root.title
        verticalAlignment: Text.AlignVCenter
        wrapMode: Text.NoWrap
    }
}
