// LoadingState.qml - Loading indicator component
import QtQuick
import qs.Common
import qs.Widgets
import QtQuick.Controls 

Column {
    id: root

    width: parent.width
    spacing: Theme.spacingL
    anchors.centerIn: parent

    BusyIndicator {
        anchors.horizontalCenter: parent.horizontalCenter
        running: true
        width: 48
        height: 48
    }

    StyledText {
        anchors.horizontalCenter: parent.horizontalCenter
        text: "Loading anime data..."
        font.pixelSize: Theme.fontSizeMedium
        color: Theme.surfaceVariantText
    }
}
