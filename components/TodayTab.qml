import QtQuick
import QtQuick.Layouts
import qs.Common
import qs.Widgets
import "../services" as Services

Item {
    id: root

    property bool isLoading: Services.AnimeScheduleService.isLoading
    property bool showAll: false
    property var todayList: showAll ? root.allWatchlistAnime : Services.AnimeScheduleService.watchlistTodayAnime

    // All watchlist anime (not just today)
    property var allWatchlistAnime: {
        var result = [];
        var timetable = Services.AnimeScheduleService.timetable;
        var watchlist = Services.AnimeScheduleService.watchlist;
        if (!timetable || !watchlist) return result;
        for (var i = 0; i < timetable.length; i++) {
            var anime = timetable[i];
            if (anime.route && watchlist.indexOf(anime.route) !== -1) {
                result.push(anime);
            }
        }
        return result;
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Theme.spacingM
        spacing: Theme.spacingM

        // Header with count and toggle
        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.spacingS

            StyledText {
                text: root.showAll ? "My Watchlist" : "Watchlist - Today"
                font.pixelSize: Theme.fontSizeMedium
                font.weight: Font.Bold
                color: Theme.surfaceText
            }

            Rectangle {
                Layout.preferredWidth: countBadge.width + Theme.spacingM
                Layout.preferredHeight: countBadge.height + Theme.spacingXS
                radius: Theme.cornerRadius / 2
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

            Item { Layout.fillWidth: true }

            // Toggle buttons
            Row {
                spacing: Theme.spacingXS

                Rectangle {
                    width: watchlistBtnText.width + Theme.spacingM
                    height: Theme.iconSize + Theme.spacingXS
                    radius: Theme.cornerRadius / 2
                    color: !root.showAll ? Theme.primary : Theme.surfaceContainerHigh

                    StyledText {
                        id: watchlistBtnText
                        anchors.centerIn: parent
                        text: "Watchlist"
                        font.pixelSize: Theme.fontSizeSmall
                        color: !root.showAll ? Theme.onPrimary : Theme.surfaceVariantText
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.showAll = false
                    }
                }

                Rectangle {
                    width: allBtnText.width + Theme.spacingM
                    height: Theme.iconSize + Theme.spacingXS
                    radius: Theme.cornerRadius / 2
                    color: root.showAll ? Theme.primary : Theme.surfaceContainerHigh

                    StyledText {
                        id: allBtnText
                        anchors.centerIn: parent
                        text: "All"
                        font.pixelSize: Theme.fontSizeSmall
                        color: root.showAll ? Theme.onPrimary : Theme.surfaceVariantText
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.showAll = true
                    }
                }
            }

            DankActionButton {
                iconName: "refresh"
                tooltipText: "Refresh anime list"
                enabled: !root.isLoading
                onClicked: Services.AnimeScheduleService.forceRefresh()
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
                    size: Theme.iconSizeLarge
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
                    size: Theme.iconSizeLarge
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
            DankListView {
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
                    // "All" shows the upcoming episode; "Watchlist" shows today's as listed
                    readonly property var airing: root.showAll ? Services.AnimeScheduleService.nextAiring(modelData) : {
                        date: Services.AnimeScheduleService.parseDate(modelData.episodeDate),
                        episode: Number(modelData.episodeNumber) || 0
                    }

                    episodeNumber: airing.episode > 0 ? "Episode " + airing.episode : ""
                    airTime: {
                        if (!airing.date)
                            return "";
                        const time = Services.AnimeScheduleService.formatTime(airing.date);
                        if (Services.AnimeScheduleService.isToday(airing.date))
                            return "Today at " + time;
                        return Services.AnimeScheduleService.formatDate(airing.date) + " at " + time;
                    }
                    timeUntil: Services.AnimeScheduleService.getTimeUntil(airing.date)
                    imageUrl: {
                        if (modelData.imageVersionRoute) {
                            return Services.AnimeScheduleService.getImageUrl(modelData.imageVersionRoute);
                        }
                        return "";
                    }
                    isInWatchlist: Services.AnimeScheduleService.isInWatchlist(modelData)
                    onWatchlistToggled: function(anime) {
                        Services.AnimeScheduleService.toggleWatchlist(anime);
                    }
                }
            }
        }
    }
}
