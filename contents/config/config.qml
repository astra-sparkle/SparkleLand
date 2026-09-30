import QtQuick
import org.kde.plasma.configuration

ConfigModel {
    ConfigCategory {
        icon: "preferences-desktop-theme"
        name: i18nc("@title:group for configuration dialog page", "General")
        source: "option.qml" // 路径相对于 contents/ui。
    }
}
