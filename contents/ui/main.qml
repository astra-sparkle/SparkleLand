import QtQml
import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.plasmoid

PlasmoidItem {
	id: root

	readonly property string appTitle: i18n("Sparkle Land")
	readonly property string appIconName: "preferences-desktop"

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
	readonly property bool showDate: plasmoid.configuration.showDate === true
	readonly property bool autoCompactFontSize: root.configNumber(plasmoid.configuration.fontPointSize, 0) <= 0

	// 主题字体只有 pointSize 时换算为像素值。
	readonly property int themeDefaultPixelSize: {
		const defaultFont = root.theme.defaultFont;
		if (defaultFont.pixelSize > 0) {
			return defaultFont.pixelSize;
		}
		const density = Screen.pixelDensity > 0 ? Screen.pixelDensity : 3.937;
		return Math.max(8, Math.round(defaultFont.pointSize / 72 * (density * 25.4)));
	}

	// twoLines 表示时间与日期共用面板厚度。
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

	readonly property bool lightTheme: root.theme.textColor.hsvValue < 0.5

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

		return Qt.locale().timeFormat(Locale.ShortFormat).replace(/:?s+/g, "");
	}

	readonly property string dateFormat: {
		const custom = root.configString(plasmoid.configuration.customDateFormat);
		return custom.length > 0 ? custom : Qt.locale().dateFormat(Locale.ShortFormat);
	}

	QtObject {
		id: themeAdapter

		readonly property color textColor: Kirigami.Theme.textColor
		readonly property color disabledTextColor: Kirigami.Theme.disabledTextColor
		readonly property color highlightColor: Kirigami.Theme.highlightColor
		readonly property color highlightedTextColor: Kirigami.Theme.highlightedTextColor
		readonly property color hoverColor: Kirigami.Theme.hoverColor
		readonly property font defaultFont: Kirigami.Theme.defaultFont
		readonly property int gridUnit: Kirigami.Units.gridUnit
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

	// MPRIS 不可用时只显示时钟。
	property var mediaProvider: null

	readonly property string trackTitle: root.mediaProvider !== null ? root.mediaProvider.trackTitle : ""
	readonly property bool isPlaying: root.mediaProvider !== null && root.mediaProvider.playing

	// 展开时紧凑条目显示时钟，仍保留媒体提示底色。
	readonly property bool mediaBackgroundVisible: root.hasMedia && root.mediaUseThemeBackground
	readonly property color mediaBackgroundColor: {
		const base = root.theme.highlightColor;
		return root.isPlaying ? base : (root.lightTheme ? Qt.lighter(base, 1.4) : Qt.darker(base, 1.4));
	}

	property date requestedDate

	readonly property bool hasMedia: root.trackTitle.length > 0
	readonly property bool panelShowsMedia: root.hasMedia && !root.expanded

	Plasmoid.title: root.appTitle
	Plasmoid.icon: root.isPlaying ? "media-playback-start" : root.appIconName
	Component.onCompleted: {
		root.resolveMediaProvider();
	}

	function resolveMediaProvider() {
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
			console.warn("Sparkle Land: MPRIS 不可用，面板只显示时钟：", component.errorString());
			return;
		}
		if (component.status !== Component.Ready) {
			return;
		}

		const provider = component.createObject(root);
		if (!provider) {
			console.warn("Sparkle Land: MPRIS 组件实例化失败：", component.errorString());
			return;
		}

		root.mediaProvider = provider;
	}

	function openCalendar() {
		const today = new Date();
		root.requestedDate = new Date(today.getFullYear(), today.getMonth(), today.getDate());
		root.expanded = true;
	}

	function toggleCalendar() {
		if (root.expanded) {
			root.expanded = false;
			return;
		}
		openCalendar();
	}

	compactRepresentation: Item {
		id: compactItem

		readonly property int contentWidth: root.safeMax(clockItem.implicitWidth, mediaItem.implicitWidth)

		readonly property font primaryFont: root.autoCompactFontSize
			? root.fontWithPixelSize(root.panelFont, root.panelPixelSize(height, root.showDate))
			: root.panelFont
		readonly property font secondaryFont: root.autoCompactFontSize
			? root.fontWithPixelSize(root.panelFont, root.panelPixelSize(height, root.showDate) * 0.8)
			: root.fontScaled(root.panelFont, 0.8)
		readonly property font mediaTitleFont: root.autoCompactFontSize
			? root.fontWithPixelSize(root.panelFont, root.panelPixelSize(height, false))
			: root.panelFont

		// 媒体按平均/最大宽度显示，时钟按配置范围约束内容宽度。
		readonly property int preferredWidth: root.hasMedia
			? (contentWidth > root.panelAverageWidth ? root.panelMaximumWidth : root.panelAverageWidth)
			: Math.max(root.panelMinimumWidth, Math.min(root.panelMaximumWidth, contentWidth))

		// Plasma 面板条目通过 Layout 尺寸参与布局。
		Layout.fillHeight: true
		Layout.minimumHeight: 32
		Layout.minimumWidth: root.panelMinimumWidth
		Layout.preferredHeight: 32
		Layout.preferredWidth: preferredWidth

		implicitHeight: 32
		implicitWidth: preferredWidth

		Rectangle {
			anchors.fill: parent
			color: root.mediaBackgroundColor
			radius: 4
			visible: root.mediaBackgroundVisible
		}

		Media {
			id: mediaItem

			anchors.fill: parent
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
			dateFont: compactItem.secondaryFont
			dateFormat: root.dateFormat
			showDate: root.showDate
			theme: root.theme
			timeFont: compactItem.primaryFont
			timeFormat: root.timeFormat
			visible: !root.panelShowsMedia
		}

		MouseArea {
			anchors.fill: parent
			onClicked: root.toggleCalendar()
		}
	}

	fullRepresentation: Panel {
		hasMedia: root.hasMedia
		mediaProvider: root.mediaProvider
		requestedDate: root.requestedDate
		textFont: root.panelFont
		theme: root.theme
		timeFormat: root.timeFormat
	}
}
