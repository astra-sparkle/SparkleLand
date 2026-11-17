import QtQuick
import QtQuick.Window

import "../../../contents/ui/Providers" as Providers

// Behavioral checks for the shared calendar helpers; exits non-zero on failure
// 月历共用辅助逻辑的行为校验；失败时以非零码退出
Window {
    id: harness

    height: 1
    visible: true
    width: 1

    Providers.CalendarShim {
        id: shim
    }

    property int failures: 0

    function check(name, condition, detail) {
        if (condition) {
            console.log("ok   " + name);
            return;
        }
        harness.failures += 1;
        console.log("FAIL " + name + (detail === undefined ? "" : " :: " + detail));
    }

    function dayText(value) {
        const month = value.getMonth() + 1;
        const day = value.getDate();
        const pad = function(number) {
            return number < 10 ? "0" + number : String(number);
        };
        return value.getFullYear() + "-" + pad(month) + "-" + pad(day);
    }

    Component.onCompleted: {
        // Weekday labels must cover 1..7 exactly once whatever day the locale starts on
        // 无论地区从周几开始，星期编号都必须恰好覆盖 1..7
        for (let firstDay = 1; firstDay <= 7; ++firstDay) {
            const labels = [];
            for (let offset = 0; offset < 7; ++offset) {
                labels.push(shim.weekDayLabelIndex(firstDay, offset));
            }
            const covered = labels.slice().sort(function(left, right) {
                return left - right;
            }).join(",");
            harness.check("weekday numbering covers 1..7 from " + firstDay,
                covered === "1,2,3,4,5,6,7", labels.join(","));
        }

        const mondayFirst = [];
        const sundayFirst = [];
        for (let offset = 0; offset < 7; ++offset) {
            mondayFirst.push(shim.weekDayLabelIndex(1, offset));
            sundayFirst.push(shim.weekDayLabelIndex(7, offset));
        }
        harness.check("monday-first week starts on monday",
            mondayFirst.join(",") === "1,2,3,4,5,6,7", mondayFirst.join(","));
        harness.check("sunday-first week starts on sunday",
            sundayFirst.join(",") === "7,1,2,3,4,5,6", sundayFirst.join(","));

        harness.check("js sunday maps to locale 7", shim.localeDayNumber(0) === 7);
        harness.check("js weekdays keep their locale number",
            shim.localeDayNumber(3) === 3);

        // 2026-11-01 is a Sunday, 2026-11-02 a Monday
        // 2026-11-01 是周日，2026-11-02 是周一
        harness.check("sunday-first month starts in the first column",
            shim.leadingCellCount(0, 7) === 0);
        harness.check("monday-first month pads the sunday column",
            shim.leadingCellCount(0, 1) === 6);
        harness.check("monday-first month starts in the first column",
            shim.leadingCellCount(1, 1) === 0);
        harness.check("sunday-first month pads one cell",
            shim.leadingCellCount(1, 7) === 1);

        const november = new Date(2026, 10, 1);
        const selected = new Date(2026, 10, 17);
        const cells = shim.monthCells(november, selected, selected, 1);
        harness.check("grid keeps six weeks", cells.length === 42, String(cells.length));
        harness.check("grid starts on 2026-10-26", harness.dayText(cells[0].date) === "2026-10-26",
            harness.dayText(cells[0].date));
        harness.check("grid ends on 2026-12-06",
            harness.dayText(cells[cells.length - 1].date) === "2026-12-06",
            harness.dayText(cells[cells.length - 1].date));

        let currentMonth = 0;
        let selectedCells = 0;
        let todayCells = 0;
        for (let index = 0; index < cells.length; ++index) {
            if (cells[index].inCurrentMonth) {
                currentMonth += 1;
            }
            if (cells[index].isSelected) {
                selectedCells += 1;
            }
            if (cells[index].isToday) {
                todayCells += 1;
            }
        }
        harness.check("november has 30 days in the grid", currentMonth === 30, String(currentMonth));
        harness.check("exactly one selected cell", selectedCells === 1, String(selectedCells));
        harness.check("exactly one today cell", todayCells === 1, String(todayCells));

        const start = shim.dayStart(new Date(2026, 10, 17, 23, 45));
        harness.check("day start drops the time of day",
            start.getHours() === 0 && start.getMinutes() === 0 && start.getDate() === 17,
            start.toString());

        harness.check("adding a day crosses the month",
            harness.dayText(shim.addDays(new Date(2026, 10, 30), 1)) === "2026-12-01",
            harness.dayText(shim.addDays(new Date(2026, 10, 30), 1)));
        harness.check("shifting a month clamps to its first day",
            harness.dayText(shim.shiftMonth(new Date(2026, 0, 31), 1)) === "2026-02-01",
            harness.dayText(shim.shiftMonth(new Date(2026, 0, 31), 1)));
        harness.check("invalid input is rejected",
            !shim.isValidDate(null) && !shim.isValidDate(new Date("nope")));

        const names = shim.weekDayNames(1);
        let emptyNames = 0;
        for (let index = 0; index < names.length; ++index) {
            if (names[index].length === 0) {
                emptyNames += 1;
            }
        }
        harness.check("weekday labels are all present",
            names.length === 7 && emptyNames === 0, names.join("|"));

        console.log(harness.failures === 0 ? "calendar shim checks passed" : "calendar shim checks failed");
        Qt.exit(harness.failures === 0 ? 0 : 1);
    }
}
