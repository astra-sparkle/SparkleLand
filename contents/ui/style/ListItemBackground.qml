import QtQuick
import org.kde.ksvg as KSvg

// Hover frame for list rows.
// 列表行的悬停框架。
KSvg.FrameSvgItem {
    id: root

    property bool hovered: false

    imagePath: "widgets/listitem"
    prefix: "hover"
    visible: root.hovered
}
