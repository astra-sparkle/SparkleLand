# Sparkle Land

Sparkle Land 是一个面向 KDE Plasma 的桌面小组件（Plasma Applet），旨在为面板提供更接近 GNOME 风格的时间、日期、媒体信息和通知展示体验。

它基于 QML 和 KDE Plasma 组件开发，适用于 Plasma 6 环境，支持紧凑版和展开版界面切换，并具备系统主题适配能力。

## 项目概览

Sparkle Land 的主要目标是：

- 在面板中显示时钟与日期
- 集成媒体播放状态与歌曲信息
- 展示通知与未读消息计数
- 提供可配置的面板宽度、字体和显示样式
- 跟随系统强调色 / 主题风格进行视觉适配

## 主要功能

### 1. 时钟与日期
- 支持自定义时间格式和日期格式
- 支持 12 小时 / 24 小时制切换
- 可选择是否显示日期
- 自动根据面板高度进行字体缩放

### 2. 媒体信息
- 通过 MPRIS 集成当前播放中的音乐/媒体信息
- 展示当前播放曲目标题
- 播放状态可呈现在紧凑面板或展开视图中
- 支持主题背景和媒体状态视觉反馈

### 3. 通知中心
- 支持通知显示、未读计数、清理通知等操作
- 可设置通知最大显示数、是否显示过期通知
- 支持通知横幅弹出效果
- 可显示“勿扰”状态与“全部清除”入口

### 4. 主题适配
- 自动读取 KDE 的强调色
- 根据亮色/暗色主题动态调整文本和高亮颜色
- 支持字体、行高和布局尺寸的自适应

### 5. 面板布局
- 提供最小宽度 / 最大宽度配置
- 紧凑模式和展开模式分开处理
- 支持在面板尺寸较小时保持清晰可读的视觉效果

## 技术栈

- QML
- Qt Quick
- KDE Plasma / Kirigami
- MPRIS
- KDE Settings / kcfg

## 仓库结构

```text
SparkleLand/
├── .gitignore
├── LICENSE
├── metadata.json
├── contents/
│   ├── config/
│   │   ├── config.qml
│   │   └── main.xml
│   └── ui/
│       ├── Calender.qml
│       ├── Clock.qml
│       ├── Media.qml
│       ├── MprisProvider.qml
│       ├── Notifications.qml
│       ├── NotificationsPopup.qml
│       ├── NotificationsProvider.qml
│       ├── Panel.qml
│       ├── main.qml
│       └── option.qml
└── README.md