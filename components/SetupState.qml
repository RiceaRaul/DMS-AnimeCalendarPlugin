import QtQuick
import qs.Common
import qs.Services
import qs.DCommon.Widgets

Column {
    id: root

    spacing: Theme.spacingM

    DIcon {
        anchors.horizontalCenter: parent.horizontalCenter
        name: "key"
        size: Theme.iconSizeLarge
        color: Theme.surfaceVariantText
    }

    StyledText {
        anchors.horizontalCenter: parent.horizontalCenter
        text: I18n.trFor("animeCalendar", "API Token Required")
        font.pixelSize: Theme.fontSizeMedium
        font.weight: Font.Medium
        color: Theme.surfaceText
    }

    StyledText {
        width: root.width
        text: I18n.trFor("animeCalendar", "Create an application on animeschedule.net to get an application token, then paste it in the plugin settings.")
        font.pixelSize: Theme.fontSizeSmall
        color: Theme.surfaceVariantText
        wrapMode: Text.WordWrap
        horizontalAlignment: Text.AlignHCenter
    }

    Row {
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: Theme.spacingS

        DButton {
            text: I18n.trFor("animeCalendar", "Get a token")
            iconName: "open_in_new"
            onClicked: Qt.openUrlExternally("https://animeschedule.net/api/v3/documentation")
        }

        DButton {
            text: I18n.trFor("animeCalendar", "Open settings")
            iconName: "settings"
            onClicked: PopoutService.openSettingsWithTab("plugin:animeCalendar")
        }
    }
}
