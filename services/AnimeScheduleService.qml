pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    // API Configuration
    property string apiTokenPath: ""
    property string _tokenFromFile: ""
    property string _tokenFromSettings: ""
    readonly property string apiToken: apiTokenPath !== "" ? _tokenFromFile : _tokenFromSettings
    property string baseUrl: "https://animeschedule.net/api/v3"

    // State
    property bool isLoading: false
    property bool hasError: false
    property string errorMessage: ""
    property int lastFetchTime: 0
    property int minFetchInterval: 30000 // 30 seconds minimum between requests

    // Timetable data
    property var timetable: []
    property var todayAnime: []
    property int todayCount: 0

    // Watchlist (local storage)
    property var watchlist: []
    property var watchlistTodayAnime: []
    property int watchlistTodayCount: 0
    readonly property string watchlistDir: Quickshell.env("HOME") + "/.config/quickshell"
    readonly property string watchlistFile: watchlistDir + "/anime-watchlist.json"

    // Rate limiting
    property int rateLimitRemaining: 120
    property int rateLimitReset: 0

    // Retry logic
    property int retryAttempts: 0
    property int maxRetryAttempts: 3
    property int retryDelay: 5000

    // Update interval (default 15 minutes)
    property int updateInterval: 900000

    readonly property var curlBaseCmd: ["curl", "-sS", "--fail", "--connect-timeout", "10", "--max-time", "30", "--compressed"]

    signal timetableUpdated()
    signal errorOccurred(string message)
    signal watchlistModified()

    function setApiToken(token) {
        root._tokenFromSettings = token || "";
        if (root.apiToken) {
            refresh();
        }
    }

    function setApiTokenPath(path) {
        root.apiTokenPath = path || "";
        if (root.apiTokenPath) {
            tokenFileLoader.running = true;
        } else {
            root._tokenFromFile = "";
        }
    }

    function reloadApiTokenFile() {
        if (root.apiTokenPath) {
            tokenFileLoader.running = true;
        }
    }

    function getTimetableUrl(type) {
        // type can be: "sub", "dub", "raw", or empty for all
        const endpoint = type ? "/timetables/" + type : "/timetables/sub";
        return baseUrl + endpoint;
    }

    function refresh() {
        fetchTimetable("sub");
    }

    function fetchTimetable(type) {
        if (!apiToken) {
            root.hasError = true;
            root.errorMessage = "API token not configured";
            errorOccurred(root.errorMessage);
            return;
        }

        if (timetableFetcher.running) {
            return;
        }

        const now = Date.now();
        if (now - root.lastFetchTime < root.minFetchInterval) {
            return;
        }

        root.lastFetchTime = now;
        root.isLoading = true;
        root.hasError = false;
        root.errorMessage = "";

        const url = getTimetableUrl(type);
        const authHeader = "Authorization: Bearer " + apiToken;

        timetableFetcher.command = curlBaseCmd.concat([
            "-H", authHeader,
            "-H", "Accept: application/json",
            url
        ]);
        timetableFetcher.running = true;
    }

    function forceRefresh() {
        root.lastFetchTime = 0;
        refresh();
    }

    function handleSuccess() {
        root.retryAttempts = 0;
        root.hasError = false;
        root.errorMessage = "";
        if (updateTimer.interval !== root.updateInterval) {
            updateTimer.interval = root.updateInterval;
        }
    }

    function handleFailure(message) {
        root.retryAttempts++;
        root.hasError = true;
        root.errorMessage = message || "Failed to fetch data";
        root.isLoading = false;

        if (root.retryAttempts < root.maxRetryAttempts) {
            retryTimer.start();
        } else {
            root.retryAttempts = 0;
            errorOccurred(root.errorMessage);
        }
    }

    function parseDate(dateString) {
        if (!dateString || dateString === "0001-01-01T00:00:00Z") {
            return null;
        }
        return new Date(dateString);
    }

    function formatTime(date) {
        if (!date) return "--:--";
        return date.toLocaleTimeString(Qt.locale(), "HH:mm");
    }

    function formatDate(date) {
        if (!date) return "--";
        return date.toLocaleDateString(Qt.locale(), "ddd, MMM d");
    }

    function isToday(date) {
        if (!date) return false;
        const today = new Date();
        return date.getFullYear() === today.getFullYear() &&
               date.getMonth() === today.getMonth() &&
               date.getDate() === today.getDate();
    }

    function getTimeUntil(date) {
        if (!date) return "";
        const now = new Date();
        const diff = date.getTime() - now.getTime();

        if (diff < 0) return "Aired";

        const hours = Math.floor(diff / (1000 * 60 * 60));
        const minutes = Math.floor((diff % (1000 * 60 * 60)) / (1000 * 60));

        if (hours > 24) {
            const days = Math.floor(hours / 24);
            return days + "d " + (hours % 24) + "h";
        }
        if (hours > 0) {
            return hours + "h " + minutes + "m";
        }
        return minutes + "m";
    }

    function getImageUrl(route) {
        if (!route) return "";
        return "https://img.animeschedule.net/production/assets/public/img/" + route;
    }

    function isInWatchlist(anime) {
        if (!anime || !anime.route) return false;
        return root.watchlist.indexOf(anime.route) !== -1;
    }

    function toggleWatchlist(anime) {
        if (!anime || !anime.route) return;
        var idx = root.watchlist.indexOf(anime.route);
        var newList = root.watchlist.slice();
        if (idx === -1) {
            newList.push(anime.route);
        } else {
            newList.splice(idx, 1);
        }
        root.watchlist = newList;
        updateWatchlistToday();
        watchlistModified();
        saveWatchlistToFile();
    }

    function setWatchlist(list) {
        root.watchlist = list || [];
        updateWatchlistToday();
    }

    function updateWatchlistToday() {
        var result = [];
        for (var i = 0; i < timetable.length; i++) {
            var anime = timetable[i];
            var airDate = parseDate(anime.episodeDate);
            if (isToday(airDate) && isInWatchlist(anime)) {
                result.push(anime);
            }
        }
        result.sort(function(a, b) {
            var dateA = parseDate(a.episodeDate);
            var dateB = parseDate(b.episodeDate);
            if (!dateA) return 1;
            if (!dateB) return -1;
            return dateA.getTime() - dateB.getTime();
        });
        root.watchlistTodayAnime = result;
        root.watchlistTodayCount = result.length;
    }

    function saveWatchlistToFile() {
        watchlistSaver.running = true;
    }

    function loadWatchlistFromFile() {
        watchlistLoader.running = true;
    }

    function filterTodayAnime() {
        const today = [];
        for (let i = 0; i < timetable.length; i++) {
            const anime = timetable[i];
            const airDate = parseDate(anime.episodeDate);
            if (isToday(airDate)) {
                today.push(anime);
            }
        }
        // Sort by air time
        today.sort((a, b) => {
            const dateA = parseDate(a.episodeDate);
            const dateB = parseDate(b.episodeDate);
            if (!dateA) return 1;
            if (!dateB) return -1;
            return dateA.getTime() - dateB.getTime();
        });
        root.todayAnime = today;
        root.todayCount = today.length;
        updateWatchlistToday();
    }

    Process {
        id: timetableFetcher
        running: false

        stdout: StdioCollector {
            onStreamFinished: {
                const raw = text.trim();

                if (!raw) {
                    root.handleFailure("Empty response from API");
                    return;
                }

                // Check if it's an error response
                if (raw.startsWith("{") && raw.includes("\"error\"")) {
                    try {
                        const errorData = JSON.parse(raw);
                        root.handleFailure(errorData.message || errorData.error || "API error");
                        return;
                    } catch (e) {
                        // Continue to try parsing as array
                    }
                }

                if (!raw.startsWith("[")) {
                    root.handleFailure("Invalid response format");
                    return;
                }

                try {
                    const data = JSON.parse(raw);

                    if (!Array.isArray(data)) {
                        throw new Error("Expected array response");
                    }

                    root.timetable = data;
                    root.filterTodayAnime();
                    root.isLoading = false;
                    root.handleSuccess();
                    root.timetableUpdated();

                } catch (e) {
                    root.handleFailure("Failed to parse response: " + e.message);
                }
            }
        }

        onExited: exitCode => {
            if (exitCode !== 0) {
                root.handleFailure("Request failed with exit code: " + exitCode);
            }
        }
    }

    Timer {
        id: updateTimer
        interval: root.updateInterval
        running: root.apiToken !== ""
        repeat: true
        onTriggered: {
            root.refresh();
        }
    }

    Timer {
        id: retryTimer
        interval: root.retryDelay
        running: false
        repeat: false
        onTriggered: {
            root.refresh();
        }
    }

    Process {
        id: tokenFileLoader
        running: false
        command: ["cat", root.apiTokenPath]

        stdout: StdioCollector {
            onStreamFinished: {
                const trimmed = (text || "").trim();
                if (trimmed !== root._tokenFromFile) {
                    root._tokenFromFile = trimmed;
                    if (trimmed) {
                        root.refresh();
                    }
                }
            }
        }

        onExited: exitCode => {
            if (exitCode !== 0) {
                root.hasError = true;
                root.errorMessage = "Failed to read API token file: " + root.apiTokenPath;
                root._tokenFromFile = "";
            }
        }
    }

    Process {
        id: watchlistSaver
        running: false
        command: [
            "bash",
            "-c",
            "mkdir -p " + root.watchlistDir + " && echo '" + JSON.stringify(root.watchlist) + "' > " + root.watchlistFile
        ]
    }

    Process {
        id: watchlistLoader
        running: false
        command: ["cat", root.watchlistFile]

        stdout: StdioCollector {
            onStreamFinished: {
                var raw = text.trim();
                if (raw) {
                    try {
                        root.watchlist = JSON.parse(raw);
                    } catch (e) {
                        root.watchlist = [];
                    }
                }
            }
        }
    }

    Component.onCompleted: {
        loadWatchlistFromFile();
    }
}
