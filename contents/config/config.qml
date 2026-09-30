import QtQuick
import org.kde.plasma.configuration

// Plasma 标准配置模型：声明配置页，「确定/应用」由 plasmashell 统一处理。
// 页面本体见同目录下的 option.qml（Plasma 约定：配置页放在 contents/config/ 下并写相对文件名）。
ConfigModel {
    ConfigCategory {
        icon: "preferences-desktop-theme"
        name: i18n("General")
        source: "option.qml"
    }
}
