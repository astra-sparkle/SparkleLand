import QtQuick
import org.kde.plasma.core as PlasmaCore

// 通知横幅：以 Plasma 工具提示窗口承载，由 plasmashell 负责定位在本小组件旁，
// 不抢焦点也不阻塞输入；按钮、动作与回复等完整交互仍在展开面板的通知页中完成。
PlasmaCore.ToolTipArea {
    id: root

    // ———————————————— 由 main.qml 注入 ————————————————
    property var provider
    property bool showPopups: true
    // 单条横幅的显示时长（毫秒）。
    property int displayTime: 5000
    // 展开面板处于打开状态时不再弹出横幅，避免与通知页重复。
    property bool appletExpanded: false
    // 面板所在的屏幕边缘（Plasma::Types::Location），决定横幅从哪一侧弹出。
    property int panelLocation: 0

    // 待展示队列与当前正在展示的通知 id。
    property var pending: []
    property int currentId: -1

    readonly property bool bannerEnabled: root.showPopups && root.provider !== null && root.provider.available

    // 上一条收起与下一条弹出之间的间隔，避免动画重叠。
    readonly property int gap: 250

    // 显式给出锚定边缘，避免依赖 ToolTipArea 自身的父链推断。
    location: root.panelLocation
    active: root.bannerEnabled
    timeout: root.displayTime

    // ———————————————— 队列 ————————————————
    // 收到新通知时入队；重复的 id 会被忽略。
    function enqueue(notificationId) {
        if (!root.bannerEnabled || root.appletExpanded || notificationId <= 0) {
            return;
        }
        if (root.currentId === notificationId || root.pending.indexOf(notificationId) >= 0) {
            return;
        }

        const next = root.pending.slice();
        next.push(notificationId);
        root.pending = next;

        if (root.currentId < 0) {
            root.showNext();
        }
    }

    // 依次展示队列中的通知；期间已失效的直接跳过。
    function showNext() {
        while (root.pending.length > 0) {
            const id = root.pending[0];
            root.pending = root.pending.slice(1);

            const banner = root.provider.bannerForId(id);
            if (banner === null) {
                continue;
            }

            root.currentId = id;
            root.mainText = banner.applicationName.length > 0 ? banner.applicationName : i18n("Notifications");
            root.subText = banner.body.length > 0 ? banner.summary + "\n" + banner.body : banner.summary;
            root.icon = banner.icon;

            // ToolTipArea 的工具提示窗口在整个 plasmashell 内共享：上一条仍在淡出时
            // 直接显示会把定位设置作用在已暴露的窗口上并触发告警，故先收起再显示。
            root.hideImmediately();
            root.showToolTip();
            return;
        }

        root.currentId = -1;
    }

    // 当前通知已从模型消失（被关闭或超时）时立即收起。
    function checkCurrent() {
        if (root.currentId < 0 || root.provider === null) {
            return;
        }
        if (root.provider.bannerForId(root.currentId) === null) {
            root.dismiss();
        }
    }

    // 收起横幅并清空队列；仅在确实由本组件占用工具提示时才收起共享窗口。
    function dismiss() {
        const wasShowing = root.currentId >= 0;
        root.currentId = -1;
        root.pending = [];

        if (wasShowing) {
            root.hideImmediately();
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
