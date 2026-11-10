import QtQuick
import org.kde.ksvg as KSvg

// Desktop theme frame drawn behind a list row while hovered
// 悬停时绘制在列表行背后的桌面主题边框
KSvg.FrameSvgItem {
    id: root

    property bool hovered: false

    imagePath: "widgets/listitem"
    prefix: "hover"
    visible: root.hovered
}
