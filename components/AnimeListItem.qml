import QtQuick
import QtQuick.Layouts
import qs.Common
import qs.Widgets

Rectangle {
    id: root

    property var anime: ({})
    property string title: anime.title || anime.route || "Unknown"
    property string episodeNumber: anime.episodeNumber ? "Ep " + anime.episodeNumber : ""
    property string airTime: ""
    property string timeUntil: ""
    property string imageUrl: ""

    width: parent ? parent.width : 200
    height: 72
    color: mouseArea.containsMouse ? Theme.surfaceContainerHigh : "transparent"
    radius: Theme.cornerRadius

    RowLayout {
        anchors.fill: parent
        anchors.margins: Theme.spacingS
        spacing: Theme.spacingM

        // Anime thumbnail
        Rectangle {
            Layout.preferredWidth: 48
            Layout.preferredHeight: 56
            radius: Theme.cornerRadiusSmall
            color: Theme.surfaceContainerHighest
            clip: true

            Image {
                anchors.fill: parent
                source: root.imageUrl
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                visible: status === Image.Ready

                Rectangle {
                    anchors.fill: parent
                    color: "transparent"
                    radius: parent.parent.radius
                    border.width: 1
                    border.color: Theme.outline
                    opacity: 0.2
                }
            }

            DankIcon {
                anchors.centerIn: parent
                name: "movie"
                size: 24
                color: Theme.surfaceVariantText
                visible: parent.children[0].status !== Image.Ready
            }
        }

        // Info column
        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 2

            StyledText {
                Layout.fillWidth: true
                text: root.title
                font.pixelSize: Theme.fontSizeMedium
                font.weight: Font.Medium
                color: Theme.surfaceText
                elide: Text.ElideRight
                maximumLineCount: 1
            }

            StyledText {
                Layout.fillWidth: true
                text: root.episodeNumber
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.primary
                visible: text !== ""
            }

            StyledText {
                Layout.fillWidth: true
                text: root.airTime
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.surfaceVariantText
                visible: text !== ""
            }
        }

        // Time until column
        ColumnLayout {
            Layout.preferredWidth: 60
            Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
            spacing: 2

            Rectangle {
                Layout.alignment: Qt.AlignRight
                Layout.preferredWidth: timeUntilText.width + Theme.spacingM
                Layout.preferredHeight: timeUntilText.height + Theme.spacingXS
                radius: Theme.cornerRadiusSmall
                color: root.timeUntil === "Aired" ? Theme.surfaceContainerHighest : Theme.primaryContainer
                visible: root.timeUntil !== ""

                StyledText {
                    id: timeUntilText
                    anchors.centerIn: parent
                    text: root.timeUntil
                    font.pixelSize: Theme.fontSizeSmall
                    font.weight: Font.Medium
                    color: root.timeUntil === "Aired" ? Theme.surfaceVariantText : Theme.onPrimaryContainer
                }
            }
        }
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            // Open anime page in browser
            if (anime.route) {
                Qt.openUrlExternally("https://animeschedule.net/anime/" + anime.route);
            }
        }
    }
}
