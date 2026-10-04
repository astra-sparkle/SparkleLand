import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.ksvg as KSvg

// 通知中心：显示当前通知列表，并提供勿扰开关与清除操作。
// 数据来自 NotificationsProvider，主题与配置由 main.qml 注入。
Item {
    id: root

    // ———————————————— 由 main.qml 注入 ————————————————
    property var theme
    property var provider
    property bool showDoNotDisturb: true
    property bool showClearAll: true

    // 相对时间的刷新计数，由下方定时器递增。
    property int timeTick

    // 分页场景下本组件会一直构建。该属性表示“当前是否轮到本页面对用户展示”。
    // 只有真正在前台才标记已读，避免用户在看日历页时未读被清空。
    property bool pageActive: true
    // 真正对用户可见 = 自身可见，且所属分页在前台。
    readonly property bool effectiveActive: root.visible && root.pageActive

    readonly property bool available: root.provider !== null && root.provider.available
    readonly property bool inhibited: root.provider !== null && root.provider.inhibited
    // 紧急通知的枚举值，用于按主题的警告色着色。
    readonly property int criticalUrgency: root.provider !== null ? root.provider.criticalUrgency : -1

    readonly property int gap: Math.round(root.theme.gridUnit / 3)
    readonly property int buttonSize: Math.round(root.theme.gridUnit * 1.5)

    readonly property font headerFont: Qt.font({
        "bold": true,
        "family": root.theme.defaultFont.family,
        "pointSize": root.theme.defaultFont.pointSize
    })

    readonly property font bodyFont: Qt.font({
        "family": root.theme.defaultFont.family,
        "pointSize": Math.max(1, root.theme.defaultFont.pointSize - 1)
    })

    // 把时间格式化为「刚刚 / n 分钟前 / n 小时前 / n 天前」。
    function relativeTime(value) {
        root.timeTick;

        if (!(value instanceof Date) || isNaN(value.getTime())) {
            return "";
        }

        const seconds = Math.max(0, Math.round((Date.now() - value.getTime()) / 1000));
        if (seconds < 60) {
            return i18n("Just now");
        }

        const minutes = Math.floor(seconds / 60);
        if (minutes < 60) {
            return i18np("%1 min ago", "%1 min ago", minutes);
        }

        const hours = Math.floor(minutes / 60);
        if (hours < 24) {
            return i18np("%1 hour ago", "%1 hours ago", hours);
        }

        return i18np("%1 day ago", "%1 days ago", Math.floor(hours / 24));
    }

    // 展开时标记已读并同步勿扰状态；首次创建时同样执行一次。
    function refresh() {
        if (root.provider === null) {
            return;
        }

        root.provider.refreshInhibition();
        root.provider.markAllRead();
    }

    onEffectiveActiveChanged: if (root.effectiveActive) {
        root.refresh();
    }

    Component.onCompleted: if (root.effectiveActive) {
        root.refresh();
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: root.gap

        // ———————————————— 顶部：标题、勿扰与清除 ————————————————
        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: root.buttonSize
            spacing: root.gap

            Text {
                Layout.fillWidth: true
                color: root.theme.textColor
                elide: Text.ElideRight
                font: root.headerFont
                text: i18n("Notifications")
                verticalAlignment: Text.AlignVCenter
            }

            // 勿扰开关。
            Item {
                id: doNotDisturbButton

                Layout.preferredHeight: root.buttonSize
                Layout.preferredWidth: root.buttonSize
                visible: root.showDoNotDisturb && root.available

                // 按钮外观取自桌面主题的 button 元素，随主题切换自动变化。
                KSvg.FrameSvgItem {
                    anchors.fill: parent
                    imagePath: "widgets/button"
                    prefix: root.inhibited ? "toolbutton-pressed" : "toolbutton-hover"
                    visible: root.inhibited || doNotDisturbMouse.containsMouse
                }

                Kirigami.Icon {
                    anchors.centerIn: parent
                    height: Math.round(parent.height * 0.8)
                    opacity: root.inhibited ? 1 : 0.7
                    source: "notifications-disabled"
                    width: height
                }

                MouseArea {
                    id: doNotDisturbMouse

                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: if (root.provider !== null) {
                        root.provider.toggleInhibition();
                    }
                }
            }

            // 清除全部。
            Item {
                id: clearAllButton

                Layout.preferredHeight: root.buttonSize
                Layout.preferredWidth: root.buttonSize
                visible: root.showClearAll && notificationList.count > 0

                KSvg.FrameSvgItem {
                    anchors.fill: parent
                    imagePath: "widgets/button"
                    prefix: "toolbutton-hover"
                    visible: clearAllMouse.containsMouse
                }

                Kirigami.Icon {
                    anchors.centerIn: parent
                    height: Math.round(parent.height * 0.8)
                    opacity: clearAllMouse.containsMouse ? 1 : 0.7
                    source: "edit-clear-history"
                    width: height
                }

                MouseArea {
                    id: clearAllMouse

                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: if (root.provider !== null) {
                        root.provider.clearAll();
                    }
                }
            }
        }

        // 勿扰生效时的说明。
        Text {
            Layout.fillWidth: true
            color: root.theme.disabledTextColor
            elide: Text.ElideRight
            font: root.bodyFont
            maximumLineCount: 1
            text: i18n("Do not disturb is active")
            visible: root.inhibited
        }

        // ———————————————— 通知列表 ————————————————
        Item {
            Layout.fillHeight: true
            Layout.fillWidth: true

            ListView {
                id: notificationList

                anchors.fill: parent
                clip: true
                model: root.provider !== null ? root.provider.listModel : null
                spacing: root.gap

                delegate: Item {
                    id: entry

                    required property int index
                    required property string applicationName
                    required property string applicationIconName
                    required property string summary
                    required property string body
                    required property bool closable
                    required property date created
                    required property date updated
                    required property int urgency

                    readonly property var stamp: isNaN(entry.updated) ? entry.created : entry.updated

                    height: entryRow.implicitHeight + root.gap * 2
                    width: ListView.view ? ListView.view.width : 0

                    // 悬停高亮由桌面主题的 listitem 框架绘制，切换主题时自动跟随。
                    KSvg.FrameSvgItem {
                        anchors.fill: parent
                        imagePath: "widgets/listitem"
                        prefix: "hover"
                        visible: entryMouse.containsMouse
                    }

                    // 整行的点击处理，声明在内容之前以便按钮优先接收点击。
                    MouseArea {
                        id: entryMouse

                        anchors.fill: parent
                        hoverEnabled: true

                        onClicked: {
                            if (root.provider === null) {
                                return;
                            }
                            if (root.provider.trigger(entry.index)) {
                                return;
                            }

                            const url = root.provider.firstUrl(entry.index);
                            if (url.length > 0) {
                                root.provider.openUrl(url);
                            }
                        }
                    }

                    RowLayout {
                        id: entryRow

                        anchors.left: parent.left
                        anchors.margins: root.gap
                        anchors.right: parent.right
                        anchors.top: parent.top
                        spacing: root.gap

                        Kirigami.Icon { // 应用图标。
                            Layout.alignment: Qt.AlignTop
                            Layout.preferredHeight: Math.round(root.theme.gridUnit * 1.8)
                            Layout.preferredWidth: height
                            source: entry.applicationIconName.length > 0 ? entry.applicationIconName : "notifications"
                        }

                        ColumnLayout {
                            Layout.alignment: Qt.AlignTop
                            Layout.fillWidth: true
                            spacing: 0

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: root.gap

                                Text { // 应用名；紧急通知使用主题的警告色。
                                    Layout.fillWidth: true
                                    color: entry.urgency === root.criticalUrgency ? root.theme.negativeTextColor : root.theme.accentColor
                                    elide: Text.ElideRight
                                    font: root.bodyFont
                                    maximumLineCount: 1
                                    text: entry.applicationName
                                }

                                Text { // 相对时间。
                                    color: root.theme.disabledTextColor
                                    font: root.bodyFont
                                    text: root.relativeTime(entry.stamp)
                                }
                            }

                            Text { // 通知标题。
                                Layout.fillWidth: true
                                color: root.theme.textColor
                                elide: Text.ElideRight
                                font: root.headerFont
                                maximumLineCount: 1
                                text: entry.summary
                            }

                            Text { // 通知正文，最多两行。
                                Layout.fillWidth: true
                                color: root.theme.disabledTextColor
                                font: root.bodyFont
                                maximumLineCount: 2
                                text: entry.body
                                visible: entry.body.length > 0
                                wrapMode: Text.WordWrap
                            }
                        }

                        Item { // 关闭按钮。
                            Layout.alignment: Qt.AlignTop
                            Layout.preferredHeight: root.buttonSize
                            Layout.preferredWidth: root.buttonSize
                            visible: entry.closable

                            KSvg.FrameSvgItem {
                                anchors.fill: parent
                                imagePath: "widgets/button"
                                prefix: "toolbutton-hover"
                                visible: closeMouse.containsMouse
                            }

                            Kirigami.Icon {
                                anchors.centerIn: parent
                                height: Math.round(parent.height * 0.7)
                                opacity: closeMouse.containsMouse ? 1 : 0.6
                                source: "window-close"
                                width: height
                            }

                            MouseArea {
                                id: closeMouse

                                anchors.fill: parent
                                hoverEnabled: true
                                onClicked: if (root.provider !== null) {
                                    root.provider.close(entry.index);
                                }
                            }
                        }
                    }
                }
            }

            // 空列表或服务不可用时的占位提示。
            Column {
                id: placeholder

                anchors.centerIn: parent
                spacing: root.gap
                visible: notificationList.count === 0
                width: Math.round(parent.width * 0.8)

                Kirigami.Icon {
                    anchors.horizontalCenter: parent.horizontalCenter
                    height: Math.round(root.theme.gridUnit * 2)
                    source: root.available ? "checkmark" : "notifications-disabled"
                    width: height
                }

                Text {
                    color: root.theme.disabledTextColor
                    font: root.theme.defaultFont
                    horizontalAlignment: Text.AlignHCenter
                    text: root.available ? i18n("No unread notifications") : i18n("Notification service is not available")
                    width: parent.width
                    wrapMode: Text.WordWrap
                }
            }
        }
    }

    // 刷新相对时间，并定期重算勿扰状态（定时抑制会自然到期）。
    Timer {
        id: refreshTimer

        interval: 60000
        repeat: true
        running: root.visible
        triggeredOnStart: true

        onTriggered: {
            root.timeTick++;
            if (root.provider !== null) {
                root.provider.refreshInhibition();
            }
        }
    }
}
