import QtQuick
import org.kde.notificationmanager as NotificationManager

// Notification provider: keeps the Plasma model, unread badge logic,
// inhibition state, and banner dispatch in one place.
// 通知提供器：把 Plasma 通知模型、未读角标逻辑、勿扰状态与横幅派发集中管理。
QtObject {
    id: root

    // Configuration forwarded by the provider host.
    // 由上层 provider 转发的配置项。
    property bool enabled: true
    property int maxVisible: 5
    property bool includeExpired: true

    // Runtime state shared with the Plasma notification service.
    // 与 Plasma 通知服务共享的运行时状态。
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
    // 横幅请求由弹窗组件处理
    signal bannerRequested(var notificationId)

    // Notifications restored from history use synthetic ids at or above this value;
    // QML int is 32-bit signed, so the marker itself has to be a double
    // 从历史记录恢复的通知使用大于等于该值的合成 ID；QML 的 int 为 32 位有符号，标记值本身须用 double
    readonly property double restoredIdBit: 2147483648

    // Popup model keeps only banner-eligible notifications
    // 弹窗模型只保留符合条件的通知
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

    // Count values are refreshed explicitly
    // 计数值由显式刷新更新
    property int count: 0
    property int unreadCount: 0
    // Timestamp of the last time the user looked at the list, defines what counts as unread
    // 上次查看列表的时间戳，用于界定未读范围
    property double lastReadMs: 0
    // Delay banners until the data source is fully initialized
    // 数据源完成初始化后再显示横幅
    property bool bannerReady: false
    // Keep critical alerts eligible during do-not-disturb when configured
    // 按设置在勿扰期间保留紧急横幅
    property int bannerUrgencies: 0
    property int criticalUrgency: -1
    // Revision timestamp of the last banner accepted per notification id
    // 每个通知 ID 上次成功请求横幅时的修订时间戳
    property var bannerStamps: ({})
    // Refresh counters when the list changes
    // 列表变化时刷新计数
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
        // In-place updates such as replaces_id keep the row count unchanged
        // replaces_id 之类的原地更新不会改变行数
        function onDataChanged() {
            root.refreshCounts();
        }
    }

    // Watch for inserted or updated notifications
    // 监听新插入与内容更新的通知
    readonly property Connections bannerWatcher: Connections {
        target: root.popupModel

        function onRowsInserted(parent, first, last) {
            if (!root.bannerReady) {
                return;
            }

            for (let row = first; row <= last; ++row) {
                root.requestBanner(root.bannerDataForRow(row));
            }
        }
        // Updated notifications never emit rowsInserted
        // 内容更新的通知不会再触发 rowsInserted
        function onDataChanged() {
            if (!root.bannerReady) {
                return;
            }

            for (let row = 0; row < root.popupModel.count; ++row) {
                root.requestBanner(root.bannerDataForRow(row));
            }
        }
    }

    // Hide notification data while the feature is switched off
    // 功能关闭时隐藏通知数据
    onEnabledChanged: root.refreshCounts()

    // Initialize once after the data source is created
    // 数据源创建后执行一次初始化
    function initialize() {
        root.criticalUrgency = NotificationManager.Notifications.CriticalUrgency;
        // Treat restored history as read so a restart does not raise the badge
        // 将重启后恢复的历史视为已读，避免重启后出现角标
        root.lastReadMs = Date.now();
        root.refreshInhibition();
        root.refreshCounts();
        root.bannerReady = true;
    }

    function refreshCounts() {
        Qt.callLater(root.applyCounts);
    }

    // Short helper to keep the enablement checks readable and consistent.
    // 统一可用性判断，减少重复条件判断。
    function isNotificationActive() {
        return root.enabled && root.available;
    }

    // Recompute counters after the model has settled, never while a model signal is still firing.
    // 在模型稳定后再计算计数，避免在信号发射过程中读取模型状态。
    function applyCounts() {
        const active = root.isNotificationActive();
        root.count = active ? root.listModel.count : 0;
        root.unreadCount = active ? root.countUnreadNotifications() : 0;
    }

    // Count notifications that arrived after the last read marker.
    // This Plasma build keeps the model's unread count at zero, so we compute it explicitly.
    // 统计上次已读标记之后到达的通知。
    // 当前 Plasma 构建版本中模型自带的未读计数会保持为 0，因此需要显式计算。
    function countUnreadNotifications() {
        const model = root.listModel;
        const notificationType = NotificationManager.Notifications;
        let unread = 0;

        for (let row = 0; row < model.count; ++row) {
            const index = model.index(row, 0);
            // Expired and dismissed entries belong to history, not to the badge
            // 过期和已关闭的条目属于历史记录，不计入角标
            if (model.data(index, notificationType.ExpiredRole) === true
                    || model.data(index, notificationType.DismissedRole) === true) {
                continue;
            }

            let date = model.data(index, notificationType.UpdatedRole);
            if (!(date instanceof Date) || isNaN(date.getTime())) {
                date = model.data(index, notificationType.CreatedRole);
            }
            if (!(date instanceof Date) || isNaN(date.getTime())) {
                continue;
            }

            if (date.getTime() > root.lastReadMs) {
                unread += 1;
            }
        }

        return unread;
    }

    function refreshAvailability() {
        const server = NotificationManager.Server;
        root.available = server.valid
            || server.currentOwner.status === NotificationManager.ServerInfo.Running;
    }

    // Update eligible banner urgencies from do-not-disturb state
    // 根据勿扰状态更新可显示的横幅级别
    function refreshBannerUrgencies() {
        const notificationType = NotificationManager.Notifications;
        let urgencies = 0;

        if (!root.inhibited || root.settings.criticalPopupsInDoNotDisturbMode) {
            urgencies |= notificationType.CriticalUrgency;
        }
        if (!root.inhibited) {
            urgencies |= notificationType.NormalUrgency;
            if (root.settings.lowPriorityPopups) {
                urgencies |= notificationType.LowUrgency;
            }
        }

        root.bannerUrgencies = urgencies;
    }

    // Show banners only for recent notifications
    // 仅为近期通知显示横幅
    function isRecentNotification(createdAt) {
        return (createdAt instanceof Date) && !isNaN(createdAt.getTime())
            && (Date.now() - createdAt.getTime() < 15000);
    }

    // Restored notifications reuse the startup time, so they would pass the recency
    // check; the synthetic id range is the only reliable marker
    // 恢复的通知会沿用启动时间而通过“近期”判定，合成 ID 区间是唯一可靠的标记
    function isRestoredNotification(notificationId) {
        return notificationId >= root.restoredIdBit;
    }

    // Request one banner per notification revision
    // 同一条通知的每次内容更新只请求一次横幅
    function requestBanner(banner) {
        if (banner === null || root.isRestoredNotification(banner.id)) {
            return;
        }

        // Prefer the update timestamp so replaced notifications count as new content
        // 优先使用更新时间，使被替换的通知也算作新内容
        const revision = root.isValidDate(banner.updated) ? banner.updated : banner.created;
        if (!root.isRecentNotification(revision)) {
            return;
        }

        const stamp = revision.getTime();
        if (root.bannerStamps[banner.id] === stamp) {
            return;
        }

        root.bannerStamps[banner.id] = stamp;
        root.bannerRequested(banner.id);
    }

    // Return banner data for a row, or null if invalid
    // 返回指定行的横幅数据，无效时返回 null
    function bannerDataForRow(row) {
        const model = root.popupModel;
        if (row < 0 || row >= model.count) {
            return null;
        }

        const notificationType = NotificationManager.Notifications;
        const index = model.index(row, 0);
        return {
            "applicationName": String(model.data(index, notificationType.ApplicationNameRole) || ""),
            "body": String(model.data(index, notificationType.BodyRole) || ""),
            "created": model.data(index, notificationType.CreatedRole),
            "updated": model.data(index, notificationType.UpdatedRole),
            "icon": model.data(index, notificationType.IconNameRole)
                || model.data(index, notificationType.ApplicationIconNameRole),
            "id": model.data(index, notificationType.IdRole),
            "summary": String(model.data(index, notificationType.SummaryRole) || "")
        };
    }

    // Find banner data by notification ID
    // 按通知 ID 查找横幅数据
    function bannerDataForId(notificationId) {
        const model = root.popupModel;
        for (let row = 0; row < model.count; ++row) {
            const banner = root.bannerDataForRow(row);
            if (banner !== null && banner.id === notificationId) {
                return banner;
            }
        }

        return null;
    }

    // Find a notification row by ID
    // 按通知 ID 查找列表行
    function rowForNotificationId(notificationId) {
        const model = root.listModel;
        const notificationType = NotificationManager.Notifications;
        for (let row = 0; row < model.count; ++row) {
            if (model.data(model.index(row, 0), notificationType.IdRole) === notificationId) {
                return row;
            }
        }

        return -1;
    }

    // Close a notification by ID
    // 按 ID 关闭通知
    function closeNotificationById(notificationId) {
        const row = root.rowForNotificationId(notificationId);
        if (row >= 0) {
            root.close(row);
        }
    }

    // Trigger a notification's default action by ID
    // 按 ID 触发通知的默认操作
    function triggerNotificationById(notificationId) {
        const row = root.rowForNotificationId(notificationId);
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

        const now = Date.now();
        model.lastRead = new Date(now);

        for (let row = 0; row < model.count; ++row) {
            model.setData(model.index(row, 0), true, NotificationManager.Notifications.ReadRole);
        }

        root.lastReadMs = now;
        root.refreshCounts();
    }
}
