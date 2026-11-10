import QtQuick
import org.kde.kirigami as Kirigami

// Icon button with a lightweight hover highlight
// 带轻量悬停高亮的图标按钮
Item {
    id: root

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
        color: root.theme.accentSubtleColor
        opacity: root.hovered ? 1 : 0
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
        source: root.source
        width: height
    }

    MouseArea {
        id: mouseArea

        anchors.fill: parent
        hoverEnabled: true
        onClicked: root.clicked()
    }
}