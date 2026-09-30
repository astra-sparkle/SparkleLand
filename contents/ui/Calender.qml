import QtQml
import QtQuick
import QtQuick.Layouts

// 内置月历实现：本机不存在可复用的 Plasma 日历接口，因此这是唯一的日历实现。
//
// 性能设计（相对旧实现的三处关键改动）：
//  1. days 模型只依赖「显示月份」和本地周首日 —— 只有切月才重建 42 个 delegate；
//     选中日期、跨零点更新「今天」只让 delegate 的绑定重新求值，不再重建 delegate。
//  2. 去掉「每格一个 hoverEnabled MouseArea」：整个日期网格共用 1 个 MouseArea，
//     由坐标算出悬停格，鼠标移动时仅相邻两格的颜色绑定发生变化。
//  3. 「今天/选中」的时间戳只在根部归一化一次，避免每个 delegate 各自构造 Date。
Item {
    id: root

    // 主题（颜色/字体/间距）由 main.qml 注入，本文件不依赖具体主题模块
    property var theme

    property date displayedMonth: new Date()
    property date selectedDate: new Date()
    property date requestedDate
    property date today: new Date()

    signal dateSelected(date date)

    // 只在根部归一化一次
    readonly property real todayStart: dayStart(root.today).getTime()
    readonly property real selectedStart: dayStart(root.selectedDate).getTime()

    // 本地一周第一天：0 = 周日 … 6 = 周六（与 JS Date 的 getDay() 一致）
    readonly property int firstDayOfWeek: Qt.locale().firstDayOfWeek

    readonly property real cellHeight: Math.round(root.theme.gridUnit * 2)

    // 月份标题：沿用上游 KDE 日历的做法，让译者可以调整「月 年」的顺序
    readonly property string monthTitle: i18nc("Format: month year", "%1 %2")
        .arg(Qt.locale().standaloneMonthName(root.displayedMonth.getMonth(), Locale.LongFormat))
        .arg(root.displayedMonth.getFullYear())

    // 表头文字只随 firstDayOfWeek 变化
    readonly property var weekDayNames: {
        const names = [];
        for (let i = 0; i < 7; ++i) {
            names.push(Qt.locale().dayName((root.firstDayOfWeek + i) % 7, Locale.ShortFormat));
        }
        return names;
    }

    // 6 周 x 7 天 = 42 格，固定行数保证高度稳定。
    // 刻意不含 isToday / isSelected，避免选中日期时重建全部 delegate。
    readonly property var days: {
        const year = root.displayedMonth.getFullYear();
        const month = root.displayedMonth.getMonth();
        const leading = (new Date(year, month, 1).getDay() - root.firstDayOfWeek + 7) % 7;

        const cells = [];
        for (let i = 0; i < 42; ++i) {
            const cellDate = new Date(year, month, 1 - leading + i);
            cells.push({
                "date": cellDate,
                "day": cellDate.getDate(),
                "inCurrentMonth": cellDate.getMonth() === month
            });
        }
        return cells;
    }

    // 用 Qt.font 整体构造，避免写 font.bold 这类子属性（会把整字体的绑定冲掉）
    readonly property font headerFont: Qt.font({
        "bold": true,
        "family": root.theme.defaultFont.family,
        "pointSize": root.theme.defaultFont.pointSize
    })

    Component.onCompleted: applyRequestedDate()

    onRequestedDateChanged: applyRequestedDate()

    function dayStart(date) {
        return new Date(date.getFullYear(), date.getMonth(), date.getDate());
    }

    function isValidDate(date) {
        return date !== undefined && date !== null && !isNaN(date.getTime());
    }

    function isToday(date) {
        return dayStart(date).getTime() === root.todayStart;
    }

    function isSelected(date) {
        return dayStart(date).getTime() === root.selectedStart;
    }

    // 入口：跳转并选中指定日期
    function showDate(date) {
        if (!isValidDate(date)) {
            return;
        }

        const start = dayStart(date);
        root.selectedDate = start;
        root.displayedMonth = new Date(start.getFullYear(), start.getMonth(), 1);
    }

    // 入口：回到今天
    function goToToday() {
        showDate(new Date());
    }

    function previousMonth() {
        root.displayedMonth = new Date(root.displayedMonth.getFullYear(), root.displayedMonth.getMonth() - 1, 1);
    }

    function nextMonth() {
        root.displayedMonth = new Date(root.displayedMonth.getFullYear(), root.displayedMonth.getMonth() + 1, 1);
    }

    function applyRequestedDate() {
        if (isValidDate(root.requestedDate)) {
            showDate(root.requestedDate);
        }
    }

    function selectDate(date) {
        if (!isValidDate(date)) {
            return;
        }

        root.selectedDate = date;
        root.dateSelected(date);
    }

    // 由网格 MouseArea 调用：命中第 index 格
    function activateIndex(index) {
        if (index < 0 || index >= root.days.length) {
            return;
        }

        const cell = root.days[index];
        if (!cell.inCurrentMonth) {
            root.displayedMonth = new Date(cell.date.getFullYear(), cell.date.getMonth(), 1);
        }
        root.selectDate(cell.date);
    }

    implicitHeight: mainColumn.implicitHeight
    implicitWidth: Math.round(root.theme.gridUnit * 15)

    ColumnLayout {
        id: mainColumn

        // 顶部对齐，高度由内容决定
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        spacing: Math.round(root.theme.gridUnit / 3)

        // 头部：上月 / 月份标题 / 下月
        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: Math.round(root.theme.gridUnit * 1.6)

            Text {
                anchors.centerIn: parent
                color: root.theme.textColor
                font: root.headerFont
                text: root.monthTitle
            }

            Text {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                color: previousMouse.containsMouse ? root.theme.highlightColor : root.theme.textColor
                font: root.headerFont
                text: "\u2039"

                MouseArea {
                    id: previousMouse

                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: root.previousMonth()
                }
            }

            Text {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                color: nextMouse.containsMouse ? root.theme.highlightColor : root.theme.textColor
                font: root.headerFont
                text: "\u203A"

                MouseArea {
                    id: nextMouse

                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: root.nextMonth()
                }
            }
        }

        // 星期表头（固定 7 项，不随切月重建）
        GridLayout {
            Layout.fillWidth: true
            columnSpacing: 0
            columns: 7
            rowSpacing: 0

            Repeater {
                model: 7

                delegate: Text {
                    Layout.fillWidth: true
                    Layout.preferredHeight: Math.round(root.theme.gridUnit)
                    color: root.theme.disabledTextColor
                    font: root.theme.defaultFont
                    horizontalAlignment: Text.AlignHCenter
                    text: root.weekDayNames[index]
                    verticalAlignment: Text.AlignVCenter
                }
            }
        }

        // 日期网格 + 唯一的鼠标处理
        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: root.cellHeight * 6

            GridLayout {
                anchors.fill: parent
                columnSpacing: 0
                columns: 7
                rowSpacing: 0

                Repeater {
                    model: root.days

                    delegate: Rectangle {
                        readonly property bool cellIsToday: root.isToday(modelData.date)
                        readonly property bool cellIsSelected: root.isSelected(modelData.date)

                        Layout.fillWidth: true
                        Layout.preferredHeight: root.cellHeight
                        color: cellIsSelected
                            ? root.theme.highlightColor
                            : (index === gridMouse.hoverIndex ? root.theme.hoverColor : "transparent")
                        radius: 4

                        Text {
                            anchors.centerIn: parent
                            color: cellIsSelected
                                ? root.theme.highlightedTextColor
                                : (cellIsToday
                                    ? root.theme.highlightColor
                                    : (modelData.inCurrentMonth ? root.theme.textColor : root.theme.disabledTextColor))
                            font: root.theme.defaultFont
                            text: modelData.day
                        }
                    }
                }
            }

            MouseArea {
                id: gridMouse

                // 命中计算：鼠标移动时只有相邻两格的颜色绑定会变化
                readonly property int hoverIndex: {
                    if (!containsMouse) {
                        return -1;
                    }

                    const column = Math.floor(mouseX / (width / 7));
                    const row = Math.floor(mouseY / root.cellHeight);
                    if (column < 0 || column > 6 || row < 0) {
                        return -1;
                    }

                    const index = row * 7 + column;
                    return index < root.days.length ? index : -1;
                }

                anchors.fill: parent
                hoverEnabled: true
                onClicked: root.activateIndex(gridMouse.hoverIndex)
            }
        }

        // 底部：回到今天
        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: Math.round(root.theme.gridUnit * 1.6)

            Text {
                id: todayLabel

                anchors.centerIn: parent
                color: todayMouse.containsMouse ? root.theme.highlightColor : root.theme.textColor
                font: root.theme.defaultFont
                text: i18n("Today")
            }

            MouseArea {
                id: todayMouse

                anchors.fill: todayLabel
                hoverEnabled: true
                onClicked: root.goToToday()
            }
        }
    }

    // 跨零点时刷新「今天」；只在可见时运行，且每天只唤醒一次
    Timer {
        id: midnightTimer

        interval: 60000
        repeat: true
        running: root.visible
        triggeredOnStart: true

        onTriggered: {
            const now = new Date();
            root.today = now;
            const nextMidnight = new Date(now.getFullYear(), now.getMonth(), now.getDate() + 1);
            midnightTimer.interval = Math.max(1000, nextMidnight.getTime() - now.getTime());
        }
    }
}
