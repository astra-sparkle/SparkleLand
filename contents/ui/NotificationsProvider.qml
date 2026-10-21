import QtQuick
import org.kde.notificationmanager as NotificationManager



// Data provider for the Plasma notification model and actions
// Plasma 通知模型与操作的数据提供器
QtObject {
    id: root

    // Properties injected by main.qml
    // 由 main.qml 注入的属性
    property int maxVisible: 5
    property bool includeExpired: true

    // Global notification settings and server state
    // 全局通知设置与服务状态
    readonly property NotificationManager.Settings settings: NotificationManager.Settings {
        onInhibitNotificationsWhenFullscreenChanged: root.refreshInhibition()
        onInhibitNotificationsWhenScreensMirroredChanged: root.refreshInhibition()
        onNotificationsInhibitedByApplicationChanged: root.refreshInhibition()
        onNotificationsInhibitedUntilChanged: root.refreshInhibition()
    }

    // Compute availability explicitly to avoid binding loops
    // 显式计算服务可用性，避免绑定循环
    property bool available: false

    // Whether do-not-disturb is currently active
    // 当前是否处于勿扰状态
    property bool inhibited: false

    // Notification list model used by the UI
    // UI 使用的通知列表模型
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

    // Banner requests are handled by the popup component
    // 横幅请求由弹出组件处理
    signal bannerRequested(int notificationId)

    // Popup model contains only banner-eligible notifications
    // 弹出模型仅包含符合展示条件的通知
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

    // Update count values explicitly to avoid binding loops
    // 显式更新计数值，避免绑定循环
    property int count: 0
    property int unreadCount: 0



    // Refresh counters when the list content changes
    // 列表内容变化时刷新计数
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

    // Delay banners until the provider is fully initialized
    // 数据源完成初始化后再显示横幅
    property bool bannerReady: false

    // Watch for newly inserted notifications
    // 监听新插入的通知
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




    // Initialize once after configuration is ready
    // 配置就绪后执行一次初始化
    function activate() {
        root.criticalUrgency = NotificationManager.Notifications.CriticalUrgency;
        root.refreshInhibition();
        root.refreshCounts();
        root.bannerReady = true;
    }




    function refreshCounts() {
        root.count = root.available ? root.listModel.count : 0;
        root.unreadCount = root.available ? root.listModel.unreadNotificationsCount : 0;
    }

    // Keep critical alerts eligible during do-not-disturb when configured
    // 按设置在勿扰期间保留紧急横幅
    property int bannerUrgencies: 0
    property int criticalUrgency: -1

    function refreshAvailability() {
        const server = NotificationManager.Server;
        root.available = server.valid
            || server.currentOwner.status === NotificationManager.ServerInfo.Running;
    }

    // Update eligible banner urgencies from do-not-disturb state
    // 根据勿扰状态更新可显示的横幅级别
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

    // Show banners only for recent notifications
    // 仅为近期通知显示横幅
    function isRecent(created) {
        return (created instanceof Date) && !isNaN(created.getTime()) && (Date.now() - created.getTime() < 15000);
    }

    // Return banner data for a row, or null if invalid
    // 返回指定行的横幅数据，无效时返回 null
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

    // Find banner data by notification ID
    // 按通知 ID 查找横幅数据
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

    // Find a notification row by ID
    // 按通知 ID 查找列表行
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

    // Close a notification by ID
    // 按 ID 关闭通知
    function closeById(notificationId) {
        const row = root.rowForId(notificationId);
        if (row >= 0) {
            root.close(row);
        }
    }

    // Trigger a notification's default action by ID
    // 按 ID 触发通知的默认操作
    function triggerById(notificationId) {
        const row = root.rowForId(notificationId);
        return row >= 0 ? root.trigger(row) : false;
    }

    // Validate dates used by do-not-disturb settings
    // 验证勿扰设置中的日期
    function isValidDate(value) {
        return value instanceof Date && !isNaN(value.getTime());
    }

    // Recompute service availability and do-not-disturb state
    // 重新计算服务可用性与勿扰状态
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




    // Toggle do-not-disturb using Plasma's notification settings
    // 使用 Plasma 通知设置切换勿扰状态
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




    // List operations use model row indexes
    // 列表操作使用模型行号
    function close(row) {
        root.listModel.close(root.listModel.index(row, 0));
    }




    // Trigger the default action and return false when unavailable
    // 触发默认操作；不可用时返回 false
    function trigger(row) {
        const model = root.listModel;
        const index = model.index(row, 0);
        if (!model.data(index, NotificationManager.Notifications.HasDefaultActionRole)) {
            return false;
        }

        model.invokeDefaultAction(index);
        return true;
    }

    // Return the single URL attached to this entry, if any
    // 返回该行唯一的附带 URL，例如截图或收到的文件；没有时返回空串
    function firstUrl(row) {
        const model = root.listModel;
        const urls = model.data(model.index(row, 0), NotificationManager.Notifications.UrlsRole);
        return Array.isArray(urls) && urls.length === 1 ? String(urls[0]) : "";
    }

    function openUrl(url) {
        Qt.openUrlExternally(url);
    }

    // Close rows from the end to avoid shifting indexes during removal
    // 从后往前逐行关闭，避免删除过程中行号偏移
    function clearAll() {
        const model = root.listModel;
        if (!root.available || model === null) {
            return;
        }

        for (let row = model.count - 1; row >= 0; --row) {
            root.close(row);
        }
    }

    // Mark all current notifications as read to clear the compact badge
    // 将当前通知全部标记为已读，以清空紧凑条目的未读角标
    function markAllRead() {
        const model = root.listModel;
        if (!root.available || model === null) {
            return;
        }

        model.lastRead = new Date();

        for (let row = 0; row < model.count; ++row) {
            model.setData(model.index(row, 0), true, NotificationManager.Notifications.ReadRole);
        }
    }
}
