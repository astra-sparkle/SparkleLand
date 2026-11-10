import "style"
import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.core as PlasmaCore

// Notification banner
// 通知横幅
PlasmaCore.ToolTipArea {
    id: root

    // Banner provider and popup options
    // 横幅数据源与弹窗选项
    property var provider
    property bool showPopups: true
    property int displayTime: 5000
    property bool appletExpanded: false
    property int panelLocation: 0

    // Pending and active notification IDs
    // 待展示与当前通知 ID
    property var pending: []
    // var keeps synthetic history ids from being truncated
    // 使用 var 避免历史合成 ID 被截断
    property var currentId: -1

    readonly property bool bannerEnabled: root.showPopups && root.provider !== null && root.provider.available

    // Gap between banners
    // 横幅间距
    readonly property int gap: 250

    // Current banner content
    // 当前横幅内容
    property string bannerApplicationName: ""
    property string bannerSummary: ""
    property string bannerBody: ""
    property string bannerIcon: ""

    readonly property font bannerTitleFont: Qt.font({
        "bold": true,
        "family": Kirigami.Theme.defaultFont.family,
        "pointSize": Kirigami.Theme.defaultFont.pointSize
    })

    // Set the edge explicitly
    // 显式设置边缘
    location: root.panelLocation
    active: root.bannerEnabled
    // Hover pauses the timeout and keeps the close button active
    // 悬停时暂停计时，并保留关闭按钮
    mainItem: root.bannerContent
    interactive: true
    timeout: root.displayTime

    // Queue a banner unless it is already active or pending
    // 当前横幅或队列中已有该通知时不重复入队
    function enqueue(notificationId) {
        if (!root.bannerEnabled || root.appletExpanded || notificationId <= 0) {
            return;
        }
        // Refresh the visible banner in place so updates are not lost
        // 横幅正在显示这条通知时原地刷新，避免丢失更新
        if (root.currentId === notificationId) {
            root.refreshCurrent(notificationId);
            return;
        }
        if (root.pending.includes(notificationId)) {
            return;
        }

        const next = [...root.pending, notificationId];
        root.pending = next;

        if (root.currentId < 0) {
            root.showNext();
        }
    }

    // Reload the content of the notification currently on screen
    // 重新加载当前屏幕上这条通知的内容
    function refreshCurrent(notificationId) {
        const banner = root.provider !== null ? root.provider.bannerDataForId(notificationId) : null;
        if (banner === null) {
            return;
        }

        root.bannerApplicationName = banner.applicationName;
        root.bannerSummary = banner.summary;
        root.bannerBody = banner.body;
        root.bannerIcon = banner.icon;
    }

    // Show the next valid banner and skip stale requests
    // 显示下一个有效横幅，并跳过已失效的请求
    function showNext() {
        while (root.pending.length > 0) {
            const id = root.pending[0];
            root.pending = root.pending.slice(1);

            const banner = root.provider.bannerDataForId(id);
            if (banner === null) {
                continue;
            }

            root.currentId = id;
            root.bannerApplicationName = banner.applicationName;
            root.bannerSummary = banner.summary;
            root.bannerBody = banner.body;
            root.bannerIcon = banner.icon;

            // Hide the shared tooltip window before resetting its location
            // 重新设置位置前先立即收起 plasmashell 共享的工具提示窗口
            root.hideImmediately();
            root.showToolTip();
            return;
        }

        root.currentId = -1;
    }

    // Dismiss the banner when its notification is no longer valid
    // 通知失效时关闭对应横幅
    function checkCurrent() {
        if (root.currentId < 0 || root.provider === null) {
            return;
        }
        if (root.provider.bannerDataForId(root.currentId) === null) {
            root.dismiss();
        }
    }

    // Dismiss the current banner and clear the queue
    // 关闭当前横幅并清空队列
    function dismiss() {
        const wasShowing = root.currentId >= 0;
        root.currentId = -1;
        root.pending = [];

        if (wasShowing) {
            root.hideImmediately();
        }
    }

    // Close the notification and continue the queue
    // 关闭当前通知并继续队列
    function closeCurrent() {
        const id = root.currentId;
        if (id >= 0 && root.provider !== null) {
            root.provider.closeNotificationById(id);
        }

        root.currentId = -1;
        root.hideImmediately();
    }

    // Trigger the current notification's default action
    // 触发当前通知的默认动作
    function activateCurrent() {
        const id = root.currentId;
        if (id < 0 || root.provider === null) {
            return;
        }

        root.provider.triggerNotificationById(id);
        root.currentId = -1;
        root.hideImmediately();
    }

    // Plasma supplies the tooltip window; this item defines its content
    // Plasma 提供工具提示窗口，此项定义横幅内容
    readonly property Item bannerContent: Item {
        // Keep symbolic icons in the tooltip's Window color set
        // 图标使用工具提示窗口的 Window 配色组
        Kirigami.Theme.colorSet: Kirigami.Theme.Window
        Kirigami.Theme.inherit: false

        // ToolTipArea sizes its window from mainItem's implicit size
        // ToolTipArea 根据 mainItem 的隐式尺寸设置窗口大小
        implicitHeight: bannerColumn.implicitHeight + Kirigami.Units.largeSpacing * 2
        implicitWidth: Math.round(Kirigami.Units.gridUnit * 18)

        // Clicking the banner activates it; later controls take click priority
        // 点击横幅触发默认操作，后声明的控件优先接收点击
        MouseArea {
            anchors.fill: parent
            onClicked: root.activateCurrent()
        }

        RowLayout {
            anchors.fill: parent
            anchors.margins: Kirigami.Units.largeSpacing
            spacing: Kirigami.Units.smallSpacing

            Kirigami.Icon {
                Layout.alignment: Qt.AlignTop
                Layout.preferredHeight: Kirigami.Units.iconSizes.smallMedium
                Layout.preferredWidth: Kirigami.Units.iconSizes.smallMedium
                source: root.bannerIcon.length > 0 ? root.bannerIcon : "notifications"
            }

            ColumnLayout {
                id: bannerColumn

                Layout.fillWidth: true
                spacing: 0

                Text {
                    Layout.fillWidth: true
                    color: root.palette.active.accent
                    elide: Text.ElideRight
                    font: Kirigami.Theme.defaultFont
                    maximumLineCount: 1
                    text: root.bannerApplicationName.length > 0 ? root.bannerApplicationName : i18n("Notifications")
                }

                Text {
                    Layout.fillWidth: true
                    color: root.palette.active.toolTipText
                    elide: Text.ElideRight
                    font: root.bannerTitleFont
                    maximumLineCount: 1
                    text: root.bannerSummary
                    visible: text.length > 0
                }

                Text {
                    Layout.fillWidth: true
                    color: root.palette.disabled.toolTipText
                    maximumLineCount: 2
                    text: root.bannerBody
                    visible: text.length > 0
                    wrapMode: Text.WordWrap
                }
            }

            Buttons.ToolButton {
                Layout.alignment: Qt.AlignTop
                Layout.preferredHeight: Kirigami.Units.iconSizes.smallMedium
                Layout.preferredWidth: Kirigami.Units.iconSizes.smallMedium
                iconColor: root.palette.active.toolTipText
                iconSizeRatio: 0.7
                source: "window-close"
                onClicked: root.closeCurrent()
            }
        }
    }

    onBannerEnabledChanged: if (!root.bannerEnabled) {
        root.dismiss();
    }

    // Resume the queue after a short gap when the tooltip closes
    // 工具提示关闭后稍作停顿，再继续横幅队列
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

    // Recheck the active banner when the notification list changes
    // 通知列表变化时重新检查当前横幅
    Connections {
        target: root.provider !== null ? root.provider.popupModel : null

        function onCountChanged() {
            root.checkCurrent();
        }
    }
}
