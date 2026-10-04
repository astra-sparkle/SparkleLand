import QtQuick
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import org.kde.kirigami as Kirigami

// 展开面板：左侧为日历，右侧根据媒体状态显示时钟或播放器。
Item {
    id: root

    // ———————————————— 由 main.qml 注入 ————————————————
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

    // ———————————————— 尺寸 ————————————————
    // 宽度用 Plasma 弹窗的**默认宽度**：shell 的 CompactApplet.qml 在 fullRepresentation
    // 没有声明 Layout.preferredWidth / implicitWidth 时，用的就是这个值：
    //     return Kirigami.Units.iconSizes.sizeForLabels * 35;
    // 高度不声明 → 一并交给 Plasma 用它自己的默认高度（同一文件里是 sizeForLabels * 25）。
    // 不依赖 Screen，多屏下行为一致。
    // Plasma 弹窗的默认宽度。
    readonly property real plasmaDefaultWidth: Kirigami.Units.iconSizes.sizeForLabels * 35

    implicitWidth: Math.round(root.plasmaDefaultWidth)

    // 专辑封面边长：分别按面板宽度、高度算出 50%，取较小者
    // （等价于 0.5 × min(宽, 高)），面板变窄时封面会跟着收，不会溢出。
    // 专辑封面边长随面板可用空间调整。
    readonly property real coverSize: Math.round(0.5 * Math.min(root.width, root.height))

    // 展开面板里的时钟字体：族沿用用户/主题的字体，字号按面板高度缩放
    // 展开面板时钟字体。
    readonly property font clockFont: Qt.font({
        "bold": true,
        "family": root.textFont.family,
        "pixelSize": Math.max(16, Math.round(root.height * 0.22))
    })

    readonly property bool playing: root.mediaProvider !== null && root.mediaProvider.playing

    // 页码指示器需要预留的高度。
    readonly property int indicatorHeight: Math.round(root.height * 0.06)

    // ———————————————— 左半：日历 / 通知 ————————————————
    Item { // 左侧：有媒体且有通知时，在通知页与日历页之间切换。
        id: leftPane

        // 有媒体时右半被播放器占用，通知改到左半与日历分页显示。
        readonly property bool paged: root.hasMedia && root.hasNotifications
        readonly property int contentMargin: Math.round(root.height * 0.05)
        // 0 = 通知页，1 = 日历页。
        property int currentPage: 0

        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.top: parent.top
        width: parent.width / 2

        // 页面容器，底部为页码指示器留出空间。
        Item {
            anchors.bottom: parent.bottom
            anchors.bottomMargin: leftPane.contentMargin + (leftPane.paged ? root.indicatorHeight : 0)
            anchors.left: parent.left
            anchors.leftMargin: leftPane.contentMargin
            anchors.right: parent.right
            anchors.rightMargin: leftPane.contentMargin
            anchors.top: parent.top
            anchors.topMargin: leftPane.contentMargin

            Notifications { // 通知页。
                anchors.fill: parent
                enabled: visible
                provider: root.notificationsProvider
                showClearAll: root.notificationsShowClearAll
                showDoNotDisturb: root.notificationsShowDoNotDisturb
                theme: root.theme
                visible: leftPane.paged && leftPane.currentPage === 0
            }

            Calender { // 日历页。
                anchors.fill: parent
                enabled: visible
                requestedDate: root.requestedDate
                theme: root.theme
                visible: !leftPane.paged || leftPane.currentPage === 1
            }
        }

        // 页码指示器：点击切换通知页与日历页。
        Row {
            id: pageIndicator

            anchors.bottom: parent.bottom
            anchors.bottomMargin: Math.round(root.height * 0.015)
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: Math.round(root.height * 0.02)
            visible: leftPane.paged

            Repeater {
                model: 2

                delegate: Rectangle {
                    required property int index

                    color: leftPane.currentPage === index ? root.theme.accentColor : root.theme.accentMutedColor
                    height: Math.round(root.height * 0.03)
                    opacity: pageMouse.containsMouse ? 1 : 0.7
                    radius: height / 2
                    width: height

                    MouseArea {
                        id: pageMouse

                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: leftPane.currentPage = index
                    }
                }
            }
        }
    }

    // ———————————————— 中间：分割线（居中、长 95%）————————————————
    Rectangle { // 中间分割线。
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.verticalCenter
        color: root.theme.disabledTextColor
        height: Math.round(root.height * 0.95)
        width: 1
    }

    // ———————————————— 右半：时钟 / 媒体控制器 / 通知 ————————————————
    Item { // 右侧：无媒体且有通知时显示通知，否则显示时钟或播放器。
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

            // 曲目名称。
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
                text: root.mediaProvider !== null ? root.mediaProvider.trackTitle : ""
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

                Item {
                    Layout.fillHeight: true
                    Layout.fillWidth: true

                    Kirigami.Icon {
                        anchors.centerIn: parent
                        height: Math.round(parent.height * 0.85)
                        source: "media-skip-backward"
                        width: height
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: if (root.mediaProvider !== null) {
                            root.mediaProvider.previous();
                        }
                    }
                }

                Item {
                    Layout.fillHeight: true
                    Layout.fillWidth: true

                    Kirigami.Icon {
                        anchors.centerIn: parent
                        height: Math.round(parent.height * 0.85)
                        source: root.playing ? "media-playback-pause" : "media-playback-start"
                        width: height
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: if (root.mediaProvider !== null) {
                            root.mediaProvider.togglePlaying();
                        }
                    }
                }

                Item {
                    Layout.fillHeight: true
                    Layout.fillWidth: true

                    Kirigami.Icon {
                        anchors.centerIn: parent
                        height: Math.round(parent.height * 0.85)
                        source: "media-skip-forward"
                        width: height
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: if (root.mediaProvider !== null) {
                            root.mediaProvider.next();
                        }
                    }
                }
            }
        }
    }
}
