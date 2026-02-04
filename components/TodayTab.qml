import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.Common
import qs.Widgets
import "../services" as Services

Item {
    id: root
    anchors.fill: parent

    property bool isLoading: Services.AnimeScheduleService.isLoading
    property var todayList: Services.AnimeScheduleService.watchlistTodayAnime

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Theme.spacingM
        spacing: Theme.spacingM

        // Header with count
        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.spacingS

            StyledText {
                Layout.fillWidth: true
                text: "My Watchlist - Today"
                font.pixelSize: Theme.fontSizeMedium
                font.weight: Font.Bold
                color: Theme.surfaceText
            }

            Rectangle {
                Layout.preferredWidth: countBadge.width + Theme.spacingM
                Layout.preferredHeight: countBadge.height + Theme.spacingXS
                radius: Theme.cornerRadiusSmall
                color: Theme.primaryContainer
                visible: todayList.length > 0

                StyledText {
                    id: countBadge
                    anchors.centerIn: parent
                    text: todayList.length.toString()
                    font.pixelSize: Theme.fontSizeSmall
                    font.weight: Font.Bold
                    color: Theme.onPrimaryContainer
                }
            }

            // Refresh Button
            Rectangle {
                Layout.preferredWidth: 32
                Layout.preferredHeight: 32
                radius: Theme.cornerRadiusSmall
                color: todayRefreshMouseArea.containsMouse ? Theme.primaryContainer : "transparent"

                DankIcon {
                    anchors.centerIn: parent
                    name: "refresh"
                    size: 18
                    color: todayRefreshMouseArea.containsMouse ? Theme.onPrimaryContainer : Theme.surfaceVariantText

                    RotationAnimation on rotation {
                        running: root.isLoading
                        from: 0
                        to: 360
                        duration: 1000
                        loops: Animation.Infinite
                    }
                }

                MouseArea {
                    id: todayRefreshMouseArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (!root.isLoading) {
                            Services.AnimeScheduleService.forceRefresh();
                        }
                    }
                }
            }
        }

        // Content
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            // Loading State
            LoadingState {
                anchors.centerIn: parent
                visible: root.isLoading && todayList.length === 0
            }

            // No Token State
            Column {
                anchors.centerIn: parent
                spacing: Theme.spacingM
                visible: Services.AnimeScheduleService.apiToken === ""

                DankIcon {
                    anchors.horizontalCenter: parent.horizontalCenter
                    name: "key"
                    size: 48
                    color: Theme.surfaceVariantText
                }

                StyledText {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "API Token Required"
                    font.pixelSize: Theme.fontSizeMedium
                    font.weight: Font.Medium
                    color: Theme.surfaceText
                }
            }

            // Empty State - no anime today
            Column {
                anchors.centerIn: parent
                spacing: Theme.spacingM
                visible: !root.isLoading && todayList.length === 0 && Services.AnimeScheduleService.apiToken !== "" && !Services.AnimeScheduleService.hasError

                DankIcon {
                    anchors.horizontalCenter: parent.horizontalCenter
                    name: "event_busy"
                    size: 48
                    color: Theme.surfaceVariantText
                }

                StyledText {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "No watchlist anime today"
                    font.pixelSize: Theme.fontSizeMedium
                    font.weight: Font.Medium
                    color: Theme.surfaceText
                }

                StyledText {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "Add anime from Season tab"
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.surfaceVariantText
                }
            }

            // Today's Anime List
            ListView {
                id: todayListView
                anchors.fill: parent
                visible: todayList.length > 0
                clip: true
                spacing: Theme.spacingXS

                model: todayList

                delegate: AnimeListItem {
                    width: todayListView.width
                    anime: modelData
                    title: modelData.title || modelData.route || "Unknown"
                    episodeNumber: modelData.episodeNumber ? "Episode " + modelData.episodeNumber : ""
                    airTime: {
                        const date = Services.AnimeScheduleService.parseDate(modelData.episodeDate);
                        if (!date) return "";
                        return "Today at " + Services.AnimeScheduleService.formatTime(date);
                    }
                    timeUntil: {
                        const date = Services.AnimeScheduleService.parseDate(modelData.episodeDate);
                        return Services.AnimeScheduleService.getTimeUntil(date);
                    }
                    imageUrl: {
                        if (modelData.imageVersionRoute) {
                            return Services.AnimeScheduleService.getImageUrl(modelData.imageVersionRoute);
                        }
                        return "";
                    }
                    isInWatchlist: true
                    onWatchlistToggled: function(anime) {
                        Services.AnimeScheduleService.toggleWatchlist(anime);
                    }
                }

                ScrollBar.vertical: ScrollBar {
                    active: true
                    policy: ScrollBar.AsNeeded
                }
            }
        }
    }
}
