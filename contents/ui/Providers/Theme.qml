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
    // Kirigami provides the semantic negative color
    // Kirigami 提供语义化的负向颜色
    readonly property color negativeTextColor: Kirigami.Theme.negativeTextColor
    readonly property font defaultFont: Kirigami.Theme.defaultFont
    readonly property int gridUnit: Kirigami.Units.gridUnit

    // Tooltip and banner roles: the banner window uses its own palette roles
    // 工具提示与横幅角色：横幅窗口使用独立的调色板角色
    readonly property color tooltipTextColor: themeAdapter.palette.active.toolTipText
    readonly property color tooltipDisabledTextColor: themeAdapter.palette.disabled.toolTipText

    // Shadow shared by the framed buttons
    // 带边框按钮共用的阴影色
    readonly property color shadowColor: Qt.rgba(0, 0, 0, 0.1)

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

    // Subtle tint shown under unloaded album art
    // 未加载专辑图时显示的柔和底色
    readonly property color coverPlaceholderColor: {
        const base = themeAdapter.disabledTextColor;
        return Qt.rgba(base.r, base.g, base.b, 0.25);
    }

    // Media background: the accent itself while playing, a shifted accent while paused
    // 媒体背景：播放时为强调色本身，暂停时使用偏移后的强调色
    function mediaBackgroundColor(playing) {
        const base = themeAdapter.accentColor;
        return playing ? base : (themeAdapter.accentTextIsLight ? Qt.darker(base, 1.4) : Qt.lighter(base, 1.4));
    }
}
