import QtQuick
import org.kde.plasma.configuration



// Applet settings page. Plasma handles loading and saving.
// 小组件设置页；由 Plasma 处理加载与保存。
ConfigModel {
    ConfigCategory {
        icon: "preferences-desktop-theme"
        name: i18nc("@title:group for configuration dialog page", "General")
        source: "option.qml"
    }
}
