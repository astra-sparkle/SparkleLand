import QtQuick

// 紧凑表示中显示当前曲目名称。
Item {
    id: root

    property var theme
    property font titleFont
    property bool playing: false
    property bool useThemeBackground: true
    property string title: ""

    // 仅在播放背景高亮时使用高亮文字色。
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
