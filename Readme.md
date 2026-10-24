# Sparkle Land

Sparkle Land 是一个面向 KDE Plasma 的桌面小组件（Plasma Applet），旨在为面板提供更接近 GNOME 风格的时间、日期、媒体信息和通知展示体验。

由于开发者正在使用滚动更新的Linux，故Sparkle Land会始终基于更新的Qt与Plasma开发。 

100%QML!

## 功能
- 正在播放
- 时钟
- 通知（不稳定）
- 月历

## QA
- 为什么不使用kirigami而是qpalette：kirigami默认从配色方案取色，而部分旧的主题（如Orchis）并没有依照最新标准允许动态的accent color。这导致HighlightColor会取色到默认的Plasma蓝色。
- 通知功能不稳定：暂不考虑优化。由于KDE官方通知功能绑定自身组件，为了不破坏桌面环境，故不考虑强行接管。但未来会考虑提供通知管理器接口。
