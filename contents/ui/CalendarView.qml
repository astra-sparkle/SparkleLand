import "style"
import QtQml
import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

Item {
    id: root

    property var theme
    // Calendar helpers injected by the applet shell, shared with any other month view
    // 由小组件外壳注入的月历辅助逻辑，与其他月历视图共用
    property var calendarShim

    readonly property bool ready: root.calendarShim !== null && root.calendarShim !== undefined

    property date displayedMonth: new Date()
    property date selectedDate: new Date()
    property date requestedDate
    property date today: new Date()

    // Week starts according to the current locale
    // 一周起始日遵循当前地区设置
    readonly property int firstDayOfWeek: Qt.locale().firstDayOfWeek

    readonly property real cellHeight: Math.round(root.theme.gridUnit * 2)

    // Month title formatted for the current locale
    // 按当前地区语言格式化的月份标题
    readonly property string monthTitle: i18nc("Format: month year", "%1 %2",
        Qt.locale().standaloneMonthName(root.displayedMonth.getMonth(), Locale.LongFormat),
        root.displayedMonth.getFullYear())

    readonly property var weekDayNames: root.ready
        ? root.calendarShim.weekDayNames(root.firstDayOfWeek)
        : []

    // Keep six weeks visible to stabilize the calendar height
    // 始终显示六周，保持日历高度稳定
    readonly property var days: root.ready
        ? root.calendarShim.monthCells(root.displayedMonth, root.selectedDate, root.today, root.firstDayOfWeek)
        : []

    readonly property font headerFont: Qt.font({
        "bold": true,
        "family": root.theme.defaultFont.family,
        "pointSize": root.theme.defaultFont.pointSize
    })

    Component.onCompleted: {
        if (!root.ready) {
            console.warn("[Sparkle Land] 月历辅助逻辑未注入，网格保持为空");
        }
        root.applyRequestedDate();
    }

    onCalendarShimChanged: root.applyRequestedDate()

    onRequestedDateChanged: applyRequestedDate()

    function showDate(date) {
        if (!root.ready || !root.calendarShim.isValidDate(date)) {
            return;
        }

        const start = root.calendarShim.dayStart(date);
        root.selectedDate = start;
        root.displayedMonth = root.calendarShim.monthStart(start);
    }

    function goToToday() {
        showDate(new Date());
    }

    function previousMonth() {
        root.displayedMonth = root.calendarShim.shiftMonth(root.displayedMonth, -1);
    }

    function nextMonth() {
        root.displayedMonth = root.calendarShim.shiftMonth(root.displayedMonth, 1);
    }

    function applyRequestedDate() {
        if (root.ready && root.calendarShim.isValidDate(root.requestedDate)) {
            showDate(root.requestedDate);
        }
    }

    function selectDate(date) {
        if (!root.ready || !root.calendarShim.isValidDate(date)) {
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
            root.displayedMonth = root.calendarShim.monthStart(cell.date);
        }
        root.selectDate(cell.date);
    }

    // Move the selection by whole days, letting the displayed month follow the date
    // 按整天移动选择，显示的月份随日期切换
    function moveSelection(dayOffset) {
        const next = root.ready ? root.calendarShim.addDays(root.selectedDate, dayOffset) : null;
        if (next !== null) {
            root.showDate(next);
        }
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

            Buttons.IconButton {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                accessibleName: i18n("Previous month")
                height: Math.round(root.theme.gridUnit * 1.6)
                source: "go-previous"
                theme: root.theme
                width: height
                onClicked: root.previousMonth()
            }

            Buttons.IconButton {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                accessibleName: i18n("Next month")
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
            id: gridArea

            Layout.fillWidth: true
            Layout.preferredHeight: root.cellHeight * 6

            // One focus stop for the month grid: arrow keys move the selection by day and
            // week, while the accessible name reports the month and the selected date
            // 月历网格作为一个焦点站点：方向键按日与按周移动选择，
            // 无障碍名称报告当前月份与选中日期
            Accessible.description: Qt.formatDate(root.selectedDate, Locale.LongFormat)
            Accessible.name: root.monthTitle
            Accessible.role: Accessible.Table
            activeFocusOnTab: true

            Keys.onDownPressed: root.moveSelection(7)
            Keys.onLeftPressed: root.moveSelection(-1)
            Keys.onRightPressed: root.moveSelection(1)
            Keys.onUpPressed: root.moveSelection(-7)
            Keys.onPressed: function(event) {
                if (event.key === Qt.Key_PageUp) {
                    root.previousMonth();
                    event.accepted = true;
                } else if (event.key === Qt.Key_PageDown) {
                    root.nextMonth();
                    event.accepted = true;
                }
            }

            GridLayout {
                anchors.fill: parent
                columnSpacing: 0
                columns: 7
                rowSpacing: 0

                Repeater {
                    model: root.days

                    delegate: Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: root.cellHeight
                        color: "transparent"

                        // Read each cell as a full date so screen readers can identify it
                        // 每个格子以完整日期对外表述，便于读屏识别
                        Accessible.name: Qt.formatDate(modelData.date, Locale.LongFormat)
                        Accessible.role: Accessible.Cell
                        Accessible.selected: modelData.isSelected

                        // Accent variants mark selection and hover while preserving the panel background
                        // 强调色变体标记选中与悬停，同时透出面板背景
                        Rectangle {
                            anchors.fill: parent
                            border.color: gridArea.activeFocus && modelData.isSelected
                                ? root.theme.accentTextColor
                                : "transparent"
                            border.width: gridArea.activeFocus && modelData.isSelected ? 1 : 0
                            color: modelData.isSelected
                                ? (index === gridMouse.hoverIndex ? root.theme.accentHoverColor : root.theme.accentColor)
                                : (index === gridMouse.hoverIndex ? root.theme.accentSubtleColor : "transparent")
                            radius: Kirigami.Units.cornerRadius
                        }

                        Text {
                            anchors.centerIn: parent
                            color: modelData.isSelected
                                ? root.theme.accentTextColor
                                : (modelData.isToday
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
                acceptedButtons: Qt.LeftButton
                hoverEnabled: true
                onClicked: root.activateIndex(gridMouse.hoverIndex)
                onPressed: gridArea.forceActiveFocus()
                // Wheel over the grid switches months, matching other KDE calendars
                // 在网格上滚动滚轮切换月份，与 KDE 其他日历一致
                onWheel: function(event) {
                    if (event.angleDelta.y > 0) {
                        root.previousMonth();
                    } else if (event.angleDelta.y < 0) {
                        root.nextMonth();
                    }
                }
            }
        }

        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: Math.round(root.theme.gridUnit * 1.6)

            Text {
                id: todayLabel

                anchors.centerIn: parent
                color: todayMouse.containsMouse || todayMouse.activeFocus ? root.theme.accentColor : root.theme.textColor
                font: root.theme.defaultFont
                text: i18n("Today")
            }

            MouseArea {
                id: todayMouse

                Accessible.name: i18n("Today")
                Accessible.onPressAction: root.goToToday()
                Accessible.role: Accessible.Button
                acceptedButtons: Qt.LeftButton
                activeFocusOnTab: true
                anchors.fill: todayLabel
                hoverEnabled: true
                onClicked: root.goToToday()
                Keys.onReturnPressed: root.goToToday()
                Keys.onSpacePressed: root.goToToday()
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
