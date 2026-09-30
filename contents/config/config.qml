import QtQuick
import org.kde.plasma.configuration

// Plasma 标准配置模型：声明配置页，「确定/应用」由 plasmashell 统一处理。
// 注意：ConfigCategory.source 是**相对 contents/ui/** 解析的（已对照本机两个第三方
// Plasma 6 插件的写法确认），所以页面本体在 contents/ui/option.qml。
ConfigModel {
    ConfigCategory {
        icon: "preferences-desktop-theme"
        name: i18n("General")
        source: "option.qml"
    }
}
