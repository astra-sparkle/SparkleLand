import QtQuick
import org.kde.kirigami as Kirigami

// Lyric styles shared by the compact panel line and the expanded media view
// 紧凑面板歌词行与展开媒体视图共用的歌词样式
Item {
    // Single-line lyric: the new line slides up while the previous one leaves,
    // and the line scrolls sideways once it is wider than the available space;
    // the travel follows the active line's published time span
    // 单行歌词：新行向上滑入、旧行向上滑出；宽度超出可用空间时水平滚动，
    // 滚动进度遵循当前行的发布时长
    component ScrollingLine: Item {
        id: line

        property font textFont
        property string text: ""
        // Progress inside the active line: 0 at its start, 1 at its end
        // 当前行内的进度：行首为 0，行尾为 1
        property real progress: 0
        property color color: "transparent"

        // Text currently on screen, kept so the previous line can slide away
        // 当前显示的文本，供旧行滑出使用
        property string shownText: ""
        // A line is sliding in or out; smooth the horizontal offset only between ticks
        // 正在切换行；仅在两次位置刷新之间平滑水平偏移
        property bool sliding: false

        readonly property real clampedProgress: Math.max(0, Math.min(1, line.progress))

        clip: true

        // Resolve the horizontal offset for a label: long lines scroll from the left
        // edge, short lines stay centered
        // 计算标签的水平偏移：长句从左侧滚动，短句保持居中
        function labelX(item, value) {
            const overflow = Math.max(0, item.implicitWidth - line.width);
            return overflow > 0
                ? -Math.round(overflow * value)
                : Math.round((line.width - item.implicitWidth) / 2);
        }

        Text {
            id: outgoingLabel

            color: line.color
            font: line.textFont
            height: line.height
            verticalAlignment: Text.AlignVCenter
            visible: false
            y: 0
        }

        Text {
            id: currentLabel

            color: line.color
            font: line.textFont
            height: line.height
            text: line.text
            verticalAlignment: Text.AlignVCenter
            x: line.labelX(currentLabel, line.clampedProgress)

            // Smooth the position ticks that drive the scroll
            // 平滑驱动滚动的位置刷新间隔
            Behavior on x {
                enabled: !line.sliding

                NumberAnimation {
                    duration: Kirigami.Units.longDuration
                    easing.type: Easing.Linear
                }
            }
        }

        ParallelAnimation {
            id: slide

            NumberAnimation {
                duration: Kirigami.Units.longDuration
                easing.type: Easing.OutCubic
                from: 0
                property: "y"
                target: outgoingLabel
                to: -line.height
            }

            NumberAnimation {
                duration: Kirigami.Units.longDuration
                easing.type: Easing.OutCubic
                from: line.height
                property: "y"
                target: currentLabel
                to: 0
            }

            onFinished: {
                outgoingLabel.visible = false;
                currentLabel.y = 0;
                line.sliding = false;
            }
        }

        onTextChanged: {
            const previous = line.shownText;
            if (line.text === previous) {
                return;
            }
            line.shownText = line.text;

            // First line, cleared lyrics or a hidden widget switch without animating
            // 首行、歌词清空或组件隐藏时直接切换
            if (previous.length === 0 || line.text.length === 0 || !line.visible) {
                slide.stop();
                outgoingLabel.visible = false;
                currentLabel.y = 0;
                line.sliding = false;
                return;
            }

            // The outgoing line froze at its end, so resolve it with full progress
            // 旧行在结束时定格，因此按完整进度计算其偏移
            outgoingLabel.text = previous;
            outgoingLabel.x = line.labelX(outgoingLabel, 1);
            outgoingLabel.y = 0;
            outgoingLabel.visible = true;
            line.sliding = true;
            slide.restart();
        }
    }

    // One lyric row: the kept part over its overflow, both elided to the row width
    // 单个歌词行：保留部分在上，顺延部分在下，均按行宽省略
    component RowText: Column {
        id: rowBlock

        property string headText: ""
        property string tailText: ""
        property color textColor: "transparent"
        property font textFont
        property real textWidth: 0

        spacing: 0
        width: Math.round(rowBlock.textWidth)

        Text {
            color: rowBlock.textColor
            elide: Text.ElideRight
            font: rowBlock.textFont
            horizontalAlignment: Text.AlignHCenter
            lineHeight: 0.8
            lineHeightMode: Text.ProportionalHeight
            text: rowBlock.headText
            width: rowBlock.width
            wrapMode: Text.NoWrap
        }

        Text {
            color: rowBlock.textColor
            elide: Text.ElideRight
            font: rowBlock.textFont
            horizontalAlignment: Text.AlignHCenter
            lineHeight: 0.8
            lineHeightMode: Text.ProportionalHeight
            text: rowBlock.tailText
            visible: rowBlock.tailText.length > 0
            width: rowBlock.width
            wrapMode: Text.NoWrap
        }
    }

    // Multi-row scrolling lyric used by the playback page: the active line sits on
    // the middle row, with the previous and next lines above and below; the optional
    // secondary row (translation or romanisation) is inserted right under the active
    // line. Before the first line starts the middle row stays blank and the first line
    // is shown as the next one. Rows stack on their own height, so neighbouring lines
    // sit side by side
    // 播放页使用的多行滚动歌词：当前行居中，上下分别为上一行与下一行，
    // 可选的副行（译文或发音）紧贴当前行下方。首句开始前中间行留空，
    // 首句作为下一句显示。各行按自身高度紧挨排列
    component ScrollingLines: Item {
        id: view

        // Normalized lyric lines and the active index, -1 before the first line starts
        // 规范化后的歌词行与当前索引，首行开始前为 -1
        property var lines: []
        property int currentIndex: -1
        // 0 = no secondary row, 1 = translation, 2 = romanisation
        // 0 = 无副行，1 = 译文，2 = 发音
        property int secondaryMode: 0
        property var theme
        property font lineFont
        // Smaller font for the lines above and below the active one
        // 上下两行使用更小字号，以突出当前行
        property font inactiveLineFont: view.lineFont
        property font secondaryFont
        // Width of the text block inside the view; a longer line is split by the provider
        // 视图内文本块的宽度；超出的歌词由提供器切分
        property real textWidth: view.width
        // Splits a lyric line into the part kept on its row and the overflow; supplied
        // by the lyric provider so the cutting rule lives outside the view
        // 把歌词行拆成留在本行的部分与溢出部分；由歌词提供器提供，使截断规则独立于视图
        property var splitter: null

        readonly property bool hasSecondary: view.secondaryMode !== 0
        readonly property int rowCount: view.hasSecondary ? 4 : 3
        readonly property int lineCount: Array.isArray(view.lines) ? view.lines.length : 0
        // Before the first line starts the middle row stays empty, and the upcoming line
        // is shown on the next row instead of being treated as the active line
        // 首行开始前中间行保持空白，即将到来的行显示在下一行，而不是被当作当前行
        readonly property bool hasActiveLine: view.currentIndex >= 0 && view.lineCount > 0
        // Index of the line on the middle row, rounded so the active styling stays
        // stable while the strip is scrolling
        // 居中行对应的歌词索引，取整使滚动过程中当前行样式保持稳定
        readonly property int anchorLine: Math.max(0, Math.round(view.currentIndex))
        readonly property int windowStart: view.hasActiveLine ? Math.max(0, view.anchorLine - 1) : 0
        readonly property int windowCount: {
            if (view.lineCount === 0) {
                return 0;
            }
            // Only the upcoming line is shown below the empty middle row
            // 空白中间行下方只显示即将到来的首句
            if (!view.hasActiveLine) {
                return Math.min(view.lineCount, 1);
            }
            const last = Math.min(view.lineCount - 1, view.anchorLine + 2);
            return Math.max(0, last - view.windowStart + 1);
        }

        // True for the line occupying the middle row
        // 占据中间行的歌词行
        function isActiveIndex(index) {
            return view.hasActiveLine && index === view.anchorLine;
        }

        // Visual slot of a line relative to the middle row; before the first line the
        // middle row is empty, so the upcoming line sits one slot below it
        // 行相对中间行的显示槽位；首行开始前中间行留空，即将到来的行位于其下一槽
        function slotOf(index) {
            return index - (view.hasActiveLine ? view.anchorLine : -1);
        }

        // Height of the empty middle row: it stands in for the first line, so it takes
        // the height that line will have once it becomes active and the strip does not
        // jump when the first line starts
        // 空白中间行的高度：它代替首行，因此采用首行成为当前行后的高度，
        // 避免首句开始时歌词条跳动
        readonly property real blankAnchorHeight: view.upcomingLineHeight()

        // Height the first line will occupy on the middle row, resolved from the same
        // split the active row uses
        // 首行占据中间行后的高度，按与当前行相同的切分规则计算
        function upcomingLineHeight() {
            if (view.lineCount === 0) {
                return view.textLineHeight(view.lineFont);
            }
            const parts = view.splitParts(view.lineTextAt(0));
            const lines = parts !== null && parts.tail.length > 0 ? 2 : 1;
            return lines * view.textLineHeight(view.lineFont);
        }

        // Height of one rendered text line for a given font, matching what Text lays out
        // 给定字体下单行文字的高度，与 Text 实际排版一致
        function textLineHeight(fontValue) {
            if (fontValue === null || fontValue === undefined || fontValue.pixelSize <= 0) {
                return 20;
            }
            return Math.round(fontValue.pixelSize * 1.5);
        }

        // Two text lines per row keep the strip height stable while the content changes
        // 每行按两行文字预留高度，内容变化时控件高度保持稳定
        implicitHeight: view.rowCount * 2 * view.textLineHeight(view.lineFont)
        clip: true

        // Split a lyric line through the provider; null keeps the text as one row
        // 通过提供器切分歌词行；为 null 时整行保留
        function splitParts(value) {
            if (typeof view.splitter !== "function") {
                return null;
            }

            const parts = view.splitter(value);
            if (parts === null || parts === undefined) {
                return null;
            }
            return {
                "head": typeof parts.head === "string" ? parts.head : "",
                "tail": typeof parts.tail === "string" ? parts.tail : ""
            };
        }

        function lineTextAt(index) {
            if (index < 0 || index >= view.lineCount) {
                return "";
            }
            const line = view.lines[index];
            return line !== null && line !== undefined && typeof line.text === "string" ? line.text : "";
        }

        function secondaryText(line) {
            if (line === null || line === undefined) {
                return "";
            }
            if (view.secondaryMode === 1) {
                return typeof line.translation === "string" ? line.translation : "";
            }
            if (view.secondaryMode === 2) {
                return typeof line.roman === "string" ? line.roman : "";
            }
            return "";
        }

        // Lines below the active one drop their split-off part so they never grow
        // towards the content that follows; before the first line the upcoming line is
        // below the empty middle row and drops it too
        // 位于当前行下方的行丢弃溢出部分，避免向下挤占后续内容；
        // 首行开始前，即将到来的行位于空白中间行下方，同样丢弃溢出部分
        function tailAt(index) {
            const parts = view.splitParts(view.lineTextAt(index));
            if (parts === null || view.slotOf(index) > 0) {
                return "";
            }
            return parts.tail;
        }

        function headAt(index) {
            const parts = view.splitParts(view.lineTextAt(index));
            return parts !== null ? parts.head : view.lineTextAt(index);
        }

        // Height of a line row, measured from the font and the lines it actually renders,
        // so neighbouring rows sit side by side without outer spacing
        // 歌词行的高度由其字体与实际显示的行数决定，相邻行因此紧挨排列而没有额外间距
        function lineHeight(index) {
            const fontValue = view.isActiveIndex(index) ? view.lineFont : view.inactiveLineFont;
            const lines = view.tailAt(index).length > 0 ? 2 : 1;
            return lines * view.textLineHeight(fontValue);
        }

        function anchorHeight() {
            return view.hasActiveLine ? view.lineHeight(view.anchorLine) : view.blankAnchorHeight;
        }

        function secondaryLine() {
            return view.hasActiveLine ? view.lines[view.anchorLine] : null;
        }

        function secondaryParts() {
            return view.splitParts(view.secondaryText(view.secondaryLine()));
        }

        function secondaryHeight() {
            if (!view.hasSecondary) {
                return 0;
            }
            const parts = view.secondaryParts();
            const lines = parts !== null && parts.tail.length > 0 ? 2 : 1;
            return lines * view.textLineHeight(view.secondaryFont);
        }

        // Top of a line row: the active row stays centered, everything else stacks
        // around it without gaps. Before the first line the middle row is empty, so the
        // upcoming line starts right below it
        // 歌词行的顶部位置：当前行居中，其余行紧贴其上下排列。
        // 首行开始前中间行留空，即将到来的行紧贴其下方开始
        function rowTop(index) {
            let top = (view.height - view.anchorHeight()) / 2;
            if (!view.hasActiveLine) {
                top += view.anchorHeight();
            }
            if (index < view.anchorLine) {
                for (let step = index; step < view.anchorLine; ++step) {
                    top -= view.lineHeight(step);
                }
                return top;
            }
            for (let step = view.anchorLine; step < index; ++step) {
                top += view.lineHeight(step);
                if (view.hasSecondary && view.isActiveIndex(step)) {
                    top += view.secondaryHeight();
                }
            }
            return top;
        }

        function secondaryTop() {
            return view.rowTop(view.anchorLine) + view.lineHeight(view.anchorLine);
        }

        Repeater {
            model: view.windowCount

            delegate: Item {
                id: lineLabel

                required property int index

                readonly property int lineIndex: view.windowStart + index
                // Slot of this row around the middle row, so an upcoming line stays
                // below the empty middle row until it starts
                // 该行相对中间行的槽位；首句开始前，即将到来的行停留在空白中间行下方
                readonly property int slot: view.slotOf(lineIndex)
                readonly property bool active: lineLabel.slot === 0

                // Fade with the distance to the active row so the scroll has no colour pop
                // 按与当前行的距离淡出，避免滚动过程中颜色突变
                height: view.lineHeight(lineIndex)
                opacity: Math.max(0.35, 1 - Math.abs(lineLabel.slot) * 0.5)
                width: view.width
                y: view.rowTop(lineIndex)

                Behavior on y {
                    NumberAnimation {
                        duration: Kirigami.Units.longDuration
                        easing.type: Easing.OutCubic
                    }
                }

                RowText {
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.verticalCenter: parent.verticalCenter
                    // Only the current line keeps the full size
                    // 仅当前行保持完整字号
                    headText: view.headAt(lineLabel.lineIndex)
                    tailText: view.tailAt(lineLabel.lineIndex)
                    textColor: view.theme !== null && view.theme !== undefined ? view.theme.textColor : "transparent"
                    textFont: lineLabel.active ? view.lineFont : view.inactiveLineFont
                    textWidth: view.textWidth
                }
            }
        }

        // Secondary row sits directly under the active line and fades in as it settles
        // 副行紧贴当前行下方，并在滚动停稳时淡入
        RowText {
            id: secondaryRow

            readonly property var parts: view.secondaryParts()
            readonly property string rowText: view.secondaryText(view.secondaryLine())

            anchors.horizontalCenter: parent.horizontalCenter
            headText: parts !== null ? parts.head : rowText
            tailText: parts !== null ? parts.tail : ""
            textColor: view.theme !== null && view.theme !== undefined ? view.theme.disabledTextColor : "transparent"
            textFont: view.secondaryFont
            textWidth: view.textWidth
            visible: view.hasSecondary && rowText.length > 0
            y: view.secondaryTop()
        }

        NumberAnimation {
            id: secondaryFade

            duration: Kirigami.Units.longDuration
            from: 0
            property: "opacity"
            target: secondaryRow
            to: 1
        }

        onAnchorLineChanged: secondaryFade.restart()
    }
}
