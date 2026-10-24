pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.Common

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
    property real lastUpdated: 0
    readonly property bool isOffline: hasError && timetable.length > 0
    readonly property int staleAfter: 15 * 60 * 1000
    property int minFetchInterval: 30000 // 30 seconds minimum between requests

    // Timetable data
    property var timetable: []
    property var todayAnime: []
    property int todayCount: 0

    // Entries { route, title, english, romaji, native, image, episodes, finished }, persisted by Daemon.qml
    property var watchlist: []
    property var watchlistTodayAnime: []
    property int watchlistTodayCount: 0

    // Retry logic
    property int retryAttempts: 0
    property int maxRetryAttempts: 3
    property int retryDelay: 5000

    // Update interval (default 15 minutes)
    property int updateInterval: 900000

    // "sub", "dub" or "raw"
    property string timetableType: "sub"

    readonly property var curlBaseCmd: ["curl", "-sS", "--fail", "--connect-timeout", "10", "--max-time", "30", "--compressed"]

    // Pending { url, callbacks }; one curl at a time
    property var _queue: []
    property var _active: null

    // fromCache: loaded from plugin state on start, not fetched
    signal timetableUpdated(bool fromCache)
    signal errorOccurred(string message)
    signal watchlistModified()

    function setApiToken(token) {
        root._tokenFromSettings = token || "";
        refreshIfStale();
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
        return baseUrl + "/timetables/" + (type || "sub");
    }

    function refresh() {
        fetchTimetable(root.timetableType);
    }

    function setTimetableType(type) {
        if (!type || type === root.timetableType)
            return;
        root.timetableType = type;
        forceRefresh();
    }

    function fetchTimetable(type) {
        if (!apiToken) {
            root.hasError = true;
            root.errorMessage = I18n.trFor("animeCalendar", "API token not configured");
            errorOccurred(root.errorMessage);
            return;
        }

        if (root.isLoading)
            return;

        const now = Date.now();
        if (now - root.lastFetchTime < root.minFetchInterval)
            return;

        root.lastFetchTime = now;
        root.isLoading = true;
        root.hasError = false;
        root.errorMessage = "";

        const week = isoWeek(new Date());
        request("/timetables/" + (type || "sub"), { year: week.year, week: week.week }, (error, data) => {
            if (error) {
                root.handleFailure(error);
                return;
            }
            if (!Array.isArray(data)) {
                root.handleFailure(I18n.trFor("animeCalendar", "Invalid response format"));
                return;
            }
            root.timetable = data;
            root.lastUpdated = Date.now();
            root.filterTodayAnime();
            root.isLoading = false;
            root.handleSuccess();
            root.timetableUpdated(false);
        });
    }

    // callback(error, data): error is a translated message or null
    function request(path, query, callback) {
        if (!root.apiToken) {
            callback(I18n.trFor("animeCalendar", "API token not configured"), null);
            return;
        }
        let url = root.baseUrl + path;
        const params = Object.keys(query || {}).map(key => encodeURIComponent(key) + "=" + encodeURIComponent(query[key]));
        if (params.length)
            url += "?" + params.join("&");

        const pending = root._active?.url === url ? root._active : root._queue.find(item => item.url === url);
        if (pending) {
            pending.callbacks.push(callback);
            return;
        }
        root._queue.push({ url: url, callbacks: [callback] });
        root._runNext();
    }

    function _runNext() {
        if (root._active || !root._queue.length)
            return;
        root._active = Object.assign(root._queue.shift(), { exitCode: -1, exited: false, body: null });
        // "-H @-" reads the auth header from stdin so the token never shows up in ps or /proc
        requester.command = curlBaseCmd.concat(["-H", "@-", "-H", "Accept: application/json", root._active.url]);
        requester.stdinEnabled = true;
        requester.running = true;
    }

    // Process exit and stdout end arrive in either order; finish after both
    function _maybeFinish() {
        const job = root._active;
        if (!job || !job.exited || job.body === null)
            return;
        root._active = null;

        let error = null;
        let data = null;
        if (job.exitCode !== 0) {
            error = I18n.trFor("animeCalendar", "Request failed with exit code: %1").arg(job.exitCode);
        } else {
            try {
                data = JSON.parse(job.body);
            } catch (e) {
                error = I18n.trFor("animeCalendar", "Failed to parse response: %1").arg(e.message);
            }
        }
        for (const callback of job.callbacks)
            callback(error, data);
        root._runNext();
    }

    function refreshIfStale() {
        if (!root.apiToken)
            return;
        if (root.hasError || !root.timetable.length || Date.now() - root.lastUpdated > root.staleAfter)
            refresh();
    }

    // ISO week, Monday to Sunday, matching the API's year/week parameters
    function isoWeek(date) {
        const day = new Date(Date.UTC(date.getFullYear(), date.getMonth(), date.getDate()));
        day.setUTCDate(day.getUTCDate() + 4 - (day.getUTCDay() || 7));
        const yearStart = Date.UTC(day.getUTCFullYear(), 0, 1);
        return { year: day.getUTCFullYear(), week: Math.ceil(((day.getTime() - yearStart) / 86400000 + 1) / 7) };
    }

    function weekKey(week, type) {
        return week.year + "-" + week.week + ":" + type;
    }

    function applyCachedTimetable(data, time) {
        if (!Array.isArray(data) || time <= root.lastUpdated)
            return;
        root.timetable = data;
        root.lastUpdated = time;
        filterTodayAnime();
        timetableUpdated(true);
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
        root.errorMessage = message || I18n.trFor("animeCalendar", "Failed to fetch data");
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

    // The timetable only holds this week's episode; an aired weekly show airs again 7 days later
    function nextAiring(anime) {
        const date = parseDate(anime.episodeDate);
        const episode = Number(anime.episodeNumber) || 0;
        if (!date || date.getTime() >= Date.now())
            return { date: date, episode: episode };
        const total = Number(anime.episodes) || 0;
        if (total > 0 && episode >= total)
            return { date: date, episode: episode };
        return {
            date: new Date(date.getTime() + 7 * 24 * 60 * 60 * 1000),
            episode: episode > 0 ? episode + 1 : 0
        };
    }

    function hasAired(date) {
        return !!date && date.getTime() < Date.now();
    }

    function getTimeUntil(date) {
        if (!date) return "";
        const now = new Date();
        const diff = date.getTime() - now.getTime();

        if (diff < 0) return I18n.trFor("animeCalendar", "Aired");

        const hours = Math.floor(diff / (1000 * 60 * 60));
        const minutes = Math.floor((diff % (1000 * 60 * 60)) / (1000 * 60));

        if (hours > 24) {
            const days = Math.floor(hours / 24);
            return I18n.trFor("animeCalendar", "%1d %2h").arg(days).arg(hours % 24);
        }
        if (hours > 0) {
            return I18n.trFor("animeCalendar", "%1h %2m").arg(hours).arg(minutes);
        }
        return I18n.trFor("animeCalendar", "%1m").arg(minutes);
    }

    function getImageUrl(route) {
        if (!route) return "";
        return "https://img.animeschedule.net/production/assets/public/img/" + route;
    }

    function isInWatchlist(anime) {
        if (!anime || !anime.route)
            return false;
        return root.watchlist.some(entry => entry.route === anime.route);
    }

    function watchlistEntry(anime) {
        return {
            route: anime.route,
            title: anime.title || "",
            english: anime.english || "",
            romaji: anime.romaji || "",
            native: anime.native || "",
            image: anime.imageVersionRoute || "",
            episodes: Number(anime.episodes) || 0,
            finished: false
        };
    }

    function toggleWatchlist(anime) {
        if (!anime || !anime.route)
            return;
        if (isInWatchlist(anime))
            root.watchlist = root.watchlist.filter(entry => entry.route !== anime.route);
        else
            root.watchlist = root.watchlist.concat([watchlistEntry(anime)]);
        updateWatchlistToday();
        watchlistModified();
    }

    // Versions before 2.1 stored bare route strings
    function setWatchlist(list) {
        const seen = {};
        const entries = [];
        for (const item of list || []) {
            const entry = typeof item === "string" ? { route: item } : item;
            if (!entry || typeof entry.route !== "string" || !entry.route || seen[entry.route])
                continue;
            seen[entry.route] = true;
            entries.push(entry);
        }
        root.watchlist = entries;
        updateWatchlistToday();
    }

    function detailsEntry(details) {
        const names = details.names || {};
        return {
            route: details.route,
            title: details.title || "",
            english: names.english || "",
            romaji: names.romaji || "",
            native: names.native || "",
            image: details.imageVersionRoute || "",
            episodes: Number(details.episodes) || 0,
            finished: details.status === "Finished",
            checked: Date.now()
        };
    }

    function updateWatchlistEntries(updates) {
        if (!updates.length)
            return;
        const byRoute = {};
        for (const update of updates)
            byRoute[update.route] = update;
        root.watchlist = root.watchlist.map(entry => byRoute[entry.route] ? Object.assign({}, entry, byRoute[entry.route]) : entry);
        watchlistModified();
    }

    function clearFinished() {
        const finished = root.watchlistRows.filter(row => row.state === "finished").map(row => row.entry.route);
        if (!finished.length)
            return;
        root.watchlist = root.watchlist.filter(entry => finished.indexOf(entry.route) === -1);
        updateWatchlistToday();
        watchlistModified();
    }

    function displayTitle(entry, anime) {
        return entry?.title || anime?.title || entry?.route || anime?.route || I18n.trFor("animeCalendar", "Unknown");
    }

    // One row per starred show: state is "upcoming", "finished" or "notAiring" (not in this week's timetable)
    readonly property var watchlistRows: {
        const byRoute = {};
        for (const anime of root.timetable)
            byRoute[anime.route] = anime;
        const rank = { upcoming: 0, notAiring: 1, finished: 2 };
        const rows = root.watchlist.map(entry => {
            const anime = byRoute[entry.route] || null;
            if (!anime)
                return { entry: entry, anime: null, state: entry.finished ? "finished" : "notAiring", date: null, episode: 0 };
            const total = Number(anime.episodes) || entry.episodes || 0;
            const episode = Number(anime.episodeNumber) || 0;
            const lastAired = total > 0 && episode >= total && hasAired(parseDate(anime.episodeDate));
            const next = nextAiring(anime);
            return { entry: entry, anime: anime, state: lastAired ? "finished" : "upcoming", date: next.date, episode: next.episode };
        });
        return rows.sort((a, b) => {
            if (a.state !== b.state)
                return rank[a.state] - rank[b.state];
            if (a.date && b.date && a.date.getTime() !== b.date.getTime())
                return a.date.getTime() - b.date.getTime();
            return displayTitle(a.entry, a.anime).localeCompare(displayTitle(b.entry, b.anime));
        });
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
        id: requester
        stdinEnabled: true

        onStarted: {
            write("Authorization: Bearer " + root.apiToken + "\n");
            stdinEnabled = false;
        }

        stdout: StdioCollector {
            onStreamFinished: {
                if (!root._active)
                    return;
                root._active.body = text;
                root._maybeFinish();
            }
        }

        onExited: exitCode => {
            if (!root._active)
                return;
            root._active.exitCode = exitCode;
            root._active.exited = true;
            root._maybeFinish();
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
        onTriggered: root.forceRefresh()
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
                    root.refreshIfStale();
                }
            }
        }

        onExited: exitCode => {
            if (exitCode !== 0) {
                root.hasError = true;
                root.errorMessage = I18n.trFor("animeCalendar", "Failed to read API token file: %1").arg(root.apiTokenPath);
                root._tokenFromFile = "";
            }
        }
    }
}
