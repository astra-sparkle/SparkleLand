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
    property bool includeExpired: true

    // ———————————————— 通知设置与服务器状态 ————————————————
    // 全局通知设置，写入后由 plasmashell 的通知服务读取。
    readonly property NotificationManager.Settings settings: NotificationManager.Settings {
        onInhibitNotificationsWhenFullscreenChanged: root.refreshInhibition()
        onInhibitNotificationsWhenScreensMirroredChanged: root.refreshInhibition()
        onNotificationsInhibitedByApplicationChanged: root.refreshInhibition()
        onNotificationsInhibitedUntilChanged: root.refreshInhibition()
    }

    // 通知服务是否可用：本实例注册成功，或已有其它组件（例如官方通知小组件）在提供服务。
    // 该值一律由 refreshAvailability() 主动求值，禁止在绑定里读取 Server：
    // 首次访问会创建该单例并同步发出 validChanged，使依赖本属性的绑定被判为循环
    // （曾导致列表在收到下一条新通知前一直显示为空）。
    property bool available: false

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

    // ———————————————— 自建横幅 ————————————————
    // 新通知到达时通知横幅组件，参数为通知 id。
    signal bannerRequested(int notificationId)

    // 横幅专用模型：只含当前有效、不在勿扰抑制期加入且符合勿扰规则的通知。
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

    // 当前列表行数与未读数量。读取模型的属性会在首次访问时触发其内部初始化并同步发出
    // 变化信号，因此在绑定里读取会被判为绑定循环、把值冻结在 0（现象：面板一直显示空列表）。
    // 因此改为普通属性，由 listWatcher 与 refreshCounts() 维护。
    property int count: 0
    property int unreadCount: 0

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

    // 初始化完成后才允许弹出横幅，避免启动阶段对历史通知误报。
    property bool bannerReady: false

    // 监听新到达的通知；排序抖动与历史条目由 isRecent 过滤掉。
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

    // 由 main.qml 在注入配置后调用一次，作为唯一的初始化入口：
    // 首次触碰 Server 单例与各模型的操作都发生在这里（而不是绑定中），
    // 避免惰性初始化期间的同步信号造成绑定循环。
    function activate() {
        root.refreshInhibition();
        root.refreshCounts();
        root.bannerReady = true;
    }

    // 刷新列表行数与未读数。
    function refreshCounts() {
        root.count = root.available ? root.listModel.count : 0;
        root.unreadCount = root.available ? root.listModel.unreadNotificationsCount : 0;
    }

    // 横幅可见的紧急级别；勿扰时只保留紧急通知，与官方浮动通知的取舍一致。
    property int bannerUrgencies: 0

    // 读取通知服务状态。模型由 plasmashell 进程内的通知服务填充，只要服务在运行即可读到数据；
    // 不能只看 valid（它仅表示本单例是否抢到了 DBus 名称）。
    function refreshAvailability() {
        const server = NotificationManager.Server;
        root.available = server.valid
            || server.currentOwner.status === NotificationManager.ServerInfo.Running;
    }

    // 依据勿扰状态计算横幅可见的紧急级别。
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

    // 只在通知刚到达时提示。
    function isRecent(created) {
        return (created instanceof Date) && !isNaN(created.getTime()) && (Date.now() - created.getTime() < 15000);
    }

    // 读取指定行的横幅数据；行无效时返回 null。
    function bannerFor(row) {
        if (row < 0 || row >= root.popupModel.count) {
            return null;
        }

        const N = NotificationManager.Notifications;
        const index = root.popupModel.index(row, 0);
        return {
            "applicationName": String(root.popupModel.data(index, N.ApplicationNameRole) || ""),
            "body": String(root.popupModel.data(index, N.BodyRole) || ""),
            "created": root.popupModel.data(index, N.CreatedRole),
            "icon": root.popupModel.data(index, N.IconNameRole) || root.popupModel.data(index, N.ApplicationIconNameRole),
            "id": root.popupModel.data(index, N.IdRole),
            "summary": String(root.popupModel.data(index, N.SummaryRole) || "")
        };
    }

    // 按通知 id 查找横幅数据；已不在模型中时返回 null。
    function bannerForId(notificationId) {
        for (let row = 0; row < root.popupModel.count; ++row) {
            const banner = root.bannerFor(row);
            if (banner !== null && banner.id === notificationId) {
                return banner;
            }
        }

        return null;
    }

    // 供勿扰状态计算使用。
    function isValidDate(value) {
        return value instanceof Date && !isNaN(value.getTime());
    }

    // 重新计算服务状态与勿扰状态；启动、设置变化、切换之后以及定时刷新时调用。
    function refreshInhibition() {
        root.refreshAvailability();

        let value = false;

        if (root.available) {
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
        }

        root.inhibited = value;
        root.refreshBannerUrgencies();
        root.refreshCounts();
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
