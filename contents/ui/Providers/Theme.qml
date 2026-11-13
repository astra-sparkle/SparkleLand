import QtQuick
import org.kde.kirigami as Kirigami

// Shared theme adapter: palette-derived colors, accent variants and control rounding
// 共享主题适配器：调色板颜色、强调色变体与控件圆角
QtObject {
    id: themeAdapter

    // Palette injected by the applet shell
    // 由小组件外壳注入的调色板
    property var palette

    readonly property color textColor: themeAdapter.palette.active.windowText
    readonly property color disabledTextColor: themeAdapter.palette.disabled.windowText
    // QPalette has no semantic error role; use Breeze negative red
    // QPalette 没有语义错误色，使用 Breeze 负向红
    readonly property color negativeTextColor: "#da4453"
    readonly property font defaultFont: Kirigami.Theme.defaultFont
    readonly property int gridUnit: Kirigami.Units.gridUnit

    // Shared rounding for controls, following the KDE style value when available;
    // Plasma 6.0/6.1 predate Kirigami.Units.cornerRadius, so fall back to a
    // grid-derived value close to its 5px default
    // 控件共用圆角：优先使用 KDE 样式提供的数值；Plasma 6.0/6.1 尚无
    // Kirigami.Units.cornerRadius，此时按网格单位回退到接近其 5px 默认值
    readonly property real cornerRadius: Math.round(
        typeof Kirigami.Units.cornerRadius === "number"
            ? Kirigami.Units.cornerRadius
            : themeAdapter.gridUnit / 4)

    // Accent follows the active palette
    // 强调色遵循当前调色板
    readonly property color accentColor: themeAdapter.palette.active.accent !== undefined
        ? themeAdapter.palette.active.accent
        : themeAdapter.palette.active.highlight

    readonly property color accentTextColor: themeAdapter.palette.active.highlightedText

    // WCAG luminance with gamma correction
    // 采用伽马修正的 WCAG 亮度计算
    function relativeLuminance(colorValue) {
        const r = colorValue.r <= 0.03928 ? colorValue.r / 12.92 : Math.pow((colorValue.r + 0.055) / 1.055, 2.4);
        const g = colorValue.g <= 0.03928 ? colorValue.g / 12.92 : Math.pow((colorValue.g + 0.055) / 1.055, 2.4);
        const b = colorValue.b <= 0.03928 ? colorValue.b / 12.92 : Math.pow((colorValue.b + 0.055) / 1.055, 2.4);
        return 0.2126 * r + 0.7152 * g + 0.0722 * b;
    }

    // Use text luminance to pick a hover direction
    // 根据文本亮度选择悬停方向
    readonly property bool accentTextIsLight: themeAdapter.relativeLuminance(themeAdapter.accentTextColor) > 0.5

    // Move away from the text color so hover keeps contrast
    // 朝文字色反方向调整，保证悬停时仍有对比度
    readonly property color accentHoverColor: themeAdapter.accentTextIsLight
        ? Qt.darker(themeAdapter.accentColor, 1.12)
        : Qt.lighter(themeAdapter.accentColor, 1.2)

    // Soft alpha variants for subtle fills
    // 用于柔和填充的透明度变体
    readonly property color accentSubtleColor: themeAdapter.accentAlpha(0.18)
    readonly property color accentMutedColor: themeAdapter.accentAlpha(0.4)

    function accentAlpha(alpha) {
        const accent = themeAdapter.accentColor;
        return Qt.rgba(accent.r, accent.g, accent.b, alpha);
    }
}
