import QtQuick

// 时钟：只负责走时与渲染。
// 时间/日期格式、字体、主题色都由 main.qml（入口）决定后传入。
Item {
    id: root

    property var theme
    property font panelFont
    property string timeFormat: "hh:mm"
    property bool showDate: false
    property string dateFormat: ""

    // 驱动重新求值的计数器
    property int tick

    // 格式里含 "s" 说明要显示秒 → 需要按秒刷新
    readonly property bool hasSeconds: root.timeFormat.indexOf("s") >= 0

    readonly property string timeText: {
        root.tick;
        return Qt.formatTime(new Date(), root.timeFormat);
    }

    readonly property string dateText: {
        root.tick;
        return Qt.formatDate(new Date(), root.dateFormat);
    }

    implicitHeight: 32
    implicitWidth: timeLabel.implicitWidth + (root.showDate ? dateLabel.implicitWidth + 6 : 0) + 24

    Text {
        id: timeLabel

        anchors.left: parent.left
        anchors.leftMargin: 12
        anchors.right: root.showDate ? dateLabel.left : parent.right
        anchors.rightMargin: root.showDate ? 0 : 12
        anchors.verticalCenter: parent.verticalCenter
        color: root.theme.textColor
        elide: Text.ElideRight
        font: root.panelFont
        horizontalAlignment: root.showDate ? Text.AlignRight : Text.AlignHCenter
        text: root.timeText
        verticalAlignment: Text.AlignVCenter
    }

    Text {
        id: dateLabel

        anchors.right: parent.right
        anchors.rightMargin: 12
        anchors.verticalCenter: parent.verticalCenter
        color: root.theme.disabledTextColor
        elide: Text.ElideRight
        font: root.panelFont
        horizontalAlignment: Text.AlignRight
        // 日期最多占一半宽度，保证时间优先可见
        width: Math.min(implicitWidth, parent.width / 2)
        visible: root.showDate
        text: root.dateText
        verticalAlignment: Text.AlignVCenter
    }

    // 只在可见（即真的在显示时钟）时运行；
    // 触发后重新对齐到下一个时间边界，避免空转与累积漂移。
    Timer {
        id: tickTimer

        interval: 60000
        repeat: true
        running: root.visible
        triggeredOnStart: true

        onTriggered: {
            root.tick++;
            const now = new Date();
            if (root.hasSeconds) {
                tickTimer.interval = 1000 - now.getMilliseconds();
            } else {
                tickTimer.interval = 60000 - (now.getSeconds() * 1000 + now.getMilliseconds());
            }
        }
    }
}
