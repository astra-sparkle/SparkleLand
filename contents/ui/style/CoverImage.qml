import QtQuick
import QtQuick.Window
import org.kde.kirigami.primitives as Primitives

Primitives.ShadowedImage {
    id: root

    // Placeholder tint shown while the artwork loads; supplied by the shared theme
    // 封面加载期间显示的占位底色；由共享主题提供
    property color placeholderColor: "transparent"

    // Decode at device resolution so large artwork is not kept at full size
    // 按设备像素解码，避免大尺寸封面保留原始分辨率
    readonly property int decodeSize: Math.max(1, Math.round(Math.max(root.width, root.height) * Screen.devicePixelRatio))

    readonly property bool loaded: root.status === Image.Ready

    asynchronous: true
    border.width: 0
    color: root.loaded ? "transparent" : root.placeholderColor
    fillMode: Image.PreserveAspectCrop
    sourceSize: Qt.size(root.decodeSize, root.decodeSize)
}
