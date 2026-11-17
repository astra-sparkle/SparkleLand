import QtQuick
import "Providers" as ProvidersDir

// Feature provider registry: the only entry point to the Providers directory
// 功能提供器注册中心：Providers 目录下组件的唯一入口
QtObject {
    id: root

    // Palette forwarded from the applet shell
    // 由小组件外壳转发的调色板
    property var palette

    // Shared theme adapter, created here so no consumer imports the Providers
    // directory and collides with same-named visual components
    // 共享主题适配器；在此创建，使消费者无需导入 Providers 目录，
    // 避免与同名视觉组件发生命名冲突
    readonly property var theme: ProvidersDir.Theme {
        palette: root.palette
    }

    // Feature settings forwarded from the applet shell
    // 由小组件外壳转发的功能配置
    property bool notificationsEnabled: true
    property int notificationsMaxVisible: 5
    property bool notificationsIncludeExpired: true

    // SPlayer-Next serves the socket and the HTTP API on one port
    // SPlayer-Next 在同一端口提供套接字与 HTTP 接口
    property string splayerUrl: "ws://127.0.0.1:14558/ws"

    // Missing MPRIS only disables the media provider
    // 缺失 MPRIS 仅禁用媒体功能
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
        // Raw MPRIS player, reused by the lyric backend for position events
        // 原始 MPRIS 播放器，供歌词后端复用位置事件
        readonly property var player: mediaSource.provider !== null ? mediaSource.provider.currentPlayer : null

        Component.onCompleted: mediaSource.loadProvider()

        // Load the implementation at runtime so its module import stays optional
        // 运行时加载实现，使其模块导入保持可选
        function loadProvider() {
            if (mediaSource.state !== 0) {
                return;
            }

            const providerComponent = Qt.createComponent("Providers/Media.qml");
            if (providerComponent.status === Component.Loading) {
                // Drop the handler once loading ends so retries cannot stack callbacks
                // 加载结束后断开回调，避免重复加载叠加监听
                const onStatusChanged = function() {
                    if (providerComponent.status === Component.Loading) {
                        return;
                    }
                    providerComponent.statusChanged.disconnect(onStatusChanged);
                    mediaSource.installProvider(providerComponent);
                };
                providerComponent.statusChanged.connect(onStatusChanged);
                return;
            }
            mediaSource.installProvider(providerComponent);
        }

        function installProvider(providerComponent) {
            if (mediaSource.provider !== null) {
                return;
            }
            if (providerComponent.status === Component.Error) {
                mediaSource.state = -1;
                console.info("[Sparkle Land] MPRIS 不可用，面板只显示时钟：", providerComponent.errorString());
                return;
            }
            if (providerComponent.status !== Component.Ready) {
                return;
            }

            const providerInstance = providerComponent.createObject(mediaSource);
            if (!providerInstance) {
                mediaSource.state = -1;
                console.warn("[Sparkle Land] MPRIS 组件实例化失败：", providerComponent.errorString());
                return;
            }

            mediaSource.provider = providerInstance;
            mediaSource.state = 1;
            console.info("[Sparkle Land] 私有 MPRIS 实现已生效");
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
                // Drop the handler once loading ends so retries cannot stack callbacks
                // 加载结束后断开回调，避免重复加载叠加监听
                const onStatusChanged = function() {
                    if (providerComponent.status === Component.Loading) {
                        return;
                    }
                    providerComponent.statusChanged.disconnect(onStatusChanged);
                    notificationSource.installProvider(providerComponent);
                };
                providerComponent.statusChanged.connect(onStatusChanged);
                return;
            }
            notificationSource.installProvider(providerComponent);
        }

        function installProvider(providerComponent) {
            if (notificationSource.provider !== null) {
                return;
            }
            if (providerComponent.status === Component.Error) {
                notificationSource.state = -1;
                console.info("[Sparkle Land] 通知服务不可用：", providerComponent.errorString());
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
                console.warn("[Sparkle Land] 通知组件实例化失败：", providerComponent.errorString());
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
            console.info("[Sparkle Land] 私有通知实现已生效");
        }
    }

    // Lyrics are filled by the SPlayer backend and need no external import
    // 歌词由 SPlayer 后端填充，无需外部模块
    readonly property var lyrics: ProvidersDir.Lyrics {
        id: lyricsProvider
    }

    // Missing QtWebSockets only disables the SPlayer feature
    // 缺失 QtWebSockets 仅禁用 SPlayer 功能
    readonly property var splayer: QtObject {
        id: splayerSource

        // 0 = unchecked, 1 = available, -1 = unavailable
        // 0 = 未检测，1 = 可用，-1 = 不可用
        property int state: 0
        property var provider: null

        readonly property bool available: splayerSource.provider !== null && splayerSource.provider.connected
        readonly property bool playing: splayerSource.provider !== null && splayerSource.provider.playing
        readonly property string songTitle: splayerSource.provider !== null ? splayerSource.provider.songTitle : ""
        readonly property string artistName: splayerSource.provider !== null ? splayerSource.provider.artistName : ""
        readonly property string albumName: splayerSource.provider !== null ? splayerSource.provider.albumName : ""
        readonly property string coverUrl: splayerSource.provider !== null ? splayerSource.provider.coverUrl : ""
        readonly property real position: splayerSource.provider !== null ? splayerSource.provider.position : 0
        readonly property real duration: splayerSource.provider !== null ? splayerSource.provider.duration : 0

        Component.onCompleted: splayerSource.loadProvider()

        // Load the implementation at runtime so its module import stays optional
        // 运行时加载实现，使其模块导入保持可选
        function loadProvider() {
            if (splayerSource.state !== 0) {
                return;
            }

            const backendComponent = Qt.createComponent("Providers/SPlayer_Next-backend.qml");
            if (backendComponent.status === Component.Loading) {
                // Drop the handler once loading ends so retries cannot stack callbacks
                // 加载结束后断开回调，避免重复加载叠加监听
                const onStatusChanged = function() {
                    if (backendComponent.status === Component.Loading) {
                        return;
                    }
                    backendComponent.statusChanged.disconnect(onStatusChanged);
                    splayerSource.installProvider(backendComponent);
                };
                backendComponent.statusChanged.connect(onStatusChanged);
                return;
            }
            splayerSource.installProvider(backendComponent);
        }

        function installProvider(backendComponent) {
            if (splayerSource.provider !== null) {
                return;
            }
            if (backendComponent.status === Component.Error) {
                splayerSource.state = -1;
                console.info("[Sparkle Land] SPlayer-Next 后端不可用：", backendComponent.errorString());
                return;
            }
            if (backendComponent.status !== Component.Ready) {
                return;
            }

            const backendInstance = backendComponent.createObject(splayerSource, {
                "url": root.splayerUrl
            });
            if (!backendInstance) {
                splayerSource.state = -1;
                console.warn("[Sparkle Land] SPlayer-Next 组件实例化失败：", backendComponent.errorString());
                return;
            }

            // Feed the lyric provider without importing it from the backend
            // 向歌词提供器下发数据，后端无需导入该组件
            backendInstance.lyrics = root.lyrics;
            // Reuse the MPRIS player already loaded by the media provider
            // 复用媒体提供器已加载的 MPRIS 播放器
            backendInstance.positionPlayer = Qt.binding(function() {
                return root.media.player;
            });

            splayerSource.provider = backendInstance;
            splayerSource.state = 1;
            console.info("[Sparkle Land] SPlayer-Next 后端已就绪");
        }

        function toggle() {
            if (splayerSource.provider !== null) {
                splayerSource.provider.toggle();
            }
        }

        function play() {
            if (splayerSource.provider !== null) {
                splayerSource.provider.play();
            }
        }

        function pause() {
            if (splayerSource.provider !== null) {
                splayerSource.provider.pause();
            }
        }

        function next() {
            if (splayerSource.provider !== null) {
                splayerSource.provider.next();
            }
        }

        function previous() {
            if (splayerSource.provider !== null) {
                splayerSource.provider.previous();
            }
        }
    }
}
