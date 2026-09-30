import QtQuick
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import org.kde.kirigami as Kirigami

Item {
    id: root

    property var theme
    property font textFont
    property string timeFormat
    property var mediaProvider
    property bool hasMedia: false
    property date requestedDate

    // Plasma 默认展开宽度为标签图标尺寸的 35 倍。
    readonly property real plasmaDefaultWidth: Kirigami.Units.iconSizes.sizeForLabels * 35

    implicitWidth: Math.round(root.plasmaDefaultWidth)

    readonly property real coverSize: Math.round(0.5 * Math.min(root.width, root.height))

    readonly property font clockFont: Qt.font({
        "bold": true,
        "family": root.textFont.family,
        "pixelSize": Math.max(16, Math.round(root.height * 0.22))
    })

    readonly property bool playing: root.mediaProvider !== null && root.mediaProvider.playing

    Item {
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.top: parent.top
        width: parent.width / 2

        Calender {
            anchors.fill: parent
            anchors.margins: Math.round(root.height * 0.05)
            theme: root.theme
            requestedDate: root.requestedDate
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
            visible: !root.hasMedia
            width: Math.round(parent.width * 0.9)
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

            Text {
                id: trackLabel

                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: coverBox.bottom
                anchors.topMargin: mediaController.gap
                // 封面与控制按钮之间的剩余高度，过小时归零。
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
