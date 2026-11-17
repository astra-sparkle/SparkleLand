import "style"
import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

// Expanded panel layout: calendar on the left, context-aware content on the right
// 展开面板布局：左侧为日历，右侧为随状态变化的内容
Item {
    id: root

    // Properties injected by the applet shell
    // 由小组件外壳注入的属性
    property var theme
    property font textFont
    property string timeFormat
    property date requestedDate

    // Calendar helpers shared with other month views
    // 与其他月历视图共用的辅助逻辑
    property var calendarShim

    property var mediaProvider
    property bool hasMedia: false
    property bool mediaControlsEnabled: true

    // Lyric provider and playback-page lyric switches
    // 歌词提供器与播放页歌词开关
    property var lyrics
    property bool showPlaybackLyrics: false
    // 0 = no secondary row, 1 = translation, 2 = romanisation
    // 0 = 无副行，1 = 译文，2 = 发音
    property int lyricsSecondaryMode: 0

    property var notificationsProvider
    property bool hasNotifications: false
    property bool notificationsShowDoNotDisturb: true
    property bool notificationsShowClearAll: true

    property bool appletExpanded: false

    readonly property string currentTrackTitle: root.mediaProvider !== null ? root.mediaProvider.trackTitle : ""
    // Lyrics replace the track title whenever the current track has any
    // 当前曲目存在歌词时，歌词取代曲名
    readonly property bool lyricsVisible: root.showPlaybackLyrics
        && root.lyrics !== null
        && root.lyrics !== undefined
        && root.lyrics.available
    readonly property real plasmaDefaultWidth: Kirigami.Units.iconSizes.sizeForLabels * 35
    readonly property real coverSize: Math.round(0.5 * Math.min(root.width, root.height))
    readonly property bool playing: root.mediaProvider !== null && root.mediaProvider.playing
    readonly property int indicatorHeight: Math.round(root.height * 0.08)

    // Scale the expanded clock font with panel height
    // 展开状态下的时钟字号随面板高度缩放
    readonly property font clockFont: Qt.font({
        "bold": true,
        "family": root.textFont.family,
        "pixelSize": Math.max(16, Math.round(root.height * 0.22))
    })

    implicitWidth: Math.round(root.plasmaDefaultWidth)

    Item {
        id: leftPane

        // When media consumes the right pane, notifications and calendar share the left pane
        // 当媒体占用右侧时，通知和日历共享左侧分页区域
        readonly property bool paged: root.hasMedia && root.hasNotifications
        readonly property int contentMargin: Math.round(root.height * 0.05)
        readonly property int pageCount: leftPane.paged ? 2 : 1
        // Page index: 0 = notifications, 1 = calendar
        // 页面索引：0 = 通知页，1 = 日历页
        property int currentPage: 0
        // Temporary drag offset measured in page units
        // 拖动时的临时偏移，单位为页
        property real dragOffset: 0

        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.top: parent.top
        width: parent.width / 2

        function showPage(index) {
            if (index >= 0 && index < leftPane.pageCount) {
                leftPane.currentPage = index;
            }
        }

        // Keep the pages side by side and translate the clipped row to switch
        // 两页并排放置，通过平移裁剪容器完成切换
        Item {
            id: pageViewport

            anchors.bottom: parent.bottom
            anchors.bottomMargin: leftPane.contentMargin + (leftPane.paged ? root.indicatorHeight : 0)
            anchors.left: parent.left
            anchors.leftMargin: leftPane.contentMargin
            anchors.right: parent.right
            anchors.rightMargin: leftPane.contentMargin
            anchors.top: parent.top
            anchors.topMargin: leftPane.contentMargin
            clip: true

            // Only take over horizontal drags beyond the threshold so page clicks keep working
            // 仅在超过阈值后接管横向拖动，保留页面内点击交互
            DragHandler {
                id: pageDrag

                enabled: leftPane.paged
                target: null
                xAxis.enabled: true
                yAxis.enabled: false

                onTranslationChanged: if (active) {
                    leftPane.dragOffset = pageDrag.translation.x / pageViewport.width;
                }
                onActiveChanged: if (!active) {
                    // Snap to the nearest page on release
                    // 松手后吸附到最近一页
                    const target = Math.round(leftPane.currentPage - leftPane.dragOffset);
                    leftPane.dragOffset = 0;
                    leftPane.showPage(target);
                }
            }

            Row {
                id: pages

                // Row position in pages equals the current page minus the drag offset
                // 行位置（页）等于当前页减去拖动偏移
                readonly property real position: leftPane.currentPage - leftPane.dragOffset

                height: pageViewport.height
                spacing: 0
                width: pageViewport.width * leftPane.pageCount
                x: -Math.round(pages.position * pageViewport.width)

                Behavior on x {
                    enabled: !pageDrag.active

                    NumberAnimation {
                        duration: Kirigami.Units.longDuration
                        easing.type: Easing.OutCubic
                    }
                }

                Notifications {
                    height: pageViewport.height
                    width: leftPane.paged ? pageViewport.width : 0

                    // Keep both pages instantiated for swiping; only the active page accepts input and marks notifications read
                    // 两页常驻以支持滑动，仅活动页接收操作并标记通知已读
                    readonly property bool isCurrent: leftPane.paged && leftPane.currentPage === 0

                    enabled: isCurrent
                    pageActive: isCurrent
                    provider: root.notificationsProvider
                    appletExpanded: root.appletExpanded
                    showClearAll: root.notificationsShowClearAll
                    showDoNotDisturb: root.notificationsShowDoNotDisturb
                    theme: root.theme
                    visible: leftPane.paged
                }

                CalendarView {
                    height: pageViewport.height
                    width: pageViewport.width

                    calendarShim: root.calendarShim
                    enabled: !leftPane.paged || leftPane.currentPage === 1
                    requestedDate: root.requestedDate
                    theme: root.theme
                }
            }
        }

        Indicators.PageIndicator {
            id: pageIndicator

            anchors.bottom: parent.bottom
            anchors.bottomMargin: Math.round(root.height * 0.015)
            anchors.horizontalCenter: parent.horizontalCenter
            count: leftPane.pageCount
            currentIndex: leftPane.currentPage
            dotSize: Math.round(root.height * 0.03)
            spacing: Math.round(root.height * 0.01)
            theme: root.theme
            visible: leftPane.paged

            onActivated: function(index) {
                leftPane.showPage(index);
            }
        }
    }

    Rectangle {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.verticalCenter
        color: root.theme.disabledTextColor
        height: Math.round(root.height * 0.95)
        width: 1
    }

    Item {
        id: rightPane

        // Notifications replace the clock when no media is playing
        // 无媒体播放时，通知会占用时钟的位置
        readonly property bool showsNotifications: !root.hasMedia && root.hasNotifications

        anchors.bottom: parent.bottom
        anchors.right: parent.right
        anchors.top: parent.top
        width: parent.width / 2

        Clock {
            anchors.centerIn: parent
            height: Math.round(parent.height * 0.4)
            theme: root.theme
            timeFont: root.clockFont
            timeFormat: root.timeFormat
            visible: !root.hasMedia && !rightPane.showsNotifications
            width: Math.round(parent.width * 0.9)
        }

        Notifications {
            anchors.fill: parent
            anchors.margins: Math.round(root.height * 0.05)
            enabled: visible
            provider: root.notificationsProvider
            appletExpanded: root.appletExpanded
            showClearAll: root.notificationsShowClearAll
            showDoNotDisturb: root.notificationsShowDoNotDisturb
            theme: root.theme
            visible: rightPane.showsNotifications
        }

        Item {
            id: mediaController

            anchors.fill: parent
            visible: root.hasMedia

            readonly property real gap: Math.round(root.height * 0.02)

            // The lyric rows need vertical room, so the cover shrinks and moves up
            // 歌词需要纵向空间，因此封面缩小并上移
            readonly property real artSize: root.lyricsVisible ? Math.round(root.coverSize * 0.6) : root.coverSize
            readonly property real artTopMargin: Math.round(root.height * (root.lyricsVisible ? 0.04 : 0.1))
            readonly property int lyricRows: root.lyricsSecondaryMode === 0 ? 3 : 4
            readonly property real lyricTop: coverBox.y + coverBox.height + mediaController.gap
            readonly property real lyricBottom: controlsRow.y - mediaController.gap
            // A lyric row holds up to the limit reported by the lyric provider; a longer
            // line is split by it, so the font only has to fit that many labels
            // 每行歌词最多容纳歌词提供器给出的全角字符数，更长的歌词由提供器切分，
            // 因此字号只需保证这些字符能横向排下
            readonly property int lyricMaxLabels: root.lyrics !== null && root.lyrics !== undefined
                && root.lyrics.lineUnitLimit > 0 ? root.lyrics.lineUnitLimit : 18
            readonly property real lyricWidth: Math.round(mediaController.width * 0.96)
            readonly property real lyricFontPixelSize: Math.max(9, Math.min(
                Math.round(root.height * 0.075),
                Math.floor(mediaController.lyricWidth / mediaController.lyricMaxLabels)))
            // The extra quarter label keeps exactly 18 labels on one line even when the
            // font advances a hair more than its pixel size
            // 额外的四分之一个字宽，保证字体步进略大于像素尺寸时 18 个全角字符仍不换行
            readonly property real lyricTextWidth: Math.round(Math.min(
                mediaController.lyricWidth,
                mediaController.lyricFontPixelSize * (mediaController.lyricMaxLabels + 0.25)))

            Item {
                id: coverBox

                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: parent.top
                anchors.topMargin: mediaController.artTopMargin
                height: mediaController.artSize
                width: mediaController.artSize

                readonly property int cornerRadius: Math.round(root.height * 0.06)

                CoverImage {
                    anchors.fill: parent
                    placeholderColor: root.theme.coverPlaceholderColor
                    radius: coverBox.cornerRadius
                    source: mediaController.visible && root.mediaProvider !== null ? root.mediaProvider.artUrl : ""
                }
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: coverBox.bottom
                anchors.topMargin: mediaController.gap
                height: Math.max(0, Math.round(controlsRow.y - (coverBox.y + coverBox.height) - mediaController.gap * 2))
                width: Math.round(mediaController.width * 0.88)

                color: root.theme.textColor
                elide: Text.ElideRight
                font: root.textFont
                horizontalAlignment: Text.AlignHCenter
                maximumLineCount: 2
                text: root.currentTrackTitle
                verticalAlignment: Text.AlignVCenter
                visible: !root.lyricsVisible
                wrapMode: Text.WordWrap
            }

            // Scrolling lyric replaces the track title while the track has lyrics
            // 曲目存在歌词时，滚动歌词控件取代曲名
            Lyrics.ScrollingLines {
                id: lyricScroller

                readonly property real availableHeight: mediaController.lyricBottom - mediaController.lyricTop

                currentIndex: root.lyrics !== null && root.lyrics !== undefined ? root.lyrics.currentIndex : -1
                lineFont: Qt.font({
                    "bold": true,
                    "family": root.textFont.family,
                    "pixelSize": Math.round(mediaController.lyricFontPixelSize)
                })
                inactiveLineFont: Qt.font({
                    "family": root.textFont.family,
                    "pixelSize": Math.max(8, Math.round(mediaController.lyricFontPixelSize * 0.78))
                })
                lines: root.lyrics !== null && root.lyrics !== undefined ? root.lyrics.lines : []
                secondaryFont: Qt.font({
                    "family": root.textFont.family,
                    "pixelSize": Math.max(8, Math.round(mediaController.lyricFontPixelSize * 0.75))
                })
                secondaryMode: root.lyricsSecondaryMode
                splitter: root.lyrics !== null && root.lyrics !== undefined ? root.lyrics.splitLine : null
                textWidth: mediaController.lyricTextWidth
                theme: root.theme
                visible: root.lyricsVisible
                width: mediaController.lyricWidth
                x: Math.round((mediaController.width - width) / 2)
                y: Math.round(mediaController.lyricTop + (availableHeight - height) / 2)
            }

            RowLayout {
                id: controlsRow

                readonly property real gapRatio: 0.05

                anchors.bottom: parent.bottom
                anchors.bottomMargin: Math.round(root.height * 0.05)
                anchors.horizontalCenter: parent.horizontalCenter
                enabled: root.mediaControlsEnabled
                height: Math.round((width - spacing * 2) / 3)
                opacity: root.mediaControlsEnabled ? 1 : 0.4
                spacing: Math.round(width * gapRatio)
                width: Math.round(mediaController.width * 0.6)

                Buttons.IconButton {
                    Layout.fillHeight: true
                    Layout.fillWidth: true
                    accessibleName: i18n("Previous track")
                    source: "media-skip-backward"
                    theme: root.theme
                    onClicked: if (root.mediaProvider !== null) {
                        root.mediaProvider.previous();
                    }
                }

                Buttons.IconButton {
                    Layout.fillHeight: true
                    Layout.fillWidth: true
                    accessibleName: root.playing ? i18n("Pause") : i18n("Play")
                    source: root.playing ? "media-playback-pause" : "media-playback-start"
                    theme: root.theme
                    onClicked: if (root.mediaProvider !== null) {
                        root.mediaProvider.togglePlaying();
                    }
                }

                Buttons.IconButton {
                    Layout.fillHeight: true
                    Layout.fillWidth: true
                    accessibleName: i18n("Next track")
                    source: "media-skip-forward"
                    theme: root.theme
                    onClicked: if (root.mediaProvider !== null) {
                        root.mediaProvider.next();
                    }
                }
            }
        }
    }
}
