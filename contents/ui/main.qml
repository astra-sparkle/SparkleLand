import QtQml
import QtQuick
import QtQuick.Layouts
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.plasmoid

// 工程入口：与系统的交互、可选依赖的探测与降级、以及所有对外调用都在这里。
// 功能实现：Clock.qml（时钟）、Media.qml（媒体，仅显示）、Calender.qml（内置日历回退）。
// 设置界面：contents/config/config.qml + contents/config/option.qml，键定义在 main.xml。
//
// 本地化：面向用户的字符串一律走 i18n。KDE 的翻译上下文在会话建立时固定，
// 因此这些字符串「每次登入 DE 时」生效一次，运行期不做语言热切换。
PlasmoidItem {
	id: root

	// ———————————————— 元数据（原 WidgetMetadata.qml 并入）————————————————
	readonly property string appTitle: i18n("Sparkle Land")
	readonly property string appIconName: "preferences-desktop"
	readonly property string appDescription: i18n("View everything in one panel.")
	readonly property string appFooter: i18n("Plasma 6 widget")

	// ———————————————— 用户设置（KConfig，见 contents/config/main.xml）————————————————
	// 全部以 plasmoid.configuration 为数据源：启动时读一次，保存设置时自动重新求值。
	readonly property int panelMinimumWidth: Math.max(16, plasmoid.configuration.minimumPanelWidth)
	readonly property int panelMaximumWidth: Math.max(root.panelMinimumWidth, plasmoid.configuration.maximumPanelWidth)
	readonly property int panelAverageWidth: Math.round((root.panelMinimumWidth + root.panelMaximumWidth) / 2)
	readonly property bool mediaUseThemeBackground: plasmoid.configuration.mediaUseThemeBackground
	readonly property bool showDate: plasmoid.configuration.showDate

	// 时间格式：优先「用户保存的自定义格式」，其次 12/24 小时制，最后跟随系统。
	readonly property string timeFormat: {
		if (plasmoid.configuration.customTimeFormat.length > 0) {
			return plasmoid.configuration.customTimeFormat;
		}
		if (plasmoid.configuration.timeFormatMode === 1) {
			return "h:mm AP";
		}
		if (plasmoid.configuration.timeFormatMode === 2) {
			return "HH:mm";
		}
		// 跟随系统：去掉秒，保持每分钟刷新一次
		return Qt.locale().timeFormat(Locale.ShortFormat).replace(/:?s+/g, "");
	}

	readonly property string dateFormat: plasmoid.configuration.customDateFormat.length > 0
		? plasmoid.configuration.customDateFormat
		: Qt.locale().dateFormat(Locale.ShortFormat)

	// ———————————————— 主题：优先 Kirigami.Theme，失败回退 PlasmaCore.Theme ————————————————
	// 回退实现是声明式的，保证 theme 永远有效；Kirigami 版本在启动时尝试创建，失败就继续用回退。
	QtObject {
		id: plasmaTheme

		readonly property color textColor: PlasmaCore.Theme.textColor
		readonly property color disabledTextColor: PlasmaCore.Theme.disabledTextColor
		readonly property color highlightColor: PlasmaCore.Theme.highlightColor
		readonly property color highlightedTextColor: PlasmaCore.Theme.highlightedTextColor
		// PlasmaCore.Theme 没有 hoverColor，对应的是 viewHoverColor
		readonly property color hoverColor: PlasmaCore.Theme.viewHoverColor
		readonly property font defaultFont: Qt.application.font
		readonly property int gridUnit: Math.max(16, Math.round(Qt.application.font.pointSize * 1.6))
	}

	property var kirigamiTheme: null
	readonly property var theme: root.kirigamiTheme !== null ? root.kirigamiTheme : plasmaTheme

	// 面板字体：未自定义时跟随主题默认字体
	readonly property font panelFont: Qt.font({
		"bold": plasmoid.configuration.fontBold,
		"family": plasmoid.configuration.fontFamily.length > 0
			? plasmoid.configuration.fontFamily
			: root.theme.defaultFont.family,
		"italic": plasmoid.configuration.fontItalic,
		"pointSize": plasmoid.configuration.fontPointSize > 0
			? plasmoid.configuration.fontPointSize
			: root.theme.defaultFont.pointSize
	})

	readonly property font titleFont: Qt.font({
		"bold": true,
		"family": root.theme.defaultFont.family,
		"pointSize": Math.round(root.theme.defaultFont.pointSize * 1.5)
	})

	// ———————————————— 可选依赖 1：媒体信息（MPRIS）————————————————
	// 媒体是可选依赖：按顺序尝试下面的候选实现，第一个成功加载的生效；
	// 全部失败则面板只显示时钟（不报错、也不影响其它功能）。
	//
	// 每个候选都是一个**独立的 QML 文件**，因此可以用静态 import —— 这是本机已验证可行的
	// 方式（第三方插件 plasmusic-toolbar 就是静态 import 同一个模块）。某个模块缺失时该文件
	// 加载失败，由这里的候选机制捕获、打印真实原因，并继续尝试下一个。
	// 已核实本机存在 org.kde.plasma.private.mpris → 候选 1 就是生效路径。
	//
	// 刻意不「判断 Plasma 版本」：QML 拿不到可靠的版本号，按能力探测不会因版本升级误判。
	// mediaState: 0 = 尚未探测，1..N = 第 N 个候选生效，-1 = 全部不可用
	readonly property var mediaProviderSources: [
		"MprisProvider.qml",
		"MprisDataEngineProvider.qml"
	]
	property int mediaState: 0
	property var mediaProvider: null

	readonly property string trackTitle: root.mediaProvider !== null ? root.mediaProvider.trackTitle : ""
	readonly property bool isPlaying: root.mediaProvider !== null && root.mediaProvider.playing

	// ———————————————— 日历 ————————————————
	// 已核实（2026-09，查看 $QML_IMPORT_PATH/org/kde/plasma/private/）：本机有 digitalclock
	// 与 mpris，**没有 calendar**，且 digitalclock 也没有导出任何日历类型。
	// 也就是说不存在任何可复用的 Plasma 日历接口 → 直接用内置 Calender.qml 作为唯一实现。
	//
	// 日历入口
	property date selectedDate: new Date()
	property date requestedDate

	// 面板显示内容判断：有曲目信息就显示媒体名，否则显示时钟
	readonly property bool panelShowsMedia: root.trackTitle.length > 0

	Plasmoid.title: root.appTitle
	Plasmoid.icon: root.isPlaying ? "media-playback-start" : root.appIconName
	// 不要设置 Plasmoid.toolTipMainText / Plasmoid.toolTipSubText：
	// KF6 的 Plasma::Applet 已移除这组属性（源码里留着 TODO KF6 的
	// "toolTipMainText toolTipSubText toolTipTextFormat toolTipItem" 待办），
	// 赋值会报 "Cannot assign to non-existent property" 并导致整个卡片加载失败。
	// 不设置时 Plasma 用 metadata.json 的 Name / Description 生成默认提示气泡，
	// 内容与这里原本要设置的值一致，因此没有任何视觉损失。

	Component.onCompleted: {
		root.resolveTheme();
		root.resolveMediaProvider();
	}

	// ———————————————— 主题解析 ————————————————
	// 用字符串 + try/catch 做可选依赖：import 只在运行时求值，
	// 因此 org.kde.kirigami 缺失或出错都不会影响本文件加载。
	function resolveTheme() {
		if (root.kirigamiTheme !== null) {
			return;
		}

		const source = [
			"import QtQml",
			"import QtQuick",
			"import org.kde.kirigami as Kirigami",
			"QtObject {",
			"    readonly property color textColor: Kirigami.Theme.textColor",
			"    readonly property color disabledTextColor: Kirigami.Theme.disabledTextColor",
			"    readonly property color highlightColor: Kirigami.Theme.highlightColor",
			"    readonly property color highlightedTextColor: Kirigami.Theme.highlightedTextColor",
			"    readonly property color hoverColor: Kirigami.Theme.hoverColor",
			"    readonly property font defaultFont: Kirigami.Theme.defaultFont",
			"    readonly property int gridUnit: Kirigami.Units.gridUnit",
			"}"
		].join("\n");

		let resolved = null;
		try {
			resolved = Qt.createQmlObject(source, root, "kirigamiTheme");
		} catch (error) {
			resolved = null;
			console.info("Sparkle Land: Kirigami 主题不可用，回退到 PlasmaCore.Theme。", error);
		}

		if (resolved) {
			root.kirigamiTheme = resolved;
		}
	}

	// ———————————————— 媒体实现：候选加载 ————————————————
	// 候选文件用静态 import（见文件内的说明），加载失败时 Loader 机制会拿到确切原因。
	function resolveMediaProvider() {
		if (root.mediaState === 0) {
			root.tryMediaProviderSource(0);
		}
	}

	// 逐个尝试候选；失败时打印**真实原因**，不做静默降级
	function tryMediaProviderSource(index) {
		if (index >= root.mediaProviderSources.length) {
			root.mediaState = -1;
			console.info("Sparkle Land: 没有可用的 MPRIS2 实现，面板只显示时钟。");
			return;
		}

		const component = Qt.createComponent(root.mediaProviderSources[index]);
		if (component.status === Component.Loading) {
			component.statusChanged.connect(function() {
				root.useMediaComponent(component, index);
			});
			return;
		}
		root.useMediaComponent(component, index);
	}

	function useMediaComponent(component, index) {
		const source = root.mediaProviderSources[index];

		if (component.status === Component.Error) {
			console.warn("Sparkle Land: 媒体候选", source, "加载失败：", component.errorString());
			root.tryMediaProviderSource(index + 1);
			return;
		}
		if (component.status !== Component.Ready) {
			return;
		}

		const provider = component.createObject(root);
		if (!provider) {
			console.warn("Sparkle Land: 媒体候选", source, "实例化失败：", component.errorString());
			root.tryMediaProviderSource(index + 1);
			return;
		}

		root.mediaProvider = provider;
		root.mediaState = index + 1;
		console.info("Sparkle Land: 媒体候选", source, "已生效");
	}

	// 展开完整视图（日历所在位置），并定位到指定日期（缺省为今天）
	function openCalendar(date) {
		const target = (date instanceof Date && !isNaN(date.getTime())) ? date : new Date();
		root.requestedDate = new Date(target.getFullYear(), target.getMonth(), target.getDate());
		root.expanded = true;
	}

	// 紧凑表示被点击：展开查看日历，再次点击收起
	function toggleCalendar(date) {
		if (root.expanded) {
			root.expanded = false;
			return;
		}
		openCalendar(date);
	}

	// ———————————————— 面板（紧凑表示）————————————————
	compactRepresentation: Item {
		// 两块内容的自然宽度取最大，避免切换时抖动
		readonly property int contentWidth: Math.max(clockItem.implicitWidth, mediaItem.implicitWidth)

		implicitHeight: 32
		// 媒体：内容不超过平均值时申请平均值，超过平均值就直接申请最大值；
		// 时钟：内容夹在 [最小, 最大] 之间。两种情况都不小于最小宽度。
		implicitWidth: root.panelShowsMedia
			? (contentWidth > root.panelAverageWidth ? root.panelMaximumWidth : root.panelAverageWidth)
			: Math.max(root.panelMinimumWidth, Math.min(root.panelMaximumWidth, contentWidth))

		Media {
			id: mediaItem

			anchors.fill: parent
			enabled: visible
			panelFont: root.panelFont
			playing: root.isPlaying
			theme: root.theme
			title: root.trackTitle
			useThemeBackground: root.mediaUseThemeBackground
			visible: root.panelShowsMedia
		}

		Clock {
			id: clockItem

			anchors.fill: parent
			dateFormat: root.dateFormat
			enabled: visible
			panelFont: root.panelFont
			showDate: root.showDate
			theme: root.theme
			timeFormat: root.timeFormat
			visible: !root.panelShowsMedia
		}

		// 入口：点击面板只做「打开完整视图」这一件事，不含任何媒体控制
		MouseArea {
			anchors.fill: parent
			onClicked: root.toggleCalendar()
		}
	}

	// ———————————————— 完整视图：标题 + 日历 + 页脚 ————————————————
	fullRepresentation: Item {
		// 高度由内容决定，避免写死高度导致日历被裁掉
		implicitHeight: contentColumn.implicitHeight + 32
		implicitWidth: Math.max(360, contentColumn.implicitWidth + 32)

		ColumnLayout {
			id: contentColumn

			anchors.fill: parent
			anchors.margins: 16
			spacing: 8

			Text {
				Layout.fillWidth: true
				color: root.theme.textColor
				font: root.titleFont
				text: root.appTitle
			}

			Text {
				Layout.fillWidth: true
				color: root.theme.disabledTextColor
				font: root.theme.defaultFont
				text: root.appDescription
				wrapMode: Text.WordWrap
			}

			// 内置日历：完整视图本身就是按需创建的，所以这里不需要再套惰性化
			Calender {
				Layout.fillHeight: true
				Layout.fillWidth: true

				onDateSelected: root.selectedDate = date
				requestedDate: root.requestedDate
				theme: root.theme
			}

			Text {
				Layout.fillWidth: true
				color: root.theme.disabledTextColor
				font: root.theme.defaultFont
				horizontalAlignment: Text.AlignRight
				text: root.appFooter
			}
		}
	}
}
