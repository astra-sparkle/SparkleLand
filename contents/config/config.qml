import QtQuick
import org.kde.plasma.configuration

// Plasma 标准配置模型：声明配置页，「确定/应用」由 plasmashell 统一处理。
// - ConfigCategory.source 相对 contents/ui/ 解析（已对照官方 org.kde.desktopcontainment
//   与本机两个第三方插件确认），所以页面本体是 contents/ui/option.qml；
// - 页面必须按 KCM 约定写（KCM.SimpleKCM + cfg_<entry> 属性），见 option.qml 顶部说明。
ConfigModel {
    ConfigCategory {
        icon: "preferences-desktop-theme"
        name: i18nc("@title:group for configuration dialog page", "General")
        source: "option.qml"
    }
}
