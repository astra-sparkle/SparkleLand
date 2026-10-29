import QtQml
import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami



// Simple month calendar with month switching and date selection
// 简单月历，支持切换月份和日期选择
Item {
    id: root

    // Properties injected by main.qml
    // 由 main.qml 注入的属性
    property var theme

    property date displayedMonth: new Date()
    property date selectedDate: new Date()
    property date requestedDate
    property date today: new Date()

    readonly property real todayStart: dayStart(root.today).getTime()
    readonly property real selectedStart: dayStart(root.selectedDate).getTime()

    // Week starts according to the current locale
    // 一周起始日遵循当前地区设置
    readonly property int firstDayOfWeek: Qt.locale().firstDayOfWeek

    readonly property real cellHeight: Math.round(root.theme.gridUnit * 2)

    // Month title formatted for the current locale
    // 按当前地区语言格式化的月份标题
    readonly property string monthTitle: i18nc("Format: month year", "%1 %2",
        Qt.locale().standaloneMonthName(root.displayedMonth.getMonth(), Locale.LongFormat),
        root.displayedMonth.getFullYear())

    readonly property var weekDayNames: {
        const names = [];
        for (let i = 0; i < 7; ++i) {
            names.push(Qt.locale().dayName((root.firstDayOfWeek + i) % 7, Locale.ShortFormat));
        }
        return names;
    }

    // Keep six weeks visible to stabilize the calendar height
    // 始终显示六周，保持日历高度稳定
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

    function showDate(date) {
        if (!isValidDate(date)) {
            return;
        }

        const start = dayStart(date);
        root.selectedDate = start;
        root.displayedMonth = new Date(start.getFullYear(), start.getMonth(), 1);
    }

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
    }

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

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        spacing: Math.round(root.theme.gridUnit / 3)

        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: Math.round(root.theme.gridUnit * 1.6)

            Text {
                anchors.centerIn: parent
                color: root.theme.textColor
                font: root.headerFont
                text: root.monthTitle
            }

            Media.MediaControlButton {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                height: Math.round(root.theme.gridUnit * 1.6)
                source: "go-previous"
                theme: root.theme
                width: height
                onClicked: root.previousMonth()
            }

            Media.MediaControlButton {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                height: Math.round(root.theme.gridUnit * 1.6)
                source: "go-next"
                theme: root.theme
                width: height
                onClicked: root.nextMonth()
            }
        }

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
                        color: "transparent"

                        // Accent variants mark selection and hover while preserving the panel background
                        // 强调色变体标记选中与悬停，同时透出面板背景
                        Rectangle {
                            anchors.fill: parent
                            color: cellIsSelected
                                ? (index === gridMouse.hoverIndex ? root.theme.accentHoverColor : root.theme.accentColor)
                                : (index === gridMouse.hoverIndex ? root.theme.accentSubtleColor : "transparent")
                            radius: Kirigami.Units.cornerRadius
                        }

                        Text {
                            anchors.centerIn: parent
                            color: cellIsSelected
                                ? root.theme.accentTextColor
                                : (cellIsToday
                                    ? root.theme.accentColor
                                    : (modelData.inCurrentMonth ? root.theme.textColor : root.theme.disabledTextColor))
                            font: root.theme.defaultFont
                            text: modelData.day
                        }
                    }
                }
            }

            MouseArea {
                id: gridMouse

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

        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: Math.round(root.theme.gridUnit * 1.6)

            Text {
                id: todayLabel

                anchors.centerIn: parent
                color: todayMouse.containsMouse ? root.theme.accentColor : root.theme.textColor
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

    // Refresh today's marker across midnight
    // 跨零点刷新“今天”标记
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
