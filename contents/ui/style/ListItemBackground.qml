import QtQuick
import org.kde.ksvg as KSvg

KSvg.FrameSvgItem {
    id: root

    property bool hovered: false

    imagePath: "widgets/listitem"
    prefix: "hover"
    visible: root.hovered
}
