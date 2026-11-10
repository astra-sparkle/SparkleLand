import QtQuick
import org.kde.kirigami as Kirigami
import org.kde.ksvg as KSvg

// Reusable button components for the applet UI.
// 小组件界面的可复用按钮组件。
Item {
    // Accent hover icon button.
    // 强调色悬停图标按钮。
    component IconButton: Item {
        id: button

        property var theme
        property string source: ""

        signal clicked

        readonly property bool hovered: mouseArea.containsMouse

        implicitHeight: Math.round(Kirigami.Units.iconSizes.small)
        implicitWidth: implicitHeight

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

    // Theme-framed tool button
    // 主题框架工具按钮
    component ToolButton: Item {
        id: button

        property string source: ""
        // Pressed state keeps the active frame
        // 按下态保留激活框架
        property bool pressed: false
        property color iconColor: "transparent"
        property real iconOpacity: 0.7
        property real iconSizeRatio: 0.8

        signal clicked

        readonly property bool hovered: mouseArea.containsMouse

        implicitHeight: Kirigami.Units.iconSizes.smallMedium
        implicitWidth: implicitHeight

        KSvg.FrameSvgItem {
            anchors.fill: parent
            imagePath: "widgets/button"
            prefix: button.pressed ? "toolbutton-pressed" : "toolbutton-hover"
            visible: button.pressed || button.hovered
        }

        Kirigami.Icon {
            anchors.centerIn: parent
            color: button.iconColor.a > 0 ? button.iconColor : Kirigami.Theme.textColor
            height: Math.round(parent.height * button.iconSizeRatio)
            opacity: button.pressed || button.hovered ? 1 : button.iconOpacity
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
