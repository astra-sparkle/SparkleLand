import QtQuick
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import org.kde.kirigami as Kirigami



// 展开面板：左侧为日历，右侧根据媒体状态显示时钟或播放器。
// Expanded panel: calendar on the left, clock or player on the right.
Item {
    id: root

    // Injected from main.qml.
    // 由 main.qml 注入。
    property var theme
    property font textFont
    property string timeFormat
    property var mediaProvider
    property bool hasMedia: false
    property bool mediaControlsEnabled: true
    property var notificationsProvider
    property bool hasNotifications: false
    property bool notificationsShowDoNotDisturb: true
    property bool notificationsShowClearAll: true
    property date requestedDate
    readonly property string currentTrackTitle: root.mediaProvider !== null ? root.mediaProvider.trackTitle : ""

    // Panel sizing.
    // 面板大小。
    readonly property real plasmaDefaultWidth: Kirigami.Units.iconSizes.sizeForLabels * 35

    implicitWidth: Math.round(root.plasmaDefaultWidth)

    // Album-art size follows the available panel space.
    // 专辑封面大小随面板可用空间缩放。
    readonly property real coverSize: Math.round(0.5 * Math.min(root.width, root.height))

    // Expanded-panel clock font scales with panel height.
    // 展开面板时钟字号按面板高度缩放。
    readonly property font clockFont: Qt.font({
        "bold": true,
        "family": root.textFont.family,
        "pixelSize": Math.max(16, Math.round(root.height * 0.22))
    })

    readonly property bool playing: root.mediaProvider !== null && root.mediaProvider.playing

    // 页码指示器需要预留的高度：圆点本身加上下各一圈命中余量。
    readonly property int indicatorHeight: Math.round(root.height * 0.08)



    // Left pane for calendar and notifications.
    Item { // Switch between notifications and calendar when both are enabled.
        id: leftPane

        // 有媒体时右半被播放器占用，通知改到左半与日历分页显示。
        readonly property bool paged: root.hasMedia && root.hasNotifications
        readonly property int contentMargin: Math.round(root.height * 0.05)
        // 页数：只有一页时既不需要切换也不需要指示器。
        readonly property int pageCount: leftPane.paged ? 2 : 1
        // 0 = 通知页，1 = 日历页。
        property int currentPage: 0
        // 拖动过程中的临时位移，单位同样是“页”。
        property real dragOffset: 0

        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.top: parent.top
        width: parent.width / 2

        // 切页；越界时保持不变。
        function showPage(index) {
            if (index >= 0 && index < leftPane.pageCount) {
                leftPane.currentPage = index;
            }
        }

        // 分页视口：两页并排放在同一行里，整行左右平移完成切换，超出部分被裁掉。
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

            // 左右拖动切页：横向拖动超过阈值才接管，因此不影响页面内的点击。
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
                    // 松手后吸附到最近的一页。
                    const target = Math.round(leftPane.currentPage - leftPane.dragOffset);
                    leftPane.dragOffset = 0;
                    leftPane.showPage(target);
                }
            }

            Row {
                id: pages

                // 整行的位置（单位：页）= 当前页减去拖动偏移。
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

                Notifications { // 通知页：只在分页时出现在左半，否则在右半显示。
                    height: pageViewport.height
                    width: leftPane.paged ? pageViewport.width : 0

                    // 分页时两页都常驻以便滑动，但只有轮到自己时才接受操作、标记已读。
                    readonly property bool isCurrent: leftPane.paged && leftPane.currentPage === 0

                    enabled: isCurrent
                    pageActive: isCurrent
                    provider: root.notificationsProvider
                    showClearAll: root.notificationsShowClearAll
                    showDoNotDisturb: root.notificationsShowDoNotDisturb
                    theme: root.theme
                    visible: leftPane.paged
                }

                Calender { // 日历页。
                    height: pageViewport.height
                    width: pageViewport.width

                    enabled: !leftPane.paged || leftPane.currentPage === 1
                    requestedDate: root.requestedDate
                    theme: root.theme
                }
            }
        }

        // 页码指示器：点击切页，当前页用拉长的胶囊表示。
        Row {
            id: pageIndicator

            readonly property int dotSize: Math.round(root.height * 0.03)
            // 命中区域比圆点大一圈，便于点击。
            readonly property int hitPadding: Math.round(pageIndicator.dotSize * 0.6)

            anchors.bottom: parent.bottom
            anchors.bottomMargin: Math.round(root.height * 0.015)
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: Math.round(root.height * 0.01)
            visible: leftPane.paged

            Repeater {
                model: leftPane.pageCount

                delegate: Item {
                    required property int index

                    readonly property bool current: leftPane.currentPage === index
                    readonly property int currentWidth: Math.round(pageIndicator.dotSize * 2.6)

                    height: pageIndicator.dotSize + pageIndicator.hitPadding * 2
                    width: (current ? currentWidth : pageIndicator.dotSize) + pageIndicator.hitPadding * 2

                    Rectangle {
                        anchors.centerIn: parent
                        color: current ? root.theme.accentColor : root.theme.accentMutedColor
                        height: pageIndicator.dotSize
                        opacity: pageMouse.containsMouse ? 1 : 0.85
                        radius: height / 2
                        width: current ? currentWidth : pageIndicator.dotSize

                        Behavior on color {
                            ColorAnimation {
                                duration: Kirigami.Units.shortDuration
                            }
                        }

                        Behavior on width {
                            NumberAnimation {
                                duration: Kirigami.Units.shortDuration
                                easing.type: Easing.OutCubic
                            }
                        }
                    }

                    MouseArea {
                        id: pageMouse

                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: leftPane.showPage(index)
                    }
                }
            }
        }
    }



    // Divider between the two panes.
    // 两个面板之间的分隔线。
    Rectangle { // Divider.
    // 分隔线。
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.verticalCenter
        color: root.theme.disabledTextColor
        height: Math.round(root.height * 0.95)
        width: 1
    }




    // Right pane for clock, media controls or notifications.
    Item { // Show notifications when there is no media; otherwise clock or controls.
        id: rightPane

        // 无媒体播放且有通知时，通知占用时钟的位置。
        readonly property bool showsNotifications: !root.hasMedia && root.hasNotifications

        anchors.bottom: parent.bottom
        anchors.right: parent.right
        anchors.top: parent.top
        width: parent.width / 2

        // ———— 无媒体且无通知：时钟 ————
        Clock {
            anchors.centerIn: parent
            height: Math.round(parent.height * 0.4)
            theme: root.theme
            timeFont: root.clockFont
            timeFormat: root.timeFormat
            visible: !root.hasMedia && !rightPane.showsNotifications
            width: Math.round(parent.width * 0.9)
        }

        // ———— 无媒体：通知 ————
        Notifications {
            anchors.fill: parent
            anchors.margins: Math.round(root.height * 0.05)
            enabled: visible
            provider: root.notificationsProvider
            showClearAll: root.notificationsShowClearAll
            showDoNotDisturb: root.notificationsShowDoNotDisturb
            theme: root.theme
            visible: rightPane.showsNotifications
        }

        // ———— 有媒体：媒体控制器 ————
        Item {
            id: mediaController

            anchors.fill: parent
            visible: root.hasMedia

            readonly property real gap: Math.round(root.height * 0.02)

            // 专辑封面，缺失时显示占位图形。
            Item {
                id: coverBox

                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: parent.top
                anchors.topMargin: Math.round(root.height * 0.1)
                height: root.coverSize
                width: root.coverSize

                readonly property int cornerRadius: Math.round(root.height * 0.06)

                Image {
                    id: coverImage

                    anchors.fill: parent
                    fillMode: Image.PreserveAspectCrop
                    source: root.mediaProvider !== null ? root.mediaProvider.artUrl : ""
                    visible: source != "" && status === Image.Ready

                    layer.enabled: visible
                    layer.textureSize: Qt.size(width * Screen.devicePixelRatio, height * Screen.devicePixelRatio)
                    layer.effect: OpacityMask {
                        maskSource: Item {
                            width: coverImage.width
                            height: coverImage.height

                            Rectangle {
                                anchors.fill: parent
                                radius: coverBox.cornerRadius
                            }
                        }
                    }
                }

                Rectangle {
                    anchors.fill: parent
                    color: root.theme.disabledTextColor
                    opacity: 0.25
                    radius: coverBox.cornerRadius
                    visible: !coverImage.visible
                }
            }

            // Track title.
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
                wrapMode: Text.WordWrap
            }

            // 上一曲、播放/暂停、下一曲。
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

                Media.MediaControlButton {
                    Layout.fillHeight: true
                    Layout.fillWidth: true
                    source: "media-skip-backward"
                    theme: root.theme
                    onClicked: if (root.mediaProvider !== null) {
                        root.mediaProvider.previous();
                    }
                }

                Media.MediaControlButton {
                    Layout.fillHeight: true
                    Layout.fillWidth: true
                    source: root.playing ? "media-playback-pause" : "media-playback-start"
                    theme: root.theme
                    onClicked: if (root.mediaProvider !== null) {
                        root.mediaProvider.togglePlaying();
                    }
                }

                Media.MediaControlButton {
                    Layout.fillHeight: true
                    Layout.fillWidth: true
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
