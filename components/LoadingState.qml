import QtQuick
import qs.Common
import qs.DCommon.Widgets

Column {
    id: root

    width: parent.width
    spacing: Theme.spacingL
    anchors.centerIn: parent

    DSpinner {
        anchors.horizontalCenter: parent.horizontalCenter
        size: Theme.iconSizeLarge
    }

    StyledText {
        anchors.horizontalCenter: parent.horizontalCenter
        text: I18n.trFor("animeCalendar", "Loading anime data...")
        font.pixelSize: Theme.fontSizeMedium
        color: Theme.surfaceVariantText
    }
}
