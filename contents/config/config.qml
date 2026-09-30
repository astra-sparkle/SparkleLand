import QtQuick
import org.kde.plasma.configuration

// 声明 applet 设置页，由 Plasma 处理应用和保存。
ConfigModel {
    ConfigCategory {
        icon: "preferences-desktop-theme"
        name: i18nc("@title:group for configuration dialog page", "General")
        source: "option.qml"
    }
}
