import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.ksvg as KSvg
import org.kde.plasma.core as PlasmaCore



// Notification banner shown in a Plasma tooltip area next to the widget.
// 小组件旁边显示的通知横幅，基于 Plasma 工具提示区域。
PlasmaCore.ToolTipArea {
    id: root

    // Injected from main.qml.
    // 由 main.qml 注入。
    property var provider
    property bool showPopups: true
    property int displayTime: 5000
    property bool appletExpanded: false
    property int panelLocation: 0

    // Pending banner IDs and active ID.
    // 待展示横幅 ID 和当前激活 ID。
    property var pending: []
    property int currentId: -1

    readonly property bool bannerEnabled: root.showPopups && root.provider !== null && root.provider.available

    // 上一条收起与下一条弹出之间的间隔，避免动画重叠。
    readonly property int gap: 250

    // 当前横幅的展示内容，由 showNext() 填充。
    property string bannerApplicationName: ""
    property string bannerSummary: ""
    property string bannerBody: ""
    property string bannerIcon: ""

    readonly property font bannerTitleFont: Qt.font({
        "bold": true,
        "family": Kirigami.Theme.defaultFont.family,
        "pointSize": Kirigami.Theme.defaultFont.pointSize
    })

    // 显式给出锚定边缘，避免依赖 ToolTipArea 自身的父链推断。
    location: root.panelLocation
    active: root.bannerEnabled
    // 内容由 bannerContent 提供；interactive 让鼠标移入时暂停关闭计时并允许点击关闭按钮。
    // 注：本机 6.7.5 的 ToolTipArea 尚无 hideOnClick 属性，但内容项会被移入工具提示窗口、
    // 不再是本项的子树，因此「点击子项即收起」的过滤逻辑不会作用于横幅内容。
    mainItem: root.bannerContent
    interactive: true
    timeout: root.displayTime

    // Queue new banner requests and avoid duplicates.
    // 入队新横幅请求并避免重复。
    function enqueue(notificationId) {
        if (!root.bannerEnabled || root.appletExpanded || notificationId <= 0) {
            return;
        }
        if (root.currentId === notificationId || root.pending.includes(notificationId)) {
            return;
        }

        const next = [...root.pending, notificationId];
        root.pending = next;

        if (root.currentId < 0) {
            root.showNext();
        }
    }

    // Show the next valid banner.
    // 显示下一个有效横幅。
    function showNext() {
        while (root.pending.length > 0) {
            const id = root.pending[0];
            root.pending = root.pending.slice(1);

            const banner = root.provider.bannerForId(id);
            if (banner === null) {
                continue;
            }

            root.currentId = id;
            root.bannerApplicationName = banner.applicationName;
            root.bannerSummary = banner.summary;
            root.bannerBody = banner.body;
            root.bannerIcon = banner.icon;

            // ToolTipArea 的工具提示窗口在整个 plasmashell 内共享：上一条仍在淡出时
            // 直接显示会把定位设置作用在已暴露的窗口上并触发告警，故先收起再显示。
            root.hideImmediately();
            root.showToolTip();
            return;
        }

        root.currentId = -1;
    }

    // Close banners whose notification is no longer valid.
    // 若通知失效则关闭对应横幅。
    function checkCurrent() {
        if (root.currentId < 0 || root.provider === null) {
            return;
        }
        if (root.provider.bannerForId(root.currentId) === null) {
            root.dismiss();
        }
    }

    // Dismiss current banner and clear queued entries.
    // 关闭当前横幅并清空队列。
    function dismiss() {
        const wasShowing = root.currentId >= 0;
        root.currentId = -1;
        root.pending = [];

        if (wasShowing) {
            root.hideImmediately();
        }
    }

    // 关闭当前横幅对应的通知，并让队列继续。
    function closeCurrent() {
        const id = root.currentId;
        if (id >= 0 && root.provider !== null) {
            root.provider.closeById(id);
        }

        root.currentId = -1;
        root.hideImmediately();
    }

    // 触发当前横幅对应通知的默认动作。
    function activateCurrent() {
        const id = root.currentId;
        if (id < 0 || root.provider === null) {
            return;
        }

        root.provider.triggerById(id);
        root.currentId = -1;
        root.hideImmediately();
    }




    // ———————————————— 横幅内容 ————————————————
    // Plasma 只提供窗口与定位，内容与外观由此项决定。
    readonly property Item bannerContent: Item {
        id: bannerContentItem

        // 工具提示窗口的配色组与面板不同，必须显式指定，否则文字在横幅底色上不可读。
        // 取值与 Plasma 自带的 DefaultToolTip.qml 保持一致（Window，而非 Tooltip）。
        Kirigami.Theme.colorSet: Kirigami.Theme.Window
        Kirigami.Theme.inherit: false

        // 工具提示窗口按 mainItem 的隐式尺寸决定自身大小，与 DefaultToolTip.qml 同一算法。
        implicitHeight: bannerColumn.implicitHeight + Kirigami.Units.largeSpacing * 2
        implicitWidth: Math.round(Kirigami.Units.gridUnit * 18)

        // 整块可点击：触发默认动作。声明在内容之前，关闭按钮优先接收点击。
        MouseArea {
            anchors.fill: parent
            onClicked: root.activateCurrent()
        }

        RowLayout {
            id: bannerRow

            anchors.fill: parent
            anchors.margins: Kirigami.Units.largeSpacing
            spacing: Kirigami.Units.smallSpacing

            Kirigami.Icon { // 应用图标。
                Layout.alignment: Qt.AlignTop
                Layout.preferredHeight: Kirigami.Units.iconSizes.smallMedium
                Layout.preferredWidth: Kirigami.Units.iconSizes.smallMedium
                source: root.bannerIcon.length > 0 ? root.bannerIcon : "notifications"
            }

            ColumnLayout {
                id: bannerColumn

                Layout.fillWidth: true
                spacing: 0

                Text { // 应用名：强调色（工具提示窗口自成一配色组，故直接取 focusColor）。
                    Layout.fillWidth: true
                    color: Kirigami.Theme.focusColor
                    elide: Text.ElideRight
                    font: Kirigami.Theme.defaultFont
                    maximumLineCount: 1
                    text: root.bannerApplicationName.length > 0 ? root.bannerApplicationName : i18n("Notifications")
                }

                Text { // 通知标题。
                    Layout.fillWidth: true
                    color: Kirigami.Theme.textColor
                    elide: Text.ElideRight
                    font: root.bannerTitleFont
                    maximumLineCount: 1
                    text: root.bannerSummary
                    visible: text.length > 0
                }

                Text { // 通知正文，最多两行。
                    Layout.fillWidth: true
                    color: Kirigami.Theme.disabledTextColor
                    maximumLineCount: 2
                    text: root.bannerBody
                    visible: text.length > 0
                    wrapMode: Text.WordWrap
                }
            }

            Item { // 关闭按钮。
                id: closeButton

                Layout.alignment: Qt.AlignTop
                Layout.preferredHeight: Kirigami.Units.iconSizes.smallMedium
                Layout.preferredWidth: Kirigami.Units.iconSizes.smallMedium

                KSvg.FrameSvgItem {
                    anchors.fill: parent
                    imagePath: "widgets/button"
                    prefix: "toolbutton-hover"
                    visible: closeMouse.containsMouse
                }

                Kirigami.Icon {
                    anchors.centerIn: parent
                    height: Math.round(parent.height * 0.7)
                    opacity: closeMouse.containsMouse ? 1 : 0.7
                    source: "window-close"
                    width: height
                }

                MouseArea {
                    id: closeMouse

                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: root.closeCurrent()
                }
            }
        }
    }




    // ———————————————— 生命周期 ————————————————
    onBannerEnabledChanged: if (!root.bannerEnabled) {
        root.dismiss();
    }

    // 收起后稍作停顿再显示下一条。
    onToolTipVisibleChanged: function(toolTipVisible) {
        if (toolTipVisible) {
            return;
        }

        root.currentId = -1;
        gapTimer.restart();
    }

    Timer {
        id: gapTimer

        interval: root.gap
        repeat: false
        onTriggered: {
            if (root.bannerEnabled && !root.appletExpanded) {
                root.showNext();
            }
        }
    }

    Connections {
        target: root.provider

        function onBannerRequested(notificationId) {
            root.enqueue(notificationId);
        }
    }

    // 列表内容变化时确认当前横幅是否仍然有效。
    Connections {
        target: root.provider !== null ? root.provider.popupModel : null

        function onCountChanged() {
            root.checkCurrent();
        }
    }
}
