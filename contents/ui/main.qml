import "style"
import QtQml
import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.plasmoid

// Applet entry point
// 小组件入口
PlasmoidItem {
	id: root

	readonly property string appTitle: i18n("Sparkle Land")
	readonly property string appIconName: "preferences-desktop"

	// Config guard
	// 配置保护
	function configNumber(value, fallback) {
		const number = Number(value);
		return isNaN(number) ? fallback : number;
	}

	function configString(value) {
		return typeof value === "string" ? value : "";
	}

	readonly property int panelMinimumWidth: Math.max(16, root.configNumber(plasmoid.configuration.minimumPanelWidth, 64))
	readonly property int panelMaximumWidth: Math.max(root.panelMinimumWidth, root.configNumber(plasmoid.configuration.maximumPanelWidth, 240))
	readonly property int panelAverageWidth: Math.round((root.panelMinimumWidth + root.panelMaximumWidth) / 2)
	readonly property bool mediaUseThemeBackground: plasmoid.configuration.mediaUseThemeBackground !== false
	// Compact media style: 0 = title, 1 = clock with background, 2 = clock with icon
	// 紧凑媒体样式：0 = 标题，1 = 带背景时钟，2 = 带图标时钟
	readonly property int mediaCompactStyle: {
		const style = root.configNumber(plasmoid.configuration.mediaCompactStyle, 0);
		return (style >= 0 && style <= 2) ? Math.round(style) : 0;
	}
	// Compact clock icon; empty keeps the packaged default
	// 紧凑时钟图标；为空时使用内置默认值
	readonly property string mediaPlaybackIcon: {
		const icon = root.configString(plasmoid.configuration.mediaPlaybackIcon);
		return icon.length > 0 ? icon : "music-note-16th";
	}
	// Notifications are enabled by default
	// 通知默认开启
	readonly property bool notificationsEnabled: plasmoid.configuration.notificationsEnabled !== false
	readonly property int notificationsMaxVisible: Math.max(0, root.configNumber(plasmoid.configuration.notificationsMaxVisible, 5))
	readonly property bool notificationsIncludeExpired: plasmoid.configuration.notificationsIncludeExpired === true
	readonly property bool notificationsShowDoNotDisturb: plasmoid.configuration.notificationsShowDoNotDisturb !== false
	readonly property bool notificationsShowClearAll: plasmoid.configuration.notificationsShowClearAll !== false
	// Compact badge count toggle
	// 紧凑角标计数开关
	readonly property bool notificationsShowUnreadCount: plasmoid.configuration.notificationsShowUnreadCount !== false
	// Popup visibility and timeout
	// 弹窗显示与超时
	readonly property bool notificationsShowPopups: plasmoid.configuration.notificationsShowPopups !== false
	readonly property int notificationsBannerTimeout: Math.max(1, root.configNumber(plasmoid.configuration.notificationsBannerTimeout, 5))
	// Screen edge for popup placement
	// 弹窗所在的屏幕边缘
	readonly property int panelLocation: plasmoid.location
	readonly property bool showDate: plasmoid.configuration.showDate === true
	// Tooltip clock ticks every second
	// 提示时钟每秒更新
	property date hoverTooltipNow: new Date()
	// Keep seconds in the tooltip time format
	// 提示时间格式保留秒
	readonly property string hoverTooltipTimeFormat: {
		const mode = root.configNumber(plasmoid.configuration.timeFormatMode, 0);
		if (mode === 1) {
			return "h:mm:ss AP";
		}
		if (mode === 2) {
			return "HH:mm:ss";
		}
		return Qt.locale().timeFormat(Locale.ShortFormat).indexOf("AP") >= 0 ? "h:mm:ss AP" : "HH:mm:ss";
	}
	// Tooltip summary and current track
	// 提示摘要和当前播放曲目
	readonly property string hoverTooltipSubText: {
		const parts = [];
		if (root.notificationsEnabled) {
			const unread = root.unreadNotificationCount;
			parts.push(unread > 0
				? i18np("%1 unread notification", "%1 unread notifications", unread)
				: i18n("No unread notifications"));
		}
		if (root.isPlaying && root.trackTitle.length > 0) {
			parts.push(i18n("Now playing: %1", root.trackTitle));
		}
		return parts.join(" · ");
	}
	// Hover text replaces the packaged tooltip text
	// 悬停文本替换内置提示文本
	toolTipMainText: Qt.formatTime(root.hoverTooltipNow, root.hoverTooltipTimeFormat)
	toolTipSubText: root.hoverTooltipSubText

	// Compact text scales with panel height when no explicit size is set
	// 未设置显式字号时，紧凑文本随面板高度缩放
	readonly property bool autoCompactFontSize: root.configNumber(plasmoid.configuration.fontPointSize, 0) <= 0

	// Measure the theme font in logical panel pixels
	// 用逻辑像素测量主题字体
	TextMetrics {
		id: themeFontMetrics

		font: root.theme.defaultFont
		text: "M"
	}

	readonly property int themeDefaultPixelSize: Math.max(8, Math.round(themeFontMetrics.height))

	// Compute a comfortable text size from the panel height
	// 根据面板高度计算合适字号
	function panelPixelSize(height, twoLines) {
		const available = height > 0 ? height : 32;
		const fitted = Math.round(available * (twoLines ? 0.56 : 0.71));
		return Math.max(8, Math.min(fitted, 3 * root.themeDefaultPixelSize));
	}

	function fontWithPixelSize(sourceFont, pixelSize) {
		return Qt.font({
			"bold": sourceFont.bold,
			"family": sourceFont.family,
			"italic": sourceFont.italic,
			"pixelSize": Math.max(1, Math.round(pixelSize))
		});
	}

	// Copy a font and scale it by a factor
	// 按比例复制并缩放字体
	function fontScaled(sourceFont, factor) {
		if (sourceFont.pixelSize > 0) {
			return root.fontWithPixelSize(sourceFont, sourceFont.pixelSize * factor);
		}
		return Qt.font({
			"bold": sourceFont.bold,
			"family": sourceFont.family,
			"italic": sourceFont.italic,
			"pointSize": Math.max(1, sourceFont.pointSize * factor)
		});
	}

	// Time format priority: custom, user mode, locale fallback
	// 时间格式优先级：自定义、用户模式、系统回退
	readonly property string timeFormat: {
		const custom = root.configString(plasmoid.configuration.customTimeFormat);
		if (custom.length > 0) {
			return custom;
		}

		const mode = root.configNumber(plasmoid.configuration.timeFormatMode, 0);
		if (mode === 1) {
			return "h:mm AP";
		}
		if (mode === 2) {
			return "HH:mm";
		}

		// Omit seconds when following the system format
		// 跟随系统格式时不显示秒
		return Qt.locale().timeFormat(Locale.ShortFormat).replace(/:?s+/g, "");
	}

	readonly property string dateFormat: {
		const custom = root.configString(plasmoid.configuration.customDateFormat);
		return custom.length > 0 ? custom : Qt.locale().dateFormat(Locale.ShortFormat);
	}

	// Shared theme colors and accent variants
	// 共享主题颜色和强调色变体
	QtObject {
		id: themeAdapter

		// Palette-driven text colors
		// 调色板驱动的文本颜色
		readonly property color textColor: root.palette.active.windowText
		readonly property color disabledTextColor: root.palette.disabled.windowText
		// QPalette has no semantic error role; use Breeze negative red
		// QPalette 没有语义错误色，使用 Breeze 负向红
		readonly property color negativeTextColor: "#da4453"
		readonly property font defaultFont: Kirigami.Theme.defaultFont
		readonly property int gridUnit: Kirigami.Units.gridUnit

		// Accent follows the active palette
		// 强调色遵循当前调色板
		readonly property color accentColor: root.palette.active.accent !== undefined
			? root.palette.active.accent
			: root.palette.active.highlight

		readonly property color accentTextColor: root.palette.active.highlightedText

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

		// Keep hover contrast high
		// 保持悬停时的对比度
		readonly property color accentHoverColor: themeAdapter.accentTextIsLight
			? Qt.darker(themeAdapter.accentColor, 1.12)
			: Qt.lighter(themeAdapter.accentColor, 1.2)

		// Soft alpha variants for subtle fills
		// 用于柔和填充的透明度变体
		readonly property color accentSubtleColor: themeAdapter.accentAlpha(0.18)
		readonly property color accentMutedColor: themeAdapter.accentAlpha(0.4)

		// Return the accent color with alpha
		// 返回带透明度的强调色
		function accentAlpha(alpha) {
			const accent = themeAdapter.accentColor;
			return Qt.rgba(accent.r, accent.g, accent.b, alpha);
		}
	}

	readonly property var theme: themeAdapter

	readonly property font panelFont: {
		const family = root.configString(plasmoid.configuration.fontFamily);
		const pointSize = root.configNumber(plasmoid.configuration.fontPointSize, 0);
		return Qt.font({
			"bold": plasmoid.configuration.fontBold === true,
			"family": family.length > 0 ? family : root.theme.defaultFont.family,
			"italic": plasmoid.configuration.fontItalic === true,
			"pointSize": pointSize > 0 ? pointSize : root.theme.defaultFont.pointSize
		});
	}

	// Each feature keeps its own provider
	// 每个功能保留自己的数据源
	Providers {
		id: providers

		notificationsEnabled: root.notificationsEnabled
		notificationsIncludeExpired: root.notificationsIncludeExpired
		notificationsMaxVisible: root.notificationsMaxVisible
	}

	readonly property string trackTitle: providers.media.trackTitle
	readonly property bool isPlaying: providers.media.playing

	readonly property bool hasNotifications: providers.notifications.hasNotifications
	readonly property int unreadNotificationCount: providers.notifications.unreadCount

	// Media background uses the accent color
	// 媒体背景使用强调色
	readonly property bool mediaBackgroundVisible: root.hasMedia && root.mediaUseThemeBackground
	readonly property color mediaBackgroundColor: {
		const base = root.theme.accentColor;
		// Shift away from the palette text color so the paused state keeps contrast
		// 朝调色板文字色的反方向调整，保证暂停态仍有足够对比度
		return root.isPlaying ? base : (root.theme.accentTextIsLight ? Qt.darker(base, 1.4) : Qt.lighter(base, 1.4));
	}

	// Date requested for the calendar
	// 日历跳转目标日期
	property date requestedDate

	readonly property bool hasMedia: root.trackTitle.length > 0
	// Track title replaces the clock only in style 0; the clock styles keep it visible
	// 仅样式 0 用曲名替代时钟，其余样式保留时钟
	readonly property bool compactShowsMediaTitle: root.hasMedia && root.mediaCompactStyle === 0
	readonly property bool compactShowsMediaIcon: root.hasMedia && root.mediaCompactStyle === 2
	readonly property bool panelShowsMedia: root.compactShowsMediaTitle && !root.expanded

	Plasmoid.title: root.appTitle
	Plasmoid.icon: root.isPlaying ? "media-playback-start" : root.appIconName

	Timer {
		interval: 1000
		repeat: true
		running: true
		triggeredOnStart: true
		onTriggered: root.hoverTooltipNow = new Date()
	}

	// Expand the calendar and select the requested date, or today by default
	// 展开日历并跳转到指定日期；未指定时使用今天
	function openCalendar(date) {
		const target = (date instanceof Date && !isNaN(date.getTime())) ? date : new Date();
		root.requestedDate = new Date(target.getFullYear(), target.getMonth(), target.getDate());
		root.expanded = true;
	}

	function toggleCalendar(date) {
		if (root.expanded) {
			root.expanded = false;
			return;
		}
		openCalendar(date);
	}

	compactRepresentation: Item {
		id: compactItem

		readonly property int contentWidth: root.compactShowsMediaTitle
			? Math.max(clockItem.implicitWidth, mediaItem.implicitWidth)
			: clockItem.implicitWidth + compactItem.sideSpace

		readonly property font primaryFont: root.autoCompactFontSize
			? root.fontWithPixelSize(root.panelFont, root.panelPixelSize(height, root.showDate))
			: root.panelFont
		readonly property font secondaryFont: root.autoCompactFontSize
			? root.fontWithPixelSize(root.panelFont, root.panelPixelSize(height, root.showDate) * 0.8)
			: root.fontScaled(root.panelFont, 0.8)
		readonly property font mediaTitleFont: root.autoCompactFontSize
			? root.fontWithPixelSize(root.panelFont, root.panelPixelSize(height, false))
			: root.panelFont

		// Clock+icon style always reserves equal side space for the playback icon and the badge, even while either is hidden
		// 时钟+图标样式下左右始终预留相同空间，供播放图标与通知角标使用（即使暂时隐藏）
		readonly property int sideSpace: root.mediaCompactStyle === 2
			? Math.max(mediaPlaybackIcon.width + 6, notificationBadge.width + 3)
			: 0

		// Reserve space for the badge so it does not cover the time or track title
		// 为角标预留空间，避免遮挡时间或曲名
		readonly property int badgeSpace: root.mediaCompactStyle === 2 ? sideSpace : (notificationBadge.visible ? notificationBadge.width + 4 : 0)

		// Media uses average or maximum width; clock width follows content within configured limits
		// 媒体模式取平均或最大宽度；时钟模式按内容宽度限制在配置范围内
		readonly property int preferredWidth: (root.compactShowsMediaTitle
			? (contentWidth > root.panelAverageWidth ? root.panelMaximumWidth : root.panelAverageWidth)
			: Math.max(root.panelMinimumWidth, Math.min(root.panelMaximumWidth, contentWidth))) + badgeSpace

		Layout.fillHeight: true
		Layout.minimumHeight: 32
		Layout.minimumWidth: root.panelMinimumWidth
		Layout.preferredHeight: 32
		Layout.preferredWidth: preferredWidth

		implicitHeight: 32
		implicitWidth: preferredWidth

		// Keep the media background visible while expanded as a track indicator
		// 展开时保留媒体背景，提示当前有曲目
		Rectangle {
			anchors.fill: parent
			color: root.mediaBackgroundColor
			radius: Kirigami.Units.cornerRadius
			visible: root.mediaBackgroundVisible
		}

		Media {
			id: mediaItem

			anchors.fill: parent
			anchors.rightMargin: compactItem.badgeSpace
			enabled: visible
			playing: root.isPlaying
			theme: root.theme
			title: root.trackTitle
			titleFont: compactItem.mediaTitleFont
			useThemeBackground: root.mediaUseThemeBackground
			visible: root.panelShowsMedia
		}

		// Music note left of the clock in the icon style, accent colored without a background
		// 图标样式下位于时钟左侧的音符，无背景时使用强调色
		// Switch to the text color over the media background so the icon stays legible
		// 媒体背景显示时改用文字色，保证图标在背景上清晰可见
		Kirigami.Icon {
			id: mediaPlaybackIcon

			readonly property int iconSize: Math.round(Math.max(10, root.panelPixelSize(compactItem.height, false) * 0.9))

			anchors.left: parent.left
			anchors.leftMargin: 6
			anchors.verticalCenter: parent.verticalCenter
			color: root.mediaBackgroundVisible ? root.theme.textColor : root.theme.accentColor
			height: iconSize
			source: root.mediaPlaybackIcon
			visible: root.compactShowsMediaIcon
			width: iconSize
		}

		Clock {
			id: clockItem

			anchors.fill: parent
			anchors.leftMargin: compactItem.sideSpace
			anchors.rightMargin: compactItem.badgeSpace
			dateFont: compactItem.secondaryFont
			dateFormat: root.dateFormat
			enabled: visible
			showDate: root.showDate
			theme: root.theme
			timeFont: compactItem.primaryFont
			timeFormat: root.timeFormat
			visible: !root.panelShowsMedia
		}

		Indicators.Badge {
			id: notificationBadge

			anchors.right: parent.right
			anchors.rightMargin: 3
			anchors.verticalCenter: parent.verticalCenter
			count: root.unreadNotificationCount
			// Over the media background the dot turns into the text color and the count takes the background color
			// 媒体背景显示时圆点改用文字色，计数文字改用背景色
			fillColor: root.mediaBackgroundVisible ? root.theme.textColor : root.theme.accentColor
			height: Math.round(Math.max(16, parent.height * 0.55))
			labelColor: root.mediaBackgroundVisible ? root.mediaBackgroundColor : root.theme.accentTextColor
			labelFont: root.fontWithPixelSize(root.panelFont, Math.max(8, Math.round(notificationBadge.height * 0.6)))
			showCount: root.notificationsShowUnreadCount
			theme: root.theme
			visible: root.notificationsEnabled && root.unreadNotificationCount > 0
		}

		// Plasma positions this banner beside the applet; declare it before MouseArea to preserve clicks
		// 横幅由 Plasma 锚定在小组件旁；置于 MouseArea 前以保留点击操作
		NotificationsPopup {
			appletExpanded: root.expanded
			displayTime: root.notificationsBannerTimeout * 1000
			panelLocation: root.panelLocation
			provider: providers.notifications.provider
			showPopups: root.notificationsShowPopups
		}

		MouseArea {
			anchors.fill: parent
			onClicked: root.toggleCalendar()
		}
	}

	fullRepresentation: Panel {
		hasMedia: root.hasMedia
		hasNotifications: root.hasNotifications
		appletExpanded: root.expanded
		mediaControlsEnabled: providers.media.available
		mediaProvider: providers.media.provider
		notificationsProvider: providers.notifications.provider
		notificationsShowClearAll: root.notificationsShowClearAll
		notificationsShowDoNotDisturb: root.notificationsShowDoNotDisturb
		requestedDate: root.requestedDate
		textFont: root.panelFont
		theme: root.theme
		timeFormat: root.timeFormat

	}
}
