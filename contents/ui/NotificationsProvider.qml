import QtQuick
import org.kde.notificationmanager as NotificationManager



// Data provider for the Plasma notification model and actions.
// Plasma 通知模型与操作的数据提供器。
QtObject {
    id: root

    // Injected from main.qml.
    // 由 main.qml 注入。
    property int maxVisible: 5
    property bool includeExpired: true

    // Global notification settings and server state.
    // 全局通知设置与服务状态。
    readonly property NotificationManager.Settings settings: NotificationManager.Settings {
        onInhibitNotificationsWhenFullscreenChanged: root.refreshInhibition()
        onInhibitNotificationsWhenScreensMirroredChanged: root.refreshInhibition()
        onNotificationsInhibitedByApplicationChanged: root.refreshInhibition()
        onNotificationsInhibitedUntilChanged: root.refreshInhibition()
    }

    // Availability is computed explicitly to avoid binding loops.
    // 通过显式计算服务可用性，避免绑定循环。
    property bool available: false

    // Whether do-not-disturb is currently active.
    // 当前是否处于勿扰状态。
    property bool inhibited: false

    // Notification list model for the UI.
    // UI 使用的通知列表模型。
    readonly property NotificationManager.Notifications listModel: NotificationManager.Notifications {
        expandUnread: false
        groupMode: NotificationManager.Notifications.GroupDisabled
        limit: root.maxVisible > 0 ? root.maxVisible : 0
        showDismissed: root.includeExpired
        showExpired: root.includeExpired
        showJobs: false
        sortMode: NotificationManager.Notifications.SortByDate
        sortOrder: Qt.DescendingOrder
    }

    // Banner requests are handled by the popup component.
    // 横幅请求由弹出组件处理。
    signal bannerRequested(int notificationId)

    // Popup model contains only banner-eligible notifications.
    // 弹出模型仅包含符合展示条件的通知。
    readonly property NotificationManager.Notifications popupModel: NotificationManager.Notifications {
        expandUnread: false
        groupMode: NotificationManager.Notifications.GroupDisabled
        limit: Math.max(1, root.maxVisible)
        showAddedDuringInhibition: false
        showDismissed: false
        showExpired: false
        showJobs: false
        sortMode: NotificationManager.Notifications.SortByTypeAndUrgency
        sortOrder: Qt.AscendingOrder
        urgencies: root.bannerUrgencies
    }

    // Count values are updated explicitly to avoid binding loops.
    // 计数值通过显式更新，避免绑定循环。
    property int count: 0
    property int unreadCount: 0



    // Refresh counters when the list content changes.
    // 列表内容变化时刷新计数。
    readonly property Connections listWatcher: Connections {
        target: root.listModel

        function onCountChanged() {
            root.refreshCounts();
        }
        function onModelReset() {
            root.refreshCounts();
        }
        function onRowsInserted() {
            root.refreshCounts();
        }
        function onRowsRemoved() {
            root.refreshCounts();
        }
        function onUnreadNotificationsCountChanged() {
            root.refreshCounts();
        }
    }

    // Delay banner display until the provider is fully ready.
    property bool bannerReady: false

    // Watch for newly inserted notifications.
    readonly property Connections bannerWatcher: Connections {
        target: root.popupModel

        function onRowsInserted(parent, first, last) {
            if (!root.bannerReady) {
                return;
            }

            for (let row = first; row <= last; ++row) {
                const banner = root.bannerFor(row);
                if (banner !== null && root.isRecent(banner.created)) {
                    root.bannerRequested(banner.id);
                }
            }
        }
    }




    // One-time init path after configuration is ready.
    function activate() {
        root.criticalUrgency = NotificationManager.Notifications.CriticalUrgency;
        root.refreshInhibition();
        root.refreshCounts();
        root.bannerReady = true;
    }




    // Refresh list counts and unread count.
    function refreshCounts() {
        root.count = root.available ? root.listModel.count : 0;
        root.unreadCount = root.available ? root.listModel.unreadNotificationsCount : 0;
    }

    // Banner urgency filter, keeping critical alerts when do-not-disturb is active.
    property int bannerUrgencies: 0
    property int criticalUrgency: -1

    // Check whether the notification daemon is active.
    function refreshAvailability() {
        const server = NotificationManager.Server;
        root.available = server.valid
            || server.currentOwner.status === NotificationManager.ServerInfo.Running;
    }

    // Update banner urgency filter from the current do-not-disturb state.
    function refreshBannerUrgencies() {
        const N = NotificationManager.Notifications;
        let urgencies = 0;

        if (!root.inhibited || root.settings.criticalPopupsInDoNotDisturbMode) {
            urgencies |= N.CriticalUrgency;
        }
        if (!root.inhibited) {
            urgencies |= N.NormalUrgency;
            if (root.settings.lowPriorityPopups) {
                urgencies |= N.LowUrgency;
            }
        }

        root.bannerUrgencies = urgencies;
    }

    // Only show banners for recent notifications.
    function isRecent(created) {
        return (created instanceof Date) && !isNaN(created.getTime()) && (Date.now() - created.getTime() < 15000);
    }

    // Return banner payload for a given row, or null if invalid.
    function bannerFor(row) {
        const model = root.popupModel;
        if (row < 0 || row >= model.count) {
            return null;
        }

        const N = NotificationManager.Notifications;
        const index = model.index(row, 0);
        return {
            "applicationName": String(model.data(index, N.ApplicationNameRole) || ""),
            "body": String(model.data(index, N.BodyRole) || ""),
            "created": model.data(index, N.CreatedRole),
            "icon": model.data(index, N.IconNameRole) || model.data(index, N.ApplicationIconNameRole),
            "id": model.data(index, N.IdRole),
            "summary": String(model.data(index, N.SummaryRole) || "")
        };
    }

    // Look up a banner by notification ID.
    function bannerForId(notificationId) {
        const model = root.popupModel;
        for (let row = 0; row < model.count; ++row) {
            const banner = root.bannerFor(row);
            if (banner !== null && banner.id === notificationId) {
                return banner;
            }
        }

        return null;
    }

    // Look up a list row by notification ID.
    function rowForId(notificationId) {
        const model = root.listModel;
        const N = NotificationManager.Notifications;
        for (let row = 0; row < model.count; ++row) {
            if (model.data(model.index(row, 0), N.IdRole) === notificationId) {
                return row;
            }
        }

        return -1;
    }

    // Close a notification by ID.
    function closeById(notificationId) {
        const row = root.rowForId(notificationId);
        if (row >= 0) {
            root.close(row);
        }
    }

    // Trigger the default action for a notification by ID.
    function triggerById(notificationId) {
        const row = root.rowForId(notificationId);
        return row >= 0 ? root.trigger(row) : false;
    }

    // Helper for do-not-disturb checks.
    function isValidDate(value) {
        return value instanceof Date && !isNaN(value.getTime());
    }

    // Recompute service and do-not-disturb state.
    function refreshInhibition() {
        root.refreshAvailability();

        const settings = root.settings;
        let value = false;

        if (root.available) {
            const until = settings.notificationsInhibitedUntil;
            if (root.isValidDate(until) && Date.now() < until.getTime()) {
                value = true;
            }
            if (settings.notificationsInhibitedByApplication) {
                value = true;
            }
            if (settings.inhibitNotificationsWhenFullscreen && settings.fullscreenFocused) {
                value = true;
            }
            if (settings.inhibitNotificationsWhenScreensMirrored && settings.screensMirrored) {
                value = true;
            }
        }

        root.inhibited = value;
        root.refreshBannerUrgencies();
        root.refreshCounts();
    }




    // Toggle do-not-disturb using the same pattern as the stock widget.
    function toggleInhibition() {
        if (root.inhibited) {
            root.settings.notificationsInhibitedUntil = undefined;
            root.settings.revokeApplicationInhibitions();
            root.settings.fullscreenFocused = false;
            root.settings.screensMirrored = false;
        } else {
            const until = new Date();
            until.setFullYear(until.getFullYear() + 1);
            root.settings.notificationsInhibitedUntil = until;
        }

        root.settings.save();
        root.refreshInhibition();
    }




    // List operations use row indexes.
    function close(row) {
        root.listModel.close(root.listModel.index(row, 0));
    }




    // Trigger default action or return false.
    function trigger(row) {
        const index = root.listModel.index(row, 0);
        if (!root.listModel.data(index, NotificationManager.Notifications.HasDefaultActionRole)) {
            return false;
        }

        root.listModel.invokeDefaultAction(index);
        return true;
    }

    // 该行唯一的附带 URL，例如截图或收到的文件；没有时返回空串。
    function firstUrl(row) {
        const urls = root.listModel.data(root.listModel.index(row, 0), NotificationManager.Notifications.UrlsRole);
        return (urls && urls.length === 1) ? String(urls[0]) : "";
    }

    function openUrl(url) {
        Qt.openUrlExternally(url);
    }

    // 逐行关闭，从后往前避免删除过程中行号偏移。
    function clearAll() {
        if (!root.available) {
            return;
        }

        for (let row = root.listModel.count - 1; row >= 0; --row) {
            root.close(row);
        }
    }

    // 把当前通知全部标记为已读，用于清空紧凑条目的未读角标。
    function markAllRead() {
        if (!root.available) {
            return;
        }

        // 记录已读时间点，未出现在列表中的通知也一并算作已读。
        root.listModel.lastRead = new Date();

        for (let row = 0; row < root.listModel.count; ++row) {
            root.listModel.setData(root.listModel.index(row, 0), true, NotificationManager.Notifications.ReadRole);
        }
    }
}
