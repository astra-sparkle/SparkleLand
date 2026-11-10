import QtQuick
import org.kde.kirigami as Kirigami

// Reusable indicator styles, used as Indicators.Badge and Indicators.PageIndicator
// 可复用的指示器样式，分别以 Indicators.Badge 和 Indicators.PageIndicator 使用
Item {
    // Accent pill showing a count; a plain dot when the count is hidden
    // 显示计数的强调色胶囊，隐藏计数时仅显示圆点
    component Badge: Rectangle {
        id: badge

        // Properties injected by the using view
        // 由使用方视图注入的属性
        property var theme
        property int count: 0
        property bool showCount: true
        property font labelFont
        property color fillColor: badge.theme.accentColor
        property color labelColor: badge.theme.accentTextColor

        // Height comes from the caller so the badge follows the surface size
        // 高度由使用方提供，使角标跟随容器尺寸
        readonly property int displayCount: Math.min(99, badge.count)

        color: badge.fillColor
        radius: height / 2
        width: badge.showCount ? Math.max(height, label.implicitWidth + Math.round(height * 0.5)) : height

        Text {
            id: label

            anchors.centerIn: parent
            color: badge.labelColor
            font: badge.labelFont
            text: badge.displayCount >= 99 ? "99+" : String(badge.displayCount)
            visible: badge.showCount
        }
    }

    // One dot per page, the current page drawn as a wider accent pill
    // 每页一个圆点，当前页绘制为更宽的强调色胶囊
    component PageIndicator: Row {
        id: indicator

        // Properties injected by the using view
        // 由使用方视图注入的属性
        property var theme
        property int count: 0
        property int currentIndex: 0

        // Dot diameter; the hit area adds padding around it
        // 圆点直径，点击区域在其外围增加边距
        property int dotSize: Math.round(Kirigami.Units.gridUnit * 0.4)

        signal activated(int index)

        readonly property int hitPadding: Math.round(indicator.dotSize * 0.6)
        readonly property int currentWidth: Math.round(indicator.dotSize * 2.6)

        spacing: Math.round(indicator.dotSize / 3)

        Repeater {
            model: indicator.count

            delegate: Item {
                id: dotDelegate

                required property int index

                readonly property bool current: indicator.currentIndex === dotDelegate.index

                height: indicator.dotSize + indicator.hitPadding * 2
                width: (dotDelegate.current ? indicator.currentWidth : indicator.dotSize) + indicator.hitPadding * 2

                Rectangle {
                    anchors.centerIn: parent
                    color: dotDelegate.current ? indicator.theme.accentColor : indicator.theme.accentMutedColor
                    height: indicator.dotSize
                    opacity: dotMouse.containsMouse ? 1 : 0.85
                    radius: height / 2
                    width: dotDelegate.current ? indicator.currentWidth : indicator.dotSize

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
                    id: dotMouse

                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: indicator.activated(dotDelegate.index)
                }
            }
        }
    }
}
