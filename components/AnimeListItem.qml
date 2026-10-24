import QtQuick
import QtQuick.Layouts
import qs.Common
import qs.DCommon.Widgets

Rectangle {
    id: root

    property var anime: ({})
    property string title: anime.title || anime.route || I18n.trFor("animeCalendar", "Unknown")
    property string episodeNumber: ""
    property string airTime: ""
    property string timeUntil: ""
    property bool aired: false
    property bool delayed: false
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
            radius: Theme.cornerRadiusS
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

            DIcon {
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
            spacing: Theme.spacingXXS

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

        DActionButton {
            Layout.alignment: Qt.AlignVCenter
            visible: root.showWatchlistButton
            iconName: root.isInWatchlist ? "star" : "star_border"
            iconColor: root.isInWatchlist ? Theme.primary : Theme.surfaceVariantText
            tooltipText: root.isInWatchlist ? I18n.trFor("animeCalendar", "Remove from watchlist") : I18n.trFor("animeCalendar", "Add to watchlist")
            onClicked: root.watchlistToggled(root.anime)
        }

        // Time until column
        ColumnLayout {
            Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
            spacing: Theme.spacingXXS

            Rectangle {
                Layout.alignment: Qt.AlignRight
                Layout.preferredWidth: delayedText.width + Theme.spacingM
                Layout.preferredHeight: delayedText.height + Theme.spacingXS
                radius: Theme.cornerRadiusS
                color: Theme.errorContainer
                visible: root.delayed

                StyledText {
                    id: delayedText
                    anchors.centerIn: parent
                    text: I18n.trFor("animeCalendar", "Delayed")
                    font.pixelSize: Theme.fontSizeSmall
                    font.weight: Font.Medium
                    color: Theme.onErrorContainer
                }
            }

            Rectangle {
                Layout.alignment: Qt.AlignRight
                Layout.preferredWidth: timeUntilText.width + Theme.spacingM
                Layout.preferredHeight: timeUntilText.height + Theme.spacingXS
                radius: Theme.cornerRadiusS
                color: root.aired ? Theme.surfaceContainerHighest : Theme.primaryContainer
                visible: root.timeUntil !== ""

                StyledText {
                    id: timeUntilText
                    anchors.centerIn: parent
                    text: root.timeUntil
                    font.pixelSize: Theme.fontSizeSmall
                    font.weight: Font.Medium
                    color: root.aired ? Theme.surfaceVariantText : Theme.onPrimaryContainer
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
