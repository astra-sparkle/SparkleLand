import QtQuick

// 时钟：只负责走时与渲染。
// 时间/日期格式、字体、主题色都由 main.qml（入口）决定后传入。
Item {
    id: root

    property var theme
    // 时间/日期字体：由 main.qml（紧凑条目，按官方字号算法算好）
    // 或 Panel.qml（展开面板，按面板高度缩放）传入。
    property font timeFont
    property font dateFont: root.timeFont
    property string timeFormat: "hh:mm"
    property bool showDate: false
    property string dateFormat: ""

    // 驱动重新求值的计数器
    property int tick

    // 格式里含 "s" 说明要显示秒 → 需要按秒刷新
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

    // 时间在上、日期（可选）在下，整块在条目里垂直居中
    // 行高：字号是像素时标签高度取字号值 —— 这正是 digitalclock 的做法
    //（timeLabel.height = sizehelper.height = 字号），两行刚好塞进面板厚度；
    // 字号是 pointSize 时（用户/主题字体）用自然行高，不做硬性压缩。
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
            tickTimer.interval = root.nextTickInterval();
        }
    }
}
