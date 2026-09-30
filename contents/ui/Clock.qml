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
    // 时间字号是否「自动」：由 main.qml 根据「用户是否设过字号」传入。
    // true  → 按 digitalclock 的算法定字号（见下方「字号」一节）
    // false → 完全使用传入的 panelFont（展开面板的时钟就是这条路径）
    property bool autoTimeSize: false

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

    // ———————————————— 字号（对齐 digitalclock）————————————————
    // digitalclock（plasma-workspace/applets/digital-clock/DigitalClock.qml）自动模式的算法：
    //     fontHelper.font.pixelSize = 3 * Kirigami.Theme.defaultFont.pixelSize
    //     sizehelper.height = min(显示日期时 height*0.56 / 否则 height*0.71, fontHelper.font.pixelSize)
    //     timeLabel.font.pixelSize = sizehelper.height
    //     dateLabel.height = 0.8 * timeLabel.height，dateLabel.font.pixelSize = 该高度
    // 即：字号上限为 3 倍主题默认字号，再按可用高度适配。这里照抄。
    readonly property real availableHeight: root.height > 0 ? root.height : 32
    readonly property int timeLabelHeight: Math.round(root.availableHeight * (root.showDate ? 0.56 : 0.71))
    readonly property int autoTimePixelSize: Math.max(8, Math.min(root.timeLabelHeight, 3 * root.themeDefaultPixelSize))

    // 主题默认字号的像素值。Kirigami 的 defaultFont 带 pixelSize；
    // 回退主题用的 Qt.application.font 往往只有 pointSize（pixelSize 为 -1）
    // → 这时按 digitalclock 的 pointToPixel() 换算：pointSize / 72 * (pixelDensity * 25.4)
    readonly property int themeDefaultPixelSize: {
        const defaultFont = root.theme.defaultFont;
        if (defaultFont.pixelSize > 0) {
            return defaultFont.pixelSize;
        }
        const density = Screen.pixelDensity > 0 ? Screen.pixelDensity : 3.937;
        return Math.max(8, Math.round(defaultFont.pointSize / 72 * (density * 25.4)));
    }

    // panelFont 的族/粗细/斜体照用，只覆盖字号（Qt.font 里 pixelSize 与 pointSize 不能同时给）
    function makeFont(pixelSize, pointSize) {
        const spec = {
            "bold": root.panelFont.bold,
            "family": root.panelFont.family,
            "italic": root.panelFont.italic
        };
        if (pixelSize > 0) {
            spec.pixelSize = pixelSize;
        } else {
            spec.pointSize = pointSize;
        }
        return Qt.font(spec);
    }

    // 手动模式（autoTimeSize === false）**原样**使用传入的字体：
    // 它可能是 pointSize（紧凑条目用的 panelFont）也可能是 pixelSize
    //（展开面板传进来的 clockFont 就是 pixelSize）—— 不能统一改写成某一种单位。
    readonly property font timeFont: root.autoTimeSize
        ? root.makeFont(root.autoTimePixelSize, 0)
        : root.panelFont
    // 日期比时间小一号（digitalclock 用 0.8 倍），单位跟传入字体保持一致
    readonly property font dateFont: {
        if (!root.autoTimeSize) {
            if (root.panelFont.pixelSize > 0) {
                return root.makeFont(Math.max(1, Math.round(root.panelFont.pixelSize * 0.8)), 0);
            }
            return root.makeFont(0, Math.max(1, root.panelFont.pointSize * 0.8));
        }
        return root.makeFont(Math.max(1, Math.round(root.autoTimePixelSize * 0.8)), 0);
    }

    implicitHeight: contentColumn.implicitHeight
    implicitWidth: Math.max(timeLabel.implicitWidth, root.showDate ? dateLabel.implicitWidth : 0) + 24

    // 时间在上、日期（可选）在下，整块在条目里垂直居中
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
            height: root.showDate ? root.timeLabelHeight : Math.round(root.availableHeight * 0.71)
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
            height: root.showDate ? Math.round(root.timeLabelHeight * 0.8) : 0
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
            const now = new Date();
            if (root.hasSeconds) {
                tickTimer.interval = 1000 - now.getMilliseconds();
            } else {
                tickTimer.interval = 60000 - (now.getSeconds() * 1000 + now.getMilliseconds());
            }
        }
    }
}
