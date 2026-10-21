import QtQuick



// Display time and an optional date, styled by the caller
// 显示时间和可选日期，样式由调用方提供
Item {
    id: root

    property var theme
    property font timeFont
    property font dateFont: root.timeFont
    property string timeFormat: "hh:mm"
    property bool showDate: false
    property string dateFormat: ""

    property int tick

    // Refresh every second when shown; otherwise align to the next minute
    // 显示秒时按秒刷新，否则对齐到下一分钟
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



    // Run only while visible and align updates to a time boundary
    // 仅在时钟可见时运行，并对齐到下一个时间边界
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
