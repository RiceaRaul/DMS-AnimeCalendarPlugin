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
    property bool isInWatchlist: false
    property bool showWatchlistButton: true

    signal watchlistToggled(var anime)

    readonly property real thumbWidth: Theme.iconSizeLarge + Theme.spacingL

    height: thumbWidth + Theme.spacingS * 3
    color: mouseArea.containsMouse ? Theme.surfaceContainerHigh : "transparent"
    radius: Theme.cornerRadius

    RowLayout {
        anchors.fill: parent
        anchors.margins: Theme.spacingS
        spacing: Theme.spacingM

        // Anime thumbnail
        Rectangle {
            Layout.preferredWidth: root.thumbWidth
            Layout.fillHeight: true
            radius: Theme.cornerRadius / 2
            color: Theme.surfaceContainerHighest
            clip: true

            Image {
                id: thumb
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
                size: Theme.iconSize
                color: Theme.surfaceVariantText
                visible: thumb.status !== Image.Ready
            }
        }

        // Info column
        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 0

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

        DankActionButton {
            Layout.alignment: Qt.AlignVCenter
            visible: root.showWatchlistButton
            iconName: root.isInWatchlist ? "star" : "star_border"
            iconColor: root.isInWatchlist ? Theme.primary : Theme.surfaceVariantText
            tooltipText: root.isInWatchlist ? "Remove from watchlist" : "Add to watchlist"
            onClicked: root.watchlistToggled(root.anime)
        }

        // Time until column
        ColumnLayout {
            Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
            spacing: 0

            Rectangle {
                Layout.alignment: Qt.AlignRight
                Layout.preferredWidth: timeUntilText.width + Theme.spacingM
                Layout.preferredHeight: timeUntilText.height + Theme.spacingXS
                radius: Theme.cornerRadius / 2
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
        z: -1
        onClicked: {
            // Open anime page in browser
            if (anime.route) {
                Qt.openUrlExternally("https://animeschedule.net/anime/" + anime.route);
            }
        }
    }
}
