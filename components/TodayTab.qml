import QtQuick
import QtQuick.Layouts
import qs.Common
import qs.DCommon.Widgets
import "../services" as Services

Item {
    id: root

    property bool isLoading: Services.AnimeScheduleService.isLoading
    readonly property bool hasToken: Services.AnimeScheduleService.apiToken !== ""
    property bool showAll: false
    // Same row shape as AnimeScheduleService.watchlistRows; today's rows keep the episode as listed
    readonly property var todayRows: Services.AnimeScheduleService.watchlistTodayAnime.map(anime => {
        const date = Services.AnimeScheduleService.parseDate(anime.episodeDate);
        const entry = Services.AnimeScheduleService.watchlist.find(item => item.route === anime.route) || { route: anime.route };
        return { entry: entry, anime: anime, state: "upcoming", date: date, episode: Number(anime.episodeNumber) || 0 };
    })
    readonly property var todayList: showAll ? Services.AnimeScheduleService.watchlistRows : todayRows
    readonly property bool hasFinished: Services.AnimeScheduleService.watchlistRows.some(row => row.state === "finished")

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
                visible: root.hasToken && todayList.length > 0

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
                visible: root.showAll && root.hasFinished
                iconName: "playlist_remove"
                tooltipText: I18n.trFor("animeCalendar", "Clear finished")
                onClicked: Services.AnimeScheduleService.clearFinished()
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
                visible: root.hasToken && root.isLoading && todayList.length === 0
            }

            SetupState {
                anchors.centerIn: parent
                width: parent.width - Theme.spacingXL * 2
                visible: !root.hasToken
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
                    text: root.showAll ? I18n.trFor("animeCalendar", "Your watchlist is empty") : I18n.trFor("animeCalendar", "No watchlist anime today")
                    font.pixelSize: Theme.fontSizeMedium
                    font.weight: Font.Medium
                    color: Theme.surfaceText
                }

                StyledText {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: I18n.trFor("animeCalendar", "Star shows in the This week tab")
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.surfaceVariantText
                }
            }

            // Today's Anime List
            DListView {
                id: todayListView
                anchors.fill: parent
                visible: root.hasToken && todayList.length > 0
                clip: true
                spacing: Theme.spacingXS

                model: todayList

                delegate: AnimeListItem {
                    required property var modelData
                    readonly property var row: modelData
                    readonly property var showItem: row.anime || row.entry

                    width: todayListView.width
                    anime: showItem
                    title: Services.AnimeScheduleService.displayTitle(row.entry, row.anime)
                    episodeNumber: {
                        if (row.state === "finished")
                            return I18n.trFor("animeCalendar", "Finished");
                        if (row.state === "notAiring")
                            return I18n.trFor("animeCalendar", "No upcoming episode");
                        return Services.AnimeScheduleService.episodeLabel(row.episode, Number(row.anime?.episodes) || row.entry.episodes || 0);
                    }
                    airTime: {
                        if (!row.date)
                            return "";
                        const time = Services.AnimeScheduleService.formatTime(row.date);
                        if (Services.AnimeScheduleService.isToday(row.date))
                            return I18n.trFor("animeCalendar", "Today at %1").arg(time);
                        return I18n.trFor("animeCalendar", "%1 at %2").arg(Services.AnimeScheduleService.formatDate(row.date)).arg(time);
                    }
                    timeUntil: row.state === "upcoming" ? Services.AnimeScheduleService.getTimeUntil(row.date) : ""
                    aired: Services.AnimeScheduleService.hasAired(row.date)
                    delayed: row.state === "upcoming" && Services.AnimeScheduleService.isDelayed(row.anime)
                    imageUrl: Services.AnimeScheduleService.getImageUrl(row.anime?.imageVersionRoute || row.entry.image)
                    isInWatchlist: Services.AnimeScheduleService.isInWatchlist(showItem)
                    onWatchlistToggled: anime => Services.AnimeScheduleService.toggleWatchlist(anime)
                }
            }
        }
    }
}
