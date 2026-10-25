import QtQuick
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import org.kde.kirigami as Kirigami



// Expanded panel with a calendar on the left and context-dependent content on the right
// 展开面板左侧显示日历，右侧内容根据当前状态变化
Item {
    id: root

    // Properties injected by main.qml
    // 由 main.qml 注入的属性
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
    // Whether the applet popup is open; the panel item also exists while collapsed
    // 小组件弹出面板是否已展开；面板项在折叠时也存在
    property bool appletExpanded: false
    property date requestedDate
    readonly property string currentTrackTitle: root.mediaProvider !== null ? root.mediaProvider.trackTitle : ""

    readonly property real plasmaDefaultWidth: Kirigami.Units.iconSizes.sizeForLabels * 35

    implicitWidth: Math.round(root.plasmaDefaultWidth)

    // Scale album artwork with the available panel space
    // 专辑封面大小随面板可用空间缩放
    readonly property real coverSize: Math.round(0.5 * Math.min(root.width, root.height))

    // Scale the expanded-panel clock font with panel height
    // 展开面板时钟字号随面板高度缩放
    readonly property font clockFont: Qt.font({
        "bold": true,
        "family": root.textFont.family,
        "pixelSize": Math.max(16, Math.round(root.height * 0.22))
    })

    readonly property bool playing: root.mediaProvider !== null && root.mediaProvider.playing

    // Height reserved for the page indicator and its hit area
    // 为页码指示器及其点击区域预留的高度
    readonly property int indicatorHeight: Math.round(root.height * 0.08)



    Item {
        id: leftPane

        // When media uses the right pane, notifications share the left pane with the calendar
        // 媒体占用右侧时，通知与日历在左侧分页显示
        readonly property bool paged: root.hasMedia && root.hasNotifications
        readonly property int contentMargin: Math.round(root.height * 0.05)
        readonly property int pageCount: leftPane.paged ? 2 : 1
        // Page index: 0 = notifications, 1 = calendar
        // 页面索引：0 = 通知页，1 = 日历页
        property int currentPage: 0
        // Temporary drag offset measured in pages
        // 拖动中的临时位移，单位为页
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

        // Place pages side by side and translate the clipped row to switch
        // 两页并排放置，通过平移裁剪行完成切换
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

            // Take over horizontal drags only past the threshold so page clicks still work
            // 仅接管超过阈值的横向拖动，以保留页面内点击
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

                // Row position in pages = current page minus drag offset
                // 行位置（页）= 当前页减去拖动偏移
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

                Calender {
                    height: pageViewport.height
                    width: pageViewport.width

                    enabled: !leftPane.paged || leftPane.currentPage === 1
                    requestedDate: root.requestedDate
                    theme: root.theme
                }
            }
        }

        Row {
            id: pageIndicator

            readonly property int dotSize: Math.round(root.height * 0.03)
            readonly property int hitPadding: Math.round(pageIndicator.dotSize * 0.6)

            anchors.bottom: parent.bottom
            anchors.bottomMargin: Math.round(root.height * 0.015)
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: Math.round(root.height * 0.01)
            visible: leftPane.paged

            Repeater {
                model: leftPane.pageCount

                delegate: Item {
                    id: indicatorDelegate
                    required property int index

                    readonly property bool current: leftPane.currentPage === index
                    readonly property int currentWidth: Math.round(pageIndicator.dotSize * 2.6)

                    height: pageIndicator.dotSize + pageIndicator.hitPadding * 2
                    width: (current ? currentWidth : pageIndicator.dotSize) + pageIndicator.hitPadding * 2

                    Rectangle {
                        anchors.centerIn: parent
                        color: indicatorDelegate.current ? root.theme.accentColor : root.theme.accentMutedColor
                        height: pageIndicator.dotSize
                        opacity: pageMouse.containsMouse ? 1 : 0.85
                        radius: height / 2
                        width: indicatorDelegate.current ? indicatorDelegate.currentWidth : pageIndicator.dotSize

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
                        onClicked: leftPane.showPage(indicatorDelegate.index)
                    }
                }
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
        // 无媒体播放且有通知时，通知占用时钟的位置
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
                    source: mediaController.visible && root.mediaProvider !== null ? root.mediaProvider.artUrl : ""
                    visible: source !== "" && status === Image.Ready

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
