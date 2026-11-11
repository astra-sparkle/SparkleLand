import QtQuick

// Feature provider registry.
// 功能提供器注册中心。
QtObject {
    id: root

    // Feature settings forwarded from the applet shell.
    // 由小组件外壳转发的功能配置。
    property bool notificationsEnabled: true
    property int notificationsMaxVisible: 5
    property bool notificationsIncludeExpired: true

    // Missing MPRIS only disables the media provider.
    // 缺失 MPRIS 仅禁用媒体功能。
    readonly property var media: QtObject {
        id: mediaSource

        // 0 = unchecked, 1 = available, -1 = unavailable
        // 0 = 未检测，1 = 可用，-1 = 不可用
        property int state: 0
        property var provider: null

        readonly property bool available: mediaSource.state === 1
        readonly property string trackTitle: mediaSource.provider !== null ? mediaSource.provider.trackTitle : ""
        // Album artwork exposed for both the compact cover and the expanded panel
        // 专辑封面同时供紧凑封面与展开面板使用
        readonly property string artUrl: mediaSource.provider !== null ? mediaSource.provider.artUrl : ""
        readonly property bool playing: mediaSource.provider !== null && mediaSource.provider.playing

        Component.onCompleted: mediaSource.loadProvider()

        // Load the implementation at runtime so its module import stays optional
        // 运行时加载实现，使其模块导入保持可选
        function loadProvider() {
            if (mediaSource.state !== 0) {
                return;
            }

            const providerComponent = Qt.createComponent("Providers/Media.qml");
            if (providerComponent.status === Component.Loading) {
                providerComponent.statusChanged.connect(function() {
                    mediaSource.installProvider(providerComponent);
                });
                return;
            }
            mediaSource.installProvider(providerComponent);
        }

        function installProvider(providerComponent) {
            if (providerComponent.status === Component.Error) {
                mediaSource.state = -1;
                console.info("Sparkle Land: MPRIS 不可用，面板只显示时钟：", providerComponent.errorString());
                return;
            }
            if (providerComponent.status !== Component.Ready) {
                return;
            }

            const providerInstance = providerComponent.createObject(mediaSource);
            if (!providerInstance) {
                mediaSource.state = -1;
                console.warn("Sparkle Land: MPRIS 组件实例化失败：", providerComponent.errorString());
                return;
            }

            mediaSource.provider = providerInstance;
            mediaSource.state = 1;
            console.info("Sparkle Land: 私有 MPRIS 实现已生效");
        }
    }

    // Missing notifications only disables the notifications feature
    // 缺失通知模块仅禁用通知功能
    readonly property var notifications: QtObject {
        id: notificationSource

        // Configuration forwarded by Providers
        // 由 Providers 转发的配置
        property bool enabled: root.notificationsEnabled
        property int maxVisible: root.notificationsMaxVisible
        property bool includeExpired: root.notificationsIncludeExpired

        // 0 = unchecked, 1 = available, -1 = unavailable
        // 0 = 未检测，1 = 可用，-1 = 不可用
        property int state: 0
        property var provider: null

        // Counters are copied through signals, never bound to the lazily created model
        // 计数通过信号复制，不绑定到惰性创建的模型
        property int count: 0
        property int unreadCount: 0
        readonly property bool hasNotifications: notificationSource.count > 0

        // Watch the data source so counts stay current without a binding
        // 监听数据源，使计数无需绑定即可保持最新
        readonly property Connections providerWatcher: Connections {
            target: notificationSource.provider

            function onCountChanged() {
                notificationSource.refreshCounts();
            }
            function onUnreadCountChanged() {
                notificationSource.refreshCounts();
            }
        }

        Component.onCompleted: {
            if (notificationSource.enabled) {
                notificationSource.loadProvider();
            }
        }

        // Load the service when the feature is switched back on
        // 功能重新开启时加载服务
        onEnabledChanged: {
            if (notificationSource.enabled) {
                notificationSource.loadProvider();
            }
            notificationSource.refreshCounts();
        }

        function refreshCounts() {
            const active = notificationSource.enabled && notificationSource.provider !== null;
            notificationSource.count = active ? notificationSource.provider.count : 0;
            notificationSource.unreadCount = active ? notificationSource.provider.unreadCount : 0;
        }

        // Load the implementation at runtime so its module import stays optional
        // 运行时加载实现，使其模块导入保持可选
        function loadProvider() {
            if (notificationSource.state !== 0) {
                return;
            }

            const providerComponent = Qt.createComponent("Providers/Notification.qml");
            if (providerComponent.status === Component.Loading) {
                providerComponent.statusChanged.connect(function() {
                    notificationSource.installProvider(providerComponent);
                });
                return;
            }
            notificationSource.installProvider(providerComponent);
        }

        function installProvider(providerComponent) {
            if (providerComponent.status === Component.Error) {
                notificationSource.state = -1;
                console.info("Sparkle Land: 通知服务不可用：", providerComponent.errorString());
                return;
            }
            if (providerComponent.status !== Component.Ready) {
                return;
            }

            const providerInstance = providerComponent.createObject(notificationSource, {
                "includeExpired": notificationSource.includeExpired,
                "maxVisible": notificationSource.maxVisible
            });
            if (!providerInstance) {
                notificationSource.state = -1;
                console.warn("Sparkle Land: 通知组件实例化失败：", providerComponent.errorString());
                return;
            }

            // Propagate config changes without reloading the applet
            // 配置变化时同步给数据源，无需重载小组件
            providerInstance.includeExpired = Qt.binding(function() {
                return notificationSource.includeExpired;
            });
            providerInstance.maxVisible = Qt.binding(function() {
                return notificationSource.maxVisible;
            });

            // Initialize models here, not in bindings, to avoid loops from synchronous lazy-init signals
            // 在此初始化模型而非绑定中触碰，避免惰性初始化信号造成绑定循环
            providerInstance.initialize();

            notificationSource.provider = providerInstance;
            notificationSource.state = 1;
            notificationSource.refreshCounts();
            console.info("Sparkle Land: 私有通知实现已生效");
        }
    }
}
