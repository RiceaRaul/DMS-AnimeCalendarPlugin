import QtQuick
import qs.Common
import qs.Widgets

Column {
    id: root

    width: parent.width
    spacing: Theme.spacingL
    anchors.centerIn: parent

    DankIcon {
        anchors.horizontalCenter: parent.horizontalCenter
        name: "progress_activity"
        size: Theme.iconSizeLarge
        color: Theme.primary

        RotationAnimation on rotation {
            running: root.visible
            from: 0
            to: 360
            duration: 1000
            loops: Animation.Infinite
        }
    }

    StyledText {
        anchors.horizontalCenter: parent.horizontalCenter
        text: "Loading anime data..."
        font.pixelSize: Theme.fontSizeMedium
        color: Theme.surfaceVariantText
    }
}
