import QtQuick
import org.kde.kirigami as Kirigami
import org.kde.ksvg as KSvg

// Reusable button styles, used as Buttons.IconButton and Buttons.ToolButton
// 可复用的按钮样式，分别以 Buttons.IconButton 和 Buttons.ToolButton 使用
Item {
    // Icon button with a lightweight accent hover highlight
    // 带轻量强调色悬停高亮的图标按钮
    component IconButton: Item {
        id: button

        // Properties injected by the using view
        // 由使用方视图注入的属性
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

    // Icon button framed by the desktop theme's tool button elements
    // 使用桌面主题工具按钮元素的图标按钮
    component ToolButton: Item {
        id: button

        // Properties injected by the using view
        // 由使用方视图注入的属性
        property string source: ""
        // Latched state keeps the pressed frame and full icon opacity
        // 常按状态固定使用按下边框与不透明图标
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
