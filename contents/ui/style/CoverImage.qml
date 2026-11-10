import QtQuick
import org.kde.kirigami.primitives as Primitives

// Rounded image with a placeholder fill while it is empty or loading
// 圆角图片，为空或加载中时显示占位底色
Primitives.ShadowedImage {
    id: root

    // Injected placeholder tint; keeps a low alpha so the panel shows through
    // 注入的占位色，保持低透明度使面板背景透出
    property color placeholderColor: "transparent"

    readonly property bool loaded: root.status === Image.Ready

    readonly property color placeholderTint: Qt.rgba(root.placeholderColor.r, root.placeholderColor.g, root.placeholderColor.b, 0.25)

    border.width: 0
    color: root.loaded ? "transparent" : root.placeholderTint
    fillMode: Image.PreserveAspectCrop
}
