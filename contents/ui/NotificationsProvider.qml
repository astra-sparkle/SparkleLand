import QtQuick
import org.kde.notificationmanager as NotificationManager

// 通知数据源：包装 Plasma 6 的 NotificationManager 模块，向 Notifications.qml 提供
// 列表模型、计数、勿扰状态与操作接口。
// 与 MprisProvider 一样由 main.qml 在运行时加载，模块缺失时不影响其它功能。
QtObject {
    id: root

    // ———————————————— 由 main.qml 注入 ————————————————
    // 列表最多显示条数，0 表示不限制。
    property int maxVisible: 5
    // 是否保留已超时或被忽略的通知。
    property bool includeExpired: false

    // ———————————————— 通知设置与服务器状态 ————————————————
    // 全局通知设置，写入后由 plasmashell 的通知服务读取。
    readonly property NotificationManager.Settings settings: NotificationManager.Settings {
        onInhibitNotificationsWhenFullscreenChanged: root.refreshInhibition()
        onInhibitNotificationsWhenScreensMirroredChanged: root.refreshInhibition()
        onNotificationsInhibitedByApplicationChanged: root.refreshInhibition()
        onNotificationsInhibitedUntilChanged: root.refreshInhibition()
    }

    // 通知服务（plasmashell）是否可用。
    readonly property bool available: NotificationManager.Server.valid

    // 勿扰模式是否生效，来源包括定时抑制、应用抑制、全屏与镜像屏幕。
    property bool inhibited: false

    // ———————————————— 通知列表 ————————————————
    // 直接交给 ListView 使用的模型。
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

    // 当前列表行数与未读数量。
    readonly property int count: root.available ? root.listModel.count : 0
    readonly property int unreadCount: root.available ? root.listModel.unreadNotificationsCount : 0

    Component.onCompleted: root.refreshInhibition()

    // 供勿扰状态计算使用。
    function isValidDate(value) {
        return value instanceof Date && !isNaN(value.getTime());
    }

    // 重新计算勿扰状态；设置变化、切换之后以及定时刷新时调用。
    function refreshInhibition() {
        if (!root.available) {
            root.inhibited = false;
            return;
        }

        let value = false;

        const until = root.settings.notificationsInhibitedUntil;
        if (root.isValidDate(until) && Date.now() < until.getTime()) {
            value = true;
        }
        if (root.settings.notificationsInhibitedByApplication) {
            value = true;
        }
        if (root.settings.inhibitNotificationsWhenFullscreen && root.settings.fullscreenFocused) {
            value = true;
        }
        if (root.settings.inhibitNotificationsWhenScreensMirrored && root.settings.screensMirrored) {
            value = true;
        }

        root.inhibited = value;
    }

    // 与官方通知小组件一致的勿扰切换：启用写入一年后的时间，关闭则撤销各抑制来源。
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

    // ———————————————— 列表操作，均以行号作为参数 ————————————————
    // 关闭并移除指定通知。
    function close(row) {
        root.listModel.close(root.listModel.index(row, 0));
    }

    // 触发默认动作；没有默认动作时返回 false。
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
