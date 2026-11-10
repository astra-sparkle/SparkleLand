import QtQuick
import org.kde.kirigami.primitives as Primitives

// Rounded cover image
// 圆角封面图
Primitives.ShadowedImage {
    id: root

    // Soft placeholder tint
    // 柔和占位色
    property color placeholderColor: "transparent"

    readonly property bool loaded: root.status === Image.Ready

    readonly property color placeholderTint: Qt.rgba(root.placeholderColor.r, root.placeholderColor.g, root.placeholderColor.b, 0.25)

    border.width: 0
    color: root.loaded ? "transparent" : root.placeholderTint
    fillMode: Image.PreserveAspectCrop
}
