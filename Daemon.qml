import QtQuick
import Quickshell
import Quickshell.Io
import qs.Modules.Plugins
import "./services" as Services

PluginComponent {
    id: root

    property bool watchlistLoaded: false

    Component.onCompleted: applySettings()
    onPluginDataChanged: applySettings()

    function applySettings() {
        updateApiToken();
        loadWatchlist();
        configureNotifications();
    }

    function updateApiToken() {
        const tokenPath = pluginData.apiTokenPath || "";
        if (tokenPath !== Services.AnimeScheduleService.apiTokenPath)
            Services.AnimeScheduleService.setApiTokenPath(tokenPath);
        else if (tokenPath)
            Services.AnimeScheduleService.reloadApiTokenFile();

        const token = pluginData.apiToken || "";
        if (token !== Services.AnimeScheduleService._tokenFromSettings)
            Services.AnimeScheduleService.setApiToken(token);

        const refreshInterval = (pluginData.refreshInterval || 15) * 60 * 1000;
        if (refreshInterval !== Services.AnimeScheduleService.updateInterval)
            Services.AnimeScheduleService.updateInterval = refreshInterval;
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

    function configureNotifications() {
        Services.NotificationService.configure({
            enableInstantNotifications: pluginData.enableInstantNotifications !== false,
            enableDailyDigest: pluginData.enableDailyDigest !== false,
            digestTime: pluginData.digestTime || "08:00",
            notificationIcon: pluginData.notificationIcon || "x-office-calendar"
        });
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
            Services.AnimeScheduleService.setWatchlist(list);
            root.saveWatchlist();
        }
    }

    Connections {
        target: Services.AnimeScheduleService
        function onWatchlistModified() {
            root.saveWatchlist();
        }
    }
}
