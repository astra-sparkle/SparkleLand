import QtQuick
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import org.kde.kirigami as Kirigami

// 展开面板（PlasmoidItem.fullRepresentation）。
//
// 布局（尺寸比例都按面板自身尺寸计算）：
//   - 面板默认占屏幕宽度 1/3（想改成 40% 就把 widthRatio 改成 0.4），高度 = 宽度 × 62.5%
//   - 左半（50% 宽）= 日历；右半（50% 宽）= 无媒体时是时钟，有媒体时是媒体控制器
//   - 中间一条**居中、长度 = 面板高度 95%** 的分割线
//   - 媒体控制器：圆角方形封面（等比裁剪，边长 = 50% 面板高度，距上边缘 20% 面板高度）；
//     按钮行 [上一曲, 暂停/继续, 下一曲] 等宽等距，总宽 = 控制器宽度 60%，居中，
//     距下边缘 5% 面板高度
//
// 主题、字体、格式、媒体接口全部由 main.qml 注入，本文件不直接依赖 Plasma 主题模块。
// 注：面板里的时钟只显示时间（timeFormat），不显示日期 —— 这里是按面板布局描述写的，
// 若也要跟随「显示日期」设置，需要把 showDate/dateFormat 一并注入并调小日期字号。
Item {
    id: root

    // ———————————————— 由 main.qml 注入 ————————————————
    property var theme
    property font textFont
    property string timeFormat
    property var mediaProvider
    property bool hasMedia: false
    property date requestedDate

    // 选中日期回传（由 main.qml 的 onDateSelected 接住）
    signal dateSelected(date date)

    // ———————————————— 尺寸 ————————————————
    readonly property real widthRatio: 1 / 3
    readonly property real heightRatio: 0.625

    implicitWidth: Math.round(Screen.width * root.widthRatio)
    implicitHeight: Math.round(root.implicitWidth * root.heightRatio)

    // 展开面板里的时钟字体：族沿用用户/主题的字体，字号按面板高度缩放
    readonly property font clockFont: Qt.font({
        "bold": true,
        "family": root.textFont.family,
        "pixelSize": Math.max(16, Math.round(root.height * 0.22))
    })

    readonly property bool playing: root.mediaProvider !== null && root.mediaProvider.playing

    // ———————————————— 左半：日历 ————————————————
    Item {
        id: leftHalf

        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.top: parent.top
        width: parent.width / 2

        Calender {
            anchors.fill: parent
            anchors.margins: Math.round(root.height * 0.05)
            theme: root.theme
            requestedDate: root.requestedDate
            onDateSelected: root.dateSelected(date)
        }
    }

    // ———————————————— 中间：分割线（居中、长 95%）————————————————
    Rectangle {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.verticalCenter
        color: root.theme.disabledTextColor
        height: Math.round(root.height * 0.95)
        width: 1
    }

    // ———————————————— 右半：时钟 / 媒体控制器 ————————————————
    Item {
        id: rightHalf

        anchors.bottom: parent.bottom
        anchors.right: parent.right
        anchors.top: parent.top
        width: parent.width / 2

        // ———— 无媒体：时钟 ————
        Clock {
            anchors.centerIn: parent
            height: Math.round(parent.height * 0.4)
            panelFont: root.clockFont
            theme: root.theme
            timeFormat: root.timeFormat
            visible: !root.hasMedia
            width: Math.round(parent.width * 0.9)
        }

        // ———— 有媒体：媒体控制器 ————
        Item {
            id: mediaController

            anchors.fill: parent
            visible: root.hasMedia

            // 圆角方形封面：边长 = 50% 面板高度，距面板上边缘 20% 面板高度
            Item {
                id: coverBox

                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: parent.top
                anchors.topMargin: Math.round(root.height * 0.2)
                height: Math.round(root.height * 0.5)
                width: height

                readonly property int cornerRadius: Math.round(root.height * 0.06)

                // 有封面图：等比裁剪成方形 + 圆角
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

                // 没有封面图时用占位块，并把曲名写在里面（面板几何很紧，没有额外一行放曲名）
                Rectangle {
                    anchors.fill: parent
                    color: root.theme.disabledTextColor
                    opacity: 0.25
                    radius: coverBox.cornerRadius
                    visible: !coverImage.visible
                }

                Text {
                    anchors.fill: parent
                    anchors.margins: Math.round(coverBox.height * 0.08)
                    color: root.theme.textColor
                    elide: Text.ElideRight
                    font: root.textFont
                    horizontalAlignment: Text.AlignHCenter
                    maximumLineCount: 3
                    text: root.mediaProvider !== null ? root.mediaProvider.trackTitle : ""
                    verticalAlignment: Text.AlignVCenter
                    visible: !coverImage.visible
                    wrapMode: Text.WordWrap
                }
            }

            // 按钮行：[上一曲, 暂停/继续, 下一曲]，等宽等距，总宽 = 控制器宽度 60%，
            // 居中，距面板下边缘 5% 面板高度
            RowLayout {
                id: controlsRow

                readonly property real gapRatio: 0.05

                anchors.bottom: parent.bottom
                anchors.bottomMargin: Math.round(root.height * 0.05)
                anchors.horizontalCenter: parent.horizontalCenter
                height: Math.round((width - spacing * 2) / 3)
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
