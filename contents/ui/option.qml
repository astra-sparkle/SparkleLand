import QtQuick
import QtQuick.Controls as QQC2
import org.kde.kcmutils as KCM
import org.kde.kirigami as Kirigami
import org.kde.plasma.plasmoid

// 配置页（Plasma 标准写法，对照官方 org.kde.desktopcontainment/contents/ui/Config*.qml）：
//   - 根必须是 KCM.SimpleKCM，表单放在其中的 Kirigami.FormLayout 里；
//   - 每个键都暴露为 cfg_<contents/config/main.xml 里的 entry 名>，
//     由配置对话框负责把值写回 KConfig，「应用」按钮的可用状态也由这些属性的变化驱动；
//   - ✗ 绝对不要直接写 plasmoid.configuration.*：那样对话框认为"没有任何改动"，
//     「应用」按钮会一直是灰的（这就是之前点不动的原因）；
//   - 初值用 Plasmoid.configuration.<entry> 读取，用户改动后由对话框写回。
KCM.SimpleKCM {
    id: page

    // ———————————————— 键（与 main.xml 一一对应）————————————————
    property alias cfg_maximumPanelWidth: maximumWidthSpin.value
    property alias cfg_minimumPanelWidth: minimumWidthSpin.value

    property alias cfg_fontBold: fontBoldCheck.checked
    property string cfg_fontFamily: Plasmoid.configuration.fontFamily
    property alias cfg_fontItalic: fontItalicCheck.checked
    property alias cfg_fontPointSize: fontPointSizeSpin.value

    property alias cfg_mediaUseThemeBackground: mediaBackgroundCheck.checked

    property string cfg_customDateFormat: Plasmoid.configuration.customDateFormat
    property string cfg_customTimeFormat: Plasmoid.configuration.customTimeFormat
    property alias cfg_showDate: showDateCheck.checked
    property alias cfg_timeFormatMode: timeFormatModeCombo.currentIndex

    Kirigami.FormLayout {
        // ———————————————— 面板宽度 ————————————————
        QQC2.Label {
            Kirigami.FormData.isSection: true
            text: i18n("Panel")
        }

        QQC2.SpinBox {
            id: minimumWidthSpin

            Kirigami.FormData.label: i18n("Minimum width:")
            from: 16
            to: Math.max(16, page.cfg_maximumPanelWidth)
            value: Plasmoid.configuration.minimumPanelWidth
        }

        QQC2.SpinBox {
            id: maximumWidthSpin

            Kirigami.FormData.label: i18n("Maximum width:")
            from: Math.max(16, page.cfg_minimumPanelWidth)
            to: 2048
            value: Plasmoid.configuration.maximumPanelWidth
        }

        // ———————————————— 字体 ————————————————
        QQC2.Label {
            Kirigami.FormData.isSection: true
            text: i18n("Font")
        }

        QQC2.ComboBox {
            id: fontFamilyCombo

            Kirigami.FormData.label: i18n("Family:")
            // 第一项表示「跟随系统」（对应空字符串）
            currentIndex: Math.max(0, model.indexOf(page.cfg_fontFamily))
            model: [i18n("Follow system")].concat(Qt.fontFamilies())
            onActivated: page.cfg_fontFamily = currentIndex === 0 ? "" : currentText
        }

        QQC2.SpinBox {
            id: fontPointSizeSpin

            Kirigami.FormData.label: i18n("Size:")
            from: 0
            textFromValue: function(value) {
                return value === 0 ? i18n("Follow system") : i18n("%1 pt", value);
            }
            to: 72
            value: Plasmoid.configuration.fontPointSize
        }

        QQC2.CheckBox {
            id: fontBoldCheck

            checked: Plasmoid.configuration.fontBold
            text: i18n("Bold")
        }

        QQC2.CheckBox {
            id: fontItalicCheck

            checked: Plasmoid.configuration.fontItalic
            text: i18n("Italic")
        }

        // ———————————————— 媒体面板 ————————————————
        QQC2.Label {
            Kirigami.FormData.isSection: true
            text: i18n("Media")
        }

        QQC2.CheckBox {
            id: mediaBackgroundCheck

            Kirigami.FormData.label: i18n("Background:")
            checked: Plasmoid.configuration.mediaUseThemeBackground
            text: i18n("Use the theme highlight color as background while playing")
        }

        // ———————————————— 时间与日期 ————————————————
        QQC2.Label {
            Kirigami.FormData.isSection: true
            text: i18n("Time and date")
        }

        QQC2.ComboBox {
            id: timeFormatModeCombo

            Kirigami.FormData.label: i18n("Clock:")
            currentIndex: Plasmoid.configuration.timeFormatMode
            model: [i18n("Follow system"), i18n("12-hour"), i18n("24-hour")]
        }

        QQC2.TextField {
            Kirigami.FormData.label: i18n("Custom time format:")
            placeholderText: i18n("Empty: use the setting above")
            text: page.cfg_customTimeFormat
            onTextEdited: page.cfg_customTimeFormat = text
        }

        QQC2.CheckBox {
            id: showDateCheck

            Kirigami.FormData.label: i18n("Date:")
            checked: Plasmoid.configuration.showDate
            text: i18n("Show the date next to the time")
        }

        QQC2.TextField {
            Kirigami.FormData.label: i18n("Date format:")
            placeholderText: i18n("Empty: follow system")
            text: page.cfg_customDateFormat
            onTextEdited: page.cfg_customDateFormat = text
        }
    }
}
