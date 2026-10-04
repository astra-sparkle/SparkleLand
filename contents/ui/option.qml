import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kcmutils as KCM
import org.kde.kirigami as Kirigami
import org.kde.plasma.plasmoid

// 配置页通过 cfg_<entry> 属性与 KConfig 绑定。
KCM.SimpleKCM {
    id: page

    // 与 main.xml 对应的配置项。
    property alias cfg_maximumPanelWidth: maximumWidthSpin.value
    property alias cfg_minimumPanelWidth: minimumWidthSpin.value

    property alias cfg_fontBold: fontBoldCheck.checked
    property string cfg_fontFamily: Plasmoid.configuration.fontFamily
    property alias cfg_fontItalic: fontItalicCheck.checked
    property alias cfg_fontPointSize: fontPointSizeSpin.value

    property alias cfg_mediaUseThemeBackground: mediaBackgroundCheck.checked

    property alias cfg_notificationsEnabled: notificationsEnabledCheck.checked
    property alias cfg_notificationsIncludeExpired: notificationsIncludeExpiredCheck.checked
    property alias cfg_notificationsBannerTimeout: notificationsBannerTimeoutSpin.value
    property alias cfg_notificationsMaxVisible: notificationsMaxVisibleSpin.value
    property alias cfg_notificationsShowPopups: notificationsShowPopupsCheck.checked
    property alias cfg_notificationsShowClearAll: notificationsClearAllCheck.checked
    property alias cfg_notificationsShowDoNotDisturb: notificationsDoNotDisturbCheck.checked

    property string cfg_customDateFormat: Plasmoid.configuration.customDateFormat
    property string cfg_customTimeFormat: Plasmoid.configuration.customTimeFormat
    property alias cfg_showDate: showDateCheck.checked
    property alias cfg_timeFormatMode: timeFormatModeCombo.currentIndex

    Kirigami.FormLayout {
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

        QQC2.Label {
            Kirigami.FormData.isSection: true
            text: i18n("Font")
        }

        QQC2.ComboBox {
            id: fontFamilyCombo

            Kirigami.FormData.label: i18n("Family:")
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

        QQC2.Label {
            Kirigami.FormData.isSection: true
            text: i18n("Notifications")
        }

        QQC2.CheckBox {
            id: notificationsEnabledCheck

            Kirigami.FormData.label: i18n("Notifications:")
            checked: Plasmoid.configuration.notificationsEnabled
            text: i18n("Replace the clock or calendar area with the notification list")
        }

        QQC2.CheckBox {
            id: notificationsShowPopupsCheck

            Kirigami.FormData.label: i18n("Banners:")
            checked: Plasmoid.configuration.notificationsShowPopups
            enabled: notificationsEnabledCheck.checked
            text: i18n("Show notifications as banners next to this widget")
        }

        QQC2.SpinBox {
            id: notificationsBannerTimeoutSpin

            Kirigami.FormData.label: i18n("Banner duration:")
            enabled: notificationsEnabledCheck.checked && notificationsShowPopupsCheck.checked
            from: 1
            textFromValue: function(value) {
                return i18np("%1 second", "%1 seconds", value);
            }
            to: 60
            value: Plasmoid.configuration.notificationsBannerTimeout
        }

        QQC2.Label {
            Layout.fillWidth: true
            enabled: notificationsShowPopupsCheck.checked
            font: Kirigami.Theme.smallFont
            opacity: 0.7
            text: i18n("Remove the Plasma Notifications widget from the panel, otherwise every notification is shown twice.")
            visible: notificationsShowPopupsCheck.checked
            wrapMode: Text.WordWrap
        }

        QQC2.SpinBox {
            id: notificationsMaxVisibleSpin

            Kirigami.FormData.label: i18n("Maximum shown:")
            enabled: notificationsEnabledCheck.checked
            from: 0
            textFromValue: function(value) {
                return value === 0 ? i18n("No limit") : i18n("%1 notifications", value);
            }
            to: 50
            value: Plasmoid.configuration.notificationsMaxVisible
        }

        QQC2.CheckBox {
            id: notificationsIncludeExpiredCheck

            checked: Plasmoid.configuration.notificationsIncludeExpired
            enabled: notificationsEnabledCheck.checked
            text: i18n("Keep notifications that timed out or were dismissed")
        }

        QQC2.CheckBox {
            id: notificationsDoNotDisturbCheck

            checked: Plasmoid.configuration.notificationsShowDoNotDisturb
            enabled: notificationsEnabledCheck.checked
            text: i18n("Show the do not disturb button")
        }

        QQC2.CheckBox {
            id: notificationsClearAllCheck

            checked: Plasmoid.configuration.notificationsShowClearAll
            enabled: notificationsEnabledCheck.checked
            text: i18n("Show the clear all button")
        }

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
