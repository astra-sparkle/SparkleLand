import QtQuick
import org.kde.plasma.configuration



// Applet settings page; Plasma handles loading and saving
// 小组件设置页，由 Plasma 负责加载与保存
ConfigModel {
    ConfigCategory {
        icon: "preferences-desktop-theme"
        name: i18nc("@title:group for configuration dialog page", "General")
        // Category sources resolve against contents/ui, so reach back into config
        // 配置页的 source 以 contents/ui 为基准，因此需指回 config 目录
        source: "../config/option.qml"
    }
}
