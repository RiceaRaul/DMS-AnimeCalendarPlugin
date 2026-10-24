import QtQuick
import qs.Common
import qs.DCommon.Widgets
import qs.Modules.Plugins
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "./components" as AnimeCalendarComponents
import "./services" as Services

PluginComponent {
    id: root

    readonly property int todayCount: Services.AnimeScheduleService.watchlistTodayCount
    readonly property string barMode: pluginData.barIndicatorMode ?? "icon_count"

    // Ticks the countdown; stopped while the bar is hidden or the countdown isn't shown
    SystemClock {
        id: clock
        enabled: root.surfaceLive && root.barMode === "icon_time"
        precision: SystemClock.Minutes
    }

    readonly property string nextAiringTime: {
        const now = clock.date.getTime();
        const list = Services.AnimeScheduleService.watchlistTodayAnime;
        for (let i = 0; i < list.length; i++) {
            const airDate = Services.AnimeScheduleService.parseDate(list[i].episodeDate);
            if (airDate && airDate.getTime() > now)
                return Services.AnimeScheduleService.getTimeUntil(airDate);
        }
        return "";
    }

    readonly property string pillText: {
        const countText = todayCount > 0 ? I18n.trFor("animeCalendar", "%1 today").arg(todayCount) : "";
        if (barMode === "icon_only")
            return "";
        if (barMode === "icon_time")
            return nextAiringTime || countText;
        return countText;
    }

    property bool watchlistLoaded: false

    Component.onCompleted: {
        updateApiToken();
        loadWatchlist();
        configureNotifications();
    }

    onPluginDataChanged: {
        updateApiToken();
        loadWatchlist();
        configureNotifications();
    }

    function updateApiToken() {
        const tokenPath = pluginData.apiTokenPath || "";
        if (tokenPath !== Services.AnimeScheduleService.apiTokenPath) {
            Services.AnimeScheduleService.setApiTokenPath(tokenPath);
        } else if (tokenPath) {
            Services.AnimeScheduleService.reloadApiTokenFile();
        }

        const token = pluginData.apiToken || "";
        if (token !== Services.AnimeScheduleService._tokenFromSettings) {
            Services.AnimeScheduleService.setApiToken(token);
        }

        // Update refresh interval from settings
        const refreshInterval = (pluginData.refreshInterval || 15) * 60 * 1000;
        if (refreshInterval !== Services.AnimeScheduleService.updateInterval) {
            Services.AnimeScheduleService.updateInterval = refreshInterval;
        }
    }

    // pluginData is empty until pluginService is injected, so wait for it before reading
    function loadWatchlist() {
        if (root.watchlistLoaded || !pluginService || !pluginId)
            return;
        root.watchlistLoaded = true;
        const saved = pluginData.watchlist;
        if (Array.isArray(saved)) {
            Services.AnimeScheduleService.setWatchlist(saved);
            return;
        }
        legacyWatchlist.path = Quickshell.env("HOME") + "/.config/quickshell/anime-watchlist.json";
    }

    function saveWatchlist() {
        if (!pluginService || !pluginId)
            return;
        pluginService.savePluginData(pluginId, "watchlist", Services.AnimeScheduleService.watchlist);
    }

    // One-time read-only import of the watchlist file used by versions before 1.0.2
    FileView {
        id: legacyWatchlist
        printErrors: false
        onLoaded: {
            let list;
            try {
                list = JSON.parse(text());
            } catch (e) {
                return;
            }
            if (!Array.isArray(list))
                return;
            Services.AnimeScheduleService.setWatchlist(list.filter(route => typeof route === "string"));
            root.saveWatchlist();
        }
    }

    function configureNotifications() {
        Services.NotificationService.configure({
            enableInstantNotifications: pluginData.enableInstantNotifications !== false,
            enableDailyDigest: pluginData.enableDailyDigest !== false,
            digestTime: pluginData.digestTime || "08:00",
            notificationIcon: pluginData.notificationIcon || "x-office-calendar"
        });
    }

    Connections {
        target: Services.AnimeScheduleService
        function onWatchlistModified() {
            root.saveWatchlist();
        }
    }

    horizontalBarPill: Component {
        Row {
            spacing: Theme.spacingXS

            DIcon {
                anchors.verticalCenter: parent.verticalCenter
                name: "calendar_month"
                size: root.iconSize
                color: Theme.widgetIconColor
            }

            StyledText {
                anchors.verticalCenter: parent.verticalCenter
                visible: text !== ""
                text: root.pillText
                font.pixelSize: root.textSize
                color: Theme.widgetTextColor
            }
        }
    }

    verticalBarPill: Component {
        Column {
            spacing: Theme.spacingXXS

            DIcon {
                anchors.horizontalCenter: parent.horizontalCenter
                name: "calendar_month"
                size: root.iconSize
                color: Theme.widgetIconColor
            }

            StyledText {
                anchors.horizontalCenter: parent.horizontalCenter
                visible: text !== ""
                text: {
                    if (root.barMode === "icon_only")
                        return "";
                    if (root.barMode === "icon_time")
                        return root.nextAiringTime;
                    return root.todayCount > 0 ? root.todayCount.toString() : "";
                }
                font.pixelSize: root.textSize
                color: Theme.widgetTextColor
            }
        }
    }

    popoutContent: Component {
        PopoutComponent {
            id: popoutColumn

            headerText: I18n.trFor("animeCalendar", "Anime Calendar")
            detailsText: root.todayCount > 0 ? I18n.trFor("animeCalendar", "%1 from watchlist airing today").arg(root.todayCount) : I18n.trFor("animeCalendar", "No watchlist anime today")
            showCloseButton: true

            Item {
                width: parent.width
                implicitHeight: root.popoutHeight - popoutColumn.headerHeight - popoutColumn.detailsHeight - Theme.spacingXL

                DTabBar {
                    id: tabBar
                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.right: parent.right
                    tabHeight: Theme.buttonHeightS
                    model: [
                        { text: I18n.trFor("animeCalendar", "Season"), icon: "calendar_month" },
                        { text: I18n.trFor("animeCalendar", "Today"), icon: "today" }
                    ]
                    onTabClicked: index => tabBar.currentIndex = index
                }

                StackLayout {
                    anchors.top: tabBar.bottom
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    currentIndex: tabBar.currentIndex

                    AnimeCalendarComponents.SeasonTab {}

                    AnimeCalendarComponents.TodayTab {}
                }
            }
        }
    }

    popoutWidth: Theme.listItemHeight * 7
    popoutHeight: Theme.listItemHeight * 9
}
