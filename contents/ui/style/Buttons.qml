import QtQuick
import org.kde.kirigami as Kirigami
import org.kde.ksvg as KSvg

Item {
    component IconButton: Item {
        id: button

        property var theme
        property string source: ""

        signal clicked

        readonly property bool hovered: mouseArea.containsMouse

        // Read the shared rounding from the theme, then scale it up with large buttons,
        // so media controls keep the same proportional rounding as the expanded panel
        // 从主题读取共用圆角；大尺寸按钮按同一比例放大，与展开面板中的封面圆角观感一致
        property real cornerRadius: Math.round(Math.max(button.theme.cornerRadius,
            button.height * 0.12))

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
            radius: button.cornerRadius
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

    // Toggle button: a persistent subtle-accent fill marks the checked state,
    // while the icon brightness carries the on/off contrast
    // 切换按钮：选中时保持淡强调色填充，开关状态主要由图标亮度区分
    component ToggleButton: Item {
        id: button

        property var theme
        property string source: ""
        property bool checked: false

        signal clicked

        readonly property bool hovered: mouseArea.containsMouse

        // Same rounding rule as the generic button
        // 圆角规则与通用按钮保持一致
        property real cornerRadius: Math.round(Math.max(button.theme.cornerRadius,
            button.height * 0.12))

        implicitHeight: Math.round(Kirigami.Units.iconSizes.small)
        implicitWidth: implicitHeight

        Kirigami.ShadowedRectangle {
            anchors.fill: parent

            // Positive offsets place the shadow at the bottom right
            // x、y 为正时阴影位于右下方
            readonly property real shadowOffset: Math.round(Kirigami.Units.smallSpacing / 2)

            border.width: 0
            color: button.theme.accentSubtleColor
            // Hover previews the accent fill without carrying the checked weight
            // 悬停时以更淡的填充预览强调色，但弱于选中态
            opacity: button.checked ? 1 : (button.hovered ? 0.5 : 0)
            radius: button.cornerRadius
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
            // Brightness switch: checked icons render at full strength, unchecked icons stay dimmed
            // 亮度切换：选中时图标为全亮，未选中时保持降低的亮度
            opacity: button.checked ? 1 : 0.55
            source: button.source
            width: height

            Behavior on opacity {
                NumberAnimation {
                    duration: Kirigami.Units.shortDuration
                    easing.type: Easing.OutCubic
                }
            }
        }

        MouseArea {
            id: mouseArea

            anchors.fill: parent
            hoverEnabled: true
            onClicked: button.clicked()
        }
    }

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
