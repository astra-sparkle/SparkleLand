import "style"
import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

Item {
    id: root

    property var theme
    property var provider
    property bool showDoNotDisturb: true
    property bool showClearAll: true

    // Counter used to refresh relative-time labels
    // 用于刷新相对时间文本的计数器
    property int timeTick

    // Only active when the applet is open on this page
    // 仅当小组件在当前页展开时生效
    property bool pageActive: true
    // The expanded view remains instantiated even while collapsed
    // 折叠时展开视图仍保留实例，以支持快速切换
    property bool appletExpanded: false
    readonly property bool effectiveActive: root.visible && root.pageActive && root.appletExpanded

    readonly property bool available: root.provider !== null && root.provider.available
    readonly property bool inhibited: root.provider !== null && root.provider.inhibited
    // Critical urgency enum value used for warning-color styling
    // 用于警告色样式的紧急级别枚举值
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

    // Format a timestamp as a relative string
    // 将时间戳格式化为相对时间
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

    // Mark notifications as read and sync do-not-disturb while active
    // 激活时标记通知为已读并同步勿扰状态
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

            Buttons.ToggleButton {
                Layout.preferredHeight: root.buttonSize
                Layout.preferredWidth: root.buttonSize
                checked: root.inhibited
                source: "notifications-disabled"
                theme: root.theme
                visible: root.showDoNotDisturb && root.available
                onClicked: if (root.provider !== null) {
                    root.provider.toggleInhibition();
                }
            }

            Buttons.IconButton {
                Layout.preferredHeight: root.buttonSize
                Layout.preferredWidth: root.buttonSize
                source: "edit-clear-history"
                theme: root.theme
                visible: root.showClearAll && notificationList.count > 0
                onClicked: if (root.provider !== null) {
                    root.provider.clearAll();
                }
            }
        }

        Text {
            Layout.fillWidth: true
            color: root.theme.disabledTextColor
            elide: Text.ElideRight
            font: root.bodyFont
            maximumLineCount: 1
            text: i18n("Do not disturb is active")
            visible: root.inhibited
        }

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

                    ListItemBackground {
                        anchors.fill: parent
                        hovered: entryMouse.containsMouse
                    }

                    // Handle row clicks before content so later buttons receive input first
                    // 整行点击区域先声明，使后续按钮优先接收输入
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

                        Kirigami.Icon {
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

                                Text {
                                    Layout.fillWidth: true
                                    color: entry.urgency === root.criticalUrgency ? root.theme.negativeTextColor : root.theme.accentColor
                                    elide: Text.ElideRight
                                    font: root.bodyFont
                                    maximumLineCount: 1
                                    text: entry.applicationName
                                }

                                Text {
                                    color: root.theme.disabledTextColor
                                    font: root.bodyFont
                                    text: root.relativeTime(entry.stamp)
                                }
                            }

                            Text {
                                Layout.fillWidth: true
                                color: root.theme.textColor
                                elide: Text.ElideRight
                                font: root.headerFont
                                maximumLineCount: 1
                                text: entry.summary
                            }

                            Text {
                                Layout.fillWidth: true
                                color: root.theme.disabledTextColor
                                font: root.bodyFont
                                maximumLineCount: 2
                                text: entry.body
                                visible: entry.body.length > 0
                                wrapMode: Text.WordWrap
                            }
                        }

                        Buttons.ToolButton {
                            Layout.alignment: Qt.AlignTop
                            Layout.preferredHeight: root.buttonSize
                            Layout.preferredWidth: root.buttonSize
                            iconOpacity: 0.6
                            iconSizeRatio: 0.7
                            source: "window-close"
                            visible: entry.closable
                            onClicked: if (root.provider !== null) {
                                root.provider.close(entry.index);
                            }
                        }
                    }
                }
            }

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

    // Refresh relative times and do-not-disturb state, including timed expiry
    // 刷新相对时间和勿扰状态，并处理定时抑制到期
    Timer {
        id: refreshTimer

        interval: 60000
        repeat: true
        running: root.effectiveActive
        triggeredOnStart: true

        onTriggered: {
            root.timeTick++;
            if (root.provider !== null) {
                root.provider.refreshInhibition();
            }
        }
    }
}
