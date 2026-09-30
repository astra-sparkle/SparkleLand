import QtQuick
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami

// 设置页：由 contents/config/config.qml 加载，运行在 plasmashell 的标准配置对话框里。
// 所有键与默认值定义在 contents/config/main.xml，这里通过 plasmoid.configuration 读写。
//
// 「绑定读取 + onXxx 回写」是 Plasma 配置页的标准写法：
// 保存时 plasmashell 会把配置写回 KConfig，随后 main.qml 中挂在
// plasmoid.configuration 上的绑定自动重新求值 —— 于是「每次启动或保存设置时应用设置」是天然的。
Kirigami.FormLayout {
    id: page

    // ———————————————— 面板宽度 ————————————————
    QQC2.Label {
        Kirigami.FormData.isSection: true
        text: i18n("Panel")
    }

    QQC2.SpinBox {
        id: minimumWidthSpin

        Kirigami.FormData.label: i18n("Minimum width:")
        from: 16
        to: Math.max(16, plasmoid.configuration.maximumPanelWidth)
        value: plasmoid.configuration.minimumPanelWidth
        onValueModified: plasmoid.configuration.minimumPanelWidth = value
    }

    QQC2.SpinBox {
        Kirigami.FormData.label: i18n("Maximum width:")
        from: Math.max(16, plasmoid.configuration.minimumPanelWidth)
        to: 2048
        value: plasmoid.configuration.maximumPanelWidth
        onValueModified: plasmoid.configuration.maximumPanelWidth = value
    }

    // ———————————————— 字体 ————————————————
    QQC2.Label {
        Kirigami.FormData.isSection: true
        text: i18n("Font")
    }

    QQC2.CheckBox {
        id: customFontCheck

        Kirigami.FormData.label: i18n("Panel font:")
        checked: plasmoid.configuration.fontFamily.length > 0 || plasmoid.configuration.fontPointSize > 0
        text: i18n("Use a custom font")
        onToggled: {
            if (!checked) {
                plasmoid.configuration.fontFamily = "";
                plasmoid.configuration.fontPointSize = 0;
            }
        }
    }

    QQC2.ComboBox {
        id: fontFamilyCombo

        Kirigami.FormData.label: i18n("Family:")
        currentIndex: {
            const index = model.indexOf(plasmoid.configuration.fontFamily);
            return index >= 0 ? index : 0;
        }
        enabled: customFontCheck.checked
        model: Qt.fontFamilies()
        onActivated: plasmoid.configuration.fontFamily = currentText
    }

    QQC2.SpinBox {
        Kirigami.FormData.label: i18n("Size:")
        enabled: customFontCheck.checked
        from: 0
        textFromValue: function(value) {
            return value === 0 ? i18n("Default") : i18n("%1 pt", value);
        }
        to: 72
        value: plasmoid.configuration.fontPointSize
        onValueModified: plasmoid.configuration.fontPointSize = value
    }

    QQC2.CheckBox {
        text: i18n("Bold")
        checked: plasmoid.configuration.fontBold
        onToggled: plasmoid.configuration.fontBold = checked
    }

    QQC2.CheckBox {
        text: i18n("Italic")
        checked: plasmoid.configuration.fontItalic
        onToggled: plasmoid.configuration.fontItalic = checked
    }

    // ———————————————— 媒体面板 ————————————————
    QQC2.Label {
        Kirigami.FormData.isSection: true
        text: i18n("Media")
    }

    QQC2.CheckBox {
        Kirigami.FormData.label: i18n("Background:")
        checked: plasmoid.configuration.mediaUseThemeBackground
        text: i18n("Use the theme highlight color as background while playing")
        onToggled: plasmoid.configuration.mediaUseThemeBackground = checked
    }

    // ———————————————— 时间与日期 ————————————————
    QQC2.Label {
        Kirigami.FormData.isSection: true
        text: i18n("Time and date")
    }

    QQC2.ComboBox {
        id: timeFormatModeCombo

        Kirigami.FormData.label: i18n("Clock:")
        currentIndex: plasmoid.configuration.timeFormatMode
        model: [i18n("Follow system"), i18n("12-hour"), i18n("24-hour")]
        onActivated: plasmoid.configuration.timeFormatMode = currentIndex
    }

    QQC2.TextField {
        Kirigami.FormData.label: i18n("Custom time format:")
        placeholderText: i18n("Empty: use the setting above")
        text: plasmoid.configuration.customTimeFormat
        onTextEdited: plasmoid.configuration.customTimeFormat = text
    }

    QQC2.CheckBox {
        Kirigami.FormData.label: i18n("Date:")
        checked: plasmoid.configuration.showDate
        text: i18n("Show the date next to the time")
        onToggled: plasmoid.configuration.showDate = checked
    }

    QQC2.TextField {
        Kirigami.FormData.label: i18n("Date format:")
        placeholderText: i18n("Empty: follow system")
        text: plasmoid.configuration.customDateFormat
        onTextEdited: plasmoid.configuration.customDateFormat = text
    }
}
