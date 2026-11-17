import QtQml
import QtQuick

// Calendar helpers shared by every month view: locale weekday numbering, date
// arithmetic and the six-week grid. Views keep only presentation and selection state.
// 月历视图共用的辅助逻辑：地区星期编号、日期运算与六周网格。
// 视图只保留呈现与选择状态。
//
// QLocale day numbers run 1..7 (Monday..Sunday) while Date.getDay() runs 0..6
// (Sunday..Saturday), so every conversion stays here instead of in the views.
// QLocale 的星期编号是 1..7（周一..周日），而 Date.getDay() 是 0..6（周日..周六），
// 因此所有换算集中在此，不散落在视图里。
QtObject {
    id: root

    // Fixed six-week grid keeps the calendar height stable across months
    // 固定六周网格，使日历高度在不同月份间保持稳定
    readonly property int cellCount: 42
    readonly property int dayCount: 7

    // QLocale day number for a Date.getDay() value: Sunday 0 becomes 7
    // 把 Date.getDay() 的取值换算为 QLocale 的星期编号：周日 0 对应 7
    function localeDayNumber(jsDay) {
        const day = Math.round(Number(jsDay) || 0) % 7;
        return day <= 0 ? 7 : Math.min(7, day);
    }

    // QLocale.dayName() number for a column offset in the current week
    // 当前星期某一列偏移对应的 QLocale.dayName() 星期编号
    function weekDayLabelIndex(firstDayOfWeek, offset) {
        const start = root.resolveFirstDayOfWeek(firstDayOfWeek);
        const step = Math.round(Number(offset) || 0) % 7;
        return ((start - 1 + step + 7) % 7) + 1;
    }

    // Empty cells before the first day of the month, counted from the locale's first day
    // 当前月份第一天之前需要留空的格子数，按地区设置的一周起始日计算
    function leadingCellCount(jsFirstDay, firstDayOfWeek) {
        const start = root.resolveFirstDayOfWeek(firstDayOfWeek);
        return (root.localeDayNumber(jsFirstDay) - start + 7) % 7;
    }

    // Weekday header labels in display order
    // 按显示顺序排列的星期表头标签
    function weekDayNames(firstDayOfWeek) {
        const start = root.resolveFirstDayOfWeek(firstDayOfWeek);
        const names = [];
        for (let offset = 0; offset < root.dayCount; ++offset) {
            names.push(Qt.locale().dayName(root.weekDayLabelIndex(start, offset), Locale.ShortFormat));
        }
        return names;
    }

    function isValidDate(value) {
        return value instanceof Date && !isNaN(value.getTime());
    }

    // Midnight of the given day, or null when the value is not a valid date
    // 给定日期当天的零点；值不是合法日期时返回 null
    function dayStart(value) {
        if (!root.isValidDate(value)) {
            return null;
        }
        return new Date(value.getFullYear(), value.getMonth(), value.getDate());
    }

    function addDays(value, days) {
        if (!root.isValidDate(value)) {
            return null;
        }
        return new Date(value.getFullYear(), value.getMonth(), value.getDate() + Math.round(Number(days) || 0));
    }

    // First day of the month containing the given date
    // 给定日期所在月份的第一天
    function monthStart(value) {
        if (!root.isValidDate(value)) {
            return null;
        }
        return new Date(value.getFullYear(), value.getMonth(), 1);
    }

    function shiftMonth(value, months) {
        if (!root.isValidDate(value)) {
            return null;
        }
        return new Date(value.getFullYear(), value.getMonth() + Math.round(Number(months) || 0), 1);
    }

    // Six-week grid for the given month, flagging the selected day and today
    // 给定月份的六周网格，并标记选中日期与今天
    function monthCells(month, selectedDate, today, firstDayOfWeek) {
        const monthDate = root.isValidDate(month) ? month : new Date();
        const year = monthDate.getFullYear();
        const monthIndex = monthDate.getMonth();
        const leading = root.leadingCellCount(new Date(year, monthIndex, 1).getDay(), firstDayOfWeek);
        const selectedStart = root.dayStart(selectedDate);
        const todayStart = root.dayStart(today);
        const selectedTime = selectedStart !== null ? selectedStart.getTime() : NaN;
        const todayTime = todayStart !== null ? todayStart.getTime() : NaN;

        const cells = [];
        for (let index = 0; index < root.cellCount; ++index) {
            const cellDate = new Date(year, monthIndex, 1 - leading + index);
            cells.push({
                "date": cellDate,
                "day": cellDate.getDate(),
                "inCurrentMonth": cellDate.getMonth() === monthIndex,
                "isSelected": cellDate.getTime() === selectedTime,
                "isToday": cellDate.getTime() === todayTime
            });
        }
        return cells;
    }

    // Missing or invalid input follows the current locale
    // 输入缺失或非法时跟随当前地区设置
    function resolveFirstDayOfWeek(value) {
        const first = Math.round(Number(value) || 0);
        if (first >= 1 && first <= 7) {
            return first;
        }
        const localized = Math.round(Number(Qt.locale().firstDayOfWeek) || 0);
        return (localized >= 1 && localized <= 7) ? localized : 1;
    }
}
