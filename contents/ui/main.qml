import QtQml
import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.plasmoid

// Applet entry point coordinating the clock, media, calendar, and settings
// 小组件入口，协调时钟、媒体、日历与配置
PlasmoidItem {
	id: root

	readonly property string appTitle: i18n("Sparkle Land")
	readonly property string appIconName: "preferences-desktop"

	// Normalize config values to prevent NaN in size calculations
	// 归一化配置值，避免尺寸计算产生 NaN
	function configNumber(value, fallback) {
		const number = Number(value);
		return isNaN(number) ? fallback : number;
	}

	function configString(value) {
		return typeof value === "string" ? value : "";
	}

	function safeMax(first, second) {
		return Math.max(root.configNumber(first, 0), root.configNumber(second, 0));
	}

	readonly property int panelMinimumWidth: Math.max(16, root.configNumber(plasmoid.configuration.minimumPanelWidth, 64))
	readonly property int panelMaximumWidth: Math.max(root.panelMinimumWidth, root.configNumber(plasmoid.configuration.maximumPanelWidth, 240))
	readonly property int panelAverageWidth: Math.round((root.panelMinimumWidth + root.panelMaximumWidth) / 2)
	readonly property bool mediaUseThemeBackground: plasmoid.configuration.mediaUseThemeBackground !== false
	// Compact panel style while media is playing: 0 = track title, 1 = clock with background, 2 = clock with playback icon
	// 媒体播放时紧凑面板样式：0 = 曲名，1 = 时钟加背景，2 = 时钟加播放图标
	readonly property int mediaCompactStyle: {
		const style = root.configNumber(plasmoid.configuration.mediaCompactStyle, 0);
		return (style >= 0 && style <= 2) ? Math.round(style) : 0;
	}
	// Notifications default to enabled; disabling them restores the original layout
	// 通知默认开启，关闭后恢复原布局
	readonly property bool notificationsEnabled: plasmoid.configuration.notificationsEnabled !== false
	readonly property int notificationsMaxVisible: Math.max(0, root.configNumber(plasmoid.configuration.notificationsMaxVisible, 5))
	readonly property bool notificationsIncludeExpired: plasmoid.configuration.notificationsIncludeExpired === true
	readonly property bool notificationsShowDoNotDisturb: plasmoid.configuration.notificationsShowDoNotDisturb !== false
	readonly property bool notificationsShowClearAll: plasmoid.configuration.notificationsShowClearAll !== false
	// Unread count inside the compact dot; when off the dot stays as a plain indicator
	// 紧凑圆点是否显示未读数量；关闭后圆点仅作为提示
	readonly property bool notificationsShowUnreadCount: plasmoid.configuration.notificationsShowUnreadCount !== false
	// Banner visibility and duration; plasmashell positions banners beside the applet
	// 横幅开关与时长；位置由 plasmashell 锚定在小组件旁
	readonly property bool notificationsShowPopups: plasmoid.configuration.notificationsShowPopups !== false
	readonly property int notificationsBannerTimeout: Math.max(1, root.configNumber(plasmoid.configuration.notificationsBannerTimeout, 5))
	// Screen edge used to position banners (Plasma::Types::Location)
	// 面板所在屏幕边缘，供横幅定位（Plasma::Types::Location）
	readonly property int panelLocation: plasmoid.location
	readonly property bool showDate: plasmoid.configuration.showDate === true
	// Scale compact text with panel height when no font size is configured
	// 未配置字号时，紧凑文本随面板高度缩放
	readonly property bool autoCompactFontSize: root.configNumber(plasmoid.configuration.fontPointSize, 0) <= 0



	// Keep compact text sizes consistent and convert point size using screen density when needed
	// 保持紧凑文本字号一致，必要时按屏幕密度换算 pointSize
	readonly property int themeDefaultPixelSize: {
		const defaultFont = root.theme.defaultFont;
		if (defaultFont.pixelSize > 0) {
			return defaultFont.pixelSize;
		}
		const density = Screen.pixelDensity > 0 ? Screen.pixelDensity : 3.937;
		return Math.max(8, Math.round(defaultFont.pointSize / 72 * (density * 25.4)));
	}

	// Calculate one- or two-line text size from the panel item height
	// 根据面板条目高度计算单行或双行字号
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

	// Scale a font while preserving its pixel or point size unit
	// 按比例缩放字体，并保留像素或磅值单位
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

	// Prefer a custom time format, then 12/24-hour mode, then the system locale
	// 时间格式依次采用自定义值、12/24 小时制和系统设置
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



	// Share theme colors, fonts, and spacing with child components; derive accent variants here
	// 向子组件提供主题颜色、字体和间距，并在此计算强调色变体
	QtObject {
		id: themeAdapter

		// Font colors are bound to QPalette roles so the active color scheme stays authoritative
		// 字体颜色全部绑定到 QPalette 角色，由当前配色方案决定
		readonly property color textColor: root.palette.active.windowText
		readonly property color disabledTextColor: root.palette.disabled.windowText
		// QPalette has no semantic error role; use Breeze negative red
		// QPalette 没有语义错误色，使用 Breeze 负向红
		readonly property color negativeTextColor: "#da4453"
		readonly property font defaultFont: Kirigami.Theme.defaultFont
		readonly property int gridUnit: Kirigami.Units.gridUnit

		// QPalette::Accent is available since Qt 6.6; fall back to Highlight on older Qt
		// QPalette::Accent 从 Qt 6.6 起可用；旧版 Qt 回退到 Highlight
		readonly property color accentColor: root.palette.active.accent !== undefined
			? root.palette.active.accent
			: root.palette.active.highlight

		// Palette pairs HighlightedText with the accent, so no manual black/white choice is needed
		// 调色板为强调色成对提供 HighlightedText，无需再手工挑选黑白
		readonly property color accentTextColor: root.palette.active.highlightedText

		// WCAG sRGB luminance requires gamma correction to classify midtones correctly
		// WCAG sRGB 相对亮度需先伽马校正，避免中间调被误判
		function relativeLuminance(c) {
			const r = c.r <= 0.03928 ? c.r / 12.92 : Math.pow((c.r + 0.055) / 1.055, 2.4);
			const g = c.g <= 0.03928 ? c.g / 12.92 : Math.pow((c.g + 0.055) / 1.055, 2.4);
			const b = c.b <= 0.03928 ? c.b / 12.92 : Math.pow((c.b + 0.055) / 1.055, 2.4);
			return 0.2126 * r + 0.7152 * g + 0.0722 * b;
		}

		// Text luminance determines the hover-color direction
		// 根据文字明度决定悬停色的变化方向
		readonly property bool accentTextIsLight: themeAdapter.relativeLuminance(themeAdapter.accentTextColor) > 0.5

		// Move hover color away from the text color to preserve contrast
		// 悬停色向文字色反方向变化，以保持对比度
		readonly property color accentHoverColor: themeAdapter.accentTextIsLight
			? Qt.darker(themeAdapter.accentColor, 1.12)
			: Qt.lighter(themeAdapter.accentColor, 1.2)

		// Alpha variants blend with the panel without requiring its background color
		// 半透明变体由渲染层与面板背景合成，无需读取底色
		readonly property color accentSubtleColor: themeAdapter.accentAlpha(0.18)
		readonly property color accentMutedColor: themeAdapter.accentAlpha(0.4)

		// Return the accent color with the requested alpha
		// 返回指定透明度的强调色
		function accentAlpha(alpha) {
			const c = themeAdapter.accentColor;
			return Qt.rgba(c.r, c.g, c.b, alpha);
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

	// Clock and calendar remain available without MPRIS; mediaState: 0 = unchecked, 1 = available, -1 = unavailable
	// MPRIS 不可用时仍可使用时钟和日历；mediaState：0 = 未检测，1 = 可用，-1 = 不可用
	property int mediaState: 0
	property var mediaProvider: null

	readonly property string trackTitle: root.mediaProvider !== null ? root.mediaProvider.trackTitle : ""
	readonly property bool isPlaying: root.mediaProvider !== null && root.mediaProvider.playing

	// Notification failures do not affect other features; notificationsState: 0 = unchecked, 1 = available, -1 = unavailable
	// 通知服务故障不影响其他功能；notificationsState：0 = 未检测，1 = 可用，-1 = 不可用
	property int notificationsState: 0
	property var notificationsProvider: null

	readonly property bool hasNotifications: root.notificationsEnabled && root.notificationsProvider !== null && root.notificationsProvider.count > 0
	readonly property int unreadNotificationCount: root.notificationsEnabled && root.notificationsProvider !== null ? root.notificationsProvider.unreadCount : 0

	// Use the accent as the media background and shift it when paused
	// 媒体背景使用强调色，暂停时按主题明暗调整以作区分
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



	Component.onCompleted: {
		root.resolveMediaProvider();
		root.resolveNotificationsProvider();
	}




	// Load the media provider at runtime so failures leave other features available
	// 运行时加载媒体数据源，失败时保留其他功能
	function resolveMediaProvider() {
		if (root.mediaState !== 0) {
			return;
		}

		const component = Qt.createComponent("MprisProvider.qml");
		if (component.status === Component.Loading) {
			component.statusChanged.connect(function() {
				root.useMediaComponent(component);
			});
			return;
		}
		root.useMediaComponent(component);
	}

	function useMediaComponent(component) {
		if (component.status === Component.Error) {
			root.mediaState = -1;
			console.info("Sparkle Land: MPRIS 不可用，面板只显示时钟：", component.errorString());
			return;
		}
		if (component.status !== Component.Ready) {
			return;
		}

		const provider = component.createObject(root);
		if (!provider) {
			root.mediaState = -1;
			console.warn("Sparkle Land: MPRIS 组件实例化失败：", component.errorString());
			return;
		}

		root.mediaProvider = provider;
		root.mediaState = 1;
		console.info("Sparkle Land: 私有 MPRIS 实现已生效");
	}

	// Load notifications at runtime so failures leave the clock and calendar available
	// 运行时加载通知数据源，失败时保留时钟与日历
	function resolveNotificationsProvider() {
		if (root.notificationsState !== 0 || !root.notificationsEnabled) {
			return;
		}

		const component = Qt.createComponent("NotificationsProvider.qml");
		if (component.status === Component.Loading) {
			component.statusChanged.connect(function() {
				root.useNotificationsComponent(component);
			});
			return;
		}
		root.useNotificationsComponent(component);
	}

	function useNotificationsComponent(component) {
		if (component.status === Component.Error) {
			root.notificationsState = -1;
			console.info("Sparkle Land: 通知服务不可用：", component.errorString());
			return;
		}
		if (component.status !== Component.Ready) {
			return;
		}

		const provider = component.createObject(root, {
			"includeExpired": root.notificationsIncludeExpired,
			"maxVisible": root.notificationsMaxVisible
		});
		if (!provider) {
			root.notificationsState = -1;
			console.warn("Sparkle Land: 通知组件实例化失败：", component.errorString());
			return;
		}

		// Propagate config changes without reloading the applet
		// 配置变化时同步给数据源，无需重载小组件
		provider.includeExpired = Qt.binding(function() {
			return root.notificationsIncludeExpired;
		});
		provider.maxVisible = Qt.binding(function() {
			return root.notificationsMaxVisible;
		});

		// Initialize models here, not in bindings, to avoid loops from synchronous lazy-init signals
		// 在此初始化模型而非绑定中触碰，避免惰性初始化信号造成绑定循环
		provider.activate();

		root.notificationsProvider = provider;
		root.notificationsState = 1;
		console.info("Sparkle Land: 私有通知实现已生效");
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
			? root.safeMax(clockItem.implicitWidth, mediaItem.implicitWidth)
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
			radius: 4
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
			source: "music-note-16th"
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

		Rectangle {
			id: notificationBadge

			readonly property int displayCount: Math.min(99, root.unreadNotificationCount)

			anchors.right: parent.right
			anchors.rightMargin: 3
			anchors.verticalCenter: parent.verticalCenter
			// Over the media background the dot turns into the text color and the count takes the background color
			// 媒体背景显示时圆点改用文字色，计数文字改用背景色
			color: root.mediaBackgroundVisible ? root.theme.textColor : root.theme.accentColor
			height: Math.round(Math.max(16, parent.height * 0.55))
			radius: height / 2
			visible: root.notificationsEnabled && root.unreadNotificationCount > 0
			width: root.notificationsShowUnreadCount
				? Math.max(height, badgeLabel.implicitWidth + Math.round(height * 0.5))
				: height

			Text {
				id: badgeLabel

				anchors.centerIn: parent
				color: root.mediaBackgroundVisible ? root.mediaBackgroundColor : root.theme.accentTextColor
				font: root.fontWithPixelSize(root.panelFont, Math.max(8, Math.round(notificationBadge.height * 0.6)))
				text: notificationBadge.displayCount >= 99 ? "99+" : String(notificationBadge.displayCount)
				visible: root.notificationsShowUnreadCount
			}
		}

		// Plasma positions this banner beside the applet; declare it before MouseArea to preserve clicks
		// 横幅由 Plasma 锚定在小组件旁；置于 MouseArea 前以保留点击操作
		NotificationsPopup {
			appletExpanded: root.expanded
			displayTime: root.notificationsBannerTimeout * 1000
			panelLocation: root.panelLocation
			provider: root.notificationsProvider
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
		mediaControlsEnabled: root.mediaState === 1
		mediaProvider: root.mediaProvider
		notificationsProvider: root.notificationsProvider
		notificationsShowClearAll: root.notificationsShowClearAll
		notificationsShowDoNotDisturb: root.notificationsShowDoNotDisturb
		requestedDate: root.requestedDate
		textFont: root.panelFont
		theme: root.theme
		timeFormat: root.timeFormat

	}
}
