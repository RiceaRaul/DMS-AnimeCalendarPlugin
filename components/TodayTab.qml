import QtQuick
import QtQuick.Layouts
import qs.Common
import qs.DCommon.Widgets
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
                text: root.showAll ? I18n.trFor("animeCalendar", "My Watchlist") : I18n.trFor("animeCalendar", "Watchlist - Today")
                font.pixelSize: Theme.fontSizeMedium
                font.weight: Font.Bold
                color: Theme.surfaceText
            }

            Rectangle {
                Layout.preferredWidth: countBadge.width + Theme.spacingM
                Layout.preferredHeight: countBadge.height + Theme.spacingXS
                radius: Theme.cornerRadiusS
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

            DButtonGroup {
                size: "small"
                arrowKeysSelect: false
                checkEnabled: false
                model: [I18n.trFor("animeCalendar", "Watchlist"), I18n.trFor("animeCalendar", "All")]
                currentIndex: root.showAll ? 1 : 0
                onSelectionChanged: (index, selected) => {
                    if (selected)
                        root.showAll = index === 1;
                }
            }

            DActionButton {
                iconName: "refresh"
                tooltipText: I18n.trFor("animeCalendar", "Refresh anime list")
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
            }

            // Empty State - no anime today
            Column {
                anchors.centerIn: parent
                spacing: Theme.spacingM
                visible: !root.isLoading && todayList.length === 0 && Services.AnimeScheduleService.apiToken !== "" && !Services.AnimeScheduleService.hasError

                DIcon {
                    anchors.horizontalCenter: parent.horizontalCenter
                    name: "event_busy"
                    size: Theme.iconSizeLarge
                    color: Theme.surfaceVariantText
                }

                StyledText {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: I18n.trFor("animeCalendar", "No watchlist anime today")
                    font.pixelSize: Theme.fontSizeMedium
                    font.weight: Font.Medium
                    color: Theme.surfaceText
                }

                StyledText {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: I18n.trFor("animeCalendar", "Add anime from Season tab")
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.surfaceVariantText
                }
            }

            // Today's Anime List
            DListView {
                id: todayListView
                anchors.fill: parent
                visible: todayList.length > 0
                clip: true
                spacing: Theme.spacingXS

                model: todayList

                delegate: AnimeListItem {
                    width: todayListView.width
                    anime: modelData
                    title: modelData.title || modelData.route || I18n.trFor("animeCalendar", "Unknown")
                    // "All" shows the upcoming episode; "Watchlist" shows today's as listed
                    readonly property var airing: root.showAll ? Services.AnimeScheduleService.nextAiring(modelData) : {
                        date: Services.AnimeScheduleService.parseDate(modelData.episodeDate),
                        episode: Number(modelData.episodeNumber) || 0
                    }

                    episodeNumber: airing.episode > 0 ? I18n.trFor("animeCalendar", "Episode %1").arg(airing.episode) : ""
                    airTime: {
                        if (!airing.date)
                            return "";
                        const time = Services.AnimeScheduleService.formatTime(airing.date);
                        if (Services.AnimeScheduleService.isToday(airing.date))
                            return I18n.trFor("animeCalendar", "Today at %1").arg(time);
                        return I18n.trFor("animeCalendar", "%1 at %2").arg(Services.AnimeScheduleService.formatDate(airing.date)).arg(time);
                    }
                    timeUntil: Services.AnimeScheduleService.getTimeUntil(airing.date)
                    aired: Services.AnimeScheduleService.hasAired(airing.date)
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
