import QtQuick
import org.kde.kirigami as Kirigami



// Compact media title; controls are rendered in the expanded panel
// 紧凑条目中的曲目名，播放控制位于展开面板
Item {
    id: root

    property var theme
    property font titleFont
    property bool playing: false
    property bool useThemeBackground: true
    property string title: ""

    // Use accent text only while playing with the theme background enabled
    // 仅在播放且启用主题背景时使用强调色文字
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





    // Playback buttons with a lightweight hover highlight
    // 带轻量悬停高亮的播放控制按钮
    component MediaControlButton: Item {
        id: button

        // Properties injected by Panel.qml
        // 由 Panel.qml 注入的属性
        property var theme
        property string source: ""

        signal clicked

        readonly property bool hovered: mouseArea.containsMouse

        Kirigami.ShadowedRectangle {
            anchors.fill: parent

            // Positive offsets place the shadow at the bottom right
            // x、y 为正时阴影位于右下方
            readonly property real shadowOffset: Math.round(Kirigami.Units.smallSpacing / 2)

            border.width: 0
            color: button.theme.accentSubtleColor
            opacity: button.hovered ? 1 : 0
            radius: Kirigami.Units.cornerRadius
            shadow.color: Qt.rgba(0, 0, 0, 0.1)
            shadow.size: Kirigami.Units.smallSpacing
            shadow.xOffset: shadowOffset
            shadow.yOffset: shadowOffset

            Behavior on opacity {
                NumberAnimation {
                    duration: Kirigami.Units.shortDuration
                    easing.type: Easing.OutCubic
                }
            }
        }

        Kirigami.Icon {
            anchors.centerIn: parent
            height: Math.round(parent.height * 0.85)
            source: button.source
            width: height
        }

        MouseArea {
            id: mouseArea

            anchors.fill: parent
            hoverEnabled: true
            onClicked: button.clicked()
        }
    }
}
