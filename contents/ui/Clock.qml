import QtQuick



// Display time and optional date. Styling is provided by the caller.
// 显示时间和可选日期；样式由调用方提供。
Item {
    id: root

    property var theme
    property font timeFont
    property font dateFont: root.timeFont
    property string timeFormat: "hh:mm"
    property bool showDate: false
    property string dateFormat: ""

    property int tick

    // Refresh every second when seconds are shown; otherwise update on the next minute.
    // 显示秒时按秒刷新，否则按分钟更新。
    readonly property bool hasSeconds: root.timeFormat.indexOf("s") >= 0

    function nextTickInterval() {
        const now = new Date();
        return root.hasSeconds
            ? 1000 - now.getMilliseconds()
            : 60000 - (now.getSeconds() * 1000 + now.getMilliseconds());
    }

    onHasSecondsChanged: {
        tickTimer.interval = root.nextTickInterval();
        if (tickTimer.running) {
            tickTimer.restart();
        }
    }

    readonly property string timeText: {
        root.tick;
        return Qt.formatTime(new Date(), root.timeFormat);
    }

    readonly property string dateText: {
        root.tick;
        return Qt.formatDate(new Date(), root.dateFormat);
    }

    implicitHeight: contentColumn.implicitHeight
    implicitWidth: Math.max(timeLabel.implicitWidth, root.showDate ? dateLabel.implicitWidth : 0) + 24



    // 时间在上，日期（可选）在下。
    Column {
        id: contentColumn

        anchors.centerIn: parent
        spacing: 0
        width: parent.width

        Text {
            id: timeLabel

            color: root.theme.textColor
            elide: Text.ElideRight
            font: root.timeFont
            height: root.timeFont.pixelSize > 0 ? root.timeFont.pixelSize : implicitHeight
            horizontalAlignment: Text.AlignHCenter
            text: root.timeText
            verticalAlignment: Text.AlignVCenter
            width: parent.width
        }

        Text {
            id: dateLabel

            color: root.theme.disabledTextColor
            elide: Text.ElideRight
            font: root.dateFont
            height: root.showDate
                ? (root.dateFont.pixelSize > 0 ? root.dateFont.pixelSize : implicitHeight)
                : 0
            horizontalAlignment: Text.AlignHCenter
            text: root.dateText
            verticalAlignment: Text.AlignVCenter
            visible: root.showDate
            width: parent.width
        }
    }



    // 仅在时钟可见时运行，并对齐到下一个时间边界。
    Timer {
        id: tickTimer

        interval: 60000
        repeat: true
        running: root.visible
        triggeredOnStart: true

        onTriggered: {
            root.tick++;
            tickTimer.interval = root.nextTickInterval();
        }
    }
}
