import QtQml
import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.plasmoid

// Applet 入口：协调时钟、媒体信息、日历及配置。
PlasmoidItem {
	id: root

	// Applet 元数据
	readonly property string appTitle: i18n("Sparkle Land")
	readonly property string appIconName: "preferences-desktop"

	// 将配置值归一化，避免缺省值参与尺寸计算时产生 NaN。
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
	// 通知功能默认开启；关闭后完全沿用原有布局。
	readonly property bool notificationsEnabled: plasmoid.configuration.notificationsEnabled !== false
	readonly property int notificationsMaxVisible: Math.max(0, root.configNumber(plasmoid.configuration.notificationsMaxVisible, 5))
	readonly property bool notificationsIncludeExpired: plasmoid.configuration.notificationsIncludeExpired === true
	readonly property bool notificationsShowDoNotDisturb: plasmoid.configuration.notificationsShowDoNotDisturb !== false
	readonly property bool notificationsShowClearAll: plasmoid.configuration.notificationsShowClearAll !== false
	// 自建横幅的开关与显示时长；横幅由 plasmashell 定位在本小组件旁。
	readonly property bool notificationsShowPopups: plasmoid.configuration.notificationsShowPopups !== false
	readonly property int notificationsBannerTimeout: Math.max(1, root.configNumber(plasmoid.configuration.notificationsBannerTimeout, 5))
	// 面板所在的屏幕边缘，供横幅决定弹出方向（取值同 Plasma::Types::Location）。
	readonly property int panelLocation: plasmoid.location
	readonly property bool showDate: plasmoid.configuration.showDate === true
	// 未设置字号时，紧凑条目字号随面板高度缩放。
	readonly property bool autoCompactFontSize: root.configNumber(plasmoid.configuration.fontPointSize, 0) <= 0

	// 紧凑条目字号在时间、日期和曲目间保持一致。
	// 主题默认字号的像素值；主题只提供 pointSize 时按屏幕密度换算。
	readonly property int themeDefaultPixelSize: {
		const defaultFont = root.theme.defaultFont;
		if (defaultFont.pixelSize > 0) {
			return defaultFont.pixelSize;
		}
		const density = Screen.pixelDensity > 0 ? Screen.pixelDensity : 3.937;
		return Math.max(8, Math.round(defaultFont.pointSize / 72 * (density * 25.4)));
	}

	// 根据面板条目高度计算单行或双行文字的字号。
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

	// 按比例缩放字体，同时保留源字体使用的字号单位。
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

	// 用文字颜色明度区分亮色与暗色主题。
	readonly property bool lightTheme: root.theme.textColor.hsvValue < 0.5

	// 时间格式优先使用自定义值，其次使用 12/24 小时制设置，最后跟随系统。
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

		// 跟随系统格式不显示秒。
		return Qt.locale().timeFormat(Locale.ShortFormat).replace(/:?s+/g, "");
	}

	readonly property string dateFormat: {
		const custom = root.configString(plasmoid.configuration.customDateFormat);
		return custom.length > 0 ? custom : Qt.locale().dateFormat(Locale.ShortFormat);
	}

	// 将主题所需的颜色、字体和间距集中提供给子组件。
	// 颜色获取规则：所有强调相关的颜色都由 Plasma 强调色派生，变体在本对象内自行计算；
	// 只有正文/次要文字与语义色仍取自配色方案，否则对比度与语义无法保证。
	QtObject {
		id: themeAdapter

		readonly property color textColor: Kirigami.Theme.textColor
		readonly property color disabledTextColor: Kirigami.Theme.disabledTextColor
		// 紧急通知的语义色（红），由配色方案提供，不能由强调色派生。
		readonly property color negativeTextColor: Kirigami.Theme.negativeTextColor
		readonly property font defaultFont: Kirigami.Theme.defaultFont
		readonly property int gridUnit: Kirigami.Units.gridUnit

		// ———————————————— 强调色及其变体 ————————————————
		// 强调色取自当前生效配色的 DecorationFocus：它就是系统设置里选定的强调色，
		// 而 Kirigami.Theme.highlightColor 是派生出的选中底色（被冲淡或加深过），并非强调色本身。
		readonly property color accentColor: Kirigami.Theme.focusColor

		// 变体一：强调色之上的文字/图标。优先采用配色方案为“选中背景”配好的文字色——
		// 它与强调色同源、对比度由方案保证；方案缺失时按对比度自行择取深浅。
		readonly property bool schemeTextOnAccentUsable: Kirigami.Theme.highlightedTextColor.a > 0
		readonly property color accentTextColor: themeAdapter.schemeTextOnAccentUsable
			? Kirigami.Theme.highlightedTextColor
			: (themeAdapter.accentNeedsLightText ? "#ffffff" : "#000000")

		// sRGB 相对亮度（WCAG）。必须先做伽马校正，否则中间调会被误判为深色。
		function relativeLuminance(c) {
			const r = c.r <= 0.03928 ? c.r / 12.92 : Math.pow((c.r + 0.055) / 1.055, 2.4);
			const g = c.g <= 0.03928 ? c.g / 12.92 : Math.pow((c.g + 0.055) / 1.055, 2.4);
			const b = c.b <= 0.03928 ? c.b / 12.92 : Math.pow((c.b + 0.055) / 1.055, 2.4);
			return 0.2126 * r + 0.7152 * g + 0.0722 * b;
		}

		// 亮度低于该值时浅色文字对比度更高（黑白文字对比度相等的分界点）。
		readonly property bool accentNeedsLightText: themeAdapter.relativeLuminance(themeAdapter.accentColor) < 0.179

		// 实际使用的文字色是否为浅色，决定悬停该往哪个方向偏移。
		readonly property bool accentTextIsLight: themeAdapter.relativeLuminance(themeAdapter.accentTextColor) > 0.5

		// 变体二：悬停。始终向背离文字色的方向偏移，保证悬停时对比度不降。
		readonly property color accentHoverColor: themeAdapter.accentTextIsLight
			? Qt.darker(themeAdapter.accentColor, 1.12)
			: Qt.lighter(themeAdapter.accentColor, 1.2)

		// 变体三、四：半透明。由渲染层与面板背景自行合成，无需知道面板底色。
		readonly property color accentSubtleColor: themeAdapter.accentAlpha(0.18)
		readonly property color accentMutedColor: themeAdapter.accentAlpha(0.4)

		// 强调色的任意透明度变体。
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

	// MPRIS 不可用时仍可使用时钟和日历。
	// mediaState: 0 = 未探测，1 = 可用，-1 = 不可用。
	property int mediaState: 0
	property var mediaProvider: null

	readonly property string trackTitle: root.mediaProvider !== null ? root.mediaProvider.trackTitle : ""
	readonly property bool isPlaying: root.mediaProvider !== null && root.mediaProvider.playing

	// 通知服务不可用时只影响通知区域，其余功能照常。
	// notificationsState: 0 = 未探测，1 = 可用，-1 = 不可用。
	property int notificationsState: 0
	property var notificationsProvider: null

	readonly property bool hasNotifications: root.notificationsEnabled && root.notificationsProvider !== null && root.notificationsProvider.count > 0
	readonly property int unreadNotificationCount: root.notificationsEnabled && root.notificationsProvider !== null ? root.notificationsProvider.unreadCount : 0

	// 有曲目时显示媒体背景，取自强调色；暂停时向主题明暗的反方向偏移以示区别。
	readonly property bool mediaBackgroundVisible: root.hasMedia && root.mediaUseThemeBackground
	readonly property color mediaBackgroundColor: {
		const base = root.theme.accentColor;
		return root.isPlaying ? base : (root.lightTheme ? Qt.lighter(base, 1.4) : Qt.darker(base, 1.4));
	}

	// 日历跳转目标。
	property date requestedDate

	// 有曲目时，展开面板显示媒体控制器。
	readonly property bool hasMedia: root.trackTitle.length > 0
	// 展开时紧凑条目显示时钟；否则有曲目时显示曲名。
	readonly property bool panelShowsMedia: root.hasMedia && !root.expanded

	Plasmoid.title: root.appTitle
	Plasmoid.icon: root.isPlaying ? "media-playback-start" : root.appIconName

	Component.onCompleted: {
		root.resolveMediaProvider();
		root.resolveNotificationsProvider();
	}

	// 运行时加载媒体实现，组件加载失败时保留其它功能。
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

	// 与媒体实现相同的加载方式：运行时加载，失败时保留时钟与日历。
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

		// 配置在运行时变化时同步给数据源，无需重载 applet。
		provider.includeExpired = Qt.binding(function() {
			return root.notificationsIncludeExpired;
		});
		provider.maxVisible = Qt.binding(function() {
			return root.notificationsMaxVisible;
		});

		// 唯一初始化入口：在这里（而不是绑定中）首次触碰 Server 单例与各通知模型，
		// 避免惰性初始化期间的同步信号造成绑定循环。
		provider.activate();

		root.notificationsProvider = provider;
		root.notificationsState = 1;
		console.info("Sparkle Land: 私有通知实现已生效");
	}

	// 展开日历，并跳转到指定日期；未指定时使用今天。
	function openCalendar(date) {
		const target = (date instanceof Date && !isNaN(date.getTime())) ? date : new Date();
		root.requestedDate = new Date(target.getFullYear(), target.getMonth(), target.getDate());
		root.expanded = true;
	}

	// 点击紧凑条目切换日历的展开状态。
	function toggleCalendar(date) {
		if (root.expanded) {
			root.expanded = false;
			return;
		}
		openCalendar(date);
	}

	// 面板紧凑表示。
	compactRepresentation: Item {
		id: compactItem

		readonly property int contentWidth: root.safeMax(clockItem.implicitWidth, mediaItem.implicitWidth)

		// 紧凑条目使用的主文字、日期和曲名字体。
		readonly property font primaryFont: root.autoCompactFontSize
			? root.fontWithPixelSize(root.panelFont, root.panelPixelSize(height, root.showDate))
			: root.panelFont
		readonly property font secondaryFont: root.autoCompactFontSize
			? root.fontWithPixelSize(root.panelFont, root.panelPixelSize(height, root.showDate) * 0.8)
			: root.fontScaled(root.panelFont, 0.8)
		readonly property font mediaTitleFont: root.autoCompactFontSize
			? root.fontWithPixelSize(root.panelFont, root.panelPixelSize(height, false))
			: root.panelFont

		// 未读角标占用的额外宽度，避免遮挡时间与曲名。
		readonly property int badgeSpace: notificationBadge.visible ? notificationBadge.width + 4 : 0

		// 媒体模式在平均宽度与最大宽度间选择；时钟模式按内容宽度限制在配置范围内。
		readonly property int preferredWidth: (root.hasMedia
			? (contentWidth > root.panelAverageWidth ? root.panelMaximumWidth : root.panelAverageWidth)
			: Math.max(root.panelMinimumWidth, Math.min(root.panelMaximumWidth, contentWidth))) + badgeSpace

		Layout.fillHeight: true
		Layout.minimumHeight: 32
		Layout.minimumWidth: root.panelMinimumWidth
		Layout.preferredHeight: 32
		Layout.preferredWidth: preferredWidth

		implicitHeight: 32
		implicitWidth: preferredWidth

		// 展开时仍保留媒体背景，作为曲目存在的提示。
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

		Clock {
			id: clockItem

			anchors.fill: parent
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

		// 未读通知提示：圆点背景加数字，位于紧凑条目右侧。
		Rectangle {
			id: notificationBadge

			readonly property int displayCount: Math.min(99, root.unreadNotificationCount)

			anchors.right: parent.right
			anchors.rightMargin: 3
			anchors.verticalCenter: parent.verticalCenter
			color: root.theme.accentColor
			height: Math.round(Math.max(14, parent.height * 0.42))
			radius: height / 2
			visible: root.notificationsEnabled && root.unreadNotificationCount > 0
			width: Math.max(height, badgeLabel.implicitWidth + Math.round(height * 0.5))

			Text {
				id: badgeLabel

				anchors.centerIn: parent
				color: root.theme.accentTextColor
				font: root.fontWithPixelSize(root.panelFont, Math.max(8, Math.round(notificationBadge.height * 0.62)))
				text: notificationBadge.displayCount >= 99 ? "99+" : String(notificationBadge.displayCount)
			}
		}

		// 通知横幅：由 plasmashell 定位在本小组件旁；声明在 MouseArea 之前以免影响点击。
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

	// 展开面板：日历与时钟或媒体控制器，有通知时预留通知区域。
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
